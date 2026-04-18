#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-build}"
BUILD_LOG_DIR="${REPO_ROOT}/${DERIVED_DATA_PATH}/Logs/Build"
MANIFEST_PATH="${BUILD_LOG_DIR}/LogStoreManifest.plist"

fail() {
  echo "$1" >&2
  exit 1
}

[[ -f "${MANIFEST_PATH}" ]] || fail "Build log manifest not found at ${MANIFEST_PATH}."

LATEST_LOG_FILE="$(
  python3 - "${MANIFEST_PATH}" <<'PY'
import plistlib
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
manifest = plistlib.loads(manifest_path.read_bytes())
logs = sorted(
    manifest.get("logs", {}).values(),
    key=lambda value: value["timeStoppedRecording"],
    reverse=True,
)

if not logs:
    raise SystemExit(1)

print(logs[0]["fileName"])
PY
)"

[[ -n "${LATEST_LOG_FILE}" ]] || fail "Unable to determine latest Xcode build log."

cd "${REPO_ROOT}"
xcode-build-server parse -a "${BUILD_LOG_DIR}/${LATEST_LOG_FILE}" >/dev/null
