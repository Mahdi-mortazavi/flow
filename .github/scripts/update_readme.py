#!/usr/bin/env python3
"""Rewrite the download block in README.md so it always points at the release
that was just published.

Only the region between the RELEASE:START / RELEASE:END markers is touched, so
the rest of the README stays hand-written. Exits 0 with no change when the
block is already current, which lets the workflow skip an empty commit.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

START = "<!-- RELEASE:START -->"
END = "<!-- RELEASE:END -->"

FA_DIGITS = str.maketrans("0123456789", "۰۱۲۳۴۵۶۷۸۹")


def fa(value: object) -> str:
    return str(value).translate(FA_DIGITS)


def build_block(repo: str, tag: str, dist: Path) -> str:
    def entry(abi: str) -> tuple[str, str] | None:
        apk = next((p for p in sorted(dist.glob(f"*-{abi}.apk"))), None)
        if apk is None:
            return None
        url = f"https://github.com/{repo}/releases/download/{tag}/{apk.name}"
        size = fa(f"{apk.stat().st_size / 1024 / 1024:.0f}")
        return url, size

    universal = entry("universal")
    arm64 = entry("arm64-v8a")
    rows = []
    if universal:
        rows.append(
            f"| **[⬇️ یونیورسال]({universal[0]})** ⭐ | همه‌ی گوشی‌ها — اگر مطمئن نیستی همین | {universal[1]} MB |"
        )
    if arm64:
        rows.append(
            f"| [⬇️ arm64-v8a]({arm64[0]}) | گوشی‌های ۶۴بیتی (۲۰۱۷ به بعد) | {arm64[1]} MB |"
        )
    table = "\n".join(rows)

    return f"""{START}
<div align="center">

### آخرین نسخه: **{tag}**

| دانلود | برای چه کسی | حجم |
|---|---|---|
{table}

<sub>سایر معماری‌ها و فایل‌های `.sha256` در <a href="https://github.com/{repo}/releases/latest">صفحه‌ی ریلیز</a> · اندروید ۷ به بالا</sub>

</div>
{END}"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--readme", default="README.md")
    parser.add_argument("--repo", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--dist", default="dist")
    args = parser.parse_args()

    readme = Path(args.readme)
    text = readme.read_text(encoding="utf-8")
    if START not in text or END not in text:
        print(f"::error::{args.readme} has no RELEASE:START/END markers — nothing to sync.")
        return 1

    block = build_block(args.repo, args.tag, Path(args.dist))
    updated = re.sub(
        re.escape(START) + r".*?" + re.escape(END),
        lambda _: block,
        text,
        flags=re.DOTALL,
    )

    if updated == text:
        print("README already current.")
        return 0

    readme.write_text(updated, encoding="utf-8")
    print(f"README download block updated to {args.tag}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
