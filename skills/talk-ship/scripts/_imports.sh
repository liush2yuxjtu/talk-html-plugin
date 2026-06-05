#!/usr/bin/env bash
# _imports.sh — single source of truth for talk-html shared scripts.
#
# talk-ship intentionally re-uses talk-html's record-to-gif.sh,
# verify-evidence.sh, publish.sh, recall.sh. This file centralizes the
# import paths so that one canonical change in talk-html propagates to
# every talk-ship script without duplicating the path.
#
# usage in any talk-ship script:
#   source "$(dirname "${BASH_SOURCE[0]}")/_imports.sh"
#   ensure_talk_html_canon
#   "$TALK_HTML_DIR/verify-evidence.sh" "$HTML"
set -euo pipefail

TALK_HTML_DIR="${TALK_HTML_DIR:-$HOME/.agents/skills/talk-html}"

# Sanity check: the canonical talk-html skill must exist. If it has been
# renamed or moved, fail loud — never silently fall back to a partial
# copy. The agent can override TALK_HTML_DIR before sourcing if the
# canonical lives somewhere unexpected.
ensure_talk_html_canon() {
  [[ -f "$TALK_HTML_DIR/SKILL.md" ]] || {
    echo "talk-ship: talk-html canonical not found at $TALK_HTML_DIR" >&2
    echo "talk-ship: set TALK_HTML_DIR or run check-canon.sh --heal on talk-html first" >&2
    return 66
  }
  [[ -x "$TALK_HTML_DIR/verify-evidence.sh" ]] || {
    echo "talk-ship: missing $TALK_HTML_DIR/verify-evidence.sh" >&2
    return 66
  }
}

# Heal both skills in one call. Safe to run before any talk-ship script
# that needs talk-html to be in sync.
heal_both_canons() {
  bash "$HOME/.agents/skills/talk-ship/check-canon.sh" --heal --all --quiet
  if [[ -x "$HOME/.agents/skills/talk-html/check-canon.sh" ]]; then
    bash "$HOME/.agents/skills/talk-html/check-canon.sh" --heal --all --quiet
  fi
}
