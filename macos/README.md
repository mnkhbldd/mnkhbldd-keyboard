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

## Build

Requires Xcode Command Line Tools:

```bash
cd macos
make
```

## Install

```bash
cd macos
make install
```

Then:

1. **System Settings → Keyboard → Input Sources → +**
2. Add **Buuz**
3. Choose it from the menu bar input menu
4. Type in any app

If it does not show up, log out and back in once.

## Uninstall

```bash
cd macos
make uninstall
```

## Conversion table

Same as Windows — see `../docs/table.html`.
