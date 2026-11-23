# roster

Lists the coding agents that are alive on this machine: Claude, Grok, and Codex.

This is not a terminal. cmux stays the window, Neovim stays the editor, and tmux stays the session engine. roster answers three things: who is running, which directory they are in, and how to attach without killing them when the list closes.

## What it shows

A row is included when the process executable is exactly `claude`, `grok`, or `codex`. The ChatGPT app, Claude.app helpers, and old session history are not included.

| Agent | Status |
| --- | --- |
| Claude | From `claude agents --json`. `busy` is shown as `working`. `waiting` and `idle` are shown as reported. Any other word is shown raw. |
| Grok | `running`. It does not publish waiting or idle. |
| Codex | `running`, and only when a `codex` process exists. History under `~/.codex/sessions` is not a live session. |

If the process is not in a tmux pane, the second line says `not in tmux`. Enter does not invent a jump. To put it in tmux: `roster open`.

Closing the list, or the popup, does not kill the agent. `ctrl-x` kills the process, and only if it is still `claude`, `grok`, or `codex`.

## Usage

```bash
roster                         # popup inside tmux; otherwise the picker
roster list                    # print the list
roster list --plain            # no color
roster open claude             # one session per directory, in the current directory
roster open grok --dir ~/src/foo
roster open claude --detach    # create or reuse the session and print its name
```

Inside tmux, `Ctrl-b g` opens the list. Enter attaches. Esc closes. Pressing `Ctrl-b g` from an agent's popup closes that popup and leaves the session running.

`roster open` reuses the session for that directory. It does not launch a second process when one already exists.

The binary can be overridden with `ROSTER_CMD_claude`, `ROSTER_CMD_grok`, or `ROSTER_CMD_codex`. Grok, when there is no override, uses `~/.grok/bin/grok` before the wrapper cmux puts on `PATH`.

## Install

Requires bash, tmux 3.2 or newer, fzf, jq, and lsof.

```bash
ln -sfn "$HOME/Documents/Github/roster/bin/roster" "$HOME/.local/bin/roster"
```

In `~/.tmux.conf`, or in the file that path points to:

```tmux
bind-key g run-shell "$HOME/.local/bin/roster popup #{q:client_name}"
```

Then: `tmux source-file ~/.tmux.conf`.

## License

MIT.
