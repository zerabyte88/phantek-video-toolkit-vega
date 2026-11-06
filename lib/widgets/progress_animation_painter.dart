import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_settings.dart';

/// Renders 5 progress animation styles:
/// - V1: Dual Ring Orbit
/// - V2: Radar Ripple Ring
/// - V3: Serpentine Snake Ring
/// - V4: Calm Liquid Orb
/// - V5: Flat Capsule Bar
class DualRingProgressPainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final bool isProcessing;
  final bool isSuccess;
  final Color color;
  final Color secondaryColor;
  final Color deepColor;
  final Color crestColor;
  final Color basinColor;
  final Color trackColor;
  final bool isWaveform;
  final bool isDark;
  final String style;
  final double? strokeWidth;

  DualRingProgressPainter({
    required this.progress,
    required this.animationValue,
    required this.isProcessing,
    required this.isSuccess,
    required this.color,
    required this.secondaryColor,
    required this.deepColor,
    required this.crestColor,
    required this.basinColor,
    required this.trackColor,
    bool? isWaveform,
    required this.isDark,
    String? style,
    this.strokeWidth,
  }) : style = style ?? (isWaveform == true ? 'v4' : 'v1'),
       isWaveform = isWaveform ?? (style == 'v4');

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    switch (style) {
      case 'v1':
        _paintDualRingOrbit(canvas, size);
        break;
      case 'v2':
        _paintRadarRipple(canvas, size);
        break;
      case 'v3':
        _paintCircularWave(canvas, size);
        break;
      case 'v4':
        _paintLiquidOrb(canvas, size);
        break;
      case 'v5':
        _paintCapsuleBar(canvas, size);
        break;
      default:
        _paintDualRingOrbit(canvas, size);
    }
  }

  /// V1: Dual Ring Orbit
  void _paintDualRingOrbit(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    final isSmall = diameter < 120;
    final rMid = isSmall ? 33.0 : 71.0;
    final strokeMain = isSmall ? 5.5 : (strokeWidth ?? 7.5);
    final center = Offset(size.width / 2, size.height / 2);

    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0);
    final safeAnim = (animationValue.isNaN || animationValue.isInfinite)
        ? 0.0
        : animationValue;

    // Central pulse glow
    if (isProcessing) {
      final glowPulse = 0.5 + 0.5 * math.sin(safeAnim * 2 * math.pi);
      final glowRadius = rMid * 0.75;
      final glowRect = Rect.fromCircle(center: center, radius: glowRadius);
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withAlpha((isDark ? 22 : 18) + (glowPulse * 25).round()),
            color.withAlpha(0),
          ],
        ).createShader(glowRect);
      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    final trackPaint = Paint()
      ..color = trackColor.withAlpha(isDark ? 45 : 65)
      ..strokeWidth = strokeMain
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, rMid, trackPaint);

    // Outer orbit track and rotating arc
    final orbitRadius = rMid + (isSmall ? 5.0 : 8.0);
    final orbitTrackPaint = Paint()
      ..color = color.withAlpha(isDark ? 35 : 50)
      ..strokeWidth = isSmall ? 0.9 : 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, orbitRadius, orbitTrackPaint);

    final rotAngle = safeAnim * 2 * math.pi;
    const arcLen = 0.85 * math.pi; // 153 degrees
    final orbitArcRect = Rect.fromCircle(center: center, radius: orbitRadius);
    final orbitSweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSmall ? 1.5 : 2.0
      ..strokeCap = StrokeCap.butt
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: arcLen,
        colors: [
          crestColor.withAlpha(0),
          crestColor.withAlpha(isProcessing ? 200 : 80),
        ],
        transform: GradientRotation(rotAngle),
      ).createShader(orbitArcRect);
    canvas.drawArc(orbitArcRect, rotAngle, arcLen, false, orbitSweepPaint);

    // Progress arc
    final sweepAngle = safeProgress * 2 * math.pi;
    if (sweepAngle > 0) {
      final mainRect = Rect.fromCircle(center: center, radius: rMid);
      final activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeMain
        ..strokeCap = StrokeCap.round;

      if (isProcessing) {
        activePaint.shader = SweepGradient(
          startAngle: 0.0,
          endAngle: 2 * math.pi,
          colors: [crestColor, color, deepColor, crestColor],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(mainRect);
      } else {
        activePaint.color = color;
      }

      canvas.drawArc(mainRect, -math.pi / 2, sweepAngle, false, activePaint);
    }
  }

  /// V2: Radar Ripple Ring
  void _paintRadarRipple(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    final isSmall = diameter < 120;
    final rMid = isSmall ? 33.0 : 71.0;
    final strokeMain = isSmall ? 5.5 : (strokeWidth ?? 7.5);
    final center = Offset(size.width / 2, size.height / 2);

    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0);
    final safeAnim = (animationValue.isNaN || animationValue.isInfinite)
        ? 0.0
        : animationValue;

    // Central ambient glow
    if (isProcessing) {
      final glowPulse = 0.5 + 0.5 * math.sin(safeAnim * 2 * math.pi);
      final glowRadius = rMid * 0.75;
      final glowRect = Rect.fromCircle(center: center, radius: glowRadius);
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withAlpha((isDark ? 20 : 16) + (glowPulse * 28).round()),
            color.withAlpha(0),
          ],
        ).createShader(glowRect);
      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    final trackPaint = Paint()
      ..color = trackColor.withAlpha(isDark ? 45 : 65)
      ..strokeWidth = strokeMain
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, rMid, trackPaint);

    // Radar ripples
    if (isProcessing) {
      final waveSpan = isSmall ? 10.0 : 16.0;
      final waveBaseOffset = isSmall ? 3.0 : 5.0;

      final wave1Phase = safeAnim % 1.0;
      final wave1Radius = rMid + waveBaseOffset + wave1Phase * waveSpan;
      final wave1Alpha = ((1.0 - wave1Phase) * (isDark ? 175 : 155)).round();
      final wave1Paint = Paint()
        ..color = color.withAlpha(wave1Alpha)
        ..strokeWidth = isSmall ? 1.6 : 2.2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, wave1Radius, wave1Paint);

      final wave2Phase = (safeAnim + 0.5) % 1.0;
      final wave2Radius = rMid + waveBaseOffset + wave2Phase * waveSpan;
      final wave2Alpha = ((1.0 - wave2Phase) * (isDark ? 175 : 155)).round();
      final wave2Paint = Paint()
        ..color = color.withAlpha(wave2Alpha)
        ..strokeWidth = isSmall ? 1.4 : 1.8
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, wave2Radius, wave2Paint);
    }

    // Progress arc
    final sweepAngle = safeProgress * 2 * math.pi;
    if (sweepAngle > 0) {
      final mainRect = Rect.fromCircle(center: center, radius: rMid);
      final activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeMain
        ..strokeCap = StrokeCap.round;

      if (isProcessing) {
        activePaint.shader = SweepGradient(
          startAngle: 0.0,
          endAngle: 2 * math.pi,
          colors: [crestColor, color, deepColor, crestColor],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(mainRect);
      } else {
        activePaint.color = color;
      }

      canvas.drawArc(mainRect, -math.pi / 2, sweepAngle, false, activePaint);
    }
  }

  /// V3: Serpentine Snake Ring
  void _paintCircularWave(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    final isSmall = diameter < 120;
    final rMid = isSmall ? 33.0 : 71.0;
    final strokeMain = isSmall ? 5.5 : (strokeWidth ?? 7.5);
    final center = Offset(size.width / 2, size.height / 2);

    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0);
    final safeAnim = (animationValue.isNaN || animationValue.isInfinite)
        ? 0.0
        : animationValue;

    final trackPaint = Paint()
      ..color = trackColor.withAlpha(isDark ? 45 : 65)
      ..strokeWidth = strokeMain
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, rMid, trackPaint);

    if (safeProgress <= 0.0) return;

    final sweepAngle = safeProgress * 2 * math.pi;
    final isFull = safeProgress >= 0.999;
    final cycles = isSmall ? 3.0 : 4.0;
    final waveAmp = isSmall ? 2.0 : 4.0;
    final timePhase = safeAnim * 2 * math.pi;

    // Sinusoidal serpentine spine
    final spinePath = Path();
    const startAngle = -math.pi / 2;
    final effectiveSweep = isFull ? (2 * math.pi) : sweepAngle;
    final steps = (effectiveSweep / (math.pi / 180)).ceil().clamp(60, 360);

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final theta = startAngle + t * effectiveSweep;
      final r = isProcessing
          ? (rMid + waveAmp * math.sin(cycles * theta - timePhase))
          : rMid;
      final pt = Offset(
        center.dx + r * math.cos(theta),
        center.dy + r * math.sin(theta),
      );
      if (i == 0) {
        spinePath.moveTo(pt.dx, pt.dy);
      } else {
        spinePath.lineTo(pt.dx, pt.dy);
      }
    }

    if (isFull) {
      spinePath.close();
    }

    // Body aura glow
    final auraStroke = strokeMain + (isSmall ? 2.5 : 3.5);
    final auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = auraStroke
      ..strokeCap = StrokeCap.round
      ..color = crestColor.withAlpha(isDark ? 55 : 80);
    canvas.drawPath(spinePath, auraPaint);

    // Main snake body
    final bounds = Rect.fromCircle(
      center: center,
      radius: rMid + waveAmp + strokeMain,
    );
    final bodyPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeMain
      ..strokeCap = StrokeCap.round;

    if (isProcessing) {
      bodyPaint.shader = SweepGradient(
        startAngle: 0.0,
        endAngle: 2 * math.pi,
        colors: [crestColor, color, deepColor, crestColor],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(bounds);
    } else {
      bodyPaint.color = color;
    }
    canvas.drawPath(spinePath, bodyPaint);
  }

  /// V4: Calm Liquid Orb
  void _paintLiquidOrb(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    final isSmall = diameter < 120;
    final radius = isSmall ? 33.0 : 71.0;
    if (radius <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final orbRect = Rect.fromCircle(center: center, radius: radius);

    // Ambient glow
    if (isProcessing) {
      final pulse = 0.5 + 0.5 * math.sin(animationValue * 2 * math.pi);
      final glowPaint = Paint()
        ..color = color.withAlpha((isDark ? 22 : 16) + (pulse * 8).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSmall ? 8.0 : 16.0);
      canvas.drawCircle(center, radius + (isSmall ? 4.0 : 8.0), glowPaint);
    }

    canvas.save();
    canvas.clipPath(Path()..addOval(orbRect));

    // Basin background
    canvas.drawRect(
      orbRect,
      Paint()
        ..color = basinColor
        ..style = PaintingStyle.fill,
    );

    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0);
    final safeAnim = (animationValue.isNaN || animationValue.isInfinite)
        ? 0.0
        : animationValue;

    if (safeProgress > 0) {
      final effectiveFill = 0.03 + safeProgress * 0.97;
      final waterY = orbRect.bottom - (effectiveFill * orbRect.height);
      final topTaper = 1.0 - ((safeProgress - 0.92) / 0.08).clamp(0.0, 1.0);
      final amp =
          (radius * (isProcessing ? 0.075 : 0.0)).clamp(0.0, 6.5) * topTaper;

      // Back fluid wave
      final backWavePath = _buildFluidWavePath(
        orbRect: orbRect,
        waterY: waterY + 1.5,
        amp: amp * 1.1,
        cycles: 1.2,
        phase: -safeAnim * 2 * math.pi + 1.2,
        harmonicRatio: 0.15,
      );
      canvas.drawPath(
        backWavePath,
        Paint()
          ..color = crestColor.withAlpha(isDark ? 95 : 120)
          ..style = PaintingStyle.fill,
      );

      // Mid fluid wave
      final midWavePath = _buildFluidWavePath(
        orbRect: orbRect,
        waterY: waterY,
        amp: amp * 0.85,
        cycles: 1.4,
        phase: safeAnim * 2 * math.pi + math.pi,
        harmonicRatio: 0.15,
      );
      canvas.drawPath(
        midWavePath,
        Paint()
          ..color = color.withAlpha(isDark ? 140 : 160)
          ..style = PaintingStyle.fill,
      );

      // Foreground fluid wave
      final frontWaveData = _buildFluidWavePathWithSurface(
        orbRect: orbRect,
        waterY: waterY,
        amp: amp,
        cycles: 1.15,
        phase: safeAnim * 2 * math.pi,
        harmonicRatio: 0.18,
      );
      canvas.drawPath(
        frontWaveData.bodyPath,
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withAlpha(isDark ? 230 : 210),
                  deepColor,
                  deepColor.withAlpha(255),
                ],
                stops: const [0.0, 0.45, 1.0],
              ).createShader(
                Rect.fromLTRB(
                  orbRect.left,
                  waterY - amp,
                  orbRect.right,
                  orbRect.bottom,
                ),
              )
          ..style = PaintingStyle.fill,
      );

      // Meniscus line
      if (frontWaveData.surfacePoints.length > 1) {
        final surfacePath = Path()
          ..moveTo(
            frontWaveData.surfacePoints.first.dx,
            frontWaveData.surfacePoints.first.dy,
          );
        for (int i = 1; i < frontWaveData.surfacePoints.length; i++) {
          surfacePath.lineTo(
            frontWaveData.surfacePoints[i].dx,
            frontWaveData.surfacePoints[i].dy,
          );
        }

        canvas.drawPath(
          surfacePath,
          Paint()
            ..color = crestColor.withAlpha(isDark ? 210 : 230)
            ..strokeWidth = isSmall ? 1.4 : 1.9
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
    } else {
      canvas.drawRect(
        orbRect,
        Paint()
          ..color = color.withAlpha(isDark ? 28 : 20)
          ..style = PaintingStyle.fill,
      );
    }

    // Specular reflection
    final glassRect = Rect.fromCircle(
      center: center,
      radius: radius - (isSmall ? 2.5 : 4.0),
    );
    final glassPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSmall ? 2.0 : 2.8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 0.5,
        colors: [
          Colors.white.withAlpha(0),
          Colors.white.withAlpha(isDark ? 95 : 120),
          Colors.white.withAlpha(0),
        ],
        transform: const GradientRotation(-math.pi * 0.85),
      ).createShader(glassRect);
    canvas.drawArc(
      glassRect,
      -math.pi * 0.85,
      math.pi * 0.5,
      false,
      glassPaint,
    );

    canvas.restore();

    // Outer ring border
    final borderStroke = isSmall ? 2.2 : 3.0;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withAlpha(isProcessing ? 230 : 255)
        ..strokeWidth = borderStroke
        ..style = PaintingStyle.stroke,
    );
  }

  Path _buildFluidWavePath({
    required Rect orbRect,
    required double waterY,
    required double amp,
    required double cycles,
    required double phase,
    required double harmonicRatio,
  }) {
    return _buildFluidWavePathWithSurface(
      orbRect: orbRect,
      waterY: waterY,
      amp: amp,
      cycles: cycles,
      phase: phase,
      harmonicRatio: harmonicRatio,
    ).bodyPath;
  }

  _FluidWaveData _buildFluidWavePathWithSurface({
    required Rect orbRect,
    required double waterY,
    required double amp,
    required double cycles,
    required double phase,
    required double harmonicRatio,
  }) {
    const steps = 60;
    final startX = orbRect.left - 4.0;
    final endX = orbRect.right + 4.0;
    final span = endX - startX;
    final bottomY = orbRect.bottom + 4.0;
    final path = Path();
    final surfacePoints = <Offset>[];

    for (int i = 0; i <= steps; i++) {
      final x = startX + (span * i / steps);
      final nx = (x - orbRect.left) / orbRect.width;
      final theta = nx * cycles * 2 * math.pi + phase;
      // Trochoidal wave offset
      final waveOffset =
          math.sin(theta) + harmonicRatio * math.sin(2 * theta + 0.6);
      final y = waterY + waveOffset * amp;
      final pt = Offset(x, y);
      surfacePoints.add(pt);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.lineTo(endX, bottomY);
    path.lineTo(startX, bottomY);
    path.close();

    return _FluidWaveData(path, surfacePoints);
  }

  /// V5: Flat Capsule Bar
  void _paintCapsuleBar(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cornerRadius = Radius.circular(size.height / 2.0);
    final rrect = RRect.fromRectAndRadius(fullRect, cornerRadius);

    final trackPaint = Paint()
      ..color = trackColor.withAlpha(isDark ? 45 : 60)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, trackPaint);

    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0);
    final safeAnim = (animationValue.isNaN || animationValue.isInfinite)
        ? 0.0
        : animationValue;
    final activeWidth = (size.width * safeProgress).clamp(0.0, size.width);

    if (activeWidth > 0) {
      final activeRect = Rect.fromLTWH(0, 0, activeWidth, size.height);
      final activeRRect = RRect.fromRectAndRadius(activeRect, cornerRadius);
      final activePaint = Paint()..style = PaintingStyle.fill;

      activePaint.shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [deepColor, color, crestColor],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(activeRect);

      canvas.save();
      // Clip to active progress bar
      canvas.clipRRect(activeRRect);
      canvas.drawRRect(activeRRect, activePaint);

      // Shimmer glint & ambient highlight
      if (isProcessing && activeWidth > 6.0) {
        final shimmerBandWidth = (size.width * 0.4).clamp(60.0, 110.0);
        final totalSpan = size.width + shimmerBandWidth * 1.5;
        final shimmerLeft = -shimmerBandWidth + safeAnim * totalSpan;
        final shimmerRect = Rect.fromLTWH(
          shimmerLeft,
          0,
          shimmerBandWidth,
          size.height,
        );

        final shimmerPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withAlpha(0),
              crestColor.withAlpha(isDark ? 50 : 40),
              Colors.white.withAlpha(isDark ? 230 : 210),
              crestColor.withAlpha(isDark ? 50 : 40),
              Colors.white.withAlpha(0),
            ],
            stops: const [0.0, 0.28, 0.50, 0.72, 1.0],
          ).createShader(shimmerRect);

        canvas.drawRect(shimmerRect, shimmerPaint);

        // Ambient glow
        final glintCoreX = shimmerLeft + shimmerBandWidth * 0.5;
        if (glintCoreX >= -10.0 && glintCoreX <= activeWidth + 10.0) {
          final auraRect = Rect.fromCenter(
            center: Offset(glintCoreX, size.height / 2.0),
            width: shimmerBandWidth * 0.5,
            height: size.height * 2.2,
          );
          final auraPaint = Paint()
            ..shader = RadialGradient(
              center: Alignment.center,
              colors: [
                crestColor.withAlpha(isDark ? 100 : 75),
                crestColor.withAlpha(0),
              ],
            ).createShader(auraRect);
          canvas.drawOval(auraRect, auraPaint);
        }
      }

      // Soft breathing glow at the leading active edge
      if (activeWidth > 8.0) {
        final capGlowRadius = size.height * 0.9;
        final capGlowPulse = 0.5 + 0.5 * math.sin(safeAnim * 2 * math.pi);
        final capPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              crestColor.withAlpha(
                (isDark ? 70 : 50) + (capGlowPulse * 30).round(),
              ),
              crestColor.withAlpha(0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(activeWidth - 2, size.height / 2),
              radius: capGlowRadius,
            ),
          );
        canvas.drawCircle(
          Offset(activeWidth - 2, size.height / 2),
          capGlowRadius,
          capPaint,
        );
      }
      canvas.restore();
    }

    final borderPaint = Paint()
      ..color = color.withAlpha(isDark ? 40 : 30)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant DualRingProgressPainter oldDelegate) {
    final progressChanged =
        oldDelegate.progress != progress &&
        !(oldDelegate.progress.isNaN && progress.isNaN);
    final animChanged =
        oldDelegate.animationValue != animationValue &&
        !(oldDelegate.animationValue.isNaN && animationValue.isNaN);
    return progressChanged ||
        animChanged ||
        oldDelegate.isProcessing != isProcessing ||
        oldDelegate.isSuccess != isSuccess ||
        oldDelegate.color != color ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.deepColor != deepColor ||
        oldDelegate.crestColor != crestColor ||
        oldDelegate.basinColor != basinColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.isWaveform != isWaveform ||
        oldDelegate.style != style ||
        oldDelegate.isDark != isDark ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Internal helper for fluid wave geometry.
class _FluidWaveData {
  final Path bodyPath;
  final List<Offset> surfacePoints;
  const _FluidWaveData(this.bodyPath, this.surfacePoints);
}

/// Animated preview for progress style picker.
class ProgressStylePreviewBox extends StatefulWidget {
  final String style;
  final ThemeData theme;
  final double? progress;

  /// Disables animation in automated tests.
  static bool enableAnimationInTests = false;

  const ProgressStylePreviewBox({
    super.key,
    required this.style,
    required this.theme,
    this.progress,
  });

  @override
  State<ProgressStylePreviewBox> createState() =>
      ProgressStylePreviewBoxState();
}

class ProgressStylePreviewBoxState extends State<ProgressStylePreviewBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  AnimationController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test') &&
        !ProgressStylePreviewBox.enableAnimationInTests;
    if (!isTesting) {
      _controller.repeat();
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
  }

  @override
  void didUpdateWidget(covariant ProgressStylePreviewBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimationState();
  }

  void _syncAnimationState() {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test') &&
        !ProgressStylePreviewBox.enableAnimationInTests;

    if (disableAnimations || isTesting) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      if (_controller.value == 0.0) {
        _controller.value = 0.5;
      }
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final hsl = HSLColor.fromColor(primary);
    final crest = hsl
        .withLightness(
          (hsl.lightness + (isDark ? 0.22 : 0.18)).clamp(0.0, 0.95),
        )
        .withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0))
        .toColor();
    final deep = hsl
        .withLightness((hsl.lightness - 0.22).clamp(0.05, 1.0))
        .toColor();
    final basin = isDark
        ? Color.alphaBlend(primary.withAlpha(20), theme.colorScheme.surface)
        : Color.alphaBlend(
            primary.withAlpha(14),
            theme.colorScheme.surfaceContainerLowest,
          );
    final track = isDark ? primary.withAlpha(40) : primary.withAlpha(30);

    final normalizedStyle = AppSettings.sanitizeProgressStyle(widget.style);
    final progressVal = (widget.progress ?? 0.68).clamp(0.0, 1.0);
    final pctInt = (progressVal * 100).round();
    final pctString = '$pctInt%';

    final textOutlineShadows = [
      Shadow(
        offset: const Offset(-0.6, -0.6),
        blurRadius: 0.3,
        color: basin.withAlpha(220),
      ),
      Shadow(
        offset: const Offset(0.6, -0.6),
        blurRadius: 0.3,
        color: basin.withAlpha(220),
      ),
      Shadow(
        offset: const Offset(0.6, 0.6),
        blurRadius: 0.3,
        color: basin.withAlpha(220),
      ),
      Shadow(
        offset: const Offset(-0.6, 0.6),
        blurRadius: 0.3,
        color: basin.withAlpha(220),
      ),
    ];

    final centerPercentage = Text(
      pctString,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.4,
        shadows: textOutlineShadows,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    final topPercentage = Text(
      pctString,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    Widget previewContent;
    switch (normalizedStyle) {
      case 'v1': // Dual Ring Orbit: enlarged 140x140 dp (180x180 canvas), center percentage 28sp
        previewContent = SizedBox(
          width: 140,
          height: 140,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        size: const Size(180, 180),
                        painter: DualRingProgressPainter(
                          progress: progressVal,
                          animationValue: _controller.value,
                          isProcessing: true,
                          isSuccess: false,
                          color: primary,
                          secondaryColor: primary,
                          deepColor: deep,
                          crestColor: crest,
                          basinColor: basin,
                          trackColor: track,
                          style: 'v1',
                          isDark: isDark,
                          strokeWidth: 7.5,
                        ),
                      ),
                    ),
                  ),
                  centerPercentage,
                ],
              ),
            ),
          ),
        );
        break;

      case 'v2': // Radar Ripple Ring: enlarged 140x140 dp (180x180 canvas), center percentage 28sp
        previewContent = SizedBox(
          width: 140,
          height: 140,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        size: const Size(180, 180),
                        painter: DualRingProgressPainter(
                          progress: progressVal,
                          animationValue: _controller.value,
                          isProcessing: true,
                          isSuccess: false,
                          color: primary,
                          secondaryColor: primary,
                          deepColor: deep,
                          crestColor: crest,
                          basinColor: basin,
                          trackColor: track,
                          style: 'v2',
                          isDark: isDark,
                          strokeWidth: 7.5,
                        ),
                      ),
                    ),
                  ),
                  centerPercentage,
                ],
              ),
            ),
          ),
        );
        break;

      case 'v3': // Circular Fluid Wave: enlarged 140x140 dp (180x180 canvas), center percentage 28sp
        previewContent = SizedBox(
          width: 140,
          height: 140,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        size: const Size(180, 180),
                        painter: DualRingProgressPainter(
                          progress: progressVal,
                          animationValue: _controller.value,
                          isProcessing: true,
                          isSuccess: false,
                          color: primary,
                          secondaryColor: primary,
                          deepColor: deep,
                          crestColor: crest,
                          basinColor: basin,
                          trackColor: track,
                          style: 'v3',
                          isDark: isDark,
                          strokeWidth: 7.5,
                        ),
                      ),
                    ),
                  ),
                  centerPercentage,
                ],
              ),
            ),
          ),
        );
        break;

      case 'v4': // Calm Liquid Orb: enlarged 140x140 dp (180x180 canvas), center percentage 28sp
        previewContent = SizedBox(
          width: 140,
          height: 140,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        size: const Size(180, 180),
                        painter: DualRingProgressPainter(
                          progress: progressVal,
                          animationValue: _controller.value,
                          isProcessing: true,
                          isSuccess: false,
                          color: primary,
                          secondaryColor: primary,
                          deepColor: deep,
                          crestColor: crest,
                          basinColor: basin,
                          trackColor: track,
                          style: 'v4',
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                  centerPercentage,
                ],
              ),
            ),
          ),
        );
        break;

      case 'v5': // Flat Capsule Bar: enlarged 250x16 dp capsule, percentage 24sp di atas bar
      default:
        previewContent = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            topPercentage,
            const SizedBox(height: 12),
            SizedBox(
              width: 250,
              height: 16,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    size: const Size(250, 16),
                    painter: DualRingProgressPainter(
                      progress: progressVal,
                      animationValue: _controller.value,
                      isProcessing: true,
                      isSuccess: false,
                      color: primary,
                      secondaryColor: primary,
                      deepColor: deep,
                      crestColor: crest,
                      basinColor: basin,
                      trackColor: track,
                      style: 'v5',
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
        break;
    }

    return Container(
      height: 168,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withAlpha(110)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155).withAlpha(180)
              : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      alignment: Alignment.center,
      child: previewContent,
    );
  }
}
