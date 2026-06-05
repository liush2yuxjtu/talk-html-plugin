#!/usr/bin/env bash
# verify-evidence.sh — minimal stub for talk-ship smoke test.
#
# The real implementation (run-log.json provenance check, screenshot
# size, duration, etc.) is being authored separately. This stub lets
# ship-checklist.sh complete its gate logic without a hard missing-file
# error, so the talk-ship engine's other validation surfaces are testable
# in isolation. Replace with the real implementation in v0.4.1.
set -euo pipefail
HTML="${1:-}"
if [[ -z "$HTML" ]]; then
  echo "verify-evidence: usage: $0 <html-file>" >&2
  exit 2
fi
[[ -f "$HTML" ]] || {
  echo "verify-evidence: file not found: $HTML" >&2
  exit 1
}
echo "verify-evidence: stub ok ($HTML · $(wc -c < "$HTML") bytes)"
exit 0
