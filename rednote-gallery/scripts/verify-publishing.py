#!/usr/bin/env python3
import argparse
import re
from pathlib import Path

PLACEHOLDERS = re.compile(r"\\b(?:TODO|TBD)\\b|正文待补|待补充", re.I)

def fail(msg):
    print(f"FAIL: {msg}")
    return False

def verify_rednote(path: Path):
    if not path.is_file():
        return fail(f"RedNote draft missing: {path}")
    ok = True
    text = path.read_text(encoding="utf-8")
    if len(text.strip()) < 80:
        ok = fail("RedNote draft is too short") and ok
    if PLACEHOLDERS.search(text):
        ok = fail("RedNote draft contains placeholder text") and ok
    if "Source Airtable record:" not in text and "source" not in text.lower():
        ok = fail("RedNote draft has no provenance/source marker") and ok
    if ok:
        print(f"PASS: RedNote draft {path} ({len(text)} chars)")
    return ok

def verify_wechat(path: Path, title: str):
    if not path.is_file():
        return fail(f"WeChat payload missing: {path}")
    ok = True
    html = path.read_text(encoding="utf-8")
    lower = html.lower()
    byte_len = len(html.encode("utf-8"))
    if not html.strip():
        ok = fail("WeChat payload is empty") and ok
    if "<script" in lower:
        ok = fail("WeChat payload contains <script>") and ok
    if "<style" in lower:
        ok = fail("WeChat payload depends on <style>") and ok
    if len(html) >= 20000:
        ok = fail(f"WeChat HTML >= 20,000 chars: {len(html)}") and ok
    if byte_len >= 1024 * 1024:
        ok = fail(f"WeChat HTML >= 1 MiB: {byte_len}") and ok
    if title and len(title) > 32:
        ok = fail(f"WeChat title > 32 chars: {len(title)}") and ok
    for src in re.findall(r'<img[^>]+src=["\\\']([^"\\\']+)', html, flags=re.I):
        if src.startswith(("http://", "https://")) and "mmbiz.qpic.cn" not in src:
            ok = fail(f"External non-WeChat image URL: {src[:120]}") and ok
    text_only = re.sub(r"<[^>]+>", " ", html)
    text_only = re.sub(r"\\s+", " ", text_only).strip()
    if len(text_only) < 100:
        ok = fail("WeChat payload has too little readable text") and ok
    if ok:
        print(
            f"PASS: WeChat payload {path} "
            f"(title={len(title)} chars, html={len(html)} chars, bytes={byte_len}, readable={len(text_only)} chars)"
        )
    return ok

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rednote", type=Path)
    ap.add_argument("--wechat", type=Path)
    ap.add_argument("--title", default="")
    args = ap.parse_args()
    if not args.rednote and not args.wechat:
        ap.error("provide --rednote and/or --wechat")
    ok = True
    if args.rednote:
        ok = verify_rednote(args.rednote) and ok
    if args.wechat:
        ok = verify_wechat(args.wechat, args.title) and ok
    raise SystemExit(0 if ok else 1)

if __name__ == "__main__":
    main()
