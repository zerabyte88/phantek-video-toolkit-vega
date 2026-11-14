import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../models/app_settings.dart';
import '../models/encoding_options.dart';
import '../models/video_info.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_glass_card.dart';
import '../widgets/theme_animated_background.dart';

class TrimPreviewScreen extends StatefulWidget {
  final VideoInfo videoInfo;
  final VideoResolution targetResolution;
  final EncodingOptions encodingOptions;
  final AppSettings appSettings;
  final bool isAudioExtraction;

  const TrimPreviewScreen({
    super.key,
    required this.videoInfo,
    required this.targetResolution,
    required this.encodingOptions,
    required this.appSettings,
    required this.isAudioExtraction,
  });

  @override
  State<TrimPreviewScreen> createState() => _TrimPreviewScreenState();
}

class _TrimPreviewScreenState extends State<TrimPreviewScreen> {
  final _settingsService = SettingsService();
  VideoPlayerController? _controller;
  bool _isControllerInitialized = false;
  bool _isPlaying = false;
  double _currentPositionSeconds = 0.0;

  late double _maxDurationSeconds;
  late double _startSeconds;
  late double _endSeconds;

  @override
  void initState() {
    super.initState();
    _maxDurationSeconds = math.max(1.0, widget.videoInfo.durationSeconds);
    _startSeconds = 0.0;
    _endSeconds = _maxDurationSeconds;

    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      final file = File(widget.videoInfo.filePath);
      if (!await file.exists()) {
        return;
      }
      final controller = VideoPlayerController.file(file);
      _controller = controller;

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.addListener(_onVideoPlayerUpdate);
      setState(() {
        _isControllerInitialized = true;
      });
    } catch (e) {
      debugPrint('TrimPreviewScreen: VideoPlayer init fallback: $e');
    }
  }

  void _onVideoPlayerUpdate() {
    if (!mounted || _controller == null) return;
    final pos = _controller!.value.position.inMilliseconds / 1000.0;
    final isPlaying = _controller!.value.isPlaying;

    if (pos >= _endSeconds && isPlaying) {
      _controller!.pause();
      _controller!.seekTo(
        Duration(milliseconds: (_startSeconds * 1000).round()),
      );
      setState(() {
        _isPlaying = false;
        _currentPositionSeconds = _startSeconds;
      });
      return;
    }

    if ((_currentPositionSeconds - pos).abs() > 0.05 ||
        _isPlaying != isPlaying) {
      setState(() {
        _currentPositionSeconds = pos;
        _isPlaying = isPlaying;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isControllerInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      if (_currentPositionSeconds >= _endSeconds ||
          _currentPositionSeconds < _startSeconds) {
        _controller!.seekTo(
          Duration(milliseconds: (_startSeconds * 1000).round()),
        );
      }
      _controller!.play();
    }
  }

  void _seekTo(double seconds) {
    final clamped = seconds.clamp(0.0, _maxDurationSeconds);
    setState(() {
      _currentPositionSeconds = clamped;
    });
    if (_controller != null && _isControllerInitialized) {
      _controller!.seekTo(Duration(milliseconds: (clamped * 1000).round()));
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoPlayerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  String _formatTime(double seconds) {
    final totalSecs = seconds.floor();
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _proceed() async {
    final opts = widget.encodingOptions.copyWith(
      trimStartMs: (_startSeconds * 1000).round(),
      trimEndMs: (_endSeconds * 1000).round(),
    );

    if (_controller != null) {
      _controller!.removeListener(_onVideoPlayerUpdate);
      try {
        await _controller!.pause();
        await _controller!.dispose();
      } catch (_) {}
      _controller = null;
    }

    if (!mounted) return;
    Navigator.of(context).pop(opts);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = _settingsService.l10n;
    final durationTrimmed = (_endSeconds - _startSeconds).clamp(
      0.0,
      _maxDurationSeconds,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.t('trim_title'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ThemeAnimatedBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Video player card
                    _buildVideoPreviewCard(theme),
                    const SizedBox(height: 16),

                    // Trimming card with Timeline Scrubber & badges
                    _buildTrimmingCard(theme, l10n, durationTrimmed),
                    const SizedBox(height: 20),

                    // Single Consolidated Action button
                    _buildActionButtons(theme, l10n),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPreviewCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return AppGlassCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio:
              _isControllerInitialized &&
                  _controller != null &&
                  _controller!.value.aspectRatio > 0
              ? _controller!.value.aspectRatio
              : (widget.videoInfo.aspectRatio > 0
                    ? widget.videoInfo.aspectRatio
                    : 16 / 9),
          child: Container(
            color: isDark ? Colors.black : const Color(0xFF0F172A),
            child: _isControllerInitialized && _controller != null
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller!),
                      // Play/Pause tap target
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _togglePlayPause,
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: _isPlaying ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(140),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Position indicator bottom bar
                      Positioned(
                        bottom: 8,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(160),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_formatTime(_currentPositionSeconds)} / ${_formatTime(_maxDurationSeconds)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.movie_outlined,
                          size: 48,
                          color: Colors.white.withAlpha(180),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.videoInfo.fileName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.videoInfo.resolution} · ${widget.videoInfo.formattedDuration}',
                          style: TextStyle(
                            color: Colors.white.withAlpha(160),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRuler(ThemeData theme) {
    final textColor = theme.colorScheme.onSurface.withAlpha(120);
    const style = TextStyle(fontSize: 10, fontWeight: FontWeight.w500);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('00:00', style: style.copyWith(color: textColor)),
          Text(
            _formatTime(_maxDurationSeconds * 0.25),
            style: style.copyWith(color: textColor),
          ),
          Text(
            _formatTime(_maxDurationSeconds * 0.50),
            style: style.copyWith(color: textColor),
          ),
          Text(
            _formatTime(_maxDurationSeconds * 0.75),
            style: style.copyWith(color: textColor),
          ),
          Text(
            _formatTime(_maxDurationSeconds),
            style: style.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTrimmingCard(
    ThemeData theme,
    AppLocalizations l10n,
    double durationTrimmed,
  ) {
    return AppGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time Ruler
          _buildTimeRuler(theme),
          const SizedBox(height: 6),

          // Interactive Visual Timeline Scrubber
          _TimelineScrubber(
            currentPosition: _currentPositionSeconds,
            startSeconds: _startSeconds,
            endSeconds: _endSeconds,
            maxDuration: _maxDurationSeconds,
            primaryColor: theme.colorScheme.primary,
            isDark: theme.brightness == Brightness.dark,
            onStartChanged: (val) {
              setState(() {
                _startSeconds = val;
              });
            },
            onEndChanged: (val) {
              setState(() {
                _endSeconds = val;
              });
            },
            onSeek: _seekTo,
          ),
          const SizedBox(height: 14),

          // Badges: Start, End, New Duration
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _buildTimeBadge(
                  key: const Key('trim_start_badge'),
                  theme: theme,
                  label: l10n.t('trim_start'),
                  time: _formatTime(_startSeconds),
                  icon: Icons.skip_previous_rounded,
                  onTap: () {
                    setState(() {
                      _startSeconds = math.min(
                        _currentPositionSeconds,
                        math.max(0.0, _endSeconds - 0.5),
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimeBadge(
                  key: const Key('trim_end_badge'),
                  theme: theme,
                  label: l10n.t('trim_end'),
                  time: _formatTime(_endSeconds),
                  icon: Icons.skip_next_rounded,
                  onTap: () {
                    setState(() {
                      _endSeconds = math.max(
                        _currentPositionSeconds,
                        math.min(_maxDurationSeconds, _startSeconds + 0.5),
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimeBadge(
                  key: const Key('trim_new_duration_badge'),
                  theme: theme,
                  label: l10n.t('trim_new_duration'),
                  time: _formatTime(durationTrimmed),
                  icon: Icons.timer_outlined,
                  isHighlighted: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBadge({
    required ThemeData theme,
    required String label,
    required String time,
    required IconData icon,
    bool isHighlighted = false,
    VoidCallback? onTap,
    Key? key,
  }) {
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isHighlighted
                ? primary.withAlpha(25)
                : theme.colorScheme.surface.withAlpha(120),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHighlighted
                  ? primary.withAlpha(90)
                  : theme.dividerColor.withAlpha(80),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isHighlighted
                        ? primary
                        : theme.colorScheme.onSurface.withAlpha(160),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isHighlighted
                            ? primary
                            : theme.colorScheme.onSurface.withAlpha(160),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isHighlighted ? primary : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, AppLocalizations l10n) {
    return ElevatedButton.icon(
      key: const Key('trim_proceed_button'),
      onPressed: _proceed,
      icon: const Icon(Icons.check_rounded, size: 20),
      label: Text(
        l10n.t('trim_btn_proceed'),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

enum _TimelineDragTarget { none, startHandle, endHandle, playhead }

class _TimelineScrubber extends StatefulWidget {
  final double currentPosition;
  final double startSeconds;
  final double endSeconds;
  final double maxDuration;
  final Color primaryColor;
  final bool isDark;
  final ValueChanged<double> onStartChanged;
  final ValueChanged<double> onEndChanged;
  final ValueChanged<double> onSeek;

  const _TimelineScrubber({
    required this.currentPosition,
    required this.startSeconds,
    required this.endSeconds,
    required this.maxDuration,
    required this.primaryColor,
    required this.isDark,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onSeek,
  });

  @override
  State<_TimelineScrubber> createState() => _TimelineScrubberState();
}

class _TimelineScrubberState extends State<_TimelineScrubber> {
  static const double _horizontalPadding = 14.0;

  _TimelineDragTarget _dragTarget = _TimelineDragTarget.none;

  double _secondsToPx(double seconds, double width) {
    final trackW = width - (_horizontalPadding * 2);
    if (trackW <= 0 || widget.maxDuration <= 0) return _horizontalPadding;
    final ratio = (seconds / widget.maxDuration).clamp(0.0, 1.0);
    return _horizontalPadding + (ratio * trackW);
  }

  double _pxToSeconds(double px, double width) {
    final trackW = width - (_horizontalPadding * 2);
    if (trackW <= 0 || widget.maxDuration <= 0) return 0.0;
    final ratio = ((px - _horizontalPadding) / trackW).clamp(0.0, 1.0);
    return ratio * widget.maxDuration;
  }

  void _handleDragStart(Offset localPosition, double width) {
    if (width <= 0 || widget.maxDuration <= 0) return;
    final dx = localPosition.dx;
    final dy = localPosition.dy;

    final startPx = _secondsToPx(widget.startSeconds, width);
    final endPx = _secondsToPx(widget.endSeconds, width);
    final playheadPx = _secondsToPx(widget.currentPosition, width);

    const topY = 14.0;
    final startCenterPx = startPx - 4.0;
    final endCenterPx = endPx + 4.0;

    final dStart = (dx - startCenterPx).abs();
    final dEnd = (dx - endCenterPx).abs();
    final dPlay = (dx - playheadPx).abs();

    // 1. Direct hit on top needle head pin
    if (dy <= topY + 8 && dPlay <= 24.0) {
      _dragTarget = _TimelineDragTarget.playhead;
    }
    // 2. Initial state where playhead and start handle are both at 0.0:
    // touching left of startPx grabs startHandle; touching at/right of startPx grabs playhead.
    else if ((playheadPx - startPx).abs() <= 4.0 && dStart <= 22.0) {
      if (dx < startPx - 2.0) {
        _dragTarget = _TimelineDragTarget.startHandle;
      } else {
        _dragTarget = _TimelineDragTarget.playhead;
      }
    }
    // 3. Disambiguate between start, end, and playhead based on touch proximity
    else if (dStart <= 24.0 && dStart <= dPlay && dStart <= dEnd) {
      _dragTarget = _TimelineDragTarget.startHandle;
    } else if (dEnd <= 24.0 && dEnd <= dPlay && dEnd < dStart) {
      _dragTarget = _TimelineDragTarget.endHandle;
    } else if (dPlay <= 20.0) {
      _dragTarget = _TimelineDragTarget.playhead;
    } else if (dStart <= 24.0) {
      _dragTarget = _TimelineDragTarget.startHandle;
    } else if (dEnd <= 24.0) {
      _dragTarget = _TimelineDragTarget.endHandle;
    } else {
      _dragTarget = _TimelineDragTarget.playhead;
    }

    _handlePointerMove(localPosition, width);
  }

  void _handlePointerMove(Offset localPosition, double width) {
    if (width <= 0 || widget.maxDuration <= 0) return;
    final t = _pxToSeconds(localPosition.dx, width);

    switch (_dragTarget) {
      case _TimelineDragTarget.startHandle:
        final newStart = t
            .clamp(0.0, math.max(0.0, widget.endSeconds - 0.5))
            .toDouble();
        widget.onStartChanged(newStart);
        // Only push playhead forward if start trim handle moves past current playhead
        if (widget.currentPosition < newStart) {
          widget.onSeek(newStart);
        }
        break;
      case _TimelineDragTarget.endHandle:
        final newEnd = t
            .clamp(
              math.min(widget.maxDuration, widget.startSeconds + 0.5),
              widget.maxDuration,
            )
            .toDouble();
        widget.onEndChanged(newEnd);
        // Only push playhead backward if end trim handle moves past current playhead
        if (widget.currentPosition > newEnd) {
          widget.onSeek(newEnd);
        }
        break;
      case _TimelineDragTarget.playhead:
        // Playhead can scrub freely across the entire trimmed window down to exact start (e.g. 0.0s)
        widget.onSeek(
          t.clamp(widget.startSeconds, widget.endSeconds).toDouble(),
        );
        break;
      case _TimelineDragTarget.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            if (width <= 0 || widget.maxDuration <= 0) return;
            final dx = details.localPosition.dx;
            final startPx = _secondsToPx(widget.startSeconds, width);
            final endPx = _secondsToPx(widget.endSeconds, width);
            // Ignore taps on the start or end handle ears so touching a trim
            // handle never teleports the preview line onto that handle.
            if ((dx - (startPx - 4.0)).abs() <= 18.0 ||
                (dx - (endPx + 4.0)).abs() <= 18.0) {
              return;
            }
            final t = _pxToSeconds(dx, width)
                .clamp(widget.startSeconds, widget.endSeconds)
                .toDouble();
            widget.onSeek(t);
          },
          onHorizontalDragStart: (details) =>
              _handleDragStart(details.localPosition, width),
          onHorizontalDragUpdate: (details) =>
              _handlePointerMove(details.localPosition, width),
          onHorizontalDragEnd: (_) {
            _dragTarget = _TimelineDragTarget.none;
          },
          onHorizontalDragCancel: () {
            _dragTarget = _TimelineDragTarget.none;
          },
          child: CustomPaint(
            size: Size(width, 68),
            painter: _TimelineTrackPainter(
              currentPosition: widget.currentPosition,
              startSeconds: widget.startSeconds,
              endSeconds: widget.endSeconds,
              maxDuration: widget.maxDuration,
              primaryColor: widget.primaryColor,
              isDark: widget.isDark,
            ),
          ),
        );
      },
    );
  }
}

class _TimelineTrackPainter extends CustomPainter {
  static const double _horizontalPadding = 14.0;
  static const double _handleW = 12.0;

  final double currentPosition;
  final double startSeconds;
  final double endSeconds;
  final double maxDuration;
  final Color primaryColor;
  final bool isDark;

  const _TimelineTrackPainter({
    required this.currentPosition,
    required this.startSeconds,
    required this.endSeconds,
    required this.maxDuration,
    required this.primaryColor,
    required this.isDark,
  });

  double _secondsToPx(double seconds, double width) {
    final trackW = width - (_horizontalPadding * 2);
    if (trackW <= 0 || maxDuration <= 0) return _horizontalPadding;
    final ratio = (seconds / maxDuration).clamp(0.0, 1.0);
    return _horizontalPadding + (ratio * trackW);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    if (w <= 0 || maxDuration <= 0) return;

    const topY = 14.0;
    final bottomY = size.height - 2.0;

    final trackLeft = _horizontalPadding;
    final trackRight = w - _horizontalPadding;

    // Track frame RRect
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(trackLeft, topY, trackRight, bottomY),
      const Radius.circular(8),
    );

    // 1. Draw base filmstrip track
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF131722) : const Color(0xFFE2E8F0);
    canvas.drawRRect(trackRect, bgPaint);

    // Filmstrip subtle notch rails
    final railPaint = Paint()
      ..color = isDark
          ? Colors.white.withAlpha(20)
          : Colors.black.withAlpha(20);
    const railStep = 24.0;
    for (double x = trackLeft + 6.0; x < trackRight - 6.0; x += railStep) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, topY + 3, 8, 3),
          const Radius.circular(1.5),
        ),
        railPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, bottomY - 6, 8, 3),
          const Radius.circular(1.5),
        ),
        railPaint,
      );
    }

    // Positions in pixels
    final startPx = _secondsToPx(startSeconds, w);
    final endPx = _secondsToPx(endSeconds, w);
    final playheadPx = _secondsToPx(currentPosition, w);

    // Clip to track boundary for cut overlays
    canvas.save();
    canvas.clipRRect(trackRect);

    // 2. Cut Out Zones (Dimmed/Dark)
    final cutPaint = Paint()
      ..color = Colors.black.withAlpha(isDark ? 180 : 120);

    // Left cut zone (trackLeft to startPx)
    if (startPx > trackLeft) {
      canvas.drawRect(
        Rect.fromLTRB(trackLeft, topY, startPx, bottomY),
        cutPaint,
      );
    }

    // Right cut zone (endPx to trackRight)
    if (endPx < trackRight) {
      canvas.drawRect(
        Rect.fromLTRB(endPx, topY, trackRight, bottomY),
        cutPaint,
      );
    }

    // 3. Kept active window tint
    final activeRect = Rect.fromLTRB(startPx, topY, endPx, bottomY);
    final activeFill = Paint()..color = primaryColor.withAlpha(22);
    canvas.drawRect(activeRect, activeFill);

    canvas.restore();

    // 4. Active selection window bounding frame
    final activeFrame = RRect.fromRectAndRadius(
      activeRect,
      const Radius.circular(8),
    );
    final framePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(activeFrame, framePaint);

    // 5. Left Handle
    final leftHandleRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(startPx - _handleW, topY - 1, startPx, bottomY + 1),
      topLeft: const Radius.circular(8),
      bottomLeft: const Radius.circular(8),
    );
    final handlePaint = Paint()..color = primaryColor;
    canvas.drawRRect(leftHandleRect, handlePaint);

    // Left handle notches
    final notchPaint = Paint()
      ..color = isDark ? Colors.black.withAlpha(220) : Colors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final midY = (topY + bottomY) / 2;
    canvas.drawLine(
      Offset(startPx - (_handleW / 2), midY - 7),
      Offset(startPx - (_handleW / 2), midY + 7),
      notchPaint,
    );

    // Right Handle
    final rightHandleRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(endPx, topY - 1, endPx + _handleW, bottomY + 1),
      topRight: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );
    canvas.drawRRect(rightHandleRect, handlePaint);

    // Right handle notches
    canvas.drawLine(
      Offset(endPx + (_handleW / 2), midY - 7),
      Offset(endPx + (_handleW / 2), midY + 7),
      notchPaint,
    );

    // 6. Needle Playhead Line & Pins
    final needleShadowPaint = Paint()
      ..color = Colors.black.withAlpha(160)
      ..strokeWidth = 3.5;
    canvas.drawLine(
      Offset(playheadPx, topY - 2),
      Offset(playheadPx, bottomY + 2),
      needleShadowPaint,
    );

    final needleLinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;

    // Vertical line through track
    canvas.drawLine(
      Offset(playheadPx, topY - 2),
      Offset(playheadPx, bottomY + 2),
      needleLinePaint,
    );

    // Top needle head (teardrop/pin)
    final needlePath = Path()
      ..moveTo(playheadPx - 6, 0)
      ..lineTo(playheadPx + 6, 0)
      ..lineTo(playheadPx + 6, 7)
      ..lineTo(playheadPx, topY)
      ..lineTo(playheadPx - 6, 7)
      ..close();

    final needleHeadPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(needlePath, needleHeadPaint);

    // Needle shadow / outline
    final needleBorder = Paint()
      ..color = Colors.black.withAlpha(160)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(needlePath, needleBorder);

    // Center eye dot
    canvas.drawCircle(
      Offset(playheadPx, 4),
      1.5,
      Paint()..color = Colors.black.withAlpha(220),
    );

    // Bottom foot pin
    final bottomPinPath = Path()
      ..moveTo(playheadPx, bottomY)
      ..lineTo(playheadPx + 5, bottomY + 5)
      ..lineTo(playheadPx - 5, bottomY + 5)
      ..close();
    canvas.drawPath(bottomPinPath, needleHeadPaint);
    canvas.drawPath(bottomPinPath, needleBorder);
  }

  @override
  bool shouldRepaint(covariant _TimelineTrackPainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
        oldDelegate.startSeconds != startSeconds ||
        oldDelegate.endSeconds != endSeconds ||
        oldDelegate.maxDuration != maxDuration ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.isDark != isDark;
  }
}
