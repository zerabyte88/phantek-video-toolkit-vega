// SPDX-License-Identifier: MIT
// Copyright (C) 2026 zerabyte88

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/encoding_options.dart';
import '../models/video_info.dart';

import 'settings_service.dart';

/// Service interfacing with native AndroidX Media3 Transformer Hardware Encoder.
class TransformerService {
  static const MethodChannel _channel = MethodChannel(
    'com.phantek.cygnus.albireo/transformer',
  );

  static void Function(double progress, String stats, [int? sizeBytes])?
  _activeProgressCallback;
  static void Function(String log)? _activeLogCallback;
  static bool _handlerInitialized = false;

  static void _ensureMethodCallHandler() {
    if (_handlerInitialized) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onProgress':
          final args = call.arguments as Map<dynamic, dynamic>?;
          if (args != null) {
            final progress = (args['progress'] as num?)?.toDouble() ?? 0.0;
            final sizeBytes = (args['sizeBytes'] as num?)?.toInt() ?? 0;
            final sizeStr = sizeBytes > 1048576
                ? '${(sizeBytes / 1048576).toStringAsFixed(1)} MB'
                : '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
            _activeProgressCallback?.call(
              progress,
              'Size: $sizeStr | HW Accel',
              sizeBytes,
            );
          }
          break;
        case 'onLog':
          final args = call.arguments as Map<dynamic, dynamic>?;
          final msg = args?['message'] as String?;
          if (msg != null) {
            _activeLogCallback?.call(msg);
          }
          break;
      }
    });
    _handlerInitialized = true;
  }

  /// Probe a video file using Android MediaMetadataRetriever and MediaExtractor.
  static Future<VideoInfo?> getVideoInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      if (!Platform.isAndroid) {
        // Fallback for non-Android environments (tests, desktop)
        final fileSize = await file.length();
        return VideoInfo(
          filePath: filePath,
          fileName: file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : filePath,
          width: 1920,
          height: 1080,
          durationSeconds: 60.0,
          bitrate: 5000000,
          fps: 30.0,
          codec: 'h264',
          fileSizeBytes: fileSize,
          hasAudio: true,
          audioCodec: 'aac',
          audioChannels: 2,
          audioBitrateKbps: 128,
        );
      }

      final Map<dynamic, dynamic>? map = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getVideoInfo', {
            'filePath': filePath,
          });
      if (map == null) return null;

      final width = (map['width'] as num?)?.toInt() ?? 0;
      final height = (map['height'] as num?)?.toInt() ?? 0;
      final duration = (map['durationSeconds'] as num?)?.toDouble() ?? 0.0;
      final bitrate = (map['bitrate'] as num?)?.toInt() ?? 0;
      final fps = (map['fps'] as num?)?.toDouble() ?? 30.0;
      final codec = map['codec'] as String? ?? 'h264';
      final fileSize = (map['fileSizeBytes'] as num?)?.toInt() ?? 0;
      final hasAudio = map['hasAudio'] as bool? ?? false;
      final audioCodec = map['audioCodec'] as String?;
      final audioChannels = (map['audioChannels'] as num?)?.toInt();
      final audioBitrateKbps = (map['audioBitrateKbps'] as num?)?.toInt();

      return VideoInfo(
        filePath: filePath,
        fileName: file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : filePath,
        width: width,
        height: height,
        durationSeconds: duration,
        bitrate: bitrate,
        fps: fps,
        codec: codec,
        fileSizeBytes: fileSize,
        hasAudio: hasAudio,
        audioCodec: audioCodec,
        audioChannels: audioChannels,
        audioBitrateKbps: audioBitrateKbps,
      );
    } catch (e) {
      debugPrint('TransformerService.getVideoInfo error: $e');
      return null;
    }
  }

  /// Queries all available hardware video encoders on the device.
  static Future<List<Map<String, dynamic>>> getHardwareEncoders() async {
    if (!Platform.isAndroid) return [];
    try {
      final List<dynamic>? list = await _channel.invokeMethod<List<dynamic>>(
        'getHardwareEncoders',
      );
      if (list == null) return [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('TransformerService.getHardwareEncoders error: $e');
      return [];
    }
  }

  /// Get or create the output directory for converted media.
  static Future<Directory> getOutputDirectory({
    String? customPath,
    bool isAudio = false,
  }) async {
    if (customPath != null && customPath.trim().isNotEmpty) {
      final customDir = Directory(customPath.trim());
      try {
        if (!await customDir.exists()) {
          await customDir.create(recursive: true);
        }
        return customDir;
      } catch (_) {}
    }

    if (Platform.isAndroid) {
      final defaultPath = isAudio
          ? '/storage/emulated/0/Music'
          : '/storage/emulated/0/Movies';
      final targetDir = Directory(defaultPath);
      try {
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        return targetDir;
      } catch (e) {
        try {
          final extDirs = await getExternalStorageDirectories(
            type: isAudio ? StorageDirectory.music : StorageDirectory.movies,
          );
          if (extDirs != null && extDirs.isNotEmpty) {
            final fallback = extDirs.first;
            if (!await fallback.exists()) {
              await fallback.create(recursive: true);
            }
            return fallback;
          }
        } catch (_) {}

        final appDocDir = await getApplicationDocumentsDirectory();
        final fallbackDir = Directory(
          '${appDocDir.path}/${isAudio ? "Music" : "Movies"}',
        );
        if (!await fallbackDir.exists()) {
          await fallbackDir.create(recursive: true);
        }
        return fallbackDir;
      }
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dir = Directory(
        '${appDocDir.path}/${isAudio ? "Music" : "Movies"}',
      );
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }

  /// Generates a unique, non-colliding output path in [outputDir].
  static Future<String> generateUniqueOutputPath({
    required Directory outputDir,
    required String fileName,
    required VideoResolution targetResolution,
    required VideoContainer container,
    String? fileNamingFormat,
  }) async {
    final format = fileNamingFormat ?? 'suffix';
    final ext = container.extension;
    final sanitizedBase = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

    String baseName;
    switch (format) {
      case 'timestamp':
        final now = DateTime.now();
        final y = now.year.toString().padLeft(4, '0');
        final m = now.month.toString().padLeft(2, '0');
        final d = now.day.toString().padLeft(2, '0');
        final h = now.hour.toString().padLeft(2, '0');
        final min = now.minute.toString().padLeft(2, '0');
        final s = now.second.toString().padLeft(2, '0');
        baseName = '${sanitizedBase}_$y$m${d}_$h$min$s';
        break;
      case 'simple':
        baseName = '${sanitizedBase}_vega';
        break;
      case 'suffix':
      default:
        final String resSuffix =
            targetResolution.label.toLowerCase().startsWith('original')
            ? (targetResolution.height > 0
                  ? '${targetResolution.height}p'
                  : 'transcoded')
            : targetResolution.label.toLowerCase();
        baseName = '$sanitizedBase-$resSuffix';
        break;
    }

    final dirPath =
        outputDir.path.endsWith('/') || outputDir.path.endsWith('\\')
        ? outputDir.path.substring(0, outputDir.path.length - 1)
        : outputDir.path;
    final sep = Platform.pathSeparator;

    final basePath = '$dirPath$sep$baseName.$ext';
    if (!await File(basePath).exists()) {
      return basePath;
    }

    int counter = 2;
    while (true) {
      final candidatePath = '$dirPath$sep$baseName-$counter.$ext';
      if (!await File(candidatePath).exists()) {
        return candidatePath;
      }
      counter++;
    }
  }

  /// Generates a unique audio output path in [outputDir].
  static Future<String> generateUniqueAudioOutputPath({
    required Directory outputDir,
    required String fileName,
    required AudioFormat audioFormat,
  }) async {
    final ext = audioFormat.extension;
    final sanitizedBase = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    final dirPath =
        outputDir.path.endsWith('/') || outputDir.path.endsWith('\\')
        ? outputDir.path.substring(0, outputDir.path.length - 1)
        : outputDir.path;
    final sep = Platform.pathSeparator;

    final basePath = '$dirPath$sep$sanitizedBase-audio.$ext';
    if (!await File(basePath).exists()) {
      return basePath;
    }

    int counter = 2;
    while (true) {
      final candidatePath = '$dirPath$sep$sanitizedBase-audio-$counter.$ext';
      if (!await File(candidatePath).exists()) {
        return candidatePath;
      }
      counter++;
    }
  }

  /// Transcodes and downscales video using AndroidX Media3 Hardware Transformer.
  static Future<String?> processVideo({
    required VideoInfo sourceVideo,
    required VideoResolution targetResolution,
    EncodingOptions encodingOptions = const EncodingOptions(),
    AppSettings appSettings = const AppSettings(),
    required void Function(double progress, String stats, [int? sizeBytes])
    onProgress,
    required void Function(String log) onLog,
  }) async {
    _ensureMethodCallHandler();
    _activeProgressCallback = onProgress;
    _activeLogCallback = onLog;

    final outputDir = await getOutputDirectory(
      customPath: appSettings.outputDirectory,
    );

    final outputPath = await generateUniqueOutputPath(
      outputDir: outputDir,
      fileName: sourceVideo.fileName,
      targetResolution: targetResolution,
      container: encodingOptions.container,
      fileNamingFormat: appSettings.fileNamingFormat,
    );

    int targetW = targetResolution.width;
    int targetH = targetResolution.height;
    if (sourceVideo.height > sourceVideo.width &&
        !targetResolution.label.toLowerCase().startsWith('original')) {
      targetW = targetResolution.height;
      targetH = targetResolution.width;
    }
    final sourceAspect =
        sourceVideo.width / (sourceVideo.height > 0 ? sourceVideo.height : 1);
    final targetAspect = targetW / (targetH > 0 ? targetH : 1);
    if (sourceAspect > targetAspect) {
      targetH = (targetW / sourceAspect).round();
    } else {
      targetW = (targetH * sourceAspect).round();
    }
    targetW = (targetW ~/ 2) * 2;
    targetH = (targetH ~/ 2) * 2;

    final targetBitrateKbps = encodingOptions.calculateTargetBitrateKbps(
      targetWidth: targetW,
      targetHeight: targetH,
      sourceWidth: sourceVideo.width,
      sourceHeight: sourceVideo.height,
      sourceBitrateBps: sourceVideo.bitrate,
    );

    final is4K = sourceVideo.is4K;
    await SettingsService().saveJobMarker(
      inputPath: sourceVideo.filePath,
      outputPath: outputPath,
      allocatedThreads: appSettings.cpuThreads,
      is4K: is4K,
    );

    onLog('Engine: AndroidX Media3 Transformer (Hardware Accelerated)');
    onLog('Target: ${targetW}x$targetH (${encodingOptions.codec.displayName})');
    onLog(
      'Rate Control: ${encodingOptions.rateControlMode.displayName} @ $targetBitrateKbps kbps',
    );
    onLog('Output Path: $outputPath');

    if (!Platform.isAndroid) {
      // Mock completion for desktop / test runner
      onProgress(0.5, 'Size: 1.2 MB | Speed: 3.5x', 1200000);
      onProgress(1.0, 'Size: 2.5 MB | Completed', 2500000);
      if (appSettings.preserveMediaDate) {
        await _syncMediaDate(sourceVideo.filePath, outputPath);
      }
      await SettingsService().clearJobMarker();
      return outputPath;
    }

    try {
      final result = await _channel.invokeMethod<String>('transcodeVideo', {
        'inputPath': sourceVideo.filePath,
        'outputPath': outputPath,
        'sourceWidth': sourceVideo.width,
        'sourceHeight': sourceVideo.height,
        'targetWidth': targetW,
        'targetHeight': targetH,
        'bitrateBps': targetBitrateKbps * 1000,
        'videoCodec': encodingOptions.codec.name,
        'rateControlMode': encodingOptions.rateControlMode.name,
        'removeAudio':
            !sourceVideo.hasAudio || encodingOptions.videoAudioBitrateKbps <= 0,
      });

      await SettingsService().clearJobMarker();
      if (result != null) {
        onProgress(1.0, 'Completed', await File(outputPath).length());
        onLog('Encoding completed successfully via Media3 Hardware Encoder!');
        if (appSettings.preserveMediaDate) {
          await _syncMediaDate(sourceVideo.filePath, outputPath);
        }
        return result;
      }
      return null;
    } catch (e) {
      await SettingsService().clearJobMarker();
      onLog('Encoding failed: $e');
      final partial = File(outputPath);
      if (await partial.exists()) {
        try {
          await partial.delete();
        } catch (_) {}
      }
      return null;
    } finally {
      _activeProgressCallback = null;
      _activeLogCallback = null;
    }
  }

  static Future<void> _syncMediaDate(
    String inputPath,
    String outputPath,
  ) async {
    try {
      final inputFile = File(inputPath);
      final outputFile = File(outputPath);
      if (await inputFile.exists() && await outputFile.exists()) {
        await outputFile.setLastModified(await inputFile.lastModified());
      }
    } catch (e) {
      debugPrint('Error syncing media date: $e');
    }
  }

  /// Extracts audio from a video file using AndroidX Media3 or PCM extractor.
  static Future<String?> extractAudio({
    required VideoInfo sourceVideo,
    required AudioFormat audioFormat,
    int audioBitrateKbps = 192,
    AppSettings appSettings = const AppSettings(),
    required void Function(double progress, String stats, [int? sizeBytes])
    onProgress,
    required void Function(String log) onLog,
  }) async {
    _ensureMethodCallHandler();
    _activeProgressCallback = onProgress;
    _activeLogCallback = onLog;

    final outputDir = await getOutputDirectory(
      customPath: appSettings.audioOutputDirectory,
      isAudio: true,
    );
    final outputPath = await generateUniqueAudioOutputPath(
      outputDir: outputDir,
      fileName: sourceVideo.fileName,
      audioFormat: audioFormat,
    );

    await SettingsService().saveJobMarker(
      inputPath: sourceVideo.filePath,
      outputPath: outputPath,
      allocatedThreads: appSettings.cpuThreads,
      is4K: false,
    );

    onLog('Engine: AndroidX Media3 Audio Extractor');
    onLog('Format: ${audioFormat.displayName} @ $audioBitrateKbps kbps');
    onLog('Output Path: $outputPath');

    if (!Platform.isAndroid) {
      onProgress(1.0, 'Completed', 500000);
      if (appSettings.preserveMediaDate) {
        await _syncMediaDate(sourceVideo.filePath, outputPath);
      }
      await SettingsService().clearJobMarker();
      return outputPath;
    }

    try {
      final result = await _channel.invokeMethod<String>('extractAudio', {
        'inputPath': sourceVideo.filePath,
        'outputPath': outputPath,
        'format': audioFormat.extension,
        'bitrateKbps': audioBitrateKbps,
      });

      await SettingsService().clearJobMarker();
      if (result != null) {
        onProgress(1.0, 'Completed', await File(outputPath).length());
        onLog('Audio extraction completed successfully!');
        if (appSettings.preserveMediaDate) {
          await _syncMediaDate(sourceVideo.filePath, outputPath);
        }
        return result;
      }
      return null;
    } catch (e) {
      await SettingsService().clearJobMarker();
      onLog('Extraction failed: $e');
      final partial = File(outputPath);
      if (await partial.exists()) {
        try {
          await partial.delete();
        } catch (_) {}
      }
      return null;
    } finally {
      _activeProgressCallback = null;
      _activeLogCallback = null;
    }
  }

  /// Cancels active transformation execution.
  static Future<void> cancelAll() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('cancelTransformation');
    } catch (e) {
      debugPrint('TransformerService.cancelAll error: $e');
    }
  }

  /// Checks whether log indicates an OOM abort.
  static bool isOomLog(String log) {
    final lower = log.toLowerCase();
    return lower.contains('cannot allocate memory') ||
        lower.contains('out of memory') ||
        lower.contains('failed to allocate memory') ||
        lower.contains('malloc of size') ||
        lower.contains('oom');
  }
}
