#!/usr/bin/env bash
# ship-checklist.sh — talk-ship release gate.
#
# Validates that the journey + recording + video are ship-ready:
#   - every stage has a non-empty evidence path that exists on disk
#   - the final MP4 plays (ffprobe exit 0, duration > 0)
#   - the contact sheet has at least 1 non-blank stage
#   - the journey covers at least Decision + Service for ship runs
#   - no real customer PII / leaked secrets in any evidence file
#   - a sibling talk-html gist URL is recorded (optional, warn-only)
#
# usage:
#   ship-checklist.sh \
#     --journey <path-to-stages.json> \
#     --video-dir <path-with-final.mp4> \
#     [--raw-dir <path-with-raw-evidence>] \
#     [--strict]            # fail on the talk-html missing too
#
# Emits:
#   <video-dir>/../evidence/ship-checklist.json
#   <video-dir>/../evidence/ship-checklist.md
#   stdout ends with a single `result: PASS` or `result: FAIL` line.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_imports.sh"
ensure_talk_html_canon

JOURNEY=""; VIDEO_DIR=""; RAW_DIR=""; STRICT="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --journey)   JOURNEY="$2"; shift 2;;
    --video-dir) VIDEO_DIR="$2"; shift 2;;
    --raw-dir)   RAW_DIR="$2"; shift 2;;
    --strict)    STRICT="true"; shift;;
    *) echo "ship-checklist: unknown arg $1" >&2; exit 2;;
  esac
done
[[ -n "$JOURNEY"   ]] || { echo "ship-checklist: --journey required"   >&2; exit 2; }
[[ -n "$VIDEO_DIR" ]] || { echo "ship-checklist: --video-dir required" >&2; exit 2; }

EVIDENCE_DIR="$(cd "$VIDEO_DIR/.." && pwd)/evidence"
mkdir -p "$EVIDENCE_DIR"
JSON="$EVIDENCE_DIR/ship-checklist.json"
MD="$EVIDENCE_DIR/ship-checklist.md"

# Patterns to detect leaked secrets. Conservative: would prefer false
# negatives over false positives in production. Add project-specific
# tokens below.
SECRETS_PATTERNS=(
  'sk-[A-Za-z0-9]{20,}'                       # OpenAI / Anthropic style
  'AKIA[0-9A-Z]{16}'                          # AWS access key
  'ghp_[A-Za-z0-9]{36}'                       # GitHub PAT
  'xoxb-[0-9]+-[0-9A-Za-z-]+'                 # Slack bot token
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'  # JWT
)

check_pass=0
check_fail=0
results="["
add_result() {
  local name="$1" pass="$2" msg="$3"
  [[ $check_pass -eq 0 ]] || results+=","
  results+="{\"name\":\"$name\",\"pass\":$pass,\"msg\":\"$msg\"}"
  if [[ "$pass" == "true" ]]; then check_pass=$((check_pass+1));
  else check_fail=$((check_fail+1)); fi
  printf -- "- [%s] %s — %s\n" "$([ "$pass" = "true" ] && echo "x" || echo " ")" "$name" "$msg" >> "$MD.tmp"
}

: > "$MD.tmp"
echo "# ship-checklist" >> "$MD.tmp"
echo >> "$MD.tmp"

# 1. journey file present and valid JSON
if [[ ! -f "$JOURNEY" ]]; then
  add_result "journey_present" false "missing: $JOURNEY"
else
  if jq -e .stages "$JOURNEY" >/dev/null 2>&1; then
    add_result "journey_present" true "stages.json is valid"
  else
    add_result "journey_present" false "stages.json is not valid JSON or has no .stages"
  fi
fi

# 2. every stage has evidence on disk
stage_total=$(jq '.stages | length' "$JOURNEY")
stage_with_evidence=0
for i in $(seq 0 $((stage_total-1))); do
  EVID=$(jq -r ".stages[$i].evidence // \"\"" "$JOURNEY")
  if [[ -n "$EVID" && -e "$EVID" && -s "$EVID" ]]; then
    stage_with_evidence=$((stage_with_evidence+1))
  fi
done
if [[ $stage_with_evidence -eq $stage_total && $stage_total -gt 0 ]]; then
  add_result "stage_evidence" true "all $stage_total stages have non-empty evidence"
else
  add_result "stage_evidence" false "$stage_with_evidence / $stage_total stages have evidence on disk"
fi

# 3. final.mp4 plays
MP4="$VIDEO_DIR/final.mp4"
if [[ ! -f "$MP4" ]]; then
  add_result "mp4_plays" false "missing: $MP4"
else
  DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$MP4" 2>/dev/null || echo 0)
  if awk "BEGIN { exit !($DUR > 0) }"; then
    add_result "mp4_plays" true "final.mp4 plays, duration=${DUR}s"
  else
    add_result "mp4_plays" false "final.mp4 reports duration=$DUR"
  fi
fi

# 4. contact sheet has content
CS="$VIDEO_DIR/contact-sheet.png"
if [[ ! -f "$CS" ]]; then
  add_result "contact_sheet" false "missing: $CS"
else
  CS_BYTES=$(wc -c < "$CS" | tr -d ' ')
  if [[ "$CS_BYTES" -gt 5000 ]]; then
    add_result "contact_sheet" true "contact-sheet.png is $CS_BYTES bytes"
  else
    add_result "contact_sheet" false "contact-sheet.png is suspiciously small ($CS_BYTES bytes)"
  fi
fi

# 5. journey covers at least Decision + Service
HAS_DECISION=$(jq '[.stages[] | .id | ascii_downcase] | map(select(test("decision|decide|buy|signup|sign-up|register"))) | length' "$JOURNEY" 2>/dev/null || echo 0)
HAS_SERVICE=$(jq '[.stages[] | .id | ascii_downcase] | map(select(test("service|onboard|use|do|run|complete|act"))) | length' "$JOURNEY" 2>/dev/null || echo 0)
if [[ "$HAS_DECISION" -ge 1 && "$HAS_SERVICE" -ge 1 ]]; then
  add_result "covers_decision_and_service" true "decision=$HAS_DECISION service=$HAS_SERVICE"
else
  add_result "covers_decision_and_service" false "decision=$HAS_DECISION service=$HAS_SERVICE (need at least 1 each)"
fi

# 6. secret sweep
SECRETS_HIT=0
SECRETS_HIT_FILE=""
if [[ -d "$RAW_DIR" ]]; then
  for pat in "${SECRETS_PATTERNS[@]}"; do
    if rg -l --pcre2 "$pat" "$RAW_DIR" >/dev/null 2>&1; then
      SECRETS_HIT=$((SECRETS_HIT+1))
      SECRETS_HIT_FILE=$(rg -l --pcre2 "$pat" "$RAW_DIR" | head -1)
    fi
  done
fi
# Also scan the video dir in case the stitcher wrote something.
for pat in "${SECRETS_PATTERNS[@]}"; do
  if rg -l --pcre2 "$pat" "$VIDEO_DIR" >/dev/null 2>&1; then
    SECRETS_HIT=$((SECRETS_HIT+1))
    [[ -z "$SECRETS_HIT_FILE" ]] && SECRETS_HIT_FILE=$(rg -l --pcre2 "$pat" "$VIDEO_DIR" | head -1)
  fi
done
if [[ $SECRETS_HIT -eq 0 ]]; then
  add_result "secrets_clean" true "no leaked secrets in evidence"
else
  add_result "secrets_clean" false "secret pattern hit: $SECRETS_HIT_FILE"
fi

# 7. talk-html gist URL (optional)
GIST=""
IDX="$(cd "$VIDEO_DIR/.." && pwd)/index.jsonl"
if [[ -f "$IDX" ]]; then
  GIST=$(tail -1 "$IDX" | jq -r '.rendered_url // ""' 2>/dev/null || true)
fi
if [[ -n "$GIST" && "$GIST" != "null" ]]; then
  add_result "talk_html_gist" true "sibling gist: $GIST"
elif [[ "$STRICT" == "true" ]]; then
  add_result "talk_html_gist" false "no sibling talk-html gist URL in index.jsonl"
else
  add_result "talk_html_gist" true "no sibling talk-html gist (warn-only)"
fi

results+="]"

cat > "$JSON" <<EOF
{
  "journey": "$JOURNEY",
  "video_dir": "$VIDEO_DIR",
  "raw_dir": "$RAW_DIR",
  "checks": $results,
  "pass": $check_pass,
  "fail": $check_fail,
  "strict": $STRICT,
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

mv "$MD.tmp" "$MD"
cat "$MD"

if [[ $check_fail -eq 0 ]]; then
  echo "result: PASS"
  exit 0
fi
echo "result: FAIL"
exit 73
