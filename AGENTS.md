## Project publishing skill

For `/write`, 随口聊天成文、语音转写整理、公众号写作与改稿, first use
`skills/write/SKILL.md`. It owns conversation-to-article editing and the bundled
WeChat MCP draft reference; apply the publishing domain contract below as well.

For any task involving 小红书 / RedNote / Xiaohongshu / 微信公众号 / WeChat Official Account / 草稿箱 / 图文消息 / 跨平台内容复用 / 发布画廊, use the project skill:

`.agents/skills/publish-rednote-wechat/SKILL.md`

That skill owns the domain workflow: derive content, run deterministic local gates, drive the real platform surface when requested, preserve non-secret evidence, and distinguish draft-saved / draft-verified / published states.

After completing any implementation, automation, or repository change for this publishing workflow, also run the canonical `/verify` skill before opening a PR.

<!-- verify-shift-left:start -->
## Pre-PR verification

Use /verify skill every time BEFORE we make a PR

- Canonical skill source: `liush2yuxjtu/claude-runtime-verification-skills@0d585c02bbeaa756e45865dd0a36f84d1b08f589`.
- Run relevant existing tests locally through `/verify` before PR creation.
- Keep test files in the repository; shift their execution left instead of deleting coverage.
- Preserve remote CI only for checks that genuinely require remote, production, deployment, secret, runner, or environment-specific execution.
- Do not open a PR on `FAIL` or `BLOCKED`. `SKIP` is only valid when the skill says no executable runtime behavior applies.

<!-- verify-shift-left:end -->
