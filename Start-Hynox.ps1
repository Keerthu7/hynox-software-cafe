$ErrorActionPreference = 'Stop'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'flutter-local.ps1') run -d chrome --web-port=8766
exit $LASTEXITCODE
