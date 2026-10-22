# Both CLI entry points share one arm64 Python runtime and module archive.
from pathlib import Path, PurePosixPath
from PyInstaller.utils.hooks import collect_all, copy_metadata

root = Path(SPECPATH).parent
modules = ['yt_dlp', 'yt_dlp_ejs', 'curl_cffi', 'certifi',
           'spotdl', 'ytmusicapi', 'pykakasi', 'spotapi']
datas, binaries, hiddenimports = [], [], []
datas += copy_metadata('spotdl', recursive=True)
for module in modules:
    data, binary, hidden = collect_all(module, include_py_files=False)
    datas += data
    binaries += binary
    hiddenimports += hidden

def keep_data(destination):
    parts = PurePosixPath(destination).parts
    # ytmusicapi defaults to en, and spotDL's YouTubeMusic provider explicitly
    # constructs YTMusic(language="de"). These tiny parser catalogs are runtime
    # dependencies, not interface languages. Keep both as well as Portuguese.
    if 'locales' in parts and parts[0] == 'ytmusicapi':
        index = parts.index('locales') + 1
        return index >= len(parts) or parts[index] in ('pt', 'pt_BR', 'pt-BR', 'en', 'de')
    # The app uses spotDL's CLI, not its independent browser/server frontend.
    if parts[:3] == ('spotdl', 'web', 'static'):
        return False
    return True

entry = root / 'Scripts' / 'SpotDLEntry.py'
a = Analysis([str(entry)], pathex=[str(root)], binaries=binaries, datas=datas,
             hiddenimports=hiddenimports, noarchive=False, optimize=1)
# Apply after hooks too: a hook can add a catalog that collect_all omitted.
a.datas = [item for item in a.datas if keep_data(item[0])]
pyz = PYZ(a.pure)
exe = EXE(pyz, a.scripts, a.binaries, a.datas, [], name='spotdl-arm64',
          console=True, debug=False, strip=False, upx=False,
          target_arch='arm64', codesign_identity=None)
