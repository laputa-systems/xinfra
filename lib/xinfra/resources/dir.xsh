##! Directory apply logic over the host boundary, one level deep.

use xinfra.host
use xinfra.model
use xinfra.plan

proc verify_after(ops: host.HostOps, spec: model.DirectorySpec) [fs, env, error] -> host.ApplyResult {
  match ops.inspect_path(spec.path) {
    Err(failure) => host.result(
      ops,
      spec.id,
      host.Unknown,
      verified: false,
      cause: f"inspect after apply failed: {failure.message}",
    ),
    Ok(inspection) => {
      let verification = plan.verify(model.Directory(spec), null, host.observed(inspection))
      if verification.ok {
        host.result(ops, spec.id, host.Changed, verified: true)
      } else {
        host.result(
          ops,
          spec.id,
          host.Partial,
          verified: false,
          cause: verification.cause,
        )
      }
    },
  }
}

proc finish(
  ops: host.HostOps,
  spec: model.DirectorySpec,
  before: host.Inspection,
  attempted: Result[Unit, Error],
) [fs, env, error] -> host.ApplyResult {
  match attempted {
    Ok(_) => verify_after(ops, spec),
    Err(failure) => {
      match ops.inspect_path(spec.path) {
        Err(_) => host.result(
          ops,
          spec.id,
          host.Unknown,
          verified: false,
          cause: failure.message,
        ),
        Ok(after) => {
          if before == after {
            host.failed(ops, spec.id, failure.message)
          } else {
            host.result(ops, spec.id, host.Partial, verified: false, cause: failure.message)
          }
        },
      }
    },
  }
}

proc secure_parent(ops: host.HostOps, spec: model.DirectorySpec) [fs, env, error] -> Result[Bool, Error] {
  ops.parent_secure(spec.path.parent(), spec.owner)
}

## Applies one directory resource and verifies the resulting state.
export proc apply(ops: host.HostOps, spec: model.DirectorySpec) [fs, env, error] -> host.ApplyResult {
  let inspection = match ops.inspect_path(spec.path) {
    Ok(value) => value,
    Err(failure) => {
      return host.failed(ops, spec.id, f"inspect failed: {failure.message}")
    },
  }
  let assessment = plan.assess(model.Directory(spec), null, host.observed(inspection))
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

  let secure = match secure_parent(ops, spec) {
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
    host.Missing => {
      let attempted = try {
        ops.mkdir_path(spec.path, spec.mode)?
        ops.set_metadata(spec.path, spec.mode, spec.owner, spec.group)?
      }
      finish(ops, spec, inspection, attempted)
    }
    host.Found(stat) => {
      if stat.kind != "dir" {
        return host.result(
          ops,
          spec.id,
          host.Blocked,
          verified: false,
          cause: f"{spec.path.display()} is a {stat.kind}, not a directory",
        )
      }

      let attempted = try {
        if spec.state == model.Absent {
          ops.remove_dir_path(spec.path)?
        } else {
          ops.set_metadata(spec.path, spec.mode, spec.owner, spec.group)?
        }
      }
      finish(ops, spec, inspection, attempted)
    }
  }
}
