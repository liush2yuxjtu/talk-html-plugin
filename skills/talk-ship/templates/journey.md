# User Journey — <slug>

> One Chinese sentence: 这次 ship 要让谁在多短时间内、用什么动作、达成什么结果？

## Persona

- 角色: <例：区域运营经理>
- 年龄 / 资历: <例：32 岁 / 3 个子区域>
- 设备 / 浏览器: <例：Chrome macOS 14, iPad Safari 17>
- 关键动机: <例：缩短派单到执行的时间>
- 主要痛点: <例：登录后看不到自己的任务，需要切 3 个页面>

## Stages

每个 stage 至少包含：可观察动作、触点、期望、证据路径。

| # | Stage | Action | Touchpoint | Expectation | KPI | Evidence | Kind |
|---|---|---|---|---|---|---|---|
| 1 | Awareness | 打开登录页 | https://app.example.com | 首屏出现项目名 + 角色头像 | LCP < 2.5s | raw/awareness-01.webm | web |
| 2 | Consideration | 浏览产品概览 | https://app.example.com/overview | 出现「我的子区域」卡片 | 卡片 3s 内可见 | raw/consideration-01.webm | web |
| 3 | Decision | 派发一条任务 | https://app.example.com/dispatch | 派发成功 toast | round-trip < 1.5s | raw/decision-01.webm | web |
| 4 | Service | 执行人接单 | https://app.example.com/task/<id> | 状态变为「执行中」 | 状态更新 < 1s | raw/service-01.webm | web |
| 5 | Loyalty | 提交反馈 | https://app.example.com/feedback | 反馈入库，弹「已收到」 | 写入 < 800ms | raw/loyalty-01.webm | web |
| 6 | Ops CLI | 查看派发日志 | `tail -n 200 logs/dispatch.log \| jq` | 出现本次派发记录 | 1s 内出现 | raw/ops-01.cast | terminal |

## Stages JSON (对应 `journey/stages.json`)

```json
{
  "slug": "<slug>",
  "persona": "<persona 描述>",
  "core_claim": "<一句话 claim>",
  "stages": [
    {
      "id": "awareness",
      "name": "进入首页",
      "action": "打开登录页",
      "touchpoint": "https://app.example.com",
      "expectation": "首屏出现项目名 + 角色头像",
      "kpi": "首屏 LCP < 2.5s",
      "evidence": "raw/awareness-01.webm",
      "kind": "web"
    }
  ]
}
```

## Anti-patterns

- **A stage with no observable action.** 例：「体验产品」。补一个具体动作。
- **A stage whose `evidence` is just a stub route.** 把 `evidence` 标为 `unrecorded` 并在 `ship-checklist.md` 里说清楚。
- **A stage with kind `web` but the recording is terminal.** 改 `kind: terminal` 或改 driver。
- **A stage with no persona.** 旅程不写 persona 等于在写自己，不是写用户。
