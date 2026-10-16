@echo off
setlocal
cd /d "%~dp0"

echo =======================================================
echo  Hynox Web Portal Builder
echo =======================================================

where flutter >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo Building Flutter Web using system Flutter...
    flutter build web --release
    goto :done
)

if exist "work\flutter\bin\flutter.bat" (
    echo Building Flutter Web using local bundled Flutter...
    call "work\flutter\bin\flutter.bat" build web --release
    goto :done
)

if exist "C:\Users\keert\OneDrive\Desktop\flutter\bin\flutter.bat" (
    echo Building Flutter Web using Desktop Flutter...
    call "C:\Users\keert\OneDrive\Desktop\flutter\bin\flutter.bat" build web --release
    goto :done
)

if exist "C:\Users\keert\Documents\Codex\2026-10-12\hynos-company-work-h-y-n\work\flutter\bin\flutter.bat" (
    echo Building Flutter Web using Codex bundled Flutter...
    call "C:\Users\keert\Documents\Codex\2026-10-12\hynos-company-work-h-y-n\work\flutter\bin\flutter.bat" build web --release
    goto :done
)

echo ERROR: Flutter SDK was not found.
exit /b 1

:done
echo.
echo =======================================================
echo  Web build complete! Output is in: build\web
echo =======================================================
