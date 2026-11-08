# Windows Audio Resource Lifecycle Architecture

## Architecture Overview

On Windows x64 desktop, **IT Feels Music** relies on several low-level native subsystems:
1. **WASAPI (Windows Audio Session API)** via `libmpv` audio output (`ao=wasapi`).
2. **Direct3D 11 & ANGLE Hardware Acceleration** via `media_kit_video`.
3. **WinRT System Media Transport Controls (SMTC)** via `smtc_windows`.
4. **Windows Shell Taskbar Integration** via `windows_taskbar`.

This report documents the resource lifecycle, synchronization requirements, and allocation/deallocation order required to prevent OS-level deadlocks and crashes.

---

## 1. Windows Audio Subsystem Stack

```mermaid
graph TD
    UI["Flutter UI Layer (Dart)"]
    Handler["AudioPlayerHandler"]
    Engine["AudioEngineService"]
    EQ["EqualizerService"]

    UI --> Handler
    UI --> Engine
    Engine --> EQ

    subgraph NativeOS ["Windows Operating System"]
        WASAPI["WASAPI Shared Mode Audio Engine"]
        DirectX["Direct3D 11 / ANGLE Texture Sharing"]
        SMTC["WinRT System Media Transport Controls"]
        Shell["Windows Explorer Taskbar COM Interface"]
    end

    Handler -->|media_kit FFI| WASAPI
    Handler -->|DirectX Texture Registrar| DirectX
    Handler -->|WinRT Dispatcher| SMTC
    Engine -->|Win32 COM API| Shell
```

---

## 2. WASAPI Shared Mode Lifecycle

`media_kit` defaults to WASAPI Shared Mode on Windows:
- **Audio Client**: `IAudioClient3` / `IAudioClient` initialized with low-latency event-driven buffers.
- **Audio Render Client**: `IAudioRenderClient` buffers audio PCM packets decoded by `libmpv`'s FFmpeg audio pipeline.
- **Volume & Pitch Shifting**: Built-in `librubberband` pitch scaling with pitch-preserving rate adjustments.

### Teardown Invariant
If a WASAPI audio stream is not paused/stopped before the controlling thread disconnects:
- The Windows Audio Service (`audiosrv`) continues polling the unmanaged ring buffer.
- When the buffer underruns, WASAPI fires an `AUDCLNT_E_DEVICE_INVALIDATED` event.
- If the event callback attempts to call back into a finalized Dart isolate, the process crashes.
- **Enforced Protocol**: `AudioPlayerHandler.dispose()` mutes volume (`setVolume(0.0)`) and calls `await _player.stop()`, allowing WASAPI to cleanly drain and close the hardware audio session.

---

## 3. Direct3D 11 Texture Sharing & GPU Resource Lifecycle

When video playback or Spotify Canvas is enabled:
1. `media_kit_video` requests a shared DirectX 11 texture handle (`HANDLE`) via Direct3D 11 device.
2. The texture handle is registered with Flutter's Windows Embedder using `TextureRegistrar::RegisterTexture`.
3. On every VSync, the Flutter GPU engine queries the registered texture (`InternalFlutterGpu_Texture_AsImage`).

### Teardown Invariant
- Destroying the Dart isolate without releasing the Direct3D texture registration causes the Flutter engine's render loop to invoke an unmapped memory address.
- **Enforced Protocol**: `CanvasControllerNotifier.dispose()` and `releaseVideoResources()` synchronously clear the active controller state, halt playback, and await player disposal before Dart isolate teardown.

---

## 4. WinRT SMTC & Windows Taskbar Deallocation Order

To prevent COM pointer leaks or race conditions during rapid hot restarts, resources must be released in strict reverse-initialization order:

```mermaid
flowchart TD
    Start["Initiate Teardown (Hot Restart / App Close)"] --> Step1["1. Detach EqualizerService (Clear 'af' Filter Graph)"]
    Step1 --> Step2["2. Mute Volume (WASAPI Volume = 0.0)"]
    Step2 --> Step3["3. Stop Audio Playback (Drain WASAPI Buffers)"]
    Step3 --> Step4["4. Cancel Stream Listeners (Position, Devices, SMTC)"]
    Step4 --> Step5["5. Dispose WinRT SMTC COM Handlers"]
    Step5 --> Step6["6. Dispose Direct3D Video Textures"]
    Step6 --> Step7["7. Dispose libmpv Handle (Native Thread Teardown)"]
    Step7 --> Finish["Safe Isolate Teardown / New Isolate Boot"]
```

This strict deallocation sequence guarantees zero orphaned native callbacks, zero WASAPI underrun panics, and zero Direct3D texture faults across hot restart and application termination.
