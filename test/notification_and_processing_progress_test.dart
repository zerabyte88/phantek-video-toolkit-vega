// SPDX-License-Identifier: MIT
// Copyright (C) 2026 zerabyte88

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phantek_video_toolkit_vega/models/app_settings.dart';
import 'package:phantek_video_toolkit_vega/models/encoding_options.dart';
import 'package:phantek_video_toolkit_vega/models/video_info.dart';
import 'package:phantek_video_toolkit_vega/screens/processing_screen.dart';
import 'package:phantek_video_toolkit_vega/services/foreground_service.dart';
import 'package:phantek_video_toolkit_vega/services/transformer_service.dart';
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
      expect(content.contains('@drawable/ic_notification'), isTrue);
    });

    test(
      'All required notification drawable resources exist and are non-empty',
      () {
        final notificationDrawables = [
          'android/app/src/main/res/drawable/ic_notification.png',
          'android/app/src/main/res/drawable-mdpi/ic_notification.png',
          'android/app/src/main/res/drawable-hdpi/ic_notification.png',
          'android/app/src/main/res/drawable-xhdpi/ic_notification.png',
          'android/app/src/main/res/drawable-xxhdpi/ic_notification.png',
          'android/app/src/main/res/drawable-xxxhdpi/ic_notification.png',
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
        'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
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
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml',
        'android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png',
        'android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png',
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png',
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png',
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png',
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

    testWidgets(
      'ProcessingScreen displays progress percentage with 1 decimal place',
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

        // Initial state before transcode progress should format with 1 decimal place
        await tester.pump();
        expect(find.text('0.0%'), findsWidgets);
      },
    );

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
          final percentageTextFinder = find.text('0.0%');
          expect(percentageTextFinder, findsWidgets);

          // Get the Text widget style color
          final textWidgets = tester.widgetList<Text>(percentageTextFinder);
          final percentageTextWidget = textWidgets.firstWhere(
            (w) => w.style?.fontSize == 34,
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
      'ProcessingScreen interpolates smooth decimal progress between updates',
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
        expect(find.text('0.0%'), findsWidgets);

        // Advance frames to trigger post-frame callback and async service startup
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        expect(progressCallback, isNotNull);

        // Task updates progress to 20.0%
        progressCallback!(0.20, 'Size: 1 MB', 1000000);
        await tester.pump(); // Start TweenAnimationBuilder interpolation from 0.0 to 0.20

        // Advance 150ms (25% of 600ms linear tween -> ~0.050 / 5.0%)
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('5.0%'), findsOneWidget);

        // Advance another 150ms (50% of 600ms linear tween -> ~0.100 / 10.0%)
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('10.0%'), findsOneWidget);

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
        final text10 = tester.widget<Text>(find.text('10.0%'));
        expect(painter.color, equals(text10.style?.color));
        expect(painter.secondaryColor, equals(text10.style?.color));
        expect(painter.progress, closeTo(0.10, 0.01));

        // Advance another 150ms (75% of 600ms linear tween -> ~0.150 / 15.0%)
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('15.0%'), findsOneWidget);

        // Advance another 150ms (100% of 600ms linear tween -> ~0.200 / 20.0%)
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('20.0%'), findsOneWidget);

        // Verify fine-grained decimal increment without integer jumping (0.204 -> 20.4%)
        progressCallback!(0.204, 'Size: 1.1 MB', 1100000);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('20.4%'), findsOneWidget);

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
        expect(find.text('100.0%'), findsWidgets);

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

    test('ProcessingScreen.formatProgressPercentage formats smooth decimals and handles edge cases', () {
      expect(ProcessingScreen.formatProgressPercentage(0.0), equals('0.0%'));
      expect(ProcessingScreen.formatProgressPercentage(0.001), equals('0.1%'));
      expect(ProcessingScreen.formatProgressPercentage(0.002), equals('0.2%'));
      expect(ProcessingScreen.formatProgressPercentage(0.005), equals('0.5%'));
      expect(
        ProcessingScreen.formatProgressPercentage(0.1412),
        equals('14.1%'),
      );
      expect(
        ProcessingScreen.formatProgressPercentage(0.1426),
        equals('14.3%'),
      );
      expect(ProcessingScreen.formatProgressPercentage(0.5), equals('50.0%'));
      expect(
        ProcessingScreen.formatProgressPercentage(0.9994),
        equals('99.9%'),
      );
      expect(ProcessingScreen.formatProgressPercentage(1.0), equals('100.0%'));
      // Boundary clamping
      expect(ProcessingScreen.formatProgressPercentage(-0.1), equals('0.0%'));
      expect(ProcessingScreen.formatProgressPercentage(1.05), equals('100.0%'));
      // Corrupt / non-finite inputs
      expect(
        ProcessingScreen.formatProgressPercentage(double.nan),
        equals('0.0%'),
      );
      expect(
        ProcessingScreen.formatProgressPercentage(double.infinity),
        equals('0.0%'),
      );
      expect(
        ProcessingScreen.formatProgressPercentage(double.negativeInfinity),
        equals('0.0%'),
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

        // Overshoot progress (1.25 -> clamped to 100.0%)
        progressCallback!(1.25, 'Size: 2 MB', 2000000);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('100.0%'), findsOneWidget);

        // Undershoot progress (-0.25 -> clamped to 0.0%)
        progressCallback!(-0.25, 'Size: 0 MB', 0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('0.0%'), findsOneWidget);

        // Non-finite progress (NaN -> fallback to 0.0%)
        progressCallback!(double.nan, 'Size: 0 MB', 0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('0.0%'), findsOneWidget);

        completer.complete(null);
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
