#!/usr/bin/env python3
"""xcstrings_import.py — TSV (key / ja / zh-Hans / zh-Hant) を Localizable.xcstrings へ
外科的に注入する (`xcstrings_export.py` の対)。

設計上の制約:
- キー順・既存 ja の中身を完全に保持する。zh 列が空のキーは 1 バイトも触らない
  (`--output` を渡さず素の空 TSV を import しても xcstrings が byte 同一になることを
  round-trip テストで確認している = このスクリプトは「変更が必要なキーの value block だけ」を
  文字列レベルで置換し、それ以外は原文をそのままコピーする)。
- ja とテキスト内の書式指定子 (`%@` / `%lld` / `%1$@` 等) が翻訳側と一致するか検証し、
  不一致なら警告を出してそのロケールへの注入をスキップする (誤訳でクラッシュ/表示崩れさせない)。
- 注入したロケールの state は "needs_review" (人手レビュー待ちを明示、"translated" にはしない)。

Usage:
    python3 scripts/xcstrings_import.py [--tsv PATH] [--xcstrings PATH] [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TSV = REPO_ROOT / "KnowledgeBase" / "Localization" / "Localizable.tsv"
DEFAULT_XCSTRINGS = REPO_ROOT / "KnowledgeBase" / "Localization" / "Localizable.xcstrings"

TARGET_LOCALES = ["zh-Hans", "zh-Hant"]

FORMAT_SPECIFIER_RE = re.compile(r"%(?:\d+\$)?(?:@|lld|ld|d|f|u|s)")


def unescape_cell(value: str) -> str:
    """`xcstrings_export.py` の `escape_cell` の逆変換。"""
    out = []
    i = 0
    n = len(value)
    while i < n:
        c = value[i]
        if c == "\\" and i + 1 < n:
            nxt = value[i + 1]
            if nxt == "t":
                out.append("\t")
                i += 2
                continue
            if nxt == "n":
                out.append("\n")
                i += 2
                continue
            if nxt == "r":
                out.append("\r")
                i += 2
                continue
            if nxt == "\\":
                out.append("\\")
                i += 2
                continue
        out.append(c)
        i += 1
    return "".join(out)


def format_specifiers(text: str) -> list[str]:
    return sorted(FORMAT_SPECIFIER_RE.findall(text))


def read_tsv(path: Path) -> list[dict]:
    rows = []
    with path.open("r", encoding="utf-8") as f:
        lines = f.read().split("\n")
    if not lines:
        return rows
    header = lines[0].split("\t")
    for line in lines[1:]:
        if line == "":
            continue
        cells = line.split("\t")
        if len(cells) != len(header):
            print(f"WARN: skipping malformed row (column count mismatch): {line!r}", file=sys.stderr)
            continue
        row = {header[i]: unescape_cell(cells[i]) for i in range(len(header))}
        rows.append(row)
    return rows


# MARK: - Xcode-style JSON scanner (text 上の各 key の value block 範囲を特定する)


def _find_string_end(text: str, start: int) -> int:
    """text[start] == '"'。閉じ quote の直後の index を返す (escape 対応)。"""
    i = start + 1
    n = len(text)
    while i < n:
        c = text[i]
        if c == "\\":
            i += 2
            continue
        if c == '"':
            return i + 1
        i += 1
    raise ValueError("unterminated string literal")


def _find_object_end(text: str, start: int) -> int:
    """text[start] == '{'。対応する '}' の直後の index を返す (文字列リテラル内の brace を無視)。"""
    assert text[start] == "{"
    depth = 0
    i = start
    n = len(text)
    while i < n:
        c = text[i]
        if c == '"':
            i = _find_string_end(text, i)
            continue
        if c == "{":
            depth += 1
            i += 1
            continue
        if c == "}":
            depth -= 1
            i += 1
            if depth == 0:
                return i
            continue
        i += 1
    raise ValueError("unterminated object")


def scan_strings_entries(text: str) -> list[tuple[str, int, int]]:
    """`"strings" : { ... }` の直下にある各 key の (key, value_start, value_end) を返す。
    value_start/value_end は key の value ("{" から対応する "}" の直後) の text index。
    """
    marker = '"strings"'
    marker_idx = text.index(marker)
    obj_start = text.index("{", marker_idx)
    obj_end = _find_object_end(text, obj_start)

    entries: list[tuple[str, int, int]] = []
    i = obj_start + 1
    while i < obj_end - 1:
        while i < obj_end - 1 and text[i] in " \n\t\r,":
            i += 1
        if i >= obj_end - 1:
            break
        assert text[i] == '"', f"expected key string at {i}, found {text[i:i+20]!r}"
        key_start = i
        key_end = _find_string_end(text, key_start)
        key = json.loads(text[key_start:key_end])
        i = key_end
        while text[i] in " \n\t\r":
            i += 1
        assert text[i] == ":", f"expected ':' at {i}, found {text[i:i+20]!r}"
        i += 1
        while text[i] in " \n\t\r":
            i += 1
        assert text[i] == "{", f"expected '{{' at {i}, found {text[i:i+20]!r}"
        value_start = i
        value_end = _find_object_end(text, value_start)
        entries.append((key, value_start, value_end))
        i = value_end
    return entries


# MARK: - Xcode-style serializer (置換する value block だけを作る)


def _dumps_value(obj, indent: int) -> str:
    pad = "  " * indent
    pad_in = "  " * (indent + 1)
    if isinstance(obj, dict):
        if not obj:
            return "{\n\n" + pad + "}"
        parts = []
        keys = list(obj.keys())
        for idx, k in enumerate(keys):
            comma = "," if idx < len(keys) - 1 else ""
            parts.append(
                f'{pad_in}{json.dumps(k, ensure_ascii=False)} : {_dumps_value(obj[k], indent + 1)}{comma}'
            )
        return "{\n" + "\n".join(parts) + "\n" + pad + "}"
    if isinstance(obj, bool):
        return "true" if obj else "false"
    if obj is None:
        return "null"
    if isinstance(obj, str):
        return json.dumps(obj, ensure_ascii=False)
    return json.dumps(obj, ensure_ascii=False)


ENTRY_VALUE_INDENT = 2  # "strings" の直下 key は 4-space (2 レベル) インデント


def build_replacement_block(entry_obj: dict) -> str:
    return _dumps_value(entry_obj, ENTRY_VALUE_INDENT)


def import_translations(tsv_path: Path, xcstrings_path: Path, dry_run: bool) -> int:
    rows = read_tsv(tsv_path)
    with xcstrings_path.open("r", encoding="utf-8") as f:
        original_text = f.read()

    with xcstrings_path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    existing_keys = set(data.get("strings", {}).keys())

    entries = scan_strings_entries(original_text)
    entry_index = {key: (start, end) for key, start, end in entries}

    edits: list[tuple[int, int, str]] = []  # (start, end, replacement_text) sorted by start
    changed_keys = 0
    skipped_keys = 0

    for row in rows:
        key = row.get("key", "")
        ja = row.get("ja", "")
        if key not in existing_keys:
            print(f"WARN: key not found in xcstrings, skipping: {key!r}", file=sys.stderr)
            continue

        to_inject: dict[str, str] = {}
        for locale in TARGET_LOCALES:
            translated = row.get(locale, "")
            if translated == "":
                continue  # 未翻訳セルは触らない
            ja_specs = format_specifiers(ja)
            translated_specs = format_specifiers(translated)
            if ja_specs != translated_specs:
                print(
                    f"WARN: format specifier mismatch for key={key!r} locale={locale}: "
                    f"ja={ja_specs} translated={translated_specs} — skipping this locale",
                    file=sys.stderr,
                )
                skipped_keys += 1
                continue
            to_inject[locale] = translated

        if not to_inject:
            continue

        value_start, value_end = entry_index[key]
        entry_obj = json.loads(original_text[value_start:value_end])
        localizations = entry_obj.setdefault("localizations", {})
        for locale, translated in to_inject.items():
            localizations[locale] = {
                "stringUnit": {
                    "state": "needs_review",
                    "value": translated,
                }
            }
        replacement = build_replacement_block(entry_obj)
        edits.append((value_start, value_end, replacement))
        changed_keys += 1

    if not edits:
        print(f"OK: nothing to inject (0 keys changed, {skipped_keys} skipped by validation)")
        return 0

    # 後ろから前へ splice することで、既に適用した edit の offset がずれないようにする。
    edits.sort(key=lambda e: e[0])
    updated_text = original_text
    for start, end, replacement in reversed(edits):
        updated_text = updated_text[:start] + replacement + updated_text[end:]

    # 書き戻す前に妥当な JSON であることを確認する (壊れた xcstrings を書かない)。
    json.loads(updated_text)

    if dry_run:
        print(f"DRY-RUN: would change {changed_keys} keys ({skipped_keys} skipped by validation)")
        return 0

    with xcstrings_path.open("w", encoding="utf-8") as f:
        f.write(updated_text)

    print(f"OK: injected {changed_keys} keys ({skipped_keys} skipped by validation) → {xcstrings_path}")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tsv", type=Path, default=DEFAULT_TSV, help="翻訳済み TSV のパス")
    parser.add_argument("--xcstrings", type=Path, default=DEFAULT_XCSTRINGS, help="Localizable.xcstrings のパス")
    parser.add_argument("--dry-run", action="store_true", help="書き込まず変更予定件数だけ表示する")
    args = parser.parse_args(argv)
    return import_translations(args.tsv, args.xcstrings, args.dry_run)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
