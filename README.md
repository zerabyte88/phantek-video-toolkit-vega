<p align="center">
  <img src="assets/icon/app_icon.png" width="120" height="120" alt="Phantek Logo" />
</p>

<h1 align="center">Phantek - Video Toolkit Vega</h1>

<p align="center">
  <strong>High-performance offline on-device video transcoding, downscaling, and audio extraction for Android powered by Hardware Acceleration (AndroidX Media3 Transformer).</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Status-Pre--release-orange?style=flat-square" alt="Status" />
  <img src="https://img.shields.io/badge/Platform-Android%207.0%2B-059669?style=flat-square&logo=android&logoColor=white" alt="Platform" />
  <img src="https://img.shields.io/badge/Arch-arm64--v8a%20%7C%20Hardware%20MediaCodec-2563eb?style=flat-square" alt="Architecture" />
  <img src="https://img.shields.io/badge/Engine-AndroidX%20Media3%20Transformer-6366f1?style=flat-square" alt="Engine" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-334155?style=flat-square" alt="License" /></a>
</p>

<p align="center">
  <a href="#overview">Overview</a> •
  <a href="#features">Features</a> •
  <a href="#supported-formats">Formats</a> •
  <a href="#installation">Installation</a> •
  <a href="#building-from-source">Build</a> •
  <a href="#privacy--security">Privacy</a> •
  <a href="#license">License</a>
</p>

---

## Overview

**Phantek - Video Toolkit Vega** is a fast, offline Android media toolkit for video transcoding, downscaling, and audio extraction. It uses hardware acceleration (AndroidX Media3 Transformer / `MediaCodec`) for fast exports, low battery draw, and a compact ~15 MB footprint without tracking or network permissions.

- **Hardware Edition**: Hardware-accelerated (`MediaCodec`), ultra-fast exports, minimal battery consumption (~15 MB APK).
- **CPU Edition**: Software encoding via native FFmpeg & `libx264` for fine-grained parameters → [phantek-video-toolkit](https://github.com/zerabyte88/phantek-video-toolkit).

> [!WARNING]
> **Active Development & Pre-Release Notice**:  
> Phantek - Video Toolkit Vega is currently under active development and in pre-release stage. You may encounter bugs, instability, or unexpected behavior.

---

## Features

### Video Processing & Downscaling
- **Resolution Downscaling:** Scale from 4K/2K down to 1080p, 720p, 480p, or 360p with OpenGL-accelerated aspect-ratio preservation and automatic even-dimension alignment.
- **Hardware Rate Control:** Constant Quality (CQ/VBR) for visual fidelity or deterministic Target Bitrate (1–35 Mbps) for exact file sizes.
- **Hardware Encoders:** Native H.264 / AVC (`video/avc`) and H.265 / HEVC (`video/hevc`) hardware pipelines.
- **Framerate Clamping:** Preserve source FPS or clamp to standard rates (24, 25, 30, 48, 50, 60 FPS).
- **Audio Handling:** Direct bitstream copy (`copy`), high-efficiency AAC re-encoding, or audio stripping.
- **Web-Optimized Output:** Exports to `.mp4` (with `+faststart` for instant web streaming), `.mkv`, and `.mov`.

### Audio Extraction
- **Outputs:** Extract to **M4A / AAC** (Hardware accelerated), **MP3**, or lossless uncompressed **WAV** (16-bit linear PCM).
- **Direct Bitstream Copy:** Preserves original audio streams without re-encoding when formats match.
- **Bitrate Options:** Selectable bitrates from 64 to 320 kbps.

### Hardware & Performance
- **Hardware Acceleration:** Minimal battery consumption, cool thermals, and lightning-fast export speeds powered by Media3 Transformer and device SoC encoders.
- **Ultra-Lightweight Footprint:** Free of heavyweight native binaries, reducing APK size from ~90 MB to ~15 MB.
- **Foreground Reliability:** Runs as an Android Foreground Service with CPU WakeLock to prevent termination when the screen is locked.
- **Real-Time Telemetry:** Monitors encoding progress, elapsed/remaining time, storage I/O rate, and temperature.
- **Crash Recovery:** Automatic job marker persistence to clean up incomplete exports if interrupted.

---

## Supported Formats

| Type | Container | Codec / Format | Notes |
| :--- | :--- | :--- | :--- |
| **Video** | `.mp4` | H.264 (`video/avc`), H.265 (`video/hevc`) | Hardware accelerated, optimized with `+faststart` |
| **Video** | `.mkv` | H.264 (`video/avc`), H.265 (`video/hevc`) | Wide container compatibility |
| **Video** | `.mov` | H.264 (`video/avc`), H.265 (`video/hevc`) | Compatible with standard mobile & desktop editors |
| **Audio** | `.m4a` | AAC (`audio/mp4a-latm`) | Hardware accelerated (64–320 kbps) |
| **Audio** | `.mp3` | MP3 (`audio/mpeg`) | 64–320 kbps |
| **Audio** | `.wav` | PCM (`audio/raw`) | 16-bit linear uncompressed PCM |

---

## Installation

Download the signed APK from [GitHub Releases](https://github.com/zerabyte88/phantek-video-toolkit-vega/releases/latest) or compile from source.

* **Architecture:** `arm64-v8a` (64-bit ARM)
* **Minimum Android Version:** Android 7.0 (API Level 24) or higher

---

## Building from Source

### Prerequisites
* [Flutter SDK](https://flutter.dev) (v3.13+)
* Android SDK & NDK
* Java 17+

### Build

```bash
# Clone the repository
git clone https://github.com/zerabyte88/phantek-video-toolkit-vega.git
cd phantek-video-toolkit-vega

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release
```

The output APK will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## Privacy & Security

* **No Network Access:** The app does not request `android.permission.INTERNET`. No network traffic can leave the device.
* **100% Local:** All operations, temporary caches, and output files stay strictly on local storage.
* **Zero Telemetry:** No analytics, advertising frameworks, or user trackers.

---

## License

This project is licensed under the **[MIT License](LICENSE)**.
