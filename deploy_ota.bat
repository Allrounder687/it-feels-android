@echo off
setlocal enabledelayedexpansion

:: ANSI Colors
set "ESC="
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "CYAN=%ESC%[96m"
set "RESET=%ESC%[0m"
set "BOLD=%ESC%[1m"
set "DIM=%ESC%[2m"

cls
echo %CYAN%%BOLD%===================================================
echo   IT-FEELS SMART DEPLOYMENT ENGINE
echo ===================================================%RESET%
echo.

:: 1. Version Bump
echo %BOLD%[1] VERSION BUMP%RESET%
echo Would you like to automatically increment the build number?
echo  %GREEN%[Y]%RESET% Yes, bump it (Recommended)
echo  %RED%[N]%RESET% No, keep current
choice /c YN /n /m "> "
if errorlevel 2 (
    set bump=n
) else (
    set bump=y
)

if "!bump!"=="y" (
    powershell -Command "$c = Get-Content pubspec.yaml; $nc = foreach ($l in $c) { if ($l -match '^version:\s*(.*)\+(\d+)') { 'version: ' + $matches[1] + '+' + ([int]$matches[2] + 1) } else { $l } }; [System.IO.File]::WriteAllLines('pubspec.yaml', $nc)"
    echo %GREEN%Build number bumped successfully!%RESET%
)

for /f "tokens=2" %%i in ('findstr /b /c:"version: " pubspec.yaml') do set FULL_VERSION=%%i
for /f "tokens=1 delims=+" %%i in ("%FULL_VERSION%") do set VERSION=%%i
echo Target Release: %CYAN%v!VERSION!%RESET% %DIM%(Build: !FULL_VERSION!)%RESET%
echo.

:: 2. Target Platform
echo %BOLD%[2] TARGET PLATFORM%RESET%
echo Which platforms should build in the cloud?
echo  %GREEN%[1]%RESET% Both Android ^& iOS (Recommended)
echo  %CYAN%[2]%RESET% Android Only
echo  %CYAN%[3]%RESET% iOS Only
choice /c 123 /n /m "> "
if errorlevel 3 (
    set TAG_PREFIX=ios-v
    set PLATFORM_NAME=iOS Only
) else if errorlevel 2 (
    set TAG_PREFIX=android-v
    set PLATFORM_NAME=Android Only
) else (
    set TAG_PREFIX=v
    set PLATFORM_NAME=Android ^& iOS
)
echo Selected: %CYAN%!PLATFORM_NAME!%RESET%
echo.

:: 3. Uncommitted Changes
git status --porcelain > "%temp%\git_status.txt"
set UNCOMMITTED=0
for %%A in ("%temp%\git_status.txt") do if %%~zA GTR 0 set UNCOMMITTED=1

if !UNCOMMITTED!==1 (
    echo %BOLD%[3] UNCOMMITTED CHANGES DETECTED%RESET%
    git status --short
    echo.
    echo How should we handle these?
    echo  %GREEN%[A]%RESET% Stage ALL changes (Recommended)
    echo  %YELLOW%[P]%RESET% Stage ONLY pubspec.yaml
    choice /c AP /n /m "> "
    if errorlevel 2 (
        git add pubspec.yaml
        echo %DIM%Staged only pubspec.yaml.%RESET%
    ) else (
        git add .
        echo %DIM%Staged all changes.%RESET%
    )
) else (
    git add pubspec.yaml
)
echo.

:: 4. Release Notes
echo %BOLD%[4] RELEASE NOTES%RESET%
set /p msg="%CYAN%Enter release notes %DIM%(Leave blank for default)%CYAN%: %RESET%"
if "!msg!"=="" set msg=chore: release v!VERSION!

if not "!msg!"=="chore: release v!VERSION!" (
    echo.
    echo Would you like to update CHANGELOG.md?
    echo  %GREEN%[Y]%RESET% Yes (Recommended)
    echo  %RED%[N]%RESET% No
    choice /c YN /n /m "> "
    if errorlevel 2 (
        REM skip
    ) else (
        echo ## v!VERSION! > "%temp%\cl_update.txt"
        echo - !msg! >> "%temp%\cl_update.txt"
        echo. >> "%temp%\cl_update.txt"
        if exist CHANGELOG.md type CHANGELOG.md >> "%temp%\cl_update.txt"
        move /y "%temp%\cl_update.txt" CHANGELOG.md >nul
        git add CHANGELOG.md
        echo %DIM%CHANGELOG.md updated.%RESET%
    )
)

echo.
echo %BOLD%===================================================%RESET%
echo Ready to deploy %CYAN%v!VERSION!%RESET% to %CYAN%!PLATFORM_NAME!%RESET%
echo Message: %YELLOW%"!msg!"%RESET%
echo %BOLD%===================================================%RESET%
echo  %GREEN%[Y]%RESET% Deploy Now
echo  %RED%[N]%RESET% Cancel
choice /c YN /n /m "> "
if errorlevel 2 (
    echo %RED%Deployment cancelled.%RESET%
    del "%temp%\git_status.txt" 2>nul
    pause
    exit /b 0
)

echo.
echo %DIM%[1/3] Committing changes...%RESET%
git commit -m "!msg!" >nul
git push >nul

echo %DIM%[2/3] Tagging release !TAG_PREFIX!!VERSION!...%RESET%
git tag -a !TAG_PREFIX!!VERSION! -m "!msg!"

echo %DIM%[3/3] Pushing tags...%RESET%
git push origin !TAG_PREFIX!!VERSION! >nul

echo.
echo %GREEN%%BOLD%===================================================%RESET%
echo %GREEN%SUCCESS!%RESET% 
echo %CYAN%GitHub Actions is now building for !PLATFORM_NAME!.%RESET%
echo %GREEN%%BOLD%===================================================%RESET%
del "%temp%\git_status.txt" 2>nul
pause
