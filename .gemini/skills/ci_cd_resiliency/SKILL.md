---
name: CI/CD Resiliency & iOS Build Fixes
description: Documentation for resilient CI/CD pipelines, handling Shorebird release fallbacks, and fixing iOS SPM platform target versions (iOS 13.0 vs iOS 15.0).
---

# CI/CD Resiliency & iOS Build Fixes

This skill documents critical workarounds and fixes used in the `it-feels-android` CI/CD pipelines to ensure stable releases on Android and iOS.

## 1. Swift Package Manager (SPM) iOS Version Fix (Exit Code 65)

**The Problem:**
Flutter 3.24+ currently hardcodes the iOS deployment target in its generated Swift Package Manager (SPM) templates to `iOS 13.0` (`12.0` in older versions). Modern plugins like Firebase (11.0+) and `background_downloader` require a minimum of `iOS 15.0`.
If the pipeline tries to build iOS using SPM, Xcode compilation fails with Exit Code 65 because the generated `Package.swift` requests `13.0` while the dependencies require `15.0`.
Disabling SPM via `flutter config --no-enable-swift-package-manager` is NOT a solution, as plugins like `receive_sharing_intent` mandate SPM.

**The Solution:**
Instead of modifying pubspec or checking in `Package.swift` hacks, we dynamically patch the Flutter SDK's SPM generator scripts *during* the GitHub Action workflow using `sed`.

In the `ios-unsigned-build.yml` workflow under the "Install dependencies" step:
```yaml
      - name: Install dependencies
        run: |
          flutter config --enable-swift-package-manager
          
          # Initialize Shorebird Flutter SDK so files exist
          shorebird flutter --version
          
          # Patch Flutter SDK SPM generator to force iOS 15.0 deployment target instead of hardcoded 13.0
          echo "Patching Flutter SDK SPM minimum iOS deployment target to 15.0..."
          find "$FLUTTER_ROOT" -type f -name "*.dart" -exec sed -i '' 's/"13\.0"/"15\.0"/g' {} + || true
          find "$FLUTTER_ROOT" -type f -name "*.dart" -exec sed -i '' "s/'13\.0'/'15\.0'/g" {} + || true
          find "$FLUTTER_ROOT" -type f -name "*.tmpl" -exec sed -i '' 's/"13\.0"/"15\.0"/g' {} + || true
          # Force rebuild of flutter_tools
          rm -f "$FLUTTER_ROOT/bin/cache/flutter_tools.stamp"
          rm -f "$FLUTTER_ROOT/bin/cache/flutter_tools.snapshot"

          # Patch Shorebird's vendored Flutter SDK (Crucial for `shorebird release ios`)
          echo "Patching Shorebird vendored Flutter SDK SPM minimum iOS deployment target to 15.0..."
          find "$HOME/.shorebird" -type f -name "*.dart" -exec sed -i '' 's/"13\.0"/"15\.0"/g' {} + || true
          find "$HOME/.shorebird" -type f -name "*.dart" -exec sed -i '' "s/'13\.0'/'15\.0'/g" {} + || true
          find "$HOME/.shorebird" -type f -name "*.tmpl" -exec sed -i '' 's/"13\.0"/"15\.0"/g' {} + || true
          # Force rebuild of Shorebird's flutter_tools
          find "$HOME/.shorebird" -type f -name "flutter_tools.stamp" -exec rm -f {} + || true
          find "$HOME/.shorebird" -type f -name "flutter_tools.snapshot" -exec rm -f {} + || true
          
          # Rebuild tools
          flutter --version
          shorebird flutter --version
          
          flutter clean
          flutter pub get
```

And additionally, during the iOS build step, directly patch the generated `Package.swift` files before falling back to Xcode native build:
```yaml
          # 3. FORCE SPM Package.swift to iOS 15 (Fix for Flutter 3.24+ hardcoding 13.0)
          echo "Finding and patching Package.swift files..."
          find . -name "Package.swift" -type f -exec sed -i '' 's/"12\.0"/"15\.0"/g' {} + || true
          find . -name "Package.swift" -type f -exec sed -i '' 's/"13\.0"/"15\.0"/g' {} + || true
          find . -name "Package.swift" -type f -exec sed -i '' 's/"14\.0"/"15\.0"/g' {} + || true
          find /Users/runner -name "Package.swift" -type f -exec sed -i '' 's/"13\.0"/"15\.0"/g' {} + || true
```

## 2. Shorebird Fallbacks

**The Problem:**
When bumping version codes or releasing a new patch, if `shorebird release` is triggered on a version that already has a release published, Shorebird fails the pipeline.

**The Solution:**
Add graceful fallbacks in both `ota_release.yml` and `ios-unsigned-build.yml`.

For Android:
```bash
shorebird release android --force || flutter build apk --release
```

For iOS:
```bash
shorebird release ios --no-codesign || flutter build ios --release --no-codesign
```
This ensures the pipeline completes successfully by building standard binaries if Shorebird patching fails due to existing releases.

## 3. Pseudo-signing iOS IPAs for TrollStore
When building unsigned release IPAs, the Xcode linker aggressively strips symbols which can result in the app crashing instantly on launch (Killed: 9) on iOS. You MUST pseudo-sign the executable using `ldid` before zipping into an IPA.

```bash
# Install ldid via brew
brew install ldid

# Run ldid on the binary
ldid -S Payload/Runner.app/Runner

# Sign all embedded frameworks and dylibs
find Payload/Runner.app/Frameworks -name "*.framework" -type d | while read framework; do
  framework_name=$(basename "$framework" .framework)
  if [ -f "$framework/$framework_name" ]; then
    ldid -S "$framework/$framework_name"
  fi
done

find Payload/Runner.app -name "*.dylib" -type f | while read dylib; do
  ldid -S "$dylib"
done
```

**Rule to remember:** ALWAYS tolerate the CocoaPods fallback warning for legacy plugins. NEVER disable SPM globally via `pubspec.yaml` just to suppress warnings.
