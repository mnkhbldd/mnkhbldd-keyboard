#!/bin/bash
# Install / uninstall Buuz macOS Input Method
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Buuz.app"
SRC_APP="${SCRIPT_DIR}/build/${APP_NAME}"
DEST_DIR="${HOME}/Library/Input Methods"
DEST_APP="${DEST_DIR}/${APP_NAME}"

uninstall() {
  # Stop any running instance so files can be replaced
  killall Buuz 2>/dev/null || true
  sleep 0.3
  if [ -d "${DEST_APP}" ]; then
    echo "Removing ${DEST_APP}"
    rm -rf "${DEST_APP}"
  else
    echo "Buuz is not installed in ${DEST_DIR}"
  fi
  echo "Log out (or kill the Buuz process) for the change to fully apply."
}

install_app() {
  if [ ! -d "${SRC_APP}" ]; then
    echo "Build first: cd macos && make"
    exit 1
  fi
  killall Buuz 2>/dev/null || true
  sleep 0.3
  mkdir -p "${DEST_DIR}"
  if [ -d "${DEST_APP}" ]; then
    rm -rf "${DEST_APP}"
  fi
  cp -R "${SRC_APP}" "${DEST_APP}"
  codesign --force --deep --sign - "${DEST_APP}" 2>/dev/null || true
  # Clear the log for a fresh session
  : > /tmp/buuz.log
  echo "Installed to ${DEST_APP}"
  echo ""
  echo "Next steps:"
  echo "  1. Switch away from Buuz, then back to Buuz (menu bar dumpling icon)"
  echo "  2. Open TextEdit and type:  buuz"
  echo "  3. You should see:          бууз"
  echo ""
  echo "If still broken, check:  cat /tmp/buuz.log"
  echo "Or log out and back in once."
}

case "${1:-}" in
  --uninstall|-u) uninstall ;;
  *) install_app ;;
esac
