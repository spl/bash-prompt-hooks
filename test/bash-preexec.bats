#!/usr/bin/env bats

setup() {
  # Reset these for each test
  unset PROMPT_COMMAND
  trap DEBUG

  # Strict checking to get testable errors
  set -o nounset

  # Needed for testing
  __bp_delay_install="true"

  # Source the script
  source "${BATS_TEST_DIRNAME}/../bash-prompt-hooks.sh"
}

bp_install() {
  __bp_install_after_session_init
  eval "$PROMPT_COMMAND"
}

test_preexec_arg() {
  [ -z "$1" ]
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

@test "No functions defined for preexec should simply return" {
    __bp_interactive_mode

    run '__bp_preexec_invoke_exec' 'true'
    [ $status -eq 0 ]
    [ -z "$output" ]
}

@test "precmd should execute a function once" {
    precmd() { echo "test echo"; }
    run '__bp_precmd_invoke_cmd'
    [ $status -eq 0 ]
    [ "$output" == "test echo" ]
}

@test "precmd should set \$? to be the previous exit code" {
    echo_exit_code() {
      echo "$?"
    }
    return_exit_code() {
      return $1
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
    false | true
    __bp_precmd_invoke_cmd
  }

  run 'set_pipestatus_and_run_precmd'
  [ $status -eq 0 ]
  [ "$output" == "1 0" ]
}

@test "precmd should set \$_ to be the previous last arg" {
    precmd() { echo "$_"; }
    bats_trap=$(trap -p DEBUG)
    trap DEBUG # remove the Bats stack-trace trap so $_ doesn't get overwritten
    : "last-arg"
    __bp_preexec_invoke_exec "$_"
    eval "$bats_trap" # Restore trap
    run '__bp_precmd_invoke_cmd'
    [ $status -eq 0 ]
    [ "$output" == "last-arg" ]
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
    preexec() { parts=(1_2); echo $parts; }
    __bp_interactive_mode
    run '__bp_preexec_invoke_exec'
    [ $status -eq 0 ]
    [ "$output" == "1 2" ]
}

@test "precmd should execute a function with IFS defined to local scope" {
    IFS=_
    precmd() { parts=(2_2); echo $parts; }
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
