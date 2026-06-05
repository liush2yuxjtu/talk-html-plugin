# talk-html-plugin

> **Claude Code / Codex 插件 · 用 HTML 说话,不要用聊天滚动条 — `/talk-html` 路由器按观众分诊 + 9 个 role 命令 + `/talk-ship` 端到端用户旅程录制引擎 · zh-CN 渲染,evident-grounded,一键 gist 分享。**

<p align="center">
  <img alt="v0.4.0" src="https://img.shields.io/badge/version-v0.4.0-8a2a2a">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-2d6a3e">
  <img alt="claude code" src="https://img.shields.io/badge/claude--code-plugin-1a1a1a">
  <img alt="codex" src="https://img.shields.io/badge/codex-compatible-1a1a1a">
  <img alt="commands" src="https://img.shields.io/badge/commands-10-a26b00">
  <img alt="skills" src="https://img.shields.io/badge/engines-4-5a3a8a">
  <img alt="zh-CN" src="https://img.shields.io/badge/lang-zh--CN-8a2a2a">
  <img alt="engines" src="https://img.shields.io/badge/engines-Playwright_+_ffmpeg_+_asciinema-3a3a3a">
</p>

```
                /talk-html  (router)
                      │
                      ▼
          ┌── infer artifact_type ──┐
          └────────────┬────────────┘
                       │
   ┌─────────┬─────────┼─────────┬─────────┐
   ▼         ▼         ▼         ▼         ▼
/talk-ux  /talk-ceo /talk-data /talk-rev /talk-cto
   │         │         │         │         │
   └────┬────┴────┬────┴────┬────┴────┬────┘
        ▼         ▼         ▼         ▼
   /talk-qa  /talk-docs /talk-legal
                                │
                                └─ (ship-bound) ── /talk-ship
                                                     │
                ┌─ engines (both bundled) ────────────┘
                ▼                                    ▼
        skills/talk-html                    skills/talk-ship
        核心渲染管线                            端到端用户旅程录制
        preflight→resolve→template→         persona→stages→Playwright/
        grounding→embed→publish→recall      tmux→MP4 + contact sheet
```

## What's in this template / Quick tour

> 想用现成的 / 想 fork 改 / 想"装上就能用" —— 三条路径下面都接得上。

装上 `talk-html-plugin` 之后你直接得到：

- **10 个 slash 命令** —— `/talk-html` 路由器 + 8 个 role 命令(`/talk-ux / talk-ceo / talk-data / talk-reviewer / talk-cto / talk-qa / talk-docs / talk-legal`)+ `/talk-ship` ship 录制。详细见 [§命令](#命令)。
- **2 套引擎** —— `skills/talk-html/`(静态页渲染 + 真内容 grounding + 嵌入真 recording + gist 发布回看)与 `skills/talk-ship/`(Playwright / tmux + asciinema 端到端 user journey 录制)。详细见 [§Two-engine structure](#two-engine-structure)。
- **可选配的 `skills/gpt-image/`** —— `/talk-html --image` 自动给发布页面配一组图(发到 ChatGPT 让它读页 → 生图 → 嵌回 → 重发),由 plugin 自带的 browse daemon 驱动。
- **role-routing 权威表** —— `skills/talk-html/role-routing.csv` 是 artifact_type → 角色 → 必看 proof → build/eval/gate 的契约源。改这一张表,所有 role 命令的契约一起更新。详细见 [§路由数据源](#路由数据源)。
- **5 endpoint × 2 engine = 6 直接软链** —— fresh install 时 `install.sh` 把 `~/.claude / ~/.codex / ~/.agents` 三个路径各建 2 条 symlink,全部 2-hop direct 指向 `PLUGIN_DEST/skills/{talk-html,talk-ship}/`,无 3-hop 链、无目录复制。
- **CI 兜底** —— `.github/workflows/ci.yml` 5 个 job 验 shell parse / node parse / json parse / role-routing.csv 闭合集 / install.sh 引擎完整性,PR 提上来自动跑。

落地页（GitHub Pages）：<https://liushiyumath.github.io/talk-html-plugin/>

## 一行安装

```bash
curl -fsSL https://raw.githubusercontent.com/LiuShiyuMath/talk-html-plugin/main/install.sh | bash
```

这会装三份东西，相互独立、各自 idempotent：

- 核心 skill → `~/.claude/skills/talk-html/`（保留原来的 `/talk-html` 入口与 publish/recall 流水线）
- 插件路由 + 10 个斜杠命令 + 两套引擎 → `~/.claude/plugins/talk-html-plugin/`
- talk-ship 独立软链 → `~/.claude/skills/talk-ship` 与 `~/.codex/skills/talk-ship`（fresh install 时自动建好，指向同一份 `skills/talk-ship/`）

## 命令

| 命令 | 给谁看 | 必看 proof |
|---|---|---|
| `/talk-html` | （路由器，按 artifact_type 自动分派） | — |
| `/talk-ship` | ship-bound：Founder / Release Manager / 真实用户 | 端到端 user journey MP4 + contact sheet |
| `/talk-ux` | Designer / UX / Product / a11y / brand / lifecycle | 截图对比 OR GIF/MP4 交互录像 |
| `/talk-ceo` | CEO / Product Owner / Release Manager / Finance / Marketing | 端到端 demo 录像 + 真实结果 |
| `/talk-data` | DBA / SRE / Data Engineer / Analyst / ML Engineer | schema diff / lineage / metric / eval 表 |
| `/talk-reviewer` | Code Reviewer / Tech Lead / API reviewer | PR diff / API contract diff |
| `/talk-cto` | Architect / SRE / Performance / Incident Commander | benchmark / Lighthouse / diagram / health / timeline |
| `/talk-qa` | QA / Bug Reporter / Release Manager / Support | before-fail + after-pass / TUI 录像 / matrix |
| `/talk-docs` | Docs Reviewer / Developer User | rendered docs preview |
| `/talk-legal` | Security Reviewer / Legal / Compliance Reviewer | scan report + sanitized exploit / 必需条款 checklist |

## Two-engine structure

talk-html-plugin 装两套引擎，按「这页的产物形态」分发：

- `skills/talk-html/` —— **核心渲染管线**。一页式输出（recap / postmortem / status board / decision log / 给特定角色看的 one-pager）。`/talk-html` 路由器先按 `artifact_type` 派给 role 命令（/talk-ux、/talk-ceo …），所有 role 命令最终都 defer 到这个 skill 跑 preflight → resolve → template → real-content grounding → embed → publish → recall。
- `skills/talk-ship/` —— **端到端用户旅程录制**。要 ship 一个新页面、新功能、新版本给真实用户看时，用 `/talk-ship`：定义 persona + stages，跑 Playwright（浏览器）或 tmux + asciinema（终端），把 capture 拼成 MP4 + contact sheet，再折回 talk-html 一页做最强证据。

**路由**：`/talk-html` 看到 `artifact_type` 命中「ship-bound 端到端用户旅程」就直接转给 `/talk-ship`，其余命中对应 role 命令。`/talk-ship` 的产物（MP4 + contact sheet）本身也是 talk-html 一页可以吃下的最强证据，所以这两个引擎是一对上下游：talk-ship 录，talk-html 装订。

## 它做什么

并行开着好几个 Claude 会话时，agent 产出的 HTML 一份份散落在 `~/.claude/jobs/`、worktree、`/tmp` 里。每份刚做出来都有用，隔几天就忘了从哪儿来。talk-html-plugin 把四件事收进一个插件：

1. **分诊** — `/talk-html` 看你在干什么，先决定页面是给谁看的，再分派到对应 role 命令；ship-bound 时转给 `/talk-ship` 走端到端录制引擎。
2. **证据契约** — role 命令与 `/talk-ship` 各自锁死了「这个角色只接受哪种 proof」「该用什么工具机器化判定 pass/fail」。
3. **沟通** — 把长回答渲染成有版式、能读的一页 HTML（zh-CN）。
4. **留存与回看** — 本地预览满意后，一键发布到 gist，凭关键词从本地索引（`~/.claude/talk-html/index.jsonl`）翻回来。

输出语言固定为简体中文；只有结构性元数据、文件路径、代码片段保留英文。

## 路由数据源

完整 artifact_type → 角色 → 必看 proof → build/eval/gate/CI artifact 映射存在：

```
skills/talk-html/role-routing.csv
```

路由层（`commands/talk-html.md`）和每个 role 命令都引用这一张表。改了映射，所有 role 命令的契约一起更新。

## 触发词

- 路由：`/talk-html`、`用 html 解释`、`做成一页`、`推到 gist`、`html 回看`、`talk in html`、`make a page out of this`、`give me an html version`。
- ship-bound 直达：`/talk-ship`、`ship it`、`准备上线`、`ship 前录一下`、`录一段用户旅程`、`拍个 ship 视频`、`端到端跑一遍`、`录个端到端 demo`。
- 角色直达：`/talk-ux`、`/talk-ceo`、`/talk-data`、`/talk-reviewer`、`/talk-cto`、`/talk-qa`、`/talk-docs`、`/talk-legal`，或对话里说「给 reviewer 看」「给 CEO 一页」「给数据团队看」之类。

## 仓库结构

```
talk-html-plugin/
├── .claude-plugin/
│   └── plugin.json                  # 插件元数据
├── commands/                        # 斜杠命令（路由器 + 8 个 role + /talk-ship）
│   ├── talk-html.md
│   ├── talk-ship.md
│   ├── talk-ux.md
│   ├── talk-ceo.md
│   ├── talk-data.md
│   ├── talk-reviewer.md
│   ├── talk-cto.md
│   ├── talk-qa.md
│   ├── talk-docs.md
│   └── talk-legal.md
├── skills/
│   ├── talk-html/                   # 核心渲染管线（被所有 role 命令 defer）
│   │   ├── SKILL.md
│   │   ├── role-routing.csv         # 路由权威表
│   │   ├── publish.sh
│   │   ├── recall.sh
│   │   └── templates/
│   │       └── skeleton.html
│   └── talk-ship/                   # 端到端用户旅程录制（被 /talk-ship defer）
│       ├── SKILL.md
│       └── ...
├── install.sh                       # 一行安装：装 skill + 装 plugin + 建 talk-ship 软链
├── index.html                       # GitHub Pages 落地页
└── README.md
```

## 回看

```bash
bash ~/.claude/skills/talk-html/recall.sh            # 列出最近 20 份
bash ~/.claude/skills/talk-html/recall.sh <关键词>   # 按关键词在浏览器里打开
```

## 依赖

- 发布到 gist 需要 [GitHub CLI](https://cli.github.com/) 并已登录（`gh auth login`）。
- `jq`、`git`、`curl` —— macOS / Linux 上一般已就位。
- 各 role 命令推荐的 build/eval 工具按需安装（Playwright、Lighthouse CI、k6、VHS、Semgrep、Mermaid…）。
- `/talk-ship` 录制浏览器旅程需要 Playwright；录制终端旅程需要 tmux + asciinema（按需）。

## 从旧仓库迁移

旧仓库名是 `talk-html-skill`。本仓库重命名为 `talk-html-plugin`，并把：

- `skill/` 移到 `skills/talk-html/`
- 新增 `.claude-plugin/` 与 `commands/`
- 新增 `skills/talk-html/role-routing.csv`

`/talk-html` 入口语义保持不变——但现在它会先做路由，再交给 SKILL.md 渲染。`v0.4` 加入第二套引擎 `skills/talk-ship/`（独立软链 `~/.claude/skills/talk-ship` 与 `~/.codex/skills/talk-ship`），专做端到端用户旅程录制。

---

本仓库的 `index.html` 就是 talk-html 自己产出的第一个 GitHub Pages 页面。
