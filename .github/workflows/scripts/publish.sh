#!/bin/bash
# publish.sh — Build a release wheel ready for PyPI upload.
#
# All native dependencies (xxHash, liburing) are vendored under third_party/
# and compiled from source by CMake.  The only system requirements are:
#   - A C/C++17 compiler (gcc/g++)
#   - CMake >= 3.10
#   - Python + pip with torch installed
#   - CUDA toolkit (provides -lcuda)
#
# No apt/yum packages like liburing-dev or libxxhash-dev are needed.
#
# Usage:
#   ./publish.sh              # Build wheel in dist/
#   ./publish.sh --upload     # Build wheel and upload to PyPI via twine
#
# Environment variables for non-interactive PyPI upload:
#   TWINE_USERNAME / TWINE_PASSWORD   — or —
#   TWINE_REPOSITORY_URL              — for custom index
set -euo pipefail

# Disable all interactive prompts
export GIT_TERMINAL_PROMPT=0
export PIP_NO_INPUT=1
export DEBIAN_FRONTEND=noninteractive

# Resolve project root (repo root), not the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}" && git rev-parse --show-toplevel)"
cd "${PROJECT_ROOT}"

UPLOAD=false
for arg in "$@"; do
  case "${arg}" in
    --upload) UPLOAD=true ;;
    *) ;;
  esac
done

# ── 1. Initialise vendored submodules ────────────────────────────────────────
echo "=== Initialising submodules ==="
git submodule update --init --recursive

# ── 2. Build vendored native libs (xxHash, liburing) via CMake ───────────────
echo "=== Building vendored native libraries ==="
mkdir -p build
cd build
if [[ "${FLEXKV_ENABLE_METRICS:-0}" == "0" ]]; then
  echo "FLEXKV_ENABLE_METRICS=0: building without Prometheus monitoring"
  cmake .. -DFLEXKV_ENABLE_MONITORING=OFF
else
  cmake ..
fi
cmake --build .

BUILD_LIB_PATH="$(pwd)/lib"
echo "=== Vendored libs built in ${BUILD_LIB_PATH} ==="
ls -lh "${BUILD_LIB_PATH}"/*.so* 2>/dev/null || true
cd ..

# Make vendored libs available to the Python build
export LD_LIBRARY_PATH="${BUILD_LIB_PATH}:${LD_LIBRARY_PATH:-}"

# ── 3. Copy shared libraries into the Python package ─────────────────────────
echo "=== Copying shared libraries into package ==="
PACKAGE_LIB_DIR="flexkv/lib"
mkdir -p "${PACKAGE_LIB_DIR}"
if [[ -d "${BUILD_LIB_PATH}" ]]; then
  for lib_file in "${BUILD_LIB_PATH}"/*.so*; do
    [[ -f "${lib_file}" ]] && cp "${lib_file}" "${PACKAGE_LIB_DIR}/" && echo "  $(basename "${lib_file}")"
  done
fi

# ── 4. Build release wheel ──────────────────────────────────────────────────
echo "=== Building release wheel ==="
pip install wheel setuptools Cython
FLEXKV_DEBUG=0 python3 setup.py bdist_wheel -v

echo ""
echo "=== Wheel(s) built ==="
ls -lh dist/*.whl

# ── 5. Optionally upload to PyPI ─────────────────────────────────────────────
if [[ "${UPLOAD}" == "true" ]]; then
  echo "=== Uploading to PyPI ==="
  pip install twine
  # twine reads credentials from env: TWINE_USERNAME, TWINE_PASSWORD
  # or from ~/.pypirc. --non-interactive prevents any prompts.
  twine upload --non-interactive dist/*.whl
fi

echo "=== Done ==="
