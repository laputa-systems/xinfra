##! Integration dispatcher.

use integration.dirs as dirs_case
use integration.facts as facts_case
use integration.files as files_case
use integration.packages as packages_case
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

  if case == "files" or case == "all" {
    match files_case.check_files() {
      Ok(_) => {}
      Err(message) => fail message
    }
  }

  if case == "packages" or case == "all" {
    match packages_case.check_packages() {
      Ok(_) => {}
      Err(message) => fail message
    }
  }

  if case != "transport" and case != "facts" and case != "dirs,symlinks" and case != "dirs" and case != "symlinks" and case != "files" and case != "packages" and case != "all" {
    fail f"unknown integration case {case}"
  }
}
