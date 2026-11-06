import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_settings.dart';

/// Renders 8 progress animation styles:
/// - V1: Orbit (Circular 180x180 dp)
/// - V2: Radar (Circular 180x180 dp)
/// - V3: Liquid (Circular 180x180 dp)
/// - V4: Particles (Circular 180x180 dp)
/// - V5: Spiral (Circular 180x180 dp)
/// - V6: Zig-Zag (Flat Bar 280x20 dp)
/// - V7: Capsule (Flat Bar 280x16 dp)
/// - V8: Equalizer (Flat Bar 280x24 dp)
class DualRingProgressPainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final double? animTime;
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
    this.animTime,
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

  double get _effectiveTime => animTime ?? (animationValue * 2.4);

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
        _paintLiquidOrb(canvas, size);
        break;
      case 'v4':
        _paintQuantumCollider(canvas, size);
        break;
      case 'v5':
        _paintGalaxyVortex(canvas, size);
        break;
      case 'v6':
        _paintSerpentineBar(canvas, size);
        break;
      case 'v7':
        _paintCapsuleBar(canvas, size);
        break;
      case 'v8':
        _paintSoundwaveBar(canvas, size);
        break;
      default:
        _paintDualRingOrbit(canvas, size);
    }
  }

  /// Shared renderer for circular progress arcs with zero white-tail artifact and smooth 100% color unification
  void _drawCircularProgressArc({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double strokeWidth,
    required double safeProgress,
    bool withGlowAura = false,
    double auraStrokeWidth = 0.0,
  }) {
    final sweepAngle = safeProgress * 2 * math.pi;
    if (sweepAngle <= 0) return;

    final mainRect = Rect.fromCircle(center: center, radius: radius);
    final isFull = safeProgress >= 0.999;
    final u = (safeProgress >= 0.88)
        ? ((safeProgress - 0.88) / 0.12).clamp(0.0, 1.0)
        : 0.0;
    final headColor = Color.lerp(crestColor, deepColor, u) ?? crestColor;

    const capPad = 0.12;
    final effectiveSweep = isFull ? (2 * math.pi) : sweepAngle;
    final totalSpan = capPad + effectiveSweep;
    final stopTail = (capPad / totalSpan).clamp(0.0, 1.0);
    final stopMid = ((capPad + effectiveSweep * 0.5) / totalSpan).clamp(
      0.0,
      1.0,
    );

    if (withGlowAura && auraStrokeWidth > 0) {
      final auraPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = auraStrokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2 - capPad,
          endAngle: -math.pi / 2 + math.max(effectiveSweep, 0.001),
          colors: [
            deepColor.withAlpha(isDark ? 40 : 25),
            deepColor.withAlpha(isDark ? 40 : 25),
            color.withAlpha(isDark ? 65 : 45),
            headColor.withAlpha(isDark ? 90 : 70),
          ],
          stops: [0.0, stopTail, stopMid, 1.0],
        ).createShader(mainRect);
      canvas.drawArc(mainRect, -math.pi / 2, effectiveSweep, false, auraPaint);
    }

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2 - capPad,
        endAngle: -math.pi / 2 + math.max(effectiveSweep, 0.001),
        colors: [deepColor, deepColor, color, headColor],
        stops: [0.0, stopTail, stopMid, 1.0],
      ).createShader(mainRect);

    canvas.drawArc(mainRect, -math.pi / 2, effectiveSweep, false, activePaint);
  }

  /// V1: Orbit
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

    // Central soft radial pulse glow
    if (isProcessing) {
      final glowPulse = 0.5 + 0.5 * math.sin(safeAnim * 2 * math.pi);
      final glowRadius = isSmall ? rMid * 0.75 : 55.0;
      final glowRect = Rect.fromCircle(center: center, radius: glowRadius);
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withAlpha(
              ((isDark ? 0.20 : 0.16) * glowPulse * 255).round().clamp(0, 255),
            ),
            color.withAlpha(0),
          ],
        ).createShader(glowRect);
      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    // Main Track ring
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeMain
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, rMid, trackPaint);

    // Outer orbit arc (153 degrees rotating 360 degrees via canvas transform to prevent gradient branch cut glitch)
    if (isProcessing) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(safeAnim * 2 * math.pi);
      final orbitRadius = rMid + (isSmall ? 5.0 : 8.0);
      const arcLen = 153.0 * math.pi / 180.0;
      final orbitArcRect = Rect.fromCircle(
        center: Offset.zero,
        radius: orbitRadius,
      );
      final orbitStroke = isSmall ? 2.0 : 2.8;
      final orbitAlpha = (0.65 * 255).round();

      final orbitSweepPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = orbitStroke
        ..strokeCap = StrokeCap.butt
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + arcLen,
          colors: [
            deepColor.withAlpha(0),
            color.withAlpha((orbitAlpha * 0.45).round()),
            crestColor.withAlpha(orbitAlpha),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(orbitArcRect);
      canvas.drawArc(
        orbitArcRect,
        -math.pi / 2,
        arcLen,
        false,
        orbitSweepPaint,
      );

      final headAngle = -math.pi / 2 + arcLen;
      final headX = orbitRadius * math.cos(headAngle);
      final headY = orbitRadius * math.sin(headAngle);
      final headCapPaint = Paint()
        ..color = crestColor.withAlpha(orbitAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(headX, headY), orbitStroke / 2.0, headCapPaint);
      canvas.restore();
    }

    // Progress arc
    _drawCircularProgressArc(
      canvas: canvas,
      center: center,
      radius: rMid,
      strokeWidth: strokeMain,
      safeProgress: safeProgress,
    );
  }

  /// V2: Radar
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

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeMain
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, rMid, trackPaint);

    // 2 concentric radar ripples expanding from rMid to rMid + 16.0
    if (isProcessing) {
      final waveSpan = isSmall ? 10.0 : 16.0;
      final rippleStroke = isSmall ? 1.6 : 2.2;

      for (int i = 0; i < 2; i++) {
        final ripplePhase = (safeAnim + i * 0.5) % 1.0;
        final rippleR = rMid + ripplePhase * waveSpan;
        final alpha = ((1.0 - ripplePhase) * 0.65 * 255).round().clamp(0, 255);
        final rippleColor =
            Color.lerp(crestColor, deepColor, ripplePhase) ?? color;
        final ripplePaint = Paint()
          ..color = rippleColor.withAlpha(alpha)
          ..strokeWidth = rippleStroke
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(center, rippleR, ripplePaint);
      }
    }

    // Progress arc
    _drawCircularProgressArc(
      canvas: canvas,
      center: center,
      radius: rMid,
      strokeWidth: strokeMain,
      safeProgress: safeProgress,
    );
  }

  /// V3: Liquid (Calm Liquid Orb matching renderV3 in conversion_bar_mockups.html)
  void _paintLiquidOrb(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    final isSmall = diameter < 120;
    final radius = isSmall ? 33.0 : 71.0;
    if (radius <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final orbRect = Rect.fromCircle(center: center, radius: radius);

    // Basin background
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = basinColor
        ..style = PaintingStyle.fill,
    );

    // Outer track border (stroke 3.0 matching mockup)
    final borderStroke = isSmall ? 2.2 : 3.0;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..strokeWidth = borderStroke
        ..style = PaintingStyle.stroke,
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius - 1.5)),
    );

    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0);
    final safeAnim = (animationValue.isNaN || animationValue.isInfinite)
        ? 0.0
        : animationValue;

    if (safeProgress > 0) {
      final waterLevelY = (center.dy + radius) - (safeProgress * (2 * radius));
      final amp = isProcessing ? (isSmall ? 2.5 : 4.0) : 0.0;
      final waveFreq = isSmall ? 0.10 : 0.05;
      final phase = safeAnim * 2 * math.pi;

      final wavePath = Path();
      final surfacePoints = <Offset>[];
      final startX = center.dx - radius - 10.0;
      final endX = center.dx + radius + 10.0;
      final bottomY = center.dy + radius + 10.0;

      for (double x = startX; x <= endX; x += 2.0) {
        final wave = amp * math.sin((x - center.dx) * waveFreq + phase);
        final y = waterLevelY + wave;
        surfacePoints.add(Offset(x, y));
        if (x == startX) {
          wavePath.moveTo(x, y);
        } else {
          wavePath.lineTo(x, y);
        }
      }
      wavePath.lineTo(endX, bottomY);
      wavePath.lineTo(startX, bottomY);
      wavePath.close();

      // Fluid wave gradient (crest -> color -> deep)
      final gradRect = Rect.fromLTRB(
        orbRect.left,
        waterLevelY - 10,
        orbRect.right,
        center.dy + radius,
      );
      canvas.drawPath(
        wavePath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [crestColor, color, deepColor],
            stops: const [0.0, 0.30, 1.0],
          ).createShader(gradRect)
          ..style = PaintingStyle.fill,
      );

      // Meniscus line (crisp white 60% alpha per mockup)
      if (surfacePoints.length > 1) {
        final surfacePath = Path()
          ..moveTo(surfacePoints.first.dx, surfacePoints.first.dy);
        for (int i = 1; i < surfacePoints.length; i++) {
          surfacePath.lineTo(surfacePoints[i].dx, surfacePoints[i].dy);
        }

        canvas.drawPath(
          surfacePath,
          Paint()
            ..color = Colors.white
                .withAlpha(153) // hexToRgba('#FFFFFF', 0.6)
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

    canvas.restore();
  }

  /// V4: Particles
  void _paintQuantumCollider(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    final isSmall = diameter < 120;
    final rMid = isSmall ? 33.0 : 71.0;
    final center = Offset(size.width / 2, size.height / 2);

    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0);
    final effectiveTime = _effectiveTime;

    // Dual synchrotron magnetic tracks (rMid - 5 and rMid + 5)
    final trackDist = isSmall ? 3.0 : 5.0;
    final trackStroke = isSmall ? 1.2 : 1.8;
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = trackStroke
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, rMid - trackDist, trackPaint);
    canvas.drawCircle(center, rMid + trackDist, trackPaint);

    // Progress plasma arc
    _drawCircularProgressArc(
      canvas: canvas,
      center: center,
      radius: rMid,
      strokeWidth: isSmall ? 4.5 : 6.5,
      safeProgress: safeProgress,
      withGlowAura: true,
      auraStrokeWidth: (isSmall ? 4.5 : 6.5) + (isSmall ? 4.0 : 6.0),
    );

    // 3 High-speed relativistic particles with comet trails
    if (isProcessing) {
      const speeds = [4.2, 5.8, 7.1];
      for (int k = 0; k < 3; k++) {
        final pAng =
            (effectiveTime * speeds[k] + (k * 2 * math.pi) / 3.0) %
            (2 * math.pi);
        for (int tr = 0; tr < 8; tr++) {
          final tAng = pAng - tr * 0.07;
          final tx = center.dx + rMid * math.cos(tAng);
          final ty = center.dy + rMid * math.sin(tAng);
          final alpha = (1.0 - tr / 8.0) * 0.55;
          final dotR = (isSmall ? 2.0 : 3.0) * (1.0 - tr / 8.0);
          final dotColor =
              Color.lerp(crestColor, deepColor, tr / 8.0) ?? crestColor;
          final trailPaint = Paint()
            ..color = dotColor.withAlpha((alpha * 255).round().clamp(0, 255))
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(tx, ty), dotR, trailPaint);
        }
        final px = center.dx + rMid * math.cos(pAng);
        final py = center.dy + rMid * math.sin(pAng);
        final headPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, py), isSmall ? 2.2 : 3.2, headPaint);
      }
    }
  }

  /// V5: Spiral
  void _paintGalaxyVortex(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    final isSmall = diameter < 120;
    final rMid = isSmall ? 33.0 : 71.0;
    final center = Offset(size.width / 2, size.height / 2);

    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0);
    final effectiveTime = _effectiveTime;

    // 3 Archimedean Spiral arms rotating gently towards nebula center with smooth radial gradient
    if (isProcessing) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(effectiveTime * 1.2);
      final minR = isSmall ? 10.0 : 20.0;
      final maxR = isSmall ? 26.0 : 55.0;
      final nebulaRect = Rect.fromCircle(center: Offset.zero, radius: maxR);
      final armPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            deepColor.withAlpha((0.40 * 255).round()),
            color.withAlpha((0.28 * 255).round()),
            crestColor.withAlpha((0.15 * 255).round()),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(nebulaRect)
        ..strokeWidth = isSmall ? 1.4 : 2.0
        ..style = PaintingStyle.stroke;
      for (int s = 0; s < 3; s++) {
        final baseAng = (s * 2 * math.pi) / 3.0;
        final armPath = Path();
        bool started = false;
        for (double rad = minR; rad <= maxR; rad += 2.0) {
          final theta = baseAng + (rad - minR) * 0.08;
          final x = rad * math.cos(theta);
          final y = rad * math.sin(theta);
          if (!started) {
            armPath.moveTo(x, y);
            started = true;
          } else {
            armPath.lineTo(x, y);
          }
        }
        canvas.drawPath(armPath, armPaint);
      }
      canvas.restore();
    }

    // Outer track ring
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = isSmall ? 2.0 : 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, rMid, trackPaint);

    // 16 Stardust particles drifting along the orbit
    if (isProcessing) {
      const count = 16;
      for (int i = 0; i < count; i++) {
        final offset = (i / count) * 2 * math.pi;
        final ang = offset + effectiveTime * 0.9;
        final dist =
            rMid + (isSmall ? 2.0 : 3.5) * math.sin(ang * 4.0 + effectiveTime);
        final px = center.dx + dist * math.cos(ang);
        final py = center.dy + dist * math.sin(ang);
        final alpha =
            (0.20 + 0.35 * math.sin(offset * 2.0 + effectiveTime * 2.0)).clamp(
              0.05,
              1.0,
            );
        final dustPaint = Paint()
          ..color = crestColor.withAlpha((alpha * 255).round().clamp(0, 255))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, py), isSmall ? 1.0 : 1.5, dustPaint);
      }
    }

    // Progress Arc
    _drawCircularProgressArc(
      canvas: canvas,
      center: center,
      radius: rMid,
      strokeWidth: isSmall ? 3.5 : 4.5,
      safeProgress: safeProgress,
      withGlowAura: true,
      auraStrokeWidth: (isSmall ? 3.5 : 4.5) + (isSmall ? 4.0 : 5.0),
    );
  }

  /// V6: Zig-Zag (Border-free, pure snake animation)
  void _paintSerpentineBar(Canvas canvas, Size size) {
    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0);

    // Horizontal padding to prevent head and tail clipping at canvas boundaries
    const pad = 8.0;
    final usableWidth = math.max(0.0, size.width - 2 * pad);
    final rawDist = usableWidth > 0
        ? (usableWidth * safeProgress).clamp(0.0, usableWidth)
        : 0.0;
    final activeDist = (rawDist <= 0 && isProcessing && usableWidth > 0)
        ? math.min(usableWidth * 0.03, 8.0)
        : rawDist;
    final headX = pad + activeDist;
    final tailX = pad;
    final yCenter = size.height / 2.0;

    if (activeDist > 0 && usableWidth > 0) {
      // Undulation wave parameters (Optimized for 280x24 dp & nimble slither)
      const amplitude = 5.0;
      final k = (2 * math.pi * 4.2) / usableWidth;
      // Seamless harmonic motion: integer cycle multiplier (4 full periods per 2.4s)
      // guarantees identical phase at wrap boundary (8*pi = 0 mod 2*pi), eliminating any stutter
      final omegaT = animTime != null
          ? (animTime! * (4.0 / 2.4) * 2 * math.pi)
          : (animationValue * 4.0 * 2 * math.pi);

      double getY(double x) =>
          yCenter + amplitude * math.sin(k * (x - pad) + omegaT);
      double getSlope(double x) =>
          amplitude * k * math.cos(k * (x - pad) + omegaT);

      // Continuous serpentine path from tailX to headX with dense 1.0 step
      final path = Path()..moveTo(tailX, getY(tailX));
      for (double x = tailX + 1.0; x < headX; x += 1.0) {
        path.lineTo(x, getY(x));
      }
      path.lineTo(headX, getY(headX));

      // 1. Spine with smooth linear gradient (strokeWidth 6.0, crisp without whitish aura)
      final spinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6.0;
      final spineRect = Rect.fromLTRB(tailX - 8.0, 0, headX + 8.0, size.height);
      final spineGradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [deepColor, color, crestColor],
        stops: const [0.0, 0.5, 1.0],
      );
      spinePaint.shader = spineGradient.createShader(spineRect);
      canvas.drawPath(path, spinePaint);

      // 2. Tail (Ekor Melonjong) rotated by wave tangent angle: width 11.0, height 6.5
      // Harmonized with start of gradient (deepColor)
      canvas.save();
      canvas.translate(tailX, getY(tailX));
      final tailTheta = math.atan(getSlope(tailX));
      canvas.rotate(tailTheta);
      final tailOval = Rect.fromCenter(
        center: Offset.zero,
        width: 11.0,
        height: 6.5,
      );
      final tailPaint = Paint()
        ..color = deepColor
        ..style = PaintingStyle.fill;
      canvas.drawOval(tailOval, tailPaint);
      canvas.restore();

      // 3. Head (Kepala Melonjong) rotated by wave tangent angle
      // Harmonized with end of gradient (crestColor)
      canvas.save();
      canvas.translate(headX, getY(headX));
      final headTheta = math.atan(getSlope(headX));
      canvas.rotate(headTheta);

      // Solid elongated oval head: width 14.5, height 9.0 (No whitish flare halo)
      final headOval = Rect.fromCenter(
        center: Offset.zero,
        width: 14.5,
        height: 9.0,
      );
      final headPaint = Paint()
        ..color = crestColor
        ..style = PaintingStyle.fill;
      canvas.drawOval(headOval, headPaint);

      // Inner white glint oval: width 4.5, height 2.6 at Offset(1.2, -0.6)
      final glintOval = Rect.fromCenter(
        center: const Offset(1.2, -0.6),
        width: 4.5,
        height: 2.6,
      );
      final glintPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawOval(glintOval, glintPaint);

      canvas.restore();
    }
  }

  /// V7: Capsule
  void _paintCapsuleBar(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cornerRadius = Radius.circular(size.height / 2.0);
    final rrect = RRect.fromRectAndRadius(fullRect, cornerRadius);

    final trackPaint = Paint()
      ..color = trackColor
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

      // Gradient body: 0.0 -> deep, 0.5 -> primary, 1.0 -> crest
      activePaint.shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [deepColor, color, crestColor],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(activeRect);

      canvas.save();
      // Clip to active progress bar
      canvas.clipRRect(activeRRect);
      canvas.drawRRect(activeRRect, activePaint);

      // Shimmer glint sweep
      if (isProcessing) {
        final shimmerPhase = safeAnim.clamp(0.0, 1.0);
        final shimX = shimmerPhase * (activeWidth + 80.0) - 40.0;
        final shimmerRect = Rect.fromLTWH(shimX - 30.0, 0, 60.0, size.height);

        final shimmerPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withAlpha(0),
              Colors.white.withAlpha(115), // rgba(255, 255, 255, 0.45)
              Colors.white.withAlpha(0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(shimmerRect);

        canvas.drawRect(shimmerRect, shimmerPaint);
      }

      canvas.restore();
    }
  }

  /// V8: Equalizer (40 dynamic audio spectrum frequency bars)
  void _paintSoundwaveBar(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(fullRect, const Radius.circular(8.0));

    // Soft rounded capsule background
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, trackPaint);

    final cy = size.height / 2.0;
    const barCount = 40;
    const pad = 6.0;
    final availW = math.max(0.0, size.width - pad * 2.0);
    if (availW <= 0) return;

    final step = availW / barCount;
    final barW = (size.width < 120) ? 1.8 : 3.2;

    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0);
    final effectiveTime = _effectiveTime;
    final activeW = availW * safeProgress;

    // Reference center line: white with 6% opacity
    final linePaint = Paint()
      ..color = Colors.white
          .withAlpha(15) // hexToRgba('#FFFFFF', 0.06)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(pad, cy), Offset(size.width - pad, cy), linePaint);

    for (int i = 0; i < barCount; i++) {
      final x = pad + i * step + step / 2.0;
      final isReached = (i * step) <= activeW;
      double barH;

      if (isReached && safeProgress > 0) {
        if (isProcessing) {
          final w1 = math.sin(i * 0.5 + effectiveTime * 6.5);
          final w2 = math.cos(i * 1.1 - effectiveTime * 4.8);
          final w3 = math.sin(i * 0.25 + effectiveTime * 8.0);
          barH = 6.0 + 13.5 * (0.5 * w1 + 0.3 * w2 + 0.2 * w3).abs();
        } else {
          barH = 12.0;
        }
      } else {
        if (isProcessing) {
          barH = 3.0 + 1.8 * math.sin(i * 0.4 + effectiveTime * 2.0);
        } else {
          barH = 3.0;
        }
      }

      barH = barH.clamp(2.0, size.height - 2.0);
      final y1 = cy - barH / 2.0;
      final y2 = cy + barH / 2.0;

      final barPaint = Paint()
        ..strokeWidth = barW
        ..strokeCap = StrokeCap.round;

      if (isReached && safeProgress > 0) {
        final barRect = Rect.fromLTRB(x - barW / 2.0, y1, x + barW / 2.0, y2);
        barPaint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [crestColor, color, deepColor],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(barRect);
      } else {
        barPaint.color = Colors.white.withAlpha(
          31,
        ); // hexToRgba('#FFFFFF', 0.12)
      }

      canvas.drawLine(Offset(x, y1), Offset(x, y2), barPaint);
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
    final timeChanged = oldDelegate.animTime != animTime;
    return progressChanged ||
        animChanged ||
        timeChanged ||
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
  final Stopwatch _stopwatch = Stopwatch();

  AnimationController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test') &&
        !ProgressStylePreviewBox.enableAnimationInTests;
    if (!isTesting) {
      _stopwatch.start();
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
        _stopwatch.stop();
      }
      if (_controller.value == 0.0) {
        _controller.value = 0.5;
      }
    } else {
      if (!_controller.isAnimating) {
        _stopwatch.start();
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _stopwatch.stop();
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
    final track = isDark
        ? Color.alphaBlend(primary.withAlpha(50), const Color(0xFF1E293B))
        : Color.alphaBlend(primary.withAlpha(40), const Color(0xFFE2E8F0));

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
      case 'v1': // Orbit: enlarged 140x140 dp (180x180 canvas), center percentage 28sp
      case 'v2': // Radar: enlarged 140x140 dp (180x180 canvas), center percentage 28sp
      case 'v3': // Liquid: enlarged 140x140 dp (180x180 canvas), center percentage 28sp
      case 'v4': // Particles: enlarged 140x140 dp (180x180 canvas), center percentage 28sp
      case 'v5': // Spiral: enlarged 140x140 dp (180x180 canvas), center percentage 28sp
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
                      builder: (context, _) {
                        final animTime = _stopwatch.isRunning
                            ? _stopwatch.elapsedMicroseconds / 1000000.0
                            : _controller.value * 2.4;
                        return CustomPaint(
                          size: const Size(180, 180),
                          painter: DualRingProgressPainter(
                            progress: progressVal,
                            animationValue: _controller.value,
                            animTime: animTime,
                            isProcessing: true,
                            isSuccess: false,
                            color: primary,
                            secondaryColor: primary,
                            deepColor: deep,
                            crestColor: crest,
                            basinColor: basin,
                            trackColor: track,
                            style: normalizedStyle,
                            isDark: isDark,
                            strokeWidth: 7.5,
                          ),
                        );
                      },
                    ),
                  ),
                  centerPercentage,
                ],
              ),
            ),
          ),
        );
        break;

      case 'v6': // Zig-Zag: 260x24 dp, percentage 24sp di atas bar
        previewContent = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            topPercentage,
            const SizedBox(height: 12),
            SizedBox(
              width: 260,
              height: 24,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final animTime = _stopwatch.isRunning
                        ? _stopwatch.elapsedMicroseconds / 1000000.0
                        : _controller.value * 2.4;
                    return CustomPaint(
                      size: const Size(260, 24),
                      painter: DualRingProgressPainter(
                        progress: progressVal,
                        animationValue: _controller.value,
                        animTime: animTime,
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
                    );
                  },
                ),
              ),
            ),
          ],
        );
        break;

      case 'v7': // Capsule: enlarged 250x16 dp, percentage 24sp di atas bar
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
                  builder: (context, _) {
                    final animTime = _stopwatch.isRunning
                        ? _stopwatch.elapsedMicroseconds / 1000000.0
                        : _controller.value * 2.4;
                    return CustomPaint(
                      size: const Size(250, 16),
                      painter: DualRingProgressPainter(
                        progress: progressVal,
                        animationValue: _controller.value,
                        animTime: animTime,
                        isProcessing: true,
                        isSuccess: false,
                        color: primary,
                        secondaryColor: primary,
                        deepColor: deep,
                        crestColor: crest,
                        basinColor: basin,
                        trackColor: track,
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

      case 'v8': // Equalizer: enlarged 250x24 dp, percentage 24sp di atas bar
      default:
        previewContent = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            topPercentage,
            const SizedBox(height: 12),
            SizedBox(
              width: 250,
              height: 24,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final animTime = _stopwatch.isRunning
                        ? _stopwatch.elapsedMicroseconds / 1000000.0
                        : _controller.value * 2.4;
                    return CustomPaint(
                      size: const Size(250, 24),
                      painter: DualRingProgressPainter(
                        progress: progressVal,
                        animationValue: _controller.value,
                        animTime: animTime,
                        isProcessing: true,
                        isSuccess: false,
                        color: primary,
                        secondaryColor: primary,
                        deepColor: deep,
                        crestColor: crest,
                        basinColor: basin,
                        trackColor: track,
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
