#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${1:-$SCRIPT_DIR/generated/QieQie}"

mkdir -p "$OUTPUT_DIR"

cp -R "$SCRIPT_DIR/QieQie.xcodeproj" "$OUTPUT_DIR/"
cp -R "$SCRIPT_DIR/QieQie" "$OUTPUT_DIR/"

echo "已创建 QieQie 项目副本：$OUTPUT_DIR"
