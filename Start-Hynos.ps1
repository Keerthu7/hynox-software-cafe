$ErrorActionPreference = 'Stop'
$flutter = Join-Path $PSScriptRoot 'work\flutter\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) {
    $flutter = 'flutter'
}
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:PUB_CACHE = Join-Path $env:LOCALAPPDATA 'Pub\Cache'
& $flutter run -d chrome -t lib/main.dart --web-port=8766
exit $LASTEXITCODE
