##! Remote command apply logic with guards.

use xinfra.host as host
use xinfra.model as model
use xinfra.plan as plan
use xinfra.remote as remote
use xinfra.transport as transport

proc execute(session: transport.Session, argv: List[Str], timeout_ms: Int? = null) -> Result[transport.ExecResult, Error] {
  match transport.exec(session, argv, timeout_ms) {
    Ok(value) => Ok(value),
    Err(message) => Err(error.failure(message)),
  }
}

proc text(value: Bytes) -> Str {
  value.utf8() ?? ""
}

pure result(host_name: Str, id: Str, status: host.ApplyStatus, verified: Bool, cause: Str? = null) -> host.ApplyResult {
  host.ApplyResult(id: id, host: host_name, status: status, verified: verified, cause: cause)
}

pure parse_or_zero(text_value: Str) -> Int {
  match text_value.parse_int() {
    Ok(value) => value,
    Err(_) => 0,
  }
}

pure duration_ms(value: Duration) -> Int {
  let text_value = f"{value}"
  if text_value.ends_with("ms") {
    return parse_or_zero(text_value.byte_slice(0, text_value.byte_len() - 2))
  }
  if text_value.ends_with("s") {
    return parse_or_zero(text_value.byte_slice(0, text_value.byte_len() - 1)) * 1000
  }
  if text_value.ends_with("m") {
    return parse_or_zero(text_value.byte_slice(0, text_value.byte_len() - 1)) * 60000
  }
  0
}

proc created(session: transport.Session, spec: model.CommandSpec) -> Result[Bool?, Error] {
  let creates_path = spec.creates
  if creates_path == null {
    return Ok(null)
  }
  match remote.inspect_path(session, creates_path ?? p"/") {
    Ok(host.Found(_)) => Ok(true),
    Ok(host.Missing) => Ok(false),
    _ => Ok(null),
  }
}

proc unless_satisfied(session: transport.Session, spec: model.CommandSpec, run_guard: Bool) -> Result[Bool?, Error] {
  let argv = spec.unless_argv
  if argv == null or ! run_guard {
    return Ok(null)
  }
  let timeout = duration_ms(spec.timeout ?? 0ms)
  let result = execute(session, argv ?? [], if timeout == 0 { null } else { timeout })?
  Ok(result.exit_code == 0)
}

## Observe a command without running its guards unless requested.
export proc observe(
  session: transport.Session,
  spec: model.CommandSpec,
  run_guards: Bool,
) -> Result[plan.Observed, Error] {
  let creates = created(session, spec)?
  let guard_result = unless_satisfied(session, spec, run_guards)?
  Ok(plan.Invocation(plan.CommandFacts(creates_present: creates, unless_satisfied: guard_result)))
}

## Apply one command resource.
export proc apply_remote(
  session: transport.Session,
  host_name: Str,
  spec: model.CommandSpec,
  elevate: List[Str] = [],
  run_guards: Bool = true,
) -> Result[host.ApplyResult, Error] {
  let before = observe(session, spec, run_guards)?
  let assessment = plan.assess(model.CommandResource(spec), null, before)
  match assessment.prediction {
    plan.Unchanged => return Ok(result(host_name, spec.id, host.Unchanged, true)),
    plan.Blocked => return Ok(result(host_name, spec.id, host.Blocked, false, assessment.cause)),
    plan.Undetermined => return Ok(result(host_name, spec.id, host.Unknown, false, assessment.cause)),
    plan.Changed => {}
  }

  let argv = if spec.argv != null {
    spec.argv ?? []
  } else if spec.shell != null {
    ["sh", "-c", spec.shell ?? ""]
  } else {
    return Ok(result(host_name, spec.id, host.Failed, false, "command needs argv or shell"))
  }
  var command = elevate
  if ! spec.env.is_empty() {
    command += ["env"]
    for {key: key, value: value} in spec.env {
      command += [f"{key}={value}"]
    }
  }
  command += argv
  let timeout = duration_ms(spec.timeout ?? 0ms)
  let ran = match execute(session, command, if timeout == 0 { null } else { timeout }) {
    Ok(value) => value,
    Err(failure) => {
      return Ok(result(host_name, spec.id, host.Failed, false, failure.message))
    }
  }
  if ran.exit_code != 0 {
    return Ok(result(host_name, spec.id, host.Failed, false, text(ran.stderr).trim()))
  }
  Ok(result(host_name, spec.id, host.Changed, true))
}
