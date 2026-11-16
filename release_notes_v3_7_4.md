# IT Feels Music v3.7.4 — Background Playback & Android Lifecycle Resilience Release

Critical stability release resolving the background playback pause and isolate death when minimizing the app to the home screen on Android, restoring permanent background audio service continuity.

---

### 🌟 Key Highlights & Fixes

#### 1. 🎵 Android Background Playback & Lifecycle Survival
- **Mobile Lifecycle Protection**: Gated `AudioPlayerHandler.dispose()` in `PixelPlayerSaavnApp.didChangeAppLifecycleState` and `dispose()` strictly to Desktop platforms (`Platform.isWindows || Platform.isLinux`). On Android/iOS, the audio playback handler now remains alive across UI detachment and screen minimize events.
- **Self-Healing Player Engine**: Added `_ensurePlayerAlive()` to `AudioPlayerHandler`. If the native player was ever disposed, calling `play()`, `playSong()`, or `seek()` automatically resurrects the player instance and re-hooks event streams, permanently eliminating the need to force-stop the app.
- **Removed False Device Change Pauses**: Replaced destructive auto-pause on `session.devicesChangedEventStream` with informational logging. Real physical headphone and Bluetooth disconnections continue to be reliably handled by `session.becomingNoisyEventStream`.
- **Desktop Device Stream Isolation**: Confined `media_kit` desktop audio device stream subscriptions strictly to Desktop platforms to prevent internal Android routing shifts from triggering premature pauses.

#### 2. 🛡️ Android Manifest & OS Task Affinity Hardening
- **Standard Task Affinity**: Removed `android:taskAffinity=""` from `AudioServiceActivity` in `AndroidManifest.xml`. The activity now maintains standard OS task stack affinity (`com.itfeels.music`), preventing Android from prematurely finishing or destroying the activity when entering the home screen.
- **Notification Permission (Android 13+)**: Declared `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` in `AndroidManifest.xml`, ensuring `AudioService` foreground playback notifications post properly without foreground service demotion.

---

### 📦 Artifacts in this Release

| Platform | Format | File Name | Size |
| :--- | :--- | :--- | :--- |
| **Windows** | Inno Setup Installer | `IT_Feels_Music_v3.7.4_Setup.exe` | ~40 MB |
| **Android** | Signed Release APK | `IT_Feels_v3.7.4.apk` | ~156 MB |
