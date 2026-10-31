##! Integration dispatcher.

use integration.facts as facts_case
use integration.transport as transport_case

cli main(case: Str = "all") [fs, process, env, error, io] {
  if case == "transport" or case == "all" {
    match transport_case.execute() {
      Ok(_) => {}
      Err(message) => fail message
    }
  }

  if case == "facts" or case == "all" {
    match facts_case.execute() {
      Ok(_) => {}
      Err(message) => fail message
    }
  }

  if case != "transport" and case != "facts" and case != "all" {
    fail f"unknown integration case {case}"
  }
}
