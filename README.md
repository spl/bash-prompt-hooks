bash-prompt-hooks
=================

`preexec` and `precmd` hooks for the Bash prompt. This is a fork of
[**bash-preexec**] that has been simplified. (See the [ChangeLog] for details.)

[**bash-preexec**]: https://github.com/rcaloras/bash-preexec
[ChangeLog]: ./ChangeLog.md

## Usage

First, get the script. For example:

```
$ curl https://raw.githubusercontent.com/spl/bash-prompt-hooks/master/bash-prompt-hooks.sh -o $HOME/.bash-prompt-hooks.sh
```

Then, source it in your Bash configuration (`$HOME/.bashrc`, `$HOME/.profile`,
`$HOME/.bash_profile`, etc). For example:

```bash
[[ -r $HOME/.bash-prompt-hooks.sh ]] && source $HOME/.bash-prompt-hooks.sh
```

Finally, define the expected hook functions:

* `preexec`: executed before a command is executed (and just after the command
  string has been read)
* `precmd`: executed just before a prompt is shown

For example:

```bash
preexec() { echo "<before command execution>"; }
precmd() { echo "<before prompt>"; }
```

This should output something like:

```
~/bash-prompt-hooks $ ls
<before command execution>
LICENSE.md  README.md  bash-prompt-hooks.sh  test
<before prompt>
~/bash-prompt-hooks $
```

## Testing

Run the tests using [Bats](https://github.com/bats-core/bats-core):

```
$ bats test
```
