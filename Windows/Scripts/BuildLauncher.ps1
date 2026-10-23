[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'O launcher nativo precisa do compilador Windows.' }
$windowsRoot = Split-Path $PSScriptRoot -Parent
[xml]$properties = Get-Content -Raw (Join-Path $windowsRoot 'Directory.Build.props')
$version = [string]$properties.Project.PropertyGroup.Version
$numeric = ([version]$version).ToString(3).Replace('.', ',') + ',0'
$build = Join-Path $windowsRoot ('artifacts\launcher-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $build, $OutputDirectory -Force | Out-Null
$icon = (Resolve-Path (Join-Path $windowsRoot 'Caeser.App\Assets\Caeser.ico')).Path.Replace('\', '\\')
$resource = (Get-Content -Raw (Join-Path $windowsRoot 'Caeser.Launcher\launcher.rc')).Replace('@ICON@', $icon).Replace('@VERSION_NUMERIC@', $numeric).Replace('@VERSION@', $version)
$rc = Join-Path $build 'launcher.rc'
$resource | Set-Content -Encoding utf8 $rc
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'Instale o Visual Studio Build Tools com C++ x64.' }
$module = Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll'
Import-Module $module
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
$source = Join-Path $windowsRoot 'Caeser.Launcher\main.c'
$res = Join-Path $build 'launcher.res'
$obj = Join-Path $build 'launcher.obj'
$executable = Join-Path $OutputDirectory 'Caeser.exe'
& rc.exe /nologo /fo $res $rc
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar os recursos do launcher.' }
& cl.exe /nologo /O1 /MT /W4 /WX /DUNICODE /D_UNICODE $source $res "/Fe:$executable" "/Fo:$obj" /link user32.lib /SUBSYSTEM:WINDOWS /MACHINE:X64 /DYNAMICBASE /NXCOMPAT /HIGHENTROPYVA
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o launcher nativo.' }
& cl.exe /nologo /O1 /MT /W4 /WX /DUNICODE /D_UNICODE (Join-Path $windowsRoot 'Caeser.Launcher\ytdlp.c') "/Fe:$(Join-Path $OutputDirectory 'yt-dlp.exe')" "/Fo:$(Join-Path $build 'ytdlp.obj')" /link /SUBSYSTEM:CONSOLE /MACHINE:X64 /DYNAMICBASE /NXCOMPAT /HIGHENTROPYVA
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o encaminhador yt-dlp.' }
