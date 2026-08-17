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

Uninstall:

```bash
brew uninstall --cask buuz
```

Source formula (builds locally; needs Command Line Tools): `brew install buuz`

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

On word commit, Buuz runs Hunspell against the bundled `mn_MN` dictionary. A word is replaced only when it is misspelled and there is a single high-confidence suggestion (one Hunspell suggestion, or exactly one suggestion with edit distance 1). Digits, punctuation, and 1-letter tokens are left unchanged.

Dictionary files are fetched at build time:

```bash
cd macos
./fetch-dict.sh
```

Credit: [bataak/dict-mn](https://github.com/bataak/dict-mn) (LPPL 1.3). Hunspell is vendored under `third_party/hunspell/`.

## Conversion table

Same as Windows — see `../docs/table.html`.
