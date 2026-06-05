---
name: Feature request
about: New role, new engine, new proof modality, or new CLI surface
title: "[feat] "
labels: ["enhancement", "needs-design"]
assignees: []
---

## What you want

<!-- one paragraph, plain language. e.g. "I want a /talk-pm role for product managers — proof is burndown chart + scope-change log" -->

## Why it earns a role (not a flag on an existing role)

<!-- 1-2 sentences. cite the proof-modality contract. if the new role's audience is a NEW who_must_see that the existing 8 + talk-ship don't cover, it's a real role. if not, suggest the existing role + a new artifact_type row in role-routing.csv instead. -->

## Proposed contract (fill in, copy from role-routing.csv header)

| column | value |
|---|---|
| `artifact_type` | <!-- e.g. "Bug fix" or "On-call handoff" --> |
| `who_must_see` | <!-- e.g. "On-call engineer" --> |
| `role_command` | <!-- e.g. "/talk-oncall" --> |
| `visual_proof_to_build` | <!-- e.g. "incident timeline + before/after metrics" --> |
| `build_tools` | <!-- comma-separated --> |
| `programmatic_evaluation_tools` | <!-- comma-separated --> |
| `deterministic_gate` | <!-- the pass/fail contract, e.g. "alerts resolved; SLO back within target" --> |
| `ci_output` | <!-- comma-separated artifact paths the CI must produce --> |

## Work you'd take on (or want)

- [ ] I'd PR the `commands/<role>.md` + `role-routing.csv` row + `skills/<role>/SKILL.md` myself
- [ ] I want a maintainer to take it
- [ ] Just an idea — no PR expected
