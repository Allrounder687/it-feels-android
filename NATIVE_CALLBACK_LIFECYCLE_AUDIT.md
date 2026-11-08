# Windows Native Callback Lifecycle Audit

## Audit Overview

This document provides a comprehensive native callback and FFI lifecycle audit for **IT Feels Music** on Windows x64. It examines every point of interaction between Dart isolate memory and unmanaged native C/C++ threads, detailing callback registration, lifespan, disposal timing, and safety guarantees.

---

## 1. Native FFI Boundary Inventory

The following subsystems register native callbacks or unmanaged OS handles:

| Subsystem | Underlying Native Library | Callback Type / Mechanism | Native Lifespan vs Isolate Lifespan | Audit Status |
|---|---|---|---|---|
| **Audio Core** | `libmpv` (0.38.0) | `mpv_set_wakeup_callback` (C function pointer) | **Process-wide** (survives isolate if undisposed) | **Hardened**: Disposed via `AudioPlayerHandler.dispose()` |
| **Audio DSP / EQ** | `libmpv` (`af` filter graph) | `MPV_EVENT_PROPERTY_CHANGE` (`NativeCallable.listener`) | **Process-wide** | **Hardened**: Detached via `EqualizerService.detachPlayer()` |
| **GPU Canvas Video** | `libmpv` + DirectX 11 / ANGLE | Direct3D 11 Texture Copy (`TextureRegistrar`) | **Compositor thread** | **Hardened**: Disposed via `CanvasControllerNotifier.dispose()` |
| **System Media Controls** | `SMTCWindows` (WinRT) | WinRT SMTC event handlers (`buttonPressStream`) | **OS COM object** | **Hardened**: Disposed via `_smtc?.dispose()` |
| **Global Hotkeys** | `hotkey_manager` (Win32) | Windows Hook (`WH_KEYBOARD_LL`) | **OS Message Loop** | **Safe**: Handled via `hotKeyManager.unregisterAll()` |
| **Taskbar Thumbnails** | `windows_taskbar` | Windows Shell COM interfaces | **Process-wide** | **Hardened**: Cleared via `AudioEngineService.dispose()` |

---

## 2. Memory & Lifespan Architecture

```mermaid
flowchart TD
    subgraph HostProcess ["Windows OS Process: it_feels_music.exe"]
        subgraph WinThreads ["Unmanaged Native OS Threads"]
            MPVThread["libmpv Worker & Event Loop Thread"]
            D3DThread["Direct3D 11 Render / Compositor Thread"]
            SMTCThread["WinRT SMTC Dispatcher Thread"]
        end

        subgraph DartVM ["Dart Virtual Machine"]
            subgraph OldIsolate ["Old Dart Isolate (Torn Down on Hot Restart)"]
                NC1["NativeCallable: mpv_wakeup (DELETED)"]
                NC2["NativeCallable: D3D Texture Callback (DELETED)"]
                HandlerOld["AudioPlayerHandler (Orphaned)"]
                EQOld["EqualizerService (Orphaned)"]
            end

            subgraph NewIsolate ["New Dart Isolate (Spun Up on Hot Restart)"]
                NC1New["New NativeCallable: mpv_wakeup (ACTIVE)"]
                NC2New["New NativeCallable: D3D Texture Callback (ACTIVE)"]
                HandlerNew["AudioPlayerHandler (ACTIVE)"]
                EQNew["EqualizerService (ACTIVE)"]
            end
        end
    end

    MPVThread -.->|Pre-Fix: Late Wakeup Callback| NC1
    D3DThread -.->|Pre-Fix: Frame Copy Callback| NC2
    NC1 -->|Dart 3.12 Invariant Check| Abort["FATAL ABORT: Callback invoked after it has been deleted"]
    NC2 -->|Dart 3.12 Invariant Check| Abort

    HandlerOld -.->|Post-Fix: reassemble() / teardown| Clear["Synchronous Detach & Dispose Before Isolate TearDown"]
    Clear -->|Property 'af' = empty & player.stop()| MPVThread
```

---

## 3. Pre-Fix vs. Post-Fix Callback Lifecycles

### Pre-Fix State (Vulnerable)
1. **Unbounded Lifecycle**: `_player` was created in `AudioPlayerHandler` constructor but never closed or disposed during app hot restart or reassemble.
2. **Asynchronous Filter Flooding**: Setting equalizer bands triggered `setProperty('af', ...)` asynchronously while the Dart VM was destroying the isolate.
3. **Dangling Texture Copy**: Video player textures in `CanvasControllerNotifier` were unawaited on teardown, causing the Windows GPU compositor (`InternalFlutterGpu_Texture_AsImage`) to call into dead Dart memory.

### Post-Fix State (Production-Hardened)
1. **Deterministic Teardown Gate**: `AudioPlayerHandler.dispose()` executes a 7-stage shutdown protocol:
   - Sets `_isDisposing = true;` to reject new inputs.
   - Detaches `EqualizerService` and sets `setProperty('af', '')`.
   - Sets volume to `0.0` and invokes `await _player.stop()`.
   - Cancels all 11 stream subscriptions synchronously.
   - Cleans up SMTC WinRT handlers.
   - Clears all UI callback closures (`onSkipNext = null; ...`).
   - Awaits `await _player.dispose()`, freeing native `libmpv` event thread handles.
   - Sets `_isDisposed = true;`.
2. **Re-entrant Mutex Guard**: `EqualizerService` sequences all filter modifications through `_filterQueue`. If the service is disposing or detached, filter dispatches are discarded immediately.
3. **Hot Restart Hook**: `reassemble()` in `_PixelPlayerSaavnAppState` detaches filters *before* Flutter destroys the Dart isolate.

---

## 4. Verification Matrix

| Callback Test Scenario | Pre-Fix Behavior | Post-Fix Behavior | Pass Status |
|---|---|---|---|
| **Hot Restart with Active Playback** | Native crash (`exit code 0xC0000005`) | Audio stops gracefully, no native callbacks, clean isolate restart | **PASS** |
| **Hot Restart with Active Equalizer** | Native crash on `af` property change | Equalizer flushes filters synchronously, callbacks detach | **PASS** |
| **Rapid Equalizer Preset Switching** | Filter collision & late callback race | Mutex sequences all commands, zero callback collision | **PASS** |
| **Tray / Window Exit** | Abrupt process termination | Clean `dispose()` sequence invoked prior to process exit | **PASS** |
| **Video Canvas Teardown** | Dangling Direct3D texture crash | Texture released and player disposed cleanly | **PASS** |
