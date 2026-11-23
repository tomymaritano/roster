#!/usr/bin/env bash
# Prueba roster sin tocar el tmux del usuario y sin matar agentes vivos.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
roster=$root/bin/roster
# shellcheck source=bin/roster
source "$roster"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

[ "$(label_status busy)" = working ] || fail "busy"
[ "$(label_status waiting)" = waiting ] || fail "waiting"
[ "$(label_status idle)" = idle ] || fail "idle"
[ "$(label_status "")" = running ] || fail "vacio"
[ "$(label_status shell)" = shell ] || fail "shell se muestra crudo"
[ "$(status_rank waiting)" = 0 ] || fail "rank waiting"
[ "$(status_rank running)" = 2 ] || fail "rank running"
[ "$(status_rank working)" = 3 ] || fail "rank working"
[ "$(etime_to_secs "02-12:12:19")" = 216739 ] || fail "etime dias"
[ "$(etime_to_secs "01:02:03")" = 3723 ] || fail "etime hms"
[ "$(etime_to_secs "04:05")" = 245 ] || fail "etime ms"
[ "$(etime_to_secs "")" = 0 ] || fail "etime vacio"
[ "$(age_human 30)" = "hace 30s" ] || fail "age s"
[ "$(age_human 90)" = "hace 1m" ] || fail "age m"
[ "$(age_human 3700)" = "hace 1h" ] || fail "age h"
[ "$(age_human 200000)" = "hace 2d" ] || fail "age d"
[ "$(age_human -5)" = "hace 0s" ] || fail "age neg"
[ "$(short_path "$HOME")" = "~" ] || fail "home"
home_doc=$(printf '~%s' "/Documents")
[ "$(short_path "$HOME/Documents")" = "$home_doc" ] || fail "sub"
[ "$(short_path /tmp)" = /tmp ] || fail "otro"
name=$(session_name_for claude /tmp)
case $name in
  roster-claude-????????) ;;
  *) fail "session $name" ;;
esac
[ "$(session_name_for claude /tmp)" = "$name" ] || fail "session estable"

sorted=$(printf 'P\t1\tgrok\tttys001\t100\t/tmp\nP\t2\tclaude\tttys002\t10\t/tmp\nC\t2\tbusy\t/tmp\t0\n' | merge_rows | finalize_rows)
first=$(printf '%s\n' "$sorted" | head -n 1)
second=$(printf '%s\n' "$sorted" | tail -n 1)
case $first in
  2$'\t'1$'\t'*) ;;
  *) fail "orden grok primero: $first" ;;
esac
case $second in
  3$'\t'2$'\t'*working*) ;;
  *) fail "claude working: $second" ;;
esac

younger=$(printf 'P\t1\tgrok\tttys001\t100\t/tmp\nP\t2\tgrok\tttys002\t10\t/tmp\n' | merge_rows | finalize_rows | head -n 1)
case $younger in
  2$'\t'2$'\t'*) ;;
  *) fail "mas nuevo primero: $younger" ;;
esac

if "$roster" jump - '' ttys000 claude >/dev/null 2>&1; then
  fail "jump debia fallar"
fi
if "$roster" kill $$ >/dev/null 2>&1; then
  fail "kill debia negarse"
fi
ps -p $$ >/dev/null || fail "el test murio"

uid=$(id -u)
absent=roster-absent-$$
if [ -S "/tmp/tmux-$uid/$absent" ]; then
  fail "el socket de prueba ya existia"
fi
if ROSTER_TMUX_L=$absent "$roster" popup >/dev/null 2>&1; then
  fail "popup sin server debia fallar"
fi
if [ -S "/tmp/tmux-$uid/$absent" ]; then
  tmux -L "$absent" kill-server >/dev/null 2>&1 || true
  fail "popup creo un server"
fi
ROSTER_TMUX_L=$absent "$roster" list --plain >/dev/null
if [ -S "/tmp/tmux-$uid/$absent" ]; then
  tmux -L "$absent" kill-server >/dev/null 2>&1 || true
  fail "list creo un server"
fi

out=$("$roster" list --plain)
printf '%s\n' "$out" | grep -q 'ningún agente vivo' && fail "lista vacia con agentes vivos"
while read -r pid comm _tty _etime; do
  case $comm in
    claude | grok | codex) ;;
    *) continue ;;
  esac
  printf '%s\n' "$out" | grep -q "^$comm " || fail "falta $comm pid $pid"
done < <(ps -ax -o pid=,comm=,tty=,etime=)

claude_status=$(printf '%s\n' "$out" | awk '$1 == "claude" { print $2; exit }')
json_status=$(claude agents --json 2>/dev/null | jq -r 'first(.[] | select(.kind == "interactive") | .status) // empty' || true)
if [ -n "$json_status" ]; then
  [ "$claude_status" = "$(label_status "$json_status")" ] || fail "claude $claude_status != $json_status"
fi
other_status=$(printf '%s\n' "$out" | awk '$1 == "grok" || $1 == "codex" { print $2 }')
while read -r st; do
  [ -n "$st" ] || continue
  [ "$st" = running ] || fail "estado inventado: $st"
done <<<"$other_status"
printf '%s\n' "$out" | grep -q 'sin tmux' || fail "sin tmux"

preview=$("$roster" preview - ttys000)
printf '%s\n' "$preview" | grep -q 'Fuera de tmux' || fail "preview"

sock=roster-test-$$
stub=$(mktemp)
cat >"$stub" <<'EOF'
#!/bin/sh
exec /bin/sleep 120
EOF
chmod +x "$stub"
cleanup() {
  tmux -L "$sock" kill-server >/dev/null 2>&1 || true
  rm -f "$stub"
}
trap cleanup EXIT

session=$(ROSTER_TMUX_L=$sock ROSTER_CMD_claude=$stub "$roster" open claude --dir /tmp --detach)
case $session in
  roster-claude-????????) ;;
  *) fail "open $session" ;;
esac
phys=$(cd /tmp && pwd -P)
[ "$session" = "$(session_name_for claude "$phys")" ] || fail "open hash"
tmux -L "$sock" has-session -t "$session"
start=$(tmux -L "$sock" list-panes -t "$session" -F '#{pane_start_command}')
[ "$start" = "$stub" ] || fail "start=$start"
tty=$(tmux -L "$sock" list-panes -t "$session" -F '#{pane_tty}')
# tmux corre `fish -c <bin>`. El proceso queda en el tty del pane, hijo del shell.
sleeps=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
  sleeps=$(ps -t "${tty#/dev/}" -o comm= | awk '{ n = $1; sub(".*/", "", n); if (n == "sleep") c++ } END { print c + 0 }')
  [ "$sleeps" = 1 ] && break
  sleep 0.2
done
[ "$sleeps" = 1 ] || fail "sleeps=$sleeps"
pid1=$(tmux -L "$sock" list-panes -t "$session" -F '#{pane_pid}')
session2=$(ROSTER_TMUX_L=$sock ROSTER_CMD_claude=$stub "$roster" open claude --dir /tmp --detach)
[ "$session" = "$session2" ] || fail "no reuso"
pid2=$(tmux -L "$sock" list-panes -t "$session" -F '#{pane_pid}')
[ "$pid1" = "$pid2" ] || fail "relanzo el proceso"
sleeps=$(ps -t "${tty#/dev/}" -o comm= | awk '{ n=$1; sub(".*/", "", n); if (n == "sleep") c++ } END { print c + 0 }')
[ "$sleeps" = 1 ] || fail "relanzo sleep=$sleeps"
count=$(tmux -L "$sock" list-sessions | wc -l | tr -d ' ')
[ "$count" = 1 ] || fail "sessions=$count"
cwd=$(tmux -L "$sock" list-panes -t "$session" -F '#{pane_current_path}')
[ "$cwd" = "$phys" ] || fail "cwd=$cwd"

# El server del usuario sigue en el socket default.
tmux has-session -t 0

printf 'OK\n'
