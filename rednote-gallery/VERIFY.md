# Publishing Verification — RedNote + WeChat Official Account

This file defines the evidence required before an agent may claim that a RedNote/Xiaohongshu draft or a WeChat Official Account article has been prepared, saved, verified, or published.

The rule is simple: **state claims require platform evidence or deterministic artifact checks.** A preview is not proof of publication.

## 1. Shared verification model

Every run must record:

- source identifier and source version;
- generated artifact paths;
- deterministic local checks;
- platform state reached;
- evidence path / platform identifier;
- timestamp;
- PASS or FAIL.

Never collapse these states:

```text
source-draft
  -> derived
  -> locally-verified
  -> platform-draft-saved
  -> platform-draft-verified
  -> published
```

A later state may only be claimed when its own gate passes.

## CLI regression checks

Run the non-destructive public-CLI checks before changing the verifier:

```bash
python3 -m unittest discover -s rednote-gallery/scripts -p 'test_*.py' -v
```

These cover placeholder rejection, valid text, and whitespace-only padding. They do not save or publish platform drafts.

## 2. RedNote / Xiaohongshu draft verification

### 2.1 Draft generation PASS

A RedNote draft is `rednote-derived` only when all of these are true:

1. A source record/version exists.
2. `rednote-draft.md` exists and is non-empty.
3. The title exists and respects the current publishing workflow limit.
4. Body text is non-empty and contains no placeholder markers such as `TODO`, `TBD`, or `正文待补`.
5. The draft preserves provenance: source record ID/version is recorded.
6. The HTML preview, if present, is labelled **draft / not published**.
7. Any referenced image set exists and can be opened.

Run:

```bash
python3 rednote-gallery/scripts/verify-publishing.py \
  --rednote rednote-gallery/posts/<post>/rednote-draft.md
```

The script exits 0 only for PASS.

### 2.2 Browser draft-save PASS

If browser automation is used, `rednote-draft-saved` additionally requires:

1. authenticated RedNote/Xiaohongshu browser session;
2. title/body/images filled into the real platform editor;
3. platform draft-save succeeds;
4. reopening the platform draft shows the same title and expected image count;
5. evidence is saved without exporting cookies, QR payloads, or tokens.

Recommended evidence:

```text
timestamp
platform
draft identifier or stable editor URL when available
title hash / title length
body text length
image count
save-result screenshot
reopen-result screenshot
PASS/FAIL
```

### 2.3 RedNote publish PASS

`rednote-published` requires a real published note URL or platform note ID that can be reopened. A local gallery card, preview, or browser-filled form is not publication evidence.

## 3. WeChat Official Account verification

### 3.1 HTML payload PASS

Before touching WeChat, verify the payload:

- no `<script>` tag;
- no `<style>` dependency;
- inline styles only for publication-critical styling;
- no unsupported external body-image URLs;
- title <= 32 Chinese characters;
- author <= 16 characters when provided;
- digest <= 120 characters when provided;
- HTML < 20,000 characters and < 1 MiB;
- single-column reading order survives CSS loss;
- payload contains meaningful text.

Run:

```bash
python3 rednote-gallery/scripts/verify-publishing.py \
  --wechat rednote-gallery/posts/<post>/wechat-payload.html \
  --title '文章标题'
```

### 3.2 Real WeChat editor SAVE PASS

For browser mode, `wechat-draft-saved` requires evidence from the real `mp.weixin.qq.com` editor:

1. browser authenticated;
2. title present in the real editor;
3. main body present in the real ProseMirror/editor;
4. structural checks pass **before save**;
5. click `保存为草稿`;
6. WeChat returns an edit URL containing a real `appmsgid`;
7. UI reports `已保存` or an equivalent successful save state;
8. no visible title/body/cover/save error.

Record the `appmsgid`. It is platform evidence that the draft reached the WeChat backend.

### 3.3 WeChat draft REOPEN PASS

`wechat-draft-verified` is stronger than save:

1. reopen the saved draft by `appmsgid`, or reopen it from the official draft list;
2. verify title length/content;
3. verify body text length within expected tolerance;
4. verify structural blocks / image count survived;
5. save screenshot or machine-readable comparison result.

If security tooling prevents reading authenticated content, do **not** silently upgrade `wechat-draft-saved` to `wechat-draft-verified`. Keep the lower state and record the limitation.

### 3.4 WeChat publish PASS

Clicking `发表` is not enough.

- API path: only terminal `publish_status = 0` plus permanent article URL is PASS.
- Browser path: only a permanent published article URL / backend publication identifier that can be reopened is PASS.
- A submitted job, confirmation dialog, or editor navigation is not PASS.

## 4. Current verified example: 2026-09-21

Source: Airtable record `recrxe7yqyc8ylK6r`.

Title:

```text
模型能力指数增长，企业却还是线性：因为少了两层系统
```

Local/editor checks observed before save:

- title length: 25;
- body text length: 2,402;
- body HTML length in WeChat editor: 13,034;
- `<section>` count: 3;
- `<p>` count: 84;
- elements retaining inline `style`: 88.

Real WeChat save result:

- authenticated Grokbot browser reached the official account backend;
- `保存为草稿` was clicked;
- resulting edit URL contained `appmsgid=100000050`;
- editor reported `已保存`;
- no visible `请设置封面`, `标题不能为空`, `正文不能为空`, or `保存失败` error was observed.

Therefore the evidence-backed state is:

```text
wechat-draft-saved = PASS
wechat-draft-verified = NOT YET CLAIMED
wechat-published = NOT CLAIMED
```

## 5. Evidence storage

Store non-secret evidence under:

```text
rednote-gallery/evidence/YYYY-MM-DD.md
```

Never commit cookies, access tokens, app secrets, authenticated storage-state JSON, QR-code payloads, or browser profiles.

## 6. Required completion statement

Good:

```text
WeChat: wechat-draft-saved PASS, appmsgid=100000050.
Reopen verification was blocked, so wechat-draft-verified is not claimed.
```

Bad:

```text
WeChat published successfully.
```

when only a draft was saved.
