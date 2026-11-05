@echo off
setlocal
cd /d "%~dp0"

echo ===================================================
echo     IT Feels Music - Inno Setup Release Builder
echo ===================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0compile_inno.ps1" %*

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Build failed with exit code %ERRORLEVEL%.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Build complete.
pause
