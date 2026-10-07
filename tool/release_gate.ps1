param(
    [Parameter(Mandatory=$true)][string]$SupabaseUrl,
    [Parameter(Mandatory=$true)][string]$PublishableKey,
    [Parameter(Mandatory=$true)][string]$WebsiteUrl,
    [Parameter(Mandatory=$true)][string]$LegalOwner,
    [Parameter(Mandatory=$true)][string]$LegalEmail,
    [Parameter(Mandatory=$true)][string]$LegalAddress,
    [bool]$GoogleAuthEnabled = $false
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) {
    $flutter = $flutterCommand.Source
} elseif (Test-Path "C:\src\flutter\bin\flutter.bat") {
    $flutter = "C:\src\flutter\bin\flutter.bat"
} else {
    throw "No encuentro Flutter. Instálalo o añádelo al PATH."
}
Set-Location $root

$ExpectedFlutterVersion = "3.41.6"
$flutterVersion = (& $flutter --version | Select-Object -First 1)
if ($flutterVersion -notlike "*Flutter $ExpectedFlutterVersion*") {
    throw "Flutter debe ser $ExpectedFlutterVersion para este release. Detectado: $flutterVersion"
}

function Assert-RealValue([string]$Name, [string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.ToUpper().Contains("PENDIENTE") -or $Value.Contains("TU-PROYECTO") -or $Value.Contains("tu-dominio")) {
        throw "$Name sigue siendo un marcador. Release bloqueado."
    }
}

Assert-RealValue "SUPABASE_URL" $SupabaseUrl
Assert-RealValue "SUPABASE_PUBLISHABLE_KEY" $PublishableKey
Assert-RealValue "WEBSITE_URL" $WebsiteUrl
Assert-RealValue "LEGAL_OWNER" $LegalOwner
Assert-RealValue "LEGAL_EMAIL" $LegalEmail
Assert-RealValue "LEGAL_ADDRESS" $LegalAddress

if (-not $SupabaseUrl.StartsWith("https://")) { throw "SUPABASE_URL debe usar HTTPS." }
if (-not $WebsiteUrl.StartsWith("https://")) { throw "WEBSITE_URL de producción debe usar HTTPS." }

$forbidden = @("DemoRepository", "demoMode", "@modo_demo", "demo_data.dart")
$runtimeFiles = Get-ChildItem (Join-Path $root "lib") -Recurse -Filter "*.dart"
foreach ($token in $forbidden) {
    $hit = Select-String -Path $runtimeFiles.FullName -SimpleMatch $token -ErrorAction SilentlyContinue
    if ($hit) { throw "Runtime contiene token prohibido '$token'. Release bloqueado." }
}

& $flutter pub get
if ($LASTEXITCODE -ne 0) { throw "pub get falló." }

$lockFile = Join-Path $root "pubspec.lock"
if (-not (Test-Path $lockFile)) {
    throw "pubspec.lock no existe después de pub get. Release bloqueado."
}
$lockStatus = (& git status --porcelain -- "pubspec.lock") -join ""
if (-not [string]::IsNullOrWhiteSpace($lockStatus)) {
    throw "pubspec.lock está sin commitear o desactualizado. Haz pub get y guarda el lockfile antes del release."
}

& $flutter analyze
if ($LASTEXITCODE -ne 0) { throw "analyze falló." }
& $flutter test
if ($LASTEXITCODE -ne 0) { throw "tests fallaron." }

$defines = @(
    "--dart-define=APP_ENV=production",
    "--dart-define=SUPABASE_URL=$SupabaseUrl",
    "--dart-define=SUPABASE_PUBLISHABLE_KEY=$PublishableKey",
    "--dart-define=WEBSITE_URL=$WebsiteUrl",
    "--dart-define=AUTH_REDIRECT_URL=$WebsiteUrl/auth",
    "--dart-define=GOOGLE_AUTH_ENABLED=$($GoogleAuthEnabled.ToString().ToLower())",
    "--dart-define=LEGAL_OWNER=$LegalOwner",
    "--dart-define=LEGAL_EMAIL=$LegalEmail",
    "--dart-define=LEGAL_ADDRESS=$LegalAddress"
)

Write-Host "Release gate superado. Generando Android App Bundle y web..." -ForegroundColor Green
& $flutter build appbundle --release @defines
if ($LASTEXITCODE -ne 0) { throw "Android release build falló." }
& $flutter build web --release @defines
if ($LASTEXITCODE -ne 0) { throw "Web release build falló." }

Write-Host "Android + web generados. iOS release debe validarse y firmarse en macOS/Xcode." -ForegroundColor Green
