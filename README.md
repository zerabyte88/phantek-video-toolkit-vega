<div align="center">
  <img src="assets/icon/app_icon.png" alt="Phantek Logo" width="120" />

  # Phantek - Video Toolkit Vega

  **Hardware-accelerated offline video transcoding, downscaling, and audio extraction for Android.**

  [![Status](https://img.shields.io/badge/Status-Pre--release-f97316?style=flat-square&logo=github&logoColor=white)](https://github.com/zerabyte88/phantek-video-toolkit-vega/releases)
  [![Platform](https://img.shields.io/badge/Platform-Android%207.0+-10b981?style=flat-square&logo=android&logoColor=white)](https://github.com/zerabyte88/phantek-video-toolkit-vega/releases)
  [![Architecture](https://img.shields.io/badge/Arch-arm64--v8a-8b5cf6?style=flat-square&logo=arm&logoColor=white)](https://github.com/zerabyte88/phantek-video-toolkit-vega/releases)
  [![Engine](https://img.shields.io/badge/Engine-Flutter%20%7C%20Media3-6366f1?style=flat-square)](https://developer.android.com/media/media3)
  [![License](https://img.shields.io/badge/License-MIT-f59e0b?style=flat-square&logo=open-source-initiative&logoColor=white)](LICENSE)

  [Download APK](https://github.com/zerabyte88/phantek-video-toolkit-vega/releases/latest) • [Features](#features) • [Supported Formats](#supported-formats) • [Tech Stack](#tech-stack) • [Build](#build-from-source)
</div>

---

> [!WARNING]
> **Active Development & Pre-Release Notice** :  
> Phantek - Video Toolkit Vega is currently under active development and in pre-release stage. You may encounter bugs, instability, or unexpected behavior.

**Phantek - Video Toolkit Vega** uses native `MediaCodec` and AndroidX Media3 Transformer. For software encoding via `libx264` and FFmpeg, see [phantek-video-toolkit](https://github.com/zerabyte88/phantek-video-toolkit).

---

## Features

- **Hardware Transcoding** : Encode H.264 (`video/avc`) and H.265 (`video/hevc`) via device SoC hardware encoders.
- **Resolution Downscaling** : Scale 4K/2K down to 1080p, 720p, 480p, or 360p with OpenGL aspect-ratio preservation and even-pixel alignment.
- **Rate Control** : Constant Quality (CQ/VBR) or target bitrate (1–35 Mbps) with framerate clamping (24–60 FPS).
- **Audio Extraction** : Extract audio streams to M4A/AAC, MP3 (64–320 kbps), or uncompressed 16-bit PCM WAV, with direct bitstream copy when formats match.
- **Foreground Execution** : Android Foreground Service with CPU `WakeLock` and crash-recovery job markers to prevent background termination.
- **Real-Time Telemetry** : Live encoding progress, elapsed/remaining time, storage I/O rate, and device thermal status.
- **AMOLED Themes** : 6 visual themes (*AMOLED Pure*, *Midnight*, *Snowfall*, *Sakura*, *Light*, *Clean Light*).
- **100% Offline** : Zero network permissions (`android.permission.INTERNET` omitted), no telemetry, and no external trackers.

---

## Supported Formats

<div align="center">

| Type | Container | Codec / Format | Notes |
| :---: | :---: | :---: | :---: |
| **Video** | `.mp4` | H.264 (`video/avc`), H.265 (`video/hevc`) | Hardware accelerated, `+faststart` |
| **Video** | `.mkv` | H.264 (`video/avc`), H.265 (`video/hevc`) | Matroska container |
| **Video** | `.mov` | H.264 (`video/avc`), H.265 (`video/hevc`) | QuickTime container |
| **Audio** | `.m4a` | AAC (`audio/mp4a-latm`) | Hardware accelerated (64–320 kbps) |
| **Audio** | `.mp3` | MP3 (`audio/mpeg`) | 64–320 kbps |
| **Audio** | `.wav` | PCM (`audio/raw`) | 16-bit linear uncompressed PCM |

</div>

---

## Tech Stack

<div align="center">

| Layer | Package / Tool | Role |
| :---: | :---: | :---: |
| **Framework** | Flutter (Dart SDK `^3.13`) | Core UI and state management |
| **Media Engine** | AndroidX Media3 (`1.5.1`) | Hardware `Transformer`, `MediaCodec`, and `Muxer` pipeline |
| **Background** | `flutter_foreground_task`, `wakelock_plus` | Foreground service execution and CPU wake lock |
| **Hardware Info** | `device_info_plus` | SoC, GPU, and thermal hardware detection |
| **Storage** | `shared_preferences`, `file_picker` | Local settings persistence and media file selection |

</div>

---

## Build from Source

### Prerequisites

- Flutter SDK `^3.13`
- Android SDK & Java 17+

### Steps

```bash
# Clone repository
git clone https://github.com/zerabyte88/phantek-video-toolkit-vega.git
cd phantek-video-toolkit-vega

# Install dependencies
flutter pub get

# Build release APK
flutter build apk --release
```

Compiled binary : `build/app/outputs/flutter-apk/app-release.apk`

---

## License

Distributed under the [MIT License](LICENSE).
