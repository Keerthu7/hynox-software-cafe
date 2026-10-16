@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-Android.ps1" %*
pause
