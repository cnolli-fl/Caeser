#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

arch="$(uname -m)"
if [[ "$(uname -s)" != Linux || ( "$arch" != x86_64 && "$arch" != aarch64 ) ]]; then
  echo "O AppImage precisa ser montado em Linux x86_64 ou aarch64." >&2
  exit 1
fi

python_bin="${PYTHON_BIN:-python3}"
version="${CAESER_LINUX_VERSION:-0.1.0}"
build_dir="$root_dir/Linux/.build"
app_dir="$build_dir/Caeser.AppDir"
dist_dir="$root_dir/Linux/dist"
mkdir -p "$build_dir" "$dist_dir"

"$python_bin" -m venv "$build_dir/venv"
"$build_dir/venv/bin/python" -m pip install --upgrade pip
"$build_dir/venv/bin/python" -m pip install -r Linux/requirements.txt

"$build_dir/venv/bin/python" -m PyInstaller --noconfirm --clean --onedir --windowed \
  --name caeser --distpath "$build_dir/pyinstaller-dist" --workpath "$build_dir/pyinstaller-work" \
  --specpath "$build_dir" --paths Linux \
  --collect-all yt_dlp --collect-all spotdl --collect-all pykakasi \
  --add-data "$root_dir/Sources/VideoDownloader/Resources:assets/Sources/VideoDownloader/Resources" \
  Linux/launcher.py

mkdir -p "$app_dir/usr/bin/tools" "$app_dir/usr/share/icons/hicolor/512x512/apps" \
  "$app_dir/usr/share/doc/caeser/licenses"
cp -a "$build_dir/pyinstaller-dist/caeser/." "$app_dir/usr/bin/"
install -m 644 Linux/THIRD-PARTY.md "$app_dir/usr/share/doc/caeser/THIRD-PARTY.md"
"$build_dir/venv/bin/python" - "$app_dir/usr/share/doc/caeser/licenses" <<'PY'
import importlib.metadata
import pathlib
import shutil
import sys

destination = pathlib.Path(sys.argv[1])
for distribution in importlib.metadata.distributions():
    name = distribution.metadata.get("Name", "package").replace("/", "-")
    version = distribution.version
    for file in distribution.files or []:
        filename = pathlib.Path(str(file)).name.lower()
        if not filename.startswith(("license", "copying", "notice")):
            continue
        source = pathlib.Path(distribution.locate_file(file))
        if source.is_file() and source.stat().st_size < 1_000_000:
            target = destination / f"{name}-{version}" / pathlib.Path(str(file)).name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
PY

ffmpeg_bin="$("$build_dir/venv/bin/python" -c 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())')"
install -m 755 "$ffmpeg_bin" "$app_dir/usr/bin/tools/ffmpeg"

deno_version="2.9.8"
deno_archive="deno-${arch}-unknown-linux-gnu.zip"
deno_base="https://github.com/denoland/deno/releases/download/v${deno_version}/${deno_archive}"
curl --fail --location --retry 3 --output "$build_dir/$deno_archive" "$deno_base"
curl --fail --location --retry 3 --output "$build_dir/$deno_archive.sha256sum" "$deno_base.sha256sum"
deno_hash="$(cut -d ' ' -f1 "$build_dir/$deno_archive.sha256sum")"
printf '%s  %s\n' "$deno_hash" "$build_dir/$deno_archive" | sha256sum --check --status
unzip -p "$build_dir/$deno_archive" deno > "$app_dir/usr/bin/tools/deno"
chmod 755 "$app_dir/usr/bin/tools/deno"

install -m 755 Linux/AppRun "$app_dir/AppRun"
install -m 644 Linux/caeser.desktop "$app_dir/caeser.desktop"
install -m 644 Sources/VideoDownloader/Resources/CaeserLogo.png "$app_dir/caeser.png"
install -m 644 Sources/VideoDownloader/Resources/CaeserLogo.png \
  "$app_dir/usr/share/icons/hicolor/512x512/apps/caeser.png"

tool="$build_dir/appimagetool-${arch}.AppImage"
curl --fail --location --retry 3 --output "$tool" \
  "https://github.com/AppImage/appimagetool/releases/download/1.9.0/appimagetool-${arch}.AppImage"
chmod 755 "$tool"
output="$dist_dir/Caeser-${version}-Linux-${arch}.AppImage"
ARCH="$arch" APPIMAGE_EXTRACT_AND_RUN=1 "$tool" "$app_dir" "$output"
chmod 755 "$output"
sha256sum "$output" > "$output.sha256"
echo "AppImage pronto: $output"
