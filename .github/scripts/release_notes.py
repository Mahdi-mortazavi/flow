#!/usr/bin/env python3
"""Build the GitHub Release body for a تک‌نقطه (Flow) release.

The body is assembled from three sources, none of which are hand-written at
release time:

  * the commit range since the previous tag  -> categorised changelog
  * the built artifacts in ``--dist``        -> download table with real sizes
  * the signing certificate fingerprint      -> verification block

Usage:
    release_notes.py --version 0.6.0 --tag v0.6.0 --previous-tag v0.5.2 \
        --repo owner/name --dist dist --cert-sha256 AA:BB:.. > body.md
"""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path

# Conventional-commit type -> (section title, is a user-visible highlight).
# Highlights are printed inline; everything else folds into a <details>.
SECTIONS: list[tuple[str, str, bool]] = [
    ("feat", "✨ قابلیت‌های تازه", True),
    ("fix", "🐛 رفعِ اشکال", True),
    ("perf", "⚡ کارایی", True),
    ("refactor", "🧱 بازآرایی کد", False),
    ("docs", "📝 مستندات", False),
    ("test", "🧪 تست", False),
    ("build", "🏗 خط تولید", False),
    ("ci", "🏗 خط تولید", False),
    ("chore", "🧹 نگهداری", False),
]

# `type(scope)!: subject` — scope and the breaking-change `!` are both optional.
SUBJECT_RE = re.compile(r"^(?P<type>[a-z]+)(?:\((?P<scope>[^)]+)\))?(?P<bang>!)?:\s*(?P<text>.+)$")
# Trailing `(#12)` that GitHub appends to squash-merge subjects.
PR_RE = re.compile(r"\s*\(#(\d+)\)\s*$")

BOT_AUTHORS = {"github-actions[bot]", "github-actions", "dependabot[bot]"}

ABI_LABELS = {
    "universal": ("⭐ **اگر مطمئن نیستی، همین را بگیر**", "روی همه‌ی گوشی‌ها نصب می‌شود"),
    "arm64-v8a": ("گوشی‌های ۶۴بیتی", "تقریباً همه‌ی گوشی‌های ۲۰۱۷ به بعد"),
    "armeabi-v7a": ("گوشی‌های ۳۲بیتی", "دستگاه‌های قدیمی‌تر"),
    "x86_64": ("شبیه‌ساز و دستگاه‌های اینتل", "برای توسعه و تست"),
}
ABI_ORDER = ["universal", "arm64-v8a", "armeabi-v7a", "x86_64"]

FA_DIGITS = str.maketrans("0123456789", "۰۱۲۳۴۵۶۷۸۹")


def fa(value: object) -> str:
    return str(value).translate(FA_DIGITS)


def git(*args: str) -> str:
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout.strip()


def collect_commits(previous_tag: str | None) -> list[dict]:
    """Commits reachable from HEAD but not from the previous tag, newest first."""
    span = f"{previous_tag}..HEAD" if previous_tag else "HEAD"
    # %x1f is the ASCII unit separator: safe inside commit subjects.
    raw = git("log", span, "--no-merges", "--pretty=format:%h%x1f%s%x1f%an")
    commits = []
    for line in filter(None, raw.splitlines()):
        sha, subject, author = line.split("\x1f")
        pr = PR_RE.search(subject)
        subject = PR_RE.sub("", subject)
        match = SUBJECT_RE.match(subject)
        commits.append(
            {
                "sha": sha,
                "author": author,
                "pr": pr.group(1) if pr else None,
                "type": match.group("type") if match else "other",
                "scope": match.group("scope") if match else None,
                "breaking": bool(match.group("bang")) if match else False,
                "text": match.group("text") if match else subject,
            }
        )
    return commits


def render_changelog(commits: list[dict], repo: str) -> str:
    def bullet(commit: dict) -> str:
        scope = f"**{commit['scope']}:** " if commit["scope"] else ""
        link = f"[`{commit['sha']}`](https://github.com/{repo}/commit/{commit['sha']})"
        pr = f" ([#{commit['pr']}](https://github.com/{repo}/pull/{commit['pr']}))" if commit["pr"] else ""
        return f"- {scope}{commit['text']}{pr} — {link}"

    highlights, housekeeping = [], []
    for kind, title, is_highlight in SECTIONS:
        matching = [c for c in commits if c["type"] == kind]
        if not matching:
            continue
        block = f"### {title}\n\n" + "\n".join(bullet(c) for c in matching)
        (highlights if is_highlight else housekeeping).append((title, block))

    other = [c for c in commits if c["type"] not in {k for k, _, _ in SECTIONS}]
    if other:
        housekeeping.append(("سایر", "### 🔹 سایر تغییرات\n\n" + "\n".join(bullet(c) for c in other)))

    parts: list[str] = []

    breaking = [c for c in commits if c["breaking"]]
    if breaking:
        parts.append(
            "> ⚠️ **تغییرِ ناسازگار**\n>\n" + "\n".join(f"> - {c['text']}" for c in breaking)
        )

    # Merge duplicate titles (build/ci share one) while preserving order.
    seen: dict[str, str] = {}
    for title, block in highlights:
        seen[title] = seen.get(title, "") + ("\n" + block.split("\n\n", 1)[1] if title in seen else block)
    parts.extend(seen.values())

    if housekeeping:
        merged: dict[str, str] = {}
        for title, block in housekeeping:
            merged[title] = merged.get(title, "") + ("\n" + block.split("\n\n", 1)[1] if title in merged else block)
        parts.append(
            "<details>\n<summary><b>تغییرات داخلی و نگهداری</b></summary>\n\n"
            + "\n\n".join(merged.values())
            + "\n\n</details>"
        )

    return "\n\n".join(parts) if parts else "_بدون تغییرِ ثبت‌شده._"


def render_downloads(dist: Path, repo: str, tag: str) -> str:
    rows = []
    for abi in ABI_ORDER:
        apk = next((p for p in sorted(dist.glob(f"*-{abi}.apk"))), None)
        if apk is None:
            continue
        who, note = ABI_LABELS[abi]
        size = fa(f"{apk.stat().st_size / 1024 / 1024:.0f}")
        url = f"https://github.com/{repo}/releases/download/{tag}/{apk.name}"
        rows.append(f"| [`{apk.name}`]({url}) | {who}<br/><sub>{note}</sub> | {size} MB |")
    if not rows:
        return "_فایلی ساخته نشد._"
    return "| فایل | برای چه کسی | حجم |\n|---|---|---|\n" + "\n".join(rows)


def render_contributors(commits: list[dict]) -> str:
    authors: list[str] = []
    for commit in commits:
        name = commit["author"]
        if name not in authors and name not in BOT_AUTHORS:
            authors.append(name)
    if not authors:
        return ""
    listed = "، ".join(f"**{a}**" for a in authors)
    return f"## 🤝 دست‌مریزاد\n\nاین نسخه را {listed} ساختند. ممنون. 🙏"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--previous-tag", default="")
    parser.add_argument("--repo", required=True)
    parser.add_argument("--dist", default="dist")
    parser.add_argument("--cert-sha256", default="")
    args = parser.parse_args()

    previous = args.previous_tag or None
    commits = collect_commits(previous)
    dist = Path(args.dist)

    compare = (
        f"https://github.com/{args.repo}/compare/{previous}...{args.tag}"
        if previous
        else f"https://github.com/{args.repo}/commits/{args.tag}"
    )
    universal = next((p for p in sorted(dist.glob("*-universal.apk"))), None)
    universal_url = (
        f"https://github.com/{args.repo}/releases/download/{args.tag}/{universal.name}"
        if universal
        else f"https://github.com/{args.repo}/releases/latest"
    )

    signature_line = (
        f"اثرِ انگشتِ گواهیِ امضا (SHA-256):\n```\n{args.cert_sha256}\n```\n"
        "این مقدار بین همه‌ی نسخه‌ها ثابت است؛ اگر روزی فرق کرد، فایل از این مخزن نیامده."
        if args.cert_sha256
        else ""
    )

    body = f"""<div align="center">

# ◉ تک‌نقطه — Flow · {args.tag}

**[ ⬇️ دانلود نسخه‌ی یونیورسال ]({universal_url})**

</div>

---

## 📥 کدام فایل را بگیرم؟

{render_downloads(dist, args.repo, args.tag)}

<sub>پیش‌نیاز: اندروید ۷ (API 24) به بالا · هر فایل یک `.sha256` کنارش دارد.</sub>

### نصب

فایل را باز کن → اگر پرسید «نصب از منابع ناشناس» را اجازه بده → **Install**.
در اولین اجرا اجازه‌ی **نوتیفیکیشن** و (روی اندروید ۱۲+) **زنگِ دقیق** را بده تا یادآورها و زنگِ پایانِ تمرکز کار کنند.

> این نسخه با همان کلیدِ دائمیِ نسخه‌های قبل امضا شده — مستقیم روی نصبِ فعلی می‌نشیند و لازم نیست چیزی را پاک کنی.

---

## 🔄 چه چیزی عوض شد

{render_changelog(commits, args.repo)}

**[مقایسه‌ی کاملِ تغییرات]({compare})**

---

## 🛡 راستی‌آزمایی

هر فایل پیش از انتشار خودکار بازرسی شده: سلامتِ آرشیو، خوانابودنِ مانیفست، `minSdk 24`، حضورِ هر سه معماری در نسخه‌ی یونیورسال، و امضای معتبر با اسکیم‌های v2+v3. اگر هرکدام رد شود، انتشار متوقف می‌شود.

```bash
sha256sum -c taknoghte-{args.tag}-universal.apk.sha256
```

{signature_line}

{render_contributors(commits)}

---

<div align="center">

**۱۰۰٪ آفلاین · بدونِ اکانت · بدونِ سرور · بدونِ ردیابی**

[📖 مستندات](https://github.com/{args.repo}#readme) · [🐛 گزارشِ مشکل](https://github.com/{args.repo}/issues/new)

<sub>ساخته‌شده توسط <a href="https://github.com/Mahdi-mortazavi">مهدی مرتضوی</a></sub>

</div>
"""
    # Collapse the blank lines left behind by optional blocks.
    print(re.sub(r"\n{3,}", "\n\n", body).strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
