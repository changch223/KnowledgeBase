#!/usr/bin/env python3
"""xcstrings_export.py — Localizable.xcstrings を TSV (key / ja / zh-Hans / zh-Hant / en) に書き出す。

多言語対応 Phase A/B の翻訳注入 (別タスク) 用の器。翻訳者・翻訳 API に渡す TSV を作り、
`xcstrings_import.py` で zh-Hans / zh-Hant / en 列を xcstrings へ書き戻す想定。

- ja 列: `localizations.ja.stringUnit.value` があればそれ、無ければ key 自体
  (xcstrings の慣習: 「空 {} キー」は key 自体が ja の原文であることを意味する)。
- zh-Hans / zh-Hant / en 列: 既存の翻訳があれば入れる (再エクスポート時に既訳を確認できるように)、
  無ければ空文字列。
- タブ / 改行を含む値は `\\t` / `\\n` / `\\r` にエスケープする (TSV の 1 行 1 キーを保つため)。
  `xcstrings_import.py` が対で unescape する。

Usage:
    python3 scripts/xcstrings_export.py [--input PATH] [--output PATH]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_INPUT = REPO_ROOT / "KnowledgeBase" / "Localization" / "Localizable.xcstrings"
DEFAULT_OUTPUT = REPO_ROOT / "KnowledgeBase" / "Localization" / "Localizable.tsv"

TARGET_LOCALES = ["zh-Hans", "zh-Hant", "en"]


def escape_cell(value: str) -> str:
    """TSV の 1 セルに安全に収める (タブ/改行を可視エスケープに変換)。"""
    return (
        value.replace("\\", "\\\\")
        .replace("\t", "\\t")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
    )


def ja_value_for(key: str, entry: dict) -> str:
    localizations = entry.get("localizations", {})
    ja = localizations.get("ja", {}).get("stringUnit", {}).get("value")
    if ja is not None and ja != "":
        return ja
    # 「空 {} キー」規約: key 自体が ja の原文。
    return key


def translated_value_for(entry: dict, locale: str) -> str:
    localizations = entry.get("localizations", {})
    return localizations.get(locale, {}).get("stringUnit", {}).get("value", "")


def export(input_path: Path, output_path: Path) -> int:
    with input_path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    strings = data.get("strings", {})
    rows = []
    for key, entry in strings.items():
        ja = ja_value_for(key, entry)
        row = [key, ja] + [translated_value_for(entry, locale) for locale in TARGET_LOCALES]
        rows.append(row)

    header = ["key", "ja"] + TARGET_LOCALES
    with output_path.open("w", encoding="utf-8", newline="\n") as f:
        f.write("\t".join(header) + "\n")
        for row in rows:
            f.write("\t".join(escape_cell(cell) for cell in row) + "\n")

    print(f"OK: exported {len(rows)} keys → {output_path}")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="Localizable.xcstrings のパス")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="出力 TSV のパス")
    args = parser.parse_args(argv)
    return export(args.input, args.output)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
