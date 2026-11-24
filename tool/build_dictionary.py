#!/usr/bin/env python3
"""Build the bundled offline dictionary (SQLite) from ECDICT.

ECDICT (https://github.com/skywind3000/ECDICT) is MIT licensed.
This script produces a *subset* database that we are allowed to redistribute,
containing every exam-tagged word plus the most frequent English words.

Usage:
    python3 tool/build_dictionary.py path/to/ecdict.csv assets/dictionary/ecdict_core.db

The generated file is committed to the repository so the app works offline
without any first-run import step. Regenerating it is deterministic (sorted by
word) so diffs stay small.
"""
from __future__ import annotations

import csv
import os
import re
import sqlite3
import sys

csv.field_size_limit(10**9)

EXAM_TAGS = {"zk", "gk", "cet4", "cet6", "ky", "toefl", "ielts", "gre"}
FREQ_LIMIT = 20000
WORD_RE = re.compile(r"^[a-z][a-z\-' ]*$")

SCHEMA = """
CREATE TABLE dictionary (
  word        TEXT PRIMARY KEY,
  display     TEXT NOT NULL,
  phonetic    TEXT,
  pos         TEXT,
  translation TEXT,
  definition  TEXT,
  tag         TEXT,
  bnc         INTEGER NOT NULL DEFAULT 0,
  frq         INTEGER NOT NULL DEFAULT 0,
  collins     INTEGER NOT NULL DEFAULT 0,
  oxford      INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_dictionary_frq ON dictionary (frq);
"""


def unescape(value: str) -> str:
    """ECDICT stores multi-line definitions with literal backslash-n escapes."""
    return value.replace("\\r\\n", "\n").replace("\\n", "\n").replace("\\t", " ").strip()


def normalize(word: str) -> str:
    return word.strip().lower()


def should_keep(row: dict) -> bool:
    word = normalize(row.get("word") or "")
    if not word or len(word) > 24 or not WORD_RE.match(word):
        return False
    if not (row.get("translation") or row.get("definition")):
        return False
    tags = set((row.get("tag") or "").split())
    bnc = int(row.get("bnc") or 0)
    frq = int(row.get("frq") or 0)
    return bool(tags & EXAM_TAGS) or (0 < bnc <= FREQ_LIMIT) or (0 < frq <= FREQ_LIMIT)


def to_int(value, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    source, target = sys.argv[1], sys.argv[2]

    entries: dict[str, tuple] = {}
    total = 0
    with open(source, encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            total += 1
            if not should_keep(row):
                continue
            word = normalize(row["word"])
            candidate = (
                word,
                row["word"].strip(),
                (row.get("phonetic") or "").strip(),
                (row.get("pos") or "").strip(),
                unescape(row.get("translation") or ""),
                unescape(row.get("definition") or ""),
                (row.get("tag") or "").strip(),
                to_int(row.get("bnc")),
                to_int(row.get("frq")),
                to_int(row.get("collins")),
                to_int(row.get("oxford")),
            )
            existing = entries.get(word)
            # Prefer the row with the richest Chinese translation when duplicated.
            if existing is None or len(candidate[4]) > len(existing[4]):
                entries[word] = candidate

    if os.path.exists(target):
        os.remove(target)
    os.makedirs(os.path.dirname(os.path.abspath(target)), exist_ok=True)

    connection = sqlite3.connect(target)
    connection.executescript(SCHEMA)
    connection.executemany(
        "INSERT INTO dictionary (word, display, phonetic, pos, translation, definition,"
        " tag, bnc, frq, collins, oxford) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        [entries[key] for key in sorted(entries)],
    )
    connection.execute("PRAGMA user_version = 1")
    connection.commit()
    connection.execute("VACUUM")
    connection.commit()
    connection.close()

    size = os.path.getsize(target) / 1024 / 1024
    print(f"source rows : {total}")
    print(f"kept entries: {len(entries)}")
    print(f"output      : {target} ({size:.2f} MiB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
