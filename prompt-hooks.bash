# prompt-hooks.bash -- `preexec` and `precmd` hooks for the Bash prompt
# https://github.com/spl/bash-prompt-hooks
#
#
# 'preexec' functions are executed before each interactive command is
# executed, with the interactive command as its argument. The 'precmd'
# function is executed before each prompt is displayed.
#
# Author: Sean Leather
#   https://github.com/spl/bash-prompt-hooks
#
# Forked from:
#   https://github.com/rcaloras/bash-preexec (Ryan Caloras)
#
# Original:
#   https://www.twistedmatrix.com/users/glyph/preexec.bash.txt (Glyph Lefkowitz)
#
# Version: UNRELEASED
#

# General Usage:
#
#  1. Source this file at the end of your bash profile so as not to interfere
#     with anything else that's using PROMPT_COMMAND.
#
#  2. Add any precmd or preexec function.
#
#  Note: This module requires two Bash features which you must not otherwise be
#  using: the "DEBUG" trap, and the "PROMPT_COMMAND" variable. If you override
#  either of these after bash-prompt-hooks has been installed it will most
#  likely break.

__bp_err() {
  echo "prompt-hooks.bash: $1" >&2
}

# Make sure only Bash is sourcing this.
if [[ -z "${BASH_VERSION:-}" ]]; then
  __bp_err 'Error! This script only works in Bash.'
  return 1
fi

# Avoid duplicate inclusion
if [[ "${__bp_imported:-}" == "defined" ]]; then
  return 0
fi
__bp_imported="defined"

# This variable describes whether we are currently in "interactive mode";
# i.e. whether this shell has just executed a prompt and is waiting for user
# input.  It documents whether the current command invoked by the trace hook is
# run interactively by the user; it's set immediately after the prompt hook,
# and unset as soon as the trace hook is run.
__bp_preexec_interactive_mode=""

__bp_trim_whitespace() {
  local var="$*"
  var="${var#"${var%%[![:space:]]*}"}" # remove leading whitespace characters
  var="${var%"${var##*[![:space:]]}"}" # remove trailing whitespace characters
  echo -n "$var"
}

# This function is installed as part of the PROMPT_COMMAND;
# It sets a variable to indicate that the prompt was just displayed,
# to allow the DEBUG trap to know that the next command is likely interactive.
__bp_interactive_mode() {
  __bp_preexec_interactive_mode="on"
}

# This function is installed as part of the PROMPT_COMMAND.
# It will invoke the precmd function.
__bp_precmd_invoke_cmd() {
  # Save the returned value from our last command, and from each process in
  # its pipeline. Note: this MUST be the first thing done in this function.
  # shellcheck disable=SC2034
  __bp_last_ret_value="$?" BP_PIPESTATUS=("${PIPESTATUS[@]}")

  # Don't invoke precmds if we are inside an execution of an "original
  # prompt command" by another precmd execution loop. This avoids infinite
  # recursion.
  if ((${__bp_inside_precmd:-0} > 0)); then
    return
  fi
  local __bp_inside_precmd=1

  # Only execute the function if it exists.
  if type -t precmd 1>/dev/null; then
    __bp_set_ret_value "$__bp_last_ret_value" "${__bp_last_argument_prev_command:-}"
    precmd
  fi
}

# Sets a return value in $?. We may want to get access to the $? variable in our
# precmd function. This is available for instance in zsh. We can simulate it in bash
# by setting the value here.
__bp_set_ret_value() {
  return "${1:-}"
}

__bp_in_prompt_command() {

  local prompt_command_array
  IFS=';' read -ra prompt_command_array <<<"${PROMPT_COMMAND:-}"

  local trimmed_arg
  trimmed_arg=$(__bp_trim_whitespace "${1:-}")

  local command
  for command in "${prompt_command_array[@]:-}"; do
    local trimmed_command
    trimmed_command=$(__bp_trim_whitespace "$command")
    # Only execute each function if it actually exists.
    if [[ "$trimmed_command" == "$trimmed_arg" ]]; then
      return 0
    fi
  done

  return 1
}

# This function is installed as the DEBUG trap.  It is invoked before each
# interactive prompt display.  Its purpose is to inspect the current
# environment to attempt to detect if the current command is being invoked
# interactively, and invoke 'preexec' if so.
__bp_preexec_invoke_exec() {
  # Save the contents of $_ so that it can be restored later on.
  # https://stackoverflow.com/questions/40944532/bash-preserve-in-a-debug-trap#40944702
  __bp_last_argument_prev_command="${1:-}"
  # Don't invoke preexecs if we are inside of another preexec.
  if ((${__bp_inside_preexec:-0} > 0)); then
    return
  fi
  local __bp_inside_preexec=1

  # Checks if the file descriptor is not standard out (i.e. '1')
  # __bp_delay_install checks if we're in test. Needed for bats to run.
  # Prevents preexec from being invoked for functions in PS1
  if [[ ! -t 1 && -z "${__bp_delay_install:-}" ]]; then
    return
  fi

  if [[ -n "${COMP_LINE:-}" ]]; then
    # We're in the middle of a completer. This obviously can't be
    # an interactively issued command.
    return
  fi
  if [[ -z "${__bp_preexec_interactive_mode:-}" ]]; then
    # We're doing something related to displaying the prompt.  Let the
    # prompt set the title instead of me.
    return
  else
    # If we're in a subshell, then the prompt won't be re-displayed to put
    # us back into interactive mode, so let's not set the variable back.
    # In other words, if you have a subshell like
    #   (sleep 1; sleep 2)
    # You want to see the 'sleep 2' as a set_command_title as well.
    if [[ 0 -eq "${BASH_SUBSHELL:-}" ]]; then
      __bp_preexec_interactive_mode=""
    fi
  fi

  if __bp_in_prompt_command "${BASH_COMMAND:-}"; then
    # If we're executing something inside our prompt_command then we don't
    # want to call preexec. Bash prior to 3.1 can't detect this at all :/
    __bp_preexec_interactive_mode=""
    return
  fi

  # If none of the previous checks have returned out of this function, then
  # the command is in fact interactive and we should invoke the user's
  # preexec function.

  local preexec_ret_value=0

  # Only execute the function if it exists.
  if type -t preexec 1>/dev/null; then
    __bp_set_ret_value "${__bp_last_ret_value:-0}"
    preexec
    preexec_ret_value="$?"
  fi

  # Restore the last argument of the last executed command, and set the return
  # value of the DEBUG trap to be the return code of the last preexec function
  # to return an error.
  # If `extdebug` is enabled a non-zero return value from any preexec function
  # will cause the user's command not to execute.
  # Run `shopt -s extdebug` to enable
  __bp_set_ret_value "$preexec_ret_value" "${__bp_last_argument_prev_command:-}"
}

__bp_install() {
  # Exit if we already have this installed.
  if [[ "${PROMPT_COMMAND:-}" == *"__bp_precmd_invoke_cmd"* ]]; then
    return 1
  fi

  # Install the DEBUG trap and pass $_ to preserve it.
  trap '__bp_preexec_invoke_exec "$_"' DEBUG

  # Install our hooks in PROMPT_COMMAND to allow our trap to know when we've
  # actually entered something.
  PROMPT_COMMAND="__bp_precmd_invoke_cmd; __bp_interactive_mode"

  # Since this function is invoked via PROMPT_COMMAND, re-execute PC now that it's properly set
  eval "$PROMPT_COMMAND"
}

# Sets our trap and __bp_install as part of our PROMPT_COMMAND to install
# after our session has started. This allows bash-prompt-hooks to be included
# at any point in our bash profile. Ideally we could set our trap inside
# __bp_install, but if a trap already exists it'll only set locally to
# the function.
__bp_install_after_session_init() {

  # Exit with error if PROMPT_COMMAND is read-only.
  # Reference: https://stackoverflow.com/a/4441178
  if ! (unset PROMPT_COMMAND 2>/dev/null); then
    __bp_err 'Error! PROMPT_COMMAND is read-only.'
    return 1
  fi

  # Warn if PROMPT_COMMAND is not empty.
  if [[ -n "${PROMPT_COMMAND:-}" ]]; then
    __bp_err 'Warning! Overriding PROMPT_COMMAND.'
  fi

  unset PROMPT_COMMAND

  # Warn if a DEBUG trap already exists.
  if [[ -n "$(trap -p DEBUG)" ]]; then
    __bp_err 'Warning! Overriding DEBUG trap.'
  fi

  # Note that we cannot always replace the DEBUG trap in a sourced script:
  # Reference: https://stackoverflow.com/q/43989793

  # Installation is finalized in PROMPT_COMMAND, which allows us to override the DEBUG
  # trap. __bp_install sets PROMPT_COMMAND to its final value, so these are only
  # invoked once.
  # It's necessary to clear any existing DEBUG trap in order to set it from the install function.
  # Using \n as it's the most universal delimiter of bash commands
  PROMPT_COMMAND='trap DEBUG; __bp_install'
}

# Run our install so long as we're not delaying it.
if [[ -z "${__bp_delay_install:-}" ]]; then
  __bp_install_after_session_init
fi
