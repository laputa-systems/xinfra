##! Secret references resolved only at apply time.

use xinfra.model
use xinfra.validate

## Resolve one secret reference to bytes.
export proc resolve(reference: model.SecretRef) [fs, env, error] -> Result[Bytes, Error] {
  match reference {
    model.FromEnv(name) => {
      let value = env.get(name)?
      Ok(bytes.from_text(value))
    }
    model.FromFile(source_path) => {
      let metadata = source_path.metadata()?
      if metadata.mode.bit_and(0o077) != 0 {
        return Err(error.failure(f"secret file {source_path.display()} is group- or world-readable"))
      }
      source_path.read_bytes()
    }
  }
}

## Digest the exact bytes a prepared source contributes.
export proc digest(source: validate.PreparedSource) [fs, env, error] -> Result[Str, Error] {
  match source {
    validate.Local(value) => Ok(hash.sha256(value.path)?.hex()),
    validate.Content(value) => Ok(hash.sha256(bytes.from_text(value.text)).hex()),
    validate.Templated(value) => Ok(hash.sha256(bytes.from_text(value.text)).hex()),
    validate.Secret(reference) => Ok(hash.sha256(resolve(reference)?).hex()),
  }
}

## Whether a prepared source resolves a secret at apply time.
export pure is_secret(source: validate.PreparedSource) -> Bool {
  match source {
    validate.Secret(_) => true,
    _ => false,
  }
}
