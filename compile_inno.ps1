<#
.SYNOPSIS
    Smart Inno Setup Release Compiler for IT Feels Music (Windows).

.DESCRIPTION
    Builds the Flutter Windows release and packages it into an Inno Setup installer.
    Supports automatic version synchronization, semantic version bumping, Inno Setup
    auto-discovery, build cache skips, and release output verification.

.PARAMETER Version
    Explicit version to assign (e.g. "3.6.32" or "3.6.32+102"). Overrides pubspec.yaml.

.PARAMETER BumpPatch
    Increments the patch version (e.g. 3.6.31 -> 3.6.32) and increments the build number.

.PARAMETER BumpMinor
    Increments the minor version (e.g. 3.6.31 -> 3.7.0) and increments the build number.

.PARAMETER BumpBuild
    Increments only the build number (+101 -> +102) leaving the semantic version intact.

.PARAMETER SkipFlutterBuild
    Skips `flutter build windows --release` and compiles the installer directly from
    existing release binaries.

.PARAMETER Clean
    Runs `flutter clean` and `flutter pub get` before starting the build.

.PARAMETER OpenFolder
    Opens Windows Explorer to the compiled installer location upon completion.

.EXAMPLE
    .\compile_inno.ps1
    Builds the current pubspec version.

.EXAMPLE
    .\compile_inno.ps1 -BumpPatch
    Bumps patch version, updates pubspec and installer script, then builds.

.EXAMPLE
    .\compile_inno.ps1 -SkipFlutterBuild
    Fast packaging: compiles the Inno installer in seconds using existing binaries.
#>

[CmdletBinding()]
param (
    [string]$Version = "",
    [switch]$BumpPatch,
    [switch]$BumpMinor,
    [switch]$BumpBuild,
    [switch]$SkipFlutterBuild,
    [switch]$Clean,
    [switch]$OpenFolder
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       IT FEELS MUSIC — SMART INNO SETUP RELEASE BUILDER        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────────────────────────
# 1. Version Detection & Semantic Bumping
# ─────────────────────────────────────────────────────────────
$PubspecPath = Join-Path $ScriptDir "pubspec.yaml"
if (!(Test-Path $PubspecPath)) {
    Write-Error "pubspec.yaml not found at $PubspecPath!"
}

$PubspecContent = Get-Content $PubspecPath -Raw
if ($PubspecContent -match 'version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)(\+([0-9]+))?') {
    $Major = [int]$matches[1]
    $Minor = [int]$matches[2]
    $Patch = [int]$matches[3]
    $BuildNum = if ($matches[5]) { [int]$matches[5] } else { 1 }
} else {
    Write-Error "Unable to parse version string from pubspec.yaml"
}

$OldVersionStr = "$Major.$Minor.$Patch+$BuildNum"
$VersionUpdated = $false

if ($BumpMinor) {
    $Minor++
    $Patch = 0
    $BuildNum++
    $VersionUpdated = $true
} elseif ($BumpPatch) {
    $Patch++
    $BuildNum++
    $VersionUpdated = $true
} elseif ($BumpBuild) {
    $BuildNum++
    $VersionUpdated = $true
} elseif ($Version -ne "") {
    if ($Version -match '^([0-9]+)\.([0-9]+)\.([0-9]+)(\+([0-9]+))?$') {
        $Major = [int]$matches[1]
        $Minor = [int]$matches[2]
        $Patch = [int]$matches[3]
        if ($matches[5]) { $BuildNum = [int]$matches[5] }
        $VersionUpdated = $true
    } else {
        Write-Warning "Supplied version '$Version' does not match semantic format X.Y.Z(+B). Using as raw version."
    }
}

$SemVersion = "$Major.$Minor.$Patch"
$FullVersion = "$Major.$Minor.$Patch+$BuildNum"

if ($VersionUpdated) {
    Write-Host "[+] Bumping Version: $OldVersionStr -> $FullVersion" -ForegroundColor Green
    $NewPubspecContent = $PubspecContent -replace 'version:\s*[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?', "version: $FullVersion"
    Set-Content -Path $PubspecPath -Value $NewPubspecContent -NoNewline
} else {
    Write-Host "[i] Current Version: $FullVersion" -ForegroundColor Yellow
}

# ─────────────────────────────────────────────────────────────
# 2. Locate Inno Setup Compiler (ISCC.exe)
# ─────────────────────────────────────────────────────────────
Write-Host "[*] Locating Inno Setup Compiler (ISCC.exe)..." -ForegroundColor Gray
$IsccCandidates = @(
    (Get-Command iscc.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    (Get-ChildItem -Path "$env:USERPROFILE\.inno_bundle\versions\*\ISCC.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName -First 1),
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)

$IsccPath = $null
foreach ($cand in $IsccCandidates) {
    if ($cand -and (Test-Path $cand)) {
        $IsccPath = $cand
        break
    }
}

if (!$IsccPath) {
    Write-Host "[!] ISCC.exe not found on system. Attempting automatic installation via winget..." -ForegroundColor Yellow
    winget install --id JRSoftware.InnoSetup --accept-source-agreements --accept-package-agreements --silent
    $IsccPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (!(Test-Path $IsccPath)) {
        $IsccPath = "C:\Program Files\Inno Setup 6\ISCC.exe"
    }
    if (!(Test-Path $IsccPath)) {
        Write-Error "Inno Setup could not be located. Please install Inno Setup 6 from https://jrsoftware.org/isdl.php"
    }
}

Write-Host "    Found ISCC: $IsccPath" -ForegroundColor DarkGray

# ─────────────────────────────────────────────────────────────
# 3. Flutter Build Pipeline
# ─────────────────────────────────────────────────────────────
$RunnerReleaseDir = Join-Path $ScriptDir "build\windows\x64\runner\Release"
$ExePath = Join-Path $RunnerReleaseDir "it_feels_music.exe"

if ($Clean) {
    Write-Host "[*] Cleaning project build caches..." -ForegroundColor Yellow
    flutter clean
    flutter pub get
}

if ($SkipFlutterBuild) {
    Write-Host "[*] Skipping Flutter Windows compilation (-SkipFlutterBuild set)" -ForegroundColor Cyan
    if (!(Test-Path $ExePath)) {
        Write-Error "Release executable not found at $ExePath. You must run a full build first before skipping."
    }
} else {
    Write-Host "[*] Building Flutter Windows Release (v$FullVersion)..." -ForegroundColor Cyan
    $BuildSwitches = @("build", "windows", "--release", "--build-name=$SemVersion", "--build-number=$BuildNum")
    & flutter @BuildSwitches
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flutter Windows release build failed with exit code $LASTEXITCODE."
    }
}

if (!(Test-Path $ExePath)) {
    Write-Error "Build verification failed: $ExePath does not exist!"
}
Write-Host "    Verified Release Binary: $ExePath" -ForegroundColor DarkGray

# ─────────────────────────────────────────────────────────────
# 4. Icon & Packaging Assets Verification
# ─────────────────────────────────────────────────────────────
$IconPath = Join-Path $ScriptDir "windows\runner\resources\app_icon.ico"
if (!(Test-Path $IconPath)) {
    $IconPath = Join-Path $ScriptDir "assets\images\icon.ico"
}
if (!(Test-Path $IconPath)) {
    Write-Warning "App icon not found at standard paths. Inno Setup will use default icon."
    $IconPath = ""
}

$IssPath = Join-Path $ScriptDir "windows\packaging\installer.iss"
if (!(Test-Path $IssPath)) {
    Write-Error "Inno Setup script not found at $IssPath!"
}

# Ensure Output Directories
$InstallerOutputDir = Join-Path $ScriptDir "build\windows\x64\installer"
if (!(Test-Path $InstallerOutputDir)) {
    New-Item -ItemType Directory -Path $InstallerOutputDir -Force | Out-Null
}

$ReleasesDir = Join-Path $ScriptDir "releases"
if (!(Test-Path $ReleasesDir)) {
    New-Item -ItemType Directory -Path $ReleasesDir -Force | Out-Null
}

$InstallerBaseName = "IT_Feels_Music_v${SemVersion}_Setup"

# ─────────────────────────────────────────────────────────────
# 5. Compile Inno Setup Installer
# ─────────────────────────────────────────────────────────────
Write-Host "[*] Compiling Inno Setup Installer: ${InstallerBaseName}.exe..." -ForegroundColor Cyan

$IsccArgs = @(
    "/DMyAppVersion=$SemVersion",
    "/DMyAppName=IT Feels Music",
    "/DMyAppPublisher=Allrounder687",
    "/DMyAppExeName=it_feels_music.exe",
    "/DMyAppExeFolder=$RunnerReleaseDir",
    "/DOutputDir=$InstallerOutputDir",
    "/DOutputBaseFilename=$InstallerBaseName"
)

if ($IconPath) {
    $IsccArgs += "/DMyAppIcon=$IconPath"
}

$IsccArgs += "`"$IssPath`""

& "$IsccPath" $IsccArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Inno Setup compilation failed with exit code $LASTEXITCODE."
}

# ─────────────────────────────────────────────────────────────
# 6. Release Artifact Verification & Publishing
# ─────────────────────────────────────────────────────────────
$CompiledInstaller = Join-Path $InstallerOutputDir "${InstallerBaseName}.exe"
if (!(Test-Path $CompiledInstaller)) {
    Write-Error "Installer binary was not created at expected path: $CompiledInstaller"
}

# Copy to root releases directory for convenience
$RootReleaseCopy = Join-Path $ReleasesDir "${InstallerBaseName}.exe"
Copy-Item -Path $CompiledInstaller -Destination $RootReleaseCopy -Force

$InstallerItem = Get-Item $RootReleaseCopy
$SizeMB = [math]::Round($InstallerItem.Length / 1MB, 2)
$Hash = (Get-FileHash -Path $RootReleaseCopy -Algorithm SHA256).Hash

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "               INNO SETUP BUILD SUCCESSFUL!                     " -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Version:       v$SemVersion (Build $BuildNum)" -ForegroundColor White
Write-Host "  File Name:     ${InstallerBaseName}.exe" -ForegroundColor White
Write-Host "  File Size:     $SizeMB MB" -ForegroundColor White
Write-Host "  SHA-256:       $Hash" -ForegroundColor DarkGray
Write-Host "  Artifact Path: $RootReleaseCopy" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

if ($OpenFolder) {
    explorer.exe /select,"$RootReleaseCopy"
}
