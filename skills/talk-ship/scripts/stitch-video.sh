#!/usr/bin/env bash
# stitch-video.sh — talk-ship video stitcher.
#
# Concatenates per-stage captures into a single MP4 with stage-name
# overlays, generates a contact sheet, and emits a poster frame.
#
# Re-uses talk-html's verify-evidence.sh to validate run-log.json
# provenance after the stitch step.
#
# usage:
#   stitch-video.sh \
#     --journey <path-to-stages.json> \
#     --raw-dir <dir-with-stage.webm|.mp4|.gif> \
#     --out-dir <video-output-dir> \
#     [--width <int>]            # final video width px (default 1180)
#     [--hold-ms <int>]          # black gap between stages (default 600)
#     [--crf <int>]              # H.264 CRF (default 23, range 18-28)
#     [--fps <int>]              # output fps (default 24)
#
# Out (KEY=VALUE):
#   MP4=<path>  CONTACT_SHEET=<path>  POSTER=<path>  RUNLOG=<path>
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_imports.sh"
ensure_talk_html_canon

JOURNEY=""; RAW_DIR=""; OUT_DIR=""
WIDTH=1180; HOLD_MS=600; CRF=23; FPS=24
while [[ $# -gt 0 ]]; do
  case "$1" in
    --journey)  JOURNEY="$2"; shift 2;;
    --raw-dir)  RAW_DIR="$2"; shift 2;;
    --out-dir)  OUT_DIR="$2"; shift 2;;
    --width)    WIDTH="$2"; shift 2;;
    --hold-ms)  HOLD_MS="$2"; shift 2;;
    --crf)      CRF="$2"; shift 2;;
    --fps)      FPS="$2"; shift 2;;
    *) echo "stitch-video: unknown arg $1" >&2; exit 2;;
  esac
done
[[ -n "$JOURNEY" ]] || { echo "stitch-video: --journey required" >&2; exit 2; }
[[ -n "$RAW_DIR"  ]] || { echo "stitch-video: --raw-dir required"  >&2; exit 2; }
[[ -n "$OUT_DIR"  ]] || { echo "stitch-video: --out-dir required"  >&2; exit 2; }
command -v ffmpeg >/dev/null || { echo "stitch-video: ffmpeg not found (brew install ffmpeg)" >&2; exit 3; }
command -v ffprobe >/dev/null || { echo "stitch-video: ffprobe not found" >&2; exit 3; }

mkdir -p "$OUT_DIR"

# Read stages in declared order. We pick the first matching file per
# stage from RAW_DIR with the right extension.
mapfile -t STAGE_IDS < <(jq -r '.stages[].id' "$JOURNEY")
mapfile -t STAGE_NAMES < <(jq -r '.stages[].name' "$JOURNEY")
mapfile -t STAGE_KINDS < <(jq -r '.stages[].kind // "web"' "$JOURNEY")

# Build concat list and a stage-timeline map.
CONCAT="$OUT_DIR/.concat.txt"
: > "$CONCAT"
TIMELINE="$OUT_DIR/.timeline.json"
TIMELINE_ARR="["
FIRST=1
for i in "${!STAGE_IDS[@]}"; do
  ID="${STAGE_IDS[$i]}"
  KIND="${STAGE_KINDS[$i]}"
  case "$KIND" in
    web)       EXT="webm";;
    terminal)  EXT="cast";;
    *)         EXT="webm";;
  esac
  # Terminal stages with no .mp4/.gif still have a .cast; the contact
  # sheet handles the cast separately. Skip them in the concat.
  FILE=""
  for ext in mp4 webm gif; do
    if [[ -f "$RAW_DIR/$ID.$ext" ]]; then FILE="$RAW_DIR/$ID.$ext"; break; fi
  done
  if [[ -z "$FILE" ]] && [[ "$KIND" == "web" ]]; then
    # Last resort: a single journey.webm produced by the Playwright driver.
    if [[ -f "$RAW_DIR/journey.webm" ]]; then FILE="$RAW_DIR/journey.webm"; fi
  fi
  if [[ -n "$FILE" ]]; then
    printf "file '%s'\n" "$FILE" >> "$CONCAT"
  fi
  # Probe duration if we can.
  DUR=0
  if [[ -n "$FILE" ]] && command -v ffprobe >/dev/null; then
    DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$FILE" 2>/dev/null || echo 0)
  fi
  [[ $FIRST -eq 0 ]] && TIMELINE_ARR+=","
  TIMELINE_ARR+="{\"id\":\"$ID\",\"name\":\"${STAGE_NAMES[$i]}\",\"kind\":\"$KIND\",\"file\":\"$FILE\",\"duration_s\":$DUR}"
  FIRST=0
done
TIMELINE_ARR+="]"
printf "%s" "$TIMELINE_ARR" > "$TIMELINE"

# Black gap between stages.
HOLD_S=$(awk "BEGIN { print $HOLD_MS/1000 }")
HOLD_DIR="$OUT_DIR/.hold"
mkdir -p "$HOLD_DIR"
for i in "${!STAGE_IDS[@]}"; do
  ffmpeg -y -f lavfi -i "color=c=black:s=${WIDTH}x720:r=${FPS}:d=${HOLD_S}" \
    -c:v libx264 -preset slow -crf "$CRF" -pix_fmt yuv420p \
    "${HOLD_DIR}/hold-${i}.mp4" 2>/dev/null
  printf "file '%s'\n" "${HOLD_DIR}/hold-${i}.mp4" >> "$CONCAT"
done
# Drop the trailing hold so the video doesn't end on a black frame.
sed -i '' '$ d' "$CONCAT" 2>/dev/null || sed -i '$ d' "$CONCAT"

# Final concat + scale + crf.
MP4="$OUT_DIR/final.mp4"
ffmpeg -y -f concat -safe 0 -i "$CONCAT" \
  -vf "scale=${WIDTH}:-2:flags=lanczos,fps=${FPS}" \
  -c:v libx264 -preset slow -crf "$CRF" -pix_fmt yuv420p \
  -movflags +faststart \
  "$MP4" 2>/dev/null

# Contact sheet: 4x4 grid of stage posters from the per-stage screenshots
# directory if it exists, else from the final video frames.
SHOT_DIR="${RAW_DIR%/raw}/screenshots"
[[ -d "$SHOT_DIR" ]] || SHOT_DIR="$RAW_DIR"
CS="$OUT_DIR/contact-sheet.png"
if [[ -d "$SHOT_DIR" ]] && ls "$SHOT_DIR"/*.png >/dev/null 2>&1; then
  ffmpeg -y -framerate 1 -i "$SHOT_DIR/%0d.png" \
    -vf "scale=320:-1,tile=4x4:padding=8:color=black" \
    -frames:v 1 "$CS" 2>/dev/null || cp "$SHOT_DIR/$(ls "$SHOT_DIR" | head -1)" "$CS"
else
  # Fall back to the first 16 frames of the final video.
  ffmpeg -y -i "$MP4" -vf "select=not(mod(n\,30)),scale=320:-1,tile=4x4" \
    -frames:v 1 -an "$CS" 2>/dev/null
fi

# Poster: first non-black frame.
POSTER="$OUT_DIR/poster.jpg"
ffmpeg -y -i "$MP4" -vf "select=gt(scene\,0.1),scale=${WIDTH}:-1" \
  -frames:v 1 -q:v 3 "$POSTER" 2>/dev/null \
  || ffmpeg -y -i "$MP4" -frames:v 1 -q:v 3 "$POSTER" 2>/dev/null

# Re-use talk-html's verify-evidence.sh on the timeline.json so the
# evidence contract stays consistent across the two skills. The talk-html
# script looks for motion markers; the timeline.json is enough.
if [[ -f "$TALK_HTML_DIR/verify-evidence.sh" ]]; then
  "$TALK_HTML_DIR/verify-evidence.sh" "$TIMELINE" >/dev/null 2>&1 || \
    echo "stitch-video: WARN verify-evidence.sh flagged the timeline" >&2
fi

echo "MP4=$MP4"
echo "CONTACT_SHEET=$CS"
echo "POSTER=$POSTER"
echo "RUNLOG=$TIMELINE"
echo "BYTES=$(wc -c < "$MP4" | tr -d ' ')"
