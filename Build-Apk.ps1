param(
    [string]$TargetPlatform = "android-arm64",
    [switch]$Universal,
    [switch]$Release
)

$ErrorActionPreference = 'Stop'
$workspace = $PSScriptRoot
$flutterBin = Join-Path $workspace 'work\flutter\bin'
$sdkPath = [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User')
if (-not $sdkPath) { $sdkPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$env:Path = "$flutterBin;$sdkPath\platform-tools;" + [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$javaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
if (-not $javaHome -or -not (Test-Path $javaHome)) { $javaHome = 'C:\Program Files\Java\jdk-17' }
$env:JAVA_HOME = $javaHome
$env:ANDROID_HOME = $sdkPath
$env:PUB_CACHE = Join-Path $env:LOCALAPPDATA 'Pub\Cache'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
Set-Location -LiteralPath $workspace

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host " Hynox Android APK Builder" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# Check Free Space
$freeGb = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
Write-Host "Free disk space on C: drive: $freeGb GB" -ForegroundColor Yellow

# Clean old bloated intermediates to save disk space
Write-Host "Pre-cleaning build intermediates to reclaim disk space..." -ForegroundColor Gray
Stop-Process -Name java, dart, adb -Force -ErrorAction SilentlyContinue
if (Test-Path "$workspace\build\app\intermediates") {
    Remove-Item -Recurse -Force "$workspace\build\app\intermediates" -ErrorAction SilentlyContinue
}
if (Test-Path "$workspace\android\.gradle") {
    Remove-Item -Recurse -Force "$workspace\android\.gradle" -ErrorAction SilentlyContinue
}

$flutter = Join-Path $flutterBin 'flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) { $flutter = 'flutter' }

Write-Host "Resolving Flutter packages..." -ForegroundColor Cyan
if (Test-Path "$workspace\.dart_tool\package_config.json") {
    Write-Host "Using existing cached packages (.dart_tool\package_config.json)..." -ForegroundColor Green
} else {
    Write-Host "Checking local cache..." -ForegroundColor Cyan
    & $flutter pub get --offline
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Offline cache miss, trying online..." -ForegroundColor Yellow
        & $flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter pub get failed. Please connect to internet to fetch missing packages.' }
    }
}

# Determine build arguments
$buildArgs = @('build', 'apk', '--no-pub')
if ($Release) {
    $buildArgs += '--release'
} else {
    $buildArgs += '--debug'
}

if (-not $Universal) {
    # Building specifically for ARM64 uses 60% less disk space and merges only 1 native lib
    $buildArgs += "--target-platform=$TargetPlatform"
    Write-Host "Targeting modern 64-bit Android ($TargetPlatform)..." -ForegroundColor Cyan
} else {
    Write-Host "Targeting universal multi-architecture build..." -ForegroundColor Cyan
}

Write-Host "Starting Gradle APK compilation (please wait)..." -ForegroundColor Cyan
& $flutter @buildArgs

if ($LASTEXITCODE -ne 0) {
    throw "APK build failed with exit code $LASTEXITCODE."
}

# Locate generated APK
$candidates = @(
    "$workspace\build\app\outputs\flutter-apk\app-debug.apk",
    "$workspace\build\app\outputs\flutter-apk\app-release.apk",
    "$workspace\build\app\outputs\flutter-apk\app-arm64-v8a-debug.apk",
    "$workspace\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
)

$sourceApk = $null
foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) {
        $sourceApk = $c
        break
    }
}

if (-not $sourceApk) {
    $found = Get-ChildItem -Path "$workspace\build\app\outputs\flutter-apk" -Filter "*.apk" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $sourceApk = $found.FullName }
}

$targetApk = Join-Path $workspace 'Hynox-POS.apk'
if ($sourceApk -and (Test-Path -LiteralPath $sourceApk)) {
    Copy-Item -LiteralPath $sourceApk -Destination $targetApk -Force
    $sizeMb = [math]::Round((Get-Item -LiteralPath $targetApk).Length / 1MB, 2)

    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host " SUCCESS! APK BUILT SUCCESSFULLY" -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host "APK File:  $targetApk" -ForegroundColor Green
    Write-Host "File Size: $sizeMb MB" -ForegroundColor Green
    Write-Host ""
    Write-Host "How to install on your Android phone:" -ForegroundColor Yellow
    Write-Host "1. Connect your phone via USB or send Hynox-POS.apk via WhatsApp/Google Drive/Email."
    Write-Host "2. On your phone, tap Hynox-POS.apk -> Install."
    Write-Host "3. Or run via ADB: adb install -r `"$targetApk`""
    Write-Host "=======================================================" -ForegroundColor Green
} else {
    Write-Host "Build completed, but could not locate the output APK." -ForegroundColor Yellow
}
