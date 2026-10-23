[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'O executável spotDL precisa ser construído no Windows.' }
$windowsRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path $windowsRoot -Parent
$cache = Join-Path $windowsRoot '.cache\spotdl'
$tools = Join-Path $windowsRoot '.tools\win-x64'
New-Item -ItemType Directory -Path $cache -Force | Out-Null
& python -c "import sys; assert sys.version_info[:2] == (3, 14), 'Build requires Python 3.14'"
if ($LASTEXITCODE -ne 0) { throw 'Python de desenvolvimento incompatível.' }
$python = Join-Path $cache 'venv\Scripts\python.exe'
if (-not (Test-Path $python)) {
    & python -m venv (Join-Path $cache 'venv')
    if ($LASTEXITCODE -ne 0) { throw 'Falha na criação do ambiente isolado.' }
}
& $python -m pip install --no-input --disable-pip-version-check -r (Join-Path $windowsRoot 'Packaging\spotdl-windows-requirements.txt')
if ($LASTEXITCODE -ne 0) { throw 'Falha nas dependências fixadas do spotDL.' }
$buildArguments = @('--noconfirm', '--clean', '--distpath', $tools, '--workpath', (Join-Path $cache 'build'),
    (Join-Path $windowsRoot 'Packaging\MediaTools.spec'))
& $python -m PyInstaller @buildArguments
if ($LASTEXITCODE -ne 0) { throw 'Falha na criação do spotdl.exe.' }
& $python (Join-Path $PSScriptRoot 'CollectPythonLicenses.py') (Join-Path $tools 'Licenses\Python-packages')
if ($LASTEXITCODE -ne 0) { throw 'Falha na coleta dos avisos de licença.' }
& $python (Join-Path $PSScriptRoot 'CollectSourceNotices.py') $tools (Join-Path $cache 'source-cache') python
if ($LASTEXITCODE -ne 0) { throw 'Falha na coleta dos fontes correspondentes das dependências Python.' }
Copy-Item (Join-Path $windowsRoot 'Packaging\spotdl-windows-requirements.txt') (Join-Path $tools 'Sources') -Force
Copy-Item (Join-Path $repoRoot 'Packaging\spotdl-requirements.txt') (Join-Path $tools 'Sources') -Force
Copy-Item (Join-Path $repoRoot 'Scripts\SpotDLEntry.py') (Join-Path $tools 'Sources') -Force
Copy-Item (Join-Path $PSScriptRoot 'MediaEntry.py') (Join-Path $tools 'Sources') -Force
Copy-Item (Join-Path $windowsRoot 'Packaging\MediaTools.spec') (Join-Path $tools 'Sources') -Force
& (Join-Path $PSScriptRoot 'BuildLauncher.ps1') -OutputDirectory (Join-Path $cache 'native')
Copy-Item (Join-Path $cache 'native\yt-dlp.exe') (Join-Path $tools 'yt-dlp.exe') -Force
Copy-Item (Join-Path $PSScriptRoot 'CollectSourceNotices.py') (Join-Path $tools 'Sources') -Force
& $python -m pip freeze | Set-Content -Encoding utf8 (Join-Path $tools 'Sources\spotdl-freeze.txt')
& (Join-Path $tools 'spotdl.exe') --version
if ($LASTEXITCODE -ne 0) { throw 'spotdl.exe não abriu depois da construção.' }
& (Join-Path $tools 'spotdl.exe') --caeser-runtime-check
if ($LASTEXITCODE -ne 0) { throw 'Os catálogos internos exigidos pelo provedor estão ausentes.' }
