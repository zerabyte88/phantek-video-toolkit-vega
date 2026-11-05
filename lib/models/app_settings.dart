import 'dart:io';

class AppSettings {
  /// CPU thread count. 0 triggers auto-detection.
  final int cpuThreads;

  /// RAM buffer size in MB.
  final int ramBufferMb;

  /// Encoding speed preset.
  final String encodingPreset;

  /// Audio bitrate in kbps. 0 mutes audio.
  final int audioBitrateKbps;

  /// Active language code.
  final String languageCode;

  /// Active theme identifier.
  final String themeMode;

  /// Keep screen awake during app usage.
  final bool keepScreenAwake;

  /// True on first launch.
  final bool isFirstLaunch;

  /// Custom video output directory.
  final String outputDirectory;

  /// Custom audio output directory.
  final String audioOutputDirectory;

  /// Card surface opacity (0.50 to 1.00).
  final double cardOpacity;

  /// Default video codec ('h264' or 'hevc').
  final String defaultVideoCodec;

  /// File naming pattern ('suffix', 'timestamp', 'simple').
  final String fileNamingFormat;

  /// Preserve original media file modification date.
  final bool preserveMediaDate;

  /// Whether to suppress the warning dialog when opening advanced settings.
  final bool suppressAdvancedModeWarning;

  /// Transcode engine ('hardware' or 'software').
  final String transcodeEngine;

  /// Automatically switch to alternative engine on error.
  final bool enableEngineFallback;

  /// Active progress style for video transcoding ('v1'..'v5').
  final String videoProgressStyle;

  /// Active progress style for audio extraction ('v1'..'v5').
  final String audioProgressStyle;

  const AppSettings({
    this.cpuThreads = 0,
    this.ramBufferMb = 512,
    this.encodingPreset = 'medium',
    this.audioBitrateKbps = 128,
    this.languageCode = 'en',
    this.themeMode = 'oled_pure',
    this.keepScreenAwake = false,
    this.isFirstLaunch = true,
    this.outputDirectory = '',
    this.audioOutputDirectory = '',
    this.cardOpacity = 1.0,
    this.defaultVideoCodec = 'h264',
    this.fileNamingFormat = 'suffix',
    this.preserveMediaDate = true,
    this.suppressAdvancedModeWarning = false,
    this.transcodeEngine = 'hardware',
    this.enableEngineFallback = true,
    this.videoProgressStyle = 'v1',
    this.audioProgressStyle = 'v1',
  });

  /// Physical CPU core count.
  static int get deviceCoreCount => Platform.numberOfProcessors;

  AppSettings copyWith({
    int? cpuThreads,
    int? ramBufferMb,
    String? encodingPreset,
    int? audioBitrateKbps,
    String? languageCode,
    String? themeMode,
    bool? keepScreenAwake,
    bool? isFirstLaunch,
    String? outputDirectory,
    String? audioOutputDirectory,
    double? cardOpacity,
    String? defaultVideoCodec,
    String? fileNamingFormat,
    bool? preserveMediaDate,
    bool? suppressAdvancedModeWarning,
    String? transcodeEngine,
    bool? enableEngineFallback,
    String? videoProgressStyle,
    String? audioProgressStyle,
  }) {
    return AppSettings(
      cpuThreads: cpuThreads ?? this.cpuThreads,
      ramBufferMb: ramBufferMb != null
          ? ramBufferMb.clamp(0, 2048)
          : this.ramBufferMb,
      encodingPreset: encodingPreset ?? this.encodingPreset,
      audioBitrateKbps: audioBitrateKbps ?? this.audioBitrateKbps,
      languageCode: languageCode ?? this.languageCode,
      themeMode: themeMode ?? this.themeMode,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      audioOutputDirectory: audioOutputDirectory ?? this.audioOutputDirectory,
      cardOpacity: cardOpacity != null
          ? cardOpacity.clamp(0.5, 1.0)
          : this.cardOpacity,
      defaultVideoCodec: defaultVideoCodec ?? this.defaultVideoCodec,
      fileNamingFormat: fileNamingFormat ?? this.fileNamingFormat,
      preserveMediaDate: preserveMediaDate ?? this.preserveMediaDate,
      suppressAdvancedModeWarning:
          suppressAdvancedModeWarning ?? this.suppressAdvancedModeWarning,
      transcodeEngine: transcodeEngine != null
          ? sanitizeTranscodeEngine(transcodeEngine)
          : this.transcodeEngine,
      enableEngineFallback:
          enableEngineFallback ?? this.enableEngineFallback,
      videoProgressStyle: videoProgressStyle != null
          ? sanitizeProgressStyle(videoProgressStyle)
          : this.videoProgressStyle,
      audioProgressStyle: audioProgressStyle != null
          ? sanitizeProgressStyle(audioProgressStyle)
          : this.audioProgressStyle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cpuThreads': cpuThreads,
      'ramBufferMb': ramBufferMb,
      'encodingPreset': encodingPreset,
      'audioBitrateKbps': audioBitrateKbps,
      'languageCode': languageCode,
      'themeMode': themeMode,
      'keepScreenAwake': keepScreenAwake,
      'isFirstLaunch': isFirstLaunch,
      'outputDirectory': outputDirectory,
      'audioOutputDirectory': audioOutputDirectory,
      'cardOpacity': cardOpacity,
      'defaultVideoCodec': defaultVideoCodec,
      'fileNamingFormat': fileNamingFormat,
      'preserveMediaDate': preserveMediaDate,
      'suppressAdvancedModeWarning': suppressAdvancedModeWarning,
      'transcodeEngine': transcodeEngine,
      'enableEngineFallback': enableEngineFallback,
      'videoProgressStyle': videoProgressStyle,
      'audioProgressStyle': audioProgressStyle,
    };
  }

  /// Normalizes preset to supported values (fast, medium, slow).
  static String sanitizePreset(String? preset) {
    if (preset == 'fast' || preset == 'slow') return preset!;
    if (preset == 'ultrafast' ||
        preset == 'superfast' ||
        preset == 'veryfast' ||
        preset == 'faster') {
      return 'fast';
    }
    return 'medium';
  }

  /// Normalizes transcode engine to supported values ('hardware', 'software').
  static String sanitizeTranscodeEngine(String? engine) {
    if (engine == 'software') return 'software';
    return 'hardware';
  }

  /// Normalizes progress animation style to supported values ('v1'..'v5').
  /// Maps legacy 'a1' -> 'v4', 'a3' -> 'v5'.
  static String sanitizeProgressStyle(String? style, [String fallback = 'v1']) {
    if (style == null) return fallback;
    final normalized = style.trim().toLowerCase();
    if (normalized == 'a1') return 'v4';
    if (normalized == 'a3') return 'v5';
    if (normalized == 'v1' ||
        normalized == 'v2' ||
        normalized == 'v3' ||
        normalized == 'v4' ||
        normalized == 'v5') {
      return normalized;
    }
    return fallback;
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      cpuThreads: json['cpuThreads'] as int? ?? 0,
      ramBufferMb: (json['ramBufferMb'] as int? ?? 512).clamp(0, 2048),
      encodingPreset: sanitizePreset(
        (json['encodingPreset'] ?? json['cpuPreset']) as String?,
      ),
      audioBitrateKbps: json['audioBitrateKbps'] as int? ?? 128,
      languageCode: json['languageCode'] as String? ?? 'en',
      themeMode: json['themeMode'] as String? ?? 'oled_pure',
      keepScreenAwake: json['keepScreenAwake'] as bool? ?? false,
      isFirstLaunch: json['isFirstLaunch'] as bool? ?? true,
      outputDirectory: json['outputDirectory'] as String? ?? '',
      audioOutputDirectory: json['audioOutputDirectory'] as String? ?? '',
      cardOpacity:
          (json['cardOpacity'] as num?)?.toDouble().clamp(0.5, 1.0) ?? 1.0,
      defaultVideoCodec: (json['defaultVideoCodec'] == 'hevc')
          ? 'hevc'
          : 'h264',
      fileNamingFormat:
          (json['fileNamingFormat'] == 'timestamp' ||
              json['fileNamingFormat'] == 'simple')
          ? json['fileNamingFormat'] as String
          : 'suffix',
      preserveMediaDate: json['preserveMediaDate'] as bool? ?? true,
      suppressAdvancedModeWarning:
          json['suppressAdvancedModeWarning'] as bool? ?? false,
      transcodeEngine: sanitizeTranscodeEngine(
        json['transcodeEngine'] as String?,
      ),
      enableEngineFallback: json['enableEngineFallback'] as bool? ?? true,
      videoProgressStyle: sanitizeProgressStyle(
        json['videoProgressStyle'] as String?,
      ),
      audioProgressStyle: sanitizeProgressStyle(
        json['audioProgressStyle'] as String?,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          cpuThreads == other.cpuThreads &&
          ramBufferMb == other.ramBufferMb &&
          encodingPreset == other.encodingPreset &&
          audioBitrateKbps == other.audioBitrateKbps &&
          languageCode == other.languageCode &&
          themeMode == other.themeMode &&
          keepScreenAwake == other.keepScreenAwake &&
          isFirstLaunch == other.isFirstLaunch &&
          outputDirectory == other.outputDirectory &&
          audioOutputDirectory == other.audioOutputDirectory &&
          cardOpacity == other.cardOpacity &&
          defaultVideoCodec == other.defaultVideoCodec &&
          fileNamingFormat == other.fileNamingFormat &&
          preserveMediaDate == other.preserveMediaDate &&
          suppressAdvancedModeWarning == other.suppressAdvancedModeWarning &&
          transcodeEngine == other.transcodeEngine &&
          enableEngineFallback == other.enableEngineFallback &&
          videoProgressStyle == other.videoProgressStyle &&
          audioProgressStyle == other.audioProgressStyle;

  @override
  int get hashCode => Object.hash(
    cpuThreads,
    ramBufferMb,
    encodingPreset,
    audioBitrateKbps,
    languageCode,
    themeMode,
    keepScreenAwake,
    isFirstLaunch,
    outputDirectory,
    audioOutputDirectory,
    cardOpacity,
    defaultVideoCodec,
    fileNamingFormat,
    preserveMediaDate,
    suppressAdvancedModeWarning,
    transcodeEngine,
    enableEngineFallback,
    videoProgressStyle,
    audioProgressStyle,
  );
}
