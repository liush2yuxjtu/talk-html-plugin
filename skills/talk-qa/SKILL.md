---
name: talk-qa
description: Evidence-first QA controller for the Talk HTML plugin. Use whenever the user asks for /talk-qa, talk-html-plugin:talk-qa, full QA matrix, release readiness, regression proof, before/after bug evidence, snapshot gallery review, "not just login/signup", design QA, UX QA, or a Chinese QA report. This skill lists the full QA matrix, runs every row with snapshots, builds a review HTML gallery with per-image text inputs and a global copy button, fixes bugs in a loop, reruns QA after clearing stale snapshots, and reports with talk-html evidence.
---

# talk-qa

This is the skill form of `/talk-qa`. Codex discovers skills from
`skills/<name>/SKILL.md`, while slash commands live under `commands/`. Keep this
skill and `commands/talk-qa.md` aligned.

## Purpose

Run serious QA that produces reviewable visual evidence. Do not accept "I
checked login and signup" as full QA.

Default workflow:

1. List the full QA matrix in tabular form before execution.
2. Implement the matrix as real checks and take snapshots for each visible row.
3. Build a local HTML snapshot gallery so the user can review every QA item.
4. If QA finds bugs and fixes are allowed, fix them, clear stale snapshots, and
   rerun the full QA matrix.
5. Append newly discovered QA rows when exploration reveals missing coverage.
6. Run global `design:design-critique` across product states.
7. When the flow is interaction-heavy, record a reviewable global MP4 plus a
   contact sheet and audit it against the Global MP4 Evidence Rules below.
8. Report with `talk-html` after evidence exists.

If the user says "show only", "no action", "plan only", or "matrix only", stop
after the matrix and do not run tools.

## Router

| User intent | Route |
|---|---|
| Full QA scope, looped QA, snapshot gallery, or "not just login/signup" | this skill |
| UI/UX critique across screens | `design:design-critique` |
| Final Chinese one-page report | `talk-html-plugin:talk-html` |
| Ship/demo/customer-facing journey proof | `talk-html-plugin:talk-ship`, then `talk-html-plugin:talk-html` |
| Browser screenshots and interaction QA | Browser / browse / frontend testing skill when available |
| Report-only with no fixes | this skill with fixes disabled |
| File durable issues from findings | QA issue-filing skill after repro is clear |

Use this order for serious product QA:

```text
talk-qa
  -> list full QA matrix / tabular
  -> run every QA row and take snapshots
  -> generate snapshot review gallery HTML
  -> fix any QA issues found
  -> clear stale snapshots and rerun full QA
  -> append newly discovered QA rows
  -> design:design-critique globally
  -> talk-html report with evidence
```

## Full QA Matrix Floor

At minimum, cover:

| Area | Required checks | Proof |
|---|---|---|
| App boot | routes, redirects, blank screen, framework overlay | route table + screenshot |
| Auth | logged out, valid login, invalid login, logout, protected routes | session matrix |
| Core workflow | primary user goal from first useful screen to result | steps + screenshots/video |
| Data states | loading, empty, success, partial, error, large data | state screenshots |
| Forms/composer | validation, submit, disabled, retry, keyboard behavior | interaction proof |
| Streaming/async | progress, long wait, timeout, cancellation, recovery | timing + video/log |
| Specialist/subflow | routing, delegated task, multi-step state | status proof |
| History/state | create, switch, restore, refresh, stale state | URL/state proof |
| Permissions/admin | allow/deny per role | access matrix + role evidence |
| Mobile/responsive | mobile, tablet, desktop, wide, keyboard pressure | viewport screenshots |
| UI/UX | hierarchy, spacing, contrast, focus, disabled/hover | design critique table |
| Accessibility | labels, focus order, keyboard nav, contrast | a11y checklist |
| API/network | success, error, timeout, malformed, slow network | API/log summary |
| Regression | previously fixed bugs remain fixed | fail-before/pass-after or replay proof |
| Build/static | lint, typecheck, build, tests, console health | command output |
| Global video evidence | reviewable MP4 of the primary journey, contact sheet, and anti-pattern audit | MP4 + contact sheet + verdict |
| Release readiness | blockers, severity, recommendation | final status table |

The matrix can add product-specific rows. If exploration discovers a missing
flow, append it to the active QA matrix and run it in the same loop.

## Bad Examples

Bad QA:

- only testing `/login` and `/signup`;
- testing only unauthenticated pages when the product is authenticated;
- saying "no console errors" without testing the main workflow;
- verifying only that the composer accepts text without sending a real message
  and waiting for the final assistant answer;
- 没有等到最终 assistant answer 就停止测试；
- showing only `after.png` for a bug fix;
- calling one happy-path run release-ready;
- producing a talk-html page with no real evidence;
- using design critique on one convenient screenshot while ignoring
  loading/error/mobile states.

Bad global MP4 evidence:

- recording only `/login` and `/signup` and calling it global QA;
- recording a video so short or fast that a human cannot review the states;
- showing a send action without waiting for the final user-visible result, then
  calling it a full workflow pass;
- stopping the MP4 before the final assistant answer and calling it release-ready
  evidence;
- showing a loading state without visible elapsed time, progress text, or timing
  metadata;
- skipping stop, cancel, retry, timeout, or recovery checks for async workflows;
- recording only desktop when responsive/mobile QA is in scope;
- recording localhost after the user asked for deployment or production QA;
- embedding an MP4 without a contact sheet, metadata, or QA-row mapping;
- using the MP4 as a replacement for per-row snapshots.

If only login/signup were tested, label the result exactly:

```text
auth-screen smoke test only
```

If the global video does not reach the final result, label it exactly:

```text
global mp4 smoke evidence only
```

## Main Loop

When the user allows execution, use this loop:

```text
while true:
  list full QA matrix / tabular
  run full QA and take snapshots for every visual QA row
  build or refresh the local snapshot gallery HTML
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

Stop the loop only when:

- all QA rows pass;
- the user asked for plan-only or report-only;
- a blocker requires user credentials, unavailable data, or an external decision;
- the user explicitly says stop.

Never hide failed or blocked rows. Mark each row as `pass`, `fail`, `blocked`,
or `not run`.

## Global MP4 Evidence Rules

Global MP4 is supporting evidence, not a substitute for the QA matrix or
per-row snapshots.

For interaction-heavy flows, generate:

- one MP4 that covers the primary journey from first useful screen through a
  user-visible result, or explicitly mark why it is only smoke evidence;
- a contact sheet sampled from the MP4;
- basic metadata: duration, resolution, source URL, and whether the run was
  localhost or deployed;
- a short timeline or QA-row mapping so the reviewer knows which moment proves
  which row;
- a verdict table that names anti-patterns found instead of hiding them.

For streaming or long-wait products, the MP4 should show:

- visible elapsed time or progress text;
- send-and-wait through final assistant result when release readiness is being
  claimed;
- enough wait time for the final assistant answer before stop/cancel is used;
- cancellation/stop behavior;
- retry or recovery behavior when the matrix includes error handling.

For production QA, a localhost MP4 is not enough. Record the deployed URL or mark
the production video row `blocked` with the account, credential, or environment
reason.

If the video is shorter than a human-reviewable walkthrough, lacks a final
result, or skips recovery states, do not call it release-ready evidence. It may
still pass as evidence that the MP4 artifact was produced, but the audit row must
state the limitation clearly.

## Snapshot Rules

Snapshots are first-class evidence.

- Take one snapshot per visible QA row and per important state change.
- Use stable filenames with row ids, for example
  `qa-03-core-workflow-desktop.png`.
- After a fix, clear stale active snapshots before rerunning. Keep a compact
  before/after bug-evidence record when needed, but the active gallery should
  show the current post-fix run.
- If a QA row is API-only or command-only, use a terminal/log snapshot or a
  clipped command-output panel in the gallery.
- If a row cannot produce a snapshot, mark why in the matrix.

## Snapshot Review Gallery HTML

Before the final talk-html report, generate a new local HTML review page for the
user. The page is for human QA review, not a polished marketing report.

Required gallery behavior:

- one card per QA row;
- each card shows status, row id, scenario, expected result, actual result, and
  evidence path;
- each visual card embeds the snapshot image;
- each image card has a text input or textarea for reviewer notes;
- there is a global copy button that copies all row statuses plus all reviewer
  notes into the clipboard;
- the page works locally without external JS;
- the page uses readable Chinese labels and supports mobile width;
- the page clearly labels `pass`, `fail`, `blocked`, and `not run`.
- when a global MP4 exists, the page embeds the MP4, its contact sheet, metadata,
  and the anti-pattern audit verdict.

Minimum HTML shape:

```html
<section class="qa-card" data-qa-id="qa-03">
  <h2>qa-03 Core workflow</h2>
  <p class="status">fail</p>
  <img src="snapshots/qa-03-core-workflow-desktop.png" alt="qa-03 Core workflow snapshot">
  <label>
    Reviewer note
    <textarea data-review-note data-qa-id="qa-03"></textarea>
  </label>
</section>
<button id="copy-all-review-notes">Copy all QA review notes</button>
```

The copy button should collect:

```text
qa_id:
status:
scenario:
evidence:
reviewer_note:
```

Use this gallery to let the user review each snapshot before or alongside the
final report.

## Reference Template · 参考模板

The single canonical QA-report template is:

```text
qa-artifacts/talk-qa-gallery-variants/4/3/4/template.html
```

Stacked Deck · 4.3.4 — a fan of evidence cards (active card lifted to the
top, gold glow), reviewer-note desk underneath, and an inline JSON editor
plus a `QA_RESULTS` array for hand-editing. Single file, no build, no
React. The reviewer opens the file, edits the array, refreshes.

It is also registered with `/web-artifacts-builder` as the canonical
template for any new QA-report artifact: when the user asks for a new
talk-qa report and the build is needed, scaffold the artifact from this
template rather than from the default Vite/shadcn init.

To open the template:

```bash
open qa-artifacts/talk-qa-gallery-variants/4/3/4/template.html
```

To scaffold a new artifact from it (web-artifacts-builder pattern):

```bash
# 1) copy the template into a fresh project dir
mkdir -p my-qa-report && cp \
  qa-artifacts/talk-qa-gallery-variants/4/3/4/template.html \
  my-qa-report/index.html
# 2) edit the QA_RESULTS array at the top of <script>
# 3) open my-qa-report/index.html — no build step
```

The template's data contract (top of the inline `<script>`):

```text
{ id, area, scenario, expected, actual, status: pass|fail|blocked|not-run,
  proof, note, accent, accent2, uiLabel }
```

`accent` / `accent2` / `uiLabel` are optional — they drive the mock-screenshot
gradient and the title-bar label so the user sees the final card shape
before real Playwright snapshots exist. Remove or replace them when real
images are ready.

## Fix Loop

When fixes are allowed:

```text
for each failed QA row:
  preserve repro and current evidence
  apply the smallest fix
  rerun that row first
  if the row passes:
    rerun the full QA matrix
    clear stale active snapshots
    take fresh snapshots
  else:
    keep fixing or mark blocked with reason
```

Do not broaden fixes beyond the reproduced failure. Do not convert a failing row
to pass without fresh evidence.

## Global Design Critique

Use `design:design-critique` after representative screenshots exist. Review the
whole product state set:

- logged-out first screen;
- authenticated empty state;
- active workflow;
- streaming/loading state;
- error/retry state;
- mobile with keyboard pressure;
- important admin/permission screens when relevant.

Design findings must enter the QA report with severity and recommendation. A
pretty login page cannot redeem a broken core workflow.

## Final Report

When reporting through `talk-html-plugin:talk-html`, include:

- first-screen release/QA claim;
- QA matrix with `pass` / `fail` / `blocked` / `not run`;
- link/path to the snapshot review gallery HTML;
- findings table with severity, repro, evidence, and fix status;
- before/after proof for bug fixes;
- screenshots/video/contact sheet for interaction-heavy claims;
- the global MP4 verdict: full workflow evidence, smoke evidence only, blocked,
  or not applicable;
- command output for build/lint/test/API checks;
- global design critique summary;
- limitations and blocked flows;
- `talk-html-meta` and `talk-html-evidence`;
- four URLs when published: `local`, `gist`, `raw`, `rendered`.

Do not publish if the user said local-only, no gist, or no publish.

## Related Files

- Command router: `commands/talk-qa.md`
- Report renderer: `skills/talk-html/SKILL.md`
- Ship journey proof: `skills/talk-ship/SKILL.md`
- Canonical QA report template (Stacked Deck · 4.3.4): `qa-artifacts/talk-qa-gallery-variants/4/3/4/template.html`
- `/web-artifacts-builder` registered template: same path, see "Reference Template" above
