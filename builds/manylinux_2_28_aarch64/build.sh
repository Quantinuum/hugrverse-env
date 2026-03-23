#!/usr/bin/env bash
# Parent build script for manylinux_2_28_aarch64.
# Invokes sub-component builds then bundles all outputs into a compressed archive.
#
# Usage: build.sh <output_path>
#   output_path - Absolute path for the resulting .tar.gz archive,
#                 e.g. /host/hugrverse_env_manylinux_2_28_aarch64.tar.gz
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_PATH="${1:?Usage: $0 <output_path>}"

echo "=== hugrverse-env build: manylinux_2_28_aarch64 ==="

# ── Component builds ─────────────────────────────────────────────────────────
echo "--- Building LLVM ---"
bash "${SCRIPT_DIR}/llvm/build.sh"

# ── Bundle outputs ────────────────────────────────────────────────────────────
echo "=== Bundling outputs to ${OUTPUT_PATH} ==="
tar -czf "${OUTPUT_PATH}" -C / opt/llvm

echo "=== Build complete: ${OUTPUT_PATH} ==="
