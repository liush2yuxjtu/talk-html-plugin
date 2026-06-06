---
description: Run or report a serious evidence-first QA pass with a full QA matrix, snapshots, a review HTML gallery, bug-fix reruns, global design critique, and a talk-html evidence report. Use for /talk-qa, full QA list/table, release readiness, regression proof, before-after fix evidence, permission/admin flow, "not just login/signup", design QA, snapshot gallery review, or Chinese QA report.
---

```
   /talk-qa
       │
       ├── controller: skills/talk-qa/SKILL.md
       │       ├── list full QA matrix / tabular
       │       ├── run every row and take snapshots
       │       ├── generate snapshot review gallery HTML
       │       ├── fix bugs found by QA
       │       ├── clear stale snapshots and rerun after fixes
       │       ├── append newly discovered QA rows
       │       ├── record global MP4 + contact sheet when interaction-heavy
       │       ├── audit MP4 anti-patterns instead of hiding limitations
       │       └── return only when all QA rows pass or a blocker/user stop appears
       │
       ├── routes:
       │       ├── design/UX findings       → design:design-critique
       │       ├── final Chinese one-pager  → skills/talk-html
       │       ├── ship-bound journey proof → skills/talk-ship, then skills/talk-html
       │       ├── browser/visual QA        → browse / frontend testing skill
       │       └── issue filing             → qa issue-filing skill
       │
       └── render:
               QA evidence bundle + gallery path → skills/talk-html/SKILL.md
```

# /talk-qa — full QA loop with snapshot gallery

## Contract

`/talk-qa` is not a shortcut for "open the login page and call it done".

It must either:

1. produce a full QA matrix without action when the user asks for plan-only; or
2. run the matrix, capture snapshots, generate a review gallery, fix bugs in a
   loop when allowed, run global design critique, and report with real evidence.

If only `/login` and `/signup` were checked, label the result as:

```text
auth-screen smoke test only
```

Do not call that full QA.

If a global video does not reach the final result, label it as:

```text
global mp4 smoke evidence only
```

Do not call that release-ready video evidence.

Bad example: 没有等到最终 assistant answer 就停止测试。

## Main Loop

```text
while true:
  list full QA matrix / tabular
  run full QA and take snapshots for every visual QA row
  build or refresh the local snapshot gallery HTML
  record global MP4 + contact sheet for interaction-heavy flows
  audit MP4 anti-patterns: too short, no final result, no timing, no recovery,
    desktop-only, localhost-only after production was requested
  wait for the final assistant answer before using stop/cancel, unless a real
    timeout or external blocker is recorded
  fix any issues found by QA, if fixes are allowed
  if any fixes were made:
    clear stale active snapshots
    run full QA again and take fresh snapshots after fix
  append newly discovered QA rows
  report current iteration to the user with evidence
  if all QA rows pass:
    return to the user
  else:
    continue
```

Stop only when all rows pass, the user asked for no action/report-only, a real
blocker requires user input, or the user says stop.

## Snapshot Review Gallery

The local review HTML must include:

- one card per QA row;
- snapshot image or terminal/log proof per card where possible;
- row status, scenario, expected result, actual result, and evidence path;
- a text input or textarea for reviewer notes on each image card;
- a global copy button that copies all statuses and reviewer notes;
- embedded global MP4, contact sheet, metadata, and anti-pattern verdict when a
  global video is part of the QA evidence;
- readable Chinese labels and mobile-safe layout.

## Report Handoff

After evidence exists, hand off to `skills/talk-html/SKILL.md` with:

- QA matrix status;
- snapshot gallery local path;
- findings and fixes;
- before/after proof;
- global MP4 verdict: full workflow evidence, smoke evidence only, blocked, or
  not applicable;
- global `design:design-critique` summary;
- limitations and blocked rows;
- publish URLs when publishing is allowed.
