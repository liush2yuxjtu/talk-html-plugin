---
name: talk-ship
description: >-
  Invoke when the user is about to ship a product, page, or feature to end
  users and wants a recorded, video-proven, end-to-end user journey. The
  skill runs the full user journey (persona, stages, touchpoints, goals,
  KPIs), records it with Playwright (browser) or tmux + asciinema
  (terminal), stitches the capture into a shareable MP4 with a contact
  sheet, and folds the proof into a talk-html one-pager. zh-CN by default.
  Triggers: /talk-ship, ship it, 准备上线, ship 前录一下, 录一段用户旅程,
  拍个 ship 视频, 端到端跑一遍, 录个端到端 demo, end-to-end recording,
  journey video, ship video, ship proof, release demo, GA demo.
  Use /talk-html for one-pagers, recaps, status boards, decision logs.
  NOT for unit tests, single-screen walkthroughs, marketing trailers, or
  animated explainers without real product capture.
---

# talk-ship

在 ship 之前用真人视角把整条用户旅程跑一遍、录下来、剪成视频、留下证据。

This skill is a **contract**, not a fixed recipe. It declares what a
ship-ready recording must contain, what tools the agent may use, what
machine-readable artifacts the run must produce, and how the run can be
folded into a `talk-html` one-pager or a stand-alone ship handoff.

## 边界：什么时候用 `/talk-ship` 而不是 `/talk-html`

| 场景 | 适合的 skill | 理由 |
|---|---|---|
| 给团队/老板/投资人发个一页 recap、状态板、决策日志 | `/talk-html` | 静态文字 + 截图 + 证据链接 |
| 把当前对话整理成可分享的网页 | `/talk-html` | 不需要 ship 录像 |
| **ship 前**给真实用户 / 客户 / 评审演示、留 release 证据 | **`/talk-ship`** | 必须有端到端录屏和视频 |
| 把一段产品改动发到 YouTube / B 站做 ship trailer | `/talk-ship` | 必须有真机录屏 |
| 单页 walkthrough / 单元 QA / 写功能 README | `qa` / `tdd` / 都不需要 skill | talk-ship 反而过重 |

简版：**talk-html 写一封能转发的信；talk-ship 拍一段能上线的预告片。**
两个 skill 是上下游关系：talk-ship 产出的视频/截图是 talk-html 的最佳
evidence；talk-html 可以把 talk-ship 的产物折成一页可分享的 release note。

## User Wants, Tools, Outputs

| # | User wants | Tools agents can use | Machine-readable outputs | Human visual report |
|---|---|---|---|---|
| 1 | 端到端走完用户旅程，不只是单页 | persona / journey / story map；浏览器/TUI 工具；ffmpeg | `journey/stages.json`、`journey/persona.md`、`run-log.json` | 旅程表 + 关键节点截图 |
| 2 | 真机录制，不是 fake demo | Playwright（浏览器），tmux + asciinema（终端），screencapture（macOS） | `.webm` / `.cast` raw 文件 + frame index | 单时间轴 MP4 |
| 3 | 一段能上线的 ship 视频 | ffmpeg concat、字幕、章节标记、palette + gif | `video/final.mp4`、`video/contact-sheet.png`、`video/poster.jpg` | 视频 + 缩略图 |
| 4 | ship 检查清单过完 | `scripts/ship-checklist.sh`、`scripts/verify-evidence.sh`（复用 talk-html） | `evidence/ship-checklist.json` | Markdown 摘要 |
| 5 | 视频/截图进 talk-html 一页 recap | `talk-html` skill、`publish.sh` | `talk-html-meta`、gist URL | talk-html 页面 |

短版：

- **User wants:** 端到端跑一遍、录下来、剪成视频、留下证据。
- **Agents get:** persona / journey / playwright / tmux / ffmpeg 的工具集 + 结构化产出。
- **Humans get:** 视频 + contact sheet + 旅程表 + ship 自检报告。

## Non-Negotiable Contract

- Output language is Simplified Chinese (`zh-CN`) unless the user explicitly
  asks otherwise. File paths, commands, URLs, code, and technical identifiers
  may stay in English.
- The journey must be **end-to-end**: cover at least `Decision + Service`
  for shipping-bound runs, or the full `Awareness → Loyalty` chain for
  release demos. Each stage must contain one observable user action.
- Recording must be **real**, not mocked: real build, real server, real
  terminal, real network. No fake UI overlays, no fake "happy path"
  composed from unrelated clips. If a stage must be faked (e.g. third-party
  payment), declare it `mocked` in `journey/stages.json` and the ship
  report must not claim the stage was recorded.
- Video proof must match the **claim**: the journey you stage is the
  journey you ship. If a stage is missing or stubbed, mark it
  `unrecorded` or `stub` in the report — never silently drop it.
- The user-visible journey must include a **human-visible** moment in
  each stage: a screenshot, a terminal frame, or a video segment. A
  `TODO` comment or a stubbed route is not a stage.
- The video must be **portable**: it has to play on the rendered gist URL
  (or the local file path) without depending on the dev server. Use MP4
  H.264 + AAC by default; WebM is acceptable when H.264 is unavailable.
- Recording must respect user privacy and copyright: no real customer
  PII, no leaked secrets, no third-party UI captured without license.
  `scripts/ship-checklist.sh` runs a regex sweep for secrets and fails
  the run on hit.
- All `run-log.json` and `journey/*.json` must be co-located with the
  video in the same artifact directory; the video alone is not enough
  evidence.

## Workflow

### 0. Preflight

For every run, heal local skill drift before reading or writing artifacts:

```bash
bash ~/.agents/skills/talk-ship/check-canon.sh --heal --all --quiet
```

The canonical skill file is:

```text
~/.agents/skills/talk-ship/SKILL.md
```

`~/.claude/skills/talk-ship` and `~/.codex/skills/talk-ship` should be
treated as loaded copies/symlinks. Repo-local `*/talk-ship/SKILL.md`
files are not authoritative for self-referential talk-ship work.

If `talk-html` is also being used, heal it too:

```bash
bash ~/.agents/skills/talk-html/check-canon.sh --heal --all --quiet
```

### 1. Resolve the Ship

Create:

- `slug`: 3-5 kebab-case words, distinct from any `talk-html` slug.
- `prompt_summary`: one Chinese sentence, 200 chars max.
- `persona`: the real human role, not "user"（例：区域运营经理 / 32 岁 / 3 个子区域）。
- `core_claim`: the one sentence the journey must prove（例："运营能在 5 分钟内从登录看到自己的任务并完成一条派发"）。
- `stages`: a curated subset of `[Awareness, Consideration, Decision,
  Service, Loyalty]` plus any product-specific stage, each with a
  single observable user action.
- `canvas`: `web`（Playwright）/ `terminal`（tmux + asciinema）/ `mixed`（both）。
- `viewport` / `terminal_cols_rows` / `lang`。
- `artifact_dir`: a single directory that will hold `journey/`、`raw/`、
  `video/`、`evidence/`，外加顶层 `README.md` 和可选的 `index.jsonl`
  （复用 talk-html 的 recall 索引）。

### 2. Plan the User Journey

Before any recording, write `journey/persona.md` and `journey/stages.json`
so the run is auditable. 模板见 `templates/journey.md`。

```json
{
  "slug": "ceo-secretary-v3-ship",
  "persona": "区域运营经理 / 32 岁 / 3 个子区域",
  "core_claim": "运营能在 5 分钟内从登录看到自己的任务并完成一条派发",
  "stages": [
    {
      "id": "awareness",
      "name": "进入首页",
      "action": "打开登录页，扫码登录",
      "touchpoint": "https://app.example.com",
      "expectation": "首屏出现项目名 + 角色头像",
      "kpi": "首屏 LCP < 2.5s",
      "evidence": "raw/awareness-01.webm",
      "kind": "web"
    }
  ]
}
```

If the user gives an `eval.md` or a list of user stories, copy them into
the journey table first; do not skip the planning step. The journey is
the audit trail; the video is the proof of the journey.

### 3. Build / Inspect the Real Product

If a build is needed, run the project's own build command (`pnpm build`,
`next build && next export`, `make site`, etc.). If shipping a static
directory, serve it as-is. Do **not** write a mock UI for the recording.

If the user has forbidden copying old code, follow that — the recording
is of the *new* product, never a re-skinned clone.

### 4. Record Each Stage

Two drivers, both bundled:

- `scripts/record-playwright-journey.mjs` — Playwright with one viewport
  and a list of stages read from `journey/stages.json`. For each stage:
  `goto → act → screenshot → hold`. Output: per-stage `.webm` plus a
  single stitched `.webm` and a `run-log.json`.
- `scripts/record-tmux-journey.sh` — tmux + asciinema for the terminal
  side. Spawn the project in a tmux pane, send stage commands, record
  the whole pane to `.cast`, then export a per-stage MP4 via
  `asciinema-agg` (or `agg`) if available, or to `.gif` otherwise.

Each stage is recorded in a single take, with a fixed start cue (a
visible header on the canvas) and a fixed end cue (an explicit "stage
done" frame in the canvas). Failures stop the run; the run-log records
the offending stage and a screenshot for debugging.

The user may invoke the skill in `mixed` canvas mode: web stages use
the Playwright driver, terminal stages use the tmux driver, and the
stitcher aligns both onto a single timeline by stage order and start
time.

### 5. Stitch and Encode

Use `scripts/stitch-video.sh` to:

1. Concatenate per-stage videos in journey order.
2. Burn in the stage name + persona as a top-left text overlay
   (drawtext).
3. Trim head/tail silence (detect via `silencedetect`).
4. Encode to MP4 H.264 + AAC, with a `slow` preset for small filesize
   and a `+faststart` flag for web streaming.
5. Generate `contact-sheet.png`（4×4 grid of stage posters，缺位也要
   占位，不能留白）and `poster.jpg`（first non-blank frame）.

### 6. Ship Checklist

Run `scripts/ship-checklist.sh`, which checks:

- [ ] Every stage in `journey/stages.json` has a non-empty `evidence` path.
- [ ] Every `evidence` file exists and is `> 0` bytes.
- [ ] `video/final.mp4` plays (`ffprobe` exit 0, duration > 0).
- [ ] `video/contact-sheet.png` shows `≥ 1` non-blank stage.
- [ ] The journey covers at least `Decision + Service` for ship runs.
- [ ] No real customer PII or leaked secrets in any evidence file
      (regex sweep against `SECRETS_PATTERNS`).
- [ ] Optional: a sibling `talk-html` run was either skipped by user,
      or completed, and the gist URL was recorded in `index.jsonl`.

Emit `evidence/ship-checklist.json` and a short Markdown summary that
ends with a single `result: PASS` or `result: FAIL` line. A failing
checklist blocks the ship handoff.

### 7. Hand Off

Default handoff is a folder:

```text
<artifact_dir>/
├── README.md                       # 这次 ship 的入口、claim、stages、链接
├── journey/
│   ├── persona.md
│   ├── stages.json
│   └── stages.md                   # 同 stages.json 的人类可读版
├── raw/
│   ├── awareness-01.webm
│   ├── decision-01.webm
│   └── ...
├── video/
│   ├── final.mp4
│   ├── contact-sheet.png
│   └── poster.jpg
├── evidence/
│   ├── run-log.json
│   ├── ship-checklist.json
│   └── ship-checklist.md
└── index.jsonl                     # 可选：复用 talk-html 索引
```

Then:

- Run `talk-html` to fold the journey into a shareable one-pager（or
  skip if the user said "no gist"）。
- Run `recall.sh` from `talk-html` to confirm the index row is recorded.
- Run `bash ~/.agents/skills/talk-ship/check-canon.sh --heal --all --quiet`
  on the way out so the next run is clean.

## Reusing talk-html building blocks

The talk-ship skill **imports** talk-html's:

- `record-to-gif.sh` — for an optional small GIF preview.
- `verify-evidence.sh` — to validate `run-log.json` provenance.
- `templates/skeleton.html` — to make the per-stage contact sheet into a
  human-readable page.
- `publish.sh` / `recall.sh` — only if folding into a talk-html page.

Do not duplicate those scripts. Source them by reference from
`~/.agents/skills/talk-html/`. If the canonical path changes, update
`scripts/_imports.sh` accordingly. The talk-html and talk-ship skills
evolve together: any talk-html change that affects a shared file must
be mirrored in `scripts/_imports.sh`.

## Quick start

```bash
# 1. heal canon
bash ~/.agents/skills/talk-ship/check-canon.sh --heal --all --quiet

# 2. plan
mkdir -p ~/ship-runs/ceo-v3/journey ~/ship-runs/ceo-v3/raw ~/ship-runs/ceo-v3/video
cp ~/.agents/skills/talk-ship/templates/journey.md ~/ship-runs/ceo-v3/journey/stages.md
# edit journey/stages.md and journey/persona.md, then convert to stages.json

# 3. record (web)
BASE_URL=https://staging.app.example.com \
JOURNEY=~/ship-runs/ceo-v3/journey/stages.json \
OUT_DIR=~/ship-runs/ceo-v3 \
node ~/.agents/skills/talk-ship/scripts/record-playwright-journey.mjs

# 4. stitch
bash ~/.agents/skills/talk-ship/scripts/stitch-video.sh \
  --journey ~/ship-runs/ceo-v3/journey/stages.json \
  --raw-dir ~/ship-runs/ceo-v3/raw \
  --out-dir ~/ship-runs/ceo-v3/video

# 5. checklist
bash ~/.agents/skills/talk-ship/scripts/ship-checklist.sh \
  --journey ~/ship-runs/ceo-v3/journey/stages.json \
  --video-dir ~/ship-runs/ceo-v3/video

# 6. (optional) fold into talk-html
bash ~/.agents/skills/talk-html/publish.sh \
  --html ~/ship-runs/ceo-v3/release.html
```

## Failure modes

- **Build fails before stage 1.** The skill stops. The run log records
  the failure and a screenshot of the last good frame.
- **Stage 1–3 of 5 fails.** The skill records what it has, marks the
  failing stage as `unrecorded`, and asks the user how to proceed
  (`retry stage N`, `rebuild`, `abort`).
- **Secrets detected in evidence.** `ship-checklist.sh` exits non-zero.
  The run is dead until the offending file is regenerated without the
  secret. The README must list the redacted file and the redaction rule.
- **Video > 50 MB.** Re-encode with `crf=28` and `preset=slow`, or split
  into multiple parts. The skill does not silently upload 200 MB videos.
- **Canvas mismatch (web vs. terminal).** `mixed` runs must declare
  stage `kind` explicitly. If a stage is declared `web` but the driver
  is `tmux`, the stitcher drops the stage and flags it in the checklist.

## Out of scope

- Live streaming. talk-ship is a one-take recording, not a broadcast.
- Marketing polish / trailers with no real product capture. Use a video
  editor.
- Animated explainers / motion graphics. Use a motion-design tool.
- Unit / integration tests. Use `tdd` / `qa`.
- Pure data pipelines / batch jobs. Record a single run, not a schedule.
