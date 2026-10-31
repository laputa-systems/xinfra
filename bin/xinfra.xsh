##! xinfra command line entry point.

use xinfra.cli as command_line

let root = match fs.gitroot() {
  Ok(value) => value,
  Err(_) => fs.cwd()?,
}
let code = command_line.run_cli(args, null, root)
exit code
