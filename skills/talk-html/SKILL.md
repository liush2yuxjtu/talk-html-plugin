---
name: talk-html
description: >-
  Invoke when the user wants a shareable HTML one-pager out of the current
  conversation, a writeup, or assembled context: recap, postmortem, status
  board, proposal, founder update, decision log, or "send a link, not a chat
  scroll" artifact. zh-CN by default. The skill publishes via GitHub gist,
  records recall metadata, and uses real screenshots/video/diff/command output
  for proof. Triggers: /talk-html, make a page, one-pager, html version,
  publish this, shareable page, gist link, 做成一页, 做个网页, html 版本,
  用 html 解释, 推到 gist. NOT for shipped UI, landing pages, React
  components, doc conversion, QA bug reports, or scripts.
---

# talk-html

Communicate in HTML, not chat. Build a readable Chinese one-pager, preview it
locally, then publish a durable gist link unless the user explicitly opts out.

This skill is a **contract**, not an eval recipe. It declares what the user
wants, what tools agents may use, what machine-readable outputs should exist,
and what tools can turn evidence into a human visual report. Agents choose
their own exploration path.

## User Wants, Tools, Outputs

| # | User wants | Tools agents can use to eval | Outputs readable to agents | Tools agents can use for human visual report |
|---|---|---|---|---|
| 1 | 分享页给人看，不是聊天记录搬运 | `talk-html`, `publish.sh`, `recall.sh`, browser, `curl` | `talk-html-meta`, `index.jsonl`, local/gist/raw/rendered URL, HTTP status | HTML/CSS, gist, htmlpreview, browser screenshot |
| 2 | 证据是真的，不要画假证明 | `verify-evidence.sh`, `talk-html-evidence`, `run-log`, source files, command logs | provenance JSON/comment, command exit code, artifact path/hash, source path | embedded screenshot, GIF, MP4, evidence caption |
| 3 | 证明必须匹配 claim | `git diff`, target CLI, test runner, browser tools, proof/source artifacts | diff, test output, command output, artifact type, reviewer/audience type | side-by-side diff, proof chain panel, status blocks |
| 4 | 不要强迫 Claude TUI | shell, CLI output, env checker, normal terminal recorder, Claude TUI when useful | redacted env report, command transcript, exit code, wrapper diff | readable terminal panel, short command replay, concise proof card |
| 5 | 如果用了 Claude TUI，就必须是真交互 | `tmux`, Claude Code TUI, `asciinema`, `ffmpeg`, terminal capture tools | TUI run log, prompt marker, response marker, frame list, recording path | TUI GIF/MP4, poster frame, prompt/response callout |
| 6 | 终端证据给人看，不给机器 scrollback | terminal recorder, `screencapture`, renderer, poster inspection tools | transcript file, frame metadata, recording metadata, clipped command output | large-font terminal visual, PASS/DENY highlight, collapsed raw evidence |
| 7 | 字体好看，中文正常，不要方块字 | font discovery tools, image renderer, screenshot/poster tools | font name, fallback list, poster path, render artifact path | SF Mono/SFNSMono + PingFang/Hiragino/Noto/Source Han rendered visual |
| 8 | 最终报告对人类清楚，对 agent 可追踪 | HTML file, metadata comment, evidence comment, index row, publish script | session id, slug, prompt summary, source list, generated timestamp | first-screen summary, visual evidence section, verification notes |

Short form:

- **User wants:** real, readable, claim-matched, shareable proof.
- **Agents get:** eval tools, provenance outputs, machine-readable metadata,
  recording/rendering tools, and publishing tools.
- **Humans get:** a visual report with real screenshots/GIF/video, readable
  terminal/TUI evidence, and no raw plumbing noise.
- **No fixed eval recipe:** agents explore, choose tools, and decide which proof
  path fits the claim.

## Non-Negotiable Contract

- Output language is Simplified Chinese (`zh-CN`) unless the user explicitly
  asks otherwise. File paths, commands, URLs, code, and technical identifiers
  may stay in English.
- The page is grounded in real sources: code, data, commands, routes, fixtures,
  screenshots, recordings, diffs, logs, tests, or generated artifacts.
- Do not invent a mock UI, fake dataset, fake command output, fake video, or
  fake provenance unless the user explicitly asked for fiction/mockup.
- If a claim depends on motion or interaction, the human report needs real
  visual evidence: GIF, MP4/WebM, screenshot sequence, terminal capture, or
  poster frame from the real run.
- If Claude TUI appears as proof, the visual evidence shows a real user prompt
  and Claude's visible response/permission/error state. A welcome screen or a
  `claude -p` shell call is not a TUI interaction.
- Do not force Claude TUI for ordinary CLI/alias/script claims. Shell proof,
  command output, env checks, and diffs are valid tools.
- Terminal/TUI visuals are for humans first: large type, stable framing, short
  commands, clear PASS/DENY moments, no secret values, no internal job clutter,
  no raw tmux plumbing as the main artifact.
- Terminal/TUI fonts must cover Chinese and box drawing. Prefer SF Mono/SFNSMono
  plus PingFang SC, Hiragino Sans GB, Noto Sans CJK SC, or Source Han Sans.
  Re-render if the poster shows `□`, `�`, missing glyph boxes, tiny text, or
  ugly fallback fonts.
- Published pages must be portable. Primary evidence must work on the rendered
  gist URL, not only on local `file://` paths.

## Workflow

### 0. Preflight

For every run, heal local skill drift before reading or writing artifacts:

```bash
bash ~/.agents/skills/talk-html/check-canon.sh --heal --all --quiet
```

The canonical skill file is:

```text
~/.agents/skills/talk-html/SKILL.md
```

`~/.claude/skills/talk-html` and `~/.codex/skills/talk-html` should be treated
as loaded copies/symlinks. Repo-local `*/talk-html/SKILL.md` files are not
authoritative for self-referential talk-html work.

### 1. Resolve the Page

Create:

- `slug`: 3-5 kebab-case words.
- `prompt_summary`: one Chinese sentence, 200 chars max.
- `template`: `explainer`, `recap`, `status`, `pitch`, or `letter`.
- `audience`: who needs to understand the page.
- `core_claim`: the one sentence the first screen must make clear.

Use `status` for proof-of-work/status pages, `pitch` for persuasive proposals,
`recap` for decision logs, `letter` for personal memo, and `explainer` when in
doubt.

### 2. Gather Real Evidence

Use the tools that fit the claim. Examples:

- Code/change proof: `git diff`, test runner, build output, CI artifact.
- CLI/alias proof: target command, env checker, redacted transcript, exit code.
- Browser/UI proof: project build command, local server, Playwright/browser,
  screenshots, GIF/MP4/WebM.
- Terminal/TUI proof: terminal recorder, `tmux`, `asciinema`, `ffmpeg`,
  `screencapture`, poster renderer.
- Data proof: source files, fixtures, command output, generated data manifest,
  hashes, `run-log`.
- Provenance proof: `talk-html-evidence`, `run-log.json`, source paths, command
  logs, timestamps.

The page should expose enough agent-readable material that another agent can
retrace the artifact without reading the chat scroll.

### 3. Write the HTML

Save to:

```text
~/.agents/talk-html/<slug>-YYYYMMDD-HHMMSS.html
```

Required page properties:

- `<html lang="zh-CN">` and `<meta charset="utf-8">`.
- Inline CSS. No external JS. Google Fonts are allowed.
- JS only for the audit pill clipboard buttons and the "继续修改" prompt copy
  button.
- Editorial typography with a real Chinese body face. Noto Serif SC is a safe
  default; terminal panels may use SF Mono/SFNSMono plus CJK fallback.
- SVG for diagrams. No live Mermaid block.
- Mobile reflow at 420 px without clipped text.
- Motion respects `prefers-reduced-motion`.
- No emoji unless the user asked.
- No AI-SaaS hero-gradient filler.
- File under 200 KB unless real embedded media genuinely requires more.

Recommended page shape:

1. First screen: one-sentence claim + proof chain.
2. Evidence: real visual proof, diff, command output, or data source.
3. Agent-readable trail: metadata, provenance, logs, paths, hashes, URLs.
4. Human-readable explanation: short sections, no hype, no internal plumbing.
5. Verification notes: collapsed `<details>` for limitations/gaps.
6. Continue bar and footer.

### 4. Stamp Metadata

At the top of `<head>`:

```html
<!-- talk-html-meta {"session_id":"<id>","job_dir":"<dir-or-null>","branch":"<git-branch-or-null>","prompt_summary":"<≤200 chars>","origin_prompt":"<verbatim first user message, ≤200 chars>","template":"<template-name>","generated_at":"<ISO8601 UTC>"} -->
```

Resolve `session_id` from `CLAUDE_SESSION_ID`, `CODEX_THREAD_ID`, transcript
lookup, or the active harness. If it cannot be found, make that visible in the
agent-readable trail instead of hiding it.

### 5. Add Provenance Near Motion Evidence

When the page embeds GIF/video/WebM or any motion artifact, put a provenance
comment near it:

```html
<!-- talk-html-evidence {"cmd":"<command or tool chain>","host":"<machine/context>","source":"<source files, command logs, fixtures, metrics, or run-log>","recorded_at":"<ISO8601 UTC>"} -->
```

If a requested moving proof cannot be recorded, visibly label the section as
unrecorded, keep the raw evidence that exists, and include a machine-readable
marker:

```html
<section data-evidence="unrecorded">...</section>
```

### 6. Add the Audit Pill

The fixed audit pill answers: which conversation made this, and how can the
user return to it?

It includes:

- human-readable `origin_prompt`, truncated for display;
- `copy id` button for `session_id`;
- `resume` button that copies `claude --resume <session_id>`;
- tooltip with full id and timestamp.

Do not add `file://` transcript links to published pages.

### 7. Add the "继续修改" Bar

Every page carries a small bar above the footer:

- one-line text input for the desired change;
- button "复制续修指令";
- helper text telling the reader to paste it into Claude/Codex.

Clipboard string:

```text
claude --resume <session_id> "继续修改我用 talk-html 生成的产物（slug: <slug>；本地 <local_path>；若会话已失效，先跑 bash ~/.agents/skills/talk-html/recall.sh <slug> 定位它）。修改要求：INSTR。改完按 talk-html 流程重新发布 gist 并打印四个 URL。"
```

### 8. Preview and Publish

Local preview:

```bash
open "$HTML_PATH"
```

Publish unless the user explicitly said not to publish:

```bash
bash ~/.agents/skills/talk-html/publish.sh "$HTML_PATH"
```

`publish.sh` runs the evidence/provenance check, publishes with `gh gist
create`, computes raw/rendered URLs, and appends `~/.agents/talk-html/index.jsonl`.

If the user said "don't publish", "local only", "no gist", "先别推", or similar,
do not publish. Print the local path and the publish command.

### 9. Print URLs

Print exactly:

```text
local:    file://<path>
gist:     <gist page URL>
raw:      <raw.githubusercontent URL>
rendered: <htmlpreview.github.io URL>
```

The rendered URL is the human-shareable URL.

## Recall

Recent pages:

```bash
bash ~/.agents/skills/talk-html/recall.sh
```

Open by slug substring:

```bash
bash ~/.agents/skills/talk-html/recall.sh <substring>
```

The index is:

```text
~/.agents/talk-html/index.jsonl
```

## Gallery

Static visual index:

```bash
cd ~/.agents/talk-html/_gallery && bun build.ts
cd ~/.agents/talk-html/_gallery && bun build.ts --publish
cd ~/.agents/talk-html/_gallery && bun verify.ts
```

Cards link to rendered gist URLs. Local-only pages show a local/unpublished
state.

## Failure Modes

| Failure | Agent-facing output | Human-facing report |
|---|---|---|
| `gh` missing or not authed | local file path, install/auth hint | local preview path and publish command |
| gist transient failure | retry log, local file path | concise publish failure note |
| rendered URL CDN lag | raw URL, HTTP status | rendered URL plus short wait/retry note |
| primary evidence unavailable | raw logs, source paths, unrecorded marker | visible "未录制/不可播放" note in verification details |
| requested video cannot be made playable | manifest gap, source path, failed command | no fake replacement; show playable items only |
| core claim has no real evidence | missing source list | state that the page cannot honestly support the claim |

## Quality Bar

1. Chinese first: all user-facing prose is zh-CN.
2. Real evidence: no fake screenshots, videos, data, diffs, or command output.
3. Claim-matched proof: the visible proof directly supports the first-screen
   claim.
4. Agent-readable trail: metadata, provenance, command/source references, and
   durable URLs exist.
5. Human-readable visual report: large enough text, readable captions, no raw
   terminal plumbing as the main artifact.
6. Claude TUI is optional, not forced. If shown, it shows real interactive
   prompt/response or permission/error state.
7. Terminal/TUI fonts are readable and CJK-safe; no tofu boxes or ugly fallback.
8. Published page parity: primary evidence works on the rendered gist URL.
9. Continue bar and audit pill are present.
10. Limitations are preserved in collapsed verification notes.

## `--image` Mode

`/talk-html --image` adds generated supporting images after the normal page is
already published. It uses the bundled `gpt-image` and `browse` skills:

1. Build and publish the normal page first.
2. Open a fresh ChatGPT/browser session with only this prompt:

```text
帮我生成一组配图：<raw URL>
```

3. Download the generated images, inline them as `data:` URLs, rerun evidence
   verification, republish, and open the rendered URL.

If image generation fails, keep the already-published no-image page. Do not
draw fake replacement images.
