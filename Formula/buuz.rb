class Buuz < Formula
  desc "Mongolian Cyrillic input method — type Latin, get Cyrillic"
  homepage "https://github.com/mnkhbldd/mnkhbldd-keyboard"
  # Pin to a commit so the checksum stays stable; bump when shipping a new release.
  url "https://github.com/mnkhbldd/mnkhbldd-keyboard/archive/2226c322b3c3afc2b122b62a079eb2e77f4f372d.tar.gz"
  version "1.0.5"
  sha256 "09e2bfd616a6d68d82a41f453af7adbd2f35abc7622973922459c079a6876961"
  license "Apache-2.0"

  head "https://github.com/mnkhbldd/mnkhbldd-keyboard.git", branch: "main"

  depends_on :macos

  def install
    cd "macos" do
      system "make"
      libexec.install "build/Buuz.app"
    end

    (bin/"buuz-ime").write <<~EOS
      #!/bin/bash
      set -euo pipefail
      APP_SRC="#{libexec}/Buuz.app"
      DEST_DIR="${HOME}/Library/Input Methods"
      DEST_APP="${DEST_DIR}/Buuz.app"

      install_ime() {
        killall Buuz 2>/dev/null || true
        sleep 0.3
        mkdir -p "${DEST_DIR}"
        rm -rf "${DEST_APP}"
        cp -R "${APP_SRC}" "${DEST_APP}"
        codesign --force --deep --sign - "${DEST_APP}" 2>/dev/null || true
        echo "Installed to ${DEST_APP}"
      }

      uninstall_ime() {
        killall Buuz 2>/dev/null || true
        sleep 0.3
        if [ -d "${DEST_APP}" ]; then
          rm -rf "${DEST_APP}"
          echo "Removed ${DEST_APP}"
        else
          echo "Buuz is not installed in ${DEST_DIR}"
        fi
      }

      case "${1:-install}" in
        install) install_ime ;;
        uninstall|remove) uninstall_ime ;;
        *)
          echo "Usage: buuz-ime [install|uninstall]"
          exit 1
          ;;
      esac
    EOS
  end

  def post_install
    system "#{bin}/buuz-ime", "install"
  end

  def caveats
    <<~EOS
      Buuz is installed to:
        ~/Library/Input Methods/Buuz.app

      Enable it:
        System Settings → Keyboard → Input Sources → + → Buuz

      If it does not appear, log out and back in once.

      Re-link after upgrades:
        buuz-ime install

      Remove the Input Method (also run after brew uninstall):
        buuz-ime uninstall
    EOS
  end

  test do
    assert_path_exists libexec/"Buuz.app/Contents/MacOS/Buuz"
    assert_match "Usage: buuz-ime", shell_output("#{bin}/buuz-ime help", 1)
  end
end
