#!/bin/bash
# Rebuild both Python CLIs for arm64 with the same fixed dependency versions.
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_cache="${1:?Usage: BuildSpotDL.sh CACHE_DIRECTORY}"
mkdir -p "$task_cache"
task_cache="$(cd "$task_cache" && pwd)"
task_python="${CAESER_BUILD_PYTHON:-python3}"
"$task_python" -c 'import sys; assert sys.version_info[:2] == (3, 14), "Build requires Python 3.14 (end users do not need Python)."'
if [ ! -x "$task_cache/spotdl-build/bin/python" ]; then
    "$task_python" -m venv "$task_cache/spotdl-build"
fi
task_python="$task_cache/spotdl-build/bin/python"
"$task_python" -m pip install --no-cache-dir --disable-pip-version-check --no-input \
    -r "$task_root/Packaging/spotdl-requirements.txt"
export PYINSTALLER_CONFIG_DIR="$task_cache/pyinstaller-cache"
"$task_python" -m PyInstaller --noconfirm --clean \
    --distpath "$task_cache" --workpath "$task_cache/pyinstaller-build" \
    "$task_root/Packaging/MediaTools.spec"
