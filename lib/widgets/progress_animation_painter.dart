import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_settings.dart';

/// Renders 6 progress animation styles:
/// - V1: Dual Ring Orbit
/// - V2: Radar Ripple Ring
/// - V3: Serpentine Snake Ring
/// - V4: Calm Liquid Orb
/// - V5: Flat Capsule Bar
/// - V6: Zig-Zag Snake Bar
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
      case 'v6':
        _paintSerpentineBar(canvas, size);
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

  /// V3: Serpentine Snake Ring (Circular 1:1 counterpart of V6)
  void _paintCircularWave(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    final isSmall = diameter < 120;
    final rMid = isSmall ? 33.0 : 71.0;
    final center = Offset(size.width / 2, size.height / 2);

    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0);
    final safeAnim = (animationValue.isNaN || animationValue.isInfinite)
        ? 0.0
        : animationValue;

    // Central pulse glow (matching V1 & V2)
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

    // Sleek guide track circle matching V6 style
    final trackPaint = Paint()
      ..color = trackColor.withAlpha(isDark ? 35 : 50)
      ..strokeWidth = isSmall ? 1.5 : 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, rMid, trackPaint);

    if (safeProgress <= 0.0) return;

    const startAngle = -math.pi / 2;
    final sweepAngle = safeProgress * 2 * math.pi;
    final isFull = safeProgress >= 0.999;
    final effectiveSweep = isFull ? (2 * math.pi) : sweepAngle;
    final cycles = isSmall ? 3.5 : 4.5;
    final waveAmp = isSmall ? 2.5 : 4.5;
    final omegaT = safeAnim * 2 * math.pi;

    final steps = (effectiveSweep / (math.pi / 180)).ceil().clamp(60, 360);
    final spinePath = Path();

    Offset tailPos = Offset.zero;
    double phiTail = 0.0;
    Offset headPos = Offset.zero;
    double phiHead = 0.0;

    for (int i = 0; i <= steps; i++) {
      final alpha = (i / steps) * effectiveSweep;
      final theta = startAngle + alpha;
      final r = isProcessing
          ? (rMid + waveAmp * math.sin(cycles * alpha + omegaT))
          : rMid;
      final pt = Offset(
        center.dx + r * math.cos(theta),
        center.dy + r * math.sin(theta),
      );

      if (i == 0) {
        spinePath.moveTo(pt.dx, pt.dy);
        tailPos = pt;
        final dr = isProcessing
            ? (waveAmp * cycles * math.cos(cycles * alpha + omegaT))
            : 0.0;
        final dx = dr * math.cos(theta) - r * math.sin(theta);
        final dy = dr * math.sin(theta) + r * math.cos(theta);
        phiTail = math.atan2(dy, dx);
      } else {
        spinePath.lineTo(pt.dx, pt.dy);
      }

      if (i == steps) {
        headPos = pt;
        final dr = isProcessing
            ? (waveAmp * cycles * math.cos(cycles * alpha + omegaT))
            : 0.0;
        final dx = dr * math.cos(theta) - r * math.sin(theta);
        final dy = dr * math.sin(theta) + r * math.cos(theta);
        phiHead = math.atan2(dy, dx);
      }
    }

    if (isFull) {
      spinePath.close();
    }

    // 1. Aura underlayer
    final auraStroke = isSmall ? 8.0 : 10.0;
    final auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = auraStroke
      ..strokeCap = StrokeCap.round
      ..color = crestColor.withAlpha(isDark ? 45 : 30);
    canvas.drawPath(spinePath, auraPaint);

    // 2. Main spine with SweepGradient [deepColor, color, crestColor]
    final spineStroke = isSmall ? 4.5 : 5.5;
    final bounds = Rect.fromCircle(
      center: center,
      radius: rMid + waveAmp + spineStroke,
    );
    final spinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = spineStroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + effectiveSweep,
        colors: [deepColor, color, crestColor],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(bounds);
    canvas.drawPath(spinePath, spinePaint);

    // 3. Ekor Melonjong (Tail)
    canvas.save();
    canvas.translate(tailPos.dx, tailPos.dy);
    canvas.rotate(phiTail);
    final tailOval = Rect.fromCenter(
      center: Offset.zero,
      width: isSmall ? 7.0 : 9.5,
      height: isSmall ? 4.0 : 5.5,
    );
    final tailPaint = Paint()
      ..color = deepColor.withAlpha(isDark ? 220 : 200)
      ..style = PaintingStyle.fill;
    canvas.drawOval(tailOval, tailPaint);
    canvas.restore();

    // 4. Kepala Melonjong (Head)
    canvas.save();
    canvas.translate(headPos.dx, headPos.dy);
    canvas.rotate(phiHead);

    // Pulsing flare oval
    final flarePulse = 0.5 + 0.5 * math.sin(safeAnim * 4 * math.pi);
    final flareW = (isSmall ? 15.0 : 21.0) + (isSmall ? 3.0 : 4.0) * flarePulse;
    final flareH = (isSmall ? 10.0 : 13.5) + (isSmall ? 2.0 : 3.0) * flarePulse;
    final flareOval = Rect.fromCenter(
      center: Offset(isSmall ? 0.7 : 1.0, 0),
      width: flareW,
      height: flareH,
    );
    final flarePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          crestColor.withAlpha(isDark ? 90 : 70),
          crestColor.withAlpha(0),
        ],
      ).createShader(flareOval);
    canvas.drawOval(flareOval, flarePaint);

    // Solid elongated oval head
    final headW = isSmall ? 9.5 : 13.0;
    final headH = isSmall ? 5.5 : 7.2;
    final headOval = Rect.fromCenter(
      center: Offset(isSmall ? 0.7 : 1.0, 0),
      width: headW,
      height: headH,
    );
    final headPaint = Paint()
      ..color = crestColor
      ..style = PaintingStyle.fill;
    canvas.drawOval(headOval, headPaint);

    // Inner glint
    final glintW = isSmall ? 3.0 : 4.0;
    final glintH = isSmall ? 1.6 : 2.2;
    final glintOval = Rect.fromCenter(
      center: Offset(isSmall ? 1.4 : 2.0, isSmall ? -0.7 : -1.0),
      width: glintW,
      height: glintH,
    );
    final glintPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawOval(glintOval, glintPaint);

    canvas.restore();
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
        final shimmerBandWidth = (activeWidth * 0.45).clamp(45.0, 85.0);
        final totalSpan = activeWidth + shimmerBandWidth;
        final shimmerLeft = -shimmerBandWidth + safeAnim * totalSpan;
        final shimmerRect = Rect.fromLTWH(
          shimmerLeft,
          0,
          shimmerBandWidth,
          size.height,
        );

        final shimmerPaint = Paint()
          ..shader = LinearGradient(
            begin: const Alignment(-0.2, -1.0),
            end: const Alignment(0.2, 1.0),
            colors: [
              Colors.white.withAlpha(0),
              crestColor.withAlpha(isDark ? 55 : 40),
              (isDark ? Colors.white : crestColor).withAlpha(
                isDark ? 230 : 210,
              ),
              crestColor.withAlpha(isDark ? 55 : 40),
              Colors.white.withAlpha(0),
            ],
            stops: const [0.0, 0.28, 0.50, 0.72, 1.0],
          ).createShader(shimmerRect);

        canvas.drawRect(shimmerRect, shimmerPaint);

        // Ambient glow
        final glintCoreX = shimmerLeft + shimmerBandWidth * 0.5;
        if (glintCoreX >= -shimmerBandWidth * 0.3 &&
            glintCoreX <= activeWidth + shimmerBandWidth * 0.3) {
          final auraRect = Rect.fromCenter(
            center: Offset(glintCoreX, size.height / 2.0),
            width: shimmerBandWidth * 0.65,
            height: size.height * 2.2,
          );
          final auraPaint = Paint()
            ..shader = RadialGradient(
              center: Alignment.center,
              colors: [
                crestColor.withAlpha(isDark ? 90 : 70),
                crestColor.withAlpha(0),
              ],
            ).createShader(auraRect);
          canvas.drawOval(auraRect, auraPaint);
        }
      }

      // Soft breathing glow at the leading active edge
      if (activeWidth > 8.0) {
        final capRadius = size.height * 0.75;
        final capCenterX = (activeWidth - size.height / 2.0).clamp(
          0.0,
          size.width,
        );
        final capGlowPulse = 0.5 + 0.5 * math.sin(safeAnim * 2 * math.pi);
        final capPaint = Paint()
          ..shader =
              RadialGradient(
                colors: [
                  crestColor.withAlpha(
                    (isDark ? 65 : 45) + (capGlowPulse * 30).round(),
                  ),
                  crestColor.withAlpha(0),
                ],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(capCenterX, size.height / 2),
                  radius: capRadius,
                ),
              );
        canvas.drawCircle(
          Offset(capCenterX, size.height / 2),
          capRadius,
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

  /// V6: Zig-Zag Snake Bar (Border-free with organic elongated head & tail)
  void _paintSerpentineBar(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cornerRadius = Radius.circular(size.height / 2.0);
    final rrect = RRect.fromRectAndRadius(fullRect, cornerRadius);

    // 1. Soft track background fill (no capsule border line)
    final trackPaint = Paint()
      ..color = trackColor.withAlpha(isDark ? 35 : 50)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, trackPaint);

    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0);
    final safeAnim = (animationValue.isNaN || animationValue.isInfinite)
        ? 0.0
        : animationValue;

    // Horizontal padding to prevent head and tail clipping at canvas boundaries
    const pad = 8.0;
    final usableWidth = math.max(0.0, size.width - 2 * pad);
    final activeDist = usableWidth > 0
        ? (usableWidth * safeProgress).clamp(0.0, usableWidth)
        : 0.0;
    final headX = pad + activeDist;
    final tailX = pad;
    final yCenter = size.height / 2.0;

    // Center guideline
    if (usableWidth > 0) {
      final guidePaint = Paint()
        ..color = trackColor.withAlpha(isDark ? 25 : 35)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(pad, yCenter),
        Offset(size.width - pad, yCenter),
        guidePaint,
      );
    }

    if (activeDist > 0 && usableWidth > 0) {
      // Undulation wave parameters
      const amplitude = 4.0;
      final k = (2 * math.pi * 4.5) / usableWidth;
      final omegaT = safeAnim * 2 * math.pi;

      double getY(double x) =>
          yCenter + amplitude * math.sin(k * (x - pad) + omegaT);
      double getSlope(double x) =>
          amplitude * k * math.cos(k * (x - pad) + omegaT);

      // Undulating serpentine path from tailX to headX
      final path = Path()..moveTo(tailX, getY(tailX));
      for (double x = tailX + 1.5; x < headX; x += 1.5) {
        path.lineTo(x, getY(x));
      }
      path.lineTo(headX, getY(headX));

      // 1. Aura underlayer
      final auraPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 9.0
        ..color = crestColor.withAlpha(isDark ? 45 : 30);
      canvas.drawPath(path, auraPaint);

      // 2. Spine with linear gradient
      final activeRect = Rect.fromLTWH(tailX, 0, activeDist, size.height);
      final spinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5.0
        ..shader = LinearGradient(
          colors: [deepColor, color, crestColor],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(activeRect);
      canvas.drawPath(path, spinePaint);

      // 3. Tail (Ekor Melonjong) rotated by wave tangent angle
      canvas.save();
      canvas.translate(tailX, getY(tailX));
      final tailTheta = math.atan(getSlope(tailX));
      canvas.rotate(tailTheta);
      final tailOval = Rect.fromCenter(
        center: Offset.zero,
        width: 9.0,
        height: 5.5,
      );
      final tailPaint = Paint()
        ..color = deepColor.withAlpha(isDark ? 220 : 200)
        ..style = PaintingStyle.fill;
      canvas.drawOval(tailOval, tailPaint);
      canvas.restore();

      // 4. Head (Kepala Melonjong) rotated by wave tangent angle
      canvas.save();
      canvas.translate(headX, getY(headX));
      final headTheta = math.atan(getSlope(headX));
      canvas.rotate(headTheta);

      // Pulsing flare oval
      final flarePulse = 0.5 + 0.5 * math.sin(safeAnim * 4 * math.pi);
      final flareOval = Rect.fromCenter(
        center: const Offset(1.0, 0),
        width: 20.0 + 4.0 * flarePulse,
        height: 13.0 + 3.0 * flarePulse,
      );
      final flarePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            crestColor.withAlpha(isDark ? 90 : 70),
            crestColor.withAlpha(0),
          ],
        ).createShader(flareOval);
      canvas.drawOval(flareOval, flarePaint);

      // Solid elongated oval head
      final headOval = Rect.fromCenter(
        center: const Offset(1.0, 0),
        width: 12.5,
        height: 7.0,
      );
      final headPaint = Paint()
        ..color = crestColor
        ..style = PaintingStyle.fill;
      canvas.drawOval(headOval, headPaint);

      // Inner glint oval
      final glintOval = Rect.fromCenter(
        center: const Offset(2.0, -1.0),
        width: 4.0,
        height: 2.2,
      );
      final glintPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawOval(glintOval, glintPaint);

      canvas.restore();
    }
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

      case 'v6': // Zig-Zag Snake Bar: enlarged 250x20 dp, percentage 24sp di atas bar
      default:
        previewContent = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            topPercentage,
            const SizedBox(height: 12),
            SizedBox(
              width: 250,
              height: 20,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    size: const Size(250, 20),
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
                      style: 'v6',
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
