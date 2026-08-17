#!/bin/bash
# Package Buuz.app into dist/Buuz-<version>.zip for GitHub Releases / Homebrew Cask.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP="${SCRIPT_DIR}/build/Buuz.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${SCRIPT_DIR}/Info.plist")"
DIST_DIR="${ROOT_DIR}/dist"
ZIP_NAME="Buuz-${VERSION}.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"

if [ ! -d "${APP}" ]; then
  echo "Build first: cd macos && make ARCHS=\"arm64 x86_64\""
  exit 1
fi

mkdir -p "${DIST_DIR}"
rm -f "${ZIP_PATH}"

# ditto preserves resource forks / code signature better than zip
ditto -c -k --keepParent "${APP}" "${ZIP_PATH}"

echo "Created ${ZIP_PATH}"
echo "SHA256: $(shasum -a 256 "${ZIP_PATH}" | awk '{print $1}')"
file "${APP}/Contents/MacOS/Buuz"
