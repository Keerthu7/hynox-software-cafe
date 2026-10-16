Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host " Hynox Disk Cleanup Utility" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

$before = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
Write-Host "Current Free Space on C: drive: $before GB" -ForegroundColor Yellow

Write-Host "1. Stopping hanging Java, Gradle, and Dart background processes..." -ForegroundColor Gray
Stop-Process -Name java, dart, adb -Force -ErrorAction SilentlyContinue

Write-Host "2. Deleting project build output folder (build/)..." -ForegroundColor Gray
if (Test-Path -LiteralPath "$PSScriptRoot\build") {
    Remove-Item -LiteralPath "$PSScriptRoot\build" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "3. Deleting Gradle temporary caches (android\.gradle)..." -ForegroundColor Gray
if (Test-Path -LiteralPath "$PSScriptRoot\android\.gradle") {
    Remove-Item -LiteralPath "$PSScriptRoot\android\.gradle" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "4. Cleaning old Gradle transform caches ($env:USERPROFILE\.gradle\caches)..." -ForegroundColor Gray
$gradleTransforms = "$env:USERPROFILE\.gradle\caches"
if (Test-Path -LiteralPath $gradleTransforms) {
    Get-ChildItem -Path $gradleTransforms -Filter "transforms-*" -Directory -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "5. Clearing Windows temp files ($env:LOCALAPPDATA\Temp)..." -ForegroundColor Gray
Get-ChildItem -Path "$env:LOCALAPPDATA\Temp" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "6. Emptying Windows Recycle Bin..." -ForegroundColor Gray
Clear-RecycleBin -Force -ErrorAction SilentlyContinue

$after = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
$freed = [math]::Round($after - $before, 2)

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Green
Write-Host "CLEANUP FINISHED!" -ForegroundColor Green
Write-Host "Free Space Before: $before GB"
Write-Host "Free Space Now:    $after GB" -ForegroundColor Green
if ($freed -gt 0) {
    Write-Host "Space Reclaimed:   +$freed GB" -ForegroundColor Green
}
Write-Host "=======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. To test immediately in your browser: Run .\START-HYNOS.cmd"
Write-Host "2. To run on Android: Ensure USB debugging is on, then run .\RUN-ANDROID.cmd"
Write-Host ""
