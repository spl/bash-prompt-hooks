#!/usr/bin/env bats

@test "should not import if it's already defined" {
  __bp_imported="defined"
  source "${BATS_TEST_DIRNAME}/../bash-prompt-hooks.sh"
  [ -z $(type -t __bp_preexec_and_precmd_install) ]
}

@test "should import if not defined" {
  unset __bp_imported
  source "${BATS_TEST_DIRNAME}/../bash-prompt-hooks.sh"
  [ -n $(type -t __bp_install) ]
}

@test "doesn't change HISTCONTROL" {
  readonly HISTCONTROL
  run source "${BATS_TEST_DIRNAME}/../bash-prompt-hooks.sh"
  [ $status -eq 0 ]
  [ "$output" == '' ]
}
@test "doesn't change HISTTIMEFORMAT" {
  readonly HISTTIMEFORMAT
  run source "${BATS_TEST_DIRNAME}/../bash-prompt-hooks.sh"
  [ $status -eq 0 ]
  [ "$output" == '' ]
}
