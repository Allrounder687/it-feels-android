---
name: "Windows Inno Release Compiler"
description: "Builds, packages, and verifies production Inno Setup Windows installers for IT Feels Music. Handles semantic version synchronization from pubspec.yaml, ISCC.exe auto-discovery, fast packaging with -SkipFlutterBuild, and SHA256 integrity verification. Use when asked to build an Inno release, compile a Windows installer, package the Windows app, bump versions, or create a Windows setup executable."
---

# Windows Inno Release Compiler

A dedicated skill for building, versioning, compiling, and verifying production Inno Setup installers for the IT Feels Flutter Windows application.

---

## Quick Reference & Commands

Run from PowerShell or Command Prompt in the repository root:

```powershell
# 1. Standard Release Build (compiles Flutter Windows + Inno Setup):
.\compile_inno.ps1

# 2. Fast Repackage (<10 seconds using existing Release binaries):
.\compile_inno.ps1 -SkipFlutterBuild

# 3. Patch Version Bump (e.g. 3.6.31 -> 3.6.32 + increments build number):
.\compile_inno.ps1 -BumpPatch

# 4. Minor Version Bump (e.g. 3.6.31 -> 3.7.0 + increments build number):
.\compile_inno.ps1 -BumpMinor

# 5. Build Number Increment (+101 -> +102):
.\compile_inno.ps1 -BumpBuild

# 6. Explicit Version Override:
.\compile_inno.ps1 -Version "3.7.0"

# 7. Clean Build (runs flutter clean and pub get first):
.\compile_inno.ps1 -Clean -OpenFolder
```

> [!TIP]
> From Windows File Explorer, users can simply double-click `compile_inno.bat` to launch the build interactively.

---

## Architecture & File Locations

| Component | Path | Description |
| :--- | :--- | :--- |
| **Automation Script (PS1)** | `compile_inno.ps1` | Orchestrates versioning, ISCC discovery, Flutter compilation, and verification. |
| **Batch Launcher** | `compile_inno.bat` | Double-clickable wrapper executing `compile_inno.ps1` with bypassed execution policy. |
| **Inno Setup Script** | `windows/packaging/installer.iss` | Inno Setup 6 definition with `#ifndef` macro overrides, modern wizard style, and `lzma2/ultra64` compression. |
| **Release Binaries** | `build/windows/x64/runner/Release/` | Native Flutter x64 binaries, runner executable, and compiled C++ plugins. |
| **Output Installer** | `releases/IT_Feels_Music_v<VERSION>_Setup.exe` | Staged installer file with SHA-256 verification. |

---

## Step-by-Step Build Procedure

When executing an Inno Setup build request, follow this sequence:

### Step 1: Version Audit
Read `pubspec.yaml` to detect current version (`version: X.Y.Z+B`):
```powershell
Select-String -Path pubspec.yaml -Pattern '^version:\s*(.+)'
```
If the user requested a version bump, pass `-BumpPatch`, `-BumpMinor`, or `-BumpBuild`.

### Step 2: Locate Inno Setup Compiler (`ISCC.exe`)
The script automatically tests candidate paths in this order:
1. `Get-Command iscc.exe` (System PATH)
2. `$env:USERPROFILE\.inno_bundle\versions\*\ISCC.exe`
3. `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`
4. `C:\Program Files\Inno Setup 6\ISCC.exe`
5. `$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe`

If missing, install via winget:
```powershell
winget install --id JRSoftware.InnoSetup --accept-source-agreements --accept-package-agreements --silent
```

### Step 3: Flutter Compilation
If binaries are already present and no Dart/native code has changed, pass `-SkipFlutterBuild` to package in $<10$ seconds. Otherwise:
```powershell
flutter build windows --release --build-name=$SemVersion --build-number=$BuildNum
```

### Step 4: Asset & Dependency Verification
Verify required assets exist before running Inno Setup:
- Runner binary: `build\windows\x64\runner\Release\it_feels_music.exe`
- Dynamic libraries: `flutter_windows.dll`, `just_audio_windows_plugin.dll`, `media_kit_video_plugin.dll`, `libmpv-2.dll`, `quickjs_c_bridge.dll`
- Application icon: `windows\runner\resources\app_icon.ico`

### Step 5: Inno Setup Packaging
Execute `ISCC.exe` passing dynamic defines:
```powershell
& "$IsccPath" /DMyAppVersion="$SemVersion" /DMyAppName="IT Feels Music" /DMyAppPublisher="Allrounder687" /DMyAppExeFolder="$RunnerReleaseDir" /DOutputDir="$InstallerOutputDir" /DOutputBaseFilename="$InstallerBaseName" "$IssPath"
```

### Step 6: Verification & Output Reporting
1. Verify installer output exists: `releases/IT_Feels_Music_v<VERSION>_Setup.exe`.
2. Compute file size (MB) and SHA-256 hash:
   ```powershell
   Get-FileHash -Path releases/IT_Feels_Music_v*_Setup.exe -Algorithm SHA256
   ```
3. Report the clickable file link, version, size, and hash to the user.

---

## Troubleshooting Common Issues

### Issue 1: `inno_bundle` Winget Cancelled Error
- **Symptom**: `A package version is already installed. Installation cancelled.`
- **Cause**: `dart run inno_bundle:build` tries to install Inno Setup by default.
- **Fix**: Use our dedicated `compile_inno.ps1` script instead, which handles existing installations gracefully.

### Issue 2: Locked Executable During Recompile
- **Symptom**: `error LNK1104: cannot open file '...it_feels_music.exe'`
- **Cause**: An active instance of IT Feels Music is running in the background.
- **Fix**: Terminate the running instance:
  ```powershell
  Stop-Process -Name "it_feels_music" -Force -ErrorAction SilentlyContinue
  ```

### Issue 3: Inno Setup Icon Missing
- **Symptom**: Setup wizard fails with `SetupIconFile does not exist`.
- **Fix**: Verify `windows/runner/resources/app_icon.ico` exists. If not, generate or fall back to `assets/images/icon.ico`.
