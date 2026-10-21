# Mongolian Hunspell dictionary (dict-mn)

Downloaded at build time by `macos/fetch-dict.sh` from
[bataak/dict-mn](https://github.com/bataak/dict-mn) tag `2026.08.13`.

Files fetched (not in git):

- `mn_MN.aff`
- `mn_MN.dic`
- `LICENSE` (LaTeX Project Public License 1.3)

Copyright 2020–2026 Batmunkh Dorjgotov. Used only for Buuz autocorrect.

`mn_freq.txt` (in git) holds word counts for ranking corrections, built by
`macos/tools/build-freq.py` from:

- Mongolian Wikipedia dump (`mnwiki-latest-pages-articles.xml.bz2`), CC BY-SA 4.0
- Leipzig Corpora Collection: `mon_news_2020_100K`, `mon_wikipedia_2021_100K`
  (D. Goldhahn, T. Eckart, U. Quasthoff: Building Large Monolingual
  Dictionaries at the Leipzig Corpora Collection, LREC 2012)
