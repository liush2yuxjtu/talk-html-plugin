---
description: 把随口聊天、语音转写和零散素材写成文章或微信公众号草稿；/write、整理成公众号、改微信草稿、给真实预览时使用。
---

# /write

读取并执行本插件 `skills/write/SKILL.md`；Claude Code 中可通过
`${CLAUDE_PLUGIN_ROOT}/skills/write/SKILL.md` 定位。

把 `$ARGUMENTS` 与当前对话作为输入，沿用已有素材、修改意见和草稿目标。
按用户要求完成文章、排版或微信草稿回读验证。不要先转到 `/talk-html` 的 gist 发布流程。
默认不公开发表；平台草稿任务优先交付微信真实预览链接。
