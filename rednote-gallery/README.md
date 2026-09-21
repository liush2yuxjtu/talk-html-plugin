# RedNote Publish Gallery

A static, browseable mirror of published RedNote/Xiaohongshu entries from Airtable, plus cross-platform WeChat HTML experiments.

- Canonical content/status: Airtable `ChatGPT Work Hub → 每日小红书内容`
- Current snapshot: 27 published records
- Current experiment source: `recrxe7yqyc8ylK6r`
- WeChat preview: `posts/2026-09-21-agent-runtime-wechat-test/`
- Project publishing skill: `.agents/skills/publish-rednote-wechat/SKILL.md`
- Rules: see `AGENTS.md`
- Verification appendix: see `VERIFY.md`
- Deterministic verifier: `scripts/verify-publishing.py`
- Live evidence: `evidence/`

Quick verification:

```bash
python3 rednote-gallery/scripts/verify-publishing.py \
  --rednote rednote-gallery/posts/2026-09-21-agent-runtime-wechat-test/rednote-draft.md \
  --wechat rednote-gallery/posts/2026-09-21-agent-runtime-wechat-test/wechat-payload.html \
  --title '模型能力指数增长，企业却还是线性：因为少了两层系统'
```

The browser preview shell is intentionally more capable than the WeChat payload. The actual payload is stored separately in `wechat-payload.html` and uses only conservative inline HTML.
