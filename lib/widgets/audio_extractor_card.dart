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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.audiotrack_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.t('audio_options'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (!sourceVideo.hasAudio) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.volume_off_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.t('no_audio_track'),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Audio format
          Row(
            children: [
              Icon(
                Icons.album_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.t('audio_format'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: AudioFormat.values.map((fmt) {
                final isSelected = encodingOptions.audioFormat == fmt;
                return ChoiceChip(
                  showCheckmark: false,
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surface,
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: isSelected ? 1.2 : 1.0,
                  ),
                  label: Text(
                    fmt.displayName,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      final isCopyOnly =
                          fmt == AudioFormat.mp3 || fmt == AudioFormat.wav;
                      onOptionsChanged(
                        encodingOptions.copyWith(
                          audioFormat: fmt,
                          audioExtractBitrateKbps: isCopyOnly
                              ? 0
                              : encodingOptions.audioExtractBitrateKbps,
                        ),
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: theme.dividerColor),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.speed_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.t('audio_bitrate'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
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
                          side: BorderSide(
                            color: isCopySelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                            width: isCopySelected ? 1.2 : 1.0,
                          ),
                          label: Text(
                            l10n.t('audio_copy'),
                            style: TextStyle(
                              fontWeight: isCopySelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isCopySelected
                                  ? Colors.white
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
                                side: BorderSide(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                  width: isSelected ? 1.2 : 1.0,
                                ),
                                label: Text(
                                  '$kbps kbps',
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
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
