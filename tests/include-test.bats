#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../prompt-hooks.bash"

setup() {
  # Reset these for each test
  unset PROMPT_COMMAND
  trap DEBUG
}

@test "error when not run in Bash" {
  unset BASH_VERSION
  run source "${SCRIPT}"
  [ $status == 1 ]
  [ "$output" == 'prompt-hooks.bash: Error! This script only works in Bash.' ]
}

@test "should not import if it's already defined" {
  # shellcheck disable=SC2034
  __bp_imported="defined"
  # shellcheck disable=SC1090
  source "${SCRIPT}"
  [ -z "$(type -t __bp_preexec_and_precmd_install)" ]
}

@test "should import if not defined" {
  unset __bp_imported
  # shellcheck disable=SC1090
  source "${SCRIPT}"
  [ -n "$(type -t __bp_install)" ]
}

@test "warning for non-empty PROMPT_COMMAND" {
  PROMPT_COMMAND='true'
  run source "${SCRIPT}"
  [ $status -eq 0 ]
  [[ "$output" == *'Warning! Overriding PROMPT_COMMAND.'* ]] || return 1
}

@test "no warning for empty PROMPT_COMMAND" {
  PROMPT_COMMAND=''
  run source "${SCRIPT}"
  [ $status -eq 0 ]
  [ -z "$output" ]
}

@test "warning for existing DEBUG trap" {
  trap true DEBUG
  [ "$(trap -p DEBUG | cut -d' ' -f3)" == "'true'" ]
  run source "${SCRIPT}"
  [ $status -eq 0 ]
  [[ "$output" == *'Warning! Overriding DEBUG trap.'* ]] || return 1
}

@test "error for readonly PROMPT_COMMAND" {
  readonly PROMPT_COMMAND
  run source "${SCRIPT}"
  [ $status -eq 1 ]
  [[ "$output" == *'Error! PROMPT_COMMAND is read-only.'* ]] || return 1
}

@test "no error for readonly HISTCONTROL" {
  readonly HISTCONTROL
  run source "${SCRIPT}"
  [ $status -eq 0 ]
  [ -z "$output" ]
}

@test "no error for readonly HISTTIMEFORMAT" {
  readonly HISTTIMEFORMAT
  run source "${SCRIPT}"
  [ $status -eq 0 ]
  [ -z "$output" ]
}
