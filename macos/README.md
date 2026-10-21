# Buuz for macOS

Same Mongolian Cyrillic IME as the Windows build, using **InputMethodKit**.

Type Latin → get Cyrillic, e.g. `buuz id'ye` → `бууз идье`.

## Structure (mirrors Windows)

| Windows | macOS |
|---------|--------|
| `Composer.cpp/h` | `Composer.cpp/h` — same conversion rules |
| `CompString.cpp/h` | `CompString.cpp/h` |
| `InputContext.cpp/h` | `InputContext.cpp/h` |
| `ImeInterface.cpp` | `BuuzInputController.mm` |
| `Init.cpp` | `Init.mm` |
| `CompWindow.cpp` | `CompWindow.mm` |
| `UiWindow.cpp` | handled inside IMK controller |
| `buuz.nsi` / `.inf` | `install.sh` |

## Install with Homebrew (recommended)

Prebuilt app — **no Xcode / compiler required**:

```bash
brew tap mnkhbldd/mnkhbldd-keyboard https://github.com/mnkhbldd/mnkhbldd-keyboard
brew install --cask buuz
```

This downloads `Buuz.app` into `~/Library/Input Methods/`.

Then:

1. **System Settings → Keyboard → Input Sources → +**
2. Add **Buuz**
3. Choose it from the menu bar input menu
4. Type in any app

If it does not show up, log out and back in once.

Update:

```bash
brew update && brew upgrade --cask buuz
```

Input Method Kit keeps serving the old binary after the app is replaced, so the cask's `postflight` kills and relaunches `Buuz.app`. No manual restart or logout is needed.

Uninstall:

```bash
brew uninstall --cask buuz
```

If an earlier install used the source formula (`brew install buuz` without `--cask`), switch to the cask:

```bash
brew uninstall --formula buuz
brew install --cask buuz
```

## Build from source

Requires Xcode Command Line Tools (`clang++`), not the full Xcode app:

```bash
cd macos
make
make install
```

Release zip (universal arm64 + x86_64):

```bash
cd macos
make package
```

## Uninstall (from source)

```bash
cd macos
make uninstall
```

## Autocorrect

On word commit, Buuz checks the word with Hunspell (bundled `mn_MN` dictionary). A misspelled word is replaced in two steps:

1. **Exact repair** — swap vowels Latin cannot distinguish (`у`/`ү`, `о`/`ө`, `э`/`е`, `и`/`ы`) and/or drop one of a doubled letter. Applied when exactly one result is a real word, or the corpus clearly prefers one: `уйлчилгээ` → `үйлчилгээ`, `оорчлолт` → `өөрчлөлт`, `сайнн` → `сайн`.
2. **Ranked correction** — every word within one typo (plus vowel swaps) is scored by how often it appears in Mongolian text against how likely that typo is on a QWERTY keyboard (adjacent keys, a missed `h` in `sh`/`ch`/`kh`, a dropped letter of `аа`/`оо`, ...). The best word is applied only when it holds ≥95% of the probability, so close calls stay as typed: `улаанбаатр` → `улаанбаатар`, `сургуль` → `сургууль`.

Words the corpus knows well but Hunspell does not (names, loanwords) are left alone, as are digits, punctuation and 1-letter tokens.

**Undo:** press Backspace right after a correction to get back what you typed. Buuz remembers that word and never corrects it again (`~/Library/Application Support/Buuz/learned-words.txt`; delete a line to forget it).

Measure changes with `make eval-spell` (add `SHOW=1` for failures, `RARE=1` for uncommon words). It spells sampled words in Latin as a user would, adds one Latin typo, and runs them through the composer and autocorrect.

Dictionary files are fetched at build time:

```bash
cd macos
./fetch-dict.sh
```

Credit: [bataak/dict-mn](https://github.com/bataak/dict-mn) (LPPL 1.3). Hunspell is vendored under `third_party/hunspell/`. Word frequencies (`Resources/dict/mn_freq.txt`, committed) are counted by `tools/build-freq.py` from Mongolian Wikipedia (CC BY-SA 4.0) and the Leipzig Corpora Collection (`mon_news_2020_100K`, `mon_wikipedia_2021_100K`).

## Conversion table

Same as Windows — see `../docs/table.html`.
