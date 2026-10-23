from pathlib import Path, PurePosixPath
from PyInstaller.utils.hooks import collect_all, copy_metadata

root = Path(SPECPATH).parent
datas, binaries, hiddenimports = copy_metadata('spotdl', recursive=True), [], []
for module in ['yt_dlp', 'yt_dlp_ejs', 'curl_cffi', 'certifi', 'spotdl', 'ytmusicapi', 'pykakasi', 'spotapi']:
    data, binary, hidden = collect_all(module, include_py_files=False)
    datas += data
    binaries += binary
    hiddenimports += hidden

def keep_data(destination):
    parts = PurePosixPath(destination.replace('\\', '/')).parts
    if 'locales' in parts and parts[0] == 'ytmusicapi':
        index = parts.index('locales') + 1
        return index >= len(parts) or parts[index] in ('pt', 'pt_BR', 'pt-BR', 'en', 'de')
    return parts[:3] != ('spotdl', 'web', 'static')

a = Analysis([str(root / 'Scripts' / 'MediaEntry.py')], pathex=[str(root)],
             binaries=binaries, datas=datas, hiddenimports=hiddenimports, noarchive=False, optimize=1)
a.datas = [item for item in a.datas if keep_data(item[0])]
pyz = PYZ(a.pure)
exe = EXE(pyz, a.scripts, a.binaries, a.datas, [], name='spotdl', console=True,
          debug=False, strip=False, upx=False)
