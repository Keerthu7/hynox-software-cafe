param(
    [string]$DeviceId
)
$ErrorActionPreference = 'Stop'
$flutterBin = Join-Path $PSScriptRoot 'work\flutter\bin'
$sdkPath = [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User')
if (-not $sdkPath) { $sdkPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$env:Path = "$flutterBin;$sdkPath\platform-tools;" + [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
    $env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
    if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
        $env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
    }
}
$env:ANDROID_HOME = $sdkPath
$env:PUB_CACHE = Join-Path $env:LOCALAPPDATA 'Pub\Cache'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
Set-Location -LiteralPath $PSScriptRoot
$flutter = Join-Path $flutterBin 'flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) { $flutter = 'flutter' }

if (-not $DeviceId) {
    $rawOutput = @(adb devices)
    $allDevices = @($rawOutput | Where-Object { $_ -match '^\S+\s+\S+$' -and $_ -notmatch '^List of' })
    $unauthorized = @($allDevices | Where-Object { $_ -match '\bunauthorized\b' })
    if ($unauthorized.Count -gt 0) {
        Write-Host "Action Required: Check your phone screen and tap 'Allow USB debugging'." -ForegroundColor Yellow
        throw 'Phone authorization needed. Please allow USB debugging on your phone.'
    }
    $deviceLines = @($allDevices | Where-Object { $_ -match '^\S+\s+device$' })
    if ($deviceLines.Count -eq 0) {
        Write-Host "No Android phone detected with USB debugging." -ForegroundColor Yellow
        Write-Host "1. Connect phone with USB cable."
        Write-Host "2. Enable USB Debugging in phone Settings -> Developer Options."
        Write-Host "3. Or run .\BUILD-APK.cmd to install the APK directly without USB debugging."
        throw 'Connect one unlocked Android phone with USB debugging enabled, or pass -DeviceId.'
    }
    $DeviceId = ($deviceLines[0] -split '\s+')[0]
}

if (-not (Test-Path "$PSScriptRoot\.dart_tool\package_config.json")) {
    & $flutter pub get --offline
    if ($LASTEXITCODE -ne 0) { & $flutter pub get }
}
& $flutter run -d $DeviceId --debug --no-pub
