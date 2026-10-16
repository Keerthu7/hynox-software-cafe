$apkPath = Join-Path $PSScriptRoot "Hynox-POS.apk"

if (-not (Test-Path -LiteralPath $apkPath)) {
    Write-Host "ERROR: Hynox-POS.apk not found. Please run .\BUILD-APK.cmd first." -ForegroundColor Red
    return
}

# Find local IPv4 address
$ipObj = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -notmatch 'vEthernet|Loopback|Tailscale|ZeroTier' -and $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' } |
    Select-Object -First 1

$ip = if ($ipObj) { $ipObj.IPAddress } else { "127.0.0.1" }
$port = 8088
$downloadUrl = "http://${ip}:${port}/Hynox-POS.apk"

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host " Hynox Instant Wi-Fi Transfer" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Make sure your phone is connected to the same Wi-Fi as this PC." -ForegroundColor Yellow
Write-Host "2. On your Android phone, open Chrome and type this URL:" -ForegroundColor Yellow
Write-Host ""
Write-Host "   $downloadUrl" -ForegroundColor Green
Write-Host ""
Write-Host "The APK will download instantly directly to your phone!" -ForegroundColor Cyan
Write-Host "(Press Ctrl+C when you are done to stop this sharing server)" -ForegroundColor Gray
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "Listening for connection from your phone..." -ForegroundColor Gray

try {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://*:${port}/")
    $listener.Start()
} catch {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:${port}/")
    $listener.Start()
}

$apkBytes = [System.IO.File]::ReadAllBytes($apkPath)

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        Write-Host "Phone connected: $($request.RemoteEndPoint.Address) requested $($request.RawUrl)" -ForegroundColor Green

        $response.ContentType = "application/vnd.android.package-archive"
        $response.ContentLength64 = $apkBytes.Length
        $response.AddHeader("Content-Disposition", "attachment; filename=Hynox-POS.apk")
        $response.OutputStream.Write($apkBytes, 0, $apkBytes.Length)
        $response.OutputStream.Close()
        Write-Host "SUCCESS! Hynox-POS.apk transferred to your phone." -ForegroundColor Green
    } catch {
        break
    }
}
$listener.Stop()
