$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter no está instalado o no está en PATH."
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$tmp = Join-Path $env:TEMP ("gratiscash-src-" + [guid]::NewGuid().ToString())
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

flutter create --platforms=android,ios,web --org com.gratiscash --project-name gratiscash .
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

# GratisCash Web es una web responsive del producto, no una PWA instalable.
Remove-Item "web\manifest.json" -Force -ErrorAction SilentlyContinue

$androidKts = "android\app\build.gradle.kts"
if (Test-Path $androidKts) {
    $content = Get-Content $androidKts -Raw
    $content = $content -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24'
    Set-Content $androidKts $content -Encoding UTF8
}

$androidGroovy = "android\app\build.gradle"
if (Test-Path $androidGroovy) {
    $content = Get-Content $androidGroovy -Raw
    $content = $content -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24'
    Set-Content $androidGroovy $content -Encoding UTF8
}

$podfile = "ios\Podfile"
if (Test-Path $podfile) {
    $content = Get-Content $podfile -Raw
    $content = $content -replace '#?\s*platform\s*:ios,\s*[''"]\d+(?:\.\d+)?[''"]', "platform :ios, '13.0'"
    Set-Content $podfile $content -Encoding UTF8
}

$manifest = "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifest) {
    $content = Get-Content $manifest -Raw
    $content = $content -replace 'android:label="gratiscash"', 'android:label="GratisCash"'
    Set-Content $manifest $content -Encoding UTF8
}

$plist = "ios\Runner\Info.plist"
if (Test-Path $plist) {
    $content = Get-Content $plist -Raw
    $content = $content -replace '<string>gratiscash</string>', '<string>GratisCash</string>'
    if ($content -notmatch 'NSPhotoLibraryUsageDescription') {
        $permission = @"
    <key>NSPhotoLibraryUsageDescription</key>
    <string>GratisCash necesita acceso a tu fototeca únicamente cuando eliges una imagen para una oportunidad o tu perfil.</string>
"@
        $content = $content -replace '</dict>\s*</plist>', ($permission + "</dict>`r`n</plist>")
    }
    Set-Content $plist $content -Encoding UTF8
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
Write-Host "GratisCash listo. Android/iOS/web generados y código validado." -ForegroundColor Green
