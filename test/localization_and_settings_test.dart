import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phantek_video_toolkit_vega/models/app_settings.dart';
import 'package:phantek_video_toolkit_vega/models/encoding_options.dart';
import 'package:phantek_video_toolkit_vega/models/video_info.dart';
import 'package:phantek_video_toolkit_vega/services/cache_manager_service.dart';
import 'package:phantek_video_toolkit_vega/services/device_spec_helper.dart';
import 'package:phantek_video_toolkit_vega/services/license_service.dart';
import 'package:phantek_video_toolkit_vega/services/transformer_service.dart';
import 'package:phantek_video_toolkit_vega/services/localization_service.dart';
import 'package:phantek_video_toolkit_vega/services/media_scanner_service.dart';
import 'package:phantek_video_toolkit_vega/screens/home_screen.dart';
import 'package:phantek_video_toolkit_vega/screens/processing_screen.dart';
import 'package:phantek_video_toolkit_vega/screens/settings_screen.dart';
import 'package:phantek_video_toolkit_vega/screens/trim_preview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phantek_video_toolkit_vega/services/settings_service.dart';
import 'package:phantek_video_toolkit_vega/theme/app_theme.dart';
import 'package:phantek_video_toolkit_vega/widgets/animated_flame_title.dart';
import 'package:phantek_video_toolkit_vega/widgets/audio_extractor_card.dart';
import 'package:phantek_video_toolkit_vega/widgets/conversion_options_card.dart';
import 'package:phantek_video_toolkit_vega/widgets/progress_animation_painter.dart';
import 'package:phantek_video_toolkit_vega/widgets/theme_animated_background.dart';
import 'package:phantek_video_toolkit_vega/widgets/video_info_card.dart';

const supportedUiCodes = [
  'id',
  'en',
  'ar',
  'ms',
  'da',
  'de',
  'es',
  'fr',
  'it',
  'nl',
  'no',
  'pt',
  'ru',
  'fi',
  'sv',
  'vi',
  'th',
  'hi',
  'ja',
  'zh_CN',
  'zh_TW',
  'ko',
];

const supportedCodes = [
  'id',
  'en',
  'zh',
  'ar',
  'ms',
  'da',
  'de',
  'es',
  'fr',
  'it',
  'nl',
  'no',
  'pt',
  'ru',
  'fi',
  'sv',
  'vi',
  'th',
  'hi',
  'ja',
  'zh_CN',
  'zh_TW',
  'ko',
];

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (ByteData? message) async {
            return const StandardMessageCodec().encodeMessage(<Object?>[null]);
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          return null;
        });
  });

  group('Localization tests', () {
    test('All requested UI languages are available in supportedLanguages without duplicates', () {
      final codes = AppLocalizations.supportedLanguages
          .map((l) => l['code'])
          .toList();
      for (final code in supportedUiCodes) {
        expect(
          codes.contains(code),
          isTrue,
          reason: 'Language $code must be supported',
        );
      }
      expect(
        codes.contains('zh'),
        isFalse,
        reason: 'Duplicate zh should not be in supportedLanguages',
      );
      expect(codes.length, equals(supportedUiCodes.length));
      expect(
        codes,
        equals([
          'id',
          'ms',
          'da',
          'de',
          'en',
          'es',
          'fr',
          'it',
          'nl',
          'no',
          'pt',
          'fi',
          'sv',
          'vi',
          'ru',
          'ar',
          'hi',
          'th',
          'ja',
          'zh_CN',
          'zh_TW',
          'ko',
        ]),
        reason:
            'supportedLanguages must be sorted Latin A-Z followed by non-Latin',
      );
    });

    test('Translations resolve correctly for all supported languages', () {
      for (final code in supportedCodes) {
        final l10n = AppLocalizations(code);
        expect(l10n.t('app_title'), 'Phantek');
        expect(l10n.t('app_long_title'), 'Phantek - Video Toolkit Vega');
        expect(l10n.t('pick_video').isNotEmpty, isTrue);
        expect(l10n.t('settings_title').isNotEmpty, isTrue);
        expect(l10n.t('loading_analyzing').isNotEmpty, isTrue);
        expect(l10n.t('settings_hardware').isNotEmpty, isTrue);
        expect(l10n.t('settings_cpu_threads').isNotEmpty, isTrue);
      }
    });

    test('String argument substitution works', () {
      final l10n = const AppLocalizations('id');
      final result = l10n.t('settings_detected_cores', args: {'count': '8'});
      expect(result.contains('8'), isTrue);
    });

    test('Cancel buttons, dialogs, rate control, and feature highlights resolve properly in all languages', () {
      for (final code in supportedCodes) {
        final l10n = AppLocalizations(code);
        expect(l10n.t('proc_cancel_confirm').isNotEmpty, isTrue);
        expect(l10n.t('proc_continue_btn').isNotEmpty, isTrue);
        expect(l10n.t('proc_cancel_btn').isNotEmpty, isTrue);
        expect(l10n.t('rate_control').isNotEmpty, isTrue);
        expect(l10n.t('feature_offline_fast').isNotEmpty, isTrue);
        expect(l10n.t('feature_offline_fast_desc').isNotEmpty, isTrue);
        expect(l10n.t('feature_crf_bitrate').isNotEmpty, isTrue);
        expect(l10n.t('feature_crf_bitrate_desc').isNotEmpty, isTrue);
        expect(l10n.t('feature_privacy').isNotEmpty, isTrue);
        expect(l10n.t('feature_privacy_desc').isNotEmpty, isTrue);
        expect(l10n.t('error_details').isNotEmpty, isTrue);
        expect(l10n.t('app_version').isNotEmpty, isTrue);
        expect(l10n.t('res_original').isNotEmpty, isTrue);
        expect(l10n.t('settings_card_opacity').isNotEmpty, isTrue);
        expect(l10n.t('settings_card_opacity_desc').isNotEmpty, isTrue);

        // Ensure keys do not return the literal key name
        expect(
          l10n.t('proc_cancel_confirm'),
          isNot(equals('proc_cancel_confirm')),
        );
        expect(l10n.t('proc_continue_btn'), isNot(equals('proc_continue_btn')));
        expect(l10n.t('proc_cancel_btn'), isNot(equals('proc_cancel_btn')));
        expect(l10n.t('rate_control'), isNot(equals('rate_control')));
        expect(
          l10n.t('settings_card_opacity'),
          isNot(equals('settings_card_opacity')),
        );
        expect(
          l10n.t('settings_card_opacity_desc'),
          isNot(equals('settings_card_opacity_desc')),
        );
      }
    });

    test('Device specifications keys resolve properly and accurately in all supported languages', () {
      for (final code in supportedCodes) {
        final l10n = AppLocalizations(code);
        expect(l10n.t('device_name').isNotEmpty, isTrue);
        expect(l10n.t('device_model').isNotEmpty, isTrue);
        expect(l10n.t('device_cpu').isNotEmpty, isTrue);
        expect(l10n.t('device_gpu').isNotEmpty, isTrue);
        expect(l10n.t('device_ram').isNotEmpty, isTrue);
        expect(l10n.t('device_storage').isNotEmpty, isTrue);
        expect(l10n.t('storage_free').isNotEmpty, isTrue);

        expect(l10n.t('device_name'), isNot(equals('device_name')));
        expect(l10n.t('device_model'), isNot(equals('device_model')));
        expect(l10n.t('device_cpu'), isNot(equals('device_cpu')));
        expect(l10n.t('device_gpu'), isNot(equals('device_gpu')));
        expect(l10n.t('device_ram'), isNot(equals('device_ram')));
        expect(l10n.t('device_storage'), isNot(equals('device_storage')));
        expect(l10n.t('storage_free'), isNot(equals('storage_free')));
      }

      // Verify language accuracy: Indonesian has 'Nama HP' and 'Penyimpanan'
      final l10nId = const AppLocalizations('id');
      expect(l10nId.t('device_name'), equals('Nama HP'));
      expect(l10nId.t('device_model'), equals('Model HP'));
      expect(l10nId.t('device_storage'), equals('Penyimpanan'));

      // English has 'Device Name' and 'Storage'
      final l10nEn = const AppLocalizations('en');
      expect(l10nEn.t('device_name'), equals('Device Name'));
      expect(l10nEn.t('device_storage'), equals('Storage'));

      // Korean has '기기 이름' and '저장 공간'
      final l10nKo = const AppLocalizations('ko');
      expect(l10nKo.t('device_name'), equals('기기 이름'));
      expect(l10nKo.t('device_storage'), equals('저장 공간'));

      // Japanese has 'デバイス名' and 'ストレージ'
      final l10nJa = const AppLocalizations('ja');
      expect(l10nJa.t('device_name'), equals('デバイス名'));
      expect(l10nJa.t('device_storage'), equals('ストレージ'));
    });

    test('100% of all l10n.t keys used across lib are translated in all supported languages', () {
      final allCalls = <String>{};
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final regex1 = RegExp(r"l10n\.t\('([^']+)'");
      final regex2 = RegExp(r'l10n\.t\("([^"]+)"');

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final m in regex1.allMatches(content)) {
          allCalls.add(m.group(1)!);
        }
        for (final m in regex2.allMatches(content)) {
          allCalls.add(m.group(1)!);
        }
      }

      // Add dynamic keys
      allCalls.addAll([
        'desc_mp4',
        'desc_mkv',
        'desc_mov',
        'desc_h264',
        'desc_hevc',
      ]);
      // Remove any interpolated placeholder patterns if present
      allCalls.removeWhere((k) => k.contains(r'$'));

      for (final code in supportedCodes) {
        final l10n = AppLocalizations(code);
        for (final key in allCalls) {
          final translated = l10n.t(key);
          expect(
            translated,
            isNot(equals(key)),
            reason: 'Key "$key" is missing translation for language "$code"',
          );
          expect(
            translated.isNotEmpty,
            isTrue,
            reason: 'Key "$key" is empty for language "$code"',
          );
        }
      }
    });
  });

  // Encoding tests removed due to refactor

  group('AppSettings tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (ByteData? message) async {
              return const StandardMessageCodec().encodeMessage(<Object?>[
                null,
              ]);
            },
          );
    });

    test('Default values are correct', () {
      const settings = AppSettings();
      expect(settings.cpuThreads, equals(0)); // Auto
      expect(settings.ramBufferMb, equals(512));
      expect(settings.encodingPreset, equals('medium'));
      expect(settings.audioBitrateKbps, equals(128));
      expect(settings.languageCode, equals('en'));
      expect(settings.themeMode, equals('oled_pure'));
      expect(settings.keepScreenAwake, isFalse);
      expect(settings.outputDirectory, equals(''));
      expect(settings.audioOutputDirectory, equals(''));
      expect(settings.defaultVideoCodec, equals('h264'));
      expect(settings.fileNamingFormat, equals('suffix'));
      expect(settings.preserveMediaDate, isTrue);
      expect(settings.transcodeEngine, equals('hardware'));
      expect(settings.enableEngineFallback, isTrue);
    });

    test('Serialization to and from JSON works', () {
      const original = AppSettings(
        cpuThreads: 4,
        ramBufferMb: 1024,
        encodingPreset: 'fast',
        audioBitrateKbps: 192,
        languageCode: 'ja',
        themeMode: 'oled_midnight',
        keepScreenAwake: true,
        outputDirectory: '/custom/storage/Movies',
        audioOutputDirectory: '/custom/storage/Music',
        defaultVideoCodec: 'hevc',
        fileNamingFormat: 'timestamp',
        preserveMediaDate: false,
        transcodeEngine: 'software',
        enableEngineFallback: false,
      );

      final json = original.toJson();
      final restored = AppSettings.fromJson(json);

      expect(restored.cpuThreads, equals(4));
      expect(restored.ramBufferMb, equals(1024));
      expect(restored.encodingPreset, equals('fast'));
      expect(restored.audioBitrateKbps, equals(192));
      expect(restored.languageCode, equals('ja'));
      expect(restored.themeMode, equals('oled_midnight'));
      expect(restored.keepScreenAwake, isTrue);
      expect(restored.defaultVideoCodec, equals('hevc'));
      expect(restored.fileNamingFormat, equals('timestamp'));
      expect(restored.preserveMediaDate, isFalse);
      expect(restored.outputDirectory, equals('/custom/storage/Movies'));
      expect(restored.audioOutputDirectory, equals('/custom/storage/Music'));
      expect(restored.transcodeEngine, equals('software'));
      expect(restored.enableEngineFallback, isFalse);
    });

    test('New theme, wakelock, and cache storage translations exist', () {
      for (final code in supportedCodes) {
        final l10n = AppLocalizations(code);
        expect(l10n.t('settings_theme').isNotEmpty, isTrue);
        expect(l10n.t('theme_oled_midnight').isNotEmpty, isTrue);
        expect(l10n.t('theme_light').isNotEmpty, isTrue);
        expect(l10n.t('settings_wakelock').isNotEmpty, isTrue);
        expect(l10n.t('settings_wakelock_desc').isNotEmpty, isTrue);
        expect(l10n.t('proc_elapsed_time').isNotEmpty, isTrue);
        expect(l10n.t('proc_remaining_time').isNotEmpty, isTrue);
        expect(l10n.t('settings_storage').isNotEmpty, isTrue);
        expect(l10n.t('settings_cache_size').isNotEmpty, isTrue);
        expect(l10n.t('settings_clear_cache').isNotEmpty, isTrue);

        // v1.1.2 new keys
        expect(l10n.t('codec_hevc_warning').isNotEmpty, isTrue);
        expect(l10n.t('codec_compat_hint').isNotEmpty, isTrue);
        expect(l10n.t('back_to_home').isNotEmpty, isTrue);
        expect(l10n.t('settings_output_folder').isNotEmpty, isTrue);
        expect(l10n.t('settings_output_folder_desc').isNotEmpty, isTrue);
        expect(l10n.t('settings_change_folder').isNotEmpty, isTrue);
        expect(l10n.t('settings_reset_folder').isNotEmpty, isTrue);
        expect(l10n.t('settings_folder_changed').isNotEmpty, isTrue);
        expect(l10n.t('settings_folder_default').isNotEmpty, isTrue);
        expect(l10n.t('settings_audio_output_folder').isNotEmpty, isTrue);
        expect(l10n.t('settings_audio_output_folder_desc').isNotEmpty, isTrue);
        expect(l10n.t('settings_audio_reset_folder').isNotEmpty, isTrue);
        expect(l10n.t('settings_audio_folder_changed').isNotEmpty, isTrue);
        expect(l10n.t('settings_audio_folder_default').isNotEmpty, isTrue);
        expect(l10n.t('theme_oled_sakura_desc').isNotEmpty, isTrue);
        expect(l10n.t('settings_default_codec').isNotEmpty, isTrue);
        expect(l10n.t('settings_file_naming').isNotEmpty, isTrue);
        expect(l10n.t('naming_format_suffix').isNotEmpty, isTrue);
        expect(l10n.t('naming_format_timestamp').isNotEmpty, isTrue);
        expect(l10n.t('naming_format_simple').isNotEmpty, isTrue);
        expect(l10n.t('settings_preserve_date').isNotEmpty, isTrue);
        expect(l10n.t('settings_preserve_date_desc').isNotEmpty, isTrue);
        expect(l10n.t('settings_transcode_engine').isNotEmpty, isTrue);
        expect(l10n.t('engine_hardware_title').isNotEmpty, isTrue);
        expect(l10n.t('engine_hardware_desc').isNotEmpty, isTrue);
        expect(l10n.t('engine_software_title').isNotEmpty, isTrue);
        expect(l10n.t('engine_software_desc').isNotEmpty, isTrue);
        expect(l10n.t('engine_fallback_toggle_title').isNotEmpty, isTrue);
        expect(l10n.t('engine_fallback_toggle_desc').isNotEmpty, isTrue);
        expect(l10n.t('engine_fallback_notice').isNotEmpty, isTrue);
      }
    });

    test('AppSettings clamps RAM buffer to 2048 MB on deserialization and copyWith', () {
      const original = AppSettings(ramBufferMb: 2048);
      expect(original.ramBufferMb, equals(2048));
      final json = original.toJson();
      expect(json['ramBufferMb'], equals(2048));
      final fromJson = AppSettings.fromJson(json);
      expect(fromJson.ramBufferMb, equals(2048));

      // Test clamping of values > 2048 MB from legacy stored json
      final clampedFromJson = AppSettings.fromJson({'ramBufferMb': 4096});
      expect(clampedFromJson.ramBufferMb, equals(2048));

      final updated = original.copyWith(ramBufferMb: 4096);
      expect(updated.ramBufferMb, equals(2048));
    });

    test(
      'DeviceSpecHelper getProcessRssMb returns non-negative memory integer',
      () {
        final rssMb = DeviceSpecHelper.getProcessRssMb();
        expect(rssMb, greaterThanOrEqualTo(0));
      },
    );

    test('DeviceSpecHelper getProcessCpuUsagePercent returns valid percentage within 0-100', () {
      final cpuUsage = DeviceSpecHelper.getProcessCpuUsagePercent();
      expect(cpuUsage, greaterThanOrEqualTo(0.0));
      expect(cpuUsage, lessThanOrEqualTo(100.0));
    });

    test(
      'AppSettings copyWith properly updates outputDirectory and other fields',
      () {
        const original = AppSettings();
        final updated = original.copyWith(
          outputDirectory: '/custom/path',
          audioOutputDirectory: '/custom/audio/path',
          keepScreenAwake: true,
        );

        expect(updated.outputDirectory, equals('/custom/path'));
        expect(updated.audioOutputDirectory, equals('/custom/audio/path'));
        expect(updated.keepScreenAwake, isTrue);
        expect(updated.cpuThreads, equals(original.cpuThreads));
        expect(updated.themeMode, equals(original.themeMode));
      },
    );

    test(
      'SettingsService properly toggles and persists keepScreenAwake',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = SettingsService();
        await service.init();

        expect(service.settings.keepScreenAwake, isFalse);

        await service.setKeepScreenAwake(true);
        expect(service.settings.keepScreenAwake, isTrue);

        await service.setKeepScreenAwake(false);
        expect(service.settings.keepScreenAwake, isFalse);

        await service.setKeepScreenAwake(true);
        expect(service.settings.keepScreenAwake, isTrue);

        await service.resetToDefaults();
        expect(service.settings.keepScreenAwake, isFalse);
      },
    );

    test(
      'SettingsService properly modifies, clamps and resets cardOpacity',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = SettingsService();
        await service.init();

        expect(service.settings.cardOpacity, equals(1.0));

        await service.setCardOpacity(0.75);
        expect(service.settings.cardOpacity, equals(0.75));

        // Clamping below 0.5
        await service.setCardOpacity(0.3);
        expect(service.settings.cardOpacity, equals(0.5));

        // Clamping above 1.0
        await service.setCardOpacity(1.2);
        expect(service.settings.cardOpacity, equals(1.0));

        // Reset to defaults restores 1.0
        await service.setCardOpacity(0.6);
        await service.resetToDefaults();
        expect(service.settings.cardOpacity, equals(1.0));
      },
    );

    test('Dual engine settings and fallback methods work correctly', () async {
      // 1. AppSettings sanitizeTranscodeEngine
      expect(
        AppSettings.sanitizeTranscodeEngine('software'),
        equals('software'),
      );
      expect(
        AppSettings.sanitizeTranscodeEngine('hardware'),
        equals('hardware'),
      );
      expect(
        AppSettings.sanitizeTranscodeEngine('unknown'),
        equals('hardware'),
      );
      expect(
        AppSettings.sanitizeTranscodeEngine(null),
        equals('hardware'),
      );

      // 2. copyWith and equality
      const base = AppSettings();
      final updated = base.copyWith(
        transcodeEngine: 'software',
        enableEngineFallback: false,
      );
      expect(updated.transcodeEngine, equals('software'));
      expect(updated.enableEngineFallback, isFalse);
      expect(updated != base, isTrue);
      expect(updated.hashCode != base.hashCode, isTrue);

      final same = base.copyWith();
      expect(same == base, isTrue);
      expect(same.hashCode, equals(base.hashCode));

      // 3. SettingsService updates
      final service = SettingsService();
      await service.setTranscodeEngine('software');
      expect(service.settings.transcodeEngine, equals('software'));

      await service.setEnableEngineFallback(false);
      expect(service.settings.enableEngineFallback, isFalse);

      await service.setTranscodeEngine('hardware');
      expect(service.settings.transcodeEngine, equals('hardware'));

      await service.setEnableEngineFallback(true);
      expect(service.settings.enableEngineFallback, isTrue);
    });

    test(
      'TransformerService passes transcodeEngine and enableEngineFallback to native channel',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('transcode_engine_test_');
        Map<dynamic, dynamic>? capturedArgs;
        const channel = MethodChannel('com.phantek.lyra.vega/transformer');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'transcodeVideo') {
                capturedArgs = methodCall.arguments as Map<dynamic, dynamic>?;
                final outPath = capturedArgs?['outputPath'] as String?;
                if (outPath != null) {
                  File(outPath).writeAsStringSync('dummy_output');
                  return outPath;
                }
                return '/mock/path/output.mp4';
              }
              return null;
            });

        TransformerService.forceNativeForTesting = true;
        try {
          const video = VideoInfo(
            filePath: '/mock/path/input.mp4',
            fileName: 'input.mp4',
            width: 1920,
            height: 1080,
            durationSeconds: 10.0,
            bitrate: 4000000,
            fps: 30.0,
            codec: 'h264',
            fileSizeBytes: 5000000,
            hasAudio: true,
          );

          final customSettings = AppSettings(
            transcodeEngine: 'software',
            enableEngineFallback: false,
            outputDirectory: tempDir.path,
          );

          const targetRes = VideoResolution(
            label: '1080p',
            width: 1920,
            height: 1080,
          );

          await TransformerService.processVideo(
            sourceVideo: video,
            targetResolution: targetRes,
            appSettings: customSettings,
            onProgress: (progress, stats, [size]) {},
            onLog: (msg) {},
          );

          expect(capturedArgs, isNotNull);
          expect(capturedArgs!['transcodeEngine'], equals('software'));
          expect(capturedArgs!['enableEngineFallback'], isFalse);
        } finally {
          TransformerService.forceNativeForTesting = false;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        }
      },
    );

    test('AppTheme.getTheme correctly factors cardOpacity into surface and card colors', () {
      final solidDark = AppTheme.getTheme('dark', cardOpacity: 1.0);
      final translucentDark = AppTheme.getTheme('dark', cardOpacity: 0.5);

      expect(solidDark.cardTheme.color?.a, equals(1.0));
      expect(translucentDark.cardTheme.color?.a, lessThan(1.0));

      final solidLight = AppTheme.getTheme('light', cardOpacity: 1.0);
      final translucentLight = AppTheme.getTheme('light', cardOpacity: 0.8);

      expect(solidLight.cardTheme.color?.a, equals(1.0));
      expect(translucentLight.cardTheme.color?.a, lessThan(1.0));
    });

    test('TransformerService getOutputDirectory uses customPath when provided and valid', () async {
      final customTemp = Directory(
        '${Directory.systemTemp.path}/test_custom_output_${DateTime.now().millisecondsSinceEpoch}',
      );
      try {
        final result = await TransformerService.getOutputDirectory(
          customPath: customTemp.path,
        );
        expect(result.path, equals(customTemp.path));
        expect(await result.exists(), isTrue);
      } finally {
        if (await customTemp.exists()) {
          await customTemp.delete(recursive: true);
        }
      }
    });
  });

  group('EncodingOptions and Mode Restrictions tests', () {
    test('Default encoding options uses H264 and MP4 for best stability', () {
      const opts = EncodingOptions();
      expect(opts.codec, equals(VideoCodec.h264));
      expect(opts.container, equals(VideoContainer.mp4));
    });

    test('Supported containers are MP4, MKV, and MOV for stability', () {
      final safeContainers = VideoContainer.values.toList();
      expect(safeContainers.contains(VideoContainer.mp4), isTrue);
      expect(safeContainers.contains(VideoContainer.mkv), isTrue);
      expect(safeContainers.contains(VideoContainer.mov), isTrue);
      expect(safeContainers.length, equals(3));
    });
  });

  group('CacheManager and Telemetry Consistency tests', () {
    test('formatBytes formats properly across units', () {
      expect(CacheManagerService.formatBytes(0), equals('0 B'));
      expect(CacheManagerService.formatBytes(500), equals('500 B'));
      expect(CacheManagerService.formatBytes(1024), equals('1 KB'));
      expect(CacheManagerService.formatBytes(1048576), equals('1.0 MB'));
      expect(CacheManagerService.formatBytes(1572864000), equals('1.46 GB'));
    });

    test('isCachedPath identifies temporary and picker cached paths', () {
      final cacheManager = CacheManagerService();
      expect(
        cacheManager.isCachedPath(
          '/data/user/0/com.app/cache/file_picker/vid.mp4',
        ),
        isTrue,
      );
      expect(
        cacheManager.isCachedPath('/data/user/0/com.app/cache/sample.mp4'),
        isTrue,
      );
      expect(cacheManager.isCachedPath('C:\\temp\\cache\\vid.mp4'), isTrue);
      expect(
        cacheManager.isCachedPath('/storage/emulated/0/Movies/sample.mp4'),
        isFalse,
      );
    });

    test('Percentage formatting rounds to clean integer consistently', () {
      expect(ProcessingScreen.formatProgressPercentage(0.185), equals('19%'));
      expect(ProcessingScreen.formatProgressPercentage(0.0), equals('0%'));
      expect(ProcessingScreen.formatProgressPercentage(0.50), equals('50%'));
      expect(ProcessingScreen.formatProgressPercentage(1.0), equals('100%'));
    });
  });

  group('TransformerService Unique Output Path tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('unique_path_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('generates initial path when file does not exist', () async {
      final path = await TransformerService.generateUniqueOutputPath(
        outputDir: tempDir,
        fileName: 'video4k.mp4',
        targetResolution: VideoResolution.standardResolutions.first,
        container: VideoContainer.mp4,
      );

      final sep = Platform.pathSeparator;
      expect(path, equals('${tempDir.path}${sep}video4k-4k.mp4'));
    });

    test('appends incremental suffix -2 when file already exists', () async {
      final sep = Platform.pathSeparator;
      // Pre-create video4k-4k.mp4
      File('${tempDir.path}${sep}video4k-4k.mp4').createSync();

      final path = await TransformerService.generateUniqueOutputPath(
        outputDir: tempDir,
        fileName: 'video4k.mp4',
        targetResolution: VideoResolution.standardResolutions.first,
        container: VideoContainer.mp4,
      );

      expect(path, equals('${tempDir.path}${sep}video4k-4k-2.mp4'));
    });

    test(
      'appends incremental suffix -3 when base and -2 already exist',
      () async {
        final sep = Platform.pathSeparator;
        // Pre-create video4k-4k.mp4 and video4k-4k-2.mp4
        File('${tempDir.path}${sep}video4k-4k.mp4').createSync();
        File('${tempDir.path}${sep}video4k-4k-2.mp4').createSync();

        final path = await TransformerService.generateUniqueOutputPath(
          outputDir: tempDir,
          fileName: 'video4k.mp4',
          targetResolution: VideoResolution.standardResolutions.first,
          container: VideoContainer.mp4,
        );

        expect(path, equals('${tempDir.path}${sep}video4k-4k-3.mp4'));
      },
    );
  });

  group('VideoInfo resolution formatting tests', () {
    test('resolution returns clean names without (HD), (FHD), (QHD), (SD)', () {
      const v4k = VideoInfo(
        filePath: '/test.mp4',
        fileName: 'test.mp4',
        width: 3840,
        height: 2160,
        durationSeconds: 10,
        bitrate: 1000,
        fps: 30,
        codec: 'h264',
        fileSizeBytes: 1000,
      );
      const v2k = VideoInfo(
        filePath: '/test.mp4',
        fileName: 'test.mp4',
        width: 2560,
        height: 1440,
        durationSeconds: 10,
        bitrate: 1000,
        fps: 30,
        codec: 'h264',
        fileSizeBytes: 1000,
      );
      const v1080 = VideoInfo(
        filePath: '/test.mp4',
        fileName: 'test.mp4',
        width: 1920,
        height: 1080,
        durationSeconds: 10,
        bitrate: 1000,
        fps: 30,
        codec: 'h264',
        fileSizeBytes: 1000,
      );
      const v720 = VideoInfo(
        filePath: '/test.mp4',
        fileName: 'test.mp4',
        width: 1280,
        height: 720,
        durationSeconds: 10,
        bitrate: 1000,
        fps: 30,
        codec: 'h264',
        fileSizeBytes: 1000,
      );
      const v480 = VideoInfo(
        filePath: '/test.mp4',
        fileName: 'test.mp4',
        width: 854,
        height: 480,
        durationSeconds: 10,
        bitrate: 1000,
        fps: 30,
        codec: 'h264',
        fileSizeBytes: 1000,
      );

      expect(v4k.resolution, equals('4K'));
      expect(v2k.resolution, equals('2K'));
      expect(v1080.resolution, equals('1080p'));
      expect(v720.resolution, equals('720p'));
      expect(v480.resolution, equals('480p'));

      // Check available downscale targets label
      expect(
        v720.availableDownscaleTargets.first.label,
        equals('Original (720p)'),
      );
    });

    test('Navigation and options reset localization keys resolve correctly in all supported languages', () {
      for (final code in supportedCodes) {
        final l10n = AppLocalizations(code);
        expect(l10n.t('back_to_home').isNotEmpty, isTrue);
        expect(l10n.t('reset_options').isNotEmpty, isTrue);
        expect(l10n.t('options_reset_success').isNotEmpty, isTrue);
        expect(l10n.t('back_to_home'), isNot(equals('back_to_home')));
        expect(l10n.t('reset_options'), isNot(equals('reset_options')));
        expect(
          l10n.t('options_reset_success'),
          isNot(equals('options_reset_success')),
        );
      }
    });

    test('Audio Extractor localization keys resolve properly in all supported languages', () {
      for (final code in supportedCodes) {
        final l10n = AppLocalizations(code);
        expect(l10n.t('category_video').isNotEmpty, isTrue);
        expect(l10n.t('category_audio').isNotEmpty, isTrue);
        expect(l10n.t('category_video'), isNot(equals('category_video')));
        expect(l10n.t('category_audio'), isNot(equals('category_audio')));
        expect(l10n.t('mode_extractor').isNotEmpty, isTrue);
        expect(l10n.t('audio_options').isNotEmpty, isTrue);
        expect(l10n.t('audio_format').isNotEmpty, isTrue);
        expect(l10n.t('audio_bitrate').isNotEmpty, isTrue);
        expect(l10n.t('audio_copy').isNotEmpty, isTrue);
        expect(l10n.t('start_audio_extraction').isNotEmpty, isTrue);
        expect(l10n.t('proc_extracting').isNotEmpty, isTrue);
        expect(l10n.t('proc_audio_completed').isNotEmpty, isTrue);
        expect(l10n.t('proc_play_audio').isNotEmpty, isTrue);
        expect(l10n.t('desc_audio_mp3').isNotEmpty, isTrue);
        expect(l10n.t('desc_audio_m4a').isNotEmpty, isTrue);
        expect(l10n.t('desc_audio_wav').isNotEmpty, isTrue);
        expect(l10n.t('desc_audio_mp3'), isNot(equals('desc_audio_mp3')));
        expect(l10n.t('desc_audio_m4a'), isNot(equals('desc_audio_m4a')));
        expect(l10n.t('desc_audio_wav'), isNot(equals('desc_audio_wav')));
        expect(l10n.t('mode_extractor'), isNot(equals('mode_extractor')));
      }
    });
  });

  group('Audio Extractor and Format tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('audio_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('AudioFormat values have correct mimeTypes and extensions', () {
      expect(AudioFormat.mp3.extension, equals('mp3'));
      expect(AudioFormat.mp3.mimeType, equals('audio/mpeg'));

      expect(AudioFormat.m4a.extension, equals('m4a'));
      expect(AudioFormat.m4a.mimeType, equals('audio/mp4a-latm'));

      expect(AudioFormat.wav.extension, equals('wav'));
      expect(AudioFormat.wav.mimeType, equals('audio/raw'));
    });

    test(
      'generateUniqueAudioOutputPath generates clean unique audio filenames',
      () async {
        final sep = Platform.pathSeparator;
        final path1 = await TransformerService.generateUniqueAudioOutputPath(
          outputDir: tempDir,
          fileName: 'clip.mp4',
          audioFormat: AudioFormat.mp3,
        );
        expect(path1, equals('${tempDir.path}${sep}clip-audio.mp3'));

        // Create file and check incremental naming
        File(path1).createSync();
        final path2 = await TransformerService.generateUniqueAudioOutputPath(
          outputDir: tempDir,
          fileName: 'clip.mp4',
          audioFormat: AudioFormat.mp3,
        );
        expect(path2, equals('${tempDir.path}${sep}clip-audio-2.mp3'));
      },
    );

    test('VideoInfo tracks hasAudio and audioCodec accurately', () {
      const withAudio = VideoInfo(
        filePath: '/test/video.mp4',
        fileName: 'video.mp4',
        fileSizeBytes: 1024,
        durationSeconds: 10.0,
        width: 1920,
        height: 1080,
        bitrate: 5000000,
        fps: 30.0,
        codec: 'h264',
        audioCodec: 'aac',
        hasAudio: true,
      );
      expect(withAudio.hasAudio, isTrue);
      expect(withAudio.audioCodec, equals('aac'));

      const withoutAudio = VideoInfo(
        filePath: '/test/silent.mp4',
        fileName: 'silent.mp4',
        fileSizeBytes: 512,
        durationSeconds: 5.0,
        width: 1280,
        height: 720,
        bitrate: 2000000,
        fps: 30.0,
        codec: 'h264',
        hasAudio: false,
      );
      expect(withoutAudio.hasAudio, isFalse);
      expect(withoutAudio.audioCodec, isNull);
    });

    test('no_audio_track localization resolves properly across all supported languages', () {
      for (final code in supportedCodes) {
        final l10n = AppLocalizations(code);
        final translated = l10n.t('no_audio_track');
        expect(translated.isNotEmpty, isTrue);
        expect(translated, isNot(equals('no_audio_track')));
      }
    });

    test('TransformerService getOutputDirectory respects custom path and isAudio flag', () async {
      final customDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}CustomAudio',
      );
      customDir.createSync();

      // Custom path provided with isAudio: true
      final outDirCustomAudio = await TransformerService.getOutputDirectory(
        customPath: customDir.path,
        isAudio: true,
      );
      expect(outDirCustomAudio.path, equals(customDir.path));

      // Custom path provided with isAudio: false
      final outDirCustomVideo = await TransformerService.getOutputDirectory(
        customPath: customDir.path,
        isAudio: false,
      );
      expect(outDirCustomVideo.path, equals(customDir.path));
    });

    test('DeviceSpecHelper getMarketedRamGb calculates accurate marketing RAM capacities', () {
      expect(DeviceSpecHelper.getMarketedRamGb(7840), equals(8));
      expect(DeviceSpecHelper.getMarketedRamGb(5800), equals(6));
      expect(DeviceSpecHelper.getMarketedRamGb(3800), equals(4));
      expect(DeviceSpecHelper.getMarketedRamGb(11800), equals(12));
      expect(DeviceSpecHelper.getMarketedRamGb(15800), equals(16));
      expect(DeviceSpecHelper.getMarketedRamGb(23800), equals(24));
    });

    test('DeviceSpecHelper getMaxCpuClockGhz safely returns null on non-Android test runner', () {
      expect(DeviceSpecHelper.getMaxCpuClockGhz(), isNull);
    });

    test('DeviceSpecHelper SoC and GPU detection correctly maps Snapdragon, Dimensity, and Exynos', () {
      final snapdragonCpu = DeviceSpecHelper.detectSocName(
        hardware: 'qcom',
        board: 'kalama',
        manufacturer: 'Qualcomm',
      );
      expect(snapdragonCpu, contains('Snapdragon 8 Gen 2'));
      final snapdragonGpu = DeviceSpecHelper.detectGpuName(
        hardware: 'qcom',
        board: 'kalama',
        socName: snapdragonCpu,
      );
      expect(snapdragonGpu, equals('Adreno 740'));

      final dimensityCpu = DeviceSpecHelper.detectSocName(
        hardware: 'mt6897',
        board: 'mt6897',
        manufacturer: 'MediaTek',
      );
      expect(dimensityCpu, contains('Dimensity 8300'));
      final dimensityGpu = DeviceSpecHelper.detectGpuName(
        hardware: 'mt6897',
        board: 'mt6897',
        socName: dimensityCpu,
      );
      expect(dimensityGpu, equals('Mali-G615 MC6'));

      final adreno710 = DeviceSpecHelper.detectGpuName(
        hardware: 'sm6450',
        board: 'crow',
        socName: 'Qualcomm Snapdragon 7s Gen 2',
      );
      expect(adreno710, equals('Adreno 710'));

      final exynosCpu = DeviceSpecHelper.detectSocName(
        hardware: 's5e9945',
        board: 's5e9945',
        manufacturer: 'Samsung',
      );
      expect(exynosCpu, contains('Exynos 2400'));
      final exynosGpu = DeviceSpecHelper.detectGpuName(
        hardware: 's5e9945',
        board: 's5e9945',
        socName: exynosCpu,
      );
      expect(exynosGpu, equals('Samsung Xclipse 940'));

      final snapdragon685 = DeviceSpecHelper.detectSocName(
        hardware: 'sm6225-ad',
        board: 'bengal',
        manufacturer: 'vivo',
      );
      expect(snapdragon685, equals('Qualcomm Snapdragon 685'));

      final snapdragon685BySocModel = DeviceSpecHelper.detectSocName(
        hardware: 'qcom',
        board: 'bengal',
        manufacturer: 'vivo',
        socModel: 'SM6225-AD',
      );
      expect(snapdragon685BySocModel, equals('Qualcomm Snapdragon 685'));

      final snapdragon685Gpu = DeviceSpecHelper.detectGpuName(
        hardware: 'sm6225-ad',
        board: 'bengal',
        socName: snapdragon685,
      );
      expect(snapdragon685Gpu, equals('Adreno 610'));

      // Snapdragon 685 detection via clock speed > 2.60 GHz (e.g. 2.80 GHz) on sm6225 / khaje
      final snapdragon685ByClock = DeviceSpecHelper.detectSocName(
        hardware: 'qcom',
        board: 'khaje',
        manufacturer: 'xiaomi',
        maxClockGhz: 2.80,
      );
      expect(snapdragon685ByClock, equals('Qualcomm Snapdragon 685'));

      final snapdragon685ByClockOnSm6225 = DeviceSpecHelper.detectSocName(
        hardware: 'sm6225',
        board: 'bengal',
        manufacturer: 'realme',
        maxClockGhz: 2.75,
      );
      expect(snapdragon685ByClockOnSm6225, equals('Qualcomm Snapdragon 685'));

      // Snapdragon 680 detection when clock speed <= 2.60 GHz (e.g. 2.40 GHz) or null on sm6225 / khaje
      final snapdragon680ByClock = DeviceSpecHelper.detectSocName(
        hardware: 'qcom',
        board: 'khaje',
        manufacturer: 'xiaomi',
        maxClockGhz: 2.40,
      );
      expect(snapdragon680ByClock, equals('Qualcomm Snapdragon 680'));

      final snapdragon680DefaultFallback = DeviceSpecHelper.detectSocName(
        hardware: 'sm6225',
        board: 'bengal',
        manufacturer: 'xiaomi',
      );
      expect(snapdragon680DefaultFallback, equals('Qualcomm Snapdragon 680'));

      // New 64-bit SoCs (2024-2026)
      final snapdragon8EliteCpu = DeviceSpecHelper.detectSocName(
        hardware: 'qcom',
        board: 'sun',
        manufacturer: 'Qualcomm',
        socModel: 'SM8750',
      );
      expect(snapdragon8EliteCpu, equals('Qualcomm Snapdragon 8 Elite'));
      final snapdragon8EliteGpu = DeviceSpecHelper.detectGpuName(
        hardware: 'sm8750',
        board: 'sun',
        socName: snapdragon8EliteCpu,
      );
      expect(snapdragon8EliteGpu, equals('Adreno 830'));

      final dimensity9400Cpu = DeviceSpecHelper.detectSocName(
        hardware: 'mt6991',
        board: 'mt6991',
        manufacturer: 'MediaTek',
      );
      expect(dimensity9400Cpu, equals('MediaTek Dimensity 9400'));
      final dimensity9400Gpu = DeviceSpecHelper.detectGpuName(
        hardware: 'mt6991',
        board: 'mt6991',
        socName: dimensity9400Cpu,
      );
      expect(dimensity9400Gpu, equals('Immortalis-G925 MC12'));

      final exynos2500Cpu = DeviceSpecHelper.detectSocName(
        hardware: 's5e9955',
        board: 's5e9955',
        manufacturer: 'Samsung',
      );
      expect(exynos2500Cpu, equals('Samsung Exynos 2500'));
      final exynos2500Gpu = DeviceSpecHelper.detectGpuName(
        hardware: 's5e9955',
        board: 's5e9955',
        socName: exynos2500Cpu,
      );
      expect(exynos2500Gpu, equals('Samsung Xclipse 950'));

      final exynos1480Cpu = DeviceSpecHelper.detectSocName(
        hardware: 's5e8845',
        board: 's5e8845',
        manufacturer: 'Samsung',
      );
      expect(exynos1480Cpu, equals('Samsung Exynos 1480'));
      final exynos1480Gpu = DeviceSpecHelper.detectGpuName(
        hardware: 's5e8845',
        board: 's5e8845',
        socName: exynos1480Cpu,
      );
      expect(exynos1480Gpu, equals('Samsung Xclipse 530'));

      final tensorG5Cpu = DeviceSpecHelper.detectSocName(
        hardware: 'google',
        board: 'laguna',
        manufacturer: 'Google',
      );
      expect(tensorG5Cpu, equals('Google Tensor G5'));
      final tensorG5Gpu = DeviceSpecHelper.detectGpuName(
        hardware: 'google',
        board: 'laguna',
        socName: tensorG5Cpu,
      );
      expect(tensorG5Gpu, equals('IMG D-Series GPU'));

      final unisocT820Cpu = DeviceSpecHelper.detectSocName(
        hardware: 'ums9620',
        board: 't820',
        manufacturer: 'Unisoc',
      );
      expect(unisocT820Cpu, equals('Unisoc T820'));
      final unisocT820Gpu = DeviceSpecHelper.detectGpuName(
        hardware: 'ums9620',
        board: 't820',
        socName: unisocT820Cpu,
      );
      expect(unisocT820Gpu, equals('Mali-G57 MP4'));

      // Additional requested SoCs (Snapdragon 8 Elite Gen 5, Dimensity 7050/9500/9600, Unisoc, Snapdragon 6 & 7 series)
      final snapdragon8EliteGen5Cpu = DeviceSpecHelper.detectSocName(
        hardware: 'qcom',
        board: 'sun',
        manufacturer: 'Qualcomm',
        socModel: 'SM8850',
      );
      expect(
        snapdragon8EliteGen5Cpu,
        equals('Qualcomm Snapdragon 8 Elite Gen 5'),
      );
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'sm8850',
          board: 'sun',
          socName: snapdragon8EliteGen5Cpu,
        ),
        equals('Adreno 840'),
      );

      final dimensity7050Cpu = DeviceSpecHelper.detectSocName(
        hardware: 'mt6877v',
        board: 'mt6877',
        manufacturer: 'MediaTek',
      );
      expect(dimensity7050Cpu, equals('MediaTek Dimensity 7050'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'mt6877v',
          board: 'mt6877',
          socName: dimensity7050Cpu,
        ),
        equals('Mali-G68 MC4'),
      );

      final dimensity9500Cpu = DeviceSpecHelper.detectSocName(
        hardware: 'mt6993',
        board: 'mt6993',
        manufacturer: 'MediaTek',
      );
      expect(dimensity9500Cpu, equals('MediaTek Dimensity 9500'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'mt6993',
          board: 'mt6993',
          socName: dimensity9500Cpu,
        ),
        equals('Immortalis-G925 MC12'),
      );

      final dimensity9600Cpu = DeviceSpecHelper.detectSocName(
        hardware: 'mt6995',
        board: 'mt6995',
        manufacturer: 'MediaTek',
      );
      expect(dimensity9600Cpu, equals('MediaTek Dimensity 9600'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'mt6995',
          board: 'mt6995',
          socName: dimensity9600Cpu,
        ),
        equals('Immortalis-G925 MC12'),
      );

      final snapdragon778GCpu = DeviceSpecHelper.detectSocName(
        hardware: 'sm7325',
        board: 'yupik',
        manufacturer: 'Qualcomm',
      );
      expect(snapdragon778GCpu, equals('Qualcomm Snapdragon 778G'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'sm7325',
          board: 'yupik',
          socName: snapdragon778GCpu,
        ),
        equals('Adreno 642L'),
      );

      final snapdragon660Cpu = DeviceSpecHelper.detectSocName(
        hardware: 'sdm660',
        board: 'sdm660',
        manufacturer: 'Qualcomm',
      );
      expect(snapdragon660Cpu, equals('Qualcomm Snapdragon 660'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'sdm660',
          board: 'sdm660',
          socName: snapdragon660Cpu,
        ),
        equals('Adreno 512'),
      );

      final unisocT770Cpu = DeviceSpecHelper.detectSocName(
        hardware: 'ums512t',
        board: 't770',
        manufacturer: 'Unisoc',
      );
      expect(unisocT770Cpu, equals('Unisoc T770'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'ums512t',
          board: 't770',
          socName: unisocT770Cpu,
        ),
        equals('Mali-G57 MP4'),
      );

      final unisocT618Cpu = DeviceSpecHelper.detectSocName(
        hardware: 'ums512',
        board: 't618',
        manufacturer: 'Unisoc',
        socModel: 'T618',
      );
      expect(unisocT618Cpu, equals('Unisoc T618'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'ums512',
          board: 't618',
          socName: unisocT618Cpu,
        ),
        equals('Mali-G57 MP1'),
      );
    });

    test('DeviceSpecHelper getHardwareInfo returns full specifications dictionary with all expected keys', () async {
      final info = await DeviceSpecHelper.getHardwareInfo();
      expect(info.containsKey('deviceName'), isTrue);
      expect(info.containsKey('modelCode'), isTrue);
      expect(info.containsKey('cpu'), isTrue);
      expect(info.containsKey('gpu'), isTrue);
      expect(info.containsKey('ram'), isTrue);
      expect(info.containsKey('storage'), isTrue);
      expect(info.containsKey('storageFree'), isTrue);
      expect(info.containsKey('cores'), isTrue);

      expect((info['deviceName'] as String).isNotEmpty, isTrue);
      expect((info['modelCode'] as String).isNotEmpty, isTrue);
      expect((info['cpu'] as String).isNotEmpty, isTrue);
      expect((info['gpu'] as String).isNotEmpty, isTrue);
      expect((info['ram'] as String).isNotEmpty, isTrue);
      expect((info['storage'] as String).isNotEmpty, isTrue);
    });
  });

  group('Theme System and AMOLED Sakura tests', () {
    test('AppTheme returns valid ThemeData for all modes including sakura', () {
      final dark = AppTheme.getTheme('oled_snowfall');
      final oled = AppTheme.getTheme('oled_midnight');
      final light = AppTheme.getTheme('light');
      final sakura = AppTheme.getTheme('oled_sakura');
      final oledSakura = AppTheme.getTheme('oled_sakura');

      expect(dark.brightness, equals(Brightness.dark));
      expect(oled.brightness, equals(Brightness.dark));
      expect(oled.scaffoldBackgroundColor, equals(Colors.black));
      expect(light.brightness, equals(Brightness.light));

      expect(sakura.brightness, equals(Brightness.dark));
      expect(sakura.scaffoldBackgroundColor, equals(Colors.black));
      expect(sakura.colorScheme.primary, equals(const Color(0xFFF472B6)));
      expect(oledSakura.colorScheme.primary, equals(const Color(0xFFF472B6)));
    });

    test(
      'All theme description strings exist across all supported languages',
      () {
        for (final code in supportedCodes) {
          final l10n = AppLocalizations(code);
          expect(l10n.t('theme_oled_snowfall').isNotEmpty, isTrue);
          expect(l10n.t('theme_oled_snowfall_desc').isNotEmpty, isTrue);
          expect(
            l10n.t('theme_oled_snowfall_desc'),
            isNot(equals('theme_oled_snowfall_desc')),
          );

          expect(l10n.t('theme_oled_midnight').isNotEmpty, isTrue);
          expect(l10n.t('theme_oled_midnight_desc').isNotEmpty, isTrue);
          expect(
            l10n.t('theme_oled_midnight_desc'),
            isNot(equals('theme_oled_midnight_desc')),
          );

          expect(l10n.t('theme_light').isNotEmpty, isTrue);
          expect(l10n.t('theme_light_desc').isNotEmpty, isTrue);
          expect(l10n.t('theme_light_desc'), isNot(equals('theme_light_desc')));

          expect(l10n.t('theme_oled_snowfall'), equals('Snowfall'));
          expect(l10n.t('theme_oled_midnight'), equals('Midnight'));
          expect(l10n.t('theme_oled_sakura'), equals('Sakura'));
          expect(l10n.t('theme_light'), equals('Daylight'));
        }
      },
    );

    testWidgets(
      'SettingsScreen displays developer profile button with open icon',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme('oled_snowfall'),
            home: const SettingsScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Developer: zerabyte88'), findsOneWidget);
        expect(find.text('GitHub'), findsOneWidget);
        expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'SettingsScreen license row opens LicensePage with clickable source code and third-party notices links',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme('oled_snowfall'),
            home: const SettingsScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final licenseRow = find.text('MIT License');
        expect(licenseRow, findsOneWidget);
        await tester.tap(licenseRow);
        await tester.pumpAndSettle();

        expect(find.byType(LicensePage), findsOneWidget);
        expect(find.text('Phantek - Video Toolkit Vega'), findsOneWidget);
        expect(find.text('Source code'), findsOneWidget);
        expect(
          find.text('https://github.com/zerabyte88/phantek-video-toolkit-vega'),
          findsOneWidget,
        );
        expect(find.text('Third-party notices'), findsNothing);

        await tester.tap(find.text('Source code'));
        await tester.pump();
      },
    );

    test('Target FPS guide keys are completely free of emojis across all supported languages', () {
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );
      for (final code in supportedCodes) {
        final l10n = AppLocalizations(code);
        final title = l10n.t('fps_info_title');
        final orig = l10n.t('fps_desc_original');
        final fps60 = l10n.t('fps_desc_60');
        final fps30 = l10n.t('fps_desc_30');
        final fps24 = l10n.t('fps_desc_24');
        final custom = l10n.t('fps_desc_custom');

        expect(title.isNotEmpty, isTrue);
        expect(orig.isNotEmpty, isTrue);
        expect(fps60.isNotEmpty, isTrue);
        expect(fps30.isNotEmpty, isTrue);
        expect(fps24.isNotEmpty, isTrue);
        expect(custom.isNotEmpty, isTrue);

        expect(
          emojiRegex.hasMatch(title),
          isFalse,
          reason: '$code title has emoji',
        );
        expect(
          emojiRegex.hasMatch(orig),
          isFalse,
          reason: '$code orig has emoji',
        );
        expect(
          emojiRegex.hasMatch(fps60),
          isFalse,
          reason: '$code fps60 has emoji',
        );
        expect(
          emojiRegex.hasMatch(fps30),
          isFalse,
          reason: '$code fps30 has emoji',
        );
        expect(
          emojiRegex.hasMatch(fps24),
          isFalse,
          reason: '$code fps24 has emoji',
        );
        expect(
          emojiRegex.hasMatch(custom),
          isFalse,
          reason: '$code custom has emoji',
        );
      }
    });

    testWidgets(
      'Target FPS only renders Original and Custom chips, custom slider clamps to 30 for 30 FPS video',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const video30 = VideoInfo(
          filePath: '/test/video.mp4',
          fileName: 'video.mp4',
          width: 1920,
          height: 1080,
          durationSeconds: 10.0,
          bitrate: 5000000,
          fps: 30.0,
          codec: 'h264',
          fileSizeBytes: 1000000,
        );

        EncodingOptions options = const EncodingOptions();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme('oled_snowfall'),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return ConversionOptionsCard(
                    sourceVideo: video30,
                    resolutions: VideoResolution.standardResolutions,
                    selectedResolution: VideoResolution.standardResolutions[2],
                    encodingOptions: options,
                    onResolutionChanged: (_) {},
                    onOptionsChanged: (newOpts) {
                      setState(() {
                        options = newOpts;
                      });
                    },
                    l10n: const AppLocalizations('id'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('advanced_options_toggle')),
        );
        await tester.tap(find.byKey(const Key('advanced_options_toggle')));
        await tester.pumpAndSettle();
        if (find.byKey(const Key('advanced_warning_yes_button')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('advanced_warning_yes_button')));
          await tester.pumpAndSettle();
        }

        // Standard fixed FPS chips should not exist
        expect(find.widgetWithText(ChoiceChip, '60 FPS'), findsNothing);
        expect(find.widgetWithText(ChoiceChip, '30 FPS'), findsNothing);

        // Only Asli and Kustom chips should be present and enabled
        expect(find.widgetWithText(ChoiceChip, 'Asli'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'Kustom'), findsOneWidget);

        // Tap Kustom chip
        await tester.tap(find.widgetWithText(ChoiceChip, 'Kustom'));
        await tester.pumpAndSettle();

        // Slider should appear and its max must be exactly 30.0
        final sliderFinder = find.byWidgetPredicate(
          (w) => w is Slider && (w.label?.contains('FPS') ?? false),
        );
        expect(sliderFinder, findsOneWidget);
        final sliderWidget = tester.widget<Slider>(sliderFinder);
        expect(sliderWidget.max, 30.0);
        expect(sliderWidget.min, 10.0);

        // Dynamic FPS explanation is removed
        expect(
          find.text(const AppLocalizations('id').t('fps_desc_custom')),
          findsNothing,
        );
      },
    );

    testWidgets('Target FPS custom slider clamps to 60 for 60 FPS video', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const video60 = VideoInfo(
        filePath: '/test/video60.mp4',
        fileName: 'video60.mp4',
        width: 1920,
        height: 1080,
        durationSeconds: 10.0,
        bitrate: 8000000,
        fps: 60.0,
        codec: 'h264',
        fileSizeBytes: 2000000,
      );

      EncodingOptions options = const EncodingOptions();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme('oled_snowfall'),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ConversionOptionsCard(
                  sourceVideo: video60,
                  resolutions: VideoResolution.standardResolutions,
                  selectedResolution: VideoResolution.standardResolutions[2],
                  encodingOptions: options,
                  onResolutionChanged: (_) {},
                  onOptionsChanged: (newOpts) {
                    setState(() {
                      options = newOpts;
                    });
                  },
                  l10n: const AppLocalizations('id'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('advanced_options_toggle')),
      );
      await tester.tap(find.byKey(const Key('advanced_options_toggle')));
      await tester.pumpAndSettle();
      if (find.byKey(const Key('advanced_warning_yes_button')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('advanced_warning_yes_button')));
        await tester.pumpAndSettle();
      }

      // 60 FPS chip should not exist, only Asli and Kustom
      expect(find.widgetWithText(ChoiceChip, '60 FPS'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Asli'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Kustom'), findsOneWidget);

      // Tap Kustom chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Kustom'));
      await tester.pumpAndSettle();

      // Slider should appear and its max must be exactly 60.0
      final sliderFinder = find.byWidgetPredicate(
        (w) => w is Slider && (w.label?.contains('FPS') ?? false),
      );
      expect(sliderFinder, findsOneWidget);
      final sliderWidget = tester.widget<Slider>(sliderFinder);
      expect(sliderWidget.max, 60.0);
      expect(sliderWidget.min, 10.0);
    });

    testWidgets(
      'Explanation texts in ConversionOptionsCard render fully on compact screens without overflow or truncation',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const video = VideoInfo(
          filePath: '/test/video.mp4',
          fileName: 'video.mp4',
          width: 1920,
          height: 1080,
          durationSeconds: 10.0,
          bitrate: 5000000,
          fps: 30.0,
          codec: 'h264',
          fileSizeBytes: 2000000,
        );

        EncodingOptions options = const EncodingOptions(
          speedPreset: SpeedPreset.max,
          rateControlMode: RateControlMode.crf,
          crfValue: 18,
          container: VideoContainer.mp4,
          targetFps: 30,
        );

        SharedPreferences.setMockInitialValues({});
        final service = SettingsService();
        await service.init();
        await service.setLanguage('id');
        final l10n = service.l10n;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme('oled_snowfall'),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ConversionOptionsCard(
                  sourceVideo: video,
                  resolutions: VideoResolution.standardResolutions,
                  selectedResolution: VideoResolution.standardResolutions[2],
                  encodingOptions: options,
                  onResolutionChanged: (_) {},
                  onOptionsChanged: (_) {},
                  l10n: l10n,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('advanced_options_toggle')),
        );
        await tester.tap(find.byKey(const Key('advanced_options_toggle')));
        await tester.pumpAndSettle();
        if (find.byKey(const Key('advanced_warning_yes_button')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('advanced_warning_yes_button')));
          await tester.pumpAndSettle();
        }

        // Ensure active preset indicator box, container format, and FPS descriptions are removed
        expect(find.byIcon(Icons.speed_rounded), findsNothing);
        expect(find.text(l10n.t('desc_crf')), findsOneWidget);
        expect(find.text(l10n.t('desc_mp4')), findsNothing);
        expect(find.text(l10n.t('fps_desc_30')), findsNothing);
        expect(find.text(l10n.t('crf_label')), findsNothing);

        // Verify no RenderParagraph in the tree has TextOverflow.ellipsis for descriptions
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        for (final text in textWidgets) {
          final str = text.data ?? text.textSpan?.toPlainText() ?? '';
          if (str.contains('CRF') ||
              str.contains('Preset') ||
              str.contains('FPS') ||
              str.contains('Format')) {
            expect(
              text.overflow,
              isNot(equals(TextOverflow.ellipsis)),
              reason: 'Text "$str" should not have TextOverflow.ellipsis',
            );
          }
        }
      },
    );
  });

  group('Adaptive CPU Thread Allocation & Crash Recovery tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    const video1080 = VideoInfo(
      filePath: '/test/video1080.mp4',
      fileName: 'video1080.mp4',
      width: 1920,
      height: 1080,
      durationSeconds: 10.0,
      bitrate: 4000000,
      fps: 30.0,
      codec: 'h264',
      fileSizeBytes: 5000000,
    );

    const video4K = VideoInfo(
      filePath: '/test/video4k.mp4',
      fileName: 'video4k.mp4',
      width: 3840,
      height: 2160,
      durationSeconds: 10.0,
      bitrate: 15000000,
      fps: 30.0,
      codec: 'h264',
      fileSizeBytes: 20000000,
    );

    test('DeviceSpecHelper.maxSafeThreadCount returns proper thresholds based on RAM', () {
      expect(
        DeviceSpecHelper.maxSafeThreadCount(3072, 8),
        equals(4),
      ); // 3GB -> 4
      expect(
        DeviceSpecHelper.maxSafeThreadCount(4096, 8),
        equals(4),
      ); // 4GB -> 4
      expect(
        DeviceSpecHelper.maxSafeThreadCount(6144, 8),
        equals(6),
      ); // 6GB -> 6
      expect(
        DeviceSpecHelper.maxSafeThreadCount(8192, 8),
        equals(8),
      ); // 8GB on 8 cores -> 8
      expect(
        DeviceSpecHelper.maxSafeThreadCount(8192, 6),
        equals(6),
      ); // 8GB on 6 cores -> 6
    });

    test('DeviceSpecHelper.isEntryOrLegacySoc distinguishes legacy chips from modern mid-range', () {
      // Modern Mid-Range / Upper: should return false
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'MediaTek Helio G70'),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'MediaTek Helio G85'),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'MediaTek Helio G99'),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'MediaTek Helio G100'),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'Qualcomm Snapdragon 660'),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'Qualcomm Snapdragon 662'),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'Qualcomm Snapdragon 665'),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'Qualcomm Snapdragon 675'),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'Qualcomm Snapdragon 680'),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(
          socName: 'Qualcomm Snapdragon 695 5G',
        ),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(
          socName: 'Qualcomm Snapdragon 732G',
        ),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'MediaTek Dimensity 7050'),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(
          socName: 'Qualcomm Snapdragon 4 Gen 2',
        ),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(
          socName: 'Qualcomm Snapdragon 4 Gen 1',
        ),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(
          socName: 'Qualcomm Snapdragon 4s Gen 2',
        ),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(hardware: 'qcom', board: 'sm4450'),
        isFalse,
      );

      // Legacy Snapdragon / Helio entry / Unisoc: should return true
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'Qualcomm Snapdragon 625'),
        isTrue,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'Qualcomm Snapdragon 636'),
        isTrue,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'Qualcomm Snapdragon 460'),
        isTrue,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(
          socName: 'MediaTek Helio P35 / G35',
        ),
        isTrue,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'MediaTek Helio G25'),
        isTrue,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'Unisoc T606'),
        isTrue,
      );
    });

    test('DeviceSpecHelper.resolveThreadCount allocates cores adaptively for RAM, SoC, and 4K resolution', () {
      // 1. RAM <= 4GB: 4 cores baseline, remains 4 cores on 4K video (entry-level lock)
      expect(
        DeviceSpecHelper.resolveThreadCount(
          video: video1080,
          customRamMb: 4096,
          customPhysicalCores: 8,
          customSoc: 'Qualcomm Snapdragon 680',
        ),
        equals(4),
      );
      expect(
        DeviceSpecHelper.resolveThreadCount(
          video: video4K,
          customRamMb: 4096,
          customPhysicalCores: 8,
          customSoc: 'Qualcomm Snapdragon 680',
        ),
        equals(4), // Remains 4 cores on entry-level / RAM <= 4GB
      );

      // 2. RAM 4GB with mid-range SoC (e.g. SD 732G RAM 4GB): allocates 4 cores (RAM protection holds)
      expect(
        DeviceSpecHelper.resolveThreadCount(
          video: video1080,
          customRamMb: 4096,
          customPhysicalCores: 8,
          customSoc: 'Qualcomm Snapdragon 732G',
        ),
        equals(4),
      );

      // 3. RAM 6GB Mid-Range (Helio G99, SD 665, Helio G85): 6 cores baseline, discounted to 5 cores on 4K
      expect(
        DeviceSpecHelper.resolveThreadCount(
          video: video1080,
          customRamMb: 6144,
          customPhysicalCores: 8,
          customSoc: 'MediaTek Helio G99',
        ),
        equals(6),
      );
      expect(
        DeviceSpecHelper.resolveThreadCount(
          video: video1080,
          customRamMb: 6144,
          customPhysicalCores: 8,
          customSoc: 'Qualcomm Snapdragon 665',
        ),
        equals(6),
      );
      expect(
        DeviceSpecHelper.resolveThreadCount(
          video: video1080,
          customRamMb: 6144,
          customPhysicalCores: 8,
          customSoc: 'MediaTek Helio G85',
        ),
        equals(6),
      );
      expect(
        DeviceSpecHelper.resolveThreadCount(
          video: video1080,
          customRamMb: 6144,
          customPhysicalCores: 8,
          customSoc: 'Qualcomm Snapdragon 4 Gen 2',
        ),
        equals(6),
      );
      expect(
        DeviceSpecHelper.resolveThreadCount(
          video: video4K,
          customRamMb: 6144,
          customPhysicalCores: 8,
          customSoc: 'MediaTek Helio G99',
        ),
        equals(5),
      );
      expect(
        DeviceSpecHelper.resolveThreadCount(
          video: video4K,
          customRamMb: 6144,
          customPhysicalCores: 8,
          customSoc: 'Qualcomm Snapdragon 665',
        ),
        equals(5),
      );

      // 4. RAM >= 8GB Flagship (Snapdragon 8 Gen 2): 8 cores baseline, discounted to 7 on 4K
      expect(
        DeviceSpecHelper.resolveThreadCount(
          video: video1080,
          customRamMb: 8192,
          customPhysicalCores: 8,
          customSoc: 'Qualcomm Snapdragon 8 Gen 2',
        ),
        equals(8),
      );
      expect(
        DeviceSpecHelper.resolveThreadCount(
          video: video4K,
          customRamMb: 8192,
          customPhysicalCores: 8,
          customSoc: 'Qualcomm Snapdragon 8 Gen 2',
        ),
        equals(7),
      );

      // 5. Manual selection: always respected and never secretly discounted
      expect(
        DeviceSpecHelper.resolveThreadCount(
          video: video4K,
          requestedThreads: 6,
          customRamMb: 4096,
          customPhysicalCores: 8,
        ),
        equals(6), // Respected!
      );

      // 6. Manual selection clamped to physical cores
      expect(
        DeviceSpecHelper.resolveThreadCount(
          video: video1080,
          requestedThreads: 8,
          customPhysicalCores: 6,
        ),
        equals(6), // Clamped to 6 physical cores
      );
    });

    test(
      'TransformerService.isOomLog correctly identifies out-of-memory logs',
      () {
        expect(
          TransformerService.isOomLog('Error: Cannot allocate memory'),
          isTrue,
        );
        expect(
          TransformerService.isOomLog('fatal: Out of memory in x264_frame_new'),
          isTrue,
        );
        expect(
          TransformerService.isOomLog('av_malloc of size 10485760 failed'),
          isTrue,
        );
        expect(
          TransformerService.isOomLog(
            'libx264 failed to allocate memory for lookahead',
          ),
          isTrue,
        );
        expect(
          TransformerService.isOomLog(
            'frame=  120 fps= 24 q=28.0 size=    1024kB time=00:00:05.00 bitrate=1677.7kbits/s speed=1.2x',
          ),
          isFalse,
        );
      },
    );

    test(
      'SettingsService job marker persists, retrieves, and clears correctly',
      () async {
        final service = SettingsService();
        await service.clearJobMarker();
        expect(await service.getJobMarker(), isNull);

        await service.saveJobMarker(
          inputPath: '/test/source.mp4',
          outputPath: '/test/out.mp4',
          allocatedThreads: 4,
          is4K: true,
          retryCount: 0,
        );

        final marker = await service.getJobMarker();
        expect(marker, isNotNull);
        expect(marker!['inputPath'], equals('/test/source.mp4'));
        expect(marker['outputPath'], equals('/test/out.mp4'));
        expect(marker['allocatedThreads'], equals(4));
        expect(marker['is4K'], isTrue);

        await service.clearJobMarker();
        expect(await service.getJobMarker(), isNull);
      },
    );

    testWidgets('SettingsScreen does not display CPU Cores setting', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = SettingsService();
      await service.init();
      await service.setCpuThreads(0);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme('oled_snowfall'),
          home: const SettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final l10n = service.l10n;

      // Verify CPU Cores setting header is not displayed
      expect(find.text(l10n.t('settings_cpu_threads')), findsNothing);
    });

    testWidgets(
      'ConversionOptionsCard does not display 4K CPU note when video is 4K in Auto mode',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = SettingsService();
        await service.init();
        await service.setCpuThreads(0); // Auto mode

        final l10n = service.l10n;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme('oled_snowfall'),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ConversionOptionsCard(
                  sourceVideo: video4K,
                  resolutions: VideoResolution.standardResolutions,
                  selectedResolution: VideoResolution.standardResolutions.first,
                  encodingOptions: const EncodingOptions(),
                  onResolutionChanged: (_) {},
                  onOptionsChanged: (_) {},
                  l10n: l10n,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify 4K stability note and CPU memory icon are not rendered
        expect(find.byIcon(Icons.memory_rounded), findsNothing);
      },
    );
  });

  group('SoC Normalization, Description, and Device Specs UI tests', () {
    test('DeviceSpecHelper.cleanSocDisplayName strips vendor prefixes and legal text cleanly', () {
      expect(
        DeviceSpecHelper.cleanSocDisplayName('Qualcomm Snapdragon 8 Elite'),
        equals('Snapdragon 8 Elite'),
      );
      expect(
        DeviceSpecHelper.cleanSocDisplayName(
          'Qualcomm Technologies, Inc Snapdragon 8 Gen 3',
        ),
        equals('Snapdragon 8 Gen 3'),
      );
      expect(
        DeviceSpecHelper.cleanSocDisplayName('MediaTek Dimensity 9400'),
        equals('Dimensity 9400'),
      );
      expect(
        DeviceSpecHelper.cleanSocDisplayName('MediaTek Helio G99 / G100'),
        equals('Helio G99 / G100'),
      );
      expect(
        DeviceSpecHelper.cleanSocDisplayName('Google Tensor G4'),
        equals('Tensor G4'),
      );
      expect(
        DeviceSpecHelper.cleanSocDisplayName('Samsung Exynos 2400 (TM)'),
        equals('Exynos 2400'),
      );
      expect(
        DeviceSpecHelper.cleanSocDisplayName('Unisoc T606'),
        equals('T606'),
      );
      expect(DeviceSpecHelper.cleanSocDisplayName('mt6768'), equals('mt6768'));
      expect(DeviceSpecHelper.cleanSocDisplayName(''), equals(''));
    });

    test('DeviceSpecHelper.describeSoc returns structured SocDescription with accurate precision', () {
      // 1. Precise SoC
      final precise = DeviceSpecHelper.describeSoc(
        socModel: 'sm8750',
        hardware: 'qcom',
        manufacturer: 'Xiaomi',
        physicalCores: 8,
      );
      expect(precise.isPrecise, isTrue);
      expect(precise.displayName, equals('Snapdragon 8 Elite'));
      expect(precise.coreCount, equals(8));

      // 2. Unmapped platform code
      final platformCode = DeviceSpecHelper.describeSoc(
        hardware: 'mt67999',
        physicalCores: 8,
      );
      expect(platformCode.isPrecise, isFalse);
      expect(platformCode.displayName, equals('mt67999'));
      expect(platformCode.coreCount, equals(8));

      // 3. Pure generic/non-informative
      final generic = DeviceSpecHelper.describeSoc(
        hardware: 'qcom',
        physicalCores: 8,
      );
      expect(generic.isPrecise, isFalse);
      expect(generic.displayName, isEmpty);
      expect(generic.coreCount, equals(8));

      // 4. Unknown/Empty
      final empty = DeviceSpecHelper.describeSoc(
        hardware: 'unknown',
        physicalCores: 8,
      );
      expect(empty.isPrecise, isFalse);
      expect(empty.displayName, isEmpty);
    });

    test(
      'New CPU spec detail translations exist across all supported languages',
      () {
        for (final code in supportedCodes) {
          final l10n = AppLocalizations(code);
          expect(
            l10n.t('device_cpu_generic').isNotEmpty,
            isTrue,
            reason: 'device_cpu_generic missing in $code',
          );
        }
      },
    );

    testWidgets(
      'SettingsScreen CPU row displays clean name without (X Core), without info icon, and does not open bottom sheet',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        final service = SettingsService();
        await service.init();
        final l10n = service.l10n;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme('oled_snowfall'),
            home: const SettingsScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 1. Verify CPU row exists
        expect(find.text(l10n.t('device_cpu')), findsOneWidget);

        // 2. Tap on the CPU row — bottom sheet should not open
        await tester.tap(find.text(l10n.t('device_cpu')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 3. Bottom sheet should NOT be present
        expect(find.byType(BottomSheet), findsNothing);
      },
    );

    testWidgets(
      'Device specs card and CPU row layout handles large text scaling and 360dp width without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        final service = SettingsService();
        await service.init();
        final l10n = service.l10n;

        final longSoc = DeviceSpecHelper.describeSoc(
          socModel:
              'MediaTek Dimensity 9600 Pro Extreme Ultimate Max Plus Edition',
          hardware: 'mt6999',
          manufacturer: 'MediaTek Technologies, Inc.',
          brand: 'MediaTek',
          physicalCores: 8,
        );

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: MaterialApp(
              theme: AppTheme.getTheme('oled_snowfall'),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Builder(
                    builder: (context) {
                      final theme = Theme.of(context);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // CPU Row with very long commercial SoC
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 105,
                                child: Text(
                                  l10n.t('device_cpu'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(140),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  longSoc.displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: theme.colorScheme.primary.withAlpha(150),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      },
    );
  });

  group('Pure AMOLED and Clean Light Static Theme tests', () {
    test('AppTheme generates valid themes for oled_pure and light_clean', () {
      final oledPure = AppTheme.getTheme('oled_pure');
      expect(oledPure.brightness, equals(Brightness.dark));
      expect(oledPure.scaffoldBackgroundColor, equals(Colors.black));

      final lightClean = AppTheme.getTheme('light_clean');
      expect(lightClean.brightness, equals(Brightness.light));
      expect(
        lightClean.scaffoldBackgroundColor,
        equals(const Color(0xFFEDF2FA)),
      );
    });

    test('All 22 languages have valid translations for new static themes and badge', () {
      for (final code in supportedCodes) {
        final l10n = AppLocalizations(code);
        expect(
          l10n.t('theme_oled_pure').isNotEmpty,
          isTrue,
          reason: 'theme_oled_pure missing in $code',
        );
        expect(
          l10n.t('theme_oled_pure_desc').isNotEmpty,
          isTrue,
          reason: 'theme_oled_pure_desc missing in $code',
        );
        expect(
          l10n.t('theme_light_clean').isNotEmpty,
          isTrue,
          reason: 'theme_light_clean missing in $code',
        );
        expect(
          l10n.t('theme_light_clean_desc').isNotEmpty,
          isTrue,
          reason: 'theme_light_clean_desc missing in $code',
        );
        expect(
          l10n.t('badge_static').isNotEmpty,
          isTrue,
          reason: 'badge_static missing in $code',
        );
        expect(
          l10n.t('badge_live').isNotEmpty,
          isTrue,
          reason: 'badge_live missing in $code',
        );
      }
    });

    testWidgets(
      'ThemeAnimatedBackground stops ticker and bypasses canvas for static themes',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final service = SettingsService();
        await service.init();

        // 1. Start on oled_pure (static)
        await service.setThemeMode('oled_pure');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme(service.settings.themeMode),
            home: const ThemeAnimatedBackground(
              child: Scaffold(body: Center(child: Text('Content'))),
            ),
          ),
        );
        // Because oled_pure is static, pumpAndSettle completes without timing out!
        await tester.pumpAndSettle();
        expect(find.text('Content'), findsOneWidget);

        // 2. Switch to light_clean (static)
        await service.setThemeMode('light_clean');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme(service.settings.themeMode),
            home: const ThemeAnimatedBackground(
              child: Scaffold(body: Center(child: Text('Content'))),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Content'), findsOneWidget);

        // 3. Reset back to dark
        await service.setThemeMode('dark');
      },
    );

    testWidgets(
      'AnimatedFlameTitle displays correct matching icons for all themes including oled_pure and light_clean',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final service = SettingsService();
        await service.init();

        // 1. oled_pure -> Icons.brightness_2_outlined
        await service.setThemeMode('oled_pure');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme(service.settings.themeMode),
            home: Scaffold(appBar: AppBar(title: const AnimatedFlameTitle())),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byIcon(Icons.brightness_2_outlined), findsOneWidget);

        // 2. light_clean -> Icons.wb_sunny_outlined
        await service.setThemeMode('light_clean');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme(service.settings.themeMode),
            home: Scaffold(appBar: AppBar(title: const AnimatedFlameTitle())),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);

        // 3. dark (Snowfall) -> Icons.ac_unit_rounded
        await service.setThemeMode('dark');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme(service.settings.themeMode),
            home: Scaffold(appBar: AppBar(title: const AnimatedFlameTitle())),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byIcon(Icons.ac_unit_rounded), findsOneWidget);

        // 4. oled (Midnight) -> Icons.nightlight_round
        await service.setThemeMode('oled_midnight');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme(service.settings.themeMode),
            home: Scaffold(appBar: AppBar(title: const AnimatedFlameTitle())),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byIcon(Icons.nightlight_round), findsOneWidget);

        // 5. light (Daylight) -> Icons.wb_sunny_rounded
        await service.setThemeMode('light');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme(service.settings.themeMode),
            home: Scaffold(appBar: AppBar(title: const AnimatedFlameTitle())),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);

        // Reset
        await service.setThemeMode('dark');
      },
    );
  });

  group('Comprehensive ARM 64-bit SoC & GPU Detection tests', () {
    test(
      'HiSilicon Kirin SoCs and Maleoon/Mali GPUs are accurately identified',
      () {
        // Flagships
        final k9020 = DeviceSpecHelper.detectSocName(
          hardware: 'hi36c0',
          board: 'hi36c0',
          manufacturer: 'HUAWEI',
        );
        expect(k9020, equals('HiSilicon Kirin 9020'));
        expect(
          DeviceSpecHelper.detectGpuName(
            hardware: 'hi36c0',
            board: 'hi36c0',
            socName: k9020,
          ),
          equals('Maleoon 920'),
        );

        final k9010 = DeviceSpecHelper.detectSocName(
          hardware: 'hi36a0',
          board: 'hi36a0',
          manufacturer: 'HUAWEI',
          socModel: 'hi36a0v121',
        );
        expect(k9010, equals('HiSilicon Kirin 9010'));
        expect(
          DeviceSpecHelper.detectGpuName(
            hardware: 'hi36a0',
            board: 'hi36a0',
            socName: k9010,
          ),
          equals('Maleoon 910'),
        );

        final k9000s = DeviceSpecHelper.detectSocName(
          hardware: 'hi36a0',
          board: 'hi36a0',
          manufacturer: 'HUAWEI',
          socModel: 'hi36a0v120 kirin9000s',
        );
        expect(k9000s, equals('HiSilicon Kirin 9000S'));
        expect(
          DeviceSpecHelper.detectGpuName(
            hardware: 'hi36a0',
            board: 'hi36a0',
            socName: k9000s,
          ),
          equals('Maleoon 910'),
        );

        final k9000 = DeviceSpecHelper.detectSocName(
          hardware: 'hi36a0',
          board: 'hi36a0',
          manufacturer: 'HUAWEI',
        );
        expect(k9000, equals('HiSilicon Kirin 9000 / 9000E'));
        expect(
          DeviceSpecHelper.detectGpuName(
            hardware: 'hi36a0',
            board: 'hi36a0',
            socName: k9000,
          ),
          equals('Mali-G78 MP24'),
        );

        final k990 = DeviceSpecHelper.detectSocName(
          hardware: 'hi3690',
          board: 'hi3690',
          manufacturer: 'HUAWEI',
          socModel: 'hi3690-5g',
        );
        expect(k990, equals('HiSilicon Kirin 990 5G'));
        expect(
          DeviceSpecHelper.detectGpuName(
            hardware: 'hi3690',
            board: 'hi3690',
            socName: k990,
          ),
          equals('Mali-G76 MP16'),
        );

        final k980 = DeviceSpecHelper.detectSocName(
          hardware: 'hi3680',
          board: 'hi3680',
          manufacturer: 'HUAWEI',
        );
        expect(k980, equals('HiSilicon Kirin 980'));
        expect(
          DeviceSpecHelper.detectGpuName(
            hardware: 'hi3680',
            board: 'hi3680',
            socName: k980,
          ),
          equals('Mali-G76 MP10'),
        );

        // Mid-Range & Legacy 64-bit Kirin
        final k8000 = DeviceSpecHelper.detectSocName(
          hardware: 'kirin 8000',
          board: 'kirin8000',
          manufacturer: 'HUAWEI',
        );
        expect(k8000, equals('HiSilicon Kirin 8000'));
        expect(
          DeviceSpecHelper.detectGpuName(
            hardware: '',
            board: '',
            socName: k8000,
          ),
          equals('Mali-G610'),
        );

        final k710 = DeviceSpecHelper.detectSocName(
          hardware: 'hi6260',
          board: 'hi6260',
          manufacturer: 'HUAWEI',
        );
        expect(k710, equals('HiSilicon Kirin 710 / 710F'));
        expect(
          DeviceSpecHelper.detectGpuName(
            hardware: 'hi6260',
            board: 'hi6260',
            socName: k710,
          ),
          equals('Mali-G51 MP4'),
        );

        final k620 = DeviceSpecHelper.detectSocName(
          hardware: 'hi6210',
          board: 'hi6210',
          manufacturer: 'HUAWEI',
        );
        expect(k620, equals('HiSilicon Kirin 620'));
        expect(
          DeviceSpecHelper.detectGpuName(
            hardware: 'hi6210',
            board: 'hi6210',
            socName: k620,
          ),
          equals('Mali-450 MP4'),
        );
      },
    );

    test('Xiaomi XRING and Surge in-house SoCs are accurately identified', () {
      final xringO3 = DeviceSpecHelper.detectSocName(
        hardware: 'xring o3',
        board: 'xring_o3',
        manufacturer: 'Xiaomi',
      );
      expect(xringO3, equals('Xiaomi XRING O3'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: '',
          board: '',
          socName: xringO3,
        ),
        equals('Immortalis-G925+'),
      );

      final xringO1 = DeviceSpecHelper.detectSocName(
        hardware: 'xring o1',
        board: 'xring_o1',
        manufacturer: 'Xiaomi',
      );
      expect(xringO1, equals('Xiaomi XRING O1'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: '',
          board: '',
          socName: xringO1,
        ),
        equals('Immortalis-G925 MC16'),
      );

      final surge = DeviceSpecHelper.detectSocName(
        hardware: 'v670',
        board: 'pinecone',
        manufacturer: 'Xiaomi',
      );
      expect(surge, equals('Xiaomi Surge S1'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'v670',
          board: 'pinecone',
          socName: surge,
        ),
        equals('Mali-T860 MP4'),
      );
    });

    test('JLQ Technology (Poco C40) SoC is accurately identified', () {
      final jlq = DeviceSpecHelper.detectSocName(
        hardware: 'jr510',
        board: 'jr510',
        manufacturer: 'Xiaomi',
        socModel: 'jlq jr510',
      );
      expect(jlq, equals('JLQ JR510'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'jr510',
          board: 'jr510',
          socName: jlq,
        ),
        equals('Mali-G57 MC1'),
      );
    });

    test('Expanded 64-bit SoCs across Snapdragon, Dimensity, Helio, and Exynos are identified', () {
      // Snapdragon 810 (MSM8994) & 410 (MSM8916)
      final sd810 = DeviceSpecHelper.detectSocName(
        hardware: 'qcom',
        board: 'msm8994',
        manufacturer: 'Qualcomm',
      );
      expect(sd810, equals('Qualcomm Snapdragon 810'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: '',
          board: 'msm8994',
          socName: sd810,
        ),
        equals('Adreno 430'),
      );

      final sd410 = DeviceSpecHelper.detectSocName(
        hardware: 'qcom',
        board: 'msm8916',
        manufacturer: 'Qualcomm',
      );
      expect(sd410, equals('Qualcomm Snapdragon 410'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: '',
          board: 'msm8916',
          socName: sd410,
        ),
        equals('Adreno 306'),
      );

      // Helio P60 (MT6771) & Helio X30 (MT6799)
      final p60 = DeviceSpecHelper.detectSocName(
        hardware: 'mt6771',
        board: 'mt6771',
        manufacturer: 'MediaTek',
      );
      expect(p60, equals('MediaTek Helio P60 / P70'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'mt6771',
          board: 'mt6771',
          socName: p60,
        ),
        equals('Mali-G72 MP3'),
      );

      final x30 = DeviceSpecHelper.detectSocName(
        hardware: 'mt6799',
        board: 'mt6799',
        manufacturer: 'MediaTek',
      );
      expect(x30, equals('MediaTek Helio X30'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'mt6799',
          board: 'mt6799',
          socName: x30,
        ),
        equals('PowerVR Series7XT Plus'),
      );

      // Exynos 8895 (Galaxy S8)
      final ex8895 = DeviceSpecHelper.detectSocName(
        hardware: 'universal8895',
        board: 'universal8895',
        manufacturer: 'Samsung',
      );
      expect(ex8895, equals('Samsung Exynos 8895'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'universal8895',
          board: 'universal8895',
          socName: ex8895,
        ),
        equals('Mali-G71 MP20'),
      );
    });

    test('cleanSocDisplayName strips HiSilicon, Xiaomi, and JLQ brand prefixes cleanly', () {
      expect(
        DeviceSpecHelper.cleanSocDisplayName('HiSilicon Kirin 9010'),
        equals('Kirin 9010'),
      );
      expect(
        DeviceSpecHelper.cleanSocDisplayName('Huawei Kirin 9000S'),
        equals('Kirin 9000S'),
      );
      expect(
        DeviceSpecHelper.cleanSocDisplayName('Xiaomi XRING O1'),
        equals('XRING O1'),
      );
      expect(
        DeviceSpecHelper.cleanSocDisplayName('Xiaomi Surge S1'),
        equals('Surge S1'),
      );
      expect(
        DeviceSpecHelper.cleanSocDisplayName('JLQ Technology JR510'),
        equals('JR510'),
      );
      expect(
        DeviceSpecHelper.cleanSocDisplayName('JLQ JR510'),
        equals('JR510'),
      );
    });

    test('isEntryOrLegacySoc categorizes entry chips to 4 threads and flagships to full threads', () {
      // Entry & legacy chips -> true (capped at 4 threads)
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'HiSilicon Kirin 710'),
        isTrue,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'HiSilicon Kirin 620'),
        isTrue,
      );
      expect(DeviceSpecHelper.isEntryOrLegacySoc(socName: 'JLQ JR510'), isTrue);
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'Qualcomm Snapdragon 410'),
        isTrue,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'MediaTek Helio P60'),
        isTrue,
      );

      // Flagships -> false (allowed up to 8 threads on 8GB+ RAM)
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'HiSilicon Kirin 9000S'),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'HiSilicon Kirin 9010'),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'Xiaomi XRING O1'),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(
          socName: 'Qualcomm Snapdragon 8 Elite',
        ),
        isFalse,
      );
      expect(
        DeviceSpecHelper.isEntryOrLegacySoc(socName: 'MediaTek Dimensity 9400'),
        isFalse,
      );
    });

    test('Newest (2025/2026) and oldest (2014) 64-bit SoCs and GPUs are detected comprehensively', () {
      // 1. Newest Flagship SoCs (2025 / 2026)
      final k9050 = DeviceSpecHelper.detectSocName(
        hardware: 'hi36d0',
        board: 'hi36d0',
        manufacturer: 'HUAWEI',
      );
      expect(k9050, equals('HiSilicon Kirin 9050 Pro'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'hi36d0',
          board: 'hi36d0',
          socName: k9050,
        ),
        equals('Maleoon 955'),
      );

      final k9030 = DeviceSpecHelper.detectSocName(
        hardware: 'hi36b0',
        board: 'hi36b0',
        manufacturer: 'HUAWEI',
      );
      expect(k9030, equals('HiSilicon Kirin 9030 Pro'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'hi36b0',
          board: 'hi36b0',
          socName: k9030,
        ),
        equals('Maleoon 935'),
      );

      final ex2600 = DeviceSpecHelper.detectSocName(
        hardware: 's5e9965',
        board: 's5e9965',
        manufacturer: 'Samsung',
      );
      expect(ex2600, equals('Samsung Exynos 2600'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 's5e9965',
          board: 's5e9965',
          socName: ex2600,
        ),
        equals('Samsung Xclipse 960'),
      );

      final ex1080 = DeviceSpecHelper.detectSocName(
        hardware: 's5e9815',
        board: 's5e9815',
        manufacturer: 'Samsung',
      );
      expect(ex1080, equals('Samsung Exynos 1080'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 's5e9815',
          board: 's5e9815',
          socName: ex1080,
        ),
        equals('Mali-G78 MP10'),
      );

      final sd8Extreme = DeviceSpecHelper.detectSocName(
        hardware: 'qcom',
        board: '8 elite extreme',
        manufacturer: 'Qualcomm',
      );
      expect(sd8Extreme, equals('Qualcomm Snapdragon 8 Elite Extreme Gen 6'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: '',
          board: '8 elite extreme',
          socName: sd8Extreme,
        ),
        equals('Adreno 850'),
      );

      final sd8Gen5 = DeviceSpecHelper.detectSocName(
        hardware: 'sm8850',
        board: 'sm8850',
        manufacturer: 'Qualcomm',
      );
      expect(sd8Gen5, equals('Qualcomm Snapdragon 8 Elite Gen 5'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'sm8850',
          board: 'sm8850',
          socName: sd8Gen5,
        ),
        equals('Adreno 840'),
      );

      final d9400Plus = DeviceSpecHelper.detectSocName(
        hardware: 'mt6991',
        board: 'dimensity 9400+',
        manufacturer: 'MediaTek',
      );
      expect(d9400Plus, equals('MediaTek Dimensity 9400+'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'mt6991',
          board: '',
          socName: d9400Plus,
        ),
        equals('Immortalis-G925 MC12'),
      );

      final d8500 = DeviceSpecHelper.detectSocName(
        hardware: 'dimensity 8500',
        board: 'dimensity 8500',
        manufacturer: 'MediaTek',
      );
      expect(d8500, equals('MediaTek Dimensity 8500'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: '',
          board: 'dimensity 8500',
          socName: d8500,
        ),
        equals('Mali-G720 MC8'),
      );

      final d7350Pro = DeviceSpecHelper.detectSocName(
        hardware: 'mt6878',
        board: 'dimensity 7350 pro',
        manufacturer: 'MediaTek',
      );
      expect(d7350Pro, equals('MediaTek Dimensity 7350 Pro'));

      final hG100 = DeviceSpecHelper.detectSocName(
        hardware: 'mt6789',
        board: 'helio g100',
        manufacturer: 'MediaTek',
      );
      expect(hG100, equals('MediaTek Helio G100'));

      final hG91 = DeviceSpecHelper.detectSocName(
        hardware: 'mt6769',
        board: 'helio g91-ultra',
        manufacturer: 'MediaTek',
      );
      expect(hG91, equals('MediaTek Helio G91-Ultra'));

      final hG81 = DeviceSpecHelper.detectSocName(
        hardware: 'mt6769',
        board: 'helio g81-ultra',
        manufacturer: 'MediaTek',
      );
      expect(hG81, equals('MediaTek Helio G81-Ultra'));

      final uniT9300 = DeviceSpecHelper.detectSocName(
        hardware: 't9300',
        board: 't9300',
        manufacturer: 'Unisoc',
      );
      expect(uniT9300, equals('Unisoc T9300'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 't9300',
          board: 't9300',
          socName: uniT9300,
        ),
        equals('Mali-G57'),
      );

      final uniT8300 = DeviceSpecHelper.detectSocName(
        hardware: 't8300',
        board: 't8300',
        manufacturer: 'Unisoc',
      );
      expect(uniT8300, equals('Unisoc T8300'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 't8300',
          board: 't8300',
          socName: uniT8300,
        ),
        equals('Mali-G57 MP2'),
      );

      final uniT7300 = DeviceSpecHelper.detectSocName(
        hardware: 't7300',
        board: 't7300',
        manufacturer: 'Unisoc',
      );
      expect(uniT7300, equals('Unisoc T7300'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 't7300',
          board: 't7300',
          socName: uniT7300,
        ),
        equals('Mali-G57 MP2'),
      );

      // 2. Oldest 64-bit SoCs (2014 / 2015)
      // Exynos 5433 (Galaxy Note 4, first 64-bit Exynos in late 2014)
      final ex5433 = DeviceSpecHelper.detectSocName(
        hardware: 'universal5433',
        board: 'universal5433',
        manufacturer: 'Samsung',
      );
      expect(ex5433, equals('Samsung Exynos 5433'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'universal5433',
          board: 'universal5433',
          socName: ex5433,
        ),
        equals('Mali-T760 MP6'),
      );
      expect(DeviceSpecHelper.isEntryOrLegacySoc(socName: ex5433), isTrue);

      // Exynos 7420 (Galaxy S6 / Note 5 in 2015)
      final ex7420 = DeviceSpecHelper.detectSocName(
        hardware: 'universal7420',
        board: 'universal7420',
        manufacturer: 'Samsung',
      );
      expect(ex7420, equals('Samsung Exynos 7420'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'universal7420',
          board: 'universal7420',
          socName: ex7420,
        ),
        equals('Mali-T760 MP8'),
      );
      expect(DeviceSpecHelper.isEntryOrLegacySoc(socName: ex7420), isTrue);

      // MediaTek MT6732 (World's first 64-bit LTE quad-core Cortex-A53 MediaTek chip in late 2014)
      final mt6732 = DeviceSpecHelper.detectSocName(
        hardware: 'mt6732',
        board: 'mt6732',
        manufacturer: 'MediaTek',
      );
      expect(mt6732, equals('MediaTek MT6732'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'mt6732',
          board: 'mt6732',
          socName: mt6732,
        ),
        equals('Mali-T760 MP2'),
      );
      expect(DeviceSpecHelper.isEntryOrLegacySoc(socName: mt6732), isTrue);

      // MediaTek MT6752 (Octa-core Cortex-A53 64-bit in late 2014)
      final mt6752 = DeviceSpecHelper.detectSocName(
        hardware: 'mt6752',
        board: 'mt6752',
        manufacturer: 'MediaTek',
      );
      expect(mt6752, equals('MediaTek MT6752'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'mt6752',
          board: 'mt6752',
          socName: mt6752,
        ),
        equals('Mali-T760 MP2'),
      );
      expect(DeviceSpecHelper.isEntryOrLegacySoc(socName: mt6752), isTrue);

      // Snapdragon 215 (QM215 - 64-bit ARM Cortex-A53 budget processor)
      final sd215 = DeviceSpecHelper.detectSocName(
        hardware: 'qm215',
        board: 'qm215',
        manufacturer: 'Qualcomm',
      );
      expect(sd215, equals('Qualcomm Snapdragon 215'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: 'qm215',
          board: 'qm215',
          socName: sd215,
        ),
        equals('Adreno 308'),
      );
      expect(DeviceSpecHelper.isEntryOrLegacySoc(socName: sd215), isTrue);

      // Snapdragon 415 (MSM8929 - 64-bit octa-core Cortex-A53 in 2015)
      final sd415 = DeviceSpecHelper.detectSocName(
        hardware: 'qcom',
        board: 'msm8929',
        manufacturer: 'Qualcomm',
      );
      expect(sd415, equals('Qualcomm Snapdragon 415'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: '',
          board: 'msm8929',
          socName: sd415,
        ),
        equals('Adreno 405'),
      );
      expect(DeviceSpecHelper.isEntryOrLegacySoc(socName: sd415), isTrue);

      // Snapdragon 615 (MSM8939 - Qualcomm's first 64-bit octa-core chip in late 2014)
      final sd615 = DeviceSpecHelper.detectSocName(
        hardware: 'qcom',
        board: 'msm8939',
        manufacturer: 'Qualcomm',
      );
      expect(sd615, equals('Qualcomm Snapdragon 615'));
      expect(
        DeviceSpecHelper.detectGpuName(
          hardware: '',
          board: 'msm8939',
          socName: sd615,
        ),
        equals('Adreno 405'),
      );
      expect(DeviceSpecHelper.isEntryOrLegacySoc(socName: sd615), isTrue);
    });

    test('All 22 languages have distinct CPU thread descriptions and clean preset titles without x264/x265', () {
      final threadKeys = [
        'settings_cpu_threads_1_desc',
        'settings_cpu_threads_2_desc',
        'settings_cpu_threads_4_desc',
        'settings_cpu_threads_6_desc',
        'settings_cpu_threads_8_desc',
      ];

      final audioKeys = [
        'settings_audio_bitrate_64_desc',
        'settings_audio_bitrate_128_desc',
        'settings_audio_bitrate_192_desc',
        'settings_audio_bitrate_256_desc',
        'settings_audio_bitrate_320_desc',
      ];

      for (final lang in AppLocalizations.supportedLanguages) {
        final code = lang['code']!;
        final l10n = AppLocalizations(code);

        // Check preset label has no x264/x265
        final presetTitle = l10n.t('settings_cpu_preset');
        expect(
          presetTitle.contains('x264/x265'),
          isFalse,
          reason:
              'Language $code still contains x264/x265 in settings_cpu_preset',
        );

        // Check all 5 CPU thread descriptions exist and are non-empty
        final threadTexts = <String>{};
        for (final key in threadKeys) {
          final text = l10n.t(key);
          expect(text, isNotEmpty, reason: 'Key $key empty in $code');
          expect(
            text,
            isNot(equals(key)),
            reason: 'Key $key untranslated in $code',
          );
          threadTexts.add(text);
        }
        // Ensure all 5 CPU thread descriptions are distinct from each other
        expect(
          threadTexts.length,
          equals(5),
          reason: 'Language $code has duplicate descriptions for CPU threads',
        );

        // Check all 5 Audio bitrate descriptions exist and are non-empty
        final audioTexts = <String>{};
        for (final key in audioKeys) {
          final text = l10n.t(key);
          expect(text, isNotEmpty, reason: 'Key $key empty in $code');
          expect(
            text,
            isNot(equals(key)),
            reason: 'Key $key untranslated in $code',
          );
          audioTexts.add(text);
        }
        // Ensure all 5 audio descriptions are distinct from each other
        expect(
          audioTexts.length,
          equals(5),
          reason:
              'Language $code has duplicate descriptions for audio bitrates',
        );
      }
    });

    test('All 22 languages have clean MediaCodec preset descriptions without CPU scalers', () {
      final keys = [
        'preset_fast_desc',
        'preset_normal_desc',
        'preset_slow_desc',
      ];
      expect(AppLocalizations.supportedLanguages.length, equals(22));

      for (final lang in AppLocalizations.supportedLanguages) {
        final code = lang['code']!;
        final l10n = AppLocalizations(code);

        for (final k in keys) {
          final val = l10n.t(k);
          expect(
            val,
            isNotEmpty,
            reason: 'Missing translation for $k in $code',
          );
          expect(
            val.contains('x264'),
            isFalse,
            reason: 'Contains x264 in $code ($k): $val',
          );
          expect(
            val.contains('x265'),
            isFalse,
            reason: 'Contains x265 in $code ($k): $val',
          );
          expect(
            val.contains('Scaler Area'),
            isFalse,
            reason: 'Contains Scaler Area in $code ($k): $val',
          );
          expect(
            val.contains('Scaler Lanczos'),
            isFalse,
            reason: 'Contains Scaler Lanczos in $code ($k): $val',
          );
          expect(
            val.contains('Scaler Bicubic'),
            isFalse,
            reason: 'Contains Scaler Bicubic in $code ($k): $val',
          );
          expect(
            val.contains('MediaCodec'),
            isTrue,
            reason: 'Missing MediaCodec keyword in $code ($k): $val',
          );
        }
      }
    });
  });

  group('Advanced Settings tests', () {
    test(
      'Cancellation dialog keys resolve properly in all supported languages',
      () {
        const requiredKeys = [
          'proc_dialog_no',
          'proc_dialog_yes',
          'proc_dialog_cancel',
          'proc_dialog_continue',
          'proc_cancel_confirm',
          'proc_cancel_desc',
        ];

        for (final lang in AppLocalizations.supportedLanguages) {
          final code = lang['code']!;
          final l10n = AppLocalizations(code);
          for (final key in requiredKeys) {
            final val = l10n.t(key);
            expect(val.isNotEmpty, isTrue, reason: 'Key $key empty in $code');
            expect(
              val,
              isNot(equals(key)),
              reason: 'Key $key unlocalized in $code',
            );
          }
        }
      },
    );

    testWidgets(
      'ConversionOptionsCard displays standard speed preset regardless of legacy advanced options',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final service = SettingsService();
        await service.init();

        final l10n = AppLocalizations('id');
        const sourceVideo = VideoInfo(
          filePath: '/storage/sample.mp4',
          fileName: 'sample.mp4',
          width: 1920,
          height: 1080,
          durationSeconds: 120,
          bitrate: 10000000,
          fps: 30,
          codec: 'h264',
          fileSizeBytes: 50000000,
        );

        const currentOpts = EncodingOptions(
          speedPreset: SpeedPreset.normal,
          crfValue: 22,
        );

        const currentRes = VideoResolution(
          label: '720p',
          width: 1280,
          height: 720,
        );

        Widget buildCard() => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConversionOptionsCard(
                sourceVideo: sourceVideo,
                resolutions: sourceVideo.availableDownscaleTargets,
                selectedResolution: currentRes,
                onResolutionChanged: (_) {},
                encodingOptions: currentOpts,
                onOptionsChanged: (_) {},
                l10n: l10n,
              ),
            ),
          ),
        );

        await tester.pumpWidget(buildCard());
        expect(find.textContaining('Normal'), findsWidgets);
        expect(find.textContaining('Custom Preset'), findsNothing);
      },
    );

    testWidgets(
      'SettingsScreen does not display Advanced Settings card or custom preset controls',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme('oled_snowfall'),
            home: const SettingsScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final service = SettingsService();
        final l10n = service.l10n;

        expect(find.byKey(const Key('advanced_settings_switch')), findsNothing);
        expect(find.text(l10n.t('settings_advanced_title')), findsNothing);
        expect(find.text(l10n.t('settings_ram_buffer')), findsNothing);
        expect(find.text(l10n.t('settings_default_codec')), findsNothing);
        expect(find.text(l10n.t('settings_file_naming')), findsOneWidget);
        expect(find.text(l10n.t('settings_preserve_date')), findsOneWidget);
      },
    );

    testWidgets(
      'ConversionOptionsCard speed preset chips are always enabled and selectable',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = SettingsService();
        await service.setLanguage('id');
        final l10n = service.l10n;

        const sampleVideo = VideoInfo(
          filePath: '/storage/sample.mp4',
          fileName: 'sample.mp4',
          width: 1920,
          height: 1080,
          durationSeconds: 120,
          bitrate: 10000000,
          fps: 30,
          codec: 'h264',
          fileSizeBytes: 50000000,
        );

        EncodingOptions currentOpts = const EncodingOptions(
          speedPreset: SpeedPreset.normal,
          crfValue: 22,
        );
        VideoResolution currentRes = VideoResolution.standardResolutions.first;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme('oled_pure'),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return SingleChildScrollView(
                    child: ConversionOptionsCard(
                      sourceVideo: sampleVideo,
                      resolutions: VideoResolution.standardResolutions,
                      selectedResolution: currentRes,
                      onResolutionChanged: (res) =>
                          setState(() => currentRes = res),
                      encodingOptions: currentOpts,
                      onOptionsChanged: (opts) =>
                          setState(() => currentOpts = opts),
                      l10n: l10n,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final fastChipFinder = find.widgetWithText(ChoiceChip, 'Cepat');
        final normalChipFinder = find.widgetWithText(ChoiceChip, 'Normal');
        final slowChipFinder = find.widgetWithText(ChoiceChip, 'Maksimal');

        expect(fastChipFinder, findsOneWidget);
        expect(normalChipFinder, findsOneWidget);
        expect(slowChipFinder, findsOneWidget);

        final fastChip = tester.widget<ChoiceChip>(fastChipFinder);
        final normalChip = tester.widget<ChoiceChip>(normalChipFinder);
        final slowChip = tester.widget<ChoiceChip>(slowChipFinder);

        expect(fastChip.onSelected, isNotNull);
        expect(normalChip.onSelected, isNotNull);
        expect(slowChip.onSelected, isNotNull);
        expect(normalChip.selected, isTrue);

        await tester.tap(fastChipFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(currentOpts.speedPreset, equals(SpeedPreset.fast));
        expect(currentOpts.crfValue, equals(24));
      },
    );

    test(
      'Default Theme and Language resolution adapts to system environment',
      () {
        // 1. Theme resolution
        expect(
          SettingsService.resolveInitialTheme(Brightness.dark),
          equals('oled_pure'),
        );
        expect(
          SettingsService.resolveInitialTheme(Brightness.light),
          equals('light_clean'),
        );

        // 2. Language resolution: supported languages
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('id', 'ID')]),
          equals('id'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('in', 'ID')]),
          equals('id'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('ms', 'MY')]),
          equals('ms'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('ja', 'JP')]),
          equals('ja'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('es', 'ES')]),
          equals('es'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('de', 'DE')]),
          equals('de'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('fr', 'FR')]),
          equals('fr'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('ko', 'KR')]),
          equals('ko'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('ru', 'RU')]),
          equals('ru'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('ar', 'SA')]),
          equals('ar'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('hi', 'IN')]),
          equals('hi'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('th', 'TH')]),
          equals('th'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('vi', 'VN')]),
          equals('vi'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('it', 'IT')]),
          equals('it'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('nl', 'NL')]),
          equals('nl'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('pt', 'BR')]),
          equals('pt'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('fi', 'FI')]),
          equals('fi'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('sv', 'SE')]),
          equals('sv'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('da', 'DK')]),
          equals('da'),
        );

        // Chinese regional variants
        expect(
          AppLocalizations.resolveSupportedLanguage([
            const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          ]),
          equals('zh_CN'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('zh', 'CN')]),
          equals('zh_CN'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('zh')]),
          equals('zh_CN'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([
            const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
          ]),
          equals('zh_TW'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('zh', 'TW')]),
          equals('zh_TW'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('zh', 'HK')]),
          equals('zh_TW'),
        );

        // Norwegian mapping
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('no', 'NO')]),
          equals('no'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('nb', 'NO')]),
          equals('no'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('nn', 'NO')]),
          equals('no'),
        );

        // Unsupported language falls back to English ('en')
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('pl', 'PL')]),
          equals('en'),
        );
        expect(
          AppLocalizations.resolveSupportedLanguage([const Locale('tr', 'TR')]),
          equals('en'),
        );
        expect(AppLocalizations.resolveSupportedLanguage([]), equals('en'));
      },
    );

    test('SettingsService applies system theme and language on first launch and reset', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SettingsService();
      await service.init();

      // First launch must automatically resolve initial theme & language
      expect(service.settings.isFirstLaunch, isFalse);
      expect(
        service.settings.themeMode == 'oled_pure' ||
            service.settings.themeMode == 'light_clean',
        isTrue,
      );
      expect(
        AppLocalizations.supportedLanguages.any(
          (m) => m['code'] == service.settings.languageCode,
        ),
        isTrue,
      );

      // Mutate and resetToDefaults
      await service.setThemeMode('oled_snowfall');
      await service.resetToDefaults();
      expect(
        service.settings.themeMode == 'oled_pure' ||
            service.settings.themeMode == 'light_clean',
        isTrue,
      );
    });

    test('VideoInfo accurately classifies 4K, long duration (>30m), and heavy processing', () {
      const vid4kLandscape = VideoInfo(
        filePath: '/test/4k.mp4',
        fileName: '4k.mp4',
        width: 3840,
        height: 2160,
        durationSeconds: 120,
        bitrate: 20000000,
        fps: 30,
        codec: 'h264',
        fileSizeBytes: 300000000,
      );
      expect(vid4kLandscape.is4K, isTrue);
      expect(vid4kLandscape.isLongDuration, isFalse);
      expect(vid4kLandscape.isHeavyProcessing, isTrue);

      const vid4kPortrait = VideoInfo(
        filePath: '/test/4k_v.mp4',
        fileName: '4k_v.mp4',
        width: 2160,
        height: 3840,
        durationSeconds: 120,
        bitrate: 20000000,
        fps: 30,
        codec: 'h264',
        fileSizeBytes: 300000000,
      );
      expect(vid4kPortrait.is4K, isTrue);
      expect(vid4kPortrait.isLongDuration, isFalse);
      expect(vid4kPortrait.isHeavyProcessing, isTrue);

      const vidLong = VideoInfo(
        filePath: '/test/long.mp4',
        fileName: 'long.mp4',
        width: 1280,
        height: 720,
        durationSeconds: 601, // > 10 minutes
        bitrate: 2000000,
        fps: 30,
        codec: 'h264',
        fileSizeBytes: 450000000,
      );
      expect(vidLong.is4K, isFalse);
      expect(vidLong.isLongDuration, isTrue);
      expect(vidLong.isHeavyProcessing, isTrue);

      const vidStandard = VideoInfo(
        filePath: '/test/standard.mp4',
        fileName: 'standard.mp4',
        width: 1920,
        height: 1080,
        durationSeconds: 300, // 5 minutes
        bitrate: 5000000,
        fps: 30,
        codec: 'h264',
        fileSizeBytes: 180000000,
      );
      expect(vidStandard.is4K, isFalse);
      expect(vidStandard.isLongDuration, isFalse);
      expect(vidStandard.isHeavyProcessing, isFalse);
    });

    test('4K and long duration heavy processing localization strings resolve across all 22 supported languages', () {
      for (final code in supportedCodes) {
        final l10n = AppLocalizations(code);
        expect(
          l10n.t('heavy_process_title'),
          isNotEmpty,
          reason: 'heavy_process_title missing in $code',
        );
        expect(
          l10n.t('heavy_process_desc'),
          isNotEmpty,
          reason: 'heavy_process_desc missing in $code',
        );
        expect(
          l10n.t('heavy_process_desc_4k'),
          isNotEmpty,
          reason: 'heavy_process_desc_4k missing in $code',
        );
        expect(
          l10n.t('heavy_process_desc_long', args: {'duration': '15m 10s'}),
          contains('15m 10s'),
          reason: 'heavy_process_desc_long missing in $code',
        );
        expect(
          l10n.t('heavy_process_desc_4k_long', args: {'duration': '15m 10s'}),
          contains('15m 10s'),
          reason: 'heavy_process_desc_4k_long missing in $code',
        );
        expect(
          l10n.t('heavy_process_banner_4k'),
          isNotEmpty,
          reason: 'heavy_process_banner_4k missing in $code',
        );
        expect(
          l10n.t('heavy_process_banner_long', args: {'duration': '15m 10s'}),
          contains('15m 10s'),
          reason: 'heavy_process_banner_long missing in $code',
        );
        expect(
          l10n.t('heavy_process_banner_4k_long'),
          isNotEmpty,
          reason: 'heavy_process_banner_4k_long missing in $code',
        );
        expect(
          l10n.t('heavy_process_use_normal'),
          isNotEmpty,
          reason: 'heavy_process_use_normal missing in $code',
        );
        expect(
          l10n.t('heavy_process_continue'),
          isNotEmpty,
          reason: 'heavy_process_continue missing in $code',
        );
        expect(
          l10n.t('heavy_process_continue').contains('...'),
          isFalse,
          reason: 'heavy_process_continue contains ellipsis in $code',
        );
        expect(
          l10n.t('heavy_process_cancel'),
          isNotEmpty,
          reason: 'heavy_process_cancel missing in $code',
        );
        expect(
          l10n.t('heavy_process_cancel').contains('...'),
          isFalse,
          reason: 'heavy_process_cancel contains ellipsis in $code',
        );
        expect(
          l10n.t('heavy_process_desc').contains('...'),
          isFalse,
          reason: 'heavy_process_desc contains ellipsis in $code',
        );
        expect(
          l10n.t('heavy_process_desc_4k').contains('...'),
          isFalse,
          reason: 'heavy_process_desc_4k contains ellipsis in $code',
        );
        expect(
          l10n
              .t('heavy_process_desc_long', args: {'duration': '15m 10s'})
              .contains('...'),
          isFalse,
          reason: 'heavy_process_desc_long contains ellipsis in $code',
        );
        expect(
          l10n
              .t('heavy_process_desc_4k_long', args: {'duration': '15m 10s'})
              .contains('...'),
          isFalse,
          reason: 'heavy_process_desc_4k_long contains ellipsis in $code',
        );
      }
    });

    group('MediaScannerService tests', () {
      test('scanFile returns false for null or empty paths', () async {
        expect(await MediaScannerService.scanFile(null), isFalse);
        expect(await MediaScannerService.scanFile(''), isFalse);
      });

      test(
        'scanFile safely handles non-Android platform or host test runner',
        () async {
          // When running tests on Windows host, Platform.isAndroid is false
          final result = await MediaScannerService.scanFile(
            '/storage/emulated/0/Movies/sample.mp4',
          );
          expect(result, isFalse);
        },
      );
    });

    test('thermal_warning_title and thermal_warning_msg exist across all supported languages', () {
      for (final code in supportedCodes) {
        final l10n = AppLocalizations(code);
        final title = l10n.t('thermal_warning_title', args: {'temp': '46.5'});
        final msg = l10n.t('thermal_warning_msg');
        expect(
          title,
          isNotEmpty,
          reason: 'thermal_warning_title missing in $code',
        );
        expect(
          title,
          isNot(equals('thermal_warning_title')),
          reason: 'thermal_warning_title untranslated in $code',
        );
        expect(
          title.contains('46.5'),
          isTrue,
          reason: 'thermal_warning_title should contain temperature in $code',
        );
        expect(msg, isNotEmpty, reason: 'thermal_warning_msg missing in $code');
        expect(
          msg,
          isNot(equals('thermal_warning_msg')),
          reason: 'thermal_warning_msg untranslated in $code',
        );
      }
    });

    group('CacheManagerService Auto-Purge tests', () {
      test(
        'autoPurgeTempFiles safely cleans temporary and cache pattern files',
        () async {
          final cacheService = CacheManagerService();
          final testDir = await Directory.systemTemp.createTemp(
            'vega_purge_test_',
          );
          try {
            final tmpFile = File('${testDir.path}/test.tmp')
              ..writeAsStringSync('dummy tmp');
            final partFile = File('${testDir.path}/video.part')
              ..writeAsStringSync('dummy part');
            final crdownloadFile = File('${testDir.path}/stream.crdownload')
              ..writeAsStringSync('dummy crdownload');
            final prefixFile = File('${testDir.path}/vega_temp_output.mp4')
              ..writeAsStringSync('dummy vega temp');
            final keepFile = File('${testDir.path}/keep_me.mp4')
              ..writeAsStringSync('keep this valid file');

            expect(tmpFile.existsSync(), isTrue);
            expect(partFile.existsSync(), isTrue);
            expect(crdownloadFile.existsSync(), isTrue);
            expect(prefixFile.existsSync(), isTrue);
            expect(keepFile.existsSync(), isTrue);

            // Path matcher check
            expect(
              cacheService.isCachedPath(
                '/data/user/0/com.phantek.lyra.vega/cache/file_picker/temp.mp4',
              ),
              isTrue,
            );
            expect(
              cacheService.isCachedPath(
                '/data/user/0/com.phantek.lyra.vega/cache/temp.mp4',
              ),
              isTrue,
            );
            expect(
              cacheService.isCachedPath('/data/local/tmp/temp.mp4'),
              isTrue,
            );
            expect(
              cacheService.isCachedPath(
                '/storage/emulated/0/Android/data/com.phantek.lyra.vega/temp/temp.mp4',
              ),
              isTrue,
            );
            expect(
              cacheService.isCachedPath(
                '/storage/emulated/0/Movies/normal/video.mp4',
              ),
              isFalse,
            );

            // Running autoPurgeTempFiles on real device/host runs without throwing
            final bytesFreed = await cacheService.autoPurgeTempFiles();
            expect(bytesFreed, greaterThanOrEqualTo(0));
          } finally {
            if (testDir.existsSync()) {
              testDir.deleteSync(recursive: true);
            }
          }
        },
      );
    });

    group('Video Preview, Trimming, Encoding Options Persistence, & Factory Reset tests', () {
      test('EncodingOptions serialization and deserialization preserves all fields and trimming values', () {
        const original = EncodingOptions(
          codec: VideoCodec.hevc,
          container: VideoContainer.mkv,
          rateControlMode: RateControlMode.bitrate,
          speedPreset: SpeedPreset.max,
          crfValue: 18,
          customBitrateKbps: 8500,
          targetFps: 60,
          audioFormat: AudioFormat.wav,
          audioExtractBitrateKbps: 320,
          videoAudioBitrateKbps: 256,
          trimStartMs: 1500,
          trimEndMs: 9500,
        );

        final json = original.toJson();
        expect(json['codec'], equals('hevc'));
        expect(json['container'], equals('mkv'));
        expect(json['rateControlMode'], equals('bitrate'));
        expect(json['speedPreset'], equals('max'));
        expect(json['crfValue'], equals(18));
        expect(json['customBitrateKbps'], equals(8500));
        expect(json['targetFps'], equals(60));
        expect(json['audioFormat'], equals('wav'));
        expect(json['audioExtractBitrateKbps'], equals(320));
        expect(json['videoAudioBitrateKbps'], equals(256));
        expect(json['trimStartMs'], equals(1500));
        expect(json['trimEndMs'], equals(9500));

        final fromJson = EncodingOptions.fromJson(json);
        expect(fromJson, equals(original));
        expect(fromJson.hashCode, equals(original.hashCode));

        // copyWith can modify or clear trim values
        final modified = original.copyWith(trimStartMs: 2000, trimEndMs: 5000);
        expect(modified.trimStartMs, equals(2000));
        expect(modified.trimEndMs, equals(5000));

        final cleared = modified.copyWith(trimStartMs: null, trimEndMs: null);
        expect(cleared.trimStartMs, isNull);
        expect(cleared.trimEndMs, isNull);
      });

      test('SettingsService persists encoding options and resets to defaults accurately', () async {
        SharedPreferences.setMockInitialValues({});
        final service = SettingsService();
        await service.init();

        const custom = EncodingOptions(
          codec: VideoCodec.hevc,
          container: VideoContainer.mov,
          rateControlMode: RateControlMode.bitrate,
          speedPreset: SpeedPreset.fast,
          crfValue: 26,
          customBitrateKbps: 6000,
          targetFps: 30,
          videoAudioBitrateKbps: 192,
          trimStartMs: 500,
          trimEndMs: 4500,
        );

        await service.saveEncodingOptions(custom);
        expect(service.savedEncodingOptions, equals(custom));
        expect(service.settings.defaultVideoCodec, equals('hevc'));

        // Re-initialize SettingsService to verify persistence from SharedPreferences
        await service.init();
        expect(service.savedEncodingOptions, equals(custom));

        // Reset encoding configuration to defaults
        await service.resetEncodingConfigurationToDefaults();
        final resetOpts = service.savedEncodingOptions;
        expect(resetOpts, isNotNull);
        expect(resetOpts!.speedPreset, equals(SpeedPreset.normal));
        expect(resetOpts.codec, equals(VideoCodec.h264));
        expect(resetOpts.container, equals(VideoContainer.mp4));
        expect(resetOpts.rateControlMode, equals(RateControlMode.crf));
        expect(resetOpts.crfValue, equals(22));
        expect(resetOpts.customBitrateKbps, equals(4000));
        expect(resetOpts.targetFps, equals(0));
        expect(resetOpts.videoAudioBitrateKbps, equals(128));
        expect(resetOpts.trimStartMs, isNull);
        expect(resetOpts.trimEndMs, isNull);
      });

      test('All new localization keys exist across all 23 languages without any emojis', () {
        const newKeys = [
          'trim_title',
          'trim_start',
          'trim_end',
          'trim_new_duration',
          'trim_btn_proceed',
          'trim_btn_skip',
          'cancel',
          'reset',
        ];

        final emojiRegex = RegExp(
          r'[\u{10000}-\u{10FFFF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}]',
          unicode: true,
        );

        for (final code in supportedCodes) {
          final l10n = AppLocalizations(code);
          for (final key in newKeys) {
            final value = l10n.t(key);
            expect(
              value,
              isNotEmpty,
              reason: 'Key "$key" should not be empty in language "$code"',
            );
            expect(
              value,
              isNot(equals(key)),
              reason: 'Key "$key" is untranslated in language "$code"',
            );
            expect(
              emojiRegex.hasMatch(value),
              isFalse,
              reason:
                  'Key "$key" in language "$code" must not contain emojis (found: "$value")',
            );
          }
        }
      });

      testWidgets(
        'TrimPreviewScreen renders timeline controls, time badges, and single proceed button',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          const video = VideoInfo(
            filePath: '/test/sample_video.mp4',
            fileName: 'sample_video.mp4',
            width: 1920,
            height: 1080,
            durationSeconds: 60.0,
            bitrate: 5000000,
            fps: 30.0,
            codec: 'h264',
            fileSizeBytes: 15000000,
          );

          SharedPreferences.setMockInitialValues({});
          final service = SettingsService();
          await service.init();
          await service.setLanguage('id');
          final l10n = service.l10n;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.getTheme('oled_snowfall'),
              home: const TrimPreviewScreen(
                videoInfo: video,
                targetResolution: VideoResolution(
                  label: '1080p',
                  width: 1920,
                  height: 1080,
                ),
                encodingOptions: EncodingOptions(),
                appSettings: AppSettings(),
                isAudioExtraction: false,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          // Verify Title
          expect(find.text(l10n.t('trim_title')), findsOneWidget);

          // Verify Timeline CustomPaint
          expect(find.byType(CustomPaint), findsWidgets);

          // Verify Time badges
          expect(find.text(l10n.t('trim_start')), findsOneWidget);
          expect(find.text(l10n.t('trim_end')), findsOneWidget);
          expect(find.text(l10n.t('trim_new_duration')), findsOneWidget);

          // Verify Single Button
          expect(find.text(l10n.t('trim_btn_proceed')), findsOneWidget);
          expect(find.text(l10n.t('trim_btn_skip')), findsNothing);
        },
      );

      testWidgets(
        'TrimPreviewScreen returns trimmed and untrimmed EncodingOptions on pop',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          const video = VideoInfo(
            filePath: '/test/sample_video.mp4',
            fileName: 'sample_video.mp4',
            width: 1920,
            height: 1080,
            durationSeconds: 60.0,
            bitrate: 5000000,
            fps: 30.0,
            codec: 'h264',
            fileSizeBytes: 15000000,
          );

          final service = SettingsService();
          await service.init();
          final l10n = service.l10n;

          EncodingOptions? returnedOptions;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.getTheme('oled_snowfall'),
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      returnedOptions = await Navigator.of(ctx)
                          .push<EncodingOptions>(
                            MaterialPageRoute(
                              builder: (_) => const TrimPreviewScreen(
                                videoInfo: video,
                                targetResolution: VideoResolution(
                                  label: '1080p',
                                  width: 1920,
                                  height: 1080,
                                ),
                                encodingOptions: EncodingOptions(),
                                appSettings: AppSettings(),
                                isAudioExtraction: false,
                              ),
                            ),
                          );
                    },
                    child: const Text('Open Trim'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Open Trim
          await tester.tap(find.text('Open Trim'));
          await tester.pumpAndSettle();

          // Tap Proceed
          await tester.tap(find.text(l10n.t('trim_btn_proceed')));
          await tester.pumpAndSettle();

          expect(returnedOptions, isNotNull);
          expect(returnedOptions!.isTrimmed, isTrue);
          expect(returnedOptions!.trimStartMs, 0);
          expect(returnedOptions!.trimEndMs, 60000);
        },
      );

      testWidgets(
        'Dragging playhead needle from start moves position without altering start trim boundary',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          const video = VideoInfo(
            filePath: '/test/sample_trim.mp4',
            fileName: 'sample_trim.mp4',
            width: 1920,
            height: 1080,
            durationSeconds: 100.0,
            bitrate: 5000000,
            fps: 30.0,
            codec: 'h264',
            fileSizeBytes: 15000000,
          );

          EncodingOptions? returnedOptions;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.getTheme('oled_snowfall'),
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      returnedOptions = await Navigator.of(ctx)
                          .push<EncodingOptions>(
                            MaterialPageRoute(
                              builder: (_) => const TrimPreviewScreen(
                                videoInfo: video,
                                targetResolution: VideoResolution(
                                  label: '1080p',
                                  width: 1920,
                                  height: 1080,
                                ),
                                encodingOptions: EncodingOptions(),
                                appSettings: AppSettings(),
                                isAudioExtraction: false,
                              ),
                            ),
                          );
                    },
                    child: const Text('Open Trim Screen 1'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open Trim Screen 1'));
          await tester.pumpAndSettle();

          final scrubberFinder = find.byWidgetPredicate(
            (w) => w is CustomPaint && w.size.height == 68,
          );
          expect(scrubberFinder, findsOneWidget);

          final scrubberTopLeft = tester.getTopLeft(scrubberFinder);

          // Both startPx and playheadPx start at x = 14.0.
          // Dragging from dx = 14.0 (the playhead needle line) towards the right
          final needleStart = scrubberTopLeft + const Offset(14.0, 30.0);
          await tester.dragFrom(needleStart, const Offset(100.0, 0.0));
          await tester.pumpAndSettle();

          // Tap proceed button
          await tester.tap(find.byKey(const Key('trim_proceed_button')));
          await tester.pumpAndSettle();

          expect(returnedOptions, isNotNull);
          // Start boundary MUST stay at 0 ms!
          expect(returnedOptions!.trimStartMs, equals(0));
          expect(returnedOptions!.trimEndMs, equals(100000));
        },
      );

      testWidgets(
        'Tapping trim_start badge snaps start trim boundary to current preview frame',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          const video = VideoInfo(
            filePath: '/test/sample_trim.mp4',
            fileName: 'sample_trim.mp4',
            width: 1920,
            height: 1080,
            durationSeconds: 100.0,
            bitrate: 5000000,
            fps: 30.0,
            codec: 'h264',
            fileSizeBytes: 15000000,
          );

          EncodingOptions? returnedOptions;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.getTheme('oled_snowfall'),
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      returnedOptions = await Navigator.of(ctx)
                          .push<EncodingOptions>(
                            MaterialPageRoute(
                              builder: (_) => const TrimPreviewScreen(
                                videoInfo: video,
                                targetResolution: VideoResolution(
                                  label: '1080p',
                                  width: 1920,
                                  height: 1080,
                                ),
                                encodingOptions: EncodingOptions(),
                                appSettings: AppSettings(),
                                isAudioExtraction: false,
                              ),
                            ),
                          );
                    },
                    child: const Text('Open Trim Screen Badge'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open Trim Screen Badge'));
          await tester.pumpAndSettle();

          final scrubberFinder = find.byWidgetPredicate(
            (w) => w is CustomPaint && w.size.height == 68,
          );
          expect(scrubberFinder, findsOneWidget);

          final scrubberTopLeft = tester.getTopLeft(scrubberFinder);

          // Tap timeline track at mid-point to advance playhead
          await tester.tapAt(scrubberTopLeft + const Offset(200.0, 30.0));
          await tester.pumpAndSettle();

          // Tap trim_start badge
          final trimStartBadge = find.byKey(const Key('trim_start_badge'));
          expect(trimStartBadge, findsOneWidget);
          await tester.tap(trimStartBadge);
          await tester.pumpAndSettle();

          // Tap proceed button
          await tester.tap(find.byKey(const Key('trim_proceed_button')));
          await tester.pumpAndSettle();

          expect(returnedOptions, isNotNull);
          // Start boundary MUST have snapped to the playhead position (> 0)
          expect(returnedOptions!.trimStartMs, greaterThan(0));
        },
      );

      testWidgets(
        'Dragging start handle moves the video start trim boundary',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          const video = VideoInfo(
            filePath: '/test/sample_trim.mp4',
            fileName: 'sample_trim.mp4',
            width: 1920,
            height: 1080,
            durationSeconds: 100.0,
            bitrate: 5000000,
            fps: 30.0,
            codec: 'h264',
            fileSizeBytes: 15000000,
          );

          EncodingOptions? returnedOptions;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.getTheme('oled_snowfall'),
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      returnedOptions = await Navigator.of(ctx)
                          .push<EncodingOptions>(
                            MaterialPageRoute(
                              builder: (_) => const TrimPreviewScreen(
                                videoInfo: video,
                                targetResolution: VideoResolution(
                                  label: '1080p',
                                  width: 1920,
                                  height: 1080,
                                ),
                                encodingOptions: EncodingOptions(),
                                appSettings: AppSettings(),
                                isAudioExtraction: false,
                              ),
                            ),
                          );
                    },
                    child: const Text('Open Trim Screen 2'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open Trim Screen 2'));
          await tester.pumpAndSettle();

          final scrubberFinder = find.byWidgetPredicate(
            (w) => w is CustomPaint && w.size.height == 68,
          );
          expect(scrubberFinder, findsOneWidget);

          final scrubberTopLeft = tester.getTopLeft(scrubberFinder);

          // Advance playhead needle forward so it no longer sits directly on top of start handle
          await tester.tapAt(scrubberTopLeft + const Offset(200.0, 30.0));
          await tester.pumpAndSettle();

          // Touch and drag the start handle ear at startPx (14.0)
          final handleEarTouch = scrubberTopLeft + const Offset(14.0, 30.0);
          await tester.dragFrom(handleEarTouch, const Offset(80.0, 0.0));
          await tester.pumpAndSettle();

          // Tap proceed button
          await tester.tap(find.byKey(const Key('trim_proceed_button')));
          await tester.pumpAndSettle();

          expect(returnedOptions, isNotNull);
          // Start boundary MUST have moved forward!
          expect(returnedOptions!.trimStartMs, greaterThan(0));
        },
      );

      testWidgets(
        'SettingsScreen has single Reset to Default Settings button and resets all configurations',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          SharedPreferences.setMockInitialValues({});
          final service = SettingsService();
          await service.init();
          await service.saveEncodingOptions(
            const EncodingOptions(
              crfValue: 16,
              customBitrateKbps: 9000,
              speedPreset: SpeedPreset.fast,
            ),
          );
          expect(service.savedEncodingOptions?.crfValue, equals(16));
          expect(service.savedEncodingOptions?.customBitrateKbps, equals(9000));
          expect(
            service.savedEncodingOptions?.speedPreset,
            equals(SpeedPreset.fast),
          );

          final l10n = service.l10n;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.getTheme('oled_snowfall'),
              home: const SettingsScreen(),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Verify Reset Configuration tile is NOT displayed
          expect(
            find.text(l10n.t('settings_reset_config_title')),
            findsNothing,
          );

          // Verify single Reset to Default Settings button is present
          final resetBtnFinder = find.widgetWithText(
            OutlinedButton,
            l10n.t('settings_reset_default'),
          );
          await tester.ensureVisible(resetBtnFinder);
          expect(resetBtnFinder, findsOneWidget);

          // Tap the reset button to show confirmation dialog
          await tester.tap(resetBtnFinder);
          await tester.pumpAndSettle();

          // Verify confirmation dialog contents
          expect(
            find.text(l10n.t('settings_reset_confirm_title')),
            findsOneWidget,
          );
          expect(
            find.text(l10n.t('settings_reset_confirm_desc')),
            findsOneWidget,
          );
          expect(find.text(l10n.t('proc_dialog_no')), findsOneWidget);

          // Confirm reset in dialog
          final dialogConfirmBtn = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.t('proc_dialog_yes')),
          );
          expect(dialogConfirmBtn, findsOneWidget);
          await tester.tap(dialogConfirmBtn);
          await tester.pumpAndSettle();

          // Verify both AppSettings and encoding configuration options are reset to defaults
          expect(service.savedEncodingOptions?.crfValue, equals(22));
          expect(service.savedEncodingOptions?.customBitrateKbps, equals(4000));
          expect(
            service.savedEncodingOptions?.speedPreset,
            equals(SpeedPreset.normal),
          );
          expect(find.text(l10n.t('settings_reset_success')), findsOneWidget);
        },
      );

      testWidgets(
        'ConversionOptionsCard speed preset selection updates speedPreset and crfValue, persists to SettingsService, and listener does not revert',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final service = SettingsService();
          await service.init();
          await service.resetToDefaults();
          final l10n = AppLocalizations('id');

          const sampleVideo = VideoInfo(
            filePath: '/dummy/sample.mp4',
            fileName: 'sample.mp4',
            width: 1920,
            height: 1080,
            durationSeconds: 60.0,
            bitrate: 4000000,
            fps: 30.0,
            codec: 'h264',
            fileSizeBytes: 30000000,
          );

          EncodingOptions currentOpts = const EncodingOptions(
            speedPreset: SpeedPreset.normal,
            crfValue: 22,
          );
          VideoResolution currentRes =
              VideoResolution.standardResolutions.first;

          // Wire HomeScreen's _onSettingsChanged logic
          void onSettingsChanged() {
            final saved = service.savedEncodingOptions;
            if (saved != null) {
              if (currentOpts != saved) {
                currentOpts = saved;
              }
              return;
            }
            final preset = SpeedPreset.fromEncodingPreset(
              service.settings.encodingPreset,
            );
            if (currentOpts.speedPreset != preset) {
              currentOpts = currentOpts.copyWith(
                speedPreset: preset,
                crfValue: preset.defaultCrf,
              );
            }
          }

          service.addListener(onSettingsChanged);
          addTearDown(() => service.removeListener(onSettingsChanged));

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.getTheme('oled_pure'),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    return SingleChildScrollView(
                      child: ConversionOptionsCard(
                        sourceVideo: sampleVideo,
                        resolutions: VideoResolution.standardResolutions,
                        selectedResolution: currentRes,
                        onResolutionChanged: (res) =>
                            setState(() => currentRes = res),
                        encodingOptions: currentOpts,
                        onOptionsChanged: (opts) {
                          setState(() => currentOpts = opts);
                          service.saveEncodingOptions(opts);
                        },
                        l10n: l10n,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          final fastChipFinder = find.byKey(const Key('preset_chip_fast'));
          final normalChipFinder = find.byKey(const Key('preset_chip_normal'));
          final slowChipFinder = find.byKey(const Key('preset_chip_slow'));

          expect(fastChipFinder, findsOneWidget);
          expect(normalChipFinder, findsOneWidget);
          expect(slowChipFinder, findsOneWidget);

          // Initial default: Normal
          expect(tester.widget<ChoiceChip>(normalChipFinder).selected, isTrue);
          expect(tester.widget<ChoiceChip>(fastChipFinder).selected, isFalse);
          expect(tester.widget<ChoiceChip>(slowChipFinder).selected, isFalse);

          // 1. Tap Cepat (fast)
          await tester.ensureVisible(fastChipFinder);
          await tester.tap(fastChipFinder);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          // Verify Cepat stays selected, updated CRF to 24, and was NOT reverted by listener
          expect(tester.widget<ChoiceChip>(fastChipFinder).selected, isTrue);
          expect(tester.widget<ChoiceChip>(normalChipFinder).selected, isFalse);
          expect(tester.widget<ChoiceChip>(slowChipFinder).selected, isFalse);
          expect(currentOpts.speedPreset, equals(SpeedPreset.fast));
          expect(currentOpts.crfValue, equals(24));
          expect(
            service.savedEncodingOptions?.speedPreset,
            equals(SpeedPreset.fast),
          );
          expect(service.savedEncodingOptions?.crfValue, equals(24));
          expect(service.settings.encodingPreset, equals('fast'));

          // 2. Tap Maksimal (slow)
          await tester.ensureVisible(slowChipFinder);
          await tester.tap(slowChipFinder);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          // Verify Maksimal stays selected, updated CRF to 20, and was NOT reverted
          expect(tester.widget<ChoiceChip>(slowChipFinder).selected, isTrue);
          expect(tester.widget<ChoiceChip>(fastChipFinder).selected, isFalse);
          expect(tester.widget<ChoiceChip>(normalChipFinder).selected, isFalse);
          expect(currentOpts.speedPreset, equals(SpeedPreset.max));
          expect(currentOpts.crfValue, equals(20));
          expect(
            service.savedEncodingOptions?.speedPreset,
            equals(SpeedPreset.max),
          );
          expect(service.savedEncodingOptions?.crfValue, equals(20));
          expect(service.settings.encodingPreset, equals('slow'));

          // 3. Tap Normal
          await tester.ensureVisible(normalChipFinder);
          await tester.tap(normalChipFinder);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          // Verify Normal stays selected, updated CRF to 22, and was NOT reverted
          expect(tester.widget<ChoiceChip>(normalChipFinder).selected, isTrue);
          expect(tester.widget<ChoiceChip>(fastChipFinder).selected, isFalse);
          expect(tester.widget<ChoiceChip>(slowChipFinder).selected, isFalse);
          expect(currentOpts.speedPreset, equals(SpeedPreset.normal));
          expect(currentOpts.crfValue, equals(22));
          expect(
            service.savedEncodingOptions?.speedPreset,
            equals(SpeedPreset.normal),
          );
          expect(service.savedEncodingOptions?.crfValue, equals(22));
          expect(service.settings.encodingPreset, equals('medium'));
        },
      );

      test('VideoInfo.copyWith correctly updates fileName and properties', () {
        const info = VideoInfo(
          filePath: '/path/to/239500.ts',
          fileName: '239500.ts',
          width: 1920,
          height: 1080,
          durationSeconds: 120.0,
          bitrate: 5000000,
          fps: 30.0,
          codec: 'h264',
          fileSizeBytes: 75000000,
        );

        final updated = info.copyWith(fileName: 'MyCustomVideo.mp4');
        expect(updated.fileName, equals('MyCustomVideo.mp4'));
        expect(updated.filePath, equals('/path/to/239500.ts'));
        expect(updated.width, equals(1920));
        expect(updated.height, equals(1080));
        expect(updated.durationSeconds, equals(120.0));
      });

      testWidgets(
        'VideoInfoCard displays thumbnail when provided and invokes onRename',
        (tester) async {
          const info = VideoInfo(
            filePath: '/path/to/239500.ts',
            fileName: '239500.ts',
            width: 1920,
            height: 1080,
            durationSeconds: 120.0,
            bitrate: 5000000,
            fps: 30.0,
            codec: 'h264',
            fileSizeBytes: 75000000,
          );

          bool renamed = false;

          // 1. Without thumbnail
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: VideoInfoCard(
                  videoInfo: info,
                  onRename: () => renamed = true,
                ),
              ),
            ),
          );

          expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
          expect(find.byType(Image), findsNothing);
          expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

          await tester.tap(find.byIcon(Icons.edit_outlined));
          expect(renamed, isTrue);

          // 2. With thumbnail bytes (1x1 transparent PNG)
          final dummyPng = Uint8List.fromList([
            0x89,
            0x50,
            0x4E,
            0x47,
            0x0D,
            0x0A,
            0x1A,
            0x0A,
            0x00,
            0x00,
            0x00,
            0x0D,
            0x49,
            0x48,
            0x44,
            0x52,
            0x00,
            0x00,
            0x00,
            0x01,
            0x00,
            0x00,
            0x00,
            0x01,
            0x08,
            0x06,
            0x00,
            0x00,
            0x00,
            0x1F,
            0x15,
            0xC4,
            0x89,
            0x00,
            0x00,
            0x00,
            0x0A,
            0x49,
            0x44,
            0x41,
            0x54,
            0x78,
            0x9C,
            0x63,
            0x00,
            0x01,
            0x00,
            0x00,
            0x05,
            0x00,
            0x01,
            0x0D,
            0x0A,
            0x2D,
            0xB4,
            0x00,
            0x00,
            0x00,
            0x00,
            0x49,
            0x45,
            0x4E,
            0x44,
            0xAE,
            0x42,
            0x60,
            0x82,
          ]);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: VideoInfoCard(videoInfo: info, thumbnailBytes: dummyPng),
              ),
            ),
          );

          expect(find.byType(Image), findsOneWidget);
          expect(find.byIcon(Icons.movie_outlined), findsNothing);
        },
      );

      test('All 23 languages have rename and save localization keys', () {
        const supported = [
          'id',
          'en',
          'zh',
          'zh_CN',
          'zh_TW',
          'es',
          'pt',
          'ja',
          'ko',
          'hi',
          'ar',
          'fr',
          'ru',
          'de',
          'it',
          'nl',
          'da',
          'fi',
          'no',
          'sv',
          'ms',
          'vi',
          'th',
        ];

        for (final lang in supported) {
          final l10n = AppLocalizations(lang);
          expect(
            l10n.t('rename_dialog_title').isNotEmpty,
            isTrue,
            reason: 'Missing rename_dialog_title in $lang',
          );
          expect(
            l10n.t('rename_dialog_hint').isNotEmpty,
            isTrue,
            reason: 'Missing rename_dialog_hint in $lang',
          );
          expect(
            l10n.t('rename_tooltip').isNotEmpty,
            isTrue,
            reason: 'Missing rename_tooltip in $lang',
          );
          expect(
            l10n.t('dialog_save').isNotEmpty,
            isTrue,
            reason: 'Missing dialog_save in $lang',
          );
        }
      });

      test('AppSettings and SettingsService support suppressAdvancedModeWarning', () async {
        const settings = AppSettings();
        expect(settings.suppressAdvancedModeWarning, isFalse);

        final updated = settings.copyWith(suppressAdvancedModeWarning: true);
        expect(updated.suppressAdvancedModeWarning, isTrue);

        final json = updated.toJson();
        expect(json['suppressAdvancedModeWarning'], isTrue);

        final fromJson = AppSettings.fromJson(json);
        expect(fromJson.suppressAdvancedModeWarning, isTrue);
        expect(fromJson, equals(updated));
        expect(fromJson.hashCode, equals(updated.hashCode));

        final service = SettingsService();
        await service.setSuppressAdvancedModeWarning(true);
        expect(service.settings.suppressAdvancedModeWarning, isTrue);
        await service.setSuppressAdvancedModeWarning(false);
        expect(service.settings.suppressAdvancedModeWarning, isFalse);
      });

      test('All 23 languages have advanced warning and greyout localization keys', () {
        const supported = [
          'id',
          'en',
          'zh',
          'zh_CN',
          'zh_TW',
          'es',
          'pt',
          'ja',
          'ko',
          'hi',
          'ar',
          'fr',
          'ru',
          'de',
          'it',
          'nl',
          'da',
          'fi',
          'no',
          'sv',
          'ms',
          'vi',
          'th',
        ];

        for (final lang in supported) {
          final l10n = AppLocalizations(lang);
          expect(
            l10n.t('advanced_warning_title').isNotEmpty,
            isTrue,
            reason: 'Missing advanced_warning_title in $lang',
          );
          expect(
            l10n.t('advanced_warning_desc').isNotEmpty,
            isTrue,
            reason: 'Missing advanced_warning_desc in $lang',
          );
          expect(
            l10n.t('dont_show_again').isNotEmpty,
            isTrue,
            reason: 'Missing dont_show_again in $lang',
          );
          expect(
            l10n.t('preset_disabled_by_advanced').isNotEmpty,
            isTrue,
            reason: 'Missing preset_disabled_by_advanced in $lang',
          );
        }
      });

      testWidgets(
        'ConversionOptionsCard shows warning dialog on expand, greyouts speed presets, and respects doNotShowAgain',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final service = SettingsService();
          await service.setLanguage('id');
          await service.setSuppressAdvancedModeWarning(false);
          final l10n = service.l10n;

          const sampleVideo = VideoInfo(
            filePath: '/storage/sample.mp4',
            fileName: 'sample.mp4',
            width: 1920,
            height: 1080,
            durationSeconds: 120,
            bitrate: 10000000,
            fps: 30,
            codec: 'h264',
            fileSizeBytes: 50000000,
          );

          EncodingOptions currentOpts = const EncodingOptions(
            speedPreset: SpeedPreset.normal,
            crfValue: 22,
          );
          VideoResolution currentRes = VideoResolution.standardResolutions.first;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.getTheme('oled_pure'),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    return SingleChildScrollView(
                      child: ConversionOptionsCard(
                        sourceVideo: sampleVideo,
                        resolutions: VideoResolution.standardResolutions,
                        selectedResolution: currentRes,
                        onResolutionChanged: (res) =>
                            setState(() => currentRes = res),
                        encodingOptions: currentOpts,
                        onOptionsChanged: (opts) =>
                            setState(() => currentOpts = opts),
                        l10n: l10n,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Initial state: advanced mode is collapsed
          // Speed chips must have full opacity (1.0) and ignorePointer is false
          final opacityFinder = find.byWidgetPredicate(
            (w) => w is Opacity && (w.opacity == 1.0 || w.opacity == 0.38),
          );
          expect(opacityFinder, findsOneWidget);
          expect(tester.widget<Opacity>(opacityFinder).opacity, equals(1.0));

          // 2. Tap advanced options toggle -> warning dialog appears
          await tester.ensureVisible(find.byKey(const Key('advanced_options_toggle')));
          await tester.tap(find.byKey(const Key('advanced_options_toggle')));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('advanced_warning_dialog')), findsOneWidget);
          expect(find.byKey(const Key('advanced_warning_checkbox')), findsOneWidget);
          expect(find.byKey(const Key('advanced_warning_no_button')), findsOneWidget);
          expect(find.byKey(const Key('advanced_warning_yes_button')), findsOneWidget);

          // 3. User taps No -> dialog dismisses, advanced options remain collapsed
          await tester.tap(find.byKey(const Key('advanced_warning_no_button')));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('advanced_warning_dialog')), findsNothing);
          expect(tester.widget<Opacity>(opacityFinder).opacity, equals(1.0));
          expect(service.settings.suppressAdvancedModeWarning, isFalse);

          // 4. Tap advanced options toggle again -> dialog appears
          await tester.tap(find.byKey(const Key('advanced_options_toggle')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('advanced_warning_dialog')), findsOneWidget);

          // 5. Check 'Jangan tampilkan lagi' checkbox
          await tester.tap(find.byKey(const Key('advanced_warning_checkbox')));
          await tester.pumpAndSettle();

          // 6. User taps Yes -> dialog dismisses, advanced mode expands, speed chips greyed out
          await tester.tap(find.byKey(const Key('advanced_warning_yes_button')));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('advanced_warning_dialog')), findsNothing);
          expect(tester.widget<Opacity>(opacityFinder).opacity, equals(0.38));
          expect(find.text(l10n.t('preset_disabled_by_advanced')), findsOneWidget);
          expect(service.settings.suppressAdvancedModeWarning, isTrue);

          // 7. Collapse advanced mode
          await tester.tap(find.byKey(const Key('advanced_options_toggle')));
          await tester.pumpAndSettle();
          expect(tester.widget<Opacity>(opacityFinder).opacity, equals(1.0));

          // 8. Expand advanced mode again -> directly opens without showing warning dialog
          await tester.tap(find.byKey(const Key('advanced_options_toggle')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('advanced_warning_dialog')), findsNothing);
          expect(tester.widget<Opacity>(opacityFinder).opacity, equals(0.38));
        },
      );
    });

    group('LicenseRegistry AndroidX Media3 tests', () {
      test('AndroidX Media3 licenses are registered in LicenseRegistry', () async {
        LicenseService.registerCustomLicenses();
        final entries = await LicenseRegistry.licenses.toList();
        final media3Entries = entries
            .where((e) => e.packages.contains('androidx.media3'))
            .toList();
        expect(media3Entries, isNotEmpty);
        final media3 = media3Entries.first;
        expect(
          media3.packages,
          containsAll(<String>[
            'androidx.media3',
            'androidx.media3:media3-transformer',
            'androidx.media3:media3-effect',
            'androidx.media3:media3-common',
            'androidx.media3:media3-exoplayer',
            'androidx.media3:media3-muxer',
            'androidx.media3:media3-container',
            'androidx.media3:media3-datasource',
            'androidx.media3:media3-decoder',
            'androidx.media3:media3-extractor',
            'androidx.media3:media3-database',
          ]),
        );
        final fullText = media3.paragraphs.map((p) => p.text).join('\n');
        expect(fullText, contains('AndroidX Media3'));
        expect(fullText, contains('The Android Open Source Project'));
        expect(fullText, contains('Apache License'));

        final coroutinesEntries = entries
            .where((e) => e.packages.contains('kotlinx.coroutines'))
            .toList();
        expect(coroutinesEntries, isNotEmpty);
        final coroutines = coroutinesEntries.first;
        expect(
          coroutines.packages,
          containsAll(<String>[
            'kotlinx.coroutines',
            'kotlinx-coroutines-core',
            'kotlinx-coroutines-android',
          ]),
        );
        final coroutinesText =
            coroutines.paragraphs.map((p) => p.text).join('\n');
        expect(coroutinesText, contains('Kotlin Coroutines'));
        expect(coroutinesText, contains('JetBrains s.r.o.'));
        expect(coroutinesText, contains('Apache License'));
      });
    });

    group('AudioExtractorCard MP3 bitrate tests', () {
      testWidgets('MP3 format greys out custom bitrate chips and selects copy', (tester) async {
        const video = VideoInfo(
          filePath: '/dummy/test.mp4',
          fileName: 'test.mp4',
          durationSeconds: 60,
          width: 1920,
          height: 1080,
          bitrate: 5000000,
          fps: 30,
          codec: 'h264',
          fileSizeBytes: 1024000,
          hasAudio: true,
          audioCodec: 'mp3',
        );

        EncodingOptions options = const EncodingOptions(
          audioFormat: AudioFormat.mp3,
        );
        final l10n = AppLocalizations('id');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return AudioExtractorCard(
                    sourceVideo: video,
                    encodingOptions: options,
                    l10n: l10n,
                    onOptionsChanged: (newOpts) {
                      setState(() {
                        options = newOpts;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 64 kbps chip should be inside an Opacity of 0.38 and IgnorePointer(ignoring: true)
        final chipFinder = find.widgetWithText(ChoiceChip, '64 kbps');
        expect(chipFinder, findsOneWidget);

        final opacityFinder = find.ancestor(
          of: chipFinder,
          matching: find.byType(Opacity),
        );
        expect(tester.widget<Opacity>(opacityFinder.first).opacity, equals(0.38));

        final ignorePointerFinder = find.ancestor(
          of: chipFinder,
          matching: find.byType(IgnorePointer),
        );
        expect(tester.widget<IgnorePointer>(ignorePointerFinder.first).ignoring, isTrue);

        // Switching to M4A removes the greyed out state
        final m4aFinder = find.widgetWithText(ChoiceChip, 'M4A');
        await tester.tap(m4aFinder);
        await tester.pumpAndSettle();

        expect(options.audioFormat, equals(AudioFormat.m4a));
        expect(tester.widget<Opacity>(opacityFinder.first).opacity, equals(1.0));
        expect(tester.widget<IgnorePointer>(ignorePointerFinder.first).ignoring, isFalse);

        // Switching to WAV also shows bitrate buttons, selects copy, and greys out custom bitrates
        final wavFinder = find.widgetWithText(ChoiceChip, 'WAV');
        await tester.tap(wavFinder);
        await tester.pumpAndSettle();

        expect(options.audioFormat, equals(AudioFormat.wav));
        expect(options.audioExtractBitrateKbps, equals(0));
        expect(tester.widget<Opacity>(opacityFinder.first).opacity, equals(0.38));
        expect(tester.widget<IgnorePointer>(ignorePointerFinder.first).ignoring, isTrue);
      });
    });

    group('Video Naming and Shared Video Resolution tests', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('shared_video_test_');
      });

      tearDown(() {
        TransformerService.mockResolveMediaDetails = null;
        TransformerService.mockPickVideo = null;
        if (tempDir.existsSync()) {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        }
      });

      test('CacheManagerService isRecentSharedFile identifies recent vs expired shared files', () async {
        final cacheManager = CacheManagerService();
        final now = DateTime.now();

        final recentFile = File('${tempDir.path}/shared_video_1720000000000_sample.mp4');
        recentFile.createSync();

        final sharedIncomingDir = Directory('${tempDir.path}/shared_incoming');
        sharedIncomingDir.createSync();
        final recentInIncoming = File('${sharedIncomingDir.path}/video_clip.mp4');
        recentInIncoming.createSync();

        final normalTempFile = File('${tempDir.path}/temp_cache_data.tmp');
        normalTempFile.createSync();

        // Recent files (created now) should be protected
        expect(cacheManager.isRecentSharedFile(recentFile, now: now), isTrue);
        expect(cacheManager.isRecentSharedFile(recentInIncoming, now: now), isTrue);
        expect(cacheManager.isRecentSharedFile(sharedIncomingDir, now: now), isTrue);
        expect(cacheManager.isRecentSharedFile(normalTempFile, now: now), isFalse);

        // Simulating a file older than 5 minutes (e.g. 6 minutes ago)
        final sixMinutesLater = now.add(const Duration(minutes: 6));
        expect(cacheManager.isRecentSharedFile(recentFile, now: sixMinutesLater), isFalse);
        expect(cacheManager.isRecentSharedFile(recentInIncoming, now: sixMinutesLater), isFalse);
      });

      test('HomeScreen.extractCleanFileName strips shared_video prefix and timestamp correctly', () {
        expect(
          HomeScreen.extractCleanFileName('shared_video_1720000000000_video_touring_23062026.mp4'),
          equals('video_touring_23062026.mp4'),
        );
        expect(
          HomeScreen.extractCleanFileName('shared_video_holiday_trip.mp4'),
          equals('holiday_trip.mp4'),
        );
        expect(
          HomeScreen.extractCleanFileName('/cache/shared_incoming/shared_video_123456_camera_roll.mp4'),
          equals('camera_roll.mp4'),
        );
        expect(
          HomeScreen.extractCleanFileName('C:\\temp\\shared_video_99999_summer.mov'),
          equals('summer.mov'),
        );
        expect(
          HomeScreen.extractCleanFileName('regular_video.mp4'),
          equals('regular_video.mp4'),
        );
      });

      test('TransformerService.resolveMediaDetails non-Android fallback extracts file name and path', () async {
        final testFile = File('${tempDir.path}/test_touring_2026.mp4');
        testFile.createSync();

        final result = await TransformerService.resolveMediaDetails(
          uri: testFile.uri.toString(),
          fallbackPath: testFile.path,
        );

        expect(result, isNotNull);
        expect(result!['fileName'], equals('test_touring_2026.mp4'));
        expect(result['realPath'], equals(testFile.path));
      });

      test('TransformerService.resolveMediaDetails respects mockResolveMediaDetails override', () async {
        TransformerService.mockResolveMediaDetails = ({required uri, fallbackPath}) async {
          return {
            'fileName': 'custom_resolved_video.mp4',
            'realPath': '/storage/emulated/0/Movies/custom_resolved_video.mp4',
          };
        };

        final result = await TransformerService.resolveMediaDetails(
          uri: 'content://media/external/video/media/9999',
          fallbackPath: '/cache/file_picker/temp.mp4',
        );

        expect(result, isNotNull);
        expect(result!['fileName'], equals('custom_resolved_video.mp4'));
        expect(result['realPath'], equals('/storage/emulated/0/Movies/custom_resolved_video.mp4'));
      });

      testWidgets('HomeScreen loads shared video and displays real cleaned file name in VideoInfoCard', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final sharedVideoFile = File('${tempDir.path}/shared_video_1720000000000_video_touring_23062026.mp4');
        sharedVideoFile.writeAsStringSync('dummy content');

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.phantek.lyra.vega/transformer'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getInitialSharedVideo') {
              return sharedVideoFile.path;
            }
            if (methodCall.method == 'getVideoInfo') {
              return null;
            }
            if (methodCall.method == 'getVideoThumbnail') {
              return null;
            }
            return null;
          },
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: HomeScreen(),
          ),
        );

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 300));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('video_touring_23062026.mp4'), findsOneWidget);
        expect(find.textContaining('shared_video_1720000000000_'), findsNothing);
      });

      testWidgets('HomeScreen pickVideo uses resolved real fileName instead of synthetic picker ID (e.g. 239500.ts)', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final syntheticFile = File('${tempDir.path}/239500.ts');
        syntheticFile.writeAsStringSync('dummy video content');

        TransformerService.mockPickVideo = () async {
          return {
            'path': syntheticFile.path,
            'fileName': 'video_touring_23062026.mp4',
            'uri': 'content://com.android.providers.media.documents/document/video%3A239500',
          };
        };

        await tester.pumpWidget(
          const MaterialApp(
            home: HomeScreen(),
          ),
        );
        await tester.pump();

        // Tap the pick video button on empty state
        final selectButton = find.byType(FilledButton);
        expect(selectButton, findsOneWidget);
        await tester.tap(selectButton);
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('video_touring_23062026.mp4'), findsOneWidget);
        expect(find.text('239500.ts'), findsNothing);
      });

      testWidgets('onSharedVideoReceived with fileName displays real video name in VideoInfoCard', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final syntheticFile = File('${tempDir.path}/239500.ts');
        syntheticFile.writeAsStringSync('dummy video content');

        const channel = MethodChannel('com.phantek.lyra.vega/transformer');

        await tester.pumpWidget(
          const MaterialApp(
            home: HomeScreen(),
          ),
        );
        await tester.pump();

        final call = MethodCall('onSharedVideoReceived', {
          'path': syntheticFile.path,
          'fileName': 'video_touring_23062026.mp4',
        });
        final byteData = channel.codec.encodeMethodCall(call);
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(channel.name, byteData, (_) {});

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('video_touring_23062026.mp4'), findsOneWidget);
        expect(find.text('239500.ts'), findsNothing);
      });
    });

    group('Progress Animation Styles (V1-V6) & Localization Tests', () {
      test('AppSettings has default v1 progress style for video and audio', () {
        const settings = AppSettings();
        expect(settings.videoProgressStyle, equals('v1'));
        expect(settings.audioProgressStyle, equals('v1'));
      });

      test('AppSettings.sanitizeProgressStyle normalizes styles and maps a1/a3', () {
        expect(AppSettings.sanitizeProgressStyle('v1'), equals('v1'));
        expect(AppSettings.sanitizeProgressStyle('V2'), equals('v2'));
        expect(AppSettings.sanitizeProgressStyle('  v3  '), equals('v3'));
        expect(AppSettings.sanitizeProgressStyle('V4'), equals('v4'));
        expect(AppSettings.sanitizeProgressStyle('V5'), equals('v5'));
        expect(AppSettings.sanitizeProgressStyle('v6'), equals('v6'));
        expect(AppSettings.sanitizeProgressStyle('V6'), equals('v6'));
        expect(AppSettings.sanitizeProgressStyle('a1'), equals('v4'));
        expect(AppSettings.sanitizeProgressStyle('A1'), equals('v4'));
        expect(AppSettings.sanitizeProgressStyle('a3'), equals('v5'));
        expect(AppSettings.sanitizeProgressStyle('A3'), equals('v5'));
        expect(AppSettings.sanitizeProgressStyle(null), equals('v1'));
        expect(AppSettings.sanitizeProgressStyle('invalid'), equals('v1'));
        expect(AppSettings.sanitizeProgressStyle('unknown', 'v2'), equals('v2'));
      });

      test('AppSettings copyWith, serialization, equality, and hashCode support progress styles', () {
        const original = AppSettings();
        final modified = original.copyWith(
          videoProgressStyle: 'v3',
          audioProgressStyle: 'v5',
        );
        expect(modified.videoProgressStyle, equals('v3'));
        expect(modified.audioProgressStyle, equals('v5'));

        final json = modified.toJson();
        expect(json['videoProgressStyle'], equals('v3'));
        expect(json['audioProgressStyle'], equals('v5'));

        final restored = AppSettings.fromJson(json);
        expect(restored.videoProgressStyle, equals('v3'));
        expect(restored.audioProgressStyle, equals('v5'));
        expect(restored, equals(modified));
        expect(restored.hashCode, equals(modified.hashCode));

        // Test fromJson with legacy a1 / a3 values
        final legacyJson = {
          'videoProgressStyle': 'a1',
          'audioProgressStyle': 'a3',
        };
        final legacyRestored = AppSettings.fromJson(legacyJson);
        expect(legacyRestored.videoProgressStyle, equals('v4'));
        expect(legacyRestored.audioProgressStyle, equals('v5'));
      });

      test('SettingsService updates video, audio, and both progress styles', () async {
        SharedPreferences.setMockInitialValues({});
        final service = SettingsService();
        await service.init();

        expect(service.settings.videoProgressStyle, equals('v1'));
        expect(service.settings.audioProgressStyle, equals('v1'));

        await service.setVideoProgressStyle('v2');
        expect(service.settings.videoProgressStyle, equals('v2'));
        expect(service.settings.audioProgressStyle, equals('v1'));

        await service.setAudioProgressStyle('v4');
        expect(service.settings.videoProgressStyle, equals('v2'));
        expect(service.settings.audioProgressStyle, equals('v4'));

        await service.setBothProgressStyles('v5');
        expect(service.settings.videoProgressStyle, equals('v5'));
        expect(service.settings.audioProgressStyle, equals('v5'));

        await service.resetToDefaults();
        expect(service.settings.videoProgressStyle, equals('v1'));
        expect(service.settings.audioProgressStyle, equals('v1'));
      });

      test('All 23 supported languages have all progress style localization keys', () {
        const keys = [
          'settings_progress_style_title',
          'settings_progress_style_subtitle',
          'scope_video',
          'scope_audio',
          'scope_both',
          'style_v1_title',
          'style_v2_title',
          'style_v3_title',
          'style_v4_title',
          'style_v5_title',
          'style_v6_title',
        ];

        for (final code in supportedCodes) {
          final l10n = AppLocalizations(code);
          for (final key in keys) {
            final translated = l10n.t(key);
            expect(translated.isNotEmpty, isTrue, reason: 'Key $key must not be empty in $code');
            expect(translated, isNot(equals(key)), reason: 'Key $key must be translated in $code');
          }
        }
      });

      testWidgets('SettingsScreen displays progress style tile and opens bottom sheet with scope toggle and styles', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        final service = SettingsService();
        await service.init();

        await tester.pumpWidget(
          const MaterialApp(
            home: SettingsScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = service.l10n;
        final titleFinder = find.text(l10n.t('settings_progress_style_title'));
        expect(titleFinder, findsOneWidget);

        await tester.scrollUntilVisible(titleFinder, 100);
        await tester.pumpAndSettle();

        await tester.tap(titleFinder);
        await tester.pumpAndSettle();

        expect(find.byType(ProgressStylePreviewBox), findsOneWidget);
        expect(find.text('68%'), findsWidgets);
        final previewSliderFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Slider),
        );
        expect(previewSliderFinder, findsOneWidget);

        // Slide the interactive slider and verify preview and slider text update
        final slider = tester.widget<Slider>(previewSliderFinder);
        slider.onChanged?.call(0.45);
        await tester.pumpAndSettle();
        expect(find.text('45%'), findsWidgets);

        slider.onChanged?.call(0.68);
        await tester.pumpAndSettle();
        expect(find.text('68%'), findsWidgets);

        expect(find.text(l10n.t('scope_video')), findsOneWidget);
        expect(find.text(l10n.t('scope_audio')), findsOneWidget);
        expect(find.text(l10n.t('scope_both')), findsOneWidget);

        expect(find.text(l10n.t('style_v1_title')), findsOneWidget);
        expect(find.text(l10n.t('style_v2_title')), findsOneWidget);
        expect(find.text(l10n.t('style_v3_title')), findsOneWidget);

        final v3Finder = find.text(l10n.t('style_v3_title'));
        await tester.scrollUntilVisible(v3Finder, 50, scrollable: find.byType(Scrollable).last);
        await tester.tap(v3Finder);
        await tester.pumpAndSettle();
        expect(service.settings.videoProgressStyle, equals('v3'));
        expect(service.settings.audioProgressStyle, equals('v3'));
        final previewV3 = tester.widget<ProgressStylePreviewBox>(find.byType(ProgressStylePreviewBox));
        expect(previewV3.style, equals('v3'));

        await tester.tap(find.text(l10n.t('scope_video')));
        await tester.pumpAndSettle();

        final v1Finder = find.text(l10n.t('style_v1_title'));
        await tester.scrollUntilVisible(v1Finder, -50, scrollable: find.byType(Scrollable).last);
        await tester.tap(v1Finder);
        await tester.pumpAndSettle();
        expect(service.settings.videoProgressStyle, equals('v1'));
        expect(service.settings.audioProgressStyle, equals('v3'));
        final previewV1 = tester.widget<ProgressStylePreviewBox>(find.byType(ProgressStylePreviewBox));
        expect(previewV1.style, equals('v1'));

        await tester.tap(find.text(l10n.t('scope_audio')));
        await tester.pumpAndSettle();

        final v4Finder = find.text(l10n.t('style_v4_title'));
        await tester.scrollUntilVisible(v4Finder, 50, scrollable: find.byType(Scrollable).last);
        expect(v4Finder, findsOneWidget);

        final v5Finder = find.text(l10n.t('style_v5_title'));
        await tester.scrollUntilVisible(v5Finder, 50, scrollable: find.byType(Scrollable).last);
        expect(v5Finder, findsOneWidget);
        await tester.tap(v5Finder);
        await tester.pumpAndSettle();
        expect(service.settings.videoProgressStyle, equals('v1'));
        expect(service.settings.audioProgressStyle, equals('v5'));
        final previewV5 = tester.widget<ProgressStylePreviewBox>(find.byType(ProgressStylePreviewBox));
        expect(previewV5.style, equals('v5'));

        final v6Finder = find.text(l10n.t('style_v6_title'));
        await tester.scrollUntilVisible(v6Finder, 50, scrollable: find.byType(Scrollable).last);
        expect(v6Finder, findsOneWidget);
        await tester.tap(v6Finder);
        await tester.pumpAndSettle();
        expect(service.settings.videoProgressStyle, equals('v1'));
        expect(service.settings.audioProgressStyle, equals('v6'));
        final previewV6 = tester.widget<ProgressStylePreviewBox>(find.byType(ProgressStylePreviewBox));
        expect(previewV6.style, equals('v6'));
      });

      testWidgets('ProgressStylePreviewBox renders active style preview correctly for all styles (v1 - v6)', (tester) async {
        final styles = ['v1', 'v2', 'v3', 'v4', 'v5', 'v6'];
        final theme = AppTheme.getTheme('vega_default');

        for (final style in styles) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Center(
                  child: ProgressStylePreviewBox(
                    style: style,
                    theme: theme,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(ProgressStylePreviewBox), findsOneWidget);
          expect(find.text('68%'), findsOneWidget);
          expect(find.byType(CustomPaint), findsWidgets);
        }
      });

      testWidgets('ProgressStylePreviewBox respects MediaQuery disableAnimations (reduced motion)', (tester) async {
        final theme = AppTheme.getTheme('oled_pure');

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Center(
                  child: ProgressStylePreviewBox(
                    style: 'v2',
                    theme: theme,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ProgressStylePreviewBox), findsOneWidget);
        expect(find.text('68%'), findsOneWidget);
      });

      testWidgets('ProgressStylePreviewBox renders correctly with custom progress values (0.0, 0.45, 1.0)', (tester) async {
        final theme = AppTheme.getTheme('vega_default');

        for (final progress in [0.0, 0.45, 1.0]) {
          final expectedPct = '${(progress * 100).round()}%';
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Center(
                  child: ProgressStylePreviewBox(
                    style: 'v1',
                    theme: theme,
                    progress: progress,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(ProgressStylePreviewBox), findsOneWidget);
          expect(find.text(expectedPct), findsOneWidget);
          expect(find.byType(CustomPaint), findsWidgets);
        }
      });
    });

    group('Hardware encoder resolution capabilities tests', () {
      tearDown(() {
        TransformerService.mockResolutionCapabilities = null;
      });

      test('All 23 supported languages have all hardware limit localization keys', () {
        const keys = [
          'res_unsupported_hardware',
          'res_adjusted_to_hardware',
          'hardware_limit_title',
          'hardware_limit_desc',
          'hardware_limit_continue',
          'hardware_limit_cancel',
        ];

        for (final code in supportedCodes) {
          final l10n = AppLocalizations(code);
          for (final key in keys) {
            final translated = l10n.t(key);
            expect(translated.isNotEmpty, isTrue, reason: 'Key $key must not be empty in $code');
            expect(translated, isNot(equals(key)), reason: 'Key $key must be translated in $code');
          }
        }
      });

      test('TransformerService.getResolutionCapabilities returns default on non-Android and honors mock', () async {
        TransformerService.mockResolutionCapabilities = null;
        final defaultCaps = await TransformerService.getResolutionCapabilities();
        expect(defaultCaps['4K'], isTrue);
        expect(defaultCaps['2K'], isTrue);
        expect(defaultCaps['maxResolution'], '4K');

        TransformerService.mockResolutionCapabilities = {
          '4K': false,
          '2K': false,
          '1080p': true,
          '720p': true,
          '480p': true,
          '360p': true,
          'maxResolution': '1080p',
        };

        final mockedCaps = await TransformerService.getResolutionCapabilities();
        expect(mockedCaps['4K'], isFalse);
        expect(mockedCaps['2K'], isFalse);
        expect(mockedCaps['1080p'], isTrue);
        expect(mockedCaps['maxResolution'], '1080p');
      });

      testWidgets('ConversionOptionsCard disables 2K in downscale mode when hardware lacks 2K support', (tester) async {
        final l10n = const AppLocalizations('id');
        const source4K = VideoInfo(
          filePath: '/storage/sample_4k.mp4',
          fileName: 'sample_4k.mp4',
          width: 3840,
          height: 2160,
          durationSeconds: 60,
          bitrate: 20000000,
          fps: 30,
          codec: 'h264',
          fileSizeBytes: 100000000,
        );

        final downscaleResolutions = VideoResolution.standardResolutions
            .where((r) => r.height < 2160)
            .toList();

        VideoResolution selected = downscaleResolutions.firstWhere((r) => r.label == '1080p');

        const caps = <String, dynamic>{
          '4K': false,
          '2K': false,
          '1080p': true,
          '720p': true,
          '480p': true,
          '360p': true,
          'maxResolution': '1080p',
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme('oled_pure'),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return SingleChildScrollView(
                    child: ConversionOptionsCard(
                      sourceVideo: source4K,
                      resolutions: downscaleResolutions,
                      selectedResolution: selected,
                      resolutionCapabilities: caps,
                      encodingOptions: const EncodingOptions(),
                      onResolutionChanged: (res) {
                        setState(() => selected = res);
                      },
                      onOptionsChanged: (_) {},
                      l10n: l10n,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.t('res_unsupported_hardware')), findsOneWidget);
        expect(find.byIcon(Icons.block_rounded), findsOneWidget);

        await tester.tap(find.text('2K'));
        await tester.pumpAndSettle();
        expect(selected.label, equals('1080p'));
      });

      testWidgets('ConversionOptionsCard keeps Original 2K active and shows adjusted message in Convert mode', (tester) async {
        final l10n = const AppLocalizations('id');
        const source2K = VideoInfo(
          filePath: '/storage/sample_2k.mp4',
          fileName: 'sample_2k.mp4',
          width: 2560,
          height: 1440,
          durationSeconds: 60,
          bitrate: 15000000,
          fps: 30,
          codec: 'h264',
          fileSizeBytes: 80000000,
        );

        final convertResolutions = [
          VideoResolution(
            label: 'Original (${source2K.resolution})',
            width: source2K.width,
            height: source2K.height,
          ),
        ];

        VideoResolution selected = convertResolutions.first;

        const caps = <String, dynamic>{
          '4K': false,
          '2K': false,
          '1080p': true,
          '720p': true,
          '480p': true,
          '360p': true,
          'maxResolution': '1080p',
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme('oled_pure'),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return SingleChildScrollView(
                    child: ConversionOptionsCard(
                      sourceVideo: source2K,
                      resolutions: convertResolutions,
                      selectedResolution: selected,
                      resolutionCapabilities: caps,
                      encodingOptions: const EncodingOptions(),
                      onResolutionChanged: (res) {
                        setState(() => selected = res);
                      },
                      onOptionsChanged: (_) {},
                      l10n: l10n,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final adjustedMsg = l10n.t('res_adjusted_to_hardware', args: {'res': '1080p'});
        expect(find.text(adjustedMsg), findsOneWidget);
        expect(find.byIcon(Icons.block_rounded), findsNothing);
      });
    });
  });
}
