# Example — release-checklist output

> 真实一次 ship 的 ship-checklist.md 大概长这样。

```markdown
# ship-checklist

- [x] journey_present — stages.json is valid
- [x] stage_evidence — all 6 stages have non-empty evidence
- [x] mp4_plays — final.mp4 plays, duration=58.4s
- [x] contact_sheet — contact-sheet.png is 218377 bytes
- [x] covers_decision_and_service — decision=1 service=1
- [x] secrets_clean — no leaked secrets in evidence
- [x] talk_html_gist — sibling gist: https://gist.htmlpreview.cc/?<id>
```

result: PASS

---

## FAIL 案例

```markdown
# ship-checklist

- [x] journey_present — stages.json is valid
- [ ] stage_evidence — 4 / 6 stages have evidence on disk
  - missing: raw/loyalty-01.webm
  - missing: raw/ops-01.cast
- [x] mp4_plays — final.mp4 plays, duration=37.2s
- [ ] contact_sheet — contact-sheet.png is suspiciously small (1203 bytes)
- [x] covers_decision_and_service — decision=1 service=1
- [x] secrets_clean — no leaked secrets in evidence
- [x] talk_html_gist — no sibling talk-html gist (warn-only)
```

result: FAIL

行动：

1. 重录 `loyalty` 和 `ops` 两个 stage，补 `.webm` / `.cast`。
2. 重新跑 `stitch-video.sh` 覆盖 `final.mp4` 和 `contact-sheet.png`。
3. 重新跑 `ship-checklist.sh` 直到 result: PASS。
