# roster

Lista los agentes de código que están vivos en esta máquina: Claude, Grok y Codex.

No es una terminal. cmux sigue siendo la ventana, Neovim el editor y tmux el motor de las sesiones. roster responde tres cosas: quién está corriendo, en qué carpeta, y cómo entrar sin matarlo al cerrar la lista.

## Qué muestra

Una fila entra si el ejecutable del proceso es exactamente `claude`, `grok` o `codex`. No entran la app de ChatGPT, los helpers de Claude.app ni el historial de sesiones viejas.

| Agente | Estado |
| --- | --- |
| Claude | El de `claude agents --json`. `busy` se muestra como `working`. `waiting` e `idle` se muestran como vienen. Cualquier otra palabra se muestra cruda. |
| Grok | `running`. No publica waiting ni idle. |
| Codex | `running`, y solo si hay un proceso `codex`. El historial en `~/.codex/sessions` no es una sesión viva. |

Si el proceso no está en un pane de tmux, la segunda línea dice `sin tmux`. Enter no inventa un salto. Para meterlo en tmux: `roster open`.

Cerrar la lista, o el popup, no mata al agente. `ctrl-x` mata el proceso, y solo si sigue siendo `claude`, `grok` o `codex`.

## Uso

```bash
roster                         # popup si estás en tmux; si no, el picker
roster list                    # imprime la lista
roster list --plain            # sin color
roster open claude             # una sesión por carpeta, en el directorio actual
roster open grok --dir ~/src/foo
roster open claude --detach    # crea o reusa la sesión e imprime el nombre
```

Dentro de tmux, `Ctrl-b g` abre la lista. Enter entra. Esc cierra. Si apretás `Ctrl-b g` desde el popup de un agente, el popup se cierra y la sesión sigue.

`roster open` reusa la sesión de esa carpeta. No lanza un segundo proceso si ya existe.

El binario se puede forzar con `ROSTER_CMD_claude`, `ROSTER_CMD_grok` o `ROSTER_CMD_codex`. Grok, si no hay override, usa `~/.grok/bin/grok` antes que el wrapper que cmux deja en el `PATH`.

## Instalar

Hacen falta bash, tmux 3.2 o más nuevo, fzf, jq y lsof.

```bash
ln -sfn "$HOME/Documents/Github/roster/bin/roster" "$HOME/.local/bin/roster"
```

En `~/.tmux.conf`, o en el archivo al que ese path apunte:

```tmux
bind-key g run-shell "$HOME/.local/bin/roster popup #{q:client_name}"
```

Después: `tmux source-file ~/.tmux.conf`.

## Licencia

MIT.
