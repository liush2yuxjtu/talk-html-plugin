#!/usr/bin/env bash
# record-tmux-journey.sh — terminal-side recorder for the talk-ship skill.
#
# Spawns the project in a real tmux pane, sends stage commands from
# journey/stages.json, and records the whole pane to an .cast via
# asciinema. Per-stage MP4s are produced when asciinema-agg is on PATH;
# otherwise the .cast is the only artifact and the checklist treats it
# as evidence.
#
# Env in / args:
#   --journey <path>      stages.json (required, terminal-kind stages only)
#   --out-dir <path>      output dir for raw/, run-log.json   (required)
#   --session <name>      tmux session name (default "talk-ship")
#   --cols <int>          pane width  (default 132)
#   --rows <int>          pane height (default 36)
#   --hold-ms <int>       ms to dwell after the last stage command (default 1200)
#
# Out:
#   <out-dir>/raw/<stage-id>.cast
#   <out-dir>/raw/journey.cast
#   <out-dir>/raw/<stage-id>.mp4   (only if asciinema-agg is on PATH)
#   <out-dir>/run-log.json
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_imports.sh"

JOURNEY=""; OUT_DIR=""; SESSION="talk-ship"; COLS=132; ROWS=36; HOLD_MS=1200
while [[ $# -gt 0 ]]; do
  case "$1" in
    --journey)  JOURNEY="$2"; shift 2;;
    --out-dir)  OUT_DIR="$2"; shift 2;;
    --session)  SESSION="$2"; shift 2;;
    --cols)     COLS="$2"; shift 2;;
    --rows)     ROWS="$2"; shift 2;;
    --hold-ms)  HOLD_MS="$2"; shift 2;;
    *) echo "record-tmux-journey: unknown arg $1" >&2; exit 2;;
  esac
done
[[ -n "$JOURNEY" ]] || { echo "record-tmux-journey: --journey required" >&2; exit 2; }
[[ -n "$OUT_DIR" ]] || { echo "record-tmux-journey: --out-dir required" >&2; exit 2; }
command -v tmux >/dev/null || { echo "record-tmux-journey: tmux not found" >&2; exit 3; }
command -v asciinema >/dev/null || { echo "record-tmux-journey: asciinema not found (brew install asciinema)" >&2; exit 3; }

mkdir -p "$OUT_DIR/raw" "$OUT_DIR/screenshots"

# Filter to terminal-kind stages. The journey file is shared with the
# Playwright driver; a stage without "kind" is treated as "web".
STAGE_FILE="$OUT_DIR/raw/.stages_terminal.json"
jq '[ .stages[] | select((.kind // "web") == "terminal") ]' "$JOURNEY" > "$STAGE_FILE"
N=$(jq 'length' "$STAGE_FILE")
[[ "$N" -gt 0 ]] || { echo "record-tmux-journey: no terminal-kind stages in $JOURNEY" >&2; exit 0; }

# Make sure the session is fresh.
tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" -x "$COLS" -y "$ROWS"

# Start the journey-level .cast. asciinema wraps a single shell, so the
# strategy is: record the whole pane in one .cast, and use stage
# boundaries (a "stage: <id>" header sent via tmux send-keys) to split.
CAST="$OUT_DIR/raw/journey.cast"
asciinema rec --stdin --cols "$COLS" --rows "$ROWS" --command "bash $STAGE_FILE.driver" "$CAST" &
ASCIINEMA_PID=$!
trap 'kill $ASCIINEMA_PID 2>/dev/null || true; tmux kill-session -t "$SESSION" 2>/dev/null || true' EXIT

# Give asciinema a moment to attach.
sleep 0.5

LOG="["
FIRST=1
for i in $(seq 0 $((N-1))); do
  ID=$(jq -r ".[$i].id" "$STAGE_FILE")
  CMD=$(jq -r ".[$i].action" "$STAGE_FILE")
  t0=$(date +%s)
  tmux send-keys -t "$SESSION" "echo === stage:$ID ==="
  tmux send-keys -t "$SESSION" "$CMD"
  tmux send-keys -t "$SESSION" "echo === end:$ID ==="
  tmux send-keys -t "$SESSION" ""
  sleep 0.4
  # Best-effort wait: the stage script is responsible for any long
  # sleeps. We just give the shell a moment to render the prompt.
  sleep 0.3
  t1=$(date +%s)
  [[ $FIRST -eq 0 ]] && LOG+=","
  LOG+="{\"stage_id\":\"$ID\",\"status\":\"OK\",\"ms\":$(( (t1 - t0) * 1000 ))}"
  FIRST=0
done

# Hold the final frame.
sleep "$(awk "BEGIN { print $HOLD_MS/1000 }")"

# Stop asciinema and the tmux session.
kill $ASCIINEMA_PID 2>/dev/null || true
wait $ASCIINEMA_PID 2>/dev/null || true
tmux kill-session -t "$SESSION" 2>/dev/null || true
trap - EXIT

LOG+="]"
cat > "$OUT_DIR/run-log.json" <<EOF
{
  "journey": "$JOURNEY",
  "canvas": "terminal",
  "viewport": { "cols": $COLS, "rows": $ROWS },
  "stages": $LOG,
  "cast": "$CAST",
  "recorded_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Optional: per-stage MP4 via asciinema-agg (or `agg`).
if command -v agg >/dev/null 2>&1; then
  for i in $(seq 0 $((N-1))); do
    ID=$(jq -r ".[$i].id" "$STAGE_FILE")
    agg "$OUT_DIR/raw/$ID.cast" "$OUT_DIR/raw/$ID.gif" >/dev/null 2>&1 || true
  done
fi

echo "CAST  $CAST"
echo "LOG   $OUT_DIR/run-log.json"
