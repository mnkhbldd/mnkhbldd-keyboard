#!/bin/bash
# Fetch pinned bataak/dict-mn Hunspell files into Resources/dict/.
# Not committed — run at build time (Makefile calls this).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${SCRIPT_DIR}/Resources/dict"
TAG="2026.08.13"
ZIP_URL="https://raw.githubusercontent.com/bataak/dict-mn/${TAG}/mn_MN.zip"
LICENSE_URL="https://raw.githubusercontent.com/bataak/dict-mn/${TAG}/LICENSE"

mkdir -p "${DEST}"

if [ -f "${DEST}/mn_MN.aff" ] && [ -f "${DEST}/mn_MN.dic" ] && [ -f "${DEST}/LICENSE" ]; then
  echo "Dictionary already present in ${DEST}"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "Downloading dict-mn ${TAG}..."
curl -fsSL "${ZIP_URL}" -o "${TMP}/mn_MN.zip"
unzip -qo "${TMP}/mn_MN.zip" -d "${TMP}"

AFF="$(find "${TMP}" -name 'mn_MN.aff' | head -1)"
DIC="$(find "${TMP}" -name 'mn_MN.dic' | head -1)"
if [ -z "${AFF}" ] || [ -z "${DIC}" ]; then
  echo "mn_MN.aff / mn_MN.dic not found in zip" >&2
  exit 1
fi

cp "${AFF}" "${DEST}/mn_MN.aff"
cp "${DIC}" "${DEST}/mn_MN.dic"
curl -fsSL "${LICENSE_URL}" -o "${DEST}/LICENSE"

echo "Installed dictionary to ${DEST}"
ls -lh "${DEST}/mn_MN.aff" "${DEST}/mn_MN.dic"
