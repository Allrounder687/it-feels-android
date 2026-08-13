!define APP_NAME "IT Feels Music"
!ifndef APP_VERSION
  !define APP_VERSION "3.6.3"
!endif
!define APP_PUBLISHER "Allrounder687"
!define APP_EXE "it_feels_music.exe"
!define BUILD_DIR "..\..\build\windows\x64\runner\Release"
!define ICON_PATH "..\..\assets\images\icon.ico"
!define OUT_DIR "..\..\build\windows\x64\installer"

Name "${APP_NAME}"
OutFile "${OUT_DIR}\ITFeelsMusic_Installer.exe"
InstallDir "$PROGRAMFILES64\${APP_NAME}"

Icon "${ICON_PATH}"
UninstallIcon "${ICON_PATH}"

Page directory
Page instfiles

UninstPage uninstConfirm
UninstPage instfiles

Section "Install"
  SetOutPath "$INSTDIR"
  
  ; Copy all files from the release directory
  File /r "${BUILD_DIR}\*"
  
  ; Create uninstaller
  WriteUninstaller "$INSTDIR\uninstall.exe"
  
  ; Create Start Menu shortcuts
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\data\flutter_assets\assets\images\icon.ico"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk" "$INSTDIR\uninstall.exe"
  
  ; Create Desktop shortcut
  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\data\flutter_assets\assets\images\icon.ico"
  
  ; Add to Programs and Features (Add/Remove Programs)
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "Publisher" "${APP_PUBLISHER}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "DisplayIcon" "$\"$INSTDIR\data\flutter_assets\assets\images\icon.ico$\""
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "DisplayVersion" "${APP_VERSION}"
SectionEnd

Section "Uninstall"
  ; Remove installed files
  RMDir /r "$INSTDIR"
  
  ; Remove shortcuts
  RMDir /r "$SMPROGRAMS\${APP_NAME}"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  
  ; Remove registry keys
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
SectionEnd
