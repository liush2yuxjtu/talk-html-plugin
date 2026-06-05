#!/usr/bin/env bash
# check-canon.sh — talk-ship canonical-file guard.
#
# Mirrors ~/.agents/skills/talk-html/check-canon.sh. Keeps the canonical
# SKILL.md in ~/plugins/talk-html-plugin/skills/talk-ship/ in sync with the
# symlinked copies in ~/.agents/, ~/.claude/, ~/.codex/, and the Claude
# plugins cache.
#
# usage:
#   check-canon.sh                  → exit 1 on drift, 0 if all match
#   check-canon.sh --heal           → copy canonical to drifted targets
#   check-canon.sh --heal --all --quiet   → silent heal, exit 0 always
#   check-canon.sh --all            → ignored, kept for symmetry with talk-html
set -euo pipefail

CANON="$HOME/plugins/talk-html-plugin/skills/talk-ship/SKILL.md"
[[ -f "$CANON" ]] || {
  echo "missing canonical talk-ship skill: $CANON" >&2
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
  "$HOME/.agents/skills/talk-ship/SKILL.md"
  "$HOME/.claude/skills/talk-ship/SKILL.md"
  "$HOME/.codex/skills/talk-ship/SKILL.md"
  "$HOME/.claude/plugins/talk-html-plugin/skills/talk-ship/SKILL.md"
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
