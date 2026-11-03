// SPDX-License-Identifier: MIT
// Copyright (C) 2026 zerabyte88

import 'package:flutter/material.dart';

import '../models/encoding_options.dart';
import '../models/video_info.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';
import 'app_glass_card.dart';

class ConversionOptionsCard extends StatefulWidget {
  final VideoInfo sourceVideo;
  final List<VideoResolution> resolutions;
  final VideoResolution? selectedResolution;
  final EncodingOptions encodingOptions;
  final ValueChanged<VideoResolution> onResolutionChanged;
  final ValueChanged<EncodingOptions> onOptionsChanged;
  final AppLocalizations l10n;

  const ConversionOptionsCard({
    super.key,
    required this.sourceVideo,
    required this.resolutions,
    required this.selectedResolution,
    required this.encodingOptions,
    required this.onResolutionChanged,
    required this.onOptionsChanged,
    required this.l10n,
  });

  @override
  State<ConversionOptionsCard> createState() => _ConversionOptionsCardState();
}

class _ConversionOptionsCardState extends State<ConversionOptionsCard>
    with AutomaticKeepAliveClientMixin {
  int _crfValue = 22;
  int _customBitrateMbps = 4;
  bool _isCustomFps = false;
  late int _customFps;
  bool _isAdvancedExpanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    SettingsService().addListener(_onSettingsUpdated);
    _crfValue = widget.encodingOptions.crfValue;
    _customBitrateMbps = (widget.encodingOptions.customBitrateKbps / 1000)
        .round()
        .clamp(1, 35);
    final sourceFps = (widget.sourceVideo.fps > 0
        ? widget.sourceVideo.fps.round()
        : 60);
    final maxFps = sourceFps.clamp(15, 120);
    final currentFps = widget.encodingOptions.targetFps;
    const standardFps = [0, 60, 50, 48, 30, 25, 24];
    if (currentFps > 0 && !standardFps.contains(currentFps)) {
      _isCustomFps = true;
      _customFps = currentFps.clamp(10, maxFps);
    } else {
      _isCustomFps = false;
      _customFps = (currentFps > 0 ? currentFps : maxFps).clamp(10, maxFps);
    }
  }

  void _onSettingsUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    SettingsService().removeListener(_onSettingsUpdated);
    super.dispose();
  }

  @override
  void didUpdateWidget(ConversionOptionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.encodingOptions.speedPreset !=
        widget.encodingOptions.speedPreset) {
      _crfValue = widget.encodingOptions.crfValue;
    }
    if (oldWidget.encodingOptions.crfValue != widget.encodingOptions.crfValue) {
      _crfValue = widget.encodingOptions.crfValue;
    }
    if (oldWidget.encodingOptions.customBitrateKbps !=
        widget.encodingOptions.customBitrateKbps) {
      _customBitrateMbps = (widget.encodingOptions.customBitrateKbps / 1000)
          .round()
          .clamp(1, 35);
    }
    if (oldWidget.encodingOptions.targetFps !=
        widget.encodingOptions.targetFps) {
      final currentFps = widget.encodingOptions.targetFps;
      const standardFps = [0, 60, 50, 48, 30, 25, 24];
      if (currentFps > 0 && !standardFps.contains(currentFps)) {
        _isCustomFps = true;
        _customFps = currentFps;
      }
    }
    if (oldWidget.sourceVideo != widget.sourceVideo) {
      final sourceFps = (widget.sourceVideo.fps > 0
          ? widget.sourceVideo.fps.round()
          : 60);
      final maxFps = sourceFps.clamp(15, 120);
      if (_customFps > maxFps) {
        _customFps = maxFps;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = widget.l10n;
    final is4K = widget.sourceVideo.is4K;
    final isLongDuration = widget.sourceVideo.isLongDuration;
    final dividerColor = theme.colorScheme.onSurface.withAlpha(
      isDark ? 18 : 24,
    );

    return AppGlassCard(
      padding: const EdgeInsets.all(16),
      border: Border.all(
        color: theme.colorScheme.onSurface.withAlpha(isDark ? 20 : 28),
        width: 1.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            l10n.t('video_options'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
              letterSpacing: 0,
            ),
          ),
          if (is4K || isLongDuration) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('heavy_process_warning_banner'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withAlpha(isDark ? 20 : 16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withAlpha(80),
                  width: 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF59E0B),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      is4K && isLongDuration
                          ? l10n.t('heavy_process_banner_4k_long')
                          : is4K
                          ? l10n.t('heavy_process_banner_4k')
                          : l10n.t(
                              'heavy_process_banner_long',
                              args: {
                                'duration':
                                    widget.sourceVideo.formattedDuration,
                              },
                            ),
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        letterSpacing: 0,
                        color: theme.colorScheme.onSurface.withAlpha(220),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // 1. Target Resolution
          _buildSectionLabel(title: l10n.t('target_resolution'), theme: theme),
          const SizedBox(height: 10),
          ...widget.resolutions.map((res) {
            final isSelected = widget.selectedResolution?.label == res.label;
            return _buildResolutionTile(
              res: res,
              isSelected: isSelected,
              theme: theme,
            );
          }),

          const SizedBox(height: 12),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 16),

          // 2. Encoding Speed Preset (Default options)
          _buildEncodingSpeedSelector(theme, l10n),

          const SizedBox(height: 16),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 16),

          // 3. Container format
          _buildContainerFormatSelector(theme, l10n),

          const SizedBox(height: 16),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 16),

          // 4. Advanced Options (Collapsible accordion)
          _buildAdvancedOptionsSection(theme, l10n),
        ],
      ),
    );
  }

  Widget _buildEncodingSpeedSelector(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSectionLabel(
          title: l10n.t('settings_encoding_preset'),
          theme: theme,
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: _isAdvancedExpanded ? 0.38 : 1.0,
          child: IgnorePointer(
            ignoring: _isAdvancedExpanded,
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChoiceChip(
                    chipKey: const Key('preset_chip_fast'),
                    label: l10n.t('preset_fast_title'),
                    isSelected:
                        widget.encodingOptions.speedPreset == SpeedPreset.fast,
                    onSelected: (selected) {
                      if (selected) {
                        widget.onOptionsChanged(
                          widget.encodingOptions.copyWith(
                            speedPreset: SpeedPreset.fast,
                            crfValue: SpeedPreset.fast.defaultCrf,
                          ),
                        );
                      }
                    },
                  ),
                  _buildChoiceChip(
                    chipKey: const Key('preset_chip_normal'),
                    label: l10n.t('preset_normal_title'),
                    isSelected:
                        widget.encodingOptions.speedPreset ==
                        SpeedPreset.normal,
                    onSelected: (selected) {
                      if (selected) {
                        widget.onOptionsChanged(
                          widget.encodingOptions.copyWith(
                            speedPreset: SpeedPreset.normal,
                            crfValue: SpeedPreset.normal.defaultCrf,
                          ),
                        );
                      }
                    },
                  ),
                  _buildChoiceChip(
                    chipKey: const Key('preset_chip_slow'),
                    label: l10n.t('preset_slow_title'),
                    isSelected:
                        widget.encodingOptions.speedPreset == SpeedPreset.max,
                    onSelected: (selected) {
                      if (selected) {
                        widget.onOptionsChanged(
                          widget.encodingOptions.copyWith(
                            speedPreset: SpeedPreset.max,
                            crfValue: SpeedPreset.max.defaultCrf,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isAdvancedExpanded) ...[
          const SizedBox(height: 8),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                l10n.t('preset_disabled_by_advanced'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: theme.colorScheme.onSurface.withAlpha(140),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContainerFormatSelector(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSectionLabel(title: l10n.t('container_format'), theme: theme),
        const SizedBox(height: 10),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: VideoContainer.values.map((format) {
              final isSelected = widget.encodingOptions.container == format;
              return _buildChoiceChip(
                chipKey: Key('container_chip_${format.name}'),
                label: '${format.displayName} (.${format.extension})',
                isSelected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    widget.onOptionsChanged(
                      widget.encodingOptions.copyWith(container: format),
                    );
                  }
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedOptionsSection(ThemeData theme, AppLocalizations l10n) {
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = theme.colorScheme.onSurface.withAlpha(
      isDark ? 18 : 24,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('advanced_options_toggle'),
          onTap: () async {
            if (!_isAdvancedExpanded) {
              final suppress =
                  SettingsService().settings.suppressAdvancedModeWarning;
              if (!suppress) {
                final confirmed = await _showAdvancedModeWarningDialog(
                  context,
                  theme,
                  l10n,
                );
                if (confirmed != true) return;
              }
            }
            if (mounted) {
              setState(() {
                _isAdvancedExpanded = !_isAdvancedExpanded;
              });
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withAlpha(
                _isAdvancedExpanded ? 14 : 8,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isAdvancedExpanded
                    ? theme.colorScheme.primary.withAlpha(80)
                    : theme.colorScheme.onSurface.withAlpha(isDark ? 20 : 28),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    l10n.t('settings_advanced_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isAdvancedExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  curve: const Cubic(0.22, 1, 0.36, 1),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withAlpha(170),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isAdvancedExpanded) ...[
          const SizedBox(height: 16),
          _buildCodecSelector(theme, l10n),
          const SizedBox(height: 16),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 16),
          _buildAudioQualitySelector(theme, l10n),
          const SizedBox(height: 16),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 16),
          _buildRateControlSelector(theme, l10n),
          const SizedBox(height: 16),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 16),
          _buildFpsSelector(theme, l10n),
        ],
      ],
    );
  }

  Future<bool?> _showAdvancedModeWarningDialog(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    bool doNotShowAgain = false;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          key: const Key('advanced_warning_dialog'),
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5484D).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE5484D),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.t('advanced_warning_title'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('advanced_warning_desc'),
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  letterSpacing: 0,
                  color: theme.colorScheme.onSurface.withAlpha(190),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  setDialogState(() {
                    doNotShowAgain = !doNotShowAgain;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          key: const Key('advanced_warning_checkbox'),
                          value: doNotShowAgain,
                          onChanged: (val) {
                            setDialogState(() {
                              doNotShowAgain = val ?? false;
                            });
                          },
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.t('dont_show_again'),
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 0,
                            color: theme.colorScheme.onSurface.withAlpha(180),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              key: const Key('advanced_warning_no_button'),
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black87,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: Text(
                l10n.t('proc_dialog_no'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            FilledButton(
              key: const Key('advanced_warning_yes_button'),
              onPressed: () async {
                if (doNotShowAgain) {
                  await SettingsService().setSuppressAdvancedModeWarning(true);
                }
                if (ctx.mounted) {
                  Navigator.of(ctx).pop(true);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE5484D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(
                l10n.t('proc_dialog_yes'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodecSelector(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSectionLabel(
          title: l10n.t('settings_default_codec'),
          theme: theme,
        ),
        const SizedBox(height: 10),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceChip(
                chipKey: const Key('codec_chip_h264'),
                label: 'H.264 / AVC',
                isSelected: widget.encodingOptions.codec == VideoCodec.h264,
                onSelected: (selected) {
                  if (selected) {
                    widget.onOptionsChanged(
                      widget.encodingOptions.copyWith(codec: VideoCodec.h264),
                    );
                  }
                },
              ),
              _buildChoiceChip(
                chipKey: const Key('codec_chip_hevc'),
                label: 'H.265 / HEVC',
                isSelected: widget.encodingOptions.codec == VideoCodec.hevc,
                onSelected: (selected) {
                  if (selected) {
                    widget.onOptionsChanged(
                      widget.encodingOptions.copyWith(codec: VideoCodec.hevc),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.encodingOptions.codec == VideoCodec.hevc
                  ? l10n.t('desc_hevc')
                  : l10n.t('desc_h264'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                letterSpacing: 0,
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioQualitySelector(ThemeData theme, AppLocalizations l10n) {
    final currentAudio = widget.encodingOptions.videoAudioBitrateKbps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSectionLabel(
          title: l10n.t('settings_audio_quality'),
          theme: theme,
        ),
        const SizedBox(height: 10),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceChip(
                label: l10n.t('settings_audio_mute'),
                isSelected: currentAudio == 0,
                onSelected: (selected) {
                  if (selected) {
                    widget.onOptionsChanged(
                      widget.encodingOptions.copyWith(videoAudioBitrateKbps: 0),
                    );
                  }
                },
              ),
              ...[128, 192, 256, 320].map(
                (kbps) => _buildChoiceChip(
                  label: '$kbps kbps',
                  isSelected: currentAudio == kbps,
                  onSelected: (selected) {
                    if (selected) {
                      widget.onOptionsChanged(
                        widget.encodingOptions.copyWith(
                          videoAudioBitrateKbps: kbps,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRateControlSelector(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSectionLabel(title: l10n.t('rate_control'), theme: theme),
        const SizedBox(height: 10),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: RateControlMode.values.map((mode) {
              final isSelected = widget.encodingOptions.rateControlMode == mode;
              return _buildChoiceChip(
                label: mode.displayName,
                isSelected: isSelected,
                isEnabled: true,
                onSelected: (selected) {
                  if (selected) {
                    widget.onOptionsChanged(
                      widget.encodingOptions.copyWith(rateControlMode: mode),
                    );
                  }
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.encodingOptions.rateControlMode == RateControlMode.crf
                  ? l10n.t('desc_crf')
                  : l10n.t('desc_bitrate'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                letterSpacing: 0,
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.encodingOptions.rateControlMode == RateControlMode.crf)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _crfValue.toDouble(),
                      min: 16,
                      max: 28,
                      divisions: 12,
                      label: '$_crfValue',
                      onChanged: (val) {
                        final newCrf = val.round();
                        if (newCrf != _crfValue) {
                          setState(() {
                            _crfValue = newCrf;
                          });
                          widget.onOptionsChanged(
                            widget.encodingOptions.copyWith(crfValue: newCrf),
                          );
                        }
                      },
                      onChangeEnd: (val) {
                        final newCrf = val.round();
                        widget.onOptionsChanged(
                          widget.encodingOptions.copyWith(crfValue: newCrf),
                        );
                      },
                    ),
                  ),
                  Container(
                    width: 44,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_crfValue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        letterSpacing: 0,
                        color: theme.colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              // Slider guide
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.t('crf_hint_sharp'),
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0,
                          color: theme.colorScheme.onSurface.withAlpha(140),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.t('crf_hint_small'),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0,
                          color: theme.colorScheme.onSurface.withAlpha(140),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Reset button
              if (_crfValue !=
                  widget.encodingOptions.speedPreset.defaultCrf) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      key: const Key('crf_custom_badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withAlpha(16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l10n.t('crf_custom'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          color: theme.colorScheme.onSurface.withAlpha(180),
                        ),
                      ),
                    ),
                    InkWell(
                      key: const Key('crf_reset_button'),
                      onTap: () {
                        final defaultCrf =
                            widget.encodingOptions.speedPreset.defaultCrf;
                        setState(() {
                          _crfValue = defaultCrf;
                        });
                        widget.onOptionsChanged(
                          widget.encodingOptions.copyWith(crfValue: defaultCrf),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.t('crf_reset'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        if (widget.encodingOptions.rateControlMode ==
            RateControlMode.bitrate) ...[
          Text(
            l10n.t('bitrate_label'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0,
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _customBitrateMbps.toDouble().clamp(1.0, 35.0),
                  min: 1,
                  max: 35,
                  divisions: 34,
                  label: '$_customBitrateMbps Mbps',
                  onChanged: (val) {
                    final newBitrate = val.round();
                    if (newBitrate != _customBitrateMbps) {
                      setState(() {
                        _customBitrateMbps = newBitrate;
                      });
                      widget.onOptionsChanged(
                        widget.encodingOptions.copyWith(
                          customBitrateKbps: newBitrate * 1000,
                        ),
                      );
                    }
                  },
                  onChangeEnd: (val) {
                    final newBitrate = val.round();
                    widget.onOptionsChanged(
                      widget.encodingOptions.copyWith(
                        customBitrateKbps: newBitrate * 1000,
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_customBitrateMbps Mbps',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    letterSpacing: 0,
                    color: theme.colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSectionLabel({required String title, required ThemeData theme}) {
    return Center(
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: theme.colorScheme.onSurface.withAlpha(200),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    Key? chipKey,
    required String label,
    required bool isSelected,
    required ValueChanged<bool>? onSelected,
    double fontSize = 12.5,
    bool isEnabled = true,
    String? tooltip,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chip = ChoiceChip(
      key: chipKey,
      showCheckmark: false,
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          letterSpacing: 0,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: !isEnabled
              ? theme.colorScheme.onSurface.withAlpha(80)
              : (isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface),
        ),
      ),
      selected: isSelected,
      onSelected: isEnabled ? onSelected : null,
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      side: BorderSide(
        color: !isEnabled
            ? theme.colorScheme.onSurface.withAlpha(20)
            : (isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withAlpha(isDark ? 24 : 32)),
        width: 1.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      visualDensity: VisualDensity.compact,
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: chip);
    }
    return chip;
  }

  Widget _buildResolutionTile({
    required VideoResolution res,
    required bool isSelected,
    required ThemeData theme,
  }) {
    final l10n = widget.l10n;
    final isDark = theme.brightness == Brightness.dark;
    final isPortrait = widget.sourceVideo.height > widget.sourceVideo.width;
    final displayW = isPortrait && !res.label.startsWith('Original')
        ? res.height
        : res.width;
    final displayH = isPortrait && !res.label.startsWith('Original')
        ? res.width
        : res.height;

    final displayLabel = res.label.startsWith('Original')
        ? '${l10n.t('res_original')} (${res.label.substring(res.label.indexOf('(') + 1)}'
        : res.label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => widget.onResolutionChanged(res),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withAlpha(isDark ? 22 : 16)
                : theme.colorScheme.onSurface.withAlpha(isDark ? 8 : 6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withAlpha(180)
                  : theme.colorScheme.onSurface.withAlpha(isDark ? 20 : 28),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha(130),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayLabel,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: 0,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '$displayW×$displayH',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withAlpha(140),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFpsSelector(ThemeData theme, AppLocalizations l10n) {
    final isDark = theme.brightness == Brightness.dark;
    final sourceFps = (widget.sourceVideo.fps > 0
        ? widget.sourceVideo.fps.round()
        : 60);
    final maxFps = sourceFps.clamp(15, 120);
    final minFps = (10 < maxFps) ? 10 : 1;
    final targetFps = widget.encodingOptions.targetFps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSectionLabel(title: l10n.t('target_fps'), theme: theme),
        const SizedBox(height: 10),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceChip(
                label: l10n.t('fps_original'),
                isSelected: targetFps == 0 && !_isCustomFps,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _isCustomFps = false;
                    });
                    widget.onOptionsChanged(
                      widget.encodingOptions.copyWith(targetFps: 0),
                    );
                  }
                },
              ),
              _buildChoiceChip(
                label: l10n.t('fps_custom'),
                isSelected: _isCustomFps,
                onSelected: (selected) {
                  if (selected) {
                    final initialCustom = (targetFps > 0 ? targetFps : maxFps)
                        .clamp(minFps, maxFps);
                    setState(() {
                      _isCustomFps = true;
                      _customFps = initialCustom;
                    });
                    widget.onOptionsChanged(
                      widget.encodingOptions.copyWith(targetFps: initialCustom),
                    );
                  }
                },
              ),
            ],
          ),
        ),

        // Custom FPS slider
        if (_isCustomFps) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withAlpha(isDark ? 10 : 6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.onSurface.withAlpha(isDark ? 20 : 28),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l10n.t('fps_custom')}: $_customFps FPS',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${l10n.t('fps_max')}: $maxFps FPS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: theme.colorScheme.onSurface.withAlpha(140),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: _customFps.toDouble().clamp(
                      minFps.toDouble(),
                      maxFps.toDouble(),
                    ),
                    min: minFps.toDouble(),
                    max: maxFps.toDouble(),
                    divisions: (maxFps - minFps) > 0 ? (maxFps - minFps) : 1,
                    label: '$_customFps FPS',
                    onChanged: (val) {
                      final newFps = val.round();
                      if (newFps != _customFps) {
                        setState(() {
                          _customFps = newFps;
                        });
                        widget.onOptionsChanged(
                          widget.encodingOptions.copyWith(targetFps: newFps),
                        );
                      }
                    },
                    onChangeEnd: (val) {
                      final newFps = val.round();
                      widget.onOptionsChanged(
                        widget.encodingOptions.copyWith(targetFps: newFps),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
