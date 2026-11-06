import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/app_settings.dart';
import '../models/encoding_options.dart';
import 'localization_service.dart';
import 'device_spec_helper.dart';

class SettingsService extends ChangeNotifier {
  static const _storageKey = 'phantek_video_toolkit_app_settings';
  static const _encodingOptionsKey = 'phantek_vega_saved_encoding_options';
  static const _progressPreviewKey = 'phantek_vega_progress_preview_percentage';

  AppSettings _settings = const AppSettings();
  EncodingOptions? _savedEncodingOptions;
  double _progressPreviewPercentage = 0.80;
  bool _isLoaded = false;

  AppSettings get settings => _settings;
  EncodingOptions? get savedEncodingOptions => _savedEncodingOptions;
  double get progressPreviewPercentage => _progressPreviewPercentage;
  bool get isLoaded => _isLoaded;

  AppLocalizations get l10n => AppLocalizations(_settings.languageCode);

  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        _settings = AppSettings.fromJson(data);
      } else {
        _settings = const AppSettings();
      }

      if (_settings.isFirstLaunch) {
        await _applyFirstLaunchDefaults();
      }

      final encStr = prefs.getString(_encodingOptionsKey);
      if (encStr != null) {
        try {
          final Map<String, dynamic> encData = jsonDecode(encStr);
          _savedEncodingOptions = EncodingOptions.fromJson(encData);
        } catch (e) {
          debugPrint('Error loading saved encoding options: $e');
        }
      }

      _progressPreviewPercentage =
          prefs.getDouble(_progressPreviewKey) ?? 0.80;

      await _applyWakelock(_settings.keepScreenAwake);
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Resolves theme from brightness ('oled_pure' or 'light_clean').
  static String resolveInitialTheme([Brightness? brightness]) {
    if (brightness != null) {
      return brightness == Brightness.light ? 'light_clean' : 'oled_pure';
    }
    try {
      final platformBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return platformBrightness == Brightness.light
          ? 'light_clean'
          : 'oled_pure';
    } catch (_) {
      return 'oled_pure';
    }
  }

  /// Resolves language from system locales with 'en' fallback.
  static String resolveInitialLanguage([List<Locale>? locales]) {
    return AppLocalizations.resolveSupportedLanguage(locales);
  }

  Future<void> _applyFirstLaunchDefaults() async {
    final tier = DeviceSpecHelper.getDeviceTier();

    String preset = 'medium';
    if (tier == DeviceTier.highEnd) preset = 'medium';
    if (tier == DeviceTier.lowEnd) preset = 'fast';

    final initialTheme = resolveInitialTheme();
    final initialLang = resolveInitialLanguage();

    _settings = _settings.copyWith(
      isFirstLaunch: false,
      encodingPreset: preset,
      cpuThreads: 0, // Auto
      themeMode: initialTheme,
      languageCode: initialLang,
    );
    await _saveSettings();
  }

  Future<void> _applyWakelock(bool enable) async {
    try {
      await WakelockPlus.toggle(enable: enable);
    } on PlatformException catch (e) {
      if (e.code != 'channel-error') {
        debugPrint('Error toggling wakelock: $e');
      }
    } catch (e) {
      debugPrint('Error toggling wakelock: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_settings.toJson());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    final oldWakelock = _settings.keepScreenAwake;
    _settings = newSettings;
    notifyListeners();
    await _saveSettings();

    if (oldWakelock != newSettings.keepScreenAwake) {
      await _applyWakelock(newSettings.keepScreenAwake);
    }
  }

  Future<void> setLanguage(String languageCode) async {
    await updateSettings(_settings.copyWith(languageCode: languageCode));
  }

  Future<void> setThemeMode(String themeMode) async {
    await updateSettings(_settings.copyWith(themeMode: themeMode));
  }

  Future<void> setKeepScreenAwake(bool enable) async {
    await updateSettings(_settings.copyWith(keepScreenAwake: enable));
  }

  Future<void> setCpuThreads(int threads) async {
    await updateSettings(_settings.copyWith(cpuThreads: threads));
  }

  Future<void> setEncodingPreset(String preset) async {
    await updateSettings(_settings.copyWith(encodingPreset: preset));
  }

  Future<void> setAudioBitrate(int kbps) async {
    await updateSettings(_settings.copyWith(audioBitrateKbps: kbps));
  }

  Future<void> setOutputDirectory(String path) async {
    await updateSettings(_settings.copyWith(outputDirectory: path.trim()));
  }

  Future<void> setAudioOutputDirectory(String path) async {
    await updateSettings(_settings.copyWith(audioOutputDirectory: path.trim()));
  }

  Future<void> setCardOpacity(double opacity) async {
    final clamped = opacity.clamp(0.5, 1.0);
    await updateSettings(_settings.copyWith(cardOpacity: clamped));
  }

  Future<void> setDefaultVideoCodec(String codec) async {
    await updateSettings(_settings.copyWith(defaultVideoCodec: codec));
  }

  Future<void> setFileNamingFormat(String format) async {
    await updateSettings(_settings.copyWith(fileNamingFormat: format));
  }

  Future<void> setPreserveMediaDate(bool preserve) async {
    await updateSettings(_settings.copyWith(preserveMediaDate: preserve));
  }

  Future<void> setSuppressAdvancedModeWarning(bool value) async {
    await updateSettings(_settings.copyWith(suppressAdvancedModeWarning: value));
  }

  Future<void> setTranscodeEngine(String engine) async {
    await updateSettings(
      _settings.copyWith(
        transcodeEngine: AppSettings.sanitizeTranscodeEngine(engine),
      ),
    );
  }

  Future<void> setEnableEngineFallback(bool enable) async {
    await updateSettings(_settings.copyWith(enableEngineFallback: enable));
  }

  Future<void> setVideoProgressStyle(String style) async {
    await updateSettings(
      _settings.copyWith(
        videoProgressStyle: AppSettings.sanitizeProgressStyle(style),
      ),
    );
  }

  Future<void> setAudioProgressStyle(String style) async {
    await updateSettings(
      _settings.copyWith(
        audioProgressStyle: AppSettings.sanitizeProgressStyle(style),
      ),
    );
  }

  Future<void> setBothProgressStyles(String style) async {
    final sanitized = AppSettings.sanitizeProgressStyle(style);
    await updateSettings(
      _settings.copyWith(
        videoProgressStyle: sanitized,
        audioProgressStyle: sanitized,
      ),
    );
  }

  Future<void> setProgressPreviewPercentage(double val) async {
    _progressPreviewPercentage = val.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_progressPreviewKey, _progressPreviewPercentage);
    } catch (e) {
      debugPrint('Error saving progress preview percentage: $e');
    }
  }

  void setCardOpacityFast(double opacity) {
    final clamped = opacity.clamp(0.5, 1.0);
    if ((_settings.cardOpacity - clamped).abs() > 0.001) {
      _settings = _settings.copyWith(cardOpacity: clamped);
      notifyListeners();
    }
  }

  Future<void> saveEncodingOptions(EncodingOptions options) async {
    _savedEncodingOptions = options;
    _settings = _settings.copyWith(
      encodingPreset: options.speedPreset.encodingPresetName,
      defaultVideoCodec: options.codec.name,
    );
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_encodingOptionsKey, jsonEncode(options.toJson()));
      await _saveSettings();
    } catch (e) {
      debugPrint('Error saving encoding options: $e');
    }
  }

  Future<void> resetEncodingConfigurationToDefaults() async {
    const defaultOptions = EncodingOptions(
      speedPreset: SpeedPreset.normal,
      codec: VideoCodec.h264,
      container: VideoContainer.mp4,
      rateControlMode: RateControlMode.crf,
      crfValue: 22,
      customBitrateKbps: 4000,
      targetFps: 0,
      videoAudioBitrateKbps: 128,
    );
    await saveEncodingOptions(defaultOptions);
  }

  Future<void> resetToDefaults() async {
    final currentLang = _settings.languageCode;
    final initialTheme = resolveInitialTheme();
    _settings = AppSettings(languageCode: currentLang, themeMode: initialTheme);
    notifyListeners();
    await _saveSettings();
    await _applyWakelock(_settings.keepScreenAwake);
    await resetEncodingConfigurationToDefaults();
  }

  // Active job marker for crash recovery

  static const _jobMarkerKey = 'active_conversion_job_marker';

  Future<void> saveJobMarker({
    required String inputPath,
    required String outputPath,
    required int allocatedThreads,
    required bool is4K,
    int retryCount = 0,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'allocatedThreads': allocatedThreads,
        'is4K': is4K,
        'retryCount': retryCount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_jobMarkerKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving job marker: $e');
    }
  }

  Future<Map<String, dynamic>?> getJobMarker() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_jobMarkerKey);
      if (str != null) {
        return jsonDecode(str) as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('Error reading job marker: $e');
    }
    return null;
  }

  Future<void> clearJobMarker() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_jobMarkerKey);
    } catch (e) {
      debugPrint('Error clearing job marker: $e');
    }
  }
}
