#!/bin/bash

set -euo pipefail

APP_NAME="QieQie"
PROJECT_NAME="QieQie.xcodeproj"
SCHEME_NAME="QieQie"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-build}"
APP_BUNDLE_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
STOP_TIMEOUT_SECONDS="${STOP_TIMEOUT_SECONDS:-10}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
REFRESH_SOURCEKIT_SCRIPT="$REPO_ROOT/scripts/refresh_sourcekit_index.sh"

cd "$REPO_ROOT"

fail() {
  echo "$1" >&2
  exit 1
}

stop_running_app() {
  if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    echo "${APP_NAME} is not running."
    return
  fi

  echo "Stopping ${APP_NAME}..."
  pkill -x "$APP_NAME"

  local waited=0
  while pgrep -x "$APP_NAME" >/dev/null 2>&1; do
    if (( waited >= STOP_TIMEOUT_SECONDS )); then
      fail "Timed out waiting for ${APP_NAME} to stop."
    fi

    sleep 1
    ((waited += 1))
  done
}

build_app() {
  echo "Building ${APP_NAME} (${CONFIGURATION})..."
  xcodebuild \
    -project "$PROJECT_NAME" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
}

refresh_sourcekit_index() {
  if [[ ! -x "$REFRESH_SOURCEKIT_SCRIPT" ]]; then
    fail "SourceKit refresh script not found at ${REFRESH_SOURCEKIT_SCRIPT}."
  fi

  echo "Refreshing SourceKit index data..."
  "$REFRESH_SOURCEKIT_SCRIPT"
}

open_app() {
  [[ -d "$APP_BUNDLE_PATH" ]] || fail "App bundle not found at ${APP_BUNDLE_PATH}."

  echo "Opening ${APP_BUNDLE_PATH}..."
  open "$APP_BUNDLE_PATH"
}

main() {
  stop_running_app
  build_app
  refresh_sourcekit_index
  open_app
}

main "$@"
