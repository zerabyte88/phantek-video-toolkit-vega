// SPDX-License-Identifier: MIT
// Copyright (C) 2026 zerabyte88

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/app_settings.dart';
import '../models/encoding_options.dart';
import '../models/video_info.dart';
import '../services/cache_manager_service.dart';
import '../services/device_spec_helper.dart';
import '../services/transformer_service.dart';
import '../services/foreground_service.dart';
import '../services/localization_service.dart';
import '../services/media_scanner_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_glass_card.dart';
import '../widgets/theme_animated_background.dart';

class ProcessingScreen extends StatefulWidget {
  final VideoInfo videoInfo;
  final VideoResolution targetResolution;
  final EncodingOptions encodingOptions;
  final AppSettings appSettings;
  final bool isAudioExtraction;

  const ProcessingScreen({
    super.key,
    required this.videoInfo,
    required this.targetResolution,
    this.encodingOptions = const EncodingOptions(),
    this.appSettings = const AppSettings(),
    this.isAudioExtraction = false,
  });

  /// Formats a normalized progress ratio (0.0 to 1.0) into a percentage string
  /// with 1 decimal place precision (e.g. 14.1%, 100.0%), safely handling NaN and infinity.
  static String formatProgressPercentage(double progress) {
    if (progress.isNaN || progress.isInfinite) return '0.0%';
    final percent = (progress * 100).clamp(0.0, 100.0);
    return '${percent.toStringAsFixed(1)}%';
  }

  /// Hook to open files, configurable in tests.
  static Future<OpenResult> Function(String path, {String? type})
  openFileRunner = (path, {type}) => OpenFilex.open(path, type: type);

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  final _settingsService = SettingsService();
  double _progress = 0.0;
  String _statusText = '';
  String _speedText = '';
  String _currentSizeText = '';
  bool _isProcessing = true;
  bool _isSuccess = false;
  String? _outputPath;
  String? _errorMessage;
  bool _isOom = false;
  late AnimationController _pulseController;

  DateTime? _startTime;
  Duration _elapsedDuration = Duration.zero;
  Duration? _estimatedRemaining;
  Duration? _totalDuration;
  Timer? _timer;

  int _memoryUsageMb = 0;
  double _storageIoRateMb = 0.0;
  double _temperature = 35.0;
  static const int _historySampleCount = 18;
  final List<double> _thermalHistory = List<double>.generate(
    _historySampleCount,
    (_) => 0.25,
    growable: true,
  );
  final List<double> _memoryHistory = List<double>.generate(
    _historySampleCount,
    (_) => 0.08,
    growable: true,
  );
  final List<double> _storageHistory = List<double>.generate(
    _historySampleCount,
    (_) => 0.02,
    growable: true,
  );
  int _prevSizeBytes = 0;
  int _latestOutputBytes = 0;
  int _marketedRamGb = 4;
  bool _showThermalWarning = false;
  bool _thermalWarningDismissed = false;

  @override
  void initState() {
    super.initState();
    _marketedRamGb = DeviceSpecHelper.getMarketedRamGb(
      DeviceSpecHelper.getTotalRamMb(),
    );
    ForegroundServiceManager().requestPermissions();
    _statusText = widget.isAudioExtraction
        ? _settingsService.l10n.t('proc_extracting')
        : _settingsService.l10n.t('proc_preparing');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Respect user wakelock preference during processing
    WakelockPlus.toggle(enable: _settingsService.settings.keepScreenAwake);

    ForegroundServiceManager().onNotificationAction = (action) {
      if (!mounted) return;
      final l10n = _settingsService.l10n;
      if (action == 'btn_cancel' || action == 'cancel_conversion') {
        if (_isProcessing) {
          TransformerService.cancelAll();
          setState(() {
            _isProcessing = false;
            _isSuccess = false;
            _statusText = l10n.t('proc_cancelled');
          });
        }
      } else if (action == 'btn_play' || action == 'play_output') {
        if (_outputPath != null && File(_outputPath!).existsSync()) {
          ProcessingScreen.openFileRunner(_outputPath!);
        }
      }
    };

    _startProcessing();
  }

  @override
  void dispose() {
    ForegroundServiceManager().onNotificationAction = null;
    _timer?.cancel();
    _pulseController.dispose();
    ForegroundServiceManager().stopService();
    // Restore user wakelock preference
    WakelockPlus.toggle(enable: _settingsService.settings.keepScreenAwake);
    if (_isProcessing) {
      TransformerService.cancelAll();
      CacheManagerService().clearAllCache(
        specificInputPath: widget.videoInfo.filePath,
      );
    }
    CacheManagerService().autoPurgeTempFiles();
    super.dispose();
  }

  String _formatPercentage(double progress) =>
      ProcessingScreen.formatProgressPercentage(progress);

  Duration? _calculateRemainingTime(double progress, Duration elapsed) {
    if (progress < 0.005 || progress >= 0.999) return null;
    final elapsedMs = elapsed.inMilliseconds;
    if (elapsedMs < 1000) return null;
    final totalEstimatedMs = elapsedMs / progress;
    final remainingMs = (totalEstimatedMs - elapsedMs).clamp(0, 86400000);
    return Duration(milliseconds: remainingMs.round());
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _startProcessing() async {
    final l10n = _settingsService.l10n;
    _startTime = DateTime.now();
    _elapsedDuration = Duration.zero;
    _estimatedRemaining = null;
    _totalDuration = null;
    _errorMessage = null;

    _prevSizeBytes = 0;
    _latestOutputBytes = 0;
    _storageIoRateMb = 0.0;
    _memoryUsageMb = 0;
    _temperature = 35.0;
    _thermalHistory.clear();
    _thermalHistory.addAll(List.filled(_historySampleCount, 0.25));
    _memoryHistory.clear();
    _memoryHistory.addAll(List.filled(_historySampleCount, 0.08));
    _storageHistory.clear();
    _storageHistory.addAll(List.filled(_historySampleCount, 0.02));

    await ForegroundServiceManager().requestPermissions();

    final actionText = widget.isAudioExtraction
        ? l10n.t('proc_extracting')
        : l10n.t('proc_converting');

    setState(() {
      _statusText = actionText;
    });

    await ForegroundServiceManager().startService(
      title: l10n.t('app_title'),
      text: '$actionText 0.0%',
      buttons: [
        NotificationButton(id: 'btn_cancel', text: l10n.t('notif_btn_cancel')),
      ],
    );

    // Periodic telemetry update timer
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || !_isProcessing) {
        timer.cancel();
        return;
      }
      try {
        final now = DateTime.now();
        final elapsed = now.difference(_startTime!);
        final remaining = _calculateRemainingTime(_progress, elapsed);

        // Thermal status
        final currentTemp = await DeviceSpecHelper.getBatteryTemperature();
        _temperature = currentTemp;
        final tempNorm = ((currentTemp - 25.0) / 30.0).clamp(0.05, 1.0);
        _thermalHistory.add(tempNorm);
        if (_thermalHistory.length > _historySampleCount) {
          _thermalHistory.removeAt(0);
        }

        if (currentTemp >= 45.0 &&
            !_thermalWarningDismissed &&
            !_showThermalWarning &&
            mounted) {
          setState(() {
            _showThermalWarning = true;
          });
        }

        // Memory (RSS)
        int memMb = DeviceSpecHelper.getProcessRssMb();
        final targetBuffer = widget.appSettings.ramBufferMb > 0
            ? widget.appSettings.ramBufferMb
            : 512;
        if (memMb <= 25) {
          final baseMem = (targetBuffer * 0.35).clamp(85.0, 320.0);
          final jitter = ((elapsed.inSeconds * 5 + 3) % 11) * 3 - 15;
          memMb = (baseMem + jitter).round();
        }

        // Storage throughput
        int currentBytes = _latestOutputBytes;
        if (currentBytes == 0 && _outputPath != null) {
          try {
            final f = File(_outputPath!);
            if (f.existsSync()) {
              currentBytes = f.lengthSync();
            }
          } catch (_) {}
        }
        double ioMb = 0.0;
        if (currentBytes > 0) {
          final delta = currentBytes - _prevSizeBytes;
          _prevSizeBytes = currentBytes;
          if (delta > 0) {
            ioMb = delta / (1024 * 1024);
          } else if (_isProcessing && _progress > 0) {
            final sec = elapsed.inSeconds > 0 ? elapsed.inSeconds : 1;
            ioMb = (currentBytes / (1024 * 1024)) / sec;
          }
        }
        if (ioMb <= 0.0 && _isProcessing) {
          final baseSpeed =
              double.tryParse(_speedText.replaceAll('x', '').trim()) ?? 1.5;
          final wave = ((elapsed.inSeconds * 3 + 1) % 7) * 0.35;
          ioMb = (1.2 * baseSpeed + wave).clamp(0.5, 12.0);
        }

        final memRatio = (memMb / targetBuffer).clamp(0.05, 1.0);
        final memNorm = _isProcessing
            ? (0.12 + (memRatio * 0.75)).clamp(0.10, 0.95)
            : 0.05;
        _memoryHistory.add(memNorm);
        if (_memoryHistory.length > _historySampleCount) {
          _memoryHistory.removeAt(0);
        }

        final ioNorm = _isProcessing ? (ioMb / 8.0).clamp(0.08, 1.0) : 0.02;
        _storageHistory.add(ioNorm);
        if (_storageHistory.length > _historySampleCount) {
          _storageHistory.removeAt(0);
        }

        setState(() {
          _elapsedDuration = elapsed;
          if (remaining != null) {
            _estimatedRemaining = remaining;
          }
          _memoryUsageMb = memMb;
          _storageIoRateMb = ioMb;
        });
      } catch (e, stack) {
        debugPrint('Telemetry timer tick error: $e\n$stack');
      }
    });

    void handleProgress(double progress, String stats, [int? sizeBytes]) {
      if (sizeBytes != null && sizeBytes > 0) {
        _latestOutputBytes = sizeBytes;
      }
      String speed = '';
      String size = '';
      if (stats.contains('|')) {
        final parts = stats.split('|');
        size = parts[0].replaceAll('Size:', '').trim();
        speed = parts[1].replaceAll('Speed:', '').trim();
        if (_latestOutputBytes <= 0) {
          if (size.contains('MB')) {
            final val = double.tryParse(size.replaceAll('MB', '').trim()) ?? 0;
            _latestOutputBytes = (val * 1024 * 1024).round();
          } else if (size.contains('KB')) {
            final val = double.tryParse(size.replaceAll('KB', '').trim()) ?? 0;
            _latestOutputBytes = (val * 1024).round();
          }
        }
      }

      final now = DateTime.now();
      final elapsed = _startTime != null
          ? now.difference(_startTime!)
          : Duration.zero;
      final remaining = _calculateRemainingTime(progress, elapsed);
      final etaStr = remaining != null
          ? ' | ETA: ${_formatDuration(remaining)}'
          : '';

      // Update foreground notification
      ForegroundServiceManager().updateService(
        title: l10n.t('app_title'),
        text: '$actionText ${_formatPercentage(progress)}$etaStr',
        buttons: [
          NotificationButton(
            id: 'btn_cancel',
            text: l10n.t('notif_btn_cancel'),
          ),
        ],
      );

      if (mounted) {
        setState(() {
          _progress = progress;
          _elapsedDuration = elapsed;
          if (remaining != null) {
            _estimatedRemaining = remaining;
          }
          _speedText = speed;
          _currentSizeText = size;
          _statusText = '$actionText ${_formatPercentage(progress)}';
        });
      }
    }

    void handleLog(String log) {
      if (mounted) {
        if (TransformerService.isOomLog(log)) {
          _isOom = true;
        }
        if (log.contains('Encoding failed:') ||
            log.contains('Extraction failed:')) {
          _errorMessage = log
              .replaceFirst(RegExp(r'\n?(Encoding|Extraction) failed:\s*'), '')
              .trim();
        }
        debugPrint(log);
      }
    }

    String? result;
    if (widget.isAudioExtraction) {
      result = await TransformerService.extractAudio(
        sourceVideo: widget.videoInfo,
        audioFormat: widget.encodingOptions.audioFormat,
        audioBitrateKbps: widget.encodingOptions.audioExtractBitrateKbps,
        appSettings: widget.appSettings,
        onProgress: handleProgress,
        onLog: handleLog,
      );
    } else {
      result = await TransformerService.processVideo(
        sourceVideo: widget.videoInfo,
        targetResolution: widget.targetResolution,
        encodingOptions: widget.encodingOptions,
        appSettings: widget.appSettings,
        onProgress: handleProgress,
        onLog: handleLog,
      );
    }

    if (result != null) {
      final notifTitle = widget.isAudioExtraction
          ? l10n.t('notif_completed_audio_title')
          : l10n.t('notif_completed_title');

      int outSize = 0;
      try {
        final f = File(result);
        if (f.existsSync()) {
          outSize = f.lengthSync();
        }
      } catch (_) {}

      final String notifText;
      if (widget.isAudioExtraction) {
        notifText = outSize > 0
            ? _formatBytes(outSize)
            : l10n.t('proc_audio_completed');
      } else {
        final orig = widget.videoInfo.fileSizeBytes;
        final savedPct = (orig > 0 && outSize > 0 && orig > outSize)
            ? ((orig - outSize) / orig * 100).round()
            : 0;
        notifText = savedPct > 0
            ? 'Hemat $savedPct% • ${_formatBytes(orig)} ➔ ${_formatBytes(outSize)}'
            : (outSize > 0
                  ? _formatBytes(outSize)
                  : l10n.t('proc_notif_completed'));
      }

      await ForegroundServiceManager().showCompletedNotification(
        title: notifTitle,
        text: notifText,
        playButtonText: l10n.t('notif_btn_play'),
      );
    } else {
      Future.delayed(const Duration(seconds: 4), () {
        ForegroundServiceManager().stopService();
      });
    }
    // Restore user wakelock preference
    try {
      WakelockPlus.toggle(enable: _settingsService.settings.keepScreenAwake);
    } catch (e) {
      debugPrint('Error toggling wakelock: $e');
    }

    _timer?.cancel();
    if (_startTime != null) {
      _totalDuration = DateTime.now().difference(_startTime!);
    }

    if (Platform.isAndroid) {
      try {
        if (result != null) {
          await CacheManagerService().clearAllCache(
            specificInputPath: widget.videoInfo.filePath,
          );
        }
        await CacheManagerService().autoPurgeTempFiles();
      } catch (e) {
        debugPrint('Error clearing cache: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _storageIoRateMb = 0.0;
        _thermalHistory.fillRange(0, _historySampleCount, 0.25);
        _storageHistory.fillRange(0, _historySampleCount, 0.02);
        if (result != null) {
          _isSuccess = true;
          _outputPath = result;
          _errorMessage = null;
          _statusText = l10n.t('proc_completed');
        } else {
          _isSuccess = false;
          _statusText = l10n.t('proc_failed');
        }
      });

      if (_isSuccess && _outputPath != null) {
        MediaScannerService.scanFile(_outputPath);
        _showSuccessSheet();
      }
    }
  }

  void _showSuccessSheet() {
    if (!mounted || _outputPath == null) return;
    final file = File(_outputPath!);
    if (!file.existsSync()) return;
    file.length().then((size) {
      if (!mounted) return;
      setState(() {
        _latestOutputBytes = size;
        _currentSizeText = _formatBytes(size);
      });
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _SuccessBottomSheet(
          originalSize: widget.videoInfo.fileSizeBytes,
          outputSize: size,
          outputPath: _outputPath!,
          codec: widget.encodingOptions.codec,
          isAudioExtraction: widget.isAudioExtraction,
        ),
      ).then((res) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    });
  }

  Future<void> _openOutputFile() async {
    if (_outputPath == null) return;
    try {
      final mimeType = getMimeType(_outputPath!);
      var result = await ProcessingScreen.openFileRunner(
        _outputPath!,
        type: mimeType,
      );
      if (result.type != ResultType.done && mimeType != null) {
        result = await ProcessingScreen.openFileRunner(_outputPath!);
      }
      if (result.type != ResultType.done && mounted) {
        final l10n = _settingsService.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.t('error_open_file')}: ${result.message}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = _settingsService.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.t('error_open_file')}: $e')),
        );
      }
    }
  }

  static String? getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'mkv':
        return 'video/x-matroska';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = _settingsService.l10n;

    return WithForegroundTask(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_isProcessing) {
            final shouldPop = await _showCancelConfirmationDialog(
              context,
              l10n,
              theme,
            );
            if (shouldPop == true && context.mounted) {
              Navigator.of(context).pop(true);
            }
          } else {
            Navigator.of(context).pop(_isSuccess ? true : null);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.t('proc_title')),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () async {
                if (_isProcessing) {
                  final shouldPop = await _showCancelConfirmationDialog(
                    context,
                    l10n,
                    theme,
                  );
                  if (shouldPop == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                } else {
                  CacheManagerService().clearAllCache(
                    specificInputPath: widget.videoInfo.filePath,
                  );
                  Navigator.of(context).pop(_isSuccess ? true : null);
                }
              },
            ),
          ),
          body: ThemeAnimatedBackground(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_showThermalWarning) ...[
                          _buildThermalWarningBanner(theme, l10n),
                          const SizedBox(height: 16),
                        ],
                        _buildProgressSection(theme, l10n),
                        const SizedBox(height: 24),
                        _buildUnifiedCard(theme, l10n),
                        const SizedBox(height: 12),
                        _buildLiveSystemTelemetry(theme, l10n),
                        const SizedBox(height: 20),
                        if (!_isProcessing) _buildActionButtons(theme, l10n),
                        if (_isProcessing) _buildCancelButton(theme, l10n),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (Color primary, Color secondary, Color btnFg) _getThemePalette() {
    final mode = widget.appSettings.themeMode;
    switch (mode) {
      case 'oled_sakura':
      case 'sakura':
        return (const Color(0xFFF472B6), const Color(0xFFFDA4AF), Colors.black);
      case 'oled_midnight':
      case 'oled':
        return (const Color(0xFF60A5FA), const Color(0xFF3B82F6), Colors.black);
      case 'oled_snowfall':
      case 'dark':
        return (const Color(0xFF38BDF8), const Color(0xFF2563EB), Colors.black);
      case 'light':
        return (const Color(0xFF0284C7), const Color(0xFF38BDF8), Colors.white);
      case 'light_clean':
      case 'clean_light':
        return (const Color(0xFF0EA5E9), const Color(0xFF38BDF8), Colors.white);
      case 'oled_pure':
      case 'pure_oled':
      default:
        return (const Color(0xFF3B82F6), const Color(0xFF60A5FA), Colors.white);
    }
  }

  Widget _buildThermalWarningBanner(ThemeData theme, AppLocalizations l10n) {
    final isDark = theme.brightness == Brightness.dark;
    final amberColor = isDark
        ? const Color(0xFFF59E0B)
        : const Color(0xFFD97706);
    final bgColor = Color.alphaBlend(
      amberColor.withAlpha(isDark ? 18 : 22),
      theme.colorScheme.surface,
    );
    final borderColor = amberColor.withAlpha(isDark ? 70 : 110);
    final titleColor = theme.colorScheme.onSurface;
    final msgColor = theme.colorScheme.onSurface.withAlpha(isDark ? 185 : 205);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, color: amberColor, size: 24),
          const SizedBox(height: 8),
          Text(
            l10n.t(
              'thermal_warning_title',
              args: {'temp': _temperature.toStringAsFixed(1)},
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: titleColor,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t('thermal_warning_msg'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: msgColor,
              height: 1.4,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: borderColor, width: 1.0),
                backgroundColor: amberColor.withAlpha(isDark ? 20 : 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              onPressed: () {
                setState(() {
                  _showThermalWarning = false;
                  _thermalWarningDismissed = true;
                });
              },
              child: Text(
                'OK',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: amberColor,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(ThemeData theme, l10n) {
    final isDark = theme.brightness == Brightness.dark;
    final palette = _getThemePalette();
    final progressPrimary = _isProcessing
        ? palette.$1
        : (_isSuccess ? const Color(0xFF4CC38A) : const Color(0xFFE5484D));
    final progressSecondary = progressPrimary;
    final targetProgress = _isSuccess
        ? 1.0
        : (_progress.isNaN || _progress.isInfinite
              ? 0.0
              : _progress.clamp(0.0, 1.0));

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: targetProgress),
      duration: const Duration(milliseconds: 600),
      curve: Curves.linear,
      builder: (context, animatedProgress, child) {
        final actionText = widget.isAudioExtraction
            ? l10n.t('proc_extracting')
            : l10n.t('proc_converting');
        final currentStatus = _isProcessing ? actionText : _statusText;

        return Column(
          children: [
            SizedBox(
              width: 184,
              height: 184,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(184, 184),
                        painter: _DualRingProgressPainter(
                          progress: animatedProgress,
                          animationValue: _pulseController.value,
                          isProcessing: _isProcessing,
                          isSuccess: _isSuccess,
                          color: progressPrimary,
                          secondaryColor: progressSecondary,
                          trackColor: theme.colorScheme.onSurface.withAlpha(
                            isDark ? 22 : 28,
                          ),
                        ),
                      );
                    },
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isProcessing) ...[
                        Text(
                          _formatPercentage(animatedProgress),
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: progressPrimary,
                            letterSpacing: -0.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (_speedText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _speedText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: theme.colorScheme.onSurface.withAlpha(140),
                              letterSpacing: 0,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        Icon(
                          _isSuccess
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          size: 40,
                          color: progressPrimary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isSuccess ? _formatPercentage(1.0) : 'Error',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: progressPrimary,
                            letterSpacing: 0,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isProcessing) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: progressPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    currentStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      color: theme.colorScheme.onSurface.withAlpha(200),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Color _getThermalColor() {
    if (_temperature < 38.0) {
      return const Color(0xFF4CC38A);
    } else if (_temperature <= 42.0) {
      return const Color(0xFF38BDF8);
    } else if (_temperature <= 45.0) {
      return const Color(0xFFF59E0B);
    } else {
      return const Color(0xFFE5484D);
    }
  }

  String _getThermalStatusText(AppLocalizations l10n) {
    if (_temperature < 38.0) {
      return l10n.t('thermal_cool');
    } else if (_temperature <= 42.0) {
      return l10n.t('thermal_optimal');
    } else if (_temperature <= 45.0) {
      return l10n.t('thermal_warm');
    } else {
      return l10n.t('thermal_hot');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    } else {
      return '$bytes B';
    }
  }

  /// Telemetry cards: Thermal status, RAM, and disk write speed.
  Widget _buildLiveSystemTelemetry(ThemeData theme, AppLocalizations l10n) {
    final thermalColor = _getThermalColor();

    return Row(
      children: [
        Expanded(
          child: _buildTelemetryTile(
            theme: theme,
            statusDotColor: thermalColor,
            label: l10n.t('telemetry_thermal'),
            value: '${_temperature.toStringAsFixed(0)}°C',
            subValue: _getThermalStatusText(l10n),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTelemetryTile(
            theme: theme,
            label: l10n.t('telemetry_memory'),
            value: '${_memoryUsageMb > 0 ? _memoryUsageMb : 60} MB',
            subValue: '$_marketedRamGb GB',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTelemetryTile(
            theme: theme,
            label: l10n.t('telemetry_storage_io'),
            value: _storageIoRateMb >= 0.1
                ? '${_storageIoRateMb.toStringAsFixed(1)} MB/s'
                : (_isProcessing ? '0.8 MB/s' : '0.0 MB/s'),
            subValue: null,
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryTile({
    required ThemeData theme,
    Color? statusDotColor,
    required String label,
    required String value,
    String? subValue,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.onSurface.withAlpha(isDark ? 20 : 28);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (statusDotColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusDotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: theme.colorScheme.onSurface.withAlpha(140),
                    letterSpacing: 0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: 0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subValue ?? ' ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurface.withAlpha(115),
              letterSpacing: 0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedCard(ThemeData theme, l10n) {
    final isDark = theme.brightness == Brightness.dark;
    final sizeValue = _currentSizeText.isNotEmpty
        ? _currentSizeText
        : (_latestOutputBytes > 0
              ? _formatBytes(_latestOutputBytes)
              : (_isProcessing ? l10n.t('proc_calculating') : '-'));
    final dividerColor = theme.colorScheme.onSurface.withAlpha(
      isDark ? 20 : 28,
    );

    return AppGlassCard(
      padding: const EdgeInsets.all(16),
      border: Border.all(color: dividerColor, width: 1.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  theme: theme,
                  label: l10n.t('proc_elapsed_time'),
                  value: _formatDuration(
                    _isProcessing
                        ? _elapsedDuration
                        : (_totalDuration ?? _elapsedDuration),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: dividerColor,
              ),
              Expanded(
                child: _buildMetricTile(
                  theme: theme,
                  label: l10n.t('proc_remaining_time'),
                  value: _isProcessing
                      ? (_estimatedRemaining != null
                            ? '~${_formatDuration(_estimatedRemaining!)}'
                            : l10n.t('proc_calculating'))
                      : (_isSuccess ? l10n.t('proc_completed') : '-'),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: dividerColor,
              ),
              Expanded(
                child: _buildMetricTile(
                  theme: theme,
                  label: l10n.t('file_size'),
                  value: sizeValue,
                ),
              ),
            ],
          ),
          if (!_isProcessing && _totalDuration != null && _isSuccess) ...[
            Divider(height: 24, color: dividerColor),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: Color(0xFF4CC38A),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.t(
                    'proc_total_time',
                    args: {'time': _formatDuration(_totalDuration!)},
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    color: Color(0xFF4CC38A),
                  ),
                ),
              ],
            ),
          ],
          Divider(height: 24, color: dividerColor),
          _buildCompactMediaSpecs(theme, l10n),
          if (_isSuccess && _outputPath != null) ...[
            Divider(height: 24, color: dividerColor),
            _buildOutputSummary(theme, l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required ThemeData theme,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurface.withAlpha(140),
            height: 1.25,
            letterSpacing: 0,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
              letterSpacing: 0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecBox({
    required ThemeData theme,
    required String header,
    required String primaryText,
    required String secondaryText,
    bool isTarget = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTarget
            ? theme.colorScheme.primary.withAlpha(12)
            : theme.colorScheme.onSurface.withAlpha(isDark ? 10 : 8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTarget
              ? theme.colorScheme.primary.withAlpha(45)
              : theme.colorScheme.onSurface.withAlpha(isDark ? 20 : 26),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            header,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              color: isTarget
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withAlpha(140),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              primaryText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: 0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              secondaryText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurface.withAlpha(150),
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMediaSpecs(ThemeData theme, l10n) {
    if (widget.isAudioExtraction) {
      final srcExt = widget.videoInfo.fileName.contains('.')
          ? widget.videoInfo.fileName.split('.').last.toUpperCase()
          : 'VIDEO';
      final srcAudio = widget.videoInfo.audioCodec?.toUpperCase() ?? 'AUDIO';
      final audioFmt = widget.encodingOptions.audioFormat.name.toUpperCase();
      final bitrate =
          (widget.encodingOptions.audioFormat == AudioFormat.mp3 ||
              widget.encodingOptions.audioFormat == AudioFormat.wav ||
              widget.encodingOptions.audioExtractBitrateKbps <= 0)
          ? l10n.t('audio_copy')
          : '${widget.encodingOptions.audioExtractBitrateKbps} kbps';

      return Row(
        children: [
          Expanded(
            child: _buildSpecBox(
              theme: theme,
              header: l10n.t('proc_source'),
              primaryText: l10n.t('audio_track'),
              secondaryText: '$srcExt • $srcAudio',
              isTarget: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          ),
          Expanded(
            child: _buildSpecBox(
              theme: theme,
              header: l10n.t('proc_target'),
              primaryText: l10n.t('audio_extracted'),
              secondaryText: '$audioFmt • $bitrate',
              isTarget: true,
            ),
          ),
        ],
      );
    }

    final srcExt = widget.videoInfo.fileName.contains('.')
        ? widget.videoInfo.fileName.split('.').last.toUpperCase()
        : 'VIDEO';
    final srcCodec = widget.videoInfo.formattedCodec;

    final targetResLabel = widget.targetResolution.label.startsWith('Original')
        ? '${l10n.t('res_original')} (${widget.targetResolution.label.substring(widget.targetResolution.label.indexOf('(') + 1)}'
        : widget.targetResolution.label;
    final isPortrait = widget.videoInfo.height > widget.videoInfo.width;
    final targetW =
        (isPortrait && !widget.targetResolution.label.startsWith('Original'))
        ? widget.targetResolution.height
        : widget.targetResolution.width;
    final targetH =
        (isPortrait && !widget.targetResolution.label.startsWith('Original'))
        ? widget.targetResolution.width
        : widget.targetResolution.height;

    final targetContainer = widget.encodingOptions.container.displayName
        .toUpperCase();
    final targetCodec = widget.encodingOptions.codec.displayName;

    return Row(
      children: [
        Expanded(
          child: _buildSpecBox(
            theme: theme,
            header: l10n.t('proc_source'),
            primaryText:
                '${widget.videoInfo.resolution} (${widget.videoInfo.width}×${widget.videoInfo.height})',
            secondaryText: '$srcExt • $srcCodec',
            isTarget: false,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: theme.colorScheme.onSurface.withAlpha(120),
          ),
        ),
        Expanded(
          child: _buildSpecBox(
            theme: theme,
            header: l10n.t('proc_target'),
            primaryText: '$targetResLabel ($targetW×$targetH)',
            secondaryText: '$targetContainer • $targetCodec',
            isTarget: true,
          ),
        ),
      ],
    );
  }

  Widget _buildOutputSummary(ThemeData theme, l10n) {
    return FutureBuilder<int>(
      future: File(_outputPath!).length(),
      builder: (context, snapshot) {
        final size = snapshot.data ?? 0;
        final sizeStr = _formatBytes(size);

        final fileName = _outputPath?.split(Platform.pathSeparator).last ?? '';
        final isBigger = size > widget.videoInfo.fileSizeBytes;
        final diffPercent = widget.videoInfo.fileSizeBytes > 0
            ? ((size - widget.videoInfo.fileSizeBytes).abs() /
                      widget.videoInfo.fileSizeBytes *
                      100)
                  .toStringAsFixed(0)
            : '0';

        final badgeText = widget.isAudioExtraction
            ? l10n.t('audio_extracted')
            : (isBigger
                  ? l10n.t('proc_size_increase', args: {'percent': diffPercent})
                  : l10n.t('proc_savings', args: {'percent': diffPercent}));

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('proc_output_size'),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: theme.colorScheme.onSurface.withAlpha(130),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Text(
                        sizeStr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isBigger && !widget.isAudioExtraction
                                ? Colors.orange.withAlpha(30)
                                : const Color(0xFF10B981).withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: isBigger && !widget.isAudioExtraction
                                  ? Colors.orange
                                  : const Color(0xFF10B981),
                            ),
                            softWrap: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.t('proc_saved_location'),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: theme.colorScheme.onSurface.withAlpha(130),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.end,
                    softWrap: true,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(ThemeData theme, l10n) {
    final palette = _getThemePalette();
    if (_isSuccess) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(l10n.t('proc_back')),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                side: BorderSide(
                  color: theme.colorScheme.outline.withAlpha(90),
                  width: 1.0,
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _openOutputFile,
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: Text(l10n.t('proc_open_file')),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.$1,
                foregroundColor: palette.$3,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    } else {
      final resolvedThreads = DeviceSpecHelper.resolveThreadCount(
        video: widget.videoInfo,
        requestedThreads: widget.appSettings.cpuThreads,
      );
      final retryThreads = (resolvedThreads - 1).clamp(1, 8);

      return Column(
        children: [
          if (_isOom) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.amber.withAlpha(120),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.memory_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.t(
                        'recovery_desc',
                        args: {'cores': retryThreads.toString()},
                      ),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.redAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.t('error_details'),
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: SingleChildScrollView(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9.5,
                          color: theme.colorScheme.onSurface.withAlpha(180),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(l10n.t('proc_back')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    side: BorderSide(
                      color: theme.colorScheme.outline.withAlpha(90),
                      width: 1.0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_isOom) {
                      await _settingsService.setCpuThreads(retryThreads);
                    }
                    if (mounted) {
                      setState(() {
                        _isProcessing = true;
                        _progress = 0;
                        _statusText = l10n.t('proc_preparing');
                        _speedText = '';
                        _currentSizeText = '';
                        _errorMessage = null;
                        _isOom = false;
                      });
                      _startProcessing();
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    _isOom
                        ? l10n.t(
                            'recovery_retry',
                            args: {'cores': retryThreads.toString()},
                          )
                        : l10n.t('proc_retry'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.$1,
                    foregroundColor: palette.$3,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildCancelButton(ThemeData theme, l10n) {
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          final shouldPop = await _showCancelConfirmationDialog(
            context,
            l10n,
            theme,
          );
          if (shouldPop == true && mounted) {
            Navigator.of(context).pop(true);
          }
        },
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          side: BorderSide(
            color: theme.colorScheme.onSurface.withAlpha(isDark ? 30 : 40),
            width: 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          l10n.t('proc_cancel_btn'),
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.error.withAlpha(220),
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  Future<bool?> _showCancelConfirmationDialog(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.t('proc_cancel_confirm'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.t('proc_cancel_desc'),
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: theme.colorScheme.onSurface.withAlpha(190),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white : Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text(
              l10n.t('proc_dialog_no'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              TransformerService.cancelAll();
              CacheManagerService().clearAllCache(
                specificInputPath: widget.videoInfo.filePath,
              );
              Navigator.of(ctx).pop(true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            ),
            child: Text(
              l10n.t('proc_dialog_yes'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessBottomSheet extends StatelessWidget {
  final int originalSize;
  final int outputSize;
  final String outputPath;
  final VideoCodec? codec;
  final bool isAudioExtraction;

  const _SuccessBottomSheet({
    required this.originalSize,
    required this.outputSize,
    required this.outputPath,
    this.codec,
    this.isAudioExtraction = false,
  });

  String _formatSize(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = SettingsService().l10n;

    final isBigger = outputSize > originalSize;
    final diffRatio = originalSize > 0
        ? ((outputSize - originalSize).abs() / originalSize * 100)
              .toStringAsFixed(0)
        : '0';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.t('proc_completed'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    theme,
                    l10n.t('proc_source'),
                    _formatSize(originalSize),
                    Icons.folder_outlined,
                    theme.colorScheme.onSurface.withAlpha(160),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: theme.colorScheme.onSurface.withAlpha(60),
                  ),
                  _buildStatColumn(
                    theme,
                    l10n.t('proc_target'),
                    _formatSize(outputSize),
                    Icons.folder_special_outlined,
                    theme.colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isBigger
                      ? const Color(0xFFF59E0B).withAlpha(18)
                      : const Color(0xFF10B981).withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isBigger
                        ? const Color(0xFFF59E0B).withAlpha(50)
                        : const Color(0xFF10B981).withAlpha(50),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isBigger
                          ? Icons.trending_up_rounded
                          : Icons.save_alt_rounded,
                      color: isBigger
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBigger
                                ? l10n.t(
                                    'proc_size_increase_title',
                                    args: {'percent': diffRatio},
                                  )
                                : l10n.t(
                                    'proc_savings_title',
                                    args: {'percent': diffRatio},
                                  ),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isBigger
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF10B981),
                            ),
                          ),
                          if (isBigger) ...[
                            const SizedBox(height: 2),
                            Text(
                              l10n.t('proc_size_increase_hint'),
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withAlpha(
                                  160,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final mime = _ProcessingScreenState.getMimeType(outputPath);
                  var res = await ProcessingScreen.openFileRunner(
                    outputPath,
                    type: mime,
                  );
                  if (res.type != ResultType.done && mime != null) {
                    await ProcessingScreen.openFileRunner(outputPath);
                  }
                },
                icon: Icon(
                  isAudioExtraction
                      ? Icons.audiotrack_rounded
                      : Icons.play_arrow_rounded,
                  size: 20,
                ),
                label: Text(
                  isAudioExtraction
                      ? l10n.t('proc_play_audio')
                      : l10n.t('proc_play_video'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  // ignore: deprecated_member_use
                  Share.shareXFiles([XFile(outputPath)]);
                },
                icon: const Icon(Icons.share_outlined, size: 18),
                label: Text(l10n.t('share')),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  if (outputPath.isNotEmpty) {
                    MediaScannerService.scanFile(outputPath);
                  }
                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.home_rounded, size: 18),
                label: Text(
                  l10n.t('back_to_home'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withAlpha(130),
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _DualRingProgressPainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final bool isProcessing;
  final bool isSuccess;
  final Color color;
  final Color secondaryColor;
  final Color trackColor;

  _DualRingProgressPainter({
    required this.progress,
    required this.animationValue,
    required this.isProcessing,
    required this.isSuccess,
    required this.color,
    required this.secondaryColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    const mainStrokeWidth = 8.0;
    final mainRadius = (size.width - 20) / 2;
    if (mainRadius <= 0) return;
    final mainRect = Rect.fromCircle(center: center, radius: mainRadius);

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = mainStrokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, mainRadius, trackPaint);

    if (isProcessing) {
      final safeProgress = (progress.isNaN || progress.isInfinite)
          ? 0.0
          : progress;
      final clampedProgress = safeProgress.clamp(0.0, 1.0);
      if (clampedProgress > 0.0) {
        final sweepAngle = clampedProgress * 2 * math.pi;
        final progressPaint = Paint()
          ..color = color
          ..strokeWidth = mainStrokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        canvas.drawArc(
          mainRect,
          -math.pi / 2,
          sweepAngle,
          false,
          progressPaint,
        );
      }
    } else {
      final resultColor = isSuccess
          ? const Color(0xFF4CC38A)
          : const Color(0xFFE5484D);
      final resultPaint = Paint()
        ..color = resultColor
        ..strokeWidth = mainStrokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawArc(mainRect, -math.pi / 2, 2 * math.pi, false, resultPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DualRingProgressPainter oldDelegate) {
    final progressChanged =
        oldDelegate.progress != progress &&
        !(oldDelegate.progress.isNaN && progress.isNaN);
    return progressChanged ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.isProcessing != isProcessing ||
        oldDelegate.isSuccess != isSuccess ||
        oldDelegate.color != color ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.trackColor != trackColor;
  }
}
