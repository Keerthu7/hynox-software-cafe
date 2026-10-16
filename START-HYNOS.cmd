@echo off
cd /d "%~dp0"
if exist "%~dp0work\flutter\bin\flutter.bat" (
  "%~dp0work\flutter\bin\flutter.bat" run -d chrome -t lib/main.dart --web-port=8766
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Hynos.ps1"
)
if errorlevel 1 pause
