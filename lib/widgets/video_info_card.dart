// SPDX-License-Identifier: MIT
// Copyright (C) 2026 zerabyte88

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';
import 'app_glass_card.dart';

class VideoInfoCard extends StatelessWidget {
  final VideoInfo videoInfo;
  final Uint8List? thumbnailBytes;
  final VoidCallback? onRename;

  const VideoInfoCard({
    super.key,
    required this.videoInfo,
    this.thumbnailBytes,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = SettingsService().l10n;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withAlpha(
                    isDark ? 14 : 10,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withAlpha(
                      isDark ? 20 : 24,
                    ),
                    width: 1.0,
                  ),
                ),
                child: thumbnailBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.memory(
                          thumbnailBytes!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.movie_outlined,
                        color: theme.colorScheme.onSurface.withAlpha(190),
                        size: 22,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            videoInfo.fileName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: 0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onRename != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: theme.colorScheme.onSurface.withAlpha(170),
                            ),
                            onPressed: onRename,
                            tooltip: l10n.t('rename_tooltip'),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            padding: const EdgeInsets.all(8),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${videoInfo.resolution}  •  ${videoInfo.codec.toUpperCase()}  •  ${videoInfo.formattedFileSize}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withAlpha(150),
                        letterSpacing: 0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 16),

          // Metadata grid
          _buildSpecsGrid(l10n, theme, dividerColor),
        ],
      ),
    );
  }

  Widget _buildSpecsGrid(
    AppLocalizations l10n,
    ThemeData theme,
    Color dividerColor,
  ) {
    final items = [
      _SpecItem(
        label: l10n.t('resolution'),
        value: '${videoInfo.width} × ${videoInfo.height}',
      ),
      _SpecItem(label: l10n.t('duration'), value: videoInfo.formattedDuration),
      _SpecItem(
        label: l10n.t('fps'),
        value: '${videoInfo.fps.toStringAsFixed(1)} fps',
      ),
      _SpecItem(label: l10n.t('bitrate'), value: videoInfo.formattedBitrate),
    ];

    final children = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      children.add(
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withAlpha(140),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  item.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      );
      if (i < items.length - 1) {
        children.add(Container(width: 1, height: 32, color: dividerColor));
      }
    }

    return Row(children: children);
  }
}

class _SpecItem {
  final String label;
  final String value;
  const _SpecItem({required this.label, required this.value});
}
