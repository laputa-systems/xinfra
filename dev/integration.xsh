##! Integration dispatcher.

use integration.commands as commands_case
use integration.dirs as dirs_case
use integration.facts as facts_case
use integration.files as files_case
use integration.lock as lock_case
use integration.multi_host as multi_host_case
use integration.packages as packages_case
use integration.plans as plans_case
use integration.secrets as secrets_case
use integration.services as services_case
use integration.transport as transport_case
use integration.users as users_case

cli main(case: Str = "all") [fs, process, env, time, error, io] {
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

  if case == "users" or case == "all" {
    match users_case.check_users() {
      Ok(_) => {}
      Err(message) => fail message
    }
  }

  if case == "commands" or case == "commands,services" or case == "all" {
    match commands_case.check_commands() {
      Ok(_) => {}
      Err(message) => fail message
    }
  }

  if case == "services" or case == "commands,services" or case == "all" {
    match services_case.check_services() {
      Ok(_) => {}
      Err(message) => fail message
    }
  }

  let multi_cases = case == "multi-host,ordering,lock,cancel" or case == "multi-host,ordering,cancel,lock"
  if case == "multi-host" or case == "ordering" or case == "cancel" or multi_cases or case == "all" {
    match multi_host_case.check_multi_host() {
      Ok(_) => {}
      Err(message) => fail message
    }
  }

  if case == "lock" or multi_cases or case == "all" {
    match lock_case.check_lock() {
      Ok(_) => {}
      Err(message) => fail message
    }
  }

  if case == "secrets" or case == "reporting" or case == "secrets,reporting" or case == "all" {
    match secrets_case.check_secrets() {
      Ok(_) => {}
      Err(error) => fail error.message
    }
  }

  if case == "stale-plan" or case == "plans" or case == "all" {
    match plans_case.check_plans() {
      Ok(_) => {}
      Err(error) => fail error.message
    }
  }

  if case != "transport" and case != "facts" and case != "dirs,symlinks" and case != "dirs" and case != "symlinks" and case != "files" and case != "packages" and case != "users" and case != "commands" and case != "services" and case != "commands,services" and case != "multi-host" and case != "ordering" and case != "cancel" and case != "lock" and case != "multi-host,ordering,lock,cancel" and case != "multi-host,ordering,cancel,lock" and case != "secrets" and case != "reporting" and case != "secrets,reporting" and case != "stale-plan" and case != "plans" and case != "all" {
    fail f"unknown integration case {case}"
  }
}
