@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo IT-FEELS AUTOMATED OTA DEPLOYMENT
echo ===================================================
echo.

REM Extract the version from pubspec.yaml
for /f "tokens=2" %%i in ('findstr /b /c:"version: " pubspec.yaml') do set FULL_VERSION=%%i

if "%FULL_VERSION%"=="" (
    echo [ERROR] Could not find version in pubspec.yaml
    pause
    exit /b 1
)

REM Strip the build number (e.g., 3.3.0+10 becomes 3.3.0)
for /f "tokens=1 delims=+" %%i in ("%FULL_VERSION%") do set VERSION=%%i

echo Detected Version: v%VERSION%
echo.
set /p proceed="Do you want to deploy v%VERSION% to all users? (y/n): "
if /i not "%proceed%"=="y" (
    echo Deployment cancelled.
    pause
    exit /b 0
)

echo.
echo [1/3] Committing pubspec.yaml...
git add pubspec.yaml
git commit -m "chore: release v%VERSION%"
git push

echo.
echo [2/3] Tagging release v%VERSION%...
git tag v%VERSION%

echo.
echo [3/3] Pushing tags to trigger GitHub Actions...
git push --tags

echo.
echo ===================================================
echo SUCCESS! 
echo GitHub Actions is now building the APK and updating Firestore.
echo Within 5 minutes, the OTA update will be live for all users.
echo ===================================================
pause
