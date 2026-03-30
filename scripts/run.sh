#!/bin/zsh
set -euo pipefail

NATIVE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$NATIVE_DIR/.." && pwd)"
RESOURCE_DIR="$NATIVE_DIR/Sources/IconPreviewLabNative/Resources"

cp "$PROJECT_ROOT/index.html" "$RESOURCE_DIR/index.html"
cp "$PROJECT_ROOT/branai-logo.svg" "$RESOURCE_DIR/branai-logo.svg"
cp "$PROJECT_ROOT/branai-icon.svg" "$RESOURCE_DIR/branai-icon.svg"
cp "$PROJECT_ROOT/ip-icon-1024.png" "$RESOURCE_DIR/ip-icon-1024.png"

swift run --package-path "$NATIVE_DIR" IconPreviewLabNative
