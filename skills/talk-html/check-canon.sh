#!/usr/bin/env bash
# check-canon.sh — talk-html canonical-file guard.
#
# Canonical SKILL.md lives in ~/plugins/talk-html-plugin/skills/talk-html/
# (the plugin is the source of truth). All other copies — ~/.agents,
# ~/.claude, ~/.codex, and the Claude plugins cache — are kept in sync
# via this script's --heal mode.
#
# usage:
#   check-canon.sh                  → exit 1 on drift, 0 if all match
#   check-canon.sh --heal           → copy canonical to drifted targets
#   check-canon.sh --heal --quiet   → silent heal, exit 0 always
#   check-canon.sh --all            → ignored, kept for symmetry with talk-ship
set -euo pipefail

CANON="$HOME/plugins/talk-html-plugin/skills/talk-html/SKILL.md"
[[ -f "$CANON" ]] || {
  echo "missing canonical talk-html skill: $CANON" >&2
  exit 66
}

HEAL="false"
QUIET="false"
for arg in "$@"; do
  case "$arg" in
    --heal) HEAL="true" ;;
    --quiet) QUIET="true" ;;
    --all) ;;
  esac
done

targets=(
  "$HOME/.agents/skills/talk-html/SKILL.md"
  "$HOME/.claude/skills/talk-html/SKILL.md"
  "$HOME/.codex/skills/talk-html/SKILL.md"
  "$HOME/.claude/plugins/talk-html-plugin/skills/talk-html/SKILL.md"
)

canon_sha="$(shasum -a 256 "$CANON" | awk '{print $1}')"

for target in "${targets[@]}"; do
  [[ "$target" != "$CANON" ]] || continue
  [[ -e "$target" ]] || continue

  if cmp -s "$CANON" "$target"; then
    continue
  fi

  if [[ "$HEAL" == "true" ]]; then
    mkdir -p "$(dirname "$target")"
    cp "$CANON" "$target"
    [[ "$QUIET" == "true" ]] || echo "healed: $target"
  else
    echo "drift: $target" >&2
    exit 1
  fi
done

[[ "$QUIET" == "true" ]] || echo "canonical sha256: $canon_sha"
