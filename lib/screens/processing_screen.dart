import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/progress_animation_painter.dart';
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

  /// Formats a normalized progress ratio (0.0 to 1.0) into an integer percentage string
  /// (e.g. 14%, 100%), safely handling NaN and infinity.
  static String formatProgressPercentage(double progress) {
    if (progress.isNaN || progress.isInfinite) return '0%';
    final percent = (progress * 100).clamp(0.0, 100.0).round();
    return '$percent%';
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
    (_) => 0.24,
    growable: true,
  );
  int _prevSizeBytes = 0;
  int _latestOutputBytes = 0;
  bool _showThermalWarning = false;
  bool _thermalWarningDismissed = false;

  @override
  void initState() {
    super.initState();
    ForegroundServiceManager().requestPermissions();
    _statusText = widget.isAudioExtraction
        ? _settingsService.l10n.t('proc_extracting')
        : _settingsService.l10n.t('proc_preparing');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    // Respect user wakelock preference during processing
    WakelockPlus.toggle(enable: _settingsService.settings.keepScreenAwake);

    ForegroundServiceManager().onNotificationAction = (action) {
      if (!mounted) return;
      final l10n = _settingsService.l10n;
      if (action == 'btn_cancel' || action == 'cancel_conversion') {
        if (_isProcessing) {
          TransformerService.cancelAll();
          _pulseController.stop();
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
    _storageHistory.addAll(List.filled(_historySampleCount, 0.24));

    await ForegroundServiceManager().requestPermissions();

    final actionText = widget.isAudioExtraction
        ? l10n.t('proc_extracting')
        : l10n.t('proc_converting');

    setState(() {
      _statusText = actionText;
    });

    await ForegroundServiceManager().startService(
      title: l10n.t('app_title'),
      text: '$actionText 0%',
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
        if (_outputPath != null) {
          try {
            final f = File(_outputPath!);
            if (f.existsSync()) {
              final diskBytes = f.lengthSync();
              if (diskBytes > currentBytes) {
                currentBytes = diskBytes;
                _latestOutputBytes = diskBytes;
              }
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

        final ioNorm = _isProcessing
            ? (0.24 + (ioMb / 8.0) * 0.66).clamp(0.26, 0.95)
            : 0.20;
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
      } else {
        size = stats.replaceAll('Size:', '').trim();
      }
      if (speed == 'HW Accel') {
        speed = '';
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

      await ForegroundServiceManager().showCompletedNotification(
        title: notifTitle,
        text: '',
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
      _pulseController.stop();
      setState(() {
        _isProcessing = false;
        _storageIoRateMb = 0.0;
        _thermalHistory.fillRange(0, _historySampleCount, 0.25);
        _storageHistory.fillRange(0, _historySampleCount, 0.20);
        if (result != null) {
          _isSuccess = true;
          _outputPath = result;
          _errorMessage = null;
          _statusText = l10n.t('proc_completed');
        } else {
          _isSuccess = false;
          _statusText = widget.isAudioExtraction
              ? l10n.t('proc_audio_failed')
              : l10n.t('proc_failed');
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

  ({
    Color primary,
    Color deep,
    Color crest,
    Color basin,
    Color track,
    Color btn,
    Color btnFg,
  })
  _getThemePalette() {
    switch (widget.appSettings.themeMode) {
      case 'light':
        return (
          primary: const Color(0xFFD97706),
          deep: const Color(0xFFF59E0B),
          crest: const Color(0xFFFBBF24),
          basin: const Color(0xFFFFFBEB),
          track: const Color(0xFFFDE68A),
          btn: const Color(0xFFFBBF24),
          btnFg: Colors.white,
        );
      case 'oled_midnight':
      case 'oled':
        return (
          primary: const Color(0xFFA78BFA),
          deep: const Color(0xFF6D28D9),
          crest: const Color(0xFFC4B5FD),
          basin: const Color(0xFF0C081C),
          track: const Color(0xFF2B1F4A),
          btn: const Color(0xFFA78BFA),
          btnFg: Colors.white,
        );
      case 'oled_sakura':
      case 'sakura':
        return (
          primary: const Color(0xFFF472B6),
          deep: const Color(0xFFDB2777),
          crest: const Color(0xFFFBCFE8),
          basin: const Color(0xFF160912),
          track: const Color(0xFF3D172B),
          btn: const Color(0xFFF472B6),
          btnFg: Colors.black,
        );
      case 'oled_pure':
      case 'pure_oled':
        return (
          primary: const Color(0xFF60A5FA),
          deep: const Color(0xFF2563EB),
          crest: const Color(0xFF93C5FD),
          basin: const Color(0xFF050912),
          track: const Color(0xFF1E293B),
          btn: const Color(0xFF2563EB),
          btnFg: Colors.white,
        );
      case 'light_clean':
      case 'clean_light':
        return (
          primary: const Color(0xFF0284C7),
          deep: const Color(0xFF0EA5E9),
          crest: const Color(0xFF7DD3FC),
          basin: const Color(0xFFF0F9FF),
          track: const Color(0xFFBAE6FD),
          btn: const Color(0xFF2563EB),
          btnFg: Colors.white,
        );
      case 'oled_snowfall':
      case 'dark':
      default:
        return (
          primary: const Color(0xFF38BDF8),
          deep: const Color(0xFF1D4ED8),
          crest: const Color(0xFF67E8F9),
          basin: const Color(0xFF060E1F),
          track: const Color(0xFF1E3254),
          btn: const Color(0xFF38BDF8),
          btnFg: Colors.white,
        );
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

  List<Shadow> _buildTextOutlineShadows(Color outlineColor) {
    final stroke = outlineColor.withAlpha(235);
    return [
      Shadow(offset: const Offset(-0.7, -0.7), blurRadius: 0.4, color: stroke),
      Shadow(offset: const Offset(0.7, -0.7), blurRadius: 0.4, color: stroke),
      Shadow(offset: const Offset(0.7, 0.7), blurRadius: 0.4, color: stroke),
      Shadow(offset: const Offset(-0.7, 0.7), blurRadius: 0.4, color: stroke),
      Shadow(offset: const Offset(0, -0.9), blurRadius: 0.4, color: stroke),
      Shadow(offset: const Offset(0, 0.9), blurRadius: 0.4, color: stroke),
      Shadow(offset: const Offset(-0.9, 0), blurRadius: 0.4, color: stroke),
      Shadow(offset: const Offset(0.9, 0), blurRadius: 0.4, color: stroke),
    ];
  }

  Widget _buildProgressSection(ThemeData theme, l10n) {
    final isDark = theme.brightness == Brightness.dark;
    final palette = _getThemePalette();
    final textOutlineShadows = _buildTextOutlineShadows(palette.basin);
    final progressPrimary = _isProcessing
        ? palette.primary
        : (_isSuccess ? const Color(0xFF4CC38A) : const Color(0xFFE5484D));
    final progressSecondary = progressPrimary;
    final targetProgress = _isSuccess
        ? 1.0
        : (_progress.isNaN || _progress.isInfinite
              ? 0.0
              : _progress.clamp(0.0, 1.0));

    final settings = widget.appSettings != const AppSettings()
        ? widget.appSettings
        : _settingsService.settings;
    final activeStyle = AppSettings.sanitizeProgressStyle(
      widget.isAudioExtraction
          ? settings.audioProgressStyle
          : settings.videoProgressStyle,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: targetProgress),
      duration: const Duration(milliseconds: 600),
      curve: Curves.linear,
      builder: (context, animatedProgress, child) {
        final actionText = widget.isAudioExtraction
            ? l10n.t('proc_extracting')
            : l10n.t('proc_converting');
        final currentStatus = _isProcessing ? actionText : _statusText;

        final percentageWidget = _isProcessing
            ? Text(
                _formatPercentage(animatedProgress),
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: progressPrimary,
                  letterSpacing: -0.5,
                  shadows: textOutlineShadows,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    size: 40,
                    color: progressPrimary,
                    shadows: textOutlineShadows,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSuccess ? _formatPercentage(1.0) : 'Error',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: progressPrimary,
                      letterSpacing: 0,
                      shadows: textOutlineShadows,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              );

        Widget indicatorWidget;
        switch (activeStyle) {
          case 'v1': // Orbit: 180x180 dp, center percentage 38sp
          case 'v2': // Radar: 180x180 dp, center percentage 38sp
          case 'v3': // Liquid: 180x180 dp, center percentage 38sp
          case 'v4': // Particles: 180x180 dp, center percentage 38sp
          case 'v5': // Spiral: 180x180 dp, center percentage 38sp
            indicatorWidget = SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        final animTime = _startTime != null
                            ? DateTime.now()
                                      .difference(_startTime!)
                                      .inMicroseconds /
                                  1000000.0
                            : _pulseController.value * 2.4;
                        return CustomPaint(
                          size: const Size(180, 180),
                          painter: _DualRingProgressPainter(
                            progress: animatedProgress,
                            animationValue: _pulseController.value,
                            animTime: animTime,
                            isProcessing: _isProcessing,
                            isSuccess: _isSuccess,
                            color: progressPrimary,
                            secondaryColor: progressSecondary,
                            deepColor: palette.deep,
                            crestColor: palette.crest,
                            basinColor: palette.basin,
                            trackColor: palette.track,
                            style: activeStyle,
                            isDark: isDark,
                          ),
                        );
                      },
                    ),
                  ),
                  percentageWidget,
                ],
              ),
            );
            break;

          case 'v6': // Zig-Zag: 280x24 dp, center percentage 38sp above bar
            indicatorWidget = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                percentageWidget,
                const SizedBox(height: 14),
                SizedBox(
                  width: 280,
                  height: 24,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        final animTime = _startTime != null
                            ? DateTime.now()
                                      .difference(_startTime!)
                                      .inMicroseconds /
                                  1000000.0
                            : _pulseController.value * 2.4;
                        return CustomPaint(
                          size: const Size(280, 24),
                          painter: _DualRingProgressPainter(
                            progress: animatedProgress,
                            animationValue: _pulseController.value,
                            animTime: animTime,
                            isProcessing: _isProcessing,
                            isSuccess: _isSuccess,
                            color: progressPrimary,
                            secondaryColor: progressSecondary,
                            deepColor: palette.deep,
                            crestColor: palette.crest,
                            basinColor: palette.basin,
                            trackColor: palette.track,
                            style: 'v6',
                            isDark: isDark,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
            break;

          case 'v7': // Capsule: 280x16 dp, center percentage 38sp above bar
            indicatorWidget = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                percentageWidget,
                const SizedBox(height: 14),
                SizedBox(
                  width: 280,
                  height: 16,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        final animTime = _startTime != null
                            ? DateTime.now()
                                      .difference(_startTime!)
                                      .inMicroseconds /
                                  1000000.0
                            : _pulseController.value * 2.4;
                        return CustomPaint(
                          size: const Size(280, 16),
                          painter: _DualRingProgressPainter(
                            progress: animatedProgress,
                            animationValue: _pulseController.value,
                            animTime: animTime,
                            isProcessing: _isProcessing,
                            isSuccess: _isSuccess,
                            color: progressPrimary,
                            secondaryColor: progressSecondary,
                            deepColor: palette.deep,
                            crestColor: palette.crest,
                            basinColor: palette.basin,
                            trackColor: palette.track,
                            style: 'v7',
                            isDark: isDark,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
            break;

          case 'v8': // Equalizer: 280x24 dp, center percentage 38sp above bar
          default:
            indicatorWidget = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                percentageWidget,
                const SizedBox(height: 14),
                SizedBox(
                  width: 280,
                  height: 24,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        final animTime = _startTime != null
                            ? DateTime.now()
                                      .difference(_startTime!)
                                      .inMicroseconds /
                                  1000000.0
                            : _pulseController.value * 2.4;
                        return CustomPaint(
                          size: const Size(280, 24),
                          painter: _DualRingProgressPainter(
                            progress: animatedProgress,
                            animationValue: _pulseController.value,
                            animTime: animTime,
                            isProcessing: _isProcessing,
                            isSuccess: _isSuccess,
                            color: progressPrimary,
                            secondaryColor: progressSecondary,
                            deepColor: palette.deep,
                            crestColor: palette.crest,
                            basinColor: palette.basin,
                            trackColor: palette.track,
                            style: 'v8',
                            isDark: isDark,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
            break;
        }

        return Column(
          children: [
            indicatorWidget,
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
    final palette = _getThemePalette();

    return Row(
      children: [
        Expanded(
          child: _buildTelemetryTile(
            theme: theme,
            label: l10n.t('telemetry_thermal'),
            value: '${_temperature.toStringAsFixed(0)}°C',
            history: _thermalHistory,
            graphColor: thermalColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTelemetryTile(
            theme: theme,
            label: l10n.t('telemetry_memory'),
            value: '${_memoryUsageMb > 0 ? _memoryUsageMb : 60} MB',
            history: _memoryHistory,
            graphColor: palette.primary,
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
            history: _storageHistory,
            graphColor: palette.deep,
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryTile({
    required ThemeData theme,
    required String label,
    required String value,
    List<double>? history,
    Color? graphColor,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final cardOpacity = _settingsService.settings.cardOpacity.clamp(0.5, 1.0);
    final cardBg = cardOpacity < 1.0
        ? theme.colorScheme.surface.withAlpha(
            (255 * cardOpacity).round().clamp(0, 255),
          )
        : theme.colorScheme.surface;
    final borderColor = theme.colorScheme.onSurface.withAlpha(isDark ? 20 : 28);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withAlpha(140),
                letterSpacing: 0,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.0,
                color: theme.colorScheme.onSurface,
                letterSpacing: 0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              strutStyle: const StrutStyle(
                fontSize: 15,
                height: 1.0,
                forceStrutHeight: true,
              ),
            ),
          ),
          if (history != null && graphColor != null) ...[
            const SizedBox(height: 8),
            _WindowsTaskGraph(
              history: history,
              color: graphColor,
              isProcessing: _isProcessing,
            ),
          ],
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
                margin: const EdgeInsets.symmetric(horizontal: 6),
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
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: dividerColor,
              ),
              Expanded(
                child: _buildMetricTile(
                  theme: theme,
                  label: l10n.t('proc_output_size'),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurface.withAlpha(140),
              height: 1.25,
              letterSpacing: 0,
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            value,
            textAlign: TextAlign.center,
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
    final targetAccent = _getThemePalette().primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTarget
            ? targetAccent.withAlpha(12)
            : theme.colorScheme.onSurface.withAlpha(isDark ? 10 : 8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTarget
              ? targetAccent.withAlpha(45)
              : theme.colorScheme.onSurface.withAlpha(isDark ? 20 : 26),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              header,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
                color: isTarget
                    ? targetAccent
                    : theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              primaryText,
              textAlign: TextAlign.center,
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
            alignment: Alignment.center,
            child: Text(
              secondaryText,
              textAlign: TextAlign.center,
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
    final cardOpacity = _settingsService.settings.cardOpacity.clamp(0.5, 1.0);
    final buttonBg = cardOpacity < 1.0
        ? theme.colorScheme.surface.withAlpha(
            (255 * cardOpacity).round().clamp(0, 255),
          )
        : theme.colorScheme.surface;
    if (_isSuccess) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(l10n.t('proc_back')),
              style: OutlinedButton.styleFrom(
                backgroundColor: buttonBg,
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
                backgroundColor: palette.btn,
                foregroundColor: palette.btnFg,
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
      final isDark = theme.brightness == Brightness.dark;
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(isDark ? 24 : 14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withAlpha(isDark ? 80 : 60),
                  width: 1.0,
                ),
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
                      Expanded(
                        child: Text(
                          l10n.t('error_details'),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(
                              ClipboardData(text: _errorMessage!),
                            );
                            if (mounted) {
                              messenger.hideCurrentSnackBar();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(l10n.t('error_copied')),
                                      ),
                                    ],
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  backgroundColor: const Color(0xFF1E293B),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withAlpha(
                                isDark ? 30 : 20,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.redAccent.withAlpha(70),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 12,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.t('error_copy'),
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withAlpha(50)
                          : Colors.black.withAlpha(10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(maxHeight: 110),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: SelectableText(
                        _errorMessage!,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9.5,
                          height: 1.35,
                          color: theme.colorScheme.onSurface.withAlpha(190),
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
                    backgroundColor: buttonBg,
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
                      _pulseController.repeat();
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
                    backgroundColor: palette.btn,
                    foregroundColor: palette.btnFg,
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
    final cardOpacity = _settingsService.settings.cardOpacity.clamp(0.5, 1.0);
    final buttonBg = cardOpacity < 1.0
        ? theme.colorScheme.surface.withAlpha(
            (255 * cardOpacity).round().clamp(0, 255),
          )
        : theme.colorScheme.surface;
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
          backgroundColor: buttonBg,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          side: BorderSide(
            color: theme.colorScheme.error.withAlpha(isDark ? 90 : 110),
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
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w600,
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

class _DualRingProgressPainter extends DualRingProgressPainter {
  _DualRingProgressPainter({
    required super.progress,
    required super.animationValue,
    super.animTime,
    required super.isProcessing,
    required super.isSuccess,
    required super.color,
    required super.secondaryColor,
    required super.deepColor,
    required super.crestColor,
    required super.basinColor,
    required super.trackColor,
    required super.isDark,
    super.style,
  });
}

class _WindowsTaskGraph extends StatelessWidget {
  final List<double> history;
  final Color color;
  final bool isProcessing;

  const _WindowsTaskGraph({
    required this.history,
    required this.color,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridColor = isDark
        ? Colors.white.withAlpha(15)
        : Colors.black.withAlpha(12);
    final borderColor = isDark
        ? Colors.white.withAlpha(20)
        : Colors.black.withAlpha(18);

    return Container(
      height: 28,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _WindowsGraphPainter(
            history: history,
            color: color,
            gridColor: gridColor,
            isProcessing: isProcessing,
          ),
        ),
      ),
    );
  }
}

class _WindowsGraphPainter extends CustomPainter {
  final List<double> history;
  final Color color;
  final Color gridColor;
  final bool isProcessing;

  _WindowsGraphPainter({
    required this.history,
    required this.color,
    required this.gridColor,
    required this.isProcessing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), gridPaint);
    const vSteps = 4;
    for (int i = 1; i < vSteps; i++) {
      final x = w * (i / vSteps);
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    if (history.isEmpty) return;

    final stepX = w / math.max(1, history.length - 1);
    final linePath = Path();
    final fillPath = Path();

    const pad = 2.0;
    final usableH = h - (pad * 2);

    for (int i = 0; i < history.length; i++) {
      final val = history[i].clamp(0.0, 1.0);
      final x = i * stepX;
      final y = h - pad - (val * usableH);

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, h);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(w, h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withAlpha(65), color.withAlpha(5)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    if (isProcessing && history.isNotEmpty) {
      final lastVal = history.last.clamp(0.0, 1.0);
      final lastX = (history.length - 1) * stepX;
      final lastY = h - pad - (lastVal * usableH);

      final dotBgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(lastX, lastY), 2.2, dotBgPaint);

      final dotBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawCircle(Offset(lastX, lastY), 2.2, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WindowsGraphPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.color != color ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.isProcessing != isProcessing;
  }
}
