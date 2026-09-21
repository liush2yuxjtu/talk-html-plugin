# AGENTS.md — WeChat HTML → RedNote Gallery

Scope: everything under `rednote-gallery/`.

## 1. Canonical sources

- Airtable `ChatGPT Work Hub → 每日小红书内容` is the canonical source for RedNote content, publication status, dates, and evidence.
- Airtable `Engineering Knowledge Base → WeChat HTML → RedNote 发布兼容规则 v1` is the canonical research record for platform rules.
- GitHub gallery files are a browseable mirror and test harness. Never treat a gallery card as proof that a platform publish happened.
- Never overwrite historical published content to make the gallery prettier. Add a new version or correct the canonical Airtable record with evidence.

## 2. State model: never collapse these states

Use explicit states and evidence:

1. `source-draft` — source content exists.
2. `html-rendered` — WeChat HTML payload generated.
3. `wechat-draft-saved` — WeChat draft/add or official editor save succeeded.
4. `wechat-draft-verified` — draft/get or official editor reopen confirms payload survived.
5. `wechat-publish-submitted` — freepublish/submit accepted a task.
6. `wechat-published` — publish status is 0 and a permanent article URL exists.
7. `rednote-derived` — RedNote text/assets derived from the source.
8. `rednote-published` — publication is evidenced in Airtable.

Never report an earlier state as a later state.

## 3. Official WeChat hard rules

Source docs:
- https://developers.weixin.qq.com/doc/subscription/api/draftbox/draftmanage/api_draft_add
- https://developers.weixin.qq.com/doc/subscription/api/material/permanent/api_uploadimage
- https://developers.weixin.qq.com/doc/subscription/api/public/api_freepublish_submit.html
- https://developers.weixin.qq.com/doc/subscription/guide/product/publish.html

Rules:
- Draft create endpoint: `POST /cgi-bin/draft/add`.
- Article title <= 32 Chinese characters; author <= 16; digest <= 120.
- `articles[].content` may contain HTML. WeChat strips JavaScript.
- Keep payload below 20,000 characters and below 1 MB. The current official page also contains a contradictory “2kb” phrase; do not hard-code a 2 KB limit without runtime verification.
- External body image URLs are filtered. Upload body images using `/cgi-bin/media/uploadimg`, then use the returned WeChat URL.
- Body image upload supports JPG/PNG under 1 MB.
- `news` cover uses a permanent `thumb_media_id`.
- `freepublish/submit` acceptance only means the publish job was submitted.
- A public publish is complete only when publish status is `0`; record the permanent article URL.
- Never expose access tokens, app secrets, authorizer tokens, cookies, or private QR/login data in the repository.

## 4. WeChat conservative HTML baseline

These are compatibility rules based on community testing. Keep them labelled as community guidance, not official guarantees.

- Publication payload should use inline `style`.
- Do not depend on `<style>`, CSS classes, CSS variables, pseudo-elements, media queries, JavaScript, iframe, video, animation, transform, or absolute/fixed positioning.
- Prefer a single-column block flow.
- Conservative tags: `section p span strong em h1-h6 blockquote ul ol li a img table hr sup sub`.
- Avoid depending on `gap`. If flex is used, the content must remain readable when flex-specific behavior is stripped.
- Avoid long same-tag/same-style single-child nesting chains. Keep nesting shallow, normally < 10 levels.
- Preview shell may use CSS/JS for developer convenience. The WeChat payload itself may not inherit those dependencies.
- Preview, export, and draft upload must all use the same payload generator.

Community references:
- https://github.com/aierwiki/wechat_platform_skills/blob/main/references/wechat_html_spec.md
- https://github.com/wechatjs/verify-article-structure-spec/blob/main/verify_article_structure.md
- https://github.com/sakuraoxo-clio/wechat-publisher
- https://wangruofeng007.com/blog/2026-07/feishu2wx-intro/
- https://github.com/EvoAI-li/md-to-weixin

## 5. Verification gates

Before claiming `html-rendered` PASS:
- payload contains no `script` or `style` tags;
- no external body image URL remains;
- title/author/digest limits pass;
- payload character and byte size are recorded;
- layout remains readable as plain single-column HTML.

Before claiming `wechat-draft-verified` PASS:
- save through official API or official editor;
- reopen via draft/get or official editor;
- compare key text blocks and image count;
- inspect mobile preview;
- record evidence and timestamp.

Before claiming `wechat-published` PASS:
- publishing was explicitly requested;
- query publish status until a terminal state;
- only status 0 is PASS;
- store permanent article URL as evidence.

## 6. RedNote derivation and gallery

- HTML is an authoring/preview source, not a native RedNote upload format.
- Derive RedNote output from the same canonical content: cover title, post body, tags, and optional image/long-image assets.
- The gallery only includes Airtable records whose canonical status is `已发布`, plus clearly labelled experiments.
- If an Airtable published record has incomplete text, show “正文尚未完整入库”; do not reconstruct or invent it.
- Gallery cards must preserve Airtable record IDs for provenance.
- New publish snapshots are append-only. Regenerate the gallery from Airtable instead of hand-editing old cards.

## 7. File layout

```
rednote-gallery/
  AGENTS.md
  README.md
  index.html
  posts/
    YYYY-MM-DD-slug/
      index.html              # browser preview shell
      wechat-payload.html     # conservative payload only
```

## 8. Current experiment

Source Airtable record: `recrxe7yqyc8ylK6r`
Title: 模型能力指数增长，企业却还是线性：因为少了两层系统
Date: 2026-09-21

Acceptance:
- gallery lists every current Airtable `已发布` record;
- current WeChat HTML preview opens on mobile and desktop;
- copy action copies only the conservative payload;
- any WeChat save/publish action is reported using the state model above.
