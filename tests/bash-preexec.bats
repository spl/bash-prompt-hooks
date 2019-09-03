#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../prompt-hooks.bash"

setup() {
  # Reset these for each test
  unset PROMPT_COMMAND
  trap DEBUG

  # Strict checking to get testable errors
  set -o nounset

  # Needed for testing
  # shellcheck disable=SC2034
  __bp_delay_install="true"

  # Source the script
  # shellcheck disable=SC1090
  source "${SCRIPT}"
}

bp_install() {
  __bp_install_after_session_init
  eval "$PROMPT_COMMAND"
}

@test "__bp_install should exit if it's already installed" {
  bp_install
  run '__bp_install'
  [ $status -eq 1 ]
  [ -z "$output" ]
}

@test "__bp_install should remove trap logic and itself from PROMPT_COMMAND" {
  __bp_install_after_session_init

  [[ "$PROMPT_COMMAND" == *"trap DEBUG"* ]] || return 1
  [[ "$PROMPT_COMMAND" == *"__bp_install"* ]] || return 1

  eval "$PROMPT_COMMAND"

  [[ "$PROMPT_COMMAND" != *"trap DEBUG"* ]] || return 1
  [[ "$PROMPT_COMMAND" != *"__bp_install"* ]] || return 1
}

@test "PROMPT_COMMAND=\"\$PROMPT_COMMAND; foo\" should work" {
  bp_install

  PROMPT_COMMAND="$PROMPT_COMMAND; true"
  eval "$PROMPT_COMMAND"
}

@test 'success if preexec unset' {
  __bp_interactive_mode
  run '__bp_preexec_invoke_exec'
  [ $status -eq 0 ]
  [ -z "$output" ]
}

@test 'preexec should run only once' {
  preexec() { echo 'preexec output'; }
  __bp_interactive_mode
  run '__bp_preexec_invoke_exec'
  [ $status -eq 0 ]
  [ "$output" == 'preexec output' ]
}

@test 'success if precmd unset' {
  run '__bp_precmd_invoke_cmd'
  [ $status -eq 0 ]
  [ -z "$output" ]
}

@test 'precmd should run only once' {
  precmd() { echo 'precmd output'; }
  run '__bp_precmd_invoke_cmd'
  [ $status -eq 0 ]
  [ "$output" == 'precmd output' ]
}

@test 'preexec should not loop' {
  preexec() {
    __bp_preexec_invoke_exec
    echo 'no preexec recursion'
  }
  __bp_interactive_mode
  run '__bp_preexec_invoke_exec'
  [ $status -eq 0 ]
  [ "$output" == 'no preexec recursion' ]
}

@test 'precmd should not loop' {
  precmd() {
    __bp_precmd_invoke_cmd
    echo 'no precmd recursion'
  }
  run '__bp_precmd_invoke_cmd'
  [ $status -eq 0 ]
  [ "$output" == 'no precmd recursion' ]
}

@test 'invoking precmd should not fail if preexec unset last arg' {
  preexec() { unset __bp_last_argument_prev_command; }
  __bp_interactive_mode
  __bp_preexec_invoke_exec 'last arg'
  run '__bp_precmd_invoke_cmd'
  [ $status -eq 0 ]
  [ "$output" == '' ]
}

@test 'invoking preexec should not fail if precmd unset ret val' {
  preexec() { echo 'preexec output'; }
  precmd() { unset __bp_last_ret_value; }
  __bp_precmd_invoke_cmd
  __bp_interactive_mode
  run '__bp_preexec_invoke_exec' 'last arg'
  [ $status -eq 0 ]
  [ "$output" == 'preexec output' ]
}

@test "precmd should set \$? to be the previous exit code" {
  echo_exit_code() {
    echo "$?"
  }
  return_exit_code() {
    return "$1"
  }
  # Helper function is necessary because Bats' run doesn't preserve $?
  set_exit_code_and_run_precmd() {
    return_exit_code 251
    __bp_precmd_invoke_cmd
  }

  precmd() { echo_exit_code; }
  run 'set_exit_code_and_run_precmd'
  [ $status -eq 0 ]
  [ "$output" == "251" ]
}

@test "precmd should set \$BP_PIPESTATUS to the previous \$PIPESTATUS" {
  precmd() {
    echo "${BP_PIPESTATUS[*]}"
  }
  # Helper function is necessary because Bats' run doesn't preserve $PIPESTATUS
  set_pipestatus_and_run_precmd() {
    false | cat
    __bp_precmd_invoke_cmd
  }

  run 'set_pipestatus_and_run_precmd'
  [ $status -eq 0 ]
  [ "$output" == "1 0" ]
}

@test 'precmd should have $_ set to the last arg' {
  precmd() { echo "$_"; }
  __bp_interactive_mode
  __bp_preexec_invoke_exec 'last arg'
  run '__bp_precmd_invoke_cmd'
  [ $status -eq 0 ]
  [ "$output" == 'last arg' ]
}

@test "precmd preserves \$_" {
  precmd() { true; }
  __bp_precmd_invoke_cmd 'abc'
  [ "$_" == 'abc' ]
}

@test "preexec preserves \$_" {
  preexec() { true; }
  __bp_preexec_invoke_exec 'abc'
  [ "$_" == 'abc' ]
}

@test "preexec \$1 unbound" {
  preexec() { echo "$1"; }
  __bp_interactive_mode
  run '__bp_preexec_invoke_exec'
  [ $status -eq 1 ]
  [[ "$output" == *"unbound variable"* ]] || return 1
}

@test "precmd \$1 unbound" {
  precmd() { echo "$1"; }
  __bp_interactive_mode
  run '__bp_precmd_invoke_cmd'
  [ $status -eq 1 ]
  [[ "$output" == *"unbound variable"* ]] || return 1
}

@test "preexec should execute a function with IFS defined to local scope" {
  IFS=_
  # shellcheck disable=SC2086 disable=SC2128
  preexec() {
    parts=(1_2)
    echo $parts
  }
  __bp_interactive_mode
  run '__bp_preexec_invoke_exec'
  [ $status -eq 0 ]
  [ "$output" == "1 2" ]
}

@test "precmd should execute a function with IFS defined to local scope" {
  IFS=_
  # shellcheck disable=SC2086 disable=SC2128
  precmd() {
    parts=(2_2)
    echo $parts
  }
  run '__bp_precmd_invoke_cmd'
  [ $status -eq 0 ]
  [ "$output" == "2 2" ]
}

@test "preexec should set \$? to be the exit code" {
  preexec() { return 1; }
  __bp_interactive_mode
  run '__bp_preexec_invoke_exec'
  [ $status -eq 1 ]
}

@test "in_prompt_command should detect if a command is part of PROMPT_COMMAND" {

  PROMPT_COMMAND="precmd_invoke_cmd; something;"
  run '__bp_in_prompt_command' "something"
  [ $status -eq 0 ]

  run '__bp_in_prompt_command' "something_else"
  [ $status -eq 1 ]

  # Should trim commands and arguments here.
  PROMPT_COMMAND=" precmd_invoke_cmd ; something ; some_stuff_here;"
  run '__bp_in_prompt_command' " precmd_invoke_cmd "
  [ $status -eq 0 ]

  PROMPT_COMMAND=" precmd_invoke_cmd ; something ; some_stuff_here;"
  run '__bp_in_prompt_command' " not_found"
  [ $status -eq 1 ]

}
