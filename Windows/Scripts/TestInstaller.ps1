[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Este teste instala o aplicativo somente no runner Windows.' }
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Execute este teste automatizado apenas em uma VM descartável do GitHub Actions.' }
$windowsRoot = Split-Path $PSScriptRoot -Parent
[xml]$properties = Get-Content -Raw (Join-Path $windowsRoot 'Directory.Build.props')
$version = $properties.Project.PropertyGroup.Version
$installer = Join-Path $windowsRoot "artifacts\dist\Caeser-$version-Windows-x64-Setup.exe"
$destination = Join-Path $env:RUNNER_TEMP ('Caeser-install-test-' + [Guid]::NewGuid().ToString('N'))
$log = Join-Path $windowsRoot 'artifacts\installer-test.log'
$arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', ('/DIR="' + $destination + '"'), ('/LOG="' + $log + '"'))
$process = Start-Process -FilePath $installer -ArgumentList $arguments -PassThru
if (-not $process.WaitForExit(120000)) {
    $process.Kill($true)
    throw 'O instalador não terminou dentro do limite.'
}
if ($process.ExitCode -ne 0) { throw "Instalador encerrou com código $($process.ExitCode)." }
try {
    foreach ($relative in @('Caeser.exe', 'Aplicativo\Caeser.exe', 'Aplicativo\resources.pri', 'Aplicativo\Tools\yt-dlp.exe', 'Aplicativo\Tools\ffmpeg.exe', 'Aplicativo\Tools\spotdl.exe', 'Documentacao\THIRD-PARTY.md')) {
        if (-not (Test-Path (Join-Path $destination $relative))) { throw "Arquivo não foi instalado: $relative" }
    }
    $product = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $destination 'Caeser.exe'))
    if ($product.ProductVersion -ne $version) { throw "O aplicativo instalado não está na versão $version." }
    if ((Get-ChildItem $destination -File -Filter '*.dll').Count -gt 0) { throw 'Bibliotecas internas ficaram soltas na raiz da instalação.' }
    & (Join-Path $PSScriptRoot 'TestUi.ps1') -ApplicationDirectory $destination -OutputDirectory (Join-Path $windowsRoot 'artifacts\installed-ui')
} finally {
    $uninstaller = Join-Path $destination 'unins000.exe'
    if (Test-Path $uninstaller) {
        $remove = Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') -PassThru
        if (-not $remove.WaitForExit(60000)) { $remove.Kill($true); throw 'A desinstalação não terminou.' }
        if ($remove.ExitCode -ne 0) { throw "Desinstalação encerrou com código $($remove.ExitCode)." }
    }
}
if (Test-Path (Join-Path $destination 'Caeser.exe')) { throw 'O executável continuou instalado após desinstalar.' }
Write-Host 'Instalação por usuário, abertura real e desinstalação verificadas na VM descartável.'
