// SPDX-License-Identifier: MIT
// Copyright (C) 2026 zerabyte88

import 'dart:math' as math;

enum VideoCodec {
  h264('H.264 / AVC', 'video/avc'),
  hevc('H.265 / HEVC', 'video/hevc');

  final String displayName;
  final String mimeType;

  const VideoCodec(this.displayName, this.mimeType);

  static VideoCodec fromName(String? name) =>
      name == 'hevc' ? VideoCodec.hevc : VideoCodec.h264;
}

enum VideoContainer {
  mp4('MP4', 'mp4'),
  mkv('MKV', 'mkv'),
  mov('MOV', 'mov');

  final String displayName;
  final String extension;

  const VideoContainer(this.displayName, this.extension);
}

enum RateControlMode {
  crf('Constant Quality (CQ/CRF)'),
  bitrate('Bitrate (CBR/VBR)');

  final String displayName;

  const RateControlMode(this.displayName);
}

enum AudioFormat {
  m4a('M4A', 'm4a', 'audio/mp4a-latm'),
  mp3('MP3', 'mp3', 'audio/mpeg'),
  wav('WAV', 'wav', 'audio/raw');

  final String displayName;
  final String extension;
  final String mimeType;

  const AudioFormat(this.displayName, this.extension, this.mimeType);
}

enum SpeedPreset {
  fast(24),
  normal(22),
  max(20);

  final int defaultCrf;

  const SpeedPreset(this.defaultCrf);

  String get encodingPresetName {
    switch (this) {
      case SpeedPreset.fast:
        return 'fast';
      case SpeedPreset.normal:
        return 'medium';
      case SpeedPreset.max:
        return 'slow';
    }
  }

  static SpeedPreset fromEncodingPreset(String? preset) {
    switch (preset) {
      case 'fast':
        return SpeedPreset.fast;
      case 'slow':
        return SpeedPreset.max;
      case 'medium':
      default:
        return SpeedPreset.normal;
    }
  }
}

class EncodingOptions {
  static const Object _sentinel = Object();

  final VideoCodec codec;
  final VideoContainer container;

  // Rate control
  final RateControlMode rateControlMode;
  final SpeedPreset speedPreset;
  final int crfValue;
  final int customBitrateKbps;

  // Target FPS (0: original)
  final int targetFps;

  // Audio options
  final AudioFormat audioFormat;
  final int audioExtractBitrateKbps; // 0 for stream copy, or target kbps
  final int videoAudioBitrateKbps; // 0 for mute, or 128, 192, 256, 320

  // Trimming (in milliseconds, null means untrimmed)
  final int? trimStartMs;
  final int? trimEndMs;

  /// Convenience alias for [crfValue].
  int get crf => crfValue;

  const EncodingOptions({
    this.codec = VideoCodec.h264,
    this.container = VideoContainer.mp4,
    this.rateControlMode = RateControlMode.crf,
    this.speedPreset = SpeedPreset.normal,
    this.crfValue = 22,
    this.customBitrateKbps = 10000,
    this.targetFps = 0,
    this.audioFormat = AudioFormat.m4a,
    this.audioExtractBitrateKbps = 192,
    this.videoAudioBitrateKbps = 128,
    this.trimStartMs,
    this.trimEndMs,
  });

  bool get isTrimmed => trimStartMs != null || trimEndMs != null;

  EncodingOptions copyWith({
    VideoCodec? codec,
    VideoContainer? container,
    RateControlMode? rateControlMode,
    SpeedPreset? speedPreset,
    int? crfValue,
    int? customBitrateKbps,
    int? targetFps,
    AudioFormat? audioFormat,
    int? audioExtractBitrateKbps,
    int? videoAudioBitrateKbps,
    Object? trimStartMs = _sentinel,
    Object? trimEndMs = _sentinel,
  }) {
    return EncodingOptions(
      codec: codec ?? this.codec,
      container: container ?? this.container,
      rateControlMode: rateControlMode ?? this.rateControlMode,
      speedPreset: speedPreset ?? this.speedPreset,
      crfValue: crfValue ?? this.crfValue,
      customBitrateKbps: customBitrateKbps ?? this.customBitrateKbps,
      targetFps: targetFps ?? this.targetFps,
      audioFormat: audioFormat ?? this.audioFormat,
      audioExtractBitrateKbps:
          audioExtractBitrateKbps ?? this.audioExtractBitrateKbps,
      videoAudioBitrateKbps:
          videoAudioBitrateKbps ?? this.videoAudioBitrateKbps,
      trimStartMs: trimStartMs == _sentinel
          ? this.trimStartMs
          : trimStartMs as int?,
      trimEndMs: trimEndMs == _sentinel ? this.trimEndMs : trimEndMs as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codec': codec.name,
      'container': container.name,
      'rateControlMode': rateControlMode.name,
      'speedPreset': speedPreset.name,
      'crfValue': crfValue,
      'customBitrateKbps': customBitrateKbps,
      'targetFps': targetFps,
      'audioFormat': audioFormat.name,
      'audioExtractBitrateKbps': audioExtractBitrateKbps,
      'videoAudioBitrateKbps': videoAudioBitrateKbps,
      'trimStartMs': trimStartMs,
      'trimEndMs': trimEndMs,
    };
  }

  factory EncodingOptions.fromJson(Map<String, dynamic> json) {
    return EncodingOptions(
      codec: VideoCodec.fromName(json['codec'] as String?),
      container: VideoContainer.values.firstWhere(
        (e) => e.name == json['container'],
        orElse: () => VideoContainer.mp4,
      ),
      rateControlMode: RateControlMode.values.firstWhere(
        (e) => e.name == json['rateControlMode'],
        orElse: () => RateControlMode.crf,
      ),
      speedPreset: SpeedPreset.values.firstWhere(
        (e) => e.name == json['speedPreset'],
        orElse: () => SpeedPreset.normal,
      ),
      crfValue: (json['crfValue'] as num?)?.toInt() ?? 22,
      customBitrateKbps: (json['customBitrateKbps'] as num?)?.toInt() ?? 10000,
      targetFps: (json['targetFps'] as num?)?.toInt() ?? 0,
      audioFormat: AudioFormat.values.firstWhere(
        (e) => e.name == json['audioFormat'],
        orElse: () => AudioFormat.m4a,
      ),
      audioExtractBitrateKbps:
          (json['audioExtractBitrateKbps'] as num?)?.toInt() ?? 192,
      videoAudioBitrateKbps:
          (json['videoAudioBitrateKbps'] as num?)?.toInt() ?? 128,
      trimStartMs: (json['trimStartMs'] as num?)?.toInt(),
      trimEndMs: (json['trimEndMs'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EncodingOptions &&
          runtimeType == other.runtimeType &&
          codec == other.codec &&
          container == other.container &&
          rateControlMode == other.rateControlMode &&
          speedPreset == other.speedPreset &&
          crfValue == other.crfValue &&
          customBitrateKbps == other.customBitrateKbps &&
          targetFps == other.targetFps &&
          audioFormat == other.audioFormat &&
          audioExtractBitrateKbps == other.audioExtractBitrateKbps &&
          videoAudioBitrateKbps == other.videoAudioBitrateKbps &&
          trimStartMs == other.trimStartMs &&
          trimEndMs == other.trimEndMs;

  @override
  int get hashCode => Object.hash(
    codec,
    container,
    rateControlMode,
    speedPreset,
    crfValue,
    customBitrateKbps,
    targetFps,
    audioFormat,
    audioExtractBitrateKbps,
    videoAudioBitrateKbps,
    trimStartMs,
    trimEndMs,
  );

  /// Estimates target video bitrate in kbps based on resolution and rate control mode.
  int calculateTargetBitrateKbps({
    required int targetWidth,
    required int targetHeight,
    required int sourceWidth,
    required int sourceHeight,
    required int sourceBitrateBps,
  }) {
    final maxDim = targetWidth > targetHeight ? targetWidth : targetHeight;

    if (rateControlMode == RateControlMode.bitrate) {
      return customBitrateKbps;
    }

    final double baseMbps;
    if (maxDim >= 2560) {
      baseMbps = 8.5;
    } else if (maxDim >= 1920) {
      baseMbps = 4.5;
    } else if (maxDim >= 1280) {
      baseMbps = 2.5;
    } else if (maxDim >= 854) {
      baseMbps = 1.3;
    } else {
      baseMbps = 0.8;
    }

    // Scale factor: ±6 CRF halves or doubles bitrate
    final diff = crfValue - 20;
    final factor = diff / 6.0;
    double estimatedBitrateMbps = baseMbps * math.pow(0.5, factor);
    const minFloorKbps = 300;

    // Avoid upscaling bitrate beyond source video
    if (sourceBitrateBps > 0) {
      final sourceKbps = sourceBitrateBps ~/ 1000;
      if (sourceKbps > 500 && (estimatedBitrateMbps * 1000) > sourceKbps) {
        estimatedBitrateMbps = (sourceKbps / 1000.0) * 0.95;
      }
    }

    return (estimatedBitrateMbps * 1000).round().clamp(minFloorKbps, 50000);
  }
}
