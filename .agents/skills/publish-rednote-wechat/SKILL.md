---
name: publish-rednote-wechat
description: >-
  Write, derive, validate, save, and verify RedNote/Xiaohongshu drafts and
  WeChat Official Account articles for this repository. Use whenever the task
  involves 小红书/RedNote/Xiaohongshu 文案、微信公众号/WeChat Official Account
  HTML、草稿箱、预览、发表、发布画廊、跨平台复用，或用户要求验证这些内容是否真的保存/发布。
  This skill follows the canonical /verify contract: shift tests left, exercise
  the real platform surface, preserve raw evidence, probe a nearby edge case,
  and emit exactly PASS / FAIL / BLOCKED / SKIP with no partial pass.
---

# Publish RedNote + WeChat

本 Skill 是 `talk-html-plugin` 项目里小红书与微信公众号内容工作的执行合同。

目标不是“生成一段看起来像内容的文字”，而是：

1. 从 canonical source 生成平台稿件；
2. 在本地先做确定性验证；
3. 能到真实平台时，真的把稿件放进平台；
4. 用真实平台状态证明“草稿已保存 / 已发布”；
5. 永远不要把 preview、浏览器填表、提交任务冒充最终发布。

## Canonical verify contract

本 Skill 必须遵守项目 `/verify` 的当前约束。项目同步副本来自：

`liush2yuxjtu/claude-runtime-verification-skills@0d585c02bbeaa756e45865dd0a36f84d1b08f589`

核心规则：

- 先跑最小但相关的 existing/local verification。
- 再沿着改动走到真实 user/program surface。
- 静态检查、类型检查、代码 review 只能做 supporting evidence。
- 真实 surface 存在时，runtime evidence 不能省。
- 至少探测一个相邻 edge case。
- 原始证据先保存，再解释。
- verdict 只能是 `PASS` / `FAIL` / `BLOCKED` / `SKIP`。
- **No partial pass.**
- 遇到环境或权限问题，返回 `BLOCKED`，不要把 lower state 升级成 success。

## Canonical project sources

- RedNote canonical content/status: Airtable `ChatGPT Work Hub → 每日小红书内容`
- Publishing rules/evidence: Airtable `Engineering Knowledge Base`
- Git repository mirror/test harness: `rednote-gallery/`
- Current deterministic verifier: `rednote-gallery/scripts/verify-publishing.py`
- Non-secret live evidence: `rednote-gallery/evidence/`

如果 Airtable connector 当前不可用：

- 不要猜 canonical status；
- 可以使用仓库中已落盘的 source/evidence；
- 将 Airtable 同步写成 pending evidence；
- 不得声称 Airtable 已更新。

## State model

严格使用这些状态：

```text
source-draft
  -> rednote-derived
  -> rednote-locally-verified
  -> rednote-draft-saved
  -> rednote-draft-verified
  -> rednote-published

source-draft
  -> html-rendered
  -> wechat-locally-verified
  -> wechat-draft-saved
  -> wechat-draft-verified
  -> wechat-publish-submitted
  -> wechat-published
```

只能声明有证据支持的最高状态。

例如：

- HTML preview 成功 ≠ `wechat-draft-saved`
- 微信 UI 显示“已保存” + real `appmsgid` = `wechat-draft-saved`
- 保存草稿 ≠ `wechat-draft-verified`
- 点击“发表” ≠ `wechat-published`
- RedNote gallery 有卡片 ≠ `rednote-published`

## Workflow

### 1. Resolve source

确认：

- source record / source file；
- source version；
- intended platform(s)；
- task is draft-only or actual publish；
- existing prior draft/version that must not be overwritten。

历史发布稿 append-only。不要为了“更漂亮”覆盖 canonical history。

### 2. Derive RedNote draft

创建或更新：

```text
rednote-gallery/posts/<date-slug>/rednote-draft.md
rednote-gallery/posts/<date-slug>/rednote-preview.html
```

要求：

- 保留 source provenance；
- 有明确标题；
- 正文非空；
- 无 `TODO` / `TBD` / `正文待补`；
- preview 必须明确标记 draft / not published；
- HTML 只是 authoring/preview surface，不冒充小红书原生上传格式。

### 3. Derive WeChat payload

创建或更新：

```text
rednote-gallery/posts/<date-slug>/wechat-payload.html
rednote-gallery/posts/<date-slug>/index.html
```

微信 payload baseline：

- 标题 <= 32 中文字符；
- 作者 <= 16 字符（如果有）；
- 摘要 <= 120 字符（如果有）；
- payload < 20,000 chars；
- payload < 1 MiB；
- 不使用 `<script>`；
- 不依赖 `<style>`；
- publication-critical CSS 使用 inline style；
- 正文外链图片不得直接依赖普通外部 URL；
- 微信正文图片应先变成 WeChat-hosted URL；
- 单列阅读顺序在 CSS 被削弱时仍可读。

### 4. Shift-left local verification

在进入真实平台前运行：

```bash
python3 rednote-gallery/scripts/verify-publishing.py \
  --rednote rednote-gallery/posts/<post>/rednote-draft.md \
  --wechat rednote-gallery/posts/<post>/wechat-payload.html \
  --title '文章标题'
```

要求：

- exit 0 = local gate PASS；
- exit non-zero = FAIL；
- 不得为了绿灯删除、弱化或跳过验证。

保存：

- command；
- exit code；
- relevant raw output；
- artifact sizes / counts。

### 5. Drive the real RedNote surface

如果任务要求平台草稿或发布，必须进入真实 authenticated RedNote/Xiaohongshu surface。

`rednote-draft-saved` PASS 需要：

- authenticated platform editor；
- 标题、正文、图片真实填入；
- 平台 draft-save 成功；
- 保存后有可识别 platform draft state / ID / URL。

`rednote-draft-verified` PASS 需要：

- 重新打开真实平台草稿；
- 标题匹配；
- 正文长度/关键块匹配；
- 图片数量匹配；
- evidence 落盘。

`rednote-published` PASS 需要：

- 可重新打开的真实 note URL 或 platform note ID；
- 页面属于本次目标内容；
- evidence 记录 permanent identifier。

### 6. Drive the real WeChat surface

如果任务要求微信草稿或发布，使用真实 `mp.weixin.qq.com` 或官方 API。

Browser path：

1. authenticated browser；
2. 打开真实图文编辑器；
3. 写入 title；
4. 写入 main body editor；
5. **保存前**检查真实编辑器结构；
6. 点击 `保存为草稿`；
7. 记录 real `appmsgid`；
8. 检查 UI 成功状态和错误状态。

保存前至少记录：

- title length；
- body text length；
- editor HTML length；
- section count；
- paragraph count；
- inline-styled element count；
- image count（有图片时）。

`wechat-draft-saved` PASS：

- save action 完成；
- real `appmsgid` 存在；
- UI 为 `已保存` 或等价成功状态；
- 无 title/body/cover/save error。

`wechat-draft-verified` PASS：

- 重新打开该 `appmsgid` 或从官方草稿箱打开；
- title 匹配；
- body length 在合理 tolerance 内；
- expected structural blocks/image count survives；
- 记录 reopen evidence。

如果安全层阻断 authenticated content inspection：

- 保持 `wechat-draft-saved`；
- `wechat-draft-verified = BLOCKED`；
- 不得升级状态。

`wechat-published` PASS：

- API：terminal `publish_status = 0` + permanent article URL；
- Browser：真实永久文章 URL / backend publication identifier 能重新打开；
- 单纯点击 `发表` 或进入确认框不算 PASS。

### 7. Nearby edge case

遵循 canonical `/verify`：真实 surface 验证后，至少探一个相邻 edge case。

适合本项目的 edge cases：

- title 接近/超过平台长度；
- payload 存在外部图片 URL；
- HTML 含 `<script>` 或 `<style>`；
- 空正文；
- 同一草稿重新打开；
- 编辑器把 HTML 降级成纯文本；
- platform save 成功但 reopen 结构丢失；
- RedNote preview 被误标为 published。

只选与本次改动最相关的一个，不要机械全跑。

## Evidence

每次 live run 写：

```text
rednote-gallery/evidence/YYYY-MM-DD.md
```

最少包含：

- claim；
- source/version；
- local verification command/result；
- runtime method；
- driven steps；
- observed platform state；
- platform identifier；
- edge probe；
- findings；
- cleanup status；
- one final verdict。

严禁把以下内容放入 Git：

- cookies；
- access tokens；
- app secrets；
- authenticated storage state；
- QR payload；
- browser profile；
- private account data。

## Current known real example

2026-09-21：

- source Airtable record: `recrxe7yqyc8ylK6r`
- title length: 25
- WeChat local HTML: 10,074 chars / 12,598 bytes
- real WeChat editor body text: 2,402 chars
- editor HTML: 13,034 chars
- sections: 3
- paragraphs: 84
- inline-styled elements: 88
- saved draft platform ID: `appmsgid=100000050`
- UI state: `已保存`

Evidence-backed claim:

```text
html-rendered = PASS
wechat-locally-verified = PASS
wechat-draft-saved = PASS
wechat-draft-verified = BLOCKED
wechat-published = NOT CLAIMED
```

不要把这个历史 example 当成下一次运行的结果。每次都重新验证真实 surface。

## Completion format

最终报告保持短，但必须明确：

```text
Claim:
Local gate:
Runtime surface:
Evidence:
Edge probe:
Findings:
Verdict: PASS | FAIL | BLOCKED | SKIP
Cleanup:
```

如果同时处理两个平台，分别给 RedNote 和 WeChat verdict。

## Relationship to /verify

本 Skill 负责领域流程；`/verify` 负责最终验证纪律。

完成任何发布相关实现、脚本、平台自动化或 AGENTS/Skill 修改后：

1. 先执行本 Skill 的平台/内容 gates；
2. 再执行项目 `/verify`；
3. 只有两个都满足各自要求，才能声称任务完成。
