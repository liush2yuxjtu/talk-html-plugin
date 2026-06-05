#!/usr/bin/env bash
# install.sh — install the talk-html-plugin (two-engine, single source of truth).
#
# Single canonical home: $PLUGIN_DEST = ~/.claude/plugins/talk-html-plugin
#   skills/talk-html/   <- engine for one-pagers (recap / postmortem / status)
#   skills/talk-ship/   <- engine for end-to-end user-journey recordings
#   commands/           <- 10 slash commands, router + 8 roles + /talk-ship
#   .claude-plugin/     <- Claude Code manifest
#   .codex-plugin/      <- Codex manifest
#
# All well-known harness skill paths (and the legacy ~/.agents/ alias) become
# 2-hop symlinks straight at $PLUGIN_DEST/skills/<name> — no 3-hop chain, no
# duplicated real directories. check-canon.sh on the plugin side guards drift
# across all five symlink endpoints.
#
#   curl -fsSL https://raw.githubusercontent.com/LiuShiyuMath/talk-html-plugin/main/install.sh | bash
#
# Existing installs are backed up to *.bak.<timestamp>, never clobbered.

set -euo pipefail

REPO="https://github.com/LiuShiyuMath/talk-html-plugin"
PLUGIN_DEST="$HOME/.claude/plugins/talk-html-plugin"
ARTIFACT_DIR="$HOME/.claude/talk-html"

echo "→ installing talk-html-plugin from $REPO (single source: $PLUGIN_DEST)"

command -v git >/dev/null 2>&1 || {
  echo "✗ git is required but not installed." >&2
  exit 1
}

backup_if_present() {
  local target="$1"
  if [[ -d "$target" || -L "$target" ]]; then
    local backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"
    echo "  note: $target already exists — moving it to $backup"
    mv "$target" "$backup"
  fi
}

link_or_skip() {
  # 2-hop direct: <link> -> $PLUGIN_DEST/skills/<name>
  local link="$1" name="$2"
  if [[ ! -e "$link" && ! -L "$link" ]]; then
    mkdir -p "$(dirname "$link")"
    ln -s "$PLUGIN_DEST/skills/$name" "$link"
    echo "  linked  $link -> $PLUGIN_DEST/skills/$name"
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 "$REPO" "$TMP/repo" >/dev/null 2>&1 || {
  echo "✗ git clone failed. check your network, or clone manually:" >&2
  echo "    git clone $REPO" >&2
  exit 1
}

# 1. plugin install (the single canonical home)
backup_if_present "$PLUGIN_DEST"
mkdir -p "$PLUGIN_DEST"
cp -R "$TMP/repo/.claude-plugin"   "$PLUGIN_DEST/"
cp -R "$TMP/repo/.codex-plugin"    "$PLUGIN_DEST/" 2>/dev/null || true
cp -R "$TMP/repo/commands"         "$PLUGIN_DEST/"
cp -R "$TMP/repo/skills"           "$PLUGIN_DEST/"

# 2. executable bits inside the plugin
chmod +x \
  "$PLUGIN_DEST/skills/talk-html/publish.sh" \
  "$PLUGIN_DEST/skills/talk-html/recall.sh" \
  "$PLUGIN_DEST/skills/talk-html/check-canon.sh" \
  "$PLUGIN_DEST/skills/talk-html/verify-evidence.sh" \
  "$PLUGIN_DEST/skills/talk-html/record-to-gif.sh" \
  "$PLUGIN_DEST/skills/talk-ship/check-canon.sh" \
  "$PLUGIN_DEST/skills/talk-ship/scripts/"*.sh 2>/dev/null || true

# 3. 2-hop symlink fan-out (5 endpoints × 2 engines = 6 links; all → $PLUGIN_DEST)
for NAME in talk-html talk-ship; do
  link_or_skip "$HOME/.claude/skills/$NAME" "$NAME"
  link_or_skip "$HOME/.codex/skills/$NAME"  "$NAME"
  link_or_skip "$HOME/.agents/skills/$NAME" "$NAME"
done

mkdir -p "$ARTIFACT_DIR"

echo "✓ skill    installed to $SKILL_DEST"
echo "✓ plugin   installed to $PLUGIN_DEST"
echo "✓ engines  bundled:"
echo "             $PLUGIN_DEST/skills/talk-html"
echo "             $PLUGIN_DEST/skills/talk-ship"
echo ""
echo "  use the router:    /talk-html        (infers audience, dispatches)"
echo "  ship a journey:    /talk-ship        (end-to-end user journey recording)"
echo "  use a role direct: /talk-ux | /talk-ceo | /talk-data | /talk-reviewer"
echo "                     /talk-cto | /talk-qa | /talk-docs | /talk-legal"
echo ""
echo "  publishing to a gist needs the GitHub CLI, authed:"
echo "    brew install gh && gh auth login"
echo ""
echo "  bundled skills (for /talk-html --image auto-illustration):"
echo "    skills/gpt-image  — drives logged-in ChatGPT to generate + download 配图"
echo "    skills/browse     — gstack browse daemon driver (chatgpt.com)"
echo "  the browse binary is NOT shipped (see .gitignore: dist/). build it once:"
echo "    cd ~/.claude/skills/gstack && bun install && bun run build"
echo "  or point \$BROWSE_BIN at an existing gstack browse binary."
