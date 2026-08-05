@echo off
echo ===================================================
echo             IT-Feels One-Click Sync
echo ===================================================
echo.

:: 1. Pull the latest changes from the remote repository
echo [*] Pulling latest updates from GitHub...
git pull

:: 2. Add all local changes
echo.
echo [*] Staging all local files...
git add .

:: 3. Commit the changes with an automatic timestamp message
echo.
echo [*] Committing changes...
git commit -m "Auto-sync: %COMPUTERNAME% - %date% %time%"

:: 4. Push the changes to GitHub
echo.
echo [*] Pushing to GitHub...
git push

echo.
echo ===================================================
echo      Sync Complete! You can close this window.
echo ===================================================
pause
