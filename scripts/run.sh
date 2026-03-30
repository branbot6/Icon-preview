#!/bin/zsh
set -euo pipefail

NATIVE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

swift run --package-path "$NATIVE_DIR" IconPreviewLabNative
