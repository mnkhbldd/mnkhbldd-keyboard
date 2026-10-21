#!/usr/bin/env python3
"""Build Resources/dict/mn_freq.txt from Mongolian text corpora.

Usage:
  build-freq.py OUT SOURCE...

Each SOURCE is one of:
  *-words.txt              Leipzig Corpora word list (id<TAB>word<TAB>count)
  *.xml.bz2                Wikipedia pages-articles dump
  anything else            plain UTF-8 text

Output: one "word<TAB>count" per line, lowercase, most frequent first.
"""

import bz2
import collections
import re
import sys

WORD = re.compile(r"[а-яёөүА-ЯЁӨҮ]+")
MIN_COUNT = 3
MAX_WORDS = 250_000


def count_text(lines, counts):
    for line in lines:
        for w in WORD.findall(line):
            if len(w) >= 2:
                counts[w.lower()] += 1


def count_leipzig(path, counts):
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3 or not parts[2].isdigit():
                continue
            word = parts[1]
            if WORD.fullmatch(word) and len(word) >= 2:
                counts[word.lower()] += int(parts[2])


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    out, sources = sys.argv[1], sys.argv[2:]
    counts = collections.Counter()
    for src in sources:
        before = sum(counts.values())
        if src.endswith("-words.txt"):
            count_leipzig(src, counts)
        elif src.endswith(".bz2"):
            with bz2.open(src, "rt", encoding="utf-8", errors="replace") as f:
                count_text(f, counts)
        else:
            with open(src, encoding="utf-8", errors="replace") as f:
                count_text(f, counts)
        print(f"{src}: {sum(counts.values()) - before} tokens", file=sys.stderr)

    rows = [(w, c) for w, c in counts.most_common(MAX_WORDS) if c >= MIN_COUNT]
    with open(out, "w", encoding="utf-8") as f:
        for w, c in rows:
            f.write(f"{w}\t{c}\n")
    print(f"wrote {len(rows)} words to {out}", file=sys.stderr)


if __name__ == "__main__":
    main()
