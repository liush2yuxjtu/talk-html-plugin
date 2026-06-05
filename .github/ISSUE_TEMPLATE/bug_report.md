---
name: Bug report
about: Something in the plugin is broken or behaving wrong
title: "[bug] "
labels: ["bug", "needs-triage"]
assignees: []
---

## What happened

<!-- one paragraph, no preamble -->

## What I expected

<!-- one paragraph, no preamble -->

## Reproduction

```bash
# minimal command(s) to reproduce
```

## Environment

- talk-html-plugin version: `v______` (from `~/.claude/plugins/talk-html-plugin/.claude-plugin/plugin.json`)
- Claude Code / Codex: `claude --version` / `codex --version`
- OS: `macOS / Linux / WSL` + version
- Harness: `~/.claude / ~/.codex / both`

## Logs

```text
paste the relevant output here
```

## What I already tried

- [ ] reinstalled (`curl -fsSL .../install.sh | bash`)
- [ ] cleared cache (`rm -rf ~/.claude/plugins/cache/personal-talk-html/`)
- [ ] checked the role-routing.csv for stale role names
- [ ] ran `bash skills/talk-html/check-canon.sh` (output below)

```text
paste here
```

## Severity

- [ ] blocker — can't use any `/talk-*` command
- [ ] major — one role broken, others work
- [ ] minor — cosmetic / docs / typo
- [ ] uncertain — needs triage
