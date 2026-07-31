---
name: Deploy IT-Feels OTA
description: Triggers the automated CI/CD pipeline to push an Over-The-Air (OTA) update to all active users.
---

# Deploy IT-Feels OTA Update

When the user requests to "release a new version", "push an update", or "deploy to production", you MUST use this skill to trigger the GitHub Actions OTA pipeline.

## The Protocol

1. **Bump Version:** Read `pubspec.yaml` and increment the `version:` string appropriately (e.g., `3.3.0+10` -> `3.3.0+11` for a hotfix, or `3.4.0+1` for a new feature).
2. **Update Changelog:** Add a new section in `CHANGELOG.md` detailing the new features and fixes you just built.
3. **Trigger Deployment:** 
   Run the deployment script located in the root directory:
   ```bash
   deploy_ota.bat
   ```
   **Important Note for Agents:** `deploy_ota.bat` has an interactive confirmation prompt (`set /p proceed=...`). If you are running this headless, you can bypass the script and directly run its underlying Git commands instead:
   ```bash
   git add pubspec.yaml CHANGELOG.md
   git commit -m "chore: release v<VERSION>"
   git push
   git tag v<VERSION>
   git push --tags
   ```

## Architecture Context
Do **NOT** attempt to compile the Android APK locally or modify the Firebase `client_config` database yourself. 
Pushing the Git Tag (`vX.Y.Z`) automatically triggers the `ota_release.yml` GitHub Action. GitHub will securely compile the APK, publish the GitHub Release, and automatically inject the new download URL into Firestore.
