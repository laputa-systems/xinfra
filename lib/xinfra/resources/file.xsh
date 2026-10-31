##! File apply logic over the host boundary with staged validation.

use xinfra.host
use xinfra.model
use xinfra.plan
use xinfra.validate

proc load_source(ops: host.HostOps, source: validate.PreparedSource) [fs, env, error] -> Result[Bytes, Error] {
  match source {
    validate.Local(value) => {
      let data = ops.read_file_path(value.path)?
      let actual = hash.sha256(data).hex()
      if actual != value.digest {
        return Err(error.failure(f"source {value.path.display()} changed after planning"))
      }

      Ok(data)
    }
    validate.Content(value) => {
      let data = bytes.from_text(value.text)
      if hash.sha256(data).hex() != value.digest {
        return Err(error.failure("prepared content digest does not match"))
      }

      Ok(data)
    }
    validate.Templated(value) => {
      let data = bytes.from_text(value.text)
      if hash.sha256(data).hex() != value.digest {
        return Err(error.failure("rendered template digest does not match"))
      }

      Ok(data)
    }
    validate.Secret(reference) => ops.resolve_secret(reference),
  }
}

proc verify_after(
  ops: host.HostOps,
  spec: model.FileSpec,
  source: validate.PreparedSource,
  digest: Str,
) [fs, env, error] -> host.ApplyResult {
  let verification_source = if validate.digest(source) == null {
    validate.Local(validate.LocalSource(path: spec.path, digest: digest))
  } else {
    source
  }
  match ops.inspect_path(spec.path) {
    Err(failure) => host.result(
      ops,
      spec.id,
      host.Unknown,
      verified: false,
      cause: f"inspect after apply failed: {failure.message}",
    ),
    Ok(inspection) => {
      let verification = plan.verify(model.File(spec), verification_source, host.observed(inspection))
      if verification.ok {
        host.result(ops, spec.id, host.Changed, verified: true)
      } else {
        host.result(ops, spec.id, host.Partial, verified: false, cause: verification.cause)
      }
    },
  }
}

proc finish_failure(
  ops: host.HostOps,
  spec: model.FileSpec,
  before: host.Inspection,
  status: host.ApplyStatus,
  failure: Error,
) [fs, env, error] -> host.ApplyResult {
  match ops.inspect_path(spec.path) {
    Err(_) => host.result(ops, spec.id, host.Unknown, verified: false, cause: failure.message),
    Ok(after) => {
      if before == after {
        host.result(ops, spec.id, status, verified: false, cause: failure.message)
      } else {
        host.result(ops, spec.id, host.Partial, verified: false, cause: failure.message)
      }
    },
  }
}

proc verify_removed(ops: host.HostOps, spec: model.FileSpec) [fs, env, error] -> host.ApplyResult {
  match ops.inspect_path(spec.path) {
    Err(failure) => host.result(
      ops,
      spec.id,
      host.Unknown,
      verified: false,
      cause: f"inspect after apply failed: {failure.message}",
    ),
    Ok(inspection) => {
      let verification = plan.verify(model.File(spec), null, host.observed(inspection))
      if verification.ok {
        host.result(ops, spec.id, host.Changed, verified: true)
      } else {
        host.result(ops, spec.id, host.Partial, verified: false, cause: verification.cause)
      }
    },
  }
}

proc apply_content(
  ops: host.HostOps,
  spec: model.FileSpec,
  source: validate.PreparedSource,
  before: host.Inspection,
  data: Bytes,
) [fs, env, error] -> host.ApplyResult {
  let digest = hash.sha256(data).hex()
  let staged = match ops.reserve_staging(spec.path) {
    Ok(value) => value,
    Err(failure) => {
      return host.failed(ops, spec.id, f"staging failed: {failure.message}")
    },
  }
  defer {
    let _ = ops.remove_path(staged)
  }

  match ops.write_staging(staged, data) {
    Err(failure) => {
      return host.result(
        ops,
        spec.id,
        host.Partial,
        verified: false,
        cause: f"transfer failed: {failure.message}",
      )
    }
    Ok(_) => {}
  }

  match ops.digest_path(staged) {
    Err(failure) => {
      return host.failed(ops, spec.id, f"staged digest failed: {failure.message}")
    },
    Ok(actual) => {
      if actual != digest {
        return host.failed(ops, spec.id, "staged bytes do not match the intended digest")
      }
    },
  }

  match ops.set_metadata(staged, spec.mode, spec.owner, spec.group) {
    Err(failure) => {
      return host.failed(ops, spec.id, f"staged metadata failed: {failure.message}")
    },
    Ok(_) => {}
  }

  if spec.validate != null {
    let validation = spec.validate ?? model.Validation(argv: [])
    match ops.validate(validation.argv, staged) {
      Err(failure) => {
        return host.failed(ops, spec.id, f"validation failed: {failure.message}")
      },
      Ok(_) => {}
    }
  }

  match ops.promote(staged, spec.path) {
    Err(failure) => {
      return finish_failure(ops, spec, before, host.Failed, failure)
    }
    Ok(_) => {}
  }

  verify_after(ops, spec, source, digest)
}

## Applies one file resource and verifies the promoted state.
export proc apply(
  ops: host.HostOps,
  spec: model.FileSpec,
  source: validate.PreparedSource?,
) [fs, env, error] -> host.ApplyResult {
  let inspection = match ops.inspect_path(spec.path) {
    Ok(value) => value,
    Err(failure) => {
      return host.failed(ops, spec.id, f"inspect failed: {failure.message}")
    },
  }
  let assessment = plan.assess(model.File(spec), source, host.observed(inspection))
  match assessment.prediction {
    plan.Unchanged => {
      return host.result(ops, spec.id, host.Unchanged, verified: true)
    },
    plan.Blocked => {
      return host.result(ops, spec.id, host.Blocked, verified: false, cause: assessment.cause)
    }
    plan.Changed => {}
    plan.Undetermined => {
      if source == null {
        return host.failed(ops, spec.id, "a present file needs a prepared source")
      }
    }
  }

  if spec.state == model.Absent {
    let secure = match ops.parent_secure(spec.path.parent(), spec.owner) {
      Ok(value) => value,
      Err(failure) => {
      return host.failed(ops, spec.id, f"parent check failed: {failure.message}")
    },
    }
    if ! secure {
      return host.result(
        ops,
        spec.id,
        host.Blocked,
        verified: false,
        cause: f"parent of {spec.path.display()} is not a trusted directory",
      )
    }

    let attempted = try {
      ops.remove_path(spec.path)?
    }
    match attempted {
      Ok(_) => {
        return verify_removed(ops, spec)
      },
      Err(failure) => {
        return finish_failure(ops, spec, inspection, host.Failed, failure)
      },
    }
  }

  if source == null {
    return host.failed(ops, spec.id, "a present file needs a prepared source")
  }

  let secure = match ops.parent_secure(spec.path.parent(), spec.owner) {
    Ok(value) => value,
    Err(failure) => {
      return host.failed(ops, spec.id, f"parent check failed: {failure.message}")
    },
  }
  if ! secure {
    return host.result(
      ops,
      spec.id,
      host.Blocked,
      verified: false,
      cause: f"parent of {spec.path.display()} is not a trusted directory",
    )
  }

  let data = match load_source(ops, source) {
    Ok(value) => value,
    Err(failure) => {
      return host.failed(ops, spec.id, f"source failed: {failure.message}")
    },
  }
  let actual = hash.sha256(data).hex()
  match inspection {
    host.Found(stat) => {
      let owner_matches = spec.owner == null or spec.owner == stat.owner
      let group_matches = spec.group == null or spec.group == stat.group
      if stat.kind == "file" and stat.mode == spec.mode and owner_matches and group_matches and stat.digest == actual {
        return host.result(ops, spec.id, host.Unchanged, verified: true)
      }
    }
    host.Missing => {}
  }
  apply_content(ops, spec, source, inspection, data)
}
