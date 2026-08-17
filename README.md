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
brew install --cask buuz
```

Then add **Buuz** under System Settings → Keyboard → Input Sources.

Uninstall:

```bash
brew uninstall --cask buuz
```

To build from source with Homebrew instead: `brew install buuz` (formula; needs Command Line Tools).

### macOS (from source)

```bash
cd macos && make && make install
```

Then add **Buuz** under System Settings → Keyboard → Input Sources.

## License

Apache License 2.0 — see `LICENSE.txt`.
