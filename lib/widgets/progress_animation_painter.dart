// SPDX-License-Identifier: MIT
// Copyright (C) 2026 zerabyte88

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_settings.dart';

/// CustomPainter untuk rendering 5 varian gaya animasi progres:
/// - V1: Dual Ring Orbit (Cincin orbit ganda dengan satelit pemandu)
/// - V2: Radar Ripple Ring (Cincin riak radar konsentris ganda)
/// - V3: Circular Fluid Wave (Lingkaran ombak fluida dengan kurva ujung mulus)
/// - V4: Calm Liquid Orb (Bola cairan tenang seimbang diameter 142dp)
/// - V5: Flat Capsule Bar (Bar kapsul datar linier dengan efek kilau sapuan shimmer)
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

  /// V1: Dual Ring Orbit (Asli APK lama)
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

    // 1. Subtle central ambient pulse glow
    if (isProcessing) {
      final pulseAlpha = (14 + 10 * math.sin(safeAnim * 2 * math.pi)).round();
      final glowPaint = Paint()
        ..color = color.withAlpha(pulseAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSmall ? 10.0 : 18.0);
      canvas.drawCircle(center, rMid * 0.75, glowPaint);
    }

    // 2. Cincin jalur utama stroke 7.5
    final trackPaint = Paint()
      ..color = trackColor.withAlpha(isDark ? 45 : 65)
      ..strokeWidth = strokeMain
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, rMid, trackPaint);

    // 3. Cincin pemandu orbit luar (stroke 1.2 pada radius + 8)
    final orbitRadius = rMid + (isSmall ? 5.0 : 8.0);
    final orbitTrackPaint = Paint()
      ..color = color.withAlpha(isDark ? 35 : 50)
      ..strokeWidth = isSmall ? 0.9 : 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, orbitRadius, orbitTrackPaint);

    // 4. Busur pendaran sweep gradient 153° (0.85 * pi) berputar halus
    final rotAngle = safeAnim * 2 * math.pi;
    const arcLen = 0.85 * math.pi; // 153 degrees
    final orbitArcRect = Rect.fromCircle(center: center, radius: orbitRadius);
    final orbitSweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSmall ? 1.5 : 2.0
      ..strokeCap = StrokeCap.round
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

    // 5. Manik satelit orbit luar (radius 3.0)
    final satAngle = rotAngle + arcLen;
    final satX = center.dx + orbitRadius * math.cos(satAngle);
    final satY = center.dy + orbitRadius * math.sin(satAngle);
    final satRadius = isSmall ? 2.2 : 3.0;

    final satGlowPaint = Paint()
      ..color = crestColor.withAlpha(180)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSmall ? 2.5 : 4.0);
    canvas.drawCircle(Offset(satX, satY), satRadius * 1.5, satGlowPaint);

    final satPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(satX, satY), satRadius, satPaint);

    // 6. Busur progres utama stroke 7.5 dengan round cap
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

      // 7. Manik kepala bercahaya (neon halo blur + core bead putih) di ujung progres
      if (isProcessing && safeProgress > 0.01 && safeProgress < 0.999) {
        final tipAngle = -math.pi / 2 + sweepAngle;
        final tipX = center.dx + rMid * math.cos(tipAngle);
        final tipY = center.dy + rMid * math.sin(tipAngle);
        final tipPos = Offset(tipX, tipY);

        final haloPaint = Paint()
          ..color = crestColor.withAlpha(220)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSmall ? 3.5 : 5.5);
        canvas.drawCircle(tipPos, isSmall ? 3.5 : 5.0, haloPaint);

        final corePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tipPos, isSmall ? 1.6 : 2.3, corePaint);
      }
    }
  }

  /// V2: Cincin Riak Radar & Ujung Pendaran (Asli v2.3.3)
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

    final maxRippleRadius = (diameter - 6.0) / 2.0;

    // 1. Subtle central ambient glow
    if (isProcessing) {
      final pulseAlpha = (16 + 12 * math.sin(safeAnim * 2 * math.pi)).round();
      final glowPaint = Paint()
        ..color = color.withAlpha(pulseAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSmall ? 10.0 : 18.0);
      canvas.drawCircle(center, rMid * 0.70, glowPaint);
    }

    // 2. Cincin jalur utama stroke 7.5
    final trackPaint = Paint()
      ..color = trackColor.withAlpha(isDark ? 45 : 65)
      ..strokeWidth = strokeMain
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, rMid, trackPaint);

    // 3. 2 gelombang riak radar memancar keluar bertahap
    if (maxRippleRadius > rMid) {
      const rippleWaves = 2;
      for (int w = 0; w < rippleWaves; w++) {
        final phase = (safeAnim + w / rippleWaves) % 1.0;
        final currentRadius = rMid + phase * (maxRippleRadius - rMid);
        final rippleAlpha =
            ((1.0 - phase) * (isProcessing ? (isDark ? 150 : 130) : 35))
                .round();

        final ripplePaint = Paint()
          ..color = color.withAlpha(rippleAlpha)
          ..strokeWidth = isSmall ? 1.2 : 1.6
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(center, currentRadius, ripplePaint);
      }
    }

    // 4. Busur progres stroke 7.5 dengan round cap
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

      // 5. Ujung busur progres berhias manik putih menyala (halo glow blur 5.5 + white core 2.3)
      if (isProcessing && safeProgress > 0.01 && safeProgress < 0.999) {
        final tipAngle = -math.pi / 2 + sweepAngle;
        final tipX = center.dx + rMid * math.cos(tipAngle);
        final tipY = center.dy + rMid * math.sin(tipAngle);
        final tipPos = Offset(tipX, tipY);

        final haloPaint = Paint()
          ..color = crestColor.withAlpha(220)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSmall ? 3.5 : 5.5);
        canvas.drawCircle(tipPos, isSmall ? 3.5 : 5.0, haloPaint);

        final corePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tipPos, isSmall ? 1.6 : 2.3, corePaint);
      }
    }
  }

  /// V3: Lingkaran Ombak Fluida (Circular Fluid Wave Ring)
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

    // 1. Cincin jalur utama stroke 7.5
    final trackPaint = Paint()
      ..color = trackColor.withAlpha(isDark ? 45 : 65)
      ..strokeWidth = strokeMain
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, rMid, trackPaint);

    if (safeProgress <= 0.0) return;

    final sweepAngle = safeProgress * 2 * math.pi;
    final isFull = safeProgress >= 0.99;
    final halfStroke = strokeMain / 2.0;
    final waveAmp = (strokeMain * 0.28).clamp(1.0, 2.6);
    final timePhase = safeAnim * 2 * math.pi;

    double getWaveRadius(double theta, bool isLayerA, bool isOuter) {
      final baseR = isOuter ? (rMid + halfStroke) : (rMid - halfStroke);
      if (!isProcessing) return baseR;

      double envelope = 1.0;
      if (!isFull) {
        const taperAngle = math.pi / 7;
        final fromStart = math.max(0.0, theta - (-math.pi / 2));
        final fromEnd = math.max(0.0, (-math.pi / 2 + sweepAngle) - theta);
        final startT = (fromStart / taperAngle).clamp(0.0, 1.0);
        final endT = (fromEnd / taperAngle).clamp(0.0, 1.0);
        final sT = startT * startT * (3.0 - 2.0 * startT);
        final eT = endT * endT * (3.0 - 2.0 * endT);
        envelope = sT * eT;
      }

      final harmonic = isLayerA
          ? (0.65 * math.sin(4 * theta + timePhase + 1.2) +
                0.35 * math.cos(8 * theta - timePhase))
          : (0.70 * math.sin(4 * theta - timePhase) +
                0.30 * math.cos(8 * theta + 1.5 * timePhase));

      final sign = isOuter ? 1.0 : -1.0;
      return baseR + sign * waveAmp * envelope * (harmonic * 0.5 + 0.5);
    }

    Path buildWaveRibbon(bool isLayerA) {
      final path = Path();
      const startAngle = -math.pi / 2;
      final effectiveSweep = isFull ? 2 * math.pi : sweepAngle;
      final steps = (effectiveSweep / (math.pi / 36)).ceil().clamp(12, 90);

      final outerPoints = <Offset>[];
      final innerPoints = <Offset>[];

      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final theta = startAngle + t * effectiveSweep;
        final rOut = getWaveRadius(theta, isLayerA, true);
        final rIn = getWaveRadius(theta, isLayerA, false);

        outerPoints.add(
          Offset(
            center.dx + rOut * math.cos(theta),
            center.dy + rOut * math.sin(theta),
          ),
        );
        innerPoints.add(
          Offset(
            center.dx + rIn * math.cos(theta),
            center.dy + rIn * math.sin(theta),
          ),
        );
      }

      if (isFull) {
        path.moveTo(outerPoints.first.dx, outerPoints.first.dy);
        for (int i = 1; i < outerPoints.length; i++) {
          path.lineTo(outerPoints[i].dx, outerPoints[i].dy);
        }
        path.close();

        final innerPath = Path()
          ..moveTo(innerPoints.first.dx, innerPoints.first.dy);
        for (int i = 1; i < innerPoints.length; i++) {
          innerPath.lineTo(innerPoints[i].dx, innerPoints[i].dy);
        }
        innerPath.close();

        return Path.combine(PathOperation.difference, path, innerPath);
      } else {
        path.moveTo(outerPoints.first.dx, outerPoints.first.dy);
        for (int i = 1; i < outerPoints.length; i++) {
          path.lineTo(outerPoints[i].dx, outerPoints[i].dy);
        }

        // Head cap: kurva setengah lingkaran mulus melengkung ke depan searah jarum jam
        final pOutEnd = outerPoints.last;
        final pInEnd = innerPoints.last;
        final capRadiusEnd = (pOutEnd - pInEnd).distance / 2.0;
        if (capRadiusEnd > 0.1) {
          path.arcToPoint(
            pInEnd,
            radius: Radius.circular(capRadiusEnd),
            clockwise: true,
          );
        } else {
          path.lineTo(pInEnd.dx, pInEnd.dy);
        }

        // Garis tepi bagian dalam kembali ke pangkal
        for (int i = innerPoints.length - 2; i >= 0; i--) {
          path.lineTo(innerPoints[i].dx, innerPoints[i].dy);
        }

        // Tail cap: kurva setengah lingkaran mulus melengkung ke belakang di titik awal
        final pInStart = innerPoints.first;
        final pOutStart = outerPoints.first;
        final capRadiusStart = (pInStart - pOutStart).distance / 2.0;
        if (capRadiusStart > 0.1) {
          path.arcToPoint(
            pOutStart,
            radius: Radius.circular(capRadiusStart),
            clockwise: true,
          );
        } else {
          path.lineTo(pOutStart.dx, pOutStart.dy);
        }

        path.close();
        return path;
      }
    }

    // 2. Layer A: Lapisan busa ombak belakang (translucent)
    final pathA = buildWaveRibbon(true);
    final paintA = Paint()
      ..color = crestColor.withAlpha(isDark ? 100 : 130)
      ..style = PaintingStyle.fill;
    canvas.drawPath(pathA, paintA);

    // 3. Layer B: Pita ombak fluida depan utama (sweep gradient)
    final pathB = buildWaveRibbon(false);
    final bounds = Rect.fromCircle(
      center: center,
      radius: rMid + halfStroke + waveAmp,
    );
    final paintB = Paint()..style = PaintingStyle.fill;

    if (isProcessing) {
      paintB.shader = SweepGradient(
        startAngle: 0.0,
        endAngle: 2 * math.pi,
        colors: [crestColor, color, deepColor, crestColor],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(bounds);
    } else {
      paintB.color = color;
    }
    canvas.drawPath(pathB, paintB);

    // 4. Glowing head bead pada ujung pita saat belum penuh
    if (isProcessing && safeProgress > 0.02 && safeProgress < 0.99) {
      final tipAngle = -math.pi / 2 + sweepAngle;
      final tipPos = Offset(
        center.dx + rMid * math.cos(tipAngle),
        center.dy + rMid * math.sin(tipAngle),
      );

      final haloPaint = Paint()
        ..color = crestColor.withAlpha(220)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSmall ? 3.5 : 5.0);
      canvas.drawCircle(tipPos, isSmall ? 3.5 : 4.8, haloPaint);

      final corePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tipPos, isSmall ? 1.6 : 2.2, corePaint);
    }
  }

  /// V4: Bola Cairan Tenang (Calm Liquid Orb - Fluida Air Realistis)
  void _paintLiquidOrb(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    final isSmall = diameter < 120;
    final radius = isSmall ? 33.0 : 71.0;
    if (radius <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final orbRect = Rect.fromCircle(center: center, radius: radius);

    // 1. Pendaran lembut tipis di belakang bola air (ambient glow)
    if (isProcessing) {
      final pulse = 0.5 + 0.5 * math.sin(animationValue * 2 * math.pi);
      final glowPaint = Paint()
        ..color = color.withAlpha((isDark ? 22 : 16) + (pulse * 8).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSmall ? 8.0 : 16.0);
      canvas.drawCircle(center, radius + (isSmall ? 4.0 : 8.0), glowPaint);
    }

    canvas.save();
    canvas.clipPath(Path()..addOval(orbRect));

    // 2. Latar Belakang Wadah (Basin / Container Background)
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

      // Gelombang 1: Lapisan Air Belakang (Deep Back Water Wave - Translucent)
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

      // Gelombang 2: Lapisan Air Tengah (Mid Fluid Wave)
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

      // Gelombang 3: Lapisan Air Depan Utama (Foreground Fluid Wave dengan Gradien Kedalaman)
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
          ..shader = LinearGradient(
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

      // 4. Garis Permukaan Meniscus Air (Clean Fluid Meniscus Surface Line)
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

        // Garis batas permukaan air mulus
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
      // Kondisi progress 0%
      canvas.drawRect(
        orbRect,
        Paint()
          ..color = color.withAlpha(isDark ? 28 : 20)
          ..style = PaintingStyle.fill,
      );
    }

    // 6. Pantulan Kaca Lingkaran Atas-Kiri (Glass Sphere Specular Reflection)
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

    // 7. Cincin Bingkai Luar Bola (Outer Ring Border)
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
      // Komposisi Gerstner/Trochoidal Wave: puncak lebih terjal, dasar lebih landai
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

  /// V5: Bar Kapsul Datar (Flat Capsule Bar dengan efek shimmer sweep)
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
      final activePaint = Paint()..style = PaintingStyle.fill;

      // Gradien horizontal dinamis memanjang dari deepColor ke crestColor di ujung kanan
      activePaint.shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [deepColor, color, crestColor],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(activeRect);

      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, cornerRadius),
        activePaint,
      );

      // Shimmer sweep glint ke kanan sesuai pola verticalShimmerGrad di README
      if (isProcessing && activeWidth > 6.0) {
        final shimmerBandWidth = (size.width * 0.35).clamp(45.0, 90.0);
        final totalSpan = activeWidth + shimmerBandWidth * 1.5;
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
              crestColor.withAlpha(isDark ? 45 : 35),
              crestColor.withAlpha(isDark ? 215 : 185),
              Colors.white.withAlpha(isDark ? 255 : 240),
              (secondaryColor != color ? secondaryColor : crestColor).withAlpha(
                isDark ? 215 : 185,
              ),
              (secondaryColor != color ? secondaryColor : crestColor).withAlpha(
                isDark ? 45 : 35,
              ),
              Colors.white.withAlpha(0),
            ],
            stops: const [0.0, 0.38, 0.47, 0.50, 0.53, 0.62, 1.0],
          ).createShader(shimmerRect);

        canvas.drawRect(shimmerRect, shimmerPaint);
      }
      canvas.restore();

      // Aura pendaran glow lembut yang bergerak bersama sapuan shimmer ke arah kanan
      if (isProcessing && activeWidth > 6.0) {
        final shimmerBandWidth = (size.width * 0.35).clamp(45.0, 90.0);
        final totalSpan = activeWidth + shimmerBandWidth * 1.5;
        final shimmerLeft = -shimmerBandWidth + safeAnim * totalSpan;
        final glintCoreX = shimmerLeft + shimmerBandWidth * 0.5;

        if (glintCoreX >= -10.0 && glintCoreX <= activeWidth + 15.0) {
          final auraRect = Rect.fromCenter(
            center: Offset(glintCoreX, size.height / 2.0),
            width: shimmerBandWidth * 0.45,
            height: size.height * 2.2,
          );
          final auraPaint = Paint()
            ..shader = RadialGradient(
              colors: [
                crestColor.withAlpha(isDark ? 110 : 85),
                crestColor.withAlpha(0),
              ],
            ).createShader(auraRect)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
          canvas.drawOval(auraRect, auraPaint);
        }
      }
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

/// Helper internal untuk data geometri gelombang fluida dan titik permukaan
class _FluidWaveData {
  final Path bodyPath;
  final List<Offset> surfacePoints;
  const _FluidWaveData(this.bodyPath, this.surfacePoints);
}

/// Widget pratinjau animasi gaya progres (Live Animated Preview)
class ProgressStylePreviewBox extends StatefulWidget {
  final String style;
  final ThemeData theme;

  /// Flag pengontrol animasi untuk testing otomatis agar tidak memicu timeout pumpAndSettle.
  static bool enableAnimationInTests = false;

  const ProgressStylePreviewBox({
    super.key,
    required this.style,
    required this.theme,
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
    const progressVal = 0.68;

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
      '68%',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.4,
        shadows: textOutlineShadows,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    final topPercentage = Text(
      '68%',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    Widget previewContent;
    switch (normalizedStyle) {
      case 'v1': // Dual Ring Orbit: 88x88 dp, center percentage 22sp
        previewContent = SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    size: const Size(88, 88),
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
                      strokeWidth: 5.5,
                    ),
                  ),
                ),
              ),
              centerPercentage,
            ],
          ),
        );
        break;

      case 'v2': // Radar Ripple Ring: 88x88 dp, center percentage 22sp
        previewContent = SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    size: const Size(88, 88),
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
                      strokeWidth: 5.5,
                    ),
                  ),
                ),
              ),
              centerPercentage,
            ],
          ),
        );
        break;

      case 'v3': // Circular Fluid Wave: 88x88 dp, center percentage 22sp
        previewContent = SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    size: const Size(88, 88),
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
                      strokeWidth: 5.5,
                    ),
                  ),
                ),
              ),
              centerPercentage,
            ],
          ),
        );
        break;

      case 'v4': // Calm Liquid Orb: 88x88 dp, center percentage 22sp
        previewContent = SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    size: const Size(88, 88),
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
        );
        break;

      case 'v5': // Flat Capsule Bar: 200x12 dp capsule, percentage 20sp di atas bar
      default:
        previewContent = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            topPercentage,
            const SizedBox(height: 10),
            SizedBox(
              width: 200,
              height: 12,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    size: const Size(200, 12),
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
      height: 124,
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
