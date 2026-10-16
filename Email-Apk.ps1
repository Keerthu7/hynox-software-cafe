$recipient = "keerthanasubbu5@gmail.com"
$apkPath = Join-Path $PSScriptRoot "Hynox-POS.apk"

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host " Hynox APK Email & Transfer Helper" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target Recipient: $recipient" -ForegroundColor Green
Write-Host "APK Location:     $apkPath" -ForegroundColor Yellow

if (-not (Test-Path -LiteralPath $apkPath)) {
    Write-Host "ERROR: Hynox-POS.apk not found. Please run .\BUILD-APK.cmd first." -ForegroundColor Red
    return
}

$sizeMb = [math]::Round((Get-Item -LiteralPath $apkPath).Length / 1MB, 2)
Write-Host "APK File Size:    $sizeMb MB" -ForegroundColor Yellow
Write-Host ""

# Copy APK file path to clipboard for quick paste
Set-Clipboard -Value $apkPath
Write-Host "[OK] APK file path copied to clipboard! (Press Ctrl+V to paste path anywhere)" -ForegroundColor Green

# 1. Open File Explorer with the APK selected
Write-Host "1. Opening folder with Hynox-POS.apk selected..." -ForegroundColor Gray
Start-Process explorer.exe -ArgumentList "/select,`"$apkPath`""

# 2. Open Gmail Web Compose addressed to keerthanasubbu5@gmail.com
$subject = [Uri]::EscapeDataString("Hynox POS APK Build ($sizeMb MB)")
$body = [Uri]::EscapeDataString("Hi Keerthana,`n`nHere is your Hynox POS Android APK build.`nFile location: $apkPath`n`nOpen this email on your phone, download the file, and tap Install.")
$gmailUrl = "https://mail.google.com/mail/u/0/?view=cm&fs=1&to=$recipient&su=$subject&body=$body"

Write-Host "2. Opening Gmail Compose for $recipient in your browser..." -ForegroundColor Cyan
Start-Process $gmailUrl

# 3. Open Google Drive in case Gmail blocks direct .apk attachment
$driveUrl = "https://drive.google.com/drive/my-drive"
Write-Host "3. Also opening Google Drive ($recipient)..." -ForegroundColor Cyan
Start-Process $driveUrl

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Green
Write-Host "ALL SET! Here is what to do:" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
Write-Host "METHOD A (Google Drive - 100% Works):" -ForegroundColor Yellow
Write-Host "  1. Drag 'Hynox-POS.apk' from the opened folder into Google Drive."
Write-Host "  2. On your phone, open the Google Drive app -> tap Hynox-POS.apk -> Install."
Write-Host ""
Write-Host "METHOD B (Gmail):" -ForegroundColor Yellow
Write-Host "  1. In the opened Gmail compose window, click the Google Drive icon at bottom."
Write-Host "  2. Select Hynox-POS.apk and click Send."
Write-Host "=======================================================" -ForegroundColor Green
