$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter no está instalado o no está en PATH."
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$tmp = Join-Path $env:TEMP ("oportu-src-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmp | Out-Null

$keep = @(
    "lib",
    "test",
    "pubspec.yaml",
    "analysis_options.yaml",
    ".env.example",
    ".gitignore",
    "README.md",
    "RELEASE_CHECKLIST.md",
    "SECURITY.md",
    "PRODUCT_SPEC.md",
    "LEGAL_AND_MODERATION.md",
    "SOURCES_2026-10-02.md",
    "CHANGELOG_V6.md",
    "ARRANCAR.ps1",
    "supabase",
    "tool"
)

foreach ($item in $keep) {
    if (Test-Path $item) {
        Copy-Item $item $tmp -Recurse -Force
    }
}

$customWeb = Join-Path $tmp "custom-web"
if (Test-Path "web\index.html") {
    New-Item -ItemType Directory -Path $customWeb -Force | Out-Null
    Copy-Item "web\index.html" (Join-Path $customWeb "index.html") -Force
}
if (Test-Path "web\robots.txt") {
    New-Item -ItemType Directory -Path $customWeb -Force | Out-Null
    Copy-Item "web\robots.txt" (Join-Path $customWeb "robots.txt") -Force
}

flutter create --platforms=android,ios,web --org app.oportu --project-name oportu .
if ($LASTEXITCODE -ne 0) {
    throw "flutter create ha fallado."
}

foreach ($item in $keep) {
    $source = Join-Path $tmp $item
    if (Test-Path $source) {
        if (Test-Path $item) {
            Remove-Item $item -Recurse -Force
        }
        Copy-Item $source $item -Recurse -Force
    }
}

if (Test-Path (Join-Path $customWeb "index.html")) {
    Copy-Item (Join-Path $customWeb "index.html") "web\index.html" -Force
}
if (Test-Path (Join-Path $customWeb "robots.txt")) {
    Copy-Item (Join-Path $customWeb "robots.txt") "web\robots.txt" -Force
}

# Oportu Web es una web responsive del producto, no una PWA instalable.
Remove-Item "web\manifest.json" -Force -ErrorAction SilentlyContinue

$manifest = "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifest) {
    $content = Get-Content $manifest -Raw
    $content = $content -replace 'android:label="oportu"', 'android:label="Oportu"'
    Set-Content $manifest $content -Encoding UTF8
}

flutter pub get
if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get ha fallado."
}

flutter analyze
if ($LASTEXITCODE -ne 0) {
    throw "flutter analyze ha fallado."
}

flutter test
if ($LASTEXITCODE -ne 0) {
    throw "flutter test ha fallado."
}

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Oportu listo. Android/iOS/web generados y código validado." -ForegroundColor Green
