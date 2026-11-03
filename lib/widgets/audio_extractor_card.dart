// SPDX-License-Identifier: MIT
// Copyright (C) 2026 zerabyte88

import 'package:flutter/material.dart';

import '../models/encoding_options.dart';
import '../models/video_info.dart';
import '../services/localization_service.dart';
import 'app_glass_card.dart';

class AudioExtractorCard extends StatelessWidget {
  final VideoInfo sourceVideo;
  final EncodingOptions encodingOptions;
  final ValueChanged<EncodingOptions> onOptionsChanged;
  final AppLocalizations l10n;

  const AudioExtractorCard({
    super.key,
    required this.sourceVideo,
    required this.encodingOptions,
    required this.onOptionsChanged,
    required this.l10n,
  });

  /// The device only has AAC/PCM encoders, so MP3 is a stream copy and is
  /// only possible when the source audio is already MP3.
  bool get _sourceIsMp3 {
    final codec = sourceVideo.audioCodec?.toLowerCase() ?? '';
    return codec.contains('mpeg') || codec.contains('mp3');
  }

  @override
  Widget build(BuildContext context) {
    if (encodingOptions.audioFormat == AudioFormat.mp3 && !_sourceIsMp3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onOptionsChanged(
          encodingOptions.copyWith(audioFormat: AudioFormat.m4a),
        );
      });
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = theme.colorScheme.onSurface.withAlpha(
      isDark ? 18 : 24,
    );
    final chipBorderColor = theme.colorScheme.onSurface.withAlpha(
      isDark ? 24 : 32,
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
            l10n.t('audio_options'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),

          if (!sourceVideo.hasAudio) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5484D).withAlpha(isDark ? 20 : 16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE5484D).withAlpha(80),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.volume_off_rounded,
                    color: Color(0xFFE5484D),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.t('no_audio_track'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE5484D),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Audio format
          Text(
            l10n.t('audio_format'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: theme.colorScheme.onSurface.withAlpha(200),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: AudioFormat.values.map((fmt) {
                final isEnabled = fmt != AudioFormat.mp3 || _sourceIsMp3;
                final isSelected =
                    isEnabled && encodingOptions.audioFormat == fmt;
                return ChoiceChip(
                  showCheckmark: false,
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: !isEnabled
                      ? theme.colorScheme.surface.withAlpha(isDark ? 50 : 80)
                      : theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: !isEnabled
                        ? theme.colorScheme.onSurface.withAlpha(
                            isDark ? 15 : 20,
                          )
                        : (isSelected
                              ? theme.colorScheme.primary
                              : chipBorderColor),
                    width: 1.0,
                  ),
                  label: Text(
                    fmt.displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      letterSpacing: 0,
                      color: !isEnabled
                          ? theme.colorScheme.onSurface.withAlpha(75)
                          : (isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface),
                    ),
                  ),
                  selected: isSelected,
                  onSelected: isEnabled
                      ? (selected) {
                          if (selected) {
                            final isCopyOnly =
                                fmt == AudioFormat.mp3 ||
                                fmt == AudioFormat.wav;
                            onOptionsChanged(
                              encodingOptions.copyWith(
                                audioFormat: fmt,
                                audioExtractBitrateKbps: isCopyOnly
                                    ? 0
                                    : encodingOptions.audioExtractBitrateKbps,
                              ),
                            );
                          }
                        }
                      : null,
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 16),

          // Audio bitrate
          Builder(
            builder: (context) {
              final isCopyOnly =
                  encodingOptions.audioFormat == AudioFormat.mp3 ||
                  encodingOptions.audioFormat == AudioFormat.wav;
              final isCopySelected =
                  isCopyOnly || encodingOptions.audioExtractBitrateKbps == 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    l10n.t('audio_bitrate'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      color: theme.colorScheme.onSurface.withAlpha(200),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          showCheckmark: false,
                          selectedColor: theme.colorScheme.primary,
                          backgroundColor: theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(
                            color: isCopySelected
                                ? theme.colorScheme.primary
                                : chipBorderColor,
                            width: 1.0,
                          ),
                          label: Text(
                            l10n.t('audio_copy'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isCopySelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              letterSpacing: 0,
                              color: isCopySelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          selected: isCopySelected,
                          onSelected: (selected) {
                            if (selected) {
                              onOptionsChanged(
                                encodingOptions.copyWith(
                                  audioExtractBitrateKbps: 0,
                                ),
                              );
                            }
                          },
                        ),
                        ...[64, 128, 192, 256, 320].map((kbps) {
                          final isSelected =
                              !isCopyOnly &&
                              encodingOptions.audioExtractBitrateKbps == kbps;
                          return Opacity(
                            opacity: isCopyOnly ? 0.38 : 1.0,
                            child: IgnorePointer(
                              ignoring: isCopyOnly,
                              child: ChoiceChip(
                                showCheckmark: false,
                                selectedColor: theme.colorScheme.primary,
                                backgroundColor: theme.colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : chipBorderColor,
                                  width: 1.0,
                                ),
                                label: Text(
                                  '$kbps kbps',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    letterSpacing: 0,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    color: isSelected
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: isCopyOnly
                                    ? null
                                    : (selected) {
                                        if (selected) {
                                          onOptionsChanged(
                                            encodingOptions.copyWith(
                                              audioExtractBitrateKbps: kbps,
                                            ),
                                          );
                                        }
                                      },
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
