# PROJECT OBSIDIAN — PHASE 3
# Release Engineering, Packaging & Deployment Guide

**Document Version:** 3.9.2  
**Target Platforms:** Windows Desktop, Android, iOS, macOS, Linux  
**Classification:** DevOps & Release Engineering  
**Date:** November 2026  

---

## 1. Release Engineering Overview & Quality Gates

Production releases of IT Feels Music must pass through deterministic quality gates prior to binary signing, packaging, and distribution. Under the **Dual-Codebase Architecture**, all UI, state, and OS features are engineered and verified in the clean upstream repository (`IT_Feels_Alternate`) before downstream synchronization.

```mermaid
flowchart LR
    A["Quality Gate 1: Static Analysis"] --> B["Quality Gate 2: Test Suite"]
    B --> C["Quality Gate 3: Dual-Codebase Audit"]
    C --> D["Binary Compilation & Signing"]
    D --> E["Inno Setup / APK Packaging"]
    E --> F["SHA-256 Integrity Verification"]
```

### 1.1 Pre-Flight Quality Checklist
Before building any release binary:
1. **Static Analysis Zero-Tolerance:**
   ```powershell
   dart analyze lib/ test/
   ```
   *Requirement:* Must return `No issues found!` (0 errors, 0 warnings, 0 lints).
2. **Automated Stress & Unit Test Pass Rate:**
   ```powershell
   flutter test test/unit/stress/
   flutter test test/unit/services/equalizer_service_test.dart test/unit/player/playback_engine_reliability_test.dart test/unit/charts/chart_aggregation_test.dart
   ```
   *Requirement:* 100% pass rate across all test suites.
3. **Dual-Codebase Compliance:**
   - Verify zero hardcoded scraping APIs (`youtube_explode_dart`, Spotify/Saavn scrapers) in `lib/`.
   - Verify Classic UI (`lib/views/`) remains 100% untouched.

---

## 2. Windows Desktop Release Engineering (Inno Setup)

Windows distributions are packaged using an automated Inno Setup script that bundles the Flutter release binaries, native C++ libmpv libraries, assets, and creates an optimized installer.

### 2.1 Toolchain & Script Structure
- **Inno Script Path:** `windows/runner/Release/setup.iss`
- **Compiler:** Inno Setup 6 (`ISCC.exe` located at `C:\Program Files (x86)\Inno Setup 6\ISCC.exe` or `C:\Users\<User>\AppData\Local\Programs\Inno Setup 6\ISCC.exe`).
- **Semantic Versioning:** The installer script automatically adopts the semantic version declared in `pubspec.yaml` (e.g. `version: 3.9.2+1`).

### 2.2 Compilation Pipeline
To compile a Windows release installer from PowerShell:

```powershell
# 1. Compile Flutter Windows Release binary
flutter build windows --release

# 2. Compile Inno Setup Installer
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows/runner/Release/setup.iss

# 3. Generate SHA-256 Checksum
Get-FileHash -Algorithm SHA256 build\windows\x64\runner\Release\IT_Feels_Setup.exe | Format-List
```

### 2.3 Windows Native Artifacts Bundled
- `it_feels_music.exe`: Compiled AOT Flutter executable.
- `flutter_windows.dll`: Flutter Windows engine.
- `mpv-2.dll` / `libmpv`: Native audio decoding and 10-band biquad filter DSP engine.
- `data/flutter_assets/`: Fonts, icons, and curated assets.

---

## 3. Android Release Engineering (APK & App Bundle)

### 3.1 Proguard & R8 Shrinking Rules
To ensure optimal size and prevent obfuscation of reflection-dependent JNI libraries (`media_kit`, `isar`, `audio_service`), `android/app/proguard-rules.pro` includes:

```proguard
-keep class com.ryanheise.audioservice.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class com.ryanheise.audio_session.** { *; }
-keep class dev.isar.** { *; }
```

### 3.2 Compilation Commands
For Google Play distribution:
```powershell
flutter build appbundle --release
```
For direct distribution / GitHub Releases (split per ABI to minimize download size):
```powershell
flutter build apk --split-per-abi --release
```
Generates lightweight APKs:
- `app-arm64-v8a-release.apk` ($\approx 22\text{MB}$)
- `app-armeabi-v7a-release.apk` ($\approx 19\text{MB}$)
- `app-x86_64-release.apk` ($\approx 24\text{MB}$)

---

## 4. Downstream Codebase Synchronization Protocol

As specified in the **Dual-Codebase Architecture Rule (`AGENTS.md`)**:
- All UI, layout, bug fixes, and native features must be committed here in `IT_Feels_Alternate`.
- To sync updates into the downstream hardcoded app (`IT-Feels`):
  ```bash
  cd ../IT-Feels
  git pull upstream master
  ```
- **Never copy code backwards** from downstream into upstream.

---

## 5. Artifact Verification & Checksum Signing

Every release artifact must be signed and validated with its cryptographic SHA-256 hash. The release engineer must publish the checksum manifest alongside binary downloads:

```text
IT_Feels_Windows_v3.9.2_Setup.exe   e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
IT_Feels_Android_v3.9.2_arm64.apk   a6c5e7b89d4e5f6a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a
```
This guarantees users receive untampered, bit-identical release binaries.
