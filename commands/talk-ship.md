---
description: Record a real, end-to-end user journey before ship — persona, stages, Playwright/tmux capture, stitched MP4, contact sheet, and a ship checklist. The strongest evidence /talk-html can fold into a release one-pager. Triggers include /talk-ship, ship it, 准备上线, ship 前录一下, 录一段用户旅程, 拍个 ship 视频, 端到端跑一遍, 录个端到端 demo, end-to-end demo, end-to-end recording, release demo, GA demo, journey video, ship video, ship proof.
---

```
   /talk-html  ─── artifact_type == ship-bound? ───────────► /talk-ship
       │                                                        │
       │ audience: Release Manager + Exec Sponsor + 真实终端用户   │
       │ must-see proof: 真实用户旅程录像（persona + stages）      │
       │   NOT 单屏截图, NOT storyboard PNG, NOT mock             │
       │ build tools: Playwright | tmux + asciinema | ffmpeg     │
       │ capture    : 浏览器 Playwright codegen / 终端 tmux rec   │
       │ stitch     : ffmpeg concat + 字幕 burn-in                │
       │ artifact   : journey.mp4 + contact_sheet.png +          │
       │              ship_checklist.md                           │
       │                                                            │
       │  /talk-ship ── evidence bundle ──► /talk-html 一页        │
       │              (video + contact sheet + checklist)            │
                                ↓
                       渲染由 skills/talk-html 完成
```

# /talk-ship — 上线前录一段真实用户旅程

## 受众原则

ship 一页的读者不是看 diff 也不是看 flamegraph —— 他们要的是「**真人在真产品上跑完一遍**」的证据。三类读者，各取所需：

- **Release Manager** — 要 ship checklist：每个 stage 录到没、关键事件触发没、回归路径覆盖没。
- **Exec Sponsor**（CEO / Founder / Product Owner）— 要 60 秒以内的端到端视频，开头 5 秒给结论、结尾 5 秒给风险。
- **真实终端用户**（被拉来当 persona 的人，或对标用户）— 要看得到自己的影子：persona 像不像、touchpoint 自不自然、KPI 是不是真的能拿到。

每类读者的「必看 proof」：

| 读者 | 必看 proof 形态 |
|---|---|
| Release Manager | ship_checklist.md（每 stage ✓/✗）+ ffprobe.json（fps/codec/duration 合规） |
| Exec Sponsor | journey.mp4（60s 内）+ contact_sheet.png（9–12 帧故事板） |
| 终端用户 | persona 卡片 + 真实 touchpoint 截图（每 stage 至少 1 张） |

## 触发与边界

**触发**（任一即进入）：

- "ship it"、"ship 前录一下"、"准备上线"、"拍个 ship 视频"
- "录一段用户旅程"、"end-to-end demo"、"release demo"、"GA demo"
- "录个端到端 demo"、"end-to-end recording"、"journey video"、"ship video"、"ship proof"

**不在 /talk-ship 范围**（请用别的 role）：

- 单元测试 / 集成测试报告 → 走 `/talk-qa` 或 `/talk-cto`
- 营销片花 / 动画解说 / 无真实产品录屏的 promo → 走 `/talk-html`（pitch 模板）或 HyperFrames
- 单屏 walkthrough（只录一个页面 / 一个 feature）→ 走 `/talk-ux` 截图
- 性能 / 架构 / 部署复盘 → 走 `/talk-cto`
- CEO 决策摘要（不录全程，只看结果）→ 走 `/talk-ceo`

边界判定：**至少 3 个 stage + 至少 1 次 persona 切换 + 真实产品（不是 mock）才进 /talk-ship**，否则退化到对应 role。

## 与 /talk-html 的关系

`/talk-html` 是 **入口 router**，`/talk-ship` 是它的 **dispatch target**：

- `/talk-html` 看到 `artifact_type = ship-bound`（用户要 GA、要 release、要 ship proof）→ 转交 `/talk-ship`。
- `/talk-ship` 产出的 **video + contact sheet + checklist** 本身就是 `/talk-html` 一页里 **最强的一类 evidence** —— 比静态截图、diff、metric 都更接近"上线了"这件事本身。
- 标准动作：`/talk-ship` 跑完拿到 `journey.mp4` + `contact_sheet.png` + `ship_checklist.md` → 再喂给 `/talk-html`（同 plugin）拼成 release one-pager。
- 反向不行：拿 `/talk-html` 输出的静态页当 ship proof 等于没录。

## 流水线（preflight → plan → capture → stitch → handoff）

1. **preflight** — 确认环境：产品 build 已起（dev / staging URL），Playwright + Chromium 可用，`ffmpeg` 在 PATH，`tmux` 可用（终端路径）。检查 `roles.csv` 里 artifact_type 路由到 `/talk-ship`。
2. **plan journey** — 写下：
   - **persona**（姓名 / 角色 / 痛点 / 设备）
   - **stages**（3–6 个，每个 stage：goal、touchpoint、expected KPI）
   - **KPI 收尾页**（最后一屏展示"我作为 persona 拿到了什么"）
3. **build / inspect product** — 必要时修 UI / 写 fixture 数据，确保 persona 一遍能跑通不撞 dead end。
4. **record each stage**：
   - **Web / 桌面**：`mcp__playwright__browser_navigate` → 操作 → 每 stage 收尾 `browser_take_screenshot` + 必要时 `browser_evaluate` 抓 KPI。
   - **终端 / CLI**：`tmux new-session -d -s ship` → `tmux send-keys` 操作 → `asciinema rec journey.cast`（或 `tmux capture-pane` 截关键帧）。
5. **stitch video**：`ffmpeg` 把每段 mp4 concat → 必要时加字幕 burn-in（ffmpeg drawtext）→ 输出 `journey.mp4`。同时用 ffmpeg 抽 9–12 帧拼 `contact_sheet.png`。
6. **ship checklist** — 写 `ship_checklist.md`：每 stage ✓/✗、KPI 是否触发、回归路径是否覆盖、未覆盖的 known gap。必跑 `ffprobe journey.mp4` 校验 fps/codec/duration。
7. **handoff** — 把 `journey.mp4` + `contact_sheet.png` + `ship_checklist.md` + `ffprobe.json` 喂回 `/talk-html`（同 plugin 的 router），由它渲染 release 一页推到 gist。本地预览后用 `open "$HTML_PATH"` 给用户看。

## 反模式

- 用 mock 数据录"假旅程" —— persona 一切就走通，不算 ship proof。
- 把 stage 录成 6 张静态截图拼起来 —— 必须 mp4 + 真实动作。
- 录完不上 `ship_checklist.md` —— 视频好看但无法对账，等于没录。
- 跳过 contact sheet —— 60s 视频 exec 不一定有时间看，contact sheet 是 5 秒兜底。
- 不做 ffprobe 校验直接发 —— 黑帧 / 掉 fps / 时长飘走会被 Release Manager 退回。
