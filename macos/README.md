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

```bash
brew tap mnkhbldd/mnkhbldd-keyboard https://github.com/mnkhbldd/mnkhbldd-keyboard
brew install buuz
```

This builds Buuz and installs it to `~/Library/Input Methods/Buuz.app`.

Then:

1. **System Settings → Keyboard → Input Sources → +**
2. Add **Buuz**
3. Choose it from the menu bar input menu
4. Type in any app

If it does not show up, log out and back in once.

Uninstall:

```bash
buuz-ime uninstall
brew uninstall buuz
```

After a `brew upgrade buuz`, re-link if needed: `buuz-ime install`.

## Build from source

Requires Xcode Command Line Tools (`clang++`), not the full Xcode app:

```bash
cd macos
make
make install
```

## Uninstall (from source)

```bash
cd macos
make uninstall
```

## Conversion table

Same as Windows — see `../docs/table.html`.
