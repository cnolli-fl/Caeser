[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Este teste instala a prévia somente no runner Windows.' }
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Execute este teste automatizado apenas em uma VM descartável do GitHub Actions.' }
$windowsRoot = Split-Path $PSScriptRoot -Parent
$installer = Join-Path $windowsRoot 'artifacts\dist\Caeser-2.1.0-Windows-x64-Preview-Setup.exe'
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
    foreach ($relative in @('Caeser.exe', 'Tools\yt-dlp.exe', 'Tools\ffmpeg.exe', 'Tools\spotdl.exe')) {
        if (-not (Test-Path (Join-Path $destination $relative))) { throw "Arquivo não foi instalado: $relative" }
    }
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
