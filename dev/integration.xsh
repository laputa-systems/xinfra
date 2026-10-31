##! Integration dispatcher.

use integration.dirs as dirs_case
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

  if case == "dirs,symlinks" or case == "dirs" or case == "symlinks" or case == "all" {
    match dirs_case.check_dirs() {
      Ok(_) => {}
      Err(message) => fail message
    }
  }

  if case != "transport" and case != "facts" and case != "dirs,symlinks" and case != "dirs" and case != "symlinks" and case != "all" {
    fail f"unknown integration case {case}"
  }
}
