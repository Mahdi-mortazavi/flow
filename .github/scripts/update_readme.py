#!/usr/bin/env python3
"""Rewrite the download block in README.md so it always points at the release
that was just published.

Only the region between the RELEASE:START / RELEASE:END markers is touched, so
the rest of the README stays hand-written. The block is deliberately narrow —
one headline link plus a single line of alternatives — because the README is
read on a phone as often as on a desktop, and a table would force sideways
scrolling there.

Exits 0 with no change when the block is already current, which lets the
workflow skip an empty commit.
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
        return url, fa(f"{apk.stat().st_size / 1024 / 1024:.0f}")

    universal = entry("universal")
    arm64 = entry("arm64-v8a")
    latest = f"https://github.com/{repo}/releases/latest"

    if universal:
        headline = (
            f"**[نسخه‌ی همه‌ی گوشی‌ها · Universal APK — {universal[1]} MB]({universal[0]})**"
        )
    else:
        headline = f"**[دانلود از صفحه‌ی ریلیز · Download]({latest})**"

    alternatives = []
    if arm64:
        alternatives.append(
            f'<a href="{arm64[0]}">arm64-v8a — {arm64[1]} MB</a>'
        )
    alternatives.append(f'<a href="{latest}">همه‌ی فایل‌ها</a>')
    note = "گوشی ۶۴بیتی و حجمِ کمتر؟ " + " · ".join(alternatives)

    return f"""{START}
<div align="center">

### ⬇️ دانلود · Download — {tag}

{headline}

<sub>{note}</sub>

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
