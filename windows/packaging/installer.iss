#ifndef MyAppName
#define MyAppName "IT Feels Music"
#endif

#ifndef MyAppVersion
#define MyAppVersion "3.6.31"
#endif

#ifndef MyAppPublisher
#define MyAppPublisher "Allrounder687"
#endif

#ifndef MyAppExeName
#define MyAppExeName "it_feels_music.exe"
#endif

#ifndef MyAppExeFolder
#define MyAppExeFolder "..\..\build\windows\x64\runner\Release"
#endif

#ifndef MyAppIcon
#define MyAppIcon "..\..\windows\runner\resources\app_icon.ico"
#endif

#ifndef OutputDir
#define OutputDir "..\..\build\windows\x64\installer"
#endif

#ifndef OutputBaseFilename
#define OutputBaseFilename "IT_Feels_Music_v" + MyAppVersion + "_Setup"
#endif

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
AppId={{BBD4-4C4A-8F20-DA15228E0F3D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile={#MyAppIcon}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyAppExeFolder}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppExeFolder}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
