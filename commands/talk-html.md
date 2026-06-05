---
description: Router for talk-html. Look at the page topic, infer the artifact_type from skills/talk-html/role-routing.csv, then dispatch to /talk-ux, /talk-ceo, /talk-data, /talk-reviewer, /talk-cto, /talk-qa, /talk-docs, or /talk-legal. For ship-bound end-to-end user journey recordings, dispatches to /talk-ship. Use when the user says talk-html, 用 html 解释, 做成一页, make a page, publish as gist, or asks to render something for a specific audience. Pass --image to auto-illustrate the page (配图) after publishing, via the bundled gpt-image + browse skills.
---

## `--image` 标志 — 发布后自动配图

`/talk-html --image`（也接受 `配图` 字样）在正常路由 + 渲染 + 发布之后多走一步：
把刚发布的公开页面链接喂给 ChatGPT，自动生成一组配图，嵌回页面再重新发布、打开。

机制全部写在 `skills/talk-html/SKILL.md` 的「`--image` 模式」一节，复用本插件自带的
`skills/gpt-image/`（生成+下载）与 `skills/browse/`（驱动 chatgpt.com）。三条铁律：
**开新对话 · 只发一句带公开链接的 prompt（`帮我生成一组配图：<url>`）· 下载全部**。
配图是增强而非发布前置闸门——失败时保留无图版本，绝不手绘/伪造替代图。

```
                        /talk-html  (router)
                              │
                              ▼
                  ┌── infer artifact_type ──┐
                  │  (from page topic)      │
                  └────────────┬────────────┘
                               │
       ┌───────────┬───────────┼───────────┬───────────┐
       ▼           ▼           ▼           ▼           ▼
  /talk-ux    /talk-ceo   /talk-data /talk-reviewer /talk-cto
       │           │           │           │           │
       └────┬──────┴────┬──────┴────┬──────┴────┬──────┘
            ▼           ▼           ▼           ▼
       /talk-qa   /talk-docs  /talk-legal   /talk-ship
            │           │           │           │
            └───────────┴─────┬─────┘           │
                              │                 │
                              ▼                 ▼
                    skills/talk-html     skills/talk-ship
                    (静态页引擎)         (端到端录像引擎)
                    preflight → resolve   persona + stages
                    → template            → Playwright / tmux
                    → real-content        → MP4 + contact sheet
                      grounding           → fold into talk-html
                    → embed real          → publish → recall
                      recording
                    → publish → recall
```

# /talk-html — 角色路由

`/talk-html` 本身不渲染页面。它做一件事：**先决定这页是给谁看**，再分派到对应的 role 子命令。
插件现在捆绑两台引擎：8 个 role 子命令共用 `skills/talk-html`（静态页 + 真内容 grounding + 嵌入真 recording），
ship-bound 端到端录像走 `skills/talk-ship`（Playwright / tmux 抓 persona + stages → MP4 + contact sheet，再折叠回 talk-html 一页）。

子命令负责锁住三件不可让步的东西：
1. **必看 proof 形态** — `who_must_see` 这一栏的人**只接受**这种证据（reviewer 只读 diff；UX 只看 recording；perf 只看 benchmark chart）。
2. **build / eval 工具集** — 怎样把 proof 真的造出来、并用第三方工具机器化判定通过/不通过。
3. **deterministic gate** — pass/fail 阈值，写在文档里、不靠人感觉。

子命令在锁完上面三件事后，统一 defer 给 `skills/talk-html/SKILL.md` 完成 preflight、模板选择、真实内容 grounding、非静态 embed、发布、回看。

## 路由规则

按以下顺序判断：

1. **用户明确指定角色** —— 比如「给 CEO 看的一页」「让 reviewer 收下这个 diff」「我要给 DBA 看 migration」——直接跳到对应 role 命令，不再做 artifact 推断。
2. **从对话内容推断 artifact_type** —— 读最近的消息、被引用的文件、被运行的命令。匹配 `skills/talk-html/role-routing.csv` 第一列 `artifact_type`。
3. **CSV 的 `role_command` 列就是分派目的地**。

## artifact_type → role_command 速查

读权威表请用：

```bash
cat ${CLAUDE_PLUGIN_ROOT}/skills/talk-html/role-routing.csv
```

下面是按角色聚合的快速索引（同样的数据，按目的地分组）：

| Role 子命令 | 覆盖的 artifact_type |
|---|---|
| `/talk-ux` | UI screen · Interactive web UI · Design system component · Localization · Accessibility · Mobile app · Visual asset · Email template |
| `/talk-ceo` | Release candidate · Video/motion asset · Payment / checkout flow |
| `/talk-data` | Database migration · Data pipeline · Analytics dashboard · AI/ML model change |
| `/talk-reviewer` | Code change · API change |
| `/talk-cto` | Performance change · Web performance · Architecture change · Deployment · Incident fix |
| `/talk-qa` | Interactive TUI · CLI output · Bug fix · Test result · Permission / admin flow |
| `/talk-docs` | Documentation |
| `/talk-legal` | Security fix · Legal/compliance copy |
| `/talk-ship` | ship-bound / 端到端 ship 录像 |

## /talk-ship 子命令

当 artifact_type 是 **ship-bound / 端到端 ship 录像**（典型触发词：「ship it」「录个端到端 demo」「端到端跑一遍」「GA 录屏」「上线前录一下」「release demo」「journey video」），路由直接把控制权交给 `/talk-ship`，
不再走 8 个 role 子命令。原因：ship proof 的形态是 **persona + stages + 真 user journey 录像 + contact sheet + checklist**，不是单页静态文字。
完整工作流见 `commands/talk-ship.md`；talk-ship 跑完会把 MP4 / contact sheet / checklist 折叠进 talk-html 一页作为最强证据。

## 多角色情况

一页可以同时是几个 artifact_type（典型例：**API change + DB migration**）。这时不是平均化成一页：

- 主路由：依首要受众挑一个 role 命令为主（reviewer 优先于 DBA，因为代码变更先于落库）。
- 副录：在主页面里补一节「同一证据给另一受众的视角」，分两条 evidence track，**不要**糅成一段。

## 模糊情况

仅当下列条件**同时**成立时才反问用户，否则直接做合理推断：

1. 对话里没有可识别的 artifact_type；
2. 没有受众线索；
3. 现成 fallback（默认 `/talk-reviewer` 用于代码、`/talk-ux` 用于 UI）会得到结构性错误的页面。

否则：选最近一个 reasonable role，在生成的页面顶部用一行小字说明你按 `<artifact_type>` 处理；用户能在浏览器里立刻看到判断对不对。

## 不做的事

- 不渲染最终 HTML（那是 `skills/talk-html` 的活）。
- 不绕过子命令直接 publish。
- 不替换子命令里写死的 gate 阈值——那是该角色的契约。
- 不在 artifact_type 不明时主动 mock 内容；先按 `skills/talk-html` 的「real content not drawn demos」原则去仓库里找真实素材。

## 与 `skills/talk-html` 的关系

`commands/` 决定**给谁看、要什么 proof、用什么 gate**。
`skills/talk-html/SKILL.md` 决定**怎么把页面真造出来**（preflight 自愈、模板、源头校验、嵌入真 video/GIF、publish、recall）。

路由层不重复 skill 的规则，子命令也不重复路由层。
