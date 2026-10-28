[CmdletBinding()]
param([switch]$DownloadChecksOnly)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows -or $env:GITHUB_ACTIONS -ne 'true') { throw 'Teste permitido somente na VM Windows descartável do GitHub.' }
$windowsRoot = Split-Path $PSScriptRoot -Parent
[xml]$props = Get-Content -Raw (Join-Path $windowsRoot 'Directory.Build.props')
$version = [string]$props.Project.PropertyGroup.Version
$dist = Join-Path $windowsRoot 'artifacts\dist'
$installer = Join-Path $dist "Caeser-$version-Windows-x64-Setup.exe"
$online = Join-Path $dist "Caeser-$version-Windows-x64-Online.exe"
$testBinary = Join-Path $windowsRoot 'artifacts\bootstrap-tests\Bootstrap.Test.exe'
$qa = Join-Path $windowsRoot 'artifacts\bootstrap-qa'
$work = Join-Path $env:RUNNER_TEMP ('Caeser-bootstrap-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work, $qa -Force | Out-Null
$portFile = Join-Path $work 'port.txt'
$server = Start-Process -FilePath (Get-Command python).Source -ArgumentList @('-u', ('"' + (Join-Path $PSScriptRoot 'BootstrapFixtureServer.py') + '"'), ('"' + $installer + '"'), ('"' + $portFile + '"')) -PassThru
function Run-Bootstrap([string]$Executable, [string[]]$Arguments, [int]$Timeout = 120000) {
    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -PassThru
    if (-not $process.WaitForExit($Timeout)) { $process.Kill($true); throw 'O instalador online não terminou dentro do limite.' }
    $code = $process.ExitCode
    Write-Host "Bootstrap $($Arguments[0]): exit=$code"
    if ($null -eq $code) { throw 'O Windows não informou o código de saída do instalador de teste.' }
    return $code
}
$destination = Join-Path $work 'Caeser ação'
try {
    for ($attempt = 0; $attempt -lt 100 -and -not (Test-Path $portFile); $attempt++) { Start-Sleep -Milliseconds 100 }
    if (-not (Test-Path $portFile)) { throw 'O servidor local não iniciou.' }
    $base = 'http://127.0.0.1:' + (Get-Content -Raw $portFile)
    if ((Run-Bootstrap $online @('--self-test')) -ne 0) { throw 'A configuração do instalador distribuído é inválida.' }
    if ((Run-Bootstrap $online @('--test-download', "$base/ok")) -ne 87) { throw 'O instalador público aceitou uma opção exclusiva dos testes.' }
    foreach ($route in @('corrupt', 'truncated', 'redirect')) {
        if ((Run-Bootstrap $testBinary @('--test-download', "$base/$route")) -eq 0) { throw "O instalador aceitou a resposta inválida: $route" }
    }
    $cancelCode = Run-Bootstrap $testBinary @('--test-cancel', "$base/slow")
    if ($cancelCode -ne 1223) { throw "O cancelamento pelo diálogo não interrompeu o download. Código recebido: $cancelCode; esperado: 1223." }
    if ($DownloadChecksOnly) {
        if ((Run-Bootstrap $testBinary @('--test-download', "$base/ok")) -ne 0) { throw 'O download local válido não passou na conferência.' }
        Write-Host 'Verificações isoladas: configuração, integridade, redirecionamento e cancelamento aprovados.'
        return
    }
    $download = Start-Process -FilePath $testBinary -ArgumentList @('--test-download', "$base/ok") -PassThru
    Start-Sleep -Milliseconds 800
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = [System.Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size); $bitmap.Save((Join-Path $qa 'bootstrap-progress.png')) }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
    if (-not $download.WaitForExit(120000) -or $download.ExitCode -ne 0) { throw 'O download local válido não passou na conferência.' }
    # Measure the previous published version under the same clean test path.
    $previous = Join-Path $work 'previous.exe'
    & curl.exe --fail --location --retry 3 --max-time 180 --output $previous -- 'https://github.com/cnolli-fl/Caeser/releases/download/windows-v2.1.0/Caeser-2.1.0-Windows-x64-Setup.exe'
    if ($LASTEXITCODE -ne 0 -or (Get-FileHash $previous -Algorithm SHA256).Hash.ToLowerInvariant() -ne '6faf3d08b554e18d7388a8b1436be0c6960aafcfb4b877c17f10ee36cf3f90a4') { throw 'A versão anterior não corresponde ao arquivo verificado.' }
    $old = Start-Process $previous -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', ('/DIR="' + $destination + '"')) -PassThru
    if (-not $old.WaitForExit(120000) -or $old.ExitCode -ne 0) { throw 'A instalação de referência falhou.' }
    $before = [long](Get-ChildItem $destination -Recurse -File | Measure-Object Length -Sum).Sum
    $filesBefore = @(Get-ChildItem $destination -Recurse -File).Count
    $oldNotices = Join-Path $destination 'Documentacao\Ferramentas'
    $registeredNotice = (Get-ChildItem $oldNotices -Recurse -File | Select-Object -First 1).FullName
    if (-not $registeredNotice) { throw 'A referência não contém os avisos legais anteriores.' }
    $nestedSentinel = Join-Path $oldNotices 'arquivo-extra-do-usuario.txt'
    'Preservar também dentro das pastas antigas.' | Set-Content $nestedSentinel
    $oldTools = Join-Path $destination 'Aplicativo\Tools'
    $extractorsBefore = (& (Join-Path $oldTools 'yt-dlp.exe') --ignore-config --list-extractors | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $extractorsBefore.Length -lt 1000) { throw 'Falha ao inventariar extratores anteriores.' }
    $codecsBefore = (& (Join-Path $oldTools 'ffmpeg.exe') -hide_banner -codecs 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao inventariar codecs anteriores.' }
    $sentinel = Join-Path $destination 'arquivo-do-usuario.txt'; 'Preservar' | Set-Content $sentinel
    if ((Run-Bootstrap $testBinary @('--test-install', "$base/ok", ('"' + $destination + '"')) 180000) -ne 0) { throw 'A instalação pelo bootstrapper falhou.' }
    $application = Join-Path $destination 'Aplicativo\Caeser.exe'
    $reopened = $null
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        $reopened = Get-Process -Name Caeser -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $application -and $_.MainWindowHandle -ne 0 }
        if ($reopened) { break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $reopened) { throw 'O Caeser não abriu depois da instalação online.' }
    $reopened | Stop-Process -Force
    if (-not (Test-Path $sentinel)) { throw 'Um arquivo extra do usuário foi removido.' }
    if (-not (Test-Path $nestedSentinel)) { throw 'Um arquivo extra na pasta de documentação foi removido.' }
    if ((Test-Path $registeredNotice) -or -not (Test-Path (Join-Path $destination 'Documentacao\Ferramentas.zip'))) { throw 'Os avisos antigos não foram substituídos pelo arquivo completo organizado.' }
    $newTools = Join-Path $destination 'Aplicativo\Tools'
    $extractorsAfter = (& (Join-Path $newTools 'yt-dlp.exe') --ignore-config --list-extractors | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $extractorsAfter -cne $extractorsBefore) { throw 'O conjunto de extratores mudou durante a otimização.' }
    $codecsAfter = (& (Join-Path $newTools 'ffmpeg.exe') -hide_banner -codecs 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $codecsAfter -cne $codecsBefore) { throw 'O conjunto de codecs mudou durante a otimização.' }
    $after = [long](Get-ChildItem $destination -Recurse -File | Measure-Object Length -Sum).Sum
    $filesAfter = @(Get-ChildItem $destination -Recurse -File).Count
    if ($after -ge $before) { throw 'A instalação otimizada não ficou menor que a 2.1.0.' }
    if ($filesAfter -ge $filesBefore) { throw 'A instalação não reduziu a quantidade de arquivos.' }
    if ((Get-Item $installer).Length -ge (Get-Item $previous).Length) { throw 'O instalador completo não ficou menor que o da 2.1.0.' }
    & (Join-Path $PSScriptRoot 'TestUi.ps1') -ApplicationDirectory $destination -OutputDirectory (Join-Path $qa 'installed-ui')
    @{ succeeded = $true; previousInstalledBytes = $before; installedBytes = $after; previousFiles = $filesBefore; installedFiles = $filesAfter; previousSetupBytes = (Get-Item $previous).Length;
       setupBytes = (Get-Item $installer).Length; onlineBytes = (Get-Item $online).Length;
       corruptRejected = $true; truncatedRejected = $true; redirectRejected = $true; cancellation = $true; reopened = $true } |
        ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $qa 'result.json')
    Copy-Item (Join-Path $qa 'result.json') (Join-Path $dist 'optimization-report.json') -Force
} finally {
    if (-not $server.HasExited) { $server.Kill($true) }
    if (Test-Path (Join-Path $destination 'Caeser.exe')) {
        $key = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{8362D1BB-D499-462E-9633-409161F21111}_is1'
        $uninstaller = ([string]$key.UninstallString).Trim('"')
        if ([IO.Path]::GetDirectoryName($uninstaller) -ne $destination -or [IO.Path]::GetFileName($uninstaller) -notmatch '^unins\d+\.exe$') { throw 'Desinstalador fora da pasta isolada de teste.' }
        $remove = Start-Process $uninstaller -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') -PassThru
        if (-not $remove.WaitForExit(60000) -or $remove.ExitCode -ne 0) { throw 'Falha ao remover a instalação de teste.' }
    }
}
Write-Host 'Bootstrapper: integridade, cancelamento, instalação, atualização da 2.1.0, redução em disco e reabertura verificados.'
