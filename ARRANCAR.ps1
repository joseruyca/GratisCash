$ErrorActionPreference = "Stop"

$project = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) {
    $flutter = $flutterCommand.Source
} elseif (Test-Path "C:\src\flutter\bin\flutter.bat") {
    $flutter = "C:\src\flutter\bin\flutter.bat"
} else {
    throw "No encuentro Flutter. Instálalo o añádelo al PATH."
}
$port = 8080
$url = "http://localhost:$port"
$configFile = Join-Path $project "tool\local_config.ps1"

Set-Location $project

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " GRATISCASH | VALIDAR Y ABRIR" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1/3 Dependencias..." -ForegroundColor Cyan
& $flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get ha fallado." }

Write-Host ""
Write-Host "2/3 Analisis..." -ForegroundColor Cyan
& $flutter analyze
if ($LASTEXITCODE -ne 0) { throw "flutter analyze ha encontrado errores." }

Write-Host ""
Write-Host "3/3 Tests..." -ForegroundColor Cyan
& $flutter test
if ($LASTEXITCODE -ne 0) { throw "flutter test ha fallado." }

$defines = @()
if (Test-Path $configFile) {
    . $configFile
    if ($null -eq $GratisCashConfig) {
        throw "tool\local_config.ps1 existe pero no define `$GratisCashConfig."
    }
    foreach ($key in $GratisCashConfig.Keys) {
        $value = [string]$GratisCashConfig[$key]
        $defines += "--dart-define=$key=$value"
    }
    Write-Host ""
    Write-Host "Backend/configuracion local detectados." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "No hay backend real conectado todavía." -ForegroundColor Yellow
    Write-Host "GratisCash abrirá el bloqueo de configuración, no datos simulados." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " GRATISCASH VALIDADO" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Direccion:" -ForegroundColor Cyan
Write-Host $url -ForegroundColor Yellow
Write-Host ""

$openCommand = "Start-Sleep -Seconds 5; Start-Process '$url'"
Start-Process powershell -WindowStyle Hidden -ArgumentList "-NoProfile", "-Command", $openCommand | Out-Null

& $flutter run -d chrome --web-port $port @defines
if ($LASTEXITCODE -ne 0) { throw "GratisCash no ha podido arrancar en Chrome." }
