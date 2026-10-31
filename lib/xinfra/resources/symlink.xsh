##! Symbolic-link apply logic over the host boundary with explicit replacement.

use xinfra.host
use xinfra.model
use xinfra.plan

proc verify_after(ops: host.HostOps, spec: model.SymlinkSpec) [fs, env, error] -> host.ApplyResult {
  match ops.inspect_path(spec.path) {
    Err(failure) => host.result(
      ops,
      spec.id,
      host.Unknown,
      verified: false,
      cause: f"inspect after apply failed: {failure.message}",
    ),
    Ok(inspection) => {
      let verification = plan.verify(model.Symlink(spec), null, host.observed(inspection))
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
  spec: model.SymlinkSpec,
  before: host.Inspection,
  failure: Error,
) [fs, env, error] -> host.ApplyResult {
  match ops.inspect_path(spec.path) {
    Err(_) => host.result(ops, spec.id, host.Unknown, verified: false, cause: failure.message),
    Ok(after) => {
      if before == after {
        host.failed(ops, spec.id, failure.message)
      } else {
        host.result(ops, spec.id, host.Partial, verified: false, cause: failure.message)
      }
    },
  }
}

proc create_link(ops: host.HostOps, spec: model.SymlinkSpec, before: host.Inspection) [fs, env, error] -> host.ApplyResult {
  let staged = match ops.reserve_staging(spec.path) {
    Ok(value) => value,
    Err(failure) => {
      return host.failed(ops, spec.id, f"staging failed: {failure.message}")
    },
  }
  defer {
    let _ = ops.remove_path(staged)
  }

  match ops.symlink(spec.target, staged) {
    Err(failure) => {
      return host.failed(ops, spec.id, f"link creation failed: {failure.message}")
    },
    Ok(_) => {}
  }

  match ops.promote(staged, spec.path) {
    Err(failure) => {
      return finish_failure(ops, spec, before, failure)
    },
    Ok(_) => {}
  }

  verify_after(ops, spec)
}

## Applies one symbolic-link resource and verifies the resulting target.
export proc apply(ops: host.HostOps, spec: model.SymlinkSpec) [fs, env, error] -> host.ApplyResult {
  let inspection = match ops.inspect_path(spec.path) {
    Ok(value) => value,
    Err(failure) => {
      return host.failed(ops, spec.id, f"inspect failed: {failure.message}")
    },
  }
  let assessment = plan.assess(model.Symlink(spec), null, host.observed(inspection))
  match assessment.prediction {
    plan.Unchanged => {
      return host.result(ops, spec.id, host.Unchanged, verified: true)
    },
    plan.Blocked => {
      return host.result(ops, spec.id, host.Blocked, verified: false, cause: assessment.cause)
    }
    plan.Undetermined => {
      return host.result(ops, spec.id, host.Unknown, verified: false, cause: assessment.cause)
    }
    plan.Changed => {}
  }

  let secure = match ops.parent_secure(spec.path.parent(), null) {
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

  match inspection {
    host.Missing => create_link(ops, spec, inspection),
    host.Found(stat) => {
      if spec.state == model.Absent {
        if stat.kind != "symlink" {
          return host.result(
            ops,
            spec.id,
            host.Blocked,
            verified: false,
            cause: f"{spec.path.display()} is a {stat.kind}, not a symbolic link",
          )
        }

        let attempted = try {
          ops.remove_path(spec.path)?
        }
        return match attempted {
          Ok(_) => verify_after(ops, spec),
          Err(failure) => finish_failure(ops, spec, inspection, failure),
        }
      }

      create_link(ops, spec, inspection)
    },
  }
}
