#!/usr/bin/env bash
# dogfood.sh — talk-html HTML self-audit (and optional auto-fix).
#
# Usage:
#   dogfood.sh <html>           Audit only. Exit 0 on PASS, 1 on any issue.
#   dogfood.sh <html> --fix     Apply safe auto-fixes, then audit.
#
# Contract:
#   - Tools: bash builtins, awk, sed, jq, rg, ffprobe, ffmpeg, head, tail,
#     find, stat. No python3.
#   - Idempotent: running --fix twice in a row does not keep mutating the file.
#   - Safe: never deletes files. Only edits the HTML in place or wraps bad
#     links in HTML comments.
#   - Verbose: every check prints [ok]/[fail] <name> -- <evidence>.
#   - Output is a Markdown report ending with `result: PASS` or
#     `result: FAIL: <N> issues`.
#
# Exit codes:
#   0  PASS
#   1  any issue (audit) or unrecoverable fix (--fix)
#   2  usage / fatal

set -uo pipefail

# ---------------------------------------------------------------- usage ----

usage() {
  cat <<'EOF'
dogfood.sh — talk-html HTML self-audit

Usage:
  dogfood.sh <html>           Audit only. Exit 0 on PASS, 1 on any issue.
  dogfood.sh <html> --fix     Apply safe auto-fixes, then audit.

Idempotent: running --fix twice does not keep mutating the file.
Safe: never deletes files; only edits the HTML in place or wraps bad links
      in HTML comments.
EOF
}

# ---------------------------------------------------------------- args -----

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi

HTML_PATH="$1"
MODE="audit"
if [[ "${2:-}" == "--fix" ]]; then
  MODE="fix"
fi

if [[ ! -f "$HTML_PATH" ]]; then
  echo "FATAL: file not found: $HTML_PATH" >&2
  exit 2
fi

# Resolve to absolute path.
HTML_DIR=$(cd "$(dirname "$HTML_PATH")" && pwd)
HTML_FILE="$HTML_DIR/$(basename "$HTML_PATH")"
HTML_SIZE=$(stat -f%z "$HTML_FILE" 2>/dev/null || stat -c%s "$HTML_FILE")

# ----------------------------------------------------------- report sink --
# Mirror all subsequent stdout into a temp log file, then on success/failure
# write `<dir-of-html>/dogfood-report.md` (overwrite) with a frontmatter
# comment so recall.sh / future greps can locate the latest report.
# Frontmatter keys (in order, JSON shape):
#   html, run_at, result, issue_count, unrepairable
LOG_FILE=$(mktemp -t dogfood.log.XXXXXX)
REPORT_FILE="$HTML_DIR/dogfood-report.md"
# `exec > >(tee "$LOG_FILE")` mirrors stdout to both the terminal (so the
# caller still sees the report in real time) and the temp log file (which
# the report writer reads at the end).
exec > >(tee "$LOG_FILE")

write_report() {
  # Determine pass/fail and the result string.
  local result_str
  if [[ "$ISSUE_COUNT" -eq 0 ]]; then
    result_str="PASS"
  else
    result_str="FAIL"
  fi
  local html_basename run_at
  html_basename=$(basename "$HTML_FILE")
  run_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  # Compose: frontmatter HTML comment + captured log body.
  {
    printf '%s\n' "<!-- talk-html-dogfood {\"html\":\"$html_basename\",\"run_at\":\"$run_at\",\"result\":\"$result_str\",\"issue_count\":$ISSUE_COUNT,\"unrepairable\":$BLOCK_COUNT} -->"
    cat "$LOG_FILE"
  } > "$REPORT_FILE"
  rm -f "$LOG_FILE"
}

# ----------------------------------------------------------- accumulators --

ISSUE_COUNT=0
declare -a ISSUE_LINES=()
record_issue() { ISSUE_LINES+=("$1"); ISSUE_COUNT=$((ISSUE_COUNT+1)); }

# Block accumulators (B4/B5/B6).
# A block is a non-mechanical [fail] that a human must address (re-record).
# Failure modes that qualify:
#   - video[N].exists missing AND path is local (not __remote__/__data__)
#   - video[N].stream missing (ffprobe + ffmpeg both fail to see a stream)
#   - img_dup.* on a path that is the primary evidence for a stage
#   - video[N].duration_zero
BLOCK_COUNT=0
declare -a BLOCK_LINES=()

emit_pass() { echo "[ok]   $1 — $2"; }
emit_fail() { echo "[fail] $1 — $2"; record_issue "$1: $2"; }

# tag_block NAME EVIDENCE — emit a [fail] line tagged with
# `[block: human-re-record]` and also record it for the block summary
# section. Reports both to ISSUE_LINES (so issue counts stay accurate) and
# to BLOCK_LINES (so block summary stays separate).
tag_block() {
  local name="$1" evidence="$2"
  local tagged="$evidence [block: human-re-record]"
  echo "[fail] $name — $tagged"
  record_issue "$name: $tagged"
  BLOCK_LINES+=("$name — $evidence")
  BLOCK_COUNT=$((BLOCK_COUNT+1))
}

# ---------------------------------------------------------------- helpers ---

# attr TAG NAME  ->  value of NAME="..." (double-quoted first, then single)
attr() {
  local tag="$1" name="$2"
  printf '%s' "$tag" | awk -v n="$name" '
    {
      # double-quoted
      q = n "=\""
      p = index($0, q)
      if (p > 0) {
        s = substr($0, p + length(q))
        e = index(s, "\"")
        if (e > 0) { print substr(s, 1, e-1); exit }
      }
      # single-quoted
      q = n "='\''"
      p = index($0, q)
      if (p > 0) {
        s = substr($0, p + length(q))
        e = index(s, "'\''")
        if (e > 0) { print substr(s, 1, e-1); exit }
      }
    }
  '
}

# has_attr TAG NAME  ->  "yes" if NAME is a bare attribute (no =value)
has_attr() {
  local tag="$1" name="$2"
  printf '%s' "$tag" | awk -v n="$name" '
    {
      s = " " $0 " "  # pad so boundary matches at edges
      pat = "(^|[ \t\n/])" n "([ \t\n/>]|$)"
      if (match(s, pat)) { print "yes"; exit }
    }
  '
}

# resolve_path REF  ->  echo absolute local path, or sentinel __remote__:URL,
# or sentinel __data__:PREFIX for data: URIs.
resolve_path() {
  local ref="$1"
  if [[ "$ref" =~ ^https?:// ]]; then
    printf '__remote__:%s' "$ref"; return
  fi
  if [[ "$ref" =~ ^data: ]]; then
    printf '__data__:%s' "${ref:0:60}"; return
  fi
  if [[ "$ref" =~ ^file:// ]]; then
    printf '%s' "${ref#file://}"; return
  fi
  # absolute path -> use as-is
  if [[ "$ref" =~ ^/ ]]; then
    printf '%s' "$ref"; return
  fi
  # relative -> resolve against HTML_DIR
  printf '%s/%s' "$HTML_DIR" "$ref"
}

# probe_media FILE  ->  outputs key=value lines (codec_type, codec_name, w, h, dur)
# Tolerates missing ffprobe by falling back to ffmpeg -i.
probe_media() {
  local f="$1"
  if command -v ffprobe >/dev/null 2>&1; then
    ffprobe -v error \
      -show_entries stream=codec_type,codec_name,width,height,duration \
      -of default=noprint_wrappers=1 \
      "$f" 2>&1 | sed 's/^/p=/' || true
  elif command -v ffmpeg >/dev/null 2>&1; then
    # Crude fallback: parse ffmpeg -i stderr. Extracts codec_type,
    # codec_name, width, height, and duration (as HH:MM:SS.ss string —
    # the dim gate then treats the raw string as a non-zero proxy so
    # A7 surfaces a real check instead of skipping).
    ffmpeg -hide_banner -i "$f" 2>&1 | awk '
      /Duration:/ {
        line = $0
        sub(/.*Duration:[[:space:]]*/, "", line)
        sub(/,.*/, "", line)
        gsub(/^ +| +$/, "", line)
        if (line != "") print "p=duration=" line
      }
      /Stream #/ {
        line = $0
        if (line ~ /Video:/) print "p=codec_type=video"
        if (line ~ /Audio:/) print "p=codec_type=audio"
        if (match(line, /Video:[[:space:]]+[A-Za-z0-9_]+/)) {
          c = substr(line, RSTART, RLENGTH)
          sub(/^Video:[[:space:]]+/, "", c)
          print "p=codec_name=" c
        }
        if (match(line, /[0-9]{2,}x[0-9]{2,}/)) {
          r = substr(line, RSTART, RLENGTH)
          n = split(r, parts, "x")
          if (n == 2) {
            print "p=width=" parts[1]
            print "p=height=" parts[2]
          }
        }
      }
    ' | sed 's/ *$//' || true
  else
    echo "p=__no_probe_tool__"
  fi
}

# ------------------------------------------------------------ tag extractors

# extract_tags TAGNAME  ->  prints one opening tag per line.
# Handles single-line tags robustly (talk-html emits img/video on one line).
extract_tags() {
  local tagname="$1"
  awk -v t="$tagname" '
    {
      line = $0
      idx = 1
      while (1) {
        s = index(substr(line, idx), "<" t)
        if (s == 0) break
        abs = idx + s - 1
        # require whitespace, >, or / after the tag name (avoid <image>, <videoctl>)
        c = substr(line, abs + 1 + length(t), 1)
        if (c != "" && c !~ /[ \t\n\/>]/) {
          idx = abs + 1
          continue
        }
        e = index(substr(line, abs), ">")
        if (e == 0) break
        print substr(line, abs, e)
        idx = abs + e
      }
    }
  ' "$HTML_FILE"
}

# extract_anchors  ->  prints one <a ...> opening tag per line.
extract_anchors() {
  awk '
    {
      line = $0
      idx = 1
      while (1) {
        s = index(substr(line, idx), "<a ")
        if (s == 0) break
        abs = idx + s - 1
        e = index(substr(line, abs), ">")
        if (e == 0) break
        print substr(line, abs, e)
        idx = abs + e
      }
    }
  ' "$HTML_FILE"
}

# extract_data_uris  ->  prints one `attr="data:..."` per line.
extract_data_uris() {
  awk '
    {
      line = $0
      while (match(line, /(src|href)="data:[^"]*"/)) {
        print substr(line, RSTART, RLENGTH)
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$HTML_FILE"
}

# extract_objects  ->  prints one <object ...> opening tag per line.
extract_objects() {
  awk '
    {
      line = $0
      idx = 1
      while (1) {
        s = index(substr(line, idx), "<object")
        if (s == 0) break
        abs = idx + s - 1
        c = substr(line, abs + 1 + length("object"), 1)
        if (c != "" && c !~ /[ \t\n\/>]/) {
          idx = abs + 1
          continue
        }
        e = index(substr(line, abs), ">")
        if (e == 0) break
        print substr(line, abs, e)
        idx = abs + e
      }
    }
  ' "$HTML_FILE"
}

# extract_meta_comment  ->  prints the talk-html-meta JSON line(s).
extract_meta_comment() {
  grep -nE '<!--\s*talk-html-meta\s*\{' "$HTML_FILE" || true
}

# extract_evidence_comment  ->  prints `LINE<TAB>JSON` for each talk-html-evidence comment.
extract_evidence_comment() {
  awk '
    /<!--[[:space:]]*talk-html-evidence[[:space:]]*\{/ {
      # Extract the JSON object up to the closing -->
      line = $0
      # Find the first {
      p = index(line, "{")
      if (p == 0) next
      # Find the matching closing brace (greedy scan)
      depth = 0
      j = p
      while (j <= length(line)) {
        ch = substr(line, j, 1)
        if (ch == "{") depth++
        else if (ch == "}") { depth--; if (depth == 0) break }
        j++
      }
      if (depth == 0 && j <= length(line)) {
        json = substr(line, p, j - p + 1)
        printf "%d\t%s\n", NR, json
      }
    }
  ' "$HTML_FILE"
}

# is_motion_ref PATH  ->  "yes" if path ends in .webm|.mp4|.gif (case insensitive).
is_motion_ref() {
  local p="$1"
  if printf '%s' "$p" | grep -qiE '\.(webm|mp4|gif)$'; then
    echo "yes"
  else
    echo "no"
  fi
}

# find_evidence_for_path PATH  ->  prints "LINE<TAB>JSON" for an evidence
# comment whose `source` ends with PATH, within ±2 lines of any reference.
# Uses grep across the whole file rather than a position-keyed scan.
find_evidence_for_path() {
  local refpath="$1"
  extract_evidence_comment | while IFS=$'\t' read -r ev_line ev_json; do
    [[ -z "$ev_json" ]] && continue
    # Parse `source` from the JSON via jq; tolerate failure.
    local ev_source=""
    if command -v jq >/dev/null 2>&1; then
      ev_source=$(printf '%s' "$ev_json" | jq -r '.source // ""' 2>/dev/null)
    else
      ev_source=$(printf '%s' "$ev_json" \
        | sed -nE 's/.*"source"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')
    fi
    if [[ -z "$ev_source" ]]; then
      printf '%s\t%s\n' "$ev_line" "$ev_json"
      continue
    fi
    # Match: ev_source ends with /refpath, or ev_source == refpath basename,
    # or ev_source basename == refpath basename.
    if [[ "$ev_source" == *"/$refpath" || "$ev_source" == "$refpath" \
       || "$(basename "$ev_source")" == "$(basename "$refpath")" ]]; then
      printf '%s\t%s\n' "$ev_line" "$ev_json"
    fi
  done
}

# is_iso8601 STR  ->  "yes" if STR parses as ISO 8601 (date+time, optional Z/offset).
is_iso8601() {
  local s="$1"
  if [[ -z "$s" ]]; then echo "no"; return; fi
  # Strict-ish: YYYY-MM-DDTHH:MM:SS[.fff][Z|±HH:MM]
  if printf '%s' "$s" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})?$'; then
    echo "yes"
  else
    echo "no"
  fi
}

# ---------------------------------------------------------------- audits ----

audit_video() {
  local tag="$1" idx="$2"
  local src
  src=$(attr "$tag" "src")
  if [[ -z "$src" ]]; then
    emit_fail "video[$idx].src_present" "no src attribute"
    return
  fi
  local resolved
  resolved=$(resolve_path "$src")
  if [[ "$resolved" == __remote__:* ]]; then
    emit_pass "video[$idx].exists" "remote url: $src"
  elif [[ "$resolved" == __data__:* ]]; then
    emit_pass "video[$idx].exists" "data: URI"
  else
    if [[ -f "$resolved" ]]; then
      local size
      size=$(stat -f%z "$resolved" 2>/dev/null || stat -c%s "$resolved" 2>/dev/null)
      # B1: size gate. <1024 bytes is a stub/placeholder video; fail.
      if (( size < 1024 )); then
        emit_fail "video[$idx].too_small" "$size bytes (need > 1024)"
      else
        emit_pass "video[$idx].exists" "$resolved ($size bytes)"
      fi
    else
      # B4: missing local video is a block (no script can recover it).
      tag_block "video[$idx].exists" "missing: $resolved"
    fi
  fi
  # Stream / codec / dimensions (only for local files that exist)
  if [[ "$resolved" != __remote__:* && "$resolved" != __data__:* && -f "$resolved" ]]; then
    local probe
    probe=$(probe_media "$resolved")
    if printf '%s' "$probe" | grep -q 'codec_type=video'; then
      emit_pass "video[$idx].stream" "ffprobe/ffmpeg sees a video stream"
    elif printf '%s' "$probe" | grep -q '__no_probe_tool__'; then
      emit_pass "video[$idx].stream" "skipped (no ffprobe/ffmpeg available)"
    else
      # B4: probe tool ran but found no video stream — re-encode/re-record.
      tag_block "video[$idx].stream" "no video stream detected"
    fi
    if printf '%s' "$probe" | grep -qE 'codec_name=(h264|vp8|vp9|av1)'; then
      emit_pass "video[$idx].codec" "browser-playable codec"
    else
      # Not a fail — many encodings still play. Just info.
      emit_pass "video[$idx].codec" "codec not in h264/vp8/vp9/av1 whitelist (may still play)"
    fi

    # A7: video dimensions + duration non-zero
    # Note: probe lines are formatted as `p=key=value`, so the value is the
    # third `=`-separated field. `awk -F'=' '$2' would yield "key" — use
    # sed to extract the value after the second `=` instead.
    local pw ph pd
    pw=$(printf '%s' "$probe" | sed -nE 's/^p=width=(.*)$/\1/p' | head -n1)
    ph=$(printf '%s' "$probe" | sed -nE 's/^p=height=(.*)$/\1/p' | head -n1)
    pd=$(printf '%s' "$probe" | sed -nE 's/^p=duration=(.*)$/\1/p' | head -n1)
    if [[ -z "$pw" || -z "$ph" || -z "$pd" ]]; then
      emit_pass "video[$idx].dim" "dimensions/duration not probed (skipped)"
    else
      # Trim whitespace
      pw=$(printf '%s' "$pw" | tr -d ' ')
      ph=$(printf '%s' "$ph" | tr -d ' ')
      pd=$(printf '%s' "$pd" | tr -d ' ')
      if [[ "$pw" == "0" || "$ph" == "0" ]]; then
        emit_fail "video[$idx].dim_zero" "width=$pw height=$ph"
      else
        emit_pass "video[$idx].dim" "${pw}x${ph}"
      fi
      if [[ "$pd" == "0" || "$pd" == "0.000000" ]]; then
        # B4: zero-duration video is a block — needs re-recording.
        tag_block "video[$idx].duration_zero" "duration=$pd"
      else
        emit_pass "video[$idx].duration" "${pd}s"
      fi
    fi
  fi

  # A1: poster attribute required for local videos >= 50px (skip remote/data URIs)
  if [[ "$resolved" != __remote__:* && "$resolved" != __data__:* ]]; then
    local poster w h
    poster=$(attr "$tag" "poster")
    w=$(attr "$tag" "width")
    h=$(attr "$tag" "height")
    # Numeric width/height (px); default 0
    local nw=0 nh=0
    [[ "$w" =~ ^[0-9]+$ ]] && nw="$w"
    [[ "$h" =~ ^[0-9]+$ ]] && nh="$h"
    # Skip if either declared dim < 50 (tiny inline).
    if (( nw > 0 && nw < 50 )) || (( nh > 0 && nh < 50 )); then
      emit_pass "video[$idx].poster" "skipped (video < 50px: w=$nw h=$nh)"
    elif [[ -z "$poster" ]]; then
      emit_fail "video[$idx].poster_missing" "no poster= attribute on local <video>"
    else
      emit_pass "video[$idx].poster" "poster=\"$poster\""
    fi
  fi

  # autoplay requires muted + playsinline (browser autoplay policies)
  local has_autoplay has_muted has_playsinline has_controls
  has_autoplay=$(has_attr "$tag" "autoplay")
  has_muted=$(has_attr "$tag" "muted")
  has_playsinline=$(has_attr "$tag" "playsinline")
  has_controls=$(has_attr "$tag" "controls")
  if [[ "$has_autoplay" == "yes" ]]; then
    if [[ "$has_muted" == "yes" && "$has_playsinline" == "yes" ]]; then
      emit_pass "video[$idx].autoplay_safe" "autoplay + muted + playsinline"
    else
      emit_fail "video[$idx].autoplay_safe" "autoplay present but muted=$has_muted playsinline=$has_playsinline (browser will block)"
    fi
  fi
  if [[ "$has_controls" != "yes" ]]; then
    emit_fail "video[$idx].controls" "no controls attribute (user cannot play/pause/seek)"
  fi

  # preload value sanity
  local preload
  preload=$(attr "$tag" "preload")
  if [[ -n "$preload" && ! "$preload" =~ ^(none|metadata|auto)$ ]]; then
    emit_fail "video[$idx].preload" "invalid preload value: '$preload' (expected none|metadata|auto)"
  fi
}

audit_img() {
  local tag="$1" idx="$2"
  local src alt
  src=$(attr "$tag" "src")
  alt=$(attr "$tag" "alt")
  if [[ -z "$src" ]]; then
    emit_fail "img[$idx].src_present" "no src"
    return
  fi
  local resolved
  resolved=$(resolve_path "$src")
  if [[ "$resolved" == __remote__:* ]]; then
    emit_pass "img[$idx].exists" "remote url: $src"
  elif [[ "$resolved" == __data__:* ]]; then
    emit_pass "img[$idx].exists" "data: URI"
  else
    if [[ -f "$resolved" ]]; then
      local size
      size=$(stat -f%z "$resolved" 2>/dev/null || stat -c%s "$resolved" 2>/dev/null)
      # B2: size gate. <200 bytes is a stub/placeholder image; fail.
      if (( size < 200 )); then
        emit_fail "img[$idx].too_small" "$size bytes (need >= 200)"
      else
        emit_pass "img[$idx].exists" "$resolved ($size bytes)"
      fi
    else
      emit_fail "img[$idx].exists" "missing: $resolved"
    fi
  fi

  if [[ -n "$alt" ]]; then
    emit_pass "img[$idx].alt_present" "alt=\"$alt\""
  else
    emit_fail "img[$idx].alt_present" "no alt attribute (a11y violation)"
  fi

  if [[ "$resolved" != __remote__:* && "$resolved" != __data__:* && -f "$resolved" ]]; then
    local probe
    probe=$(probe_media "$resolved")
    if printf '%s' "$probe" | grep -qE '^[pd]?=?.*[0-9]+x[0-9]+'; then
      emit_pass "img[$idx].dimensions" "decoded dimensions present"
    else
      emit_pass "img[$idx].dimensions" "dimensions not probed (or non-image stream)"
    fi
  fi
}

audit_source() {
  local tag="$1" idx="$2"
  local src type
  src=$(attr "$tag" "src")
  type=$(attr "$tag" "type")
  if [[ -n "$src" ]]; then
    local resolved
    resolved=$(resolve_path "$src")
    if [[ -f "$resolved" ]]; then
      emit_pass "source[$idx].exists" "$resolved"
    else
      emit_fail "source[$idx].exists" "missing: $resolved"
    fi
  fi
  if [[ -n "$type" && "$type" =~ ^(video|audio|image)/ ]]; then
    emit_pass "source[$idx].type" "type=\"$type\""
  else
    emit_fail "source[$idx].type" "missing/invalid type: '$type' (expected video|audio|image mime)"
  fi
}

audit_anchor() {
  local tag="$1" idx="$2"
  local href
  href=$(attr "$tag" "href")
  if [[ "$href" =~ ^file:// ]]; then
    emit_fail "a[$idx].file_href" "file:// link does not survive upload/publish: $href"
  fi
}

audit_data_uri() {
  local raw="$1" idx="$2"
  local uri
  uri=$(printf '%s' "$raw" | sed -E 's/^(src|href)="//; s/"$//')
  local len=${#uri}
  if (( len > 102400 )); then
    emit_fail "data_uri[$idx].size" "data: URI is $len bytes (>100KB) — convert to a file"
  else
    emit_pass "data_uri[$idx].size" "$len bytes"
  fi
}

# A2: <object data= type=> — run audit_img semantics (size > 200, alt/aria-label).
audit_object() {
  local tag="$1" idx="$2"
  local data type
  data=$(attr "$tag" "data")
  type=$(attr "$tag" "type")
  if [[ -z "$data" ]]; then
    emit_fail "object[$idx].data_present" "no data attribute"
    return
  fi
  local resolved
  resolved=$(resolve_path "$data")
  if [[ "$resolved" == __remote__:* ]]; then
    emit_pass "object[$idx].exists" "remote url: $data"
    return
  fi
  if [[ "$resolved" == __data__:* ]]; then
    emit_pass "object[$idx].exists" "data: URI"
    return
  fi
  # Local file
  if [[ -f "$resolved" ]]; then
    local size
    size=$(stat -f%z "$resolved" 2>/dev/null || stat -c%s "$resolved" 2>/dev/null)
    # B3: size gate. <200 bytes is a stub/placeholder object; fail.
    if (( size < 200 )); then
      emit_fail "object[$idx].too_small" "$resolved is $size bytes (need >= 200)"
    else
      emit_pass "object[$idx].exists" "$resolved ($size bytes)"
    fi
  else
    emit_fail "object[$idx].exists" "missing: $resolved"
    return
  fi
  # alt-or-aria-label: an <object> has no alt, but it can carry aria-label / aria-labelledby
  # / a <figcaption> / title. Check for any of these.
  local aria_label aria_labelledby title
  aria_label=$(attr "$tag" "aria-label")
  aria_labelledby=$(attr "$tag" "aria-labelledby")
  title=$(attr "$tag" "title")
  if [[ -n "$aria_label" || -n "$aria_labelledby" || -n "$title" ]]; then
    emit_pass "object[$idx].alt_or_aria" "aria-label=\"$aria_label\" title=\"$title\""
  else
    emit_fail "object[$idx].alt_or_aria" \
      "no aria-label / aria-labelledby / title on <object data=$data type=$type> (a11y violation)"
  fi
  # Type must look like a MIME
  if [[ -n "$type" && "$type" =~ ^[a-zA-Z0-9.+-]+/[a-zA-Z0-9.+-]+ ]]; then
    emit_pass "object[$idx].type" "type=\"$type\""
  else
    emit_fail "object[$idx].type" "missing/invalid type: '$type'"
  fi
}

# A3: collect every local image path referenced by <img> OR <object type=image/*>,
# hash each, surface duplicates across DISTINCT paths.
audit_duplicate_frames() {
  # Use a temp file to dedupe path -> hash (bash 3.2 portable, no -A).
  local hashdb
  hashdb=$(mktemp -t dogfood.hashes.XXXXXX)
  trap "rm -f '$hashdb'" RETURN

  # Harvest <img src=>
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    local src
    src=$(attr "$tag" "src")
    [[ -z "$src" ]] && continue
    local resolved
    resolved=$(resolve_path "$src")
    if [[ "$resolved" == __remote__:* || "$resolved" == __data__:* ]]; then
      continue
    fi
    [[ -f "$resolved" ]] || continue
    # Skip if already in db.
    if ! grep -F -x "$resolved" "$hashdb" >/dev/null 2>&1; then
      printf '%s\n' "$resolved" >> "$hashdb"
    fi
  done < <(extract_tags "img")

  # Harvest <object data= type=image/*>
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    local data type
    data=$(attr "$tag" "data")
    type=$(attr "$tag" "type")
    [[ -z "$data" ]] && continue
    if [[ ! "$type" =~ ^image/ ]]; then
      continue
    fi
    local resolved
    resolved=$(resolve_path "$data")
    if [[ "$resolved" == __remote__:* || "$resolved" == __data__:* ]]; then
      continue
    fi
    [[ -f "$resolved" ]] || continue
    if ! grep -F -x "$resolved" "$hashdb" >/dev/null 2>&1; then
      printf '%s\n' "$resolved" >> "$hashdb"
    fi
  done < <(extract_objects)

  # Hash every distinct path and group by hash.
  local groupdb
  groupdb=$(mktemp -t dogfood.groups.XXXXXX)
  trap "rm -f '$hashdb' '$groupdb'" RETURN

  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    local h
    h=$(shasum -a 256 "$p" 2>/dev/null | awk '{print $1}')
    [[ -z "$h" ]] && continue
    local short="${h:0:7}"
    # groupdb format: hash<TAB>short<TAB>path1<TAB>path2...
    local existing
    existing=$(grep -m1 "^${h}	" "$groupdb" 2>/dev/null || true)
    if [[ -z "$existing" ]]; then
      printf '%s\t%s\t%s\n' "$h" "$short" "$p" >> "$groupdb"
    else
      # Check for path duplicates in the existing line.
      if ! printf '%s' "$existing" | tr '\t' '\n' | grep -Fx "$p" >/dev/null 2>&1; then
        printf '%s\t%s\n' "$existing" "$p" >> "$groupdb"
      fi
    fi
  done < "$hashdb"

  # Deduplicate groupdb lines (keep longest match per hash).
  local finaldb
  finaldb=$(mktemp -t dogfood.final.XXXXXX)
  trap "rm -f '$hashdb' '$groupdb' '$finaldb'" RETURN
  while IFS=$'\t' read -r h short p1 rest; do
    [[ -z "$h" ]] && continue
    if grep -m1 "^${h}	" "$finaldb" >/dev/null 2>&1; then
      local line
      line=$(grep -m1 "^${h}	" "$finaldb")
      for q in $p1 $rest; do
        [[ -z "$q" ]] && continue
        if ! printf '%s' "$line" | tr '\t' '\n' | grep -Fx "$q" >/dev/null 2>&1; then
          line="$line	$q"
        fi
      done
      local tmp
      tmp=$(mktemp -t dogfood.final.tmp.XXXXXX)
      awk -v target="${h}	" -v newline="$line" '
        { if (index($0, target) == 1) print newline; else print $0 }
      ' "$finaldb" > "$tmp" && mv "$tmp" "$finaldb"
    else
      printf '%s\t%s\t%s\n' "$h" "$short" "$p1" >> "$finaldb"
    fi
  done < "$groupdb"

  # Emit failures for any hash with 2+ distinct paths.
  local any_dup=0
  while IFS=$'\t' read -r h short p1 rest; do
    [[ -z "$h" ]] && continue
    # Build a list of distinct paths.
    local -a paths=("$p1")
    for q in $rest; do
      [[ -z "$q" ]] && continue
      local dup=0
      for x in "${paths[@]}"; do
        [[ "$x" == "$q" ]] && dup=1
      done
      (( dup == 0 )) && paths+=("$q")
    done
    if (( ${#paths[@]} >= 2 )); then
      any_dup=1
      local joined=""
      for q in "${paths[@]}"; do
        if [[ -z "$joined" ]]; then
          joined="$q"
        else
          joined="$joined, $q"
        fi
      done
      # B4: if any of the duplicate paths is the primary evidence for a
      # stage (has a talk-html-evidence comment whose source matches),
      # this is a non-mechanical failure — a human must re-record one of
      # the stages with a distinct frame.
      local is_primary=0
      for q in "${paths[@]}"; do
        if [[ -n "$(find_evidence_for_path "$(basename "$q")" 2>/dev/null)" ]]; then
          is_primary=1
          break
        fi
      done
      if (( is_primary == 1 )); then
        tag_block "img_dup.$short" "referenced ${#paths[@]} times: $joined"
      else
        emit_fail "img_dup.$short" "referenced ${#paths[@]} times: $joined"
      fi
    fi
  done < "$finaldb"

  if (( any_dup == 0 )); then
    emit_pass "img_dup" "no duplicate local image frames"
  fi
}

# A4: prefers-reduced-motion guard
audit_reduced_motion() {
  # Match a real CSS @media rule with prefers-reduced-motion: require the
  # keyword and an opening brace on the same logical rule. Earlier pattern
  # `@media[^{]*prefers-reduced-motion` false-positived on text like
  # `<code>@media (prefers-reduced-motion)</code>` inside a comment/description.
  # This variant additionally requires a `{` after the keyword (which a
  # genuine `@media (...) {` rule has, a prose mention does not). Tolerates
  # nested CSS braces inside the rule body.
  if command -v rg >/dev/null 2>&1; then
    if rg -q '@media[^{]*prefers-reduced-motion[^{]*\{' "$HTML_FILE"; then
      emit_pass "html.reduced_motion" "@media (prefers-reduced-motion: reduce) CSS rule present"
    else
      emit_fail "html.reduced_motion" "no @media (prefers-reduced-motion: reduce) CSS rule (literal string in prose/comment does not count)"
    fi
  else
    if grep -qE '@media[^{]*prefers-reduced-motion[^{]*\{' "$HTML_FILE"; then
      emit_pass "html.reduced_motion" "@media (prefers-reduced-motion: reduce) CSS rule present"
    else
      emit_fail "html.reduced_motion" "no @media (prefers-reduced-motion: reduce) CSS rule (literal string in prose/comment does not count)"
    fi
  fi
}

# A5: talk-html-meta comment — exactly one, JSON parse, required keys
audit_meta_comment() {
  local hits
  hits=$(extract_meta_comment | wc -l | tr -d ' ')
  if [[ "$hits" -eq 0 ]]; then
    emit_fail "html.meta.present" "no <!-- talk-html-meta {...} --> comment found"
    return
  fi
  if [[ "$hits" -ne 1 ]]; then
    emit_fail "html.meta.count" "found $hits talk-html-meta comments (expected exactly 1)"
    return
  fi
  emit_pass "html.meta.count" "exactly 1 talk-html-meta comment"

  local line json
  line=$(extract_meta_comment | head -n1)
  # Strip the leading "N:..." from grep -n output if present.
  json=$(printf '%s' "$line" | sed -E 's/^[0-9]+://')
  # Extract the JSON object by brace-matching: find first '{' and walk to matching '}'.
  json=$(printf '%s' "$json" | awk '
    {
      line = $0
      p = index(line, "{")
      if (p == 0) next
      depth = 0
      j = p
      out = ""
      while (j <= length(line)) {
        ch = substr(line, j, 1)
        out = out ch
        if (ch == "{") depth++
        else if (ch == "}") { depth--; if (depth == 0) break }
        j++
      }
      print out
    }
  ')
  if [[ -z "$json" ]]; then
    emit_fail "html.meta.parse" "could not extract JSON from meta comment"
    return
  fi

  # Validate via jq (preferred) or python3-free heuristic fallback.
  local session_id prompt_summary template generated_at
  if command -v jq >/dev/null 2>&1; then
    session_id=$(printf '%s' "$json" | jq -r '.session_id // ""' 2>/dev/null)
    prompt_summary=$(printf '%s' "$json" | jq -r '.prompt_summary // ""' 2>/dev/null)
    template=$(printf '%s' "$json" | jq -r '.template // ""' 2>/dev/null)
    generated_at=$(printf '%s' "$json" | jq -r '.generated_at // ""' 2>/dev/null)
  else
    session_id=$(printf '%s' "$json" \
      | sed -nE 's/.*"session_id"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
    prompt_summary=$(printf '%s' "$json" \
      | sed -nE 's/.*"prompt_summary"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
    template=$(printf '%s' "$json" \
      | sed -nE 's/.*"template"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
    generated_at=$(printf '%s' "$json" \
      | sed -nE 's/.*"generated_at"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
  fi

  if [[ -n "$session_id" ]]; then
    emit_pass "html.meta.session_id" "session_id=\"$session_id\""
  else
    emit_fail "html.meta.session_id" "missing or empty"
  fi
  if [[ -n "$prompt_summary" ]]; then
    emit_pass "html.meta.prompt_summary" "prompt_summary length=${#prompt_summary}"
  else
    emit_fail "html.meta.prompt_summary" "missing or empty"
  fi
  case "$template" in
    explainer|recap|status|pitch|letter)
      emit_pass "html.meta.template" "template=\"$template\""
      ;;
    *)
      emit_fail "html.meta.template" "invalid template value: '$template' (expected one of: explainer, recap, status, pitch, letter)"
      ;;
  esac
  local iso
  iso=$(is_iso8601 "$generated_at")
  if [[ "$iso" == "yes" ]]; then
    emit_pass "html.meta.generated_at" "generated_at=\"$generated_at\""
  else
    emit_fail "html.meta.generated_at" "missing or not ISO 8601: '$generated_at'"
  fi
}

# A6: for every motion artifact path, require a talk-html-evidence comment
# within ±2 lines. Parse JSON; require keys cmd, host, source, recorded_at.
audit_evidence_comment() {
  # Build a list of motion refs as "LINE<TAB>PATH" pairs, then validate each.
  # For each ref, look for an evidence comment on any line within ±2 of the ref line.
  # We collect refs first (with line numbers), then run a second pass for evidence lookup.
  local refs_file
  refs_file=$(mktemp -t dogfood.refs.XXXXXX)
  trap "rm -f '$refs_file'" RETURN

  # Helper: find the line number of the first occurrence of "needle" in HTML_FILE.
  find_line() {
    local needle="$1"
    local ln=0
    if command -v rg >/dev/null 2>&1; then
      ln=$(rg -nF "$needle" "$HTML_FILE" 2>/dev/null \
        | head -n1 | awk -F: '{print $1}')
    else
      ln=$(grep -nF "$needle" "$HTML_FILE" 2>/dev/null \
        | head -n1 | awk -F: '{print $1}')
    fi
    [[ -z "$ln" ]] && ln=0
    printf '%s' "$ln"
  }

  # <video src=...> with motion extension
  local tag src resolved kind ref_line
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    src=$(attr "$tag" "src")
    [[ -z "$src" ]] && continue
    if [[ "$(is_motion_ref "$src")" == "yes" ]]; then
      ref_line=$(find_line "$src")
      printf '%s\t%s\n' "$ref_line" "$src" >> "$refs_file"
    fi
  done < <(extract_tags "video")
  # <source src=...> with motion extension
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    src=$(attr "$tag" "src")
    [[ -z "$src" ]] && continue
    if [[ "$(is_motion_ref "$src")" == "yes" ]]; then
      ref_line=$(find_line "$src")
      printf '%s\t%s\n' "$ref_line" "$src" >> "$refs_file"
    fi
  done < <(extract_tags "source")
  # <img src=...> with motion extension
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    src=$(attr "$tag" "src")
    [[ -z "$src" ]] && continue
    if [[ "$(is_motion_ref "$src")" == "yes" ]]; then
      ref_line=$(find_line "$src")
      printf '%s\t%s\n' "$ref_line" "$src" >> "$refs_file"
    fi
  done < <(extract_tags "img")
  # <object data=...> with motion extension
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    local data
    data=$(attr "$tag" "data")
    [[ -z "$data" ]] && continue
    if [[ "$(is_motion_ref "$data")" == "yes" ]]; then
      ref_line=$(find_line "$data")
      printf '%s\t%s\n' "$ref_line" "$data" >> "$refs_file"
    fi
  done < <(extract_objects)

  if [[ ! -s "$refs_file" ]]; then
    emit_pass "evidence.coverage" "no motion artifacts referenced; nothing to verify"
    return
  fi

  # Pre-load evidence comment lines (LINE<TAB>JSON) into a temp file.
  local ev_file
  ev_file=$(mktemp -t dogfood.ev.XXXXXX)
  trap "rm -f '$refs_file' '$ev_file'" RETURN
  extract_evidence_comment > "$ev_file"

  local any_fail=0
  while IFS=$'\t' read -r ref_line path; do
    [[ -z "$path" ]] && continue
    # Find an evidence comment within ±2 lines of ref_line.
    local ev_line ev_json
    ev_line=""
    ev_json=""
    if (( ref_line > 0 )); then
      while IFS=$'\t' read -r l j; do
        [[ -z "$l" ]] && continue
        local dist=$(( l - ref_line ))
        (( dist < 0 )) && dist=$(( -dist ))
        if (( dist <= 2 )); then
          ev_line="$l"
          ev_json="$j"
          break
        fi
      done < "$ev_file"
    else
      # No ref line known — fall back to "any evidence comment" so a missing
      # tag location doesn't accidentally hide a present comment. (We still
      # flag it via evidence.missing if no comment is found at all.)
      local first_l first_j
      first_l=$(head -n1 "$ev_file" | awk -F'\t' '{print $1}')
      first_j=$(head -n1 "$ev_file" | awk -F'\t' '{$1=""; sub(/^\t/,""); print}')
      if [[ -n "$first_l" ]]; then
        ev_line="$first_l"
        ev_json="$first_j"
      fi
    fi

    if [[ -z "$ev_json" ]]; then
      any_fail=1
      emit_fail "evidence.missing" "$path (no talk-html-evidence comment within ±2 lines of ref line $ref_line)"
      continue
    fi

    # Validate the JSON fields.
    local cmd host source recorded_at
    if command -v jq >/dev/null 2>&1; then
      cmd=$(printf '%s' "$ev_json" | jq -r '.cmd // ""' 2>/dev/null)
      host=$(printf '%s' "$ev_json" | jq -r '.host // ""' 2>/dev/null)
      source=$(printf '%s' "$ev_json" | jq -r '.source // ""' 2>/dev/null)
      recorded_at=$(printf '%s' "$ev_json" | jq -r '.recorded_at // ""' 2>/dev/null)
    else
      cmd=$(printf '%s' "$ev_json" \
        | sed -nE 's/.*"cmd"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
      host=$(printf '%s' "$ev_json" \
        | sed -nE 's/.*"host"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
      source=$(printf '%s' "$ev_json" \
        | sed -nE 's/.*"source"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
      recorded_at=$(printf '%s' "$ev_json" \
        | sed -nE 's/.*"recorded_at"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
    fi

    local ev_invalid=0
    local reason=""
    if [[ -z "$cmd" ]]; then
      ev_invalid=1; reason="$reason cmd=missing"
    fi
    if [[ -z "$host" ]]; then
      ev_invalid=1; reason="$reason host=missing"
    fi
    if [[ -z "$source" ]]; then
      ev_invalid=1; reason="$reason source=missing"
    fi
    if [[ -z "$recorded_at" || "$(is_iso8601 "$recorded_at")" == "no" ]]; then
      ev_invalid=1; reason="$reason recorded_at=missing_or_not_iso8601"
    fi
    if (( ev_invalid == 1 )); then
      any_fail=1
      emit_fail "evidence.invalid" "$path:$reason"
    else
      emit_pass "evidence.comment" "$path (evidence at line $ev_line, source=\"$source\")"
    fi
  done < "$refs_file"

  : $((any_fail))  # referenced to avoid "set but unused" lint
}

audit_html_meta() {
  if grep -qiE '<html[^>]+lang=' "$HTML_FILE"; then
    local lang
    lang=$(grep -oiE '<html[^>]+lang="[^"]+"' "$HTML_FILE" | head -n1 \
      | sed -E 's/.*lang="([^"]+)".*/\1/')
    emit_pass "html.lang" "lang=\"$lang\""
  else
    emit_fail "html.lang" "no lang attribute on <html>"
  fi
  if grep -qiE '<meta[^>]+charset=' "$HTML_FILE"; then
    emit_pass "html.charset" "charset declared"
  else
    emit_fail "html.charset" "no <meta charset>"
  fi
  if grep -qiE '<meta[^>]+name="viewport"' "$HTML_FILE"; then
    emit_pass "html.viewport" "viewport meta present"
  else
    emit_fail "html.viewport" "no <meta name=viewport>"
  fi
  local title
  title=$(awk -v IGNORECASE=1 '/<title>/{gsub(/<\/?title>/,""); print; exit}' "$HTML_FILE")
  if [[ -n "$title" ]]; then
    emit_pass "html.title" "title=\"$title\""
  else
    emit_fail "html.title" "no <title> element"
  fi
}

# ---------------------------------------------------------------- fixes ----

# Sed escape helpers. Delimiter is `|`. Pattern side must escape the BRE
# metachars: \ | . * [ ^ $. Replacement side must escape: \ & |.
sed_esc_pat() { printf '%s' "$1" | sed 's/[\\|.*^$[]/\\&/g'; }
sed_esc_rep() { printf '%s' "$1" | sed 's/[\\&|]/\\&/g'; }

# apply_fixes — safe, idempotent in-place mutations.
# Each fix is guarded by a "second run is a no-op" predicate. A per-fix
# md5/size snapshot drives the per-fix banner. End-of-run summary counts
# changed vs idempotent runs.
apply_fixes() {
  # Counters for the summary line. Global to the function (no `local -i`
  # in POSIX sh mode; we are in bash 3.2 on macOS so this is fine).
  fix_changed=0
  fix_idempotent=0

  # Snapshot helpers.
  snap_md5()  { md5 -q "$HTML_FILE" 2>/dev/null || md5sum "$HTML_FILE" | awk '{print $1}'; }
  snap_size() { stat -f%z "$HTML_FILE" 2>/dev/null || stat -c%s "$HTML_FILE"; }

  # emit_fix_banner N NAME MD5_BEFORE MD5_AFTER SIZE_BEFORE SIZE_AFTER MUTATIONS
  emit_fix_banner() {
    local n="$1" name="$2" b="$3" a="$4" sb="$5" sa="$6" mut="$7"
    if [[ "$b" == "$a" ]]; then
      echo "[fix $n] $name — no-change"
      fix_idempotent=$((fix_idempotent + 1))
    else
      local delta=$(( sa - sb ))
      echo "[fix $n] $name — changed: $delta bytes, +$mut attrs"
      fix_changed=$((fix_changed + 1))
    fi
  }

  # Helper: write a count file from awk (BSD awk has no good way to bubble
  # a counter back to the parent shell except via a side file).
  read_count() {
    local f="$1"
    if [[ -f "$f" ]]; then
      cat "$f"
      rm -f "$f"
    else
      echo 0
    fi
  }

  # ---- Fix 1: <img ...> without alt= gets alt="" inserted before the close.
  local mut1=0 md5_b md5_a sb sa
  md5_b=$(snap_md5); sb=$(snap_size)
  awk -v cnt_file="$HTML_FILE.fix1.cnt" '
    {
      line = $0
      out = ""
      idx = 1
      while ((p = index(substr(line, idx), "<img")) > 0) {
        abs = idx + p - 1
        end = index(substr(line, abs), ">")
        if (end == 0) { out = out substr(line, idx); break }
        tag = substr(line, abs, end)
        # Idempotency: skip if tag already contains alt= anywhere.
        if (index(tag, "alt=") == 0) {
          newtag = substr(tag, 1, length(tag)-1) " alt=\"\">"
          out = out substr(line, idx, abs-1) newtag
          cnt++
        } else {
          out = out substr(line, idx, abs-1+end)
        }
        idx = abs + end
      }
      if (idx <= length(line)) out = out substr(line, idx)
      print out
    }
    END { print cnt+0 > cnt_file }
  ' "$HTML_FILE" > "$HTML_FILE.tmp" && mv "$HTML_FILE.tmp" "$HTML_FILE"
  mut1=$(read_count "$HTML_FILE.fix1.cnt")
  md5_a=$(snap_md5); sa=$(snap_size)
  emit_fix_banner 1 "img-alt-insert" "$md5_b" "$md5_a" "$sb" "$sa" "$mut1"

  # ---- Fix 2: <video autoplay> without muted / playsinline gets them.
  local mut2=0
  md5_b=$(snap_md5); sb=$(snap_size)
  awk -v cnt_file="$HTML_FILE.fix2.cnt" '
    {
      line = $0
      out = ""
      idx = 1
      while ((p = index(substr(line, idx), "<video")) > 0) {
        abs = idx + p - 1
        end = index(substr(line, abs), ">")
        if (end == 0) { out = out substr(line, idx); break }
        tag = substr(line, abs, end)
        newtag = tag
        # Detect autoplay (bare attribute).
        is_autoplay = 0
        if (match(" "tag" ", /(^|[ \t\n])autoplay([ \t\n\/>]|$)/)) is_autoplay = 1
        if (is_autoplay) {
          if (index(" "newtag" ", " muted ") == 0 && index(" "newtag" ", " muted>") == 0 && index(" "newtag" ", " muted/>") == 0) {
            newtag = substr(newtag, 1, length(newtag)-1) " muted"
            cnt++
          }
          if (index(" "newtag" ", " playsinline ") == 0 && index(" "newtag" ", " playsinline>") == 0 && index(" "newtag" ", " playsinline/>") == 0) {
            newtag = substr(newtag, 1, length(newtag)-1) " playsinline"
            cnt++
          }
        }
        out = out substr(line, idx, abs-1) newtag
        idx = abs + end
      }
      if (idx <= length(line)) out = out substr(line, idx)
      print out
    }
    END { print cnt+0 > cnt_file }
  ' "$HTML_FILE" > "$HTML_FILE.tmp" && mv "$HTML_FILE.tmp" "$HTML_FILE"
  mut2=$(read_count "$HTML_FILE.fix2.cnt")
  md5_a=$(snap_md5); sa=$(snap_size)
  emit_fix_banner 2 "video-autoplay-safe" "$md5_b" "$md5_a" "$sb" "$sa" "$mut2"

  # ---- Fix 3: Wrap <a href="file://...">...</a> in an HTML comment.
  # Operates on the whole file as a single buffer. Idempotent: if the
  # immediate surrounding text already contains our marker, skip.
  local mut3=0
  md5_b=$(snap_md5); sb=$(snap_size)
  awk -v cnt_file="$HTML_FILE.fix3.cnt" '
    {
      buf = buf $0 "\n"
    }
    END {
      out = buf
      s = 1
      while (1) {
        a = index(substr(out, s), "<a ")
        if (a == 0) break
        a = s + a - 1
        # Find end of opening tag
        e = a
        while (e <= length(out) && substr(out, e, 1) != ">") e++
        if (e > length(out)) break
        opentag = substr(out, a, e - a + 1)
        if (opentag !~ /href="file:\/\//) { s = e + 1; continue }
        # Idempotency: look behind for our opening marker.
        prefix = substr(out, 1, a-1)
        last_open = 0
        scan = 1
        while (1) {
          k = index(substr(prefix, scan), "<!--DOGFOOD: file:// link commented out:")
          if (k == 0) break
          last_open = scan + k - 1
          scan = scan + k + 50
        }
        if (last_open > 0) {
          # See if a matching --> exists between last_open and a.
          between = substr(out, last_open, a - last_open)
          if (index(between, "-->") > 0) { s = e + 1; continue }
        }
        # Find matching </a>
        depth = 1
        p = e + 1
        end_a = 0
        while (p <= length(out)) {
          rest = substr(out, p)
          no = index(rest, "<a ")
          nc = index(rest, "</a>")
          if (nc == 0) break
          no_abs = (no > 0) ? p + no - 1 : -1
          nc_abs = p + nc - 1
          if (no > 0 && no_abs < nc_abs) {
            depth++
            p = no_abs + 3
          } else {
            depth--
            if (depth == 0) { end_a = nc_abs + 3; break }
            p = nc_abs + 4
          }
        }
        if (end_a == 0) break
        block = substr(out, a, end_a - a)
        new = "<!--DOGFOOD: file:// link commented out: " block " /DOGFOOD-->"
        out = substr(out, 1, a - 1) new substr(out, end_a)
        s = a + length(new)
        cnt++
      }
      printf "%s", out
      print cnt+0 > cnt_file
    }
  ' "$HTML_FILE" > "$HTML_FILE.tmp" && mv "$HTML_FILE.tmp" "$HTML_FILE"
  mut3=$(read_count "$HTML_FILE.fix3.cnt")
  md5_a=$(snap_md5); sa=$(snap_size)
  emit_fix_banner 3 "anchor-file-wrap" "$md5_b" "$md5_a" "$sb" "$sa" "$mut3"

  # ---- Fix 4: <video> poster injection from sibling file.
  # For each <video> without poster, look for a sibling file with the same
  # stem but a static-image extension (.jpg/.jpeg/.png/.webp). If found,
  # inject `poster="<basename>"` into the tag. Idempotent: skip if the
  # tag already contains poster=.
  local mut4=0
  md5_b=$(snap_md5); sb=$(snap_size)
  declare -a fix4_subs=()
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    # Idempotency: skip if poster= already present anywhere in the tag.
    if printf '%s' "$tag" | grep -q 'poster='; then
      continue
    fi
    local src
    src=$(attr "$tag" "src")
    [[ -z "$src" ]] && continue
    local resolved
    resolved=$(resolve_path "$src")
    # Skip remote / data: URIs (audit handles them differently).
    [[ "$resolved" == __remote__:* || "$resolved" == __data__:* ]] && continue
    # Skip missing videos (Fix 6 wraps them with a marker; don't try to
    # add a poster to a video that doesn't exist).
    [[ -f "$resolved" ]] || continue
    local src_basename src_dir stem
    src_basename=$(basename "$src")
    src_dir=$(dirname "$src")
    stem="${src_basename%.*}"
    local found_poster=""
    for ext in jpg jpeg png webp JPG JPEG PNG WEBP; do
      local candidate="$src_dir/$stem.$ext"
      local cand_resolved
      cand_resolved=$(resolve_path "$candidate")
      if [[ -f "$cand_resolved" ]]; then
        found_poster="$stem.$ext"
        break
      fi
    done
    [[ -z "$found_poster" ]] && continue
    # Inject poster="<basename>" just before the closing > of the opening tag.
    local newtag
    newtag="${tag%>} poster=\"$found_poster\">"
    local esc_pat esc_rep
    esc_pat=$(sed_esc_pat "$tag")
    esc_rep=$(sed_esc_rep "$newtag")
    fix4_subs+=("s|${esc_pat}|${esc_rep}|")
    mut4=$((mut4 + 1))
  done < <(extract_tags "video")
  if (( ${#fix4_subs[@]} > 0 )); then
    sed "${fix4_subs[@]}" "$HTML_FILE" > "$HTML_FILE.tmp" && mv "$HTML_FILE.tmp" "$HTML_FILE"
  fi
  md5_a=$(snap_md5); sa=$(snap_size)
  emit_fix_banner 4 "video-poster-injection" "$md5_b" "$md5_a" "$sb" "$sa" "$mut4"

  # ---- Fix 5: evidence comment repair for motion artifacts.
  # For each motion artifact (<video src>, <source src>, <img src=.webm|.mp4|.gif>,
  # <object data=.webm|.mp4|.gif>) that does NOT have a
  # `<!-- talk-html-evidence {…} -->` within ±2 lines, insert a stub
  # immediately before the tag. Idempotent: scan ±2 lines; if a
  # talk-html-evidence comment exists, skip.
  local mut5=0
  md5_b=$(snap_md5); sb=$(snap_size)
  # Pre-collect line numbers of existing talk-html-evidence comments.
  local ev_lines_file
  ev_lines_file=$(mktemp -t dogfood.evlines.XXXXXX)
  awk '/<!--[[:space:]]*talk-html-evidence[[:space:]]*\{/{print NR}' \
    "$HTML_FILE" > "$ev_lines_file" 2>/dev/null
  local hostname_val iso_now
  hostname_val=$(hostname 2>/dev/null || echo "unknown")
  iso_now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  awk \
    -v evf="$ev_lines_file" \
    -v host="$hostname_val" \
    -v iso="$iso_now" \
    -v cnt_file="$HTML_FILE.fix5.cnt" '
    BEGIN {
      # BWK awk on macOS mis-parses regex LITERALS that contain "<" (e.g.
      # /<video/) — they end up matching a stray byte. Pass the patterns
      # as string variables instead so the regex engine gets the real text.
      re_video  = "<video[[:space:]]+[^>]*src=\"[^\"]*\\.(webm|mp4|gif)\""
      re_source = "<source[[:space:]]+[^>]*src=\"[^\"]*\\.(webm|mp4|gif)\""
      re_img    = "<img[[:space:]]+[^>]*src=\"[^\"]*\\.(webm|mp4|gif)\""
      re_object = "<object[[:space:]]+[^>]*data=\"[^\"]*\\.(webm|mp4|gif)\""
      re_src    = "src=\"[^\"]*\""
      re_data   = "data=\"[^\"]*\""
      while ((getline ln < evf) > 0) {
        ev_lines[ln] = 1
      }
      close(evf)
    }
    {
      line = $0
      do_insert = 0
      src_for_stub = ""

      m_video  = match(line, re_video)
      m_source = match(line, re_source)
      m_img    = match(line, re_img)
      m_object = match(line, re_object)

      if (m_video || m_source || m_img) {
        if (match(line, re_src)) {
          src_for_stub = substr(line, RSTART+5, RLENGTH-6)
        }
        has_ev = 0
        for (i = NR-2; i <= NR+2; i++) {
          if (i in ev_lines) { has_ev = 1; break }
        }
        if (!has_ev) do_insert = 1
      } else if (m_object) {
        if (match(line, re_data)) {
          src_for_stub = substr(line, RSTART+6, RLENGTH-7)
        }
        has_ev = 0
        for (i = NR-2; i <= NR+2; i++) {
          if (i in ev_lines) { has_ev = 1; break }
        }
        if (!has_ev) do_insert = 1
      }

      if (do_insert) {
        printf "<!-- talk-html-evidence {\"cmd\":\"unrecorded\",\"host\":\"%s\",\"source\":\"%s\",\"recorded_at\":\"%s\"} -->\n", host, src_for_stub, iso
        cnt++
      }
      print
    }
    END { print cnt+0 > cnt_file }
  ' "$HTML_FILE" > "$HTML_FILE.tmp" && mv "$HTML_FILE.tmp" "$HTML_FILE"
  mut5=$(read_count "$HTML_FILE.fix5.cnt")
  rm -f "$ev_lines_file"
  md5_a=$(snap_md5); sa=$(snap_size)
  emit_fix_banner 5 "evidence-stub-repair" "$md5_b" "$md5_a" "$sb" "$sa" "$mut5"

  # ---- Fix 6: wrap missing local media with DOGFOOD evidence-gap marker.
  # For each <video> / <img> / <object> whose exists check failed AND the
  # path is local, do NOT delete the tag. Instead prepend a
  # `<!-- DOGFOOD: missing-media evidence gap: <path> /DOGFOOD-->`
  # comment so the human can grep. The audit on the next pass will still
  # see the underlying tag and report `[block: human-re-record]` for the
  # same path — this just makes the gap visible in the HTML itself.
  # Idempotent: skip if a marker for this path is already present.
  # BSD-sed-safe: the prior version embedded a literal newline in the
  # sed replacement (`s|pat|rep\npat|`), which BSD sed on macOS rejects
  # with "unescaped newline inside substitute pattern". Use awk to do
  # the line injection. Side-file template mirrors Fix 5: build a
  # "<tag><TAB><marker>" pair list, then a single awk pass that, for
  # every line containing a known broken tag, prints the marker line
  # followed by the original line (`print "<marker>\n" $0; next` rule).
  local mut6=0
  md5_b=$(snap_md5); sb=$(snap_size)
  # Side file: one line per missing media, "<tag><TAB><marker>".
  local fix6_pairs
  fix6_pairs=$(mktemp -t dogfood.fix6.pairs.XXXXXX)
  trap "rm -f '$fix6_pairs'" RETURN
  # <video src=…>
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    local src resolved
    src=$(attr "$tag" "src")
    [[ -z "$src" ]] && continue
    resolved=$(resolve_path "$src")
    [[ "$resolved" == __remote__:* || "$resolved" == __data__:* ]] && continue
    [[ -f "$resolved" ]] && continue
    if grep -qF "DOGFOOD: missing-media evidence gap: $src" "$HTML_FILE"; then
      continue
    fi
    local marker="<!-- DOGFOOD: missing-media evidence gap: $src /DOGFOOD-->"
    printf '%s\t%s\n' "$tag" "$marker" >> "$fix6_pairs"
  done < <(extract_tags "video")
  # <img src=…>
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    local src resolved
    src=$(attr "$tag" "src")
    [[ -z "$src" ]] && continue
    resolved=$(resolve_path "$src")
    [[ "$resolved" == __remote__:* || "$resolved" == __data__:* ]] && continue
    [[ -f "$resolved" ]] && continue
    if grep -qF "DOGFOOD: missing-media evidence gap: $src" "$HTML_FILE"; then
      continue
    fi
    local marker="<!-- DOGFOOD: missing-media evidence gap: $src /DOGFOOD-->"
    printf '%s\t%s\n' "$tag" "$marker" >> "$fix6_pairs"
  done < <(extract_tags "img")
  # <object data=…>
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    local data resolved
    data=$(attr "$tag" "data")
    [[ -z "$data" ]] && continue
    resolved=$(resolve_path "$data")
    [[ "$resolved" == __remote__:* || "$resolved" == __data__:* ]] && continue
    [[ -f "$resolved" ]] && continue
    if grep -qF "DOGFOOD: missing-media evidence gap: $data" "$HTML_FILE"; then
      continue
    fi
    local marker="<!-- DOGFOOD: missing-media evidence gap: $data /DOGFOOD-->"
    printf '%s\t%s\n' "$tag" "$marker" >> "$fix6_pairs"
  done < <(extract_objects)
  if [[ -s "$fix6_pairs" ]]; then
    awk \
      -v pairs_file="$fix6_pairs" \
      -v cnt_file="$HTML_FILE.fix6.cnt" '
      BEGIN {
        n = 0
        while ((getline pair < pairs_file) > 0) {
          p = index(pair, "\t")
          if (p == 0) continue
          n++
          tags[n] = substr(pair, 1, p-1)
          markers[n] = substr(pair, p+1)
        }
        close(pairs_file)
      }
      {
        line = $0
        injected = 0
        for (i = 1; i <= n; i++) {
          p = index(line, tags[i])
          if (p > 0) {
            line = substr(line, 1, p-1) markers[i] "\n" substr(line, p)
            injected = 1
          }
        }
        if (injected) cnt++
        print line
      }
      END { print cnt+0 > cnt_file }
    ' "$HTML_FILE" > "$HTML_FILE.tmp" && mv "$HTML_FILE.tmp" "$HTML_FILE"
  fi
  mut6=$(read_count "$HTML_FILE.fix6.cnt")
  rm -f "$fix6_pairs"
  md5_a=$(snap_md5); sa=$(snap_size)
  emit_fix_banner 6 "missing-media-wrap" "$md5_b" "$md5_a" "$sb" "$sa" "$mut6"

  # ---- Fix 7: <video> without `controls` gets ` controls` injected.
  # Mirror Fix 2 (autoplay-safe) style — awk pass over the file, splice
  # ` controls` before the closing `>` of the opening tag. Idempotency:
  # `index(tag, "controls") != 0` → already has it, skip. Use awk
  # pattern variables, NOT sed literal-newline.
  local mut7=0
  md5_b=$(snap_md5); sb=$(snap_size)
  awk -v cnt_file="$HTML_FILE.fix7.cnt" '
    {
      line = $0
      out = ""
      idx = 1
      while ((p = index(substr(line, idx), "<video")) > 0) {
        abs = idx + p - 1
        end = index(substr(line, abs), ">")
        if (end == 0) { out = out substr(line, idx); break }
        tag = substr(line, abs, end)
        if (index(tag, "controls") == 0) {
          newtag = substr(tag, 1, length(tag)-1) " controls>"
          out = out substr(line, idx, abs-1) newtag
          cnt++
        } else {
          out = out substr(line, idx, abs-1+end)
        }
        idx = abs + end
      }
      if (idx <= length(line)) out = out substr(line, idx)
      print out
    }
    END { print cnt+0 > cnt_file }
  ' "$HTML_FILE" > "$HTML_FILE.tmp" && mv "$HTML_FILE.tmp" "$HTML_FILE"
  mut7=$(read_count "$HTML_FILE.fix7.cnt")
  md5_a=$(snap_md5); sa=$(snap_size)
  emit_fix_banner 7 "video-controls-inject" "$md5_b" "$md5_a" "$sb" "$sa" "$mut7"

  # Summary
  echo "[fix summary] applied $fix_changed changed, $fix_idempotent idempotent"
}

# --------------------------------------------------------------- driver ----

echo "# dogfood audit"
echo
echo "- file: \`$HTML_FILE\`"
echo "- mode: $MODE"
echo "- size: $HTML_SIZE bytes"
echo

if [[ "$MODE" == "fix" ]]; then
  echo "## auto-fix pass"
  apply_fixes
  echo
  # Re-read size after fixes
  HTML_SIZE=$(stat -f%z "$HTML_FILE" 2>/dev/null || stat -c%s "$HTML_FILE")
fi

echo "## page-level checks"
audit_html_meta
echo
echo "### reduced-motion guard"
audit_reduced_motion
echo
echo "### talk-html-meta comment"
audit_meta_comment

echo
echo "## media checks"

echo
echo "### <video>"
i=0
while IFS= read -r tag; do
  [[ -z "$tag" ]] && continue
  i=$((i+1))
  audit_video "$tag" "$i"
done < <(extract_tags "video")

echo
echo "### <img>"
i=0
while IFS= read -r tag; do
  [[ -z "$tag" ]] && continue
  i=$((i+1))
  audit_img "$tag" "$i"
done < <(extract_tags "img")

echo
echo "### <object>"
i=0
while IFS= read -r tag; do
  [[ -z "$tag" ]] && continue
  i=$((i+1))
  audit_object "$tag" "$i"
done < <(extract_objects)

echo
echo "### <source>"
i=0
while IFS= read -r tag; do
  [[ -z "$tag" ]] && continue
  i=$((i+1))
  audit_source "$tag" "$i"
done < <(extract_tags "source")

echo
echo "### <a href=\"file://\">"
i=0
while IFS= read -r tag; do
  [[ -z "$tag" ]] && continue
  href=$(attr "$tag" "href")
  if [[ "$href" =~ ^file:// ]]; then
    i=$((i+1))
    audit_anchor "$tag" "$i"
  fi
done < <(extract_anchors)

echo
echo "### data: URIs"
i=0
while IFS= read -r raw; do
  [[ -z "$raw" ]] && continue
  i=$((i+1))
  audit_data_uri "$raw" "$i"
done < <(extract_data_uris)

echo
echo "## duplicate frames"
audit_duplicate_frames

echo
echo "## evidence comments"
audit_evidence_comment

echo
if [[ $ISSUE_COUNT -eq 0 ]]; then
  # B5: print an (empty) block summary even on PASS so consumers can
  # always grep for the section.
  echo "## block summary"
  echo
  echo "(none)"
  echo
  echo "## summary"
  echo
  echo "result: PASS"
  write_report
  exit 0
else
  echo "## issues"
  echo
  for line in "${ISSUE_LINES[@]}"; do
    echo "- $line"
  done
  echo
  # B5: dedicated section listing each [block: human-re-record] issue on
  # its own line so a human can grep without parsing the issues block.
  echo "## block summary"
  echo
  if (( BLOCK_COUNT == 0 )); then
    echo "(none)"
  else
    for line in "${BLOCK_LINES[@]}"; do
      echo "- $line [block: human-re-record]"
    done
  fi
  echo
  echo "## summary"
  echo
  # B6: if there is at least one block, the summary spells out how many
  # need human re-recording.
  if (( BLOCK_COUNT > 0 )); then
    echo "result: FAIL: $ISSUE_COUNT issues, $BLOCK_COUNT need human re-record"
  else
    echo "result: FAIL: $ISSUE_COUNT issues"
  fi
  write_report
  exit 1
fi
