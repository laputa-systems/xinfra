##! Remote file staging and validation.

use xinfra.remote as remote
use xinfra.transport as transport
use xinfra.validate

## Stream a prepared source into an owned staging path.
export proc write(
  session: transport.Session,
  destination: Path,
  source: validate.PreparedSource,
) -> Result[Unit, Error] {
  match source {
    validate.Local(value) => {
      let result = match transport.upload_file(session, destination, value.path, 180000) {
        Ok(value) => value,
        Err(message) => { return Err(error.failure(message)) },
      }
      return Err(error.failure(result.stderr.utf8() ?? "")) when result.exit_code != 0
      Ok()
    }
    validate.Content(value) => {
      let result = match transport.write_bytes(session, destination, bytes.from_text(value.text), 60000) {
        Ok(value) => value,
        Err(message) => { return Err(error.failure(message)) },
      }
      return Err(error.failure(result.stderr.utf8() ?? "")) when result.exit_code != 0
      Ok()
    }
    validate.Templated(value) => {
      let result = match transport.write_bytes(session, destination, bytes.from_text(value.text), 60000) {
        Ok(value) => value,
        Err(message) => { return Err(error.failure(message)) },
      }
      return Err(error.failure(result.stderr.utf8() ?? "")) when result.exit_code != 0
      Ok()
    }
    validate.Secret(_) => Err(error.failure("secret file sources are R7")),
  }
}

## Run one validator argv with the staged path appended.
export proc validate(session: transport.Session, argv: List[Str], staged: Path) -> Result[Unit, Error] {
  if argv.is_empty() {
    return Err(error.failure("validator argv is empty"))
  }
  var command = argv
  command += [staged.display()]
  let result = match transport.exec(session, command, 60000) {
    Ok(value) => value,
    Err(message) => { return Err(error.failure(message)) },
  }
  return Err(error.failure(result.stderr.utf8() ?? "")) when result.exit_code != 0
  Ok()
}
