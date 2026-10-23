[CmdletBinding()]
param([Parameter(Mandatory)][string]$Installer, [Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Compile o instalador online em Windows x64.' }
$windowsRoot = Split-Path $PSScriptRoot -Parent
[xml]$props = Get-Content -Raw (Join-Path $windowsRoot 'Directory.Build.props')
$version = [string]$props.Project.PropertyGroup.Version
$installerPath = (Resolve-Path $Installer).Path
$hash = (Get-FileHash $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
$bytes = (Get-Item $installerPath).Length
if ($bytes -le 0 -or $bytes -gt 512MB -or [IO.Path]::GetFileName($installerPath) -ne "Caeser-$version-Windows-x64-Setup.exe") { throw 'Payload inválido para o instalador online.' }
$build = Join-Path $windowsRoot ('artifacts\bootstrap-' + [Guid]::NewGuid().ToString('N'))
$tests = Join-Path $windowsRoot 'artifacts\bootstrap-tests'
New-Item -ItemType Directory -Path $build, $OutputDirectory, $tests -Force | Out-Null
$payloadUrl = "https://github.com/cnolli-fl/Caeser/releases/download/windows-v$version/Caeser-$version-Windows-x64-Setup.exe"
@("#define PAYLOAD_VERSION L`"$version`"", "#define PAYLOAD_URL L`"$payloadUrl`"", "#define PAYLOAD_SHA256 L`"$hash`"", "#define PAYLOAD_BYTES $($bytes)ULL") | Set-Content -Encoding utf8 (Join-Path $build 'payload.h')
$resource = (Get-Content -Raw (Join-Path $windowsRoot 'Caeser.Launcher\launcher.rc')).Replace('@ICON@', (Join-Path $windowsRoot 'Caeser.App\Assets\Caeser.ico').Replace('\', '\\')).Replace('@VERSION_NUMERIC@', (([version]$version).ToString(3).Replace('.', ',') + ',0')).Replace('@VERSION@', $version)
$resource += "`n1 24 `"$((Join-Path $windowsRoot 'Caeser.Bootstrap\bootstrap.manifest').Replace('\', '\\'))`"`n"
$rc = Join-Path $build 'bootstrap.rc'; $resource | Set-Content -Encoding utf8 $rc
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'Compilador C++ x64 não encontrado.' }
Import-Module (Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
$res = Join-Path $build 'bootstrap.res'
& rc.exe /nologo /fo $res $rc
if ($LASTEXITCODE -ne 0) { throw 'Falha nos recursos do instalador online.' }
$output = Join-Path $OutputDirectory "Caeser-$version-Windows-x64-Online.exe"
foreach ($testing in @($false, $true)) {
    $target = if ($testing) { Join-Path $tests 'Bootstrap.Test.exe' } else { $output }
    [string[]]$extra = @()
    if ($testing) { $extra = @('/DCAESER_BOOTSTRAP_TEST') }
    & cl.exe /nologo /O1 /MT /W4 /utf-8 /std:c++17 /EHsc /DUNICODE /D_UNICODE /D_WIN32_WINNT=0x0A00 @extra "/I$build" (Join-Path $windowsRoot 'Caeser.Bootstrap\main.cpp') $res "/Fe:$target" "/Fo:$(Join-Path $build ('bootstrap-' + $testing + '.obj'))" /link winhttp.lib bcrypt.lib comctl32.lib shell32.lib ole32.lib uuid.lib user32.lib /MANIFEST:NO /SUBSYSTEM:WINDOWS /MACHINE:X64 /DYNAMICBASE /NXCOMPAT /HIGHENTROPYVA
    if ($LASTEXITCODE -ne 0) { throw 'Falha na compilação do instalador online.' }
}
if ((Get-Item $output).Length -gt 1MB) { throw 'O instalador online ultrapassou a meta de 1 MB.' }
$selfTest = Start-Process -FilePath $output -ArgumentList '--self-test' -Wait -PassThru
if ($selfTest.ExitCode -ne 0) { throw 'O instalador online não passou na verificação de configuração.' }
@{ version = $version; payload = [IO.Path]::GetFileName($installerPath); url = $payloadUrl; sha256 = $hash; bytes = $bytes;
   online = [IO.Path]::GetFileName($output); onlineBytes = (Get-Item $output).Length } |
    ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $OutputDirectory 'bootstrap-metadata.json')
Write-Host "Instalador online: $((Get-Item $output).Length) bytes; pacote: $bytes bytes."
