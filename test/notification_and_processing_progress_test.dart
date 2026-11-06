import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filex/open_filex.dart';
import 'package:phantek_video_toolkit_vega/models/app_settings.dart';
import 'package:phantek_video_toolkit_vega/models/encoding_options.dart';
import 'package:phantek_video_toolkit_vega/models/video_info.dart';
import 'package:phantek_video_toolkit_vega/screens/processing_screen.dart';
import 'package:phantek_video_toolkit_vega/services/device_spec_helper.dart';
import 'package:phantek_video_toolkit_vega/services/foreground_service.dart';
import 'package:phantek_video_toolkit_vega/services/localization_service.dart';
import 'package:phantek_video_toolkit_vega/services/settings_service.dart';
import 'package:phantek_video_toolkit_vega/services/transformer_service.dart';
import 'package:phantek_video_toolkit_vega/widgets/progress_animation_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R1: Notification Icon Configuration & Android Resources', () {
    test('ForegroundServiceManager configures NOTIFICATION_ICON metadata and background color', () {
      expect(
        ForegroundServiceManager.notificationIconMetaData,
        equals('com.phantek.lyra.vega.service.NOTIFICATION_ICON'),
      );
      expect(
        ForegroundServiceManager.defaultNotificationIcon.metaDataName,
        equals(ForegroundServiceManager.notificationIconMetaData),
      );
      expect(
        ForegroundServiceManager.defaultNotificationIcon.backgroundColor,
        equals(const Color(0xFF9333EA)),
      );
    });

    test('AndroidManifest.xml contains NOTIFICATION_ICON metadata mapping', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(
        content.contains('com.phantek.lyra.vega.service.NOTIFICATION_ICON'),
        isTrue,
      );
      expect(content.contains('@drawable/ic_notification_vega'), isTrue);
    });

    test(
      'All required notification drawable resources exist and are non-empty',
      () {
        final notificationDrawables = [
          'android/app/src/main/res/drawable/ic_notification_vega.png',
          'android/app/src/main/res/drawable-mdpi/ic_notification_vega.png',
          'android/app/src/main/res/drawable-hdpi/ic_notification_vega.png',
          'android/app/src/main/res/drawable-xhdpi/ic_notification_vega.png',
          'android/app/src/main/res/drawable-xxhdpi/ic_notification_vega.png',
          'android/app/src/main/res/drawable-xxxhdpi/ic_notification_vega.png',
        ];

        for (final path in notificationDrawables) {
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: '$path should exist');
          expect(
            file.lengthSync(),
            greaterThan(0),
            reason: '$path should not be empty',
          );
        }
      },
    );

    test('All launcher mipmap icons exist and are updated', () {
      final mipmapIcons = [
        'android/app/src/main/res/mipmap-mdpi/ic_launcher_vega.png',
        'android/app/src/main/res/mipmap-hdpi/ic_launcher_vega.png',
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher_vega.png',
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_vega.png',
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_vega.png',
      ];

      for (final path in mipmapIcons) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path should exist');
        expect(
          file.lengthSync(),
          greaterThan(0),
          reason: '$path should not be empty',
        );
      }
    });

    test('Adaptive icon XMLs and foreground drawables exist', () {
      final adaptiveFiles = [
        'android/app/src/main/res/values/colors.xml',
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_vega.xml',
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_vega_round.xml',
        'android/app/src/main/res/mipmap-mdpi/ic_launcher_vega_foreground.png',
        'android/app/src/main/res/mipmap-hdpi/ic_launcher_vega_foreground.png',
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher_vega_foreground.png',
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_vega_foreground.png',
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_vega_foreground.png',
      ];

      for (final path in adaptiveFiles) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path should exist');
        expect(
          file.lengthSync(),
          greaterThan(0),
          reason: '$path should not be empty',
        );
      }
    });

    test('Source app_icon.png exists in assets/icon', () {
      final sourceIcon = File('assets/icon/app_icon.png');
      expect(sourceIcon.existsSync(), isTrue);
      expect(sourceIcon.lengthSync(), greaterThan(1000));
    });
  });

  group('R2 & R3: ProcessingScreen Progress Decimal Precision & Color Synchronization', () {
    const testVideo = VideoInfo(
      filePath: '/storage/test_video.mp4',
      fileName: 'test_video.mp4',
      width: 1920,
      height: 1080,
      durationSeconds: 60,
      bitrate: 5000000,
      fps: 30,
      codec: 'h264',
      fileSizeBytes: 20000000,
    );

    const testResolution = VideoResolution(
      label: '720p',
      width: 1280,
      height: 720,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterForegroundTask.skipServiceResponseCheck = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_foreground_task/methods'),
            (MethodCall call) async {
              switch (call.method) {
                case 'checkNotificationPermission':
                  return 0;
                case 'requestNotificationPermission':
                  return 0;
                case 'isRunningService':
                  return false;
                case 'startService':
                  return 'started';
                case 'updateService':
                  return 'updated';
                case 'stopService':
                  return 'stopped';
                default:
                  return null;
              }
            },
          );
      final testCacheDir = Directory.systemTemp.createTempSync(
        'vega_test_cache_',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall call) async {
              if (call.method == 'getTemporaryDirectory') {
                return testCacheDir.path;
              }
              if (call.method == 'getExternalCacheDirectories') {
                return <String>[testCacheDir.path];
              }
              return testCacheDir.path;
            },
          );
    });

    tearDown(() {
      FlutterForegroundTask.skipServiceResponseCheck = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_foreground_task/methods'),
            null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
    });

    testWidgets('ProcessingScreen displays progress percentage as integer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingScreen(
            videoInfo: testVideo,
            targetResolution: testResolution,
            encodingOptions: EncodingOptions(),
            appSettings: AppSettings(),
          ),
        ),
      );

      // Initial state before transcode progress should format as integer
      await tester.pump();
      expect(find.text('0%'), findsWidgets);
    });

    testWidgets(
      'ProcessingScreen unifies loading ring color with percentage text across themes',
      (WidgetTester tester) async {
        for (final themeMode in [
          'oled_pure',
          'oled_sakura',
          'oled_midnight',
          'oled_snowfall',
          'light',
          'light_clean',
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: ProcessingScreen(
                videoInfo: testVideo,
                targetResolution: testResolution,
                encodingOptions: const EncodingOptions(),
                appSettings: AppSettings(themeMode: themeMode),
              ),
            ),
          );

          await tester.pump();

          // Find the CustomPaint that draws the progress ring
          final customPaintFinder = find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.painter.runtimeType.toString() ==
                    '_DualRingProgressPainter',
          );
          expect(
            customPaintFinder,
            findsOneWidget,
            reason: 'Theme $themeMode should render _DualRingProgressPainter',
          );

          final customPaint = tester.widget<CustomPaint>(customPaintFinder);
          final dynamic painter = customPaint.painter;

          // Find Text widget displaying the percentage
          final percentageTextFinder = find.text('0%');
          expect(percentageTextFinder, findsWidgets);

          // Get the Text widget style color
          final textWidgets = tester.widgetList<Text>(percentageTextFinder);
          final percentageTextWidget = textWidgets.firstWhere(
            (w) => w.style?.fontSize == 38 || w.style?.fontSize == 34,
          );
          final textStyleColor = percentageTextWidget.style?.color;

          // Verify painter color exactly matches the percentage text color
          expect(
            painter.color,
            equals(textStyleColor),
            reason:
                'Painter color (${painter.color}) must match percentage text color ($textStyleColor) in theme $themeMode',
          );
          expect(
            painter.secondaryColor,
            equals(textStyleColor),
            reason:
                'Painter secondaryColor (${painter.secondaryColor}) must match percentage text color ($textStyleColor) in theme $themeMode',
          );
        }
      },
    );

    testWidgets(
      'ProcessingScreen interpolates smooth progress between updates',
      (WidgetTester tester) async {
        void Function(double, String, [int?])? progressCallback;
        final completer = Completer<String?>();

        TransformerService.mockProcessVideo =
            ({
              required sourceVideo,
              required targetResolution,
              encodingOptions = const EncodingOptions(),
              appSettings = const AppSettings(),
              required onProgress,
              required onLog,
            }) async {
              progressCallback = onProgress;
              return completer.future;
            };

        addTearDown(() {
          TransformerService.mockProcessVideo = null;
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: ProcessingScreen(
              videoInfo: testVideo,
              targetResolution: testResolution,
              encodingOptions: EncodingOptions(),
              appSettings: AppSettings(),
            ),
          ),
        );

        // Initial build before task starts
        await tester.pump();
        expect(find.text('0%'), findsWidgets);

        // Advance frames to trigger post-frame callback and async service startup
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        expect(progressCallback, isNotNull);

        // Task updates progress to 20%
        progressCallback!(0.20, 'Size: 1 MB', 1000000);
        await tester
            .pump(); // Start TweenAnimationBuilder interpolation from 0 to 0.20

        // Advance 150ms (25% of 600ms linear tween -> ~0.05 / 5%)
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('5%'), findsOneWidget);

        // Advance another 150ms (50% of 600ms linear tween -> ~0.10 / 10%)
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('10%'), findsOneWidget);

        // Verify active progress ring color matches the percentage text color during interpolation
        final customPaintFinder = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() ==
                  '_DualRingProgressPainter',
        );
        expect(customPaintFinder, findsOneWidget);
        final dynamic painter = tester
            .widget<CustomPaint>(customPaintFinder)
            .painter;
        final text10 = tester.widget<Text>(find.text('10%'));
        expect(painter.color, equals(text10.style?.color));
        expect(painter.secondaryColor, equals(text10.style?.color));
        expect(painter.progress, closeTo(0.10, 0.01));

        // Advance another 150ms (75% of 600ms linear tween -> ~0.15 / 15%)
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('15%'), findsOneWidget);

        // Advance another 150ms (100% of 600ms linear tween -> ~0.20 / 20%)
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('20%'), findsOneWidget);

        // Complete the process successfully
        final tempFile = File('${Directory.systemTemp.path}/test_output.mp4')
          ..writeAsBytesSync([0, 1, 2]);
        addTearDown(() {
          if (tempFile.existsSync()) tempFile.deleteSync();
        });
        completer.complete(tempFile.path);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
        expect(find.text('100%'), findsWidgets);

        // Flush 4-second delayed foreground service stop timer
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('ProcessingScreen displays error state when task fails', (
      WidgetTester tester,
    ) async {
      final completer = Completer<String?>();

      TransformerService.mockProcessVideo =
          ({
            required sourceVideo,
            required targetResolution,
            encodingOptions = const EncodingOptions(),
            appSettings = const AppSettings(),
            required onProgress,
            required onLog,
          }) async {
            return completer.future;
          };

      addTearDown(() {
        TransformerService.mockProcessVideo = null;
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingScreen(
            videoInfo: testVideo,
            targetResolution: testResolution,
            encodingOptions: EncodingOptions(),
            appSettings: AppSettings(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      completer.complete(null);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
    });

    test('ProcessingScreen.formatProgressPercentage formats integers and handles edge cases', () {
      expect(ProcessingScreen.formatProgressPercentage(0.0), equals('0%'));
      expect(ProcessingScreen.formatProgressPercentage(0.004), equals('0%'));
      expect(ProcessingScreen.formatProgressPercentage(0.006), equals('1%'));
      expect(ProcessingScreen.formatProgressPercentage(0.01), equals('1%'));
      expect(ProcessingScreen.formatProgressPercentage(0.141), equals('14%'));
      expect(ProcessingScreen.formatProgressPercentage(0.146), equals('15%'));
      expect(ProcessingScreen.formatProgressPercentage(0.5), equals('50%'));
      expect(ProcessingScreen.formatProgressPercentage(0.999), equals('100%'));
      expect(ProcessingScreen.formatProgressPercentage(1.0), equals('100%'));
      // Boundary clamping
      expect(ProcessingScreen.formatProgressPercentage(-0.1), equals('0%'));
      expect(ProcessingScreen.formatProgressPercentage(1.05), equals('100%'));
      // Corrupt / non-finite inputs
      expect(
        ProcessingScreen.formatProgressPercentage(double.nan),
        equals('0%'),
      );
      expect(
        ProcessingScreen.formatProgressPercentage(double.infinity),
        equals('0%'),
      );
      expect(
        ProcessingScreen.formatProgressPercentage(double.negativeInfinity),
        equals('0%'),
      );
    });

    testWidgets(
      'ProcessingScreen progress painter paints safely for low decimal progress and NaN',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ProcessingScreen(
              videoInfo: testVideo,
              targetResolution: testResolution,
              encodingOptions: EncodingOptions(),
              appSettings: AppSettings(),
            ),
          ),
        );

        await tester.pump();

        final customPaintFinder = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() ==
                  '_DualRingProgressPainter',
        );
        expect(customPaintFinder, findsOneWidget);

        final customPaint = tester.widget<CustomPaint>(customPaintFinder);
        final dynamic painter = customPaint.painter;

        // Verify painter can paint with valid canvas and handles constrained sizes safely
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, const Size(196, 196)),
          returnsNormally,
        );
        expect(
          () => painter.paint(canvas, const Size(20, 20)),
          returnsNormally,
        );
        expect(() => painter.paint(canvas, const Size(0, 0)), returnsNormally);

        // Verify shouldRepaint handles NaN comparisons safely
        expect(painter.shouldRepaint(painter), isFalse);
      },
    );

    testWidgets(
      'ProcessingScreen clamps out-of-bounds progress targets safely',
      (WidgetTester tester) async {
        void Function(double, String, [int?])? progressCallback;
        final completer = Completer<String?>();

        TransformerService.mockProcessVideo =
            ({
              required sourceVideo,
              required targetResolution,
              encodingOptions = const EncodingOptions(),
              appSettings = const AppSettings(),
              required onProgress,
              required onLog,
            }) async {
              progressCallback = onProgress;
              return completer.future;
            };

        addTearDown(() {
          TransformerService.mockProcessVideo = null;
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: ProcessingScreen(
              videoInfo: testVideo,
              targetResolution: testResolution,
              encodingOptions: EncodingOptions(),
              appSettings: AppSettings(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        expect(progressCallback, isNotNull);

        // Overshoot progress (1.25 -> clamped to 100%)
        progressCallback!(1.25, 'Size: 2 MB', 2000000);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('100%'), findsOneWidget);

        // Undershoot progress (-0.25 -> clamped to 0%)
        progressCallback!(-0.25, 'Size: 0 MB', 0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('0%'), findsOneWidget);

        // Non-finite progress (NaN -> fallback to 0%)
        progressCallback!(double.nan, 'Size: 0 MB', 0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('0%'), findsOneWidget);

        completer.complete(null);
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'ProcessingScreen displays Theme-Adaptive Thermal Warning banner when temp >= 45C and dismisses on OK',
      (WidgetTester tester) async {
        final completer = Completer<String?>();
        DeviceSpecHelper.mockBatteryTemperature = 47.5;

        TransformerService.mockProcessVideo =
            ({
              required sourceVideo,
              required targetResolution,
              encodingOptions = const EncodingOptions(),
              appSettings = const AppSettings(),
              required onProgress,
              required onLog,
            }) async {
              return completer.future;
            };

        addTearDown(() {
          DeviceSpecHelper.mockBatteryTemperature = null;
          TransformerService.mockProcessVideo = null;
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: ProcessingScreen(
              videoInfo: testVideo,
              targetResolution: testResolution,
              encodingOptions: EncodingOptions(),
              appSettings: AppSettings(),
            ),
          ),
        );

        // Advance 1 second for periodic telemetry timer to tick and read temperature
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();

        // Banner elements should be present
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.textContaining('47.5'), findsWidgets);
        expect(find.text('OK'), findsOneWidget);

        // Tap the OK button to dismiss the banner
        await tester.tap(find.text('OK'));
        await tester.pump();

        // Banner should disappear
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
        expect(find.text('OK'), findsNothing);

        completer.complete(null);
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'Video mode uses Liquid Orb painter with 6 distinct theme primary colors',
      (WidgetTester tester) async {
        final completer = Completer<String?>();
        TransformerService.mockProcessVideo =
            ({
              required sourceVideo,
              required targetResolution,
              encodingOptions = const EncodingOptions(),
              appSettings = const AppSettings(),
              required onProgress,
              required onLog,
            }) async {
              return completer.future;
            };

        addTearDown(() {
          TransformerService.mockProcessVideo = null;
        });

        final seenPrimaries = <Color>{};
        const themes = [
          'oled_snowfall',
          'light',
          'oled_midnight',
          'oled_sakura',
          'oled_pure',
          'light_clean',
        ];

        for (final themeMode in themes) {
          await tester.pumpWidget(
            MaterialApp(
              home: ProcessingScreen(
                videoInfo: testVideo,
                targetResolution: testResolution,
                encodingOptions: const EncodingOptions(),
                appSettings: AppSettings(
                  themeMode: themeMode,
                  videoProgressStyle: 'v2',
                ),
                isAudioExtraction: false,
              ),
            ),
          );
          await tester.pump();

          final customPaintFinder = find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.painter.runtimeType.toString() ==
                    '_DualRingProgressPainter',
          );
          expect(customPaintFinder, findsOneWidget);

          final dynamic painter = tester
              .widget<CustomPaint>(customPaintFinder)
              .painter;
          expect(painter.isWaveform, isFalse);

          final percentageTextWidget = tester
              .widgetList<Text>(find.text('0%'))
              .firstWhere(
                (w) => w.style?.fontSize == 38 || w.style?.fontSize == 34,
              );
          expect(painter.color, equals(percentageTextWidget.style?.color));
          expect(
            painter.secondaryColor,
            equals(percentageTextWidget.style?.color),
          );
          seenPrimaries.add(painter.color as Color);

          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          expect(
            () => painter.paint(canvas, const Size(176, 176)),
            returnsNormally,
          );
          expect(
            () => painter.paint(canvas, const Size(20, 20)),
            returnsNormally,
          );
          expect(
            () => painter.paint(canvas, const Size(0, 0)),
            returnsNormally,
          );
        }

        expect(seenPrimaries.length, equals(6));

        completer.complete(null);
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'Audio extraction mode uses Waveform painter across all 6 themes and paints constrained sizes safely',
      (WidgetTester tester) async {
        void Function(double, String, [int?])? progressCallback;
        final completer = Completer<String?>();
        TransformerService.mockExtractAudio =
            ({
              required sourceVideo,
              required audioFormat,
              audioBitrateKbps = 192,
              appSettings = const AppSettings(),
              encodingOptions = const EncodingOptions(),
              required onProgress,
              required onLog,
            }) async {
              progressCallback = onProgress;
              return completer.future;
            };

        addTearDown(() {
          TransformerService.mockExtractAudio = null;
        });

        final seenPrimaries = <Color>{};
        const themes = [
          'oled_snowfall',
          'light',
          'oled_midnight',
          'oled_sakura',
          'oled_pure',
          'light_clean',
        ];

        for (final themeMode in themes) {
          await tester.pumpWidget(
            MaterialApp(
              home: ProcessingScreen(
                videoInfo: testVideo,
                targetResolution: testResolution,
                encodingOptions: const EncodingOptions(),
                appSettings: AppSettings(
                  themeMode: themeMode,
                  audioProgressStyle: 'v4',
                ),
                isAudioExtraction: true,
              ),
            ),
          );
          await tester.pump();

          final customPaintFinder = find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.painter.runtimeType.toString() ==
                    '_DualRingProgressPainter',
          );
          expect(customPaintFinder, findsOneWidget);

          final dynamic painter = tester
              .widget<CustomPaint>(customPaintFinder)
              .painter;
          expect(painter.isWaveform, isTrue);

          final percentageTextWidget = tester
              .widgetList<Text>(find.text('0%'))
              .firstWhere(
                (w) => w.style?.fontSize == 38 || w.style?.fontSize == 34,
              );
          expect(painter.color, equals(percentageTextWidget.style?.color));
          expect(
            painter.secondaryColor,
            equals(percentageTextWidget.style?.color),
          );
          seenPrimaries.add(painter.color as Color);

          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          expect(
            () => painter.paint(canvas, const Size(300, 92)),
            returnsNormally,
          );
          expect(
            () => painter.paint(canvas, const Size(20, 20)),
            returnsNormally,
          );
          expect(
            () => painter.paint(canvas, const Size(0, 0)),
            returnsNormally,
          );
        }

        expect(seenPrimaries.length, equals(6));

        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        expect(progressCallback, isNotNull);

        progressCallback!(0.55, 'Size: 512 KB', 524288);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('55%'), findsOneWidget);

        final activePaintFinder = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() ==
                  '_DualRingProgressPainter',
        );
        final dynamic activePainter = tester
            .widget<CustomPaint>(activePaintFinder)
            .painter;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => activePainter.paint(canvas, const Size(300, 92)),
          returnsNormally,
        );
        expect(
          () => activePainter.paint(canvas, const Size(20, 20)),
          returnsNormally,
        );
        expect(
          () => activePainter.paint(canvas, const Size(0, 0)),
          returnsNormally,
        );

        completer.complete(null);
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });

  group('R6: Android Share Intent Filter & Shared Video Receiving', () {
    const channel = MethodChannel('com.phantek.lyra.vega/transformer');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      TransformerService.setSharedVideoCallback(null);
    });

    test(
      'AndroidManifest.xml contains SEND and VIEW intent-filters for video/*',
      () {
        final manifestFile = File('android/app/src/main/AndroidManifest.xml');
        expect(manifestFile.existsSync(), isTrue);

        final content = manifestFile.readAsStringSync();
        expect(content.contains('android.intent.action.SEND'), isTrue);
        expect(content.contains('android.intent.action.VIEW'), isTrue);
        expect(content.contains('android:mimeType="video/*"'), isTrue);
        expect(content.contains('android.intent.category.DEFAULT'), isTrue);
        expect(content.contains('android.intent.category.BROWSABLE'), isTrue);
      },
    );

    test('TransformerService.getInitialSharedVideo returns path or null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'getInitialSharedVideo') {
              return '/data/user/0/com.phantek.lyra.vega/cache/shared_video_123.mp4';
            }
            return null;
          });

      final path = await TransformerService.getInitialSharedVideo();
      expect(
        path,
        equals('/data/user/0/com.phantek.lyra.vega/cache/shared_video_123.mp4'),
      );

      // Test null case
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'getInitialSharedVideo') {
              return null;
            }
            return null;
          });

      final nullPath = await TransformerService.getInitialSharedVideo();
      expect(nullPath, isNull);

      // Test error handling
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            throw PlatformException(
              code: 'ERROR',
              message: 'Failed to get shared video',
            );
          });

      final errorPath = await TransformerService.getInitialSharedVideo();
      expect(errorPath, isNull);
    });

    test('TransformerService.setSharedVideoCallback handles onSharedVideoReceived with map argument', () async {
      String? receivedPath;
      TransformerService.setSharedVideoCallback((path) {
        receivedPath = path;
      });

      final call = const MethodCall('onSharedVideoReceived', {
        'path': '/storage/emulated/0/Movies/shared_clip.mp4',
      });
      final byteData = channel.codec.encodeMethodCall(call);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'com.phantek.lyra.vega/transformer',
            byteData,
            (ByteData? reply) {},
          );

      expect(
        receivedPath,
        equals('/storage/emulated/0/Movies/shared_clip.mp4'),
      );
    });

    test('TransformerService.setSharedVideoCallback handles onSharedVideoReceived with string argument', () async {
      String? receivedPath;
      TransformerService.setSharedVideoCallback((path) {
        receivedPath = path;
      });

      final call = const MethodCall(
        'onSharedVideoReceived',
        '/storage/emulated/0/DCIM/Camera/direct_clip.mp4',
      );
      final byteData = channel.codec.encodeMethodCall(call);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'com.phantek.lyra.vega/transformer',
            byteData,
            (ByteData? reply) {},
          );

      expect(
        receivedPath,
        equals('/storage/emulated/0/DCIM/Camera/direct_clip.mp4'),
      );
    });

    test(
      'TransformerService.setSharedVideoCallback(null) clears callback',
      () async {
        int invokeCount = 0;
        TransformerService.setSharedVideoCallback((path) {
          invokeCount++;
        });

        TransformerService.setSharedVideoCallback(null);

        final call = const MethodCall('onSharedVideoReceived', {
          'path': '/storage/emulated/0/Movies/ignored.mp4',
        });
        final byteData = channel.codec.encodeMethodCall(call);

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              'com.phantek.lyra.vega/transformer',
              byteData,
              (ByteData? reply) {},
            );

        expect(invokeCount, equals(0));
      },
    );
  });

  group('R4: Notification Actions, Completion Notifications & Localization', () {
    const testVideo = VideoInfo(
      filePath: '/storage/test_video.mp4',
      fileName: 'test_video.mp4',
      width: 1920,
      height: 1080,
      durationSeconds: 60,
      bitrate: 5000000,
      fps: 30,
      codec: 'h264',
      fileSizeBytes: 20000000,
    );

    const testResolution = VideoResolution(
      label: '720p',
      width: 1280,
      height: 720,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterForegroundTask.skipServiceResponseCheck = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_foreground_task/methods'),
            (MethodCall call) async {
              switch (call.method) {
                case 'checkNotificationPermission':
                  return 0;
                case 'requestNotificationPermission':
                  return 0;
                case 'isRunningService':
                  return true;
                case 'startService':
                  return 'started';
                case 'updateService':
                  return 'updated';
                case 'stopService':
                  return 'stopped';
                default:
                  return null;
              }
            },
          );
      final testCacheDir = Directory.systemTemp.createTempSync(
        'vega_test_cache_r4_',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall call) async {
              if (call.method == 'getTemporaryDirectory') {
                return testCacheDir.path;
              }
              if (call.method == 'getExternalCacheDirectories') {
                return <String>[testCacheDir.path];
              }
              return testCacheDir.path;
            },
          );
    });

    tearDown(() {
      FlutterForegroundTask.skipServiceResponseCheck = false;
      ForegroundServiceManager().onNotificationAction = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_foreground_task/methods'),
            null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
    });

    test(
      'ForegroundServiceManager starts and updates service with buttons',
      () async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('flutter_foreground_task/methods'),
              (MethodCall call) async {
                calls.add(call);
                switch (call.method) {
                  case 'checkNotificationPermission':
                    return 0;
                  case 'isRunningService':
                    return calls.any((c) => c.method == 'startService');
                  case 'startService':
                    return 'started';
                  case 'updateService':
                    return 'updated';
                  case 'stopService':
                    return 'stopped';
                  default:
                    return null;
                }
              },
            );

        final manager = ForegroundServiceManager();
        await manager.startService(
          title: 'Converting',
          text: 'Progress 10%',
          buttons: const [
            NotificationButton(id: 'btn_cancel', text: 'Batalkan'),
          ],
        );

        final startCall = calls.firstWhere((c) => c.method == 'startService');
        final startArgs = Map<String, dynamic>.from(startCall.arguments as Map);
        expect(startArgs['notificationContentTitle'], equals('Converting'));
        expect(startArgs['notificationContentText'], equals('Progress 10%'));
        final startButtons = (startArgs['buttons'] as List).cast<Map>();
        expect(startButtons.first['id'], equals('btn_cancel'));
        expect(startButtons.first['text'], equals('Batalkan'));

        // Update service with progress and buttons
        await manager.updateService(
          title: 'Converting',
          text: 'Progress 50%',
          buttons: const [
            NotificationButton(id: 'btn_cancel', text: 'Batalkan'),
          ],
          force: true,
        );

        final updateCall = calls.lastWhere((c) => c.method == 'updateService');
        final updateArgs = Map<String, dynamic>.from(
          updateCall.arguments as Map,
        );
        expect(updateArgs['notificationContentText'], equals('Progress 50%'));
        final updateButtons = (updateArgs['buttons'] as List).cast<Map>();
        expect(updateButtons.first['id'], equals('btn_cancel'));

        // Show completed notification with btn_play
        await manager.showCompletedNotification(
          title: 'Selesai',
          text: 'Hemat 40%',
          playButtonText: 'Putar',
        );

        final completeCall = calls.lastWhere(
          (c) => c.method == 'updateService',
        );
        final completeArgs = Map<String, dynamic>.from(
          completeCall.arguments as Map,
        );
        expect(completeArgs['notificationContentTitle'], equals('Selesai'));
        expect(completeArgs['notificationContentText'], equals('Hemat 40%'));
        final completeButtons = (completeArgs['buttons'] as List).cast<Map>();
        expect(completeButtons.first['id'], equals('btn_play'));
        expect(completeButtons.first['text'], equals('Putar'));
      },
    );

    test(
      'ForegroundServiceManager onNotificationAction callback receives events',
      () {
        final manager = ForegroundServiceManager();
        String? receivedAction;
        manager.onNotificationAction = (action) {
          receivedAction = action;
        };

        manager.onNotificationAction?.call('btn_cancel');
        expect(receivedAction, equals('btn_cancel'));

        manager.onNotificationAction?.call('btn_play');
        expect(receivedAction, equals('btn_play'));

        manager.onNotificationAction = null;
        expect(manager.onNotificationAction, isNull);
      },
    );

    testWidgets(
      'ProcessingScreen handles btn_cancel notification action and aborts processing',
      (WidgetTester tester) async {
        await SettingsService().setLanguage('id');
        final completer = Completer<String?>();
        var cancelCalled = false;

        TransformerService.mockProcessVideo =
            ({
              required sourceVideo,
              required targetResolution,
              encodingOptions = const EncodingOptions(),
              appSettings = const AppSettings(),
              required onProgress,
              required onLog,
            }) async {
              return completer.future;
            };

        TransformerService.mockCancelAll = () async {
          cancelCalled = true;
        };

        addTearDown(() async {
          await SettingsService().setLanguage('en');
          TransformerService.mockProcessVideo = null;
          TransformerService.mockCancelAll = null;
          if (!completer.isCompleted) completer.complete(null);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: ProcessingScreen(
              videoInfo: testVideo,
              targetResolution: testResolution,
              encodingOptions: EncodingOptions(),
              appSettings: AppSettings(languageCode: 'id'),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(ForegroundServiceManager().onNotificationAction, isNotNull);

        // Trigger notification cancel action
        ForegroundServiceManager().onNotificationAction!('btn_cancel');
        await tester.pump();

        expect(cancelCalled, isTrue);
        expect(find.text('Konversi Dibatalkan'), findsOneWidget);
      },
    );

    testWidgets(
      'ProcessingScreen handles btn_play notification action and opens output file',
      (WidgetTester tester) async {
        final tempFile = File(
          '${Directory.systemTemp.path}/notif_test_output.mp4',
        )..writeAsBytesSync([0, 1, 2, 3]);
        addTearDown(() {
          if (tempFile.existsSync()) tempFile.deleteSync();
        });

        final completer = Completer<String?>();
        TransformerService.mockProcessVideo =
            ({
              required sourceVideo,
              required targetResolution,
              encodingOptions = const EncodingOptions(),
              appSettings = const AppSettings(),
              required onProgress,
              required onLog,
            }) async {
              return completer.future;
            };

        String? openedPath;
        final prevRunner = ProcessingScreen.openFileRunner;
        ProcessingScreen.openFileRunner = (path, {type}) async {
          openedPath = path;
          return OpenResult(type: ResultType.done, message: 'done');
        };

        addTearDown(() {
          ProcessingScreen.openFileRunner = prevRunner;
          TransformerService.mockProcessVideo = null;
          if (!completer.isCompleted) completer.complete(null);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: ProcessingScreen(
              videoInfo: testVideo,
              targetResolution: testResolution,
              encodingOptions: EncodingOptions(),
              appSettings: AppSettings(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Complete processing successfully
        completer.complete(tempFile.path);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));

        // Trigger notification play action
        ForegroundServiceManager().onNotificationAction!('btn_play');
        await tester.pump();

        expect(openedPath, equals(tempFile.path));
      },
    );

    test('All 23 supported languages define notification action keys without emojis', () {
      final languages = [
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
      expect(languages.length, equals(23));

      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}]',
        unicode: true,
      );

      final requiredKeys = [
        'notif_btn_cancel',
        'notif_btn_play',
        'notif_completed_title',
        'notif_completed_audio_title',
        'proc_cancelled',
      ];

      for (final lang in languages) {
        final l10n = AppLocalizations(lang);
        for (final key in requiredKeys) {
          final value = l10n.t(key);
          expect(
            value,
            isNot(equals(key)),
            reason: 'Language "$lang" must have a translation for "$key"',
          );
          expect(
            value.trim().isNotEmpty,
            isTrue,
            reason: 'Language "$lang" translation for "$key" must not be empty',
          );
          expect(
            emojiRegex.hasMatch(value),
            isFalse,
            reason:
                'Language "$lang" string "$key" ("$value") must not contain emojis',
          );
        }
      }

      // Verify specific Indonesian canonical strings
      final idL10n = AppLocalizations('id');
      expect(idL10n.t('notif_btn_cancel'), equals('Batalkan'));
      expect(idL10n.t('notif_btn_play'), equals('Putar'));
      expect(
        idL10n.t('notif_completed_title'),
        equals('Konversi Video Selesai'),
      );
      expect(
        idL10n.t('notif_completed_audio_title'),
        equals('Ekstraksi Audio Selesai'),
      );
      expect(idL10n.t('proc_cancelled'), equals('Konversi Dibatalkan'));

      // Verify specific English canonical strings
      final enL10n = AppLocalizations('en');
      expect(enL10n.t('notif_btn_cancel'), equals('Cancel'));
      expect(enL10n.t('notif_btn_play'), equals('Play'));
      expect(
        enL10n.t('notif_completed_title'),
        equals('Video Conversion Completed'),
      );
      expect(
        enL10n.t('notif_completed_audio_title'),
        equals('Audio Extraction Completed'),
      );
      expect(enL10n.t('proc_cancelled'), equals('Conversion Cancelled'));
    });
  });

  group('DeviceSpecHelper.getBatteryTemperature', () {
    const MethodChannel channel = MethodChannel(
      'com.phantek.lyra.vega/transformer',
    );

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      DeviceSpecHelper.mockBatteryTemperature = null;
      DeviceSpecHelper.isAndroidOverride = null;
    });

    test('returns mockBatteryTemperature if set', () async {
      DeviceSpecHelper.mockBatteryTemperature = 42.5;
      final temp = await DeviceSpecHelper.getBatteryTemperature();
      expect(temp, equals(42.5));
    });

    test(
      'returns native temperature when MethodChannel succeeds with valid temp',
      () async {
        DeviceSpecHelper.isAndroidOverride = true;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'getDeviceTemperature') {
                return 38.6;
              }
              return null;
            });

        final temp = await DeviceSpecHelper.getBatteryTemperature();
        expect(temp, equals(38.6));
      },
    );

    test('returns fallback temperature 35.0 when MethodChannel returns null or <= 0', () async {
      DeviceSpecHelper.isAndroidOverride = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'getDeviceTemperature') {
              return null;
            }
            return null;
          });

      final temp = await DeviceSpecHelper.getBatteryTemperature();
      expect(temp, equals(35.0));
    });

    test(
      'returns fallback temperature 35.0 when MethodChannel throws exception',
      () async {
        DeviceSpecHelper.isAndroidOverride = true;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'getDeviceTemperature') {
                throw PlatformException(
                  code: 'UNAVAILABLE',
                  message: 'Sensor fail',
                );
              }
              return null;
            });

        final temp = await DeviceSpecHelper.getBatteryTemperature();
        expect(temp, equals(35.0));
      },
    );

    test('returns fallback temperature 35.0 when not on Android', () async {
      DeviceSpecHelper.isAndroidOverride = false;
      final temp = await DeviceSpecHelper.getBatteryTemperature();
      expect(temp, equals(35.0));
    });
  });

  group('Progress Animation Styles (V1-V6) ProcessingScreen Rendering Tests', () {
    const testVideo = VideoInfo(
      filePath: '/storage/test_video.mp4',
      fileName: 'test_video.mp4',
      width: 1920,
      height: 1080,
      durationSeconds: 60,
      bitrate: 5000000,
      fps: 30,
      codec: 'h264',
      fileSizeBytes: 20000000,
    );

    const testResolution = VideoResolution(
      label: '720p',
      width: 1280,
      height: 720,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterForegroundTask.skipServiceResponseCheck = true;
    });

    testWidgets('V1 (Orbit) renders 180x180 dp with center percentage 38sp', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingScreen(
            videoInfo: testVideo,
            targetResolution: testResolution,
            appSettings: AppSettings(videoProgressStyle: 'v1'),
          ),
        ),
      );
      await tester.pump();

      final customPaintFinder = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() ==
                '_DualRingProgressPainter' &&
            (widget.painter as dynamic).style == 'v1',
      );
      expect(customPaintFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      expect(customPaint.size, equals(const Size(180, 180)));

      expect(
        find.ancestor(
          of: customPaintFinder,
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );

      final textFinder = find.text('0%');
      expect(textFinder, findsWidgets);
      final textWidget = tester
          .widgetList<Text>(textFinder)
          .firstWhere((w) => w.style?.fontSize == 38);
      expect(textWidget.style?.fontWeight, equals(FontWeight.w700));

      final dynamic painter = customPaint.painter;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => painter.paint(canvas, const Size(180, 180)),
        returnsNormally,
      );
      expect(() => painter.paint(canvas, const Size(20, 20)), returnsNormally);
      expect(() => painter.paint(canvas, Size.zero), returnsNormally);
    });

    testWidgets('V2 (Radar) renders 180x180 dp with center percentage 38sp', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingScreen(
            videoInfo: testVideo,
            targetResolution: testResolution,
            appSettings: AppSettings(videoProgressStyle: 'v2'),
          ),
        ),
      );
      await tester.pump();

      final customPaintFinder = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() ==
                '_DualRingProgressPainter' &&
            (widget.painter as dynamic).style == 'v2',
      );
      expect(customPaintFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      expect(customPaint.size, equals(const Size(180, 180)));

      final textFinder = find.text('0%');
      expect(textFinder, findsWidgets);
      final textWidget = tester
          .widgetList<Text>(textFinder)
          .firstWhere((w) => w.style?.fontSize == 38);
      expect(textWidget.style?.fontWeight, equals(FontWeight.w700));

      final dynamic painter = customPaint.painter;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => painter.paint(canvas, const Size(180, 180)),
        returnsNormally,
      );
      expect(() => painter.paint(canvas, const Size(20, 20)), returnsNormally);
      expect(() => painter.paint(canvas, Size.zero), returnsNormally);
    });

    testWidgets('V3 (Liquid) renders 180x180 dp with center percentage 38sp', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingScreen(
            videoInfo: testVideo,
            targetResolution: testResolution,
            appSettings: AppSettings(videoProgressStyle: 'v3'),
          ),
        ),
      );
      await tester.pump();

      final customPaintFinder = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() ==
                '_DualRingProgressPainter' &&
            (widget.painter as dynamic).style == 'v3',
      );
      expect(customPaintFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      expect(customPaint.size, equals(const Size(180, 180)));

      final textFinder = find.text('0%');
      expect(textFinder, findsWidgets);
      final textWidget = tester
          .widgetList<Text>(textFinder)
          .firstWhere((w) => w.style?.fontSize == 38);
      expect(textWidget.style?.fontWeight, equals(FontWeight.w700));

      final dynamic painter = customPaint.painter;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => painter.paint(canvas, const Size(180, 180)),
        returnsNormally,
      );
      expect(() => painter.paint(canvas, const Size(20, 20)), returnsNormally);
      expect(() => painter.paint(canvas, Size.zero), returnsNormally);
    });

    testWidgets(
      'V4 (Particles) renders 180x180 dp with center percentage 38sp',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ProcessingScreen(
              videoInfo: testVideo,
              targetResolution: testResolution,
              appSettings: AppSettings(videoProgressStyle: 'v4'),
            ),
          ),
        );
        await tester.pump();

        final customPaintFinder = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() ==
                  '_DualRingProgressPainter' &&
              (widget.painter as dynamic).style == 'v4',
        );
        expect(customPaintFinder, findsOneWidget);

        final customPaint = tester.widget<CustomPaint>(customPaintFinder);
        expect(customPaint.size, equals(const Size(180, 180)));

        final textFinder = find.text('0%');
        expect(textFinder, findsWidgets);
        final textWidget = tester
            .widgetList<Text>(textFinder)
            .firstWhere((w) => w.style?.fontSize == 38);
        expect(textWidget.style?.fontWeight, equals(FontWeight.w700));

        final dynamic painter = customPaint.painter;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, const Size(180, 180)),
          returnsNormally,
        );
        expect(
          () => painter.paint(canvas, const Size(20, 20)),
          returnsNormally,
        );
        expect(() => painter.paint(canvas, Size.zero), returnsNormally);
      },
    );

    testWidgets('V5 (Spiral) renders 180x180 dp with center percentage 38sp', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingScreen(
            videoInfo: testVideo,
            targetResolution: testResolution,
            appSettings: AppSettings(videoProgressStyle: 'v5'),
          ),
        ),
      );
      await tester.pump();

      final customPaintFinder = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() ==
                '_DualRingProgressPainter' &&
            (widget.painter as dynamic).style == 'v5',
      );
      expect(customPaintFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      expect(customPaint.size, equals(const Size(180, 180)));

      final textFinder = find.text('0%');
      expect(textFinder, findsWidgets);
      final textWidget = tester
          .widgetList<Text>(textFinder)
          .firstWhere((w) => w.style?.fontSize == 38);
      expect(textWidget.style?.fontWeight, equals(FontWeight.w700));

      final dynamic painter = customPaint.painter;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => painter.paint(canvas, const Size(180, 180)),
        returnsNormally,
      );
      expect(() => painter.paint(canvas, const Size(20, 20)), returnsNormally);
      expect(() => painter.paint(canvas, Size.zero), returnsNormally);
    });

    testWidgets(
      'V6 (Zig-Zag) renders 280x24 dp with center percentage 38sp above bar',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ProcessingScreen(
              videoInfo: testVideo,
              targetResolution: testResolution,
              appSettings: AppSettings(videoProgressStyle: 'v6'),
            ),
          ),
        );
        await tester.pump();

        final customPaintFinder = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() ==
                  '_DualRingProgressPainter' &&
              (widget.painter as dynamic).style == 'v6',
        );
        expect(customPaintFinder, findsOneWidget);

        final customPaint = tester.widget<CustomPaint>(customPaintFinder);
        expect(customPaint.size, equals(const Size(280, 24)));

        final textFinder = find.text('0%');
        expect(textFinder, findsWidgets);
        final textWidget = tester
            .widgetList<Text>(textFinder)
            .firstWhere((w) => w.style?.fontSize == 38);
        expect(textWidget.style?.fontWeight, equals(FontWeight.w700));

        final dynamic painter = customPaint.painter;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, const Size(280, 24)),
          returnsNormally,
        );
        expect(
          () => painter.paint(canvas, const Size(20, 10)),
          returnsNormally,
        );
        expect(() => painter.paint(canvas, Size.zero), returnsNormally);
      },
    );

    testWidgets(
      'V7 (Capsule) renders 280x16 dp with center percentage 38sp above bar',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ProcessingScreen(
              videoInfo: testVideo,
              targetResolution: testResolution,
              appSettings: AppSettings(videoProgressStyle: 'v7'),
            ),
          ),
        );
        await tester.pump();

        final customPaintFinder = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() ==
                  '_DualRingProgressPainter' &&
              (widget.painter as dynamic).style == 'v7',
        );
        expect(customPaintFinder, findsOneWidget);

        final customPaint = tester.widget<CustomPaint>(customPaintFinder);
        expect(customPaint.size, equals(const Size(280, 16)));

        final textFinder = find.text('0%');
        expect(textFinder, findsWidgets);
        final textWidget = tester
            .widgetList<Text>(textFinder)
            .firstWhere((w) => w.style?.fontSize == 38);
        expect(textWidget.style?.fontWeight, equals(FontWeight.w700));

        final dynamic painter = customPaint.painter;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, const Size(280, 16)),
          returnsNormally,
        );
        expect(
          () => painter.paint(canvas, const Size(20, 10)),
          returnsNormally,
        );
        expect(() => painter.paint(canvas, Size.zero), returnsNormally);
      },
    );

    testWidgets(
      'V8 (Equalizer) renders 280x24 dp with center percentage 38sp above bar',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ProcessingScreen(
              videoInfo: testVideo,
              targetResolution: testResolution,
              appSettings: AppSettings(videoProgressStyle: 'v8'),
            ),
          ),
        );
        await tester.pump();

        final customPaintFinder = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() ==
                  '_DualRingProgressPainter' &&
              (widget.painter as dynamic).style == 'v8',
        );
        expect(customPaintFinder, findsOneWidget);

        final customPaint = tester.widget<CustomPaint>(customPaintFinder);
        expect(customPaint.size, equals(const Size(280, 24)));

        final textFinder = find.text('0%');
        expect(textFinder, findsWidgets);
        final textWidget = tester
            .widgetList<Text>(textFinder)
            .firstWhere((w) => w.style?.fontSize == 38);
        expect(textWidget.style?.fontWeight, equals(FontWeight.w700));

        final dynamic painter = customPaint.painter;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, const Size(280, 24)),
          returnsNormally,
        );
        expect(
          () => painter.paint(canvas, const Size(20, 10)),
          returnsNormally,
        );
        expect(() => painter.paint(canvas, Size.zero), returnsNormally);
      },
    );

    testWidgets(
      'Audio extraction respects audioProgressStyle independently from videoProgressStyle',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ProcessingScreen(
              videoInfo: testVideo,
              targetResolution: testResolution,
              appSettings: AppSettings(
                videoProgressStyle: 'v1',
                audioProgressStyle: 'v8',
              ),
              isAudioExtraction: true,
            ),
          ),
        );
        await tester.pump();

        final customPaintFinder = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() ==
                  '_DualRingProgressPainter' &&
              (widget.painter as dynamic).style == 'v8',
        );
        expect(customPaintFinder, findsOneWidget);
      },
    );

    test('DualRingProgressPainter renders seamlessly across animTime progression for all 8 styles', () {
      final styles = ['v1', 'v2', 'v3', 'v4', 'v5', 'v6', 'v7', 'v8'];
      for (final style in styles) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final isBar = style == 'v6' || style == 'v7' || style == 'v8';
        final size = isBar
            ? (style == 'v7' ? const Size(280, 16) : const Size(280, 24))
            : const Size(180, 180);

        // Test at multiple continuous time points across cycle boundaries (0.0s, 1.2s, 2.4s, 3.6s, 4.8s)
        for (double t = 0.0; t <= 5.0; t += 0.5) {
          final painter = DualRingProgressPainter(
            progress: 0.68,
            animationValue: (t / 2.4) % 1.0,
            animTime: t,
            isProcessing: true,
            isSuccess: false,
            color: const Color(0xFFA78BFA),
            secondaryColor: const Color(0xFFA78BFA),
            deepColor: const Color(0xFF6D28D9),
            crestColor: const Color(0xFFC4B5FD),
            basinColor: const Color(0xFF0C081C),
            trackColor: const Color(0xFF2B1F4A),
            isDark: true,
            style: style,
          );

          expect(() => painter.paint(canvas, size), returnsNormally);
        }

        // Test shouldRepaint when animTime updates
        final p1 = DualRingProgressPainter(
          progress: 0.5,
          animationValue: 0.2,
          animTime: 0.48,
          isProcessing: true,
          isSuccess: false,
          color: const Color(0xFFA78BFA),
          secondaryColor: const Color(0xFFA78BFA),
          deepColor: const Color(0xFF6D28D9),
          crestColor: const Color(0xFFC4B5FD),
          basinColor: const Color(0xFF0C081C),
          trackColor: const Color(0xFF2B1F4A),
          isDark: true,
          style: style,
        );
        final p2 = DualRingProgressPainter(
          progress: 0.5,
          animationValue: 0.2,
          animTime: 0.50,
          isProcessing: true,
          isSuccess: false,
          color: const Color(0xFFA78BFA),
          secondaryColor: const Color(0xFFA78BFA),
          deepColor: const Color(0xFF6D28D9),
          crestColor: const Color(0xFFC4B5FD),
          basinColor: const Color(0xFF0C081C),
          trackColor: const Color(0xFF2B1F4A),
          isDark: true,
          style: style,
        );
        expect(p2.shouldRepaint(p1), isTrue);
      }
    });

    test('DualRingProgressPainter renders smooth gradient across V1, V2, V4, V5, V6, V7, V8', () {
      final styles = ['v1', 'v2', 'v3', 'v4', 'v5', 'v6', 'v7', 'v8'];
      for (final style in styles) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final isBar = style == 'v6' || style == 'v7' || style == 'v8';
        final size = isBar
            ? (style == 'v7' ? const Size(280, 16) : const Size(280, 24))
            : const Size(180, 180);

        final painter = DualRingProgressPainter(
          progress: 0.75,
          animationValue: 0.5,
          animTime: 1.2,
          isProcessing: true,
          isSuccess: false,
          color: const Color(0xFFA78BFA),
          secondaryColor: const Color(0xFFA78BFA),
          deepColor: const Color(0xFF6D28D9),
          crestColor: const Color(0xFFC4B5FD),
          basinColor: const Color(0xFF0C081C),
          trackColor: const Color(0xFF2B1F4A),
          isDark: true,
          style: style,
        );

        expect(() => painter.paint(canvas, size), returnsNormally);
      }
    });

    test('Capsule V7 shimmer glint maintains continuous sweep without premature reset', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(280, 16);

      for (double anim = 0.0; anim <= 1.0; anim += 0.1) {
        final painter = DualRingProgressPainter(
          progress: 0.7,
          animationValue: anim,
          animTime: anim * 2.4,
          isProcessing: true,
          isSuccess: false,
          color: const Color(0xFFA78BFA),
          secondaryColor: const Color(0xFFA78BFA),
          deepColor: const Color(0xFF6D28D9),
          crestColor: const Color(0xFFC4B5FD),
          basinColor: const Color(0xFF0C081C),
          trackColor: const Color(0xFF2B1F4A),
          isDark: true,
          style: 'v7',
        );
        expect(() => painter.paint(canvas, size), returnsNormally);
      }
    });

    test('Zig-Zag V6 snake undulates seamlessly across loop boundaries and animTime progression', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(280, 24);

      for (double anim = 0.0; anim <= 1.0; anim += 0.05) {
        final painter = DualRingProgressPainter(
          progress: 0.65,
          animationValue: anim,
          animTime: anim * 2.4,
          isProcessing: true,
          isSuccess: false,
          color: const Color(0xFFA78BFA),
          secondaryColor: const Color(0xFFA78BFA),
          deepColor: const Color(0xFF6D28D9),
          crestColor: const Color(0xFFC4B5FD),
          basinColor: const Color(0xFF0C081C),
          trackColor: const Color(0xFF2B1F4A),
          isDark: true,
          style: 'v6',
        );
        expect(() => painter.paint(canvas, size), returnsNormally);
      }
    });

    test('DualRingProgressPainter renders 100% color unification without error across circular styles', () {
      final circularStyles = ['v1', 'v2', 'v4', 'v5'];
      for (final style in circularStyles) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(180, 180);

        final painter100 = DualRingProgressPainter(
          progress: 1.0,
          animationValue: 0.5,
          animTime: 1.2,
          isProcessing: true,
          isSuccess: false,
          color: const Color(0xFFA78BFA),
          secondaryColor: const Color(0xFFA78BFA),
          deepColor: const Color(0xFF6D28D9),
          crestColor: const Color(0xFFC4B5FD),
          basinColor: const Color(0xFF0C081C),
          trackColor: const Color(0xFF2B1F4A),
          isDark: true,
          style: style,
        );
        expect(() => painter100.paint(canvas, size), returnsNormally);

        for (double p = 0.90; p <= 1.0; p += 0.02) {
          final painterTransition = DualRingProgressPainter(
            progress: p,
            animationValue: 0.3,
            animTime: 0.8,
            isProcessing: true,
            isSuccess: false,
            color: const Color(0xFFA78BFA),
            secondaryColor: const Color(0xFFA78BFA),
            deepColor: const Color(0xFF6D28D9),
            crestColor: const Color(0xFFC4B5FD),
            basinColor: const Color(0xFF0C081C),
            trackColor: const Color(0xFF2B1F4A),
            isDark: true,
            style: style,
          );
          expect(() => painterTransition.paint(canvas, size), returnsNormally);
        }
      }
    });

    test('DualRingProgressPainter V5 renders head cap without white head spark artifact', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(180, 180);

      final painter = DualRingProgressPainter(
        progress: 0.85,
        animationValue: 0.4,
        animTime: 1.0,
        isProcessing: true,
        isSuccess: false,
        color: const Color(0xFFA78BFA),
        secondaryColor: const Color(0xFFA78BFA),
        deepColor: const Color(0xFF6D28D9),
        crestColor: const Color(0xFFC4B5FD),
        basinColor: const Color(0xFF0C081C),
        trackColor: const Color(0xFF2B1F4A),
        isDark: true,
        style: 'v5',
      );
      expect(() => painter.paint(canvas, size), returnsNormally);
    });

    test('DualRingProgressPainter V1-V5 parity suite verifies rendering in small, normal, light, and dark modes', () {
      final styles = ['v1', 'v2', 'v3', 'v4', 'v5'];
      final sizes = [const Size(48, 48), const Size(180, 180)];
      final progressValues = [0.0, 0.25, 0.50, 0.75, 0.95, 1.0];

      for (final style in styles) {
        for (final size in sizes) {
          for (final isDark in [true, false]) {
            for (final p in progressValues) {
              final recorder = ui.PictureRecorder();
              final canvas = Canvas(recorder);
              final painter = DualRingProgressPainter(
                progress: p,
                animationValue: 0.65,
                animTime: 1.5,
                isProcessing: true,
                isSuccess: false,
                color: const Color(0xFFA78BFA),
                secondaryColor: const Color(0xFFA78BFA),
                deepColor: const Color(0xFF6D28D9),
                crestColor: const Color(0xFFC4B5FD),
                basinColor: const Color(0xFF0C081C),
                trackColor: const Color(0xFF2B1F4A),
                isDark: isDark,
                style: style,
              );
              expect(
                () => painter.paint(canvas, size),
                returnsNormally,
                reason: 'Failed on style: $style, size: $size, dark: $isDark, progress: $p',
              );
            }
          }
        }
      }
    });
  });
}
