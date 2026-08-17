# mnkhbldd-keyboard (Buuz)

Mongolian Cyrillic IME — type Latin letters, get Cyrillic.

Example: `buuz id'ye` → `бууз идье`

Based on [Buuz](https://github.com/odbayar/buuz) by Odbayar Nyamtseren, with a **macOS** InputMethodKit port.

## Platforms

- **Windows** — classic IMM IME DLL (`Buuz.sln`)
- **macOS** — see [`macos/README.md`](macos/README.md)

### macOS (Homebrew — recommended)

Prebuilt app — **no Xcode / compiler required**:

```bash
brew tap mnkhbldd/mnkhbldd-keyboard https://github.com/mnkhbldd/mnkhbldd-keyboard
brew trust --cask mnkhbldd/mnkhbldd-keyboard/buuz
brew install --cask buuz
```

If you already installed Buuz earlier with `make install` or the old source formula (`brew install buuz` without `--cask`), remove it first:

```bash
brew uninstall --formula buuz 2>/dev/null || true
rm -rf ~/Library/Input\ Methods/Buuz.app
brew install --cask buuz
# or: brew install --cask --force buuz
```

Then add **Buuz** under System Settings → Keyboard → Input Sources.

Update:

```bash
brew update && brew upgrade --cask buuz
```

The cask restarts the input method for you, so the new version takes effect immediately.

Uninstall:

```bash
brew uninstall --cask buuz
```

### macOS (from source)

```bash
cd macos && make && make install
```

Then add **Buuz** under System Settings → Keyboard → Input Sources.

On commit (space / Enter), Buuz may autocorrect a converted Cyrillic word — fixing vowels Latin cannot distinguish (`уйлчилгээ` → `үйлчилгээ`) and accidental doubled letters (`сайнн` → `сайн`). Ambiguous words are left as typed.

## License

Apache License 2.0 — see `LICENSE.txt`.

Bundled with Hunspell (MPL/GPL/LGPL) and the [dict-mn](https://github.com/bataak/dict-mn) Mongolian dictionary (LPPL 1.3). See `NOTICE`.
