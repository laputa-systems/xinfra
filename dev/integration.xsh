##! Integration dispatcher.

use integration.transport as transport_case

cli main(case: Str = "all") [fs, process, env, error, io] {
  if case == "transport" or case == "all" {
    match transport_case.execute() {
      Ok(_) => {}
      Err(message) => fail message
    }
  } else {
    fail f"unknown integration case {case}"
  }
}
