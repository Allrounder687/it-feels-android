$ErrorActionPreference = "Stop"

Write-Host "Building Flutter Windows Release..."
flutter build windows --release

Write-Host "Checking for NSIS..."
if (!(Get-Command makensis -ErrorAction SilentlyContinue)) {
    Write-Host "NSIS not found. Installing via Chocolatey..."
    choco install nsis -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

Write-Host "Creating NSIS Script..."
$nsi = @"
Name "IT Feels"
OutFile "it-feels-windows-v3.5.35-setup.exe"
InstallDir "`$PROGRAMFILES\IT Feels"
RequestExecutionLevel admin

Page directory
Page instfiles

UninstPage uninstConfirm
UninstPage instfiles

Section "Install"
  SetOutPath "`$INSTDIR"
  File /r "build\windows\x64\runner\Release\*"
  
  WriteUninstaller "`$INSTDIR\uninstall.exe"
  
  CreateShortcut "`$DESKTOP\IT Feels.lnk" "`$INSTDIR\it_feels_music.exe"
  CreateDirectory "`$SMPROGRAMS\IT Feels"
  CreateShortcut "`$SMPROGRAMS\IT Feels\IT Feels.lnk" "`$INSTDIR\it_feels_music.exe"
  CreateShortcut "`$SMPROGRAMS\IT Feels\Uninstall IT Feels.lnk" "`$INSTDIR\uninstall.exe"
SectionEnd

Section "Uninstall"
  RMDir /r "`$INSTDIR"
  Delete "`$DESKTOP\IT Feels.lnk"
  RMDir /r "`$SMPROGRAMS\IT Feels"
SectionEnd
"@
Set-Content -Path installer.nsi -Value $nsi

Write-Host "Compiling NSIS Installer..."
makensis installer.nsi

Write-Host "Uploading to GitHub Release..."
gh release upload v3.5.35 it-feels-windows-v3.5.35-setup.exe --clobber

Write-Host "Done!"
