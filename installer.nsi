!define APPNAME "It Feels Music"
!define COMPANYNAME "Kreo"
!define DESCRIPTION "A premium music application"
!define EXENAME "it_feels_music.exe"
!define VERSION "3.5.27"

Name "${APPNAME}"
OutFile "ItFeelsMusic_Setup.exe"
InstallDir "$PROGRAMFILES\${COMPANYNAME}\${APPNAME}"

RequestExecutionLevel admin

Page directory
Page instfiles

Section "install"
    SetOutPath "$INSTDIR"
    File /r "build\windows\x64\runner\Release\*"

    WriteUninstaller "$INSTDIR\uninstall.exe"
    CreateShortcut "$SMPROGRAMS\${APPNAME}.lnk" "$INSTDIR\${EXENAME}"
    CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${EXENAME}"
    
    # Registry information for add/remove programs
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayName" "${APPNAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayIcon" "$\"$INSTDIR\${EXENAME}$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "Publisher" "${COMPANYNAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayVersion" "${VERSION}"
SectionEnd

Section "uninstall"
    Delete "$INSTDIR\uninstall.exe"
    Delete "$SMPROGRAMS\${APPNAME}.lnk"
    Delete "$DESKTOP\${APPNAME}.lnk"
    RMDir /r "$INSTDIR"
    
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}"
SectionEnd
