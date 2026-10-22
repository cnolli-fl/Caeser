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
# Verify the real upgrade from the published, flat-layout 1.1.1 installer.
# Download is immutable-by-hash, and execution is limited to this disposable VM.
$legacy = Join-Path $env:RUNNER_TEMP ('Caeser-legacy-' + [Guid]::NewGuid().ToString('N') + '.exe')
& curl.exe --fail --location --retry 3 --max-time 180 --output $legacy -- 'https://github.com/cnolli-fl/Caeser/releases/download/windows-v1.1.1/Caeser-1.1.1-Windows-x64-Setup.exe'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao obter o instalador anterior para o teste de atualização.' }
if ((Get-FileHash $legacy -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'a8d6f0ab373e5a51424004c04f723865c28a179e9ec930d229b7b3305f9d0574') { throw 'O instalador anterior não corresponde ao arquivo validado.' }
$previous = Start-Process -FilePath $legacy -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', ('/DIR="' + $destination + '"')) -PassThru
if (-not $previous.WaitForExit(120000)) { $previous.Kill($true); throw 'O instalador anterior não terminou.' }
if ($previous.ExitCode -ne 0) { throw 'Falha ao instalar a versão anterior para testar atualização.' }
$sentinel = Join-Path $destination 'arquivo-do-usuario-nao-apagar.txt'
'Arquivo não registrado pelo instalador; deve sobreviver à atualização.' | Set-Content -Encoding utf8 $sentinel
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
    if (Test-Path (Join-Path $destination 'Tools')) { throw 'A atualização deixou ferramentas/fontes da instalação antiga na raiz.' }
    if (-not (Test-Path $sentinel)) { throw 'A atualização apagou um arquivo não registrado do usuário.' }
    & (Join-Path $PSScriptRoot 'TestUi.ps1') -ApplicationDirectory $destination -OutputDirectory (Join-Path $windowsRoot 'artifacts\installed-ui')
} finally {
    # Inno reserves a new uninsNNN name before PrepareToInstall runs. During
    # an upgrade the current uninstaller is often unins001, not unins000.
    # Resolve the registered executable and validate the exact test directory.
    $registration = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{8362D1BB-D499-462E-9633-409161F21111}_is1' -ErrorAction Stop
    $uninstaller = ([string]$registration.UninstallString).Trim('"')
    if ([IO.Path]::GetFullPath([IO.Path]::GetDirectoryName($uninstaller)).TrimEnd('\') -ne [IO.Path]::GetFullPath($destination).TrimEnd('\')) {
        throw 'O desinstalador registrado não pertence à instalação temporária deste teste.'
    }
    if ([IO.Path]::GetFileName($uninstaller) -notmatch '^unins\d+\.exe$') { throw 'Nome inesperado de desinstalador.' }
    if (Test-Path $uninstaller) {
        $remove = Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') -PassThru
        if (-not $remove.WaitForExit(60000)) { $remove.Kill($true); throw 'A desinstalação não terminou.' }
        if ($remove.ExitCode -ne 0) { throw "Desinstalação encerrou com código $($remove.ExitCode)." }
    }
}
if (Test-Path (Join-Path $destination 'Caeser.exe')) { throw 'O executável continuou instalado após desinstalar.' }
if (-not (Test-Path $sentinel)) { throw 'A desinstalação apagou um arquivo não registrado do usuário.' }
Write-Host 'Atualização da 1.1.1, pasta limpa, preservação de arquivo do usuário, abertura real e desinstalação verificadas na VM descartável.'
