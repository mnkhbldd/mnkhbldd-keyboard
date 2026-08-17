# mnkhbldd-keyboard (Buuz)

Mongolian Cyrillic IME — type Latin letters, get Cyrillic.

Example: `buuz id'ye` → `бууз идье`

Based on [Buuz](https://github.com/odbayar/buuz) by Odbayar Nyamtseren, with a **macOS** InputMethodKit port.

## Platforms

- **Windows** — classic IMM IME DLL (`Buuz.sln`)
- **macOS** — see [`macos/README.md`](macos/README.md)

### macOS (Homebrew)

```bash
brew tap mnkhbldd/mnkhbldd-keyboard https://github.com/mnkhbldd/mnkhbldd-keyboard
brew install buuz
```

Needs [Homebrew](https://brew.sh) (and its Command Line Tools). Then add **Buuz** under System Settings → Keyboard → Input Sources.

Uninstall:

```bash
buuz-ime uninstall
brew uninstall buuz
```

### macOS (from source)

```bash
cd macos && make && make install
```

Then add **Buuz** under System Settings → Keyboard → Input Sources.

## License

Apache License 2.0 — see `LICENSE.txt`.
