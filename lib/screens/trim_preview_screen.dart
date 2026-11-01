// SPDX-License-Identifier: MIT
// Copyright (C) 2026 zerabyte88

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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

    if ((_currentPositionSeconds - pos).abs() > 0.1 ||
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

  Future<void> _proceed({required bool isTrimmed}) async {
    final opts = isTrimmed
        ? widget.encodingOptions.copyWith(
            trimStartMs: (_startSeconds * 1000).round(),
            trimEndMs: (_endSeconds * 1000).round(),
          )
        : widget.encodingOptions.copyWith(trimStartMs: null, trimEndMs: null);

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

                    // Trimming card with RangeSlider & badges
                    _buildTrimmingCard(theme, l10n, durationTrimmed),
                    const SizedBox(height: 20),

                    // Action buttons
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

  Widget _buildTrimmingCard(
    ThemeData theme,
    AppLocalizations l10n,
    double durationTrimmed,
  ) {
    return AppGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // RangeSlider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.primary.withAlpha(40),
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withAlpha(30),
              trackHeight: 4,
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 8,
              ),
            ),
            child: RangeSlider(
              values: RangeValues(_startSeconds, _endSeconds),
              min: 0.0,
              max: _maxDurationSeconds,
              onChanged: (RangeValues values) {
                setState(() {
                  _startSeconds = values.start;
                  _endSeconds = values.end;
                });
                if (_controller != null && _isControllerInitialized) {
                  _controller!.seekTo(
                    Duration(milliseconds: (_startSeconds * 1000).round()),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // Badges: Start, End, New Duration
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _buildTimeBadge(
                  theme: theme,
                  label: l10n.t('trim_start'),
                  time: _formatTime(_startSeconds),
                  icon: Icons.skip_previous_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimeBadge(
                  theme: theme,
                  label: l10n.t('trim_end'),
                  time: _formatTime(_endSeconds),
                  icon: Icons.skip_next_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimeBadge(
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
  }) {
    final primary = theme.colorScheme.primary;

    return Container(
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
    );
  }

  Widget _buildActionButtons(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary button: Proceed with trimming
        ElevatedButton.icon(
          onPressed: () => _proceed(isTrimmed: true),
          icon: const Icon(Icons.check_rounded, size: 20),
          label: Text(
            l10n.t('trim_btn_proceed'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary button: Skip trimming
        OutlinedButton.icon(
          onPressed: () => _proceed(isTrimmed: false),
          icon: const Icon(Icons.all_inclusive_rounded, size: 18),
          label: Text(
            l10n.t('trim_btn_skip'),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
