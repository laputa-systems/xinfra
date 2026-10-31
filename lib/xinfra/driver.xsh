##! Production observations and applies over one host at a time.

use xinfra.host as host
use xinfra.inventory as inventory
use xinfra.model as model
use xinfra.plan as plan
use xinfra.remote as remote
use xinfra.resources.command as command
use xinfra.resources.dir as dir
use xinfra.resources.file as file
use xinfra.resources.group as group_resource
use xinfra.resources.package as package
use xinfra.resources.service as service
use xinfra.resources.symlink as symlink
use xinfra.resources.user as user_resource
use xinfra.transport as transport
use xinfra.validate as validate

proc connect(entry: inventory.Host) -> Result[transport.Session, Error] {
  match transport.connect_endpoint(entry.address, entry.port, entry.user, entry.key, entry.host_key) {
    Ok(value) => Ok(value),
    Err(message) => Err(error.failure(message)),
  }
}

proc elevation(session: transport.Session) -> Result[List[Str], Error] {
  let doas = match transport.exec(session, ["doas", "-n", "true"]) {
    Ok(value) => value,
    Err(_) => { return Ok([]) },
  }
  if doas.exit_code == 0 {
    return Ok(["doas", "-n"])
  }

  let sudo = match transport.exec(session, ["sudo", "-n", "true"]) {
    Ok(value) => value,
    Err(_) => { return Ok([]) },
  }
  if sudo.exit_code == 0 {
    return Ok(["sudo", "-n"])
  }

  Ok([])
}

proc unknown(inspection: Result[host.Inspection, Error]) -> plan.Observed {
  match inspection {
    Ok(value) => host.observed(value),
    Err(_) => plan.Unknown,
  }
}

## Read one resource fact over a short-lived session.
export proc observe(entry: inventory.Host, resource: model.Resource) -> Result[plan.Observed, Error] {
  with session = connect(entry)? {
    match resource {
      model.Directory(spec) => unknown(remote.inspect_path(session, spec.path)),
      model.File(spec) => unknown(remote.inspect_path(session, spec.path)),
      model.Symlink(spec) => unknown(remote.inspect_path(session, spec.path)),
      model.Package(spec) => match package.fact(session, spec) {
        Ok(value) => value,
        Err(_) => plan.Unknown,
      },
      model.UserResource(spec) => match user_resource.fact(session, spec.name) {
        Ok(value) => value,
        Err(_) => plan.Unknown,
      },
      model.GroupResource(spec) => match group_resource.fact(session, spec.name) {
        Ok(value) => value,
        Err(_) => plan.Unknown,
      },
      model.CommandResource(spec) => match command.observe(session, spec, false) {
        Ok(value) => value,
        Err(_) => plan.Unknown,
      },
      model.ServiceResource(spec) => match service.fact(session, spec.name) {
        Ok(value) => value,
        Err(_) => plan.Unknown,
      },
    }
  }
}

proc apply_one(
  session: transport.Session,
  entry: inventory.Host,
  resource: model.Resource,
  source: validate.PreparedSource?,
  elevate: List[Str],
) -> Result[host.ApplyResult, Error] {
  let resource_elevate = if model.privilege(resource) == model.AsRoot { elevate } else { [] }
  match resource {
    model.Directory(spec) => Ok(dir.apply_remote(session, entry.name, spec, resource_elevate)),
    model.File(spec) => Ok(file.apply_remote(session, entry.name, spec, source, resource_elevate)),
    model.Symlink(spec) => Ok(symlink.apply_remote(session, entry.name, spec, resource_elevate)),
    model.Package(spec) => match package.apply_remote(session, entry.name, spec, resource_elevate) {
      Ok(value) => Ok(value.result),
      Err(failure) => Err(failure),
    }
    model.UserResource(spec) => user_resource.apply_remote(session, entry.name, spec, resource_elevate),
    model.GroupResource(spec) => group_resource.apply_remote(session, entry.name, spec, resource_elevate),
    model.CommandResource(spec) => command.apply_remote(session, entry.name, spec, resource_elevate, true),
    model.ServiceResource(spec) => service.apply_remote(session, entry.name, spec, resource_elevate),
  }
}

## Apply one resource over a short-lived session.
export proc apply(
  entry: inventory.Host,
  resource: model.Resource,
  source: validate.PreparedSource?,
) -> Result[host.ApplyResult, Error] {
  with session = connect(entry)? {
    let elevate = elevation(session)?
    apply_one(session, entry, resource, source, elevate)?
  }
}

## Apply one coalesced service notification over a short-lived session.
export proc notify(entry: inventory.Host, spec: model.ServiceSpec) -> Result[host.ApplyResult, Error] {
  with session = connect(entry)? {
    let elevate = elevation(session)?
    if spec.on_change == model.Reload {
      service.reload_remote(session, spec.name, elevate)?
    } else {
      service.restart_remote(session, spec.name, elevate)?
    }
  }
}
