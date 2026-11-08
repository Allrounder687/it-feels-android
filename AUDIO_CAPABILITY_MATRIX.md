# Audio Capability & Platform Sound Engineering Matrix
**IT Feels Music — Project Obsidian 2026**
*Document Version: 1.0.0 | Status: Production Audio Architecture*

---

## 1. Executive Sound Engineering Philosophy

In high-end audio engineering, authenticity and transparency are paramount. IT Feels Music adheres to strict sound integrity principles:
1. **Zero Fake Marketing:** We never advertise "Lossless", "Hi-Res 24-bit/192kHz", or "Bit-Perfect" unless both the audio source file and the hardware DAC pipeline genuinely support it.
2. **Source Truth:** JioSaavn streams provide authentic 320kbps AAC audio containers ($44.1\text{kHz}$, 16-bit stereo, constant bitrate). Adaptive fallback downgrades to 96kbps AAC on unstable cellular connections.
3. **Cross-Platform Uniformity:** Audio digital signal processing (DSP), graphic equalization, and loudness normalization execute via `media_kit`'s libmpv engine, guaranteeing identical acoustic curves across Windows, macOS, Linux, Android, and iOS.

---

## 2. Platform Audio Capability Matrix

| Feature / Subsystem | Windows Desktop | macOS Desktop | Linux Desktop | Android (AAudio) | iOS (AudioUnit) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Audio Core Backend** | libmpv (WASAPI) | libmpv (CoreAudio) | libmpv (Pulse/PipeWire) | libmpv (AAudio/OpenSL) | libmpv (AudioToolbox) |
| **Max Streaming Bitrate**| 320 kbps AAC (Stereo) | 320 kbps AAC (Stereo) | 320 kbps AAC (Stereo) | 320 kbps AAC (Stereo) | 320 kbps AAC (Stereo) |
| **10-Band Graphic EQ** | Native (mpv `af`) | Native (mpv `af`) | Native (mpv `af`) | Native (mpv `af`) | Native (mpv `af`) |
| **Loudness Normalization**| EBU R128 (`loudnorm`)| EBU R128 (`loudnorm`)| EBU R128 (`loudnorm`)| EBU R128 (`loudnorm`)| EBU R128 (`loudnorm`)|
| **Bass & Treble Boosters**| User-tunable (0-10dB)| User-tunable (0-10dB)| User-tunable (0-10dB)| User-tunable (0-10dB)| User-tunable (0-10dB)|
| **Pitch & Speed Scaling**| Rubberband / Scaletempo | Rubberband / Scaletempo | Rubberband / Scaletempo | Scaletempo | Scaletempo |
| **Hardware Disconnect** | WASAPI Endpoint Diff| CoreAudio Route Check | Pulse Sink Monitor | `ACTION_AUDIO_BECOMING_NOISY` | `AVAudioSessionRouteChange` |
| **Transient Ducking** | Not applicable | CoreAudio Session | Pulse Audio Rules | AudioFocus (Duck 35%) | AudioSession (Duck 35%) |
| **System Transport Keys**| Windows SMTC + Taskbar| MPRemoteCommandCenter | MPRIS D-Bus | MediaSessionCompat | MPNowPlayingInfoCenter |
| **Lock Screen Controls** | SMTC Windows Overlay| macOS Lock Screen Widget| Lock Screen MPRIS | Android Media Notification | iOS Lock Screen Player |

---

## 3. The 10-Band Graphic Equalizer Architecture

Implemented in `EqualizerService` (`lib/data/services/equalizer_service.dart`), the 10-band equalizer models standard ISO octave center frequencies using biquad peaking filters:

$$\text{Filter}(f, g) = \text{equalizer}=f:g:\text{width\_type}=o:w=1.0$$

### Frequency Band Allocation
1. **31 Hz (Sub-Bass):** Rumble, sub-bass synthesizers, deep cinematic impact.
2. **62 Hz (Bass):** Kick drums, bass guitars, low-end foundation.
3. **125 Hz (Upper Bass):** Bass warmth, snare body, lower vocal warmth.
4. **250 Hz (Low Midrange):** Woodwinds, brass body, piano low notes.
5. **500 Hz (Midrange):** Male vocals, guitar body, horn richness.
6. **1 kHz (Upper Midrange):** Female vocals, snare crack, presence center.
7. **2 kHz (Presence):** Vocal articulation, acoustic guitar strum attack.
8. **4 kHz (High Midrange):** Edge, clarity, speech intelligibility.
9. **8 kHz (Brilliance):** Cymbals, percussion sparkle, open-air feeling.
10. **16 kHz (Air):** Extreme high frequencies, room ambiance, delicate shimmer.

### 3.1 Built-In Curated Acoustic Presets
- **Flat:** Neutral studio reference ($0\text{dB}$ across all bands).
- **Bass Boost:** $+6\text{dB}$ at $31\text{Hz}$, $+5\text{dB}$ at $62\text{Hz}$, $+4\text{dB}$ at $125\text{Hz}$, $+6\text{dB}$ analog bass boost.
- **Treble Boost:** Gentle roll-off below $250\text{Hz}$, ascending $+4\text{dB}$ to $+7\text{dB}$ boost between $4\text{kHz}$ and $16\text{kHz}$.
- **Rock:** Aggressive V-curve emphasizing low punch and electric guitar harmonics.
- **Pop:** Vocal forward curve centered around $1\text{kHz}-2\text{kHz}$ with controlled low-end firmness.
- **Acoustic:** Linear warm tilt tailored for unamplified strings and unplugged performances.
- **Electronic / Dance:** Sub-bass shelf paired with crisp cymbal brilliance and mid-cut clarity.
- **Vocal Clarity:** Focused speech intelligibility curve attenuating low mud ($< 125\text{Hz}$) and elevating $500\text{Hz}-2\text{kHz}$.
- **Jazz:** Smooth warm midrange highlighting upright bass and brass overtones.
- **Deep Lows:** Heavy $+8\text{dB}$ low shelf for maximum sub-woofer engagement.

---

## 4. Loudness Normalization & ReplayGain (EBU R128)

Different tracks across varied albums and mastering eras exhibit drastically differing perceived loudness, forcing listeners to constantly adjust hardware volume knobs.

Project Obsidian implements broadcast-grade **EBU R128 Loudness Normalization**:
- **Target Integrated Loudness ($I$):** $-16.0\text{ LUFS}$ (Optimized for modern mobile and headphone listening).
- **True Peak Ceiling ($TP$):** $-1.5\text{ dBTP}$ (Eliminates inter-sample clipping on digital-to-analog converters).
- **Loudness Range ($LRA$):** $11.0\text{ LU}$ (Preserves dramatic musical dynamics without over-compression).
- **libmpv Filter Integration:** `loudnorm=I=-16:TP=-1.5:LRA=11`.
- **Toggleable:** Users can toggle loudness normalization ON or OFF via the Equalizer control sheet.

---

## 5. DSP Speed & Pitch Independence

The engine supports independent playback rate ($0.5\times$ to $2.0\times$) and pitch shift ($0.5\times$ to $2.0\times$):
- **Pitch-Preserved Speed Shift:** Speeding up or slowing down audio maintains original vocal formant and harmonic pitch using libmpv's `scaletempo` time-stretching filter.
- **Vibe Presets:**
  - *Slowed + Reverb:* Rate $0.85\times$, Pitch $0.85\times$ with subtle acoustic depth.
  - *Nightcore:* Rate $1.25\times$, Pitch $1.25\times$ for high-energy acceleration.
  - *Normal:* Bit-accurate original master timing.
