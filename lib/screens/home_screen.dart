import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/encoding_options.dart';
import '../models/video_info.dart';
import '../services/cache_manager_service.dart';
import '../services/transformer_service.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';
import '../widgets/animated_flame_title.dart';
import '../widgets/app_glass_card.dart';
import '../widgets/audio_extractor_card.dart';
import '../widgets/conversion_options_card.dart';
import '../widgets/theme_animated_background.dart';
import '../widgets/video_info_card.dart';
import 'processing_screen.dart';
import 'settings_screen.dart';
import 'trim_preview_screen.dart';

enum _AppMode { convert, downscale, extractor }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Extracts clean file name by stripping shared_video prefixes and timestamps.
  static String extractCleanFileName(String rawPathOrName) {
    var name = rawPathOrName;
    if (name.contains('/') || name.contains('\\')) {
      final sep = name.contains('/') ? '/' : '\\';
      name = name.split(sep).last;
    }
    name = name.replaceFirst(RegExp(r'^shared_video_\d+_'), '');
    name = name.replaceFirst(RegExp(r'^shared_video_'), '');
    return name.isNotEmpty ? name : 'video.mp4';
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _settingsService = SettingsService();

  _AppMode _selectedMode = _AppMode.convert;
  VideoInfo? _videoInfo;
  Uint8List? _videoThumbnail;
  VideoResolution? _selectedResolution;
  EncodingOptions _encodingOptions = const EncodingOptions();
  Map<String, dynamic>? _resolutionCapabilities;
  bool _isLoading = false;
  String _loadingMessage = '';

  Future<void> _loadResolutionCapabilities({String? codec}) async {
    final effectiveCodec = codec ?? _encodingOptions.codec.name;
    try {
      final caps = await TransformerService.getResolutionCapabilities(
        codec: effectiveCodec,
      );
      if (mounted) {
        setState(() {
          _resolutionCapabilities = caps;
          if (_selectedMode == _AppMode.downscale &&
              _selectedResolution != null) {
            final isSupported =
                caps[_selectedResolution!.label] as bool? ?? true;
            if (!isSupported) {
              final downscaleOptions = _getResolutionsForMode(
                _AppMode.downscale,
              );
              final firstSupported = downscaleOptions.firstWhere(
                (r) => (caps[r.label] as bool? ?? true),
                orElse: () => downscaleOptions.first,
              );
              _selectedResolution = firstSupported;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading resolution capabilities: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    final saved = _settingsService.savedEncodingOptions;
    if (saved != null) {
      _encodingOptions = saved;
    } else {
      final defaultPreset = SpeedPreset.fromEncodingPreset(
        _settingsService.settings.encodingPreset,
      );
      final defaultCodec = VideoCodec.fromName(
        _settingsService.settings.defaultVideoCodec,
      );
      _encodingOptions = EncodingOptions(
        speedPreset: defaultPreset,
        crfValue: defaultPreset.defaultCrf,
        codec: defaultCodec,
        videoAudioBitrateKbps: _settingsService.settings.audioBitrateKbps,
      );
    }
    _settingsService.addListener(_onSettingsChanged);
    CacheManagerService().clearAllCache();
    CacheManagerService().autoPurgeTempFiles();
    TransformerService.setSharedVideoCallback(
      null,
      onSharedWithName: (path, fileName) {
        if (mounted) _loadVideoFromPath(path, customName: fileName);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkCrashedJob();
      final sharedPath = await TransformerService.getInitialSharedVideo();
      if (sharedPath != null && mounted) {
        _loadVideoFromPath(sharedPath);
      }
    });
  }

  @override
  void dispose() {
    TransformerService.setSharedVideoCallback(null);
    _settingsService.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final saved = _settingsService.savedEncodingOptions;
    if (saved != null) {
      if (_encodingOptions != saved) {
        setState(() {
          _encodingOptions = saved;
        });
      }
      return;
    }
    final preset = SpeedPreset.fromEncodingPreset(
      _settingsService.settings.encodingPreset,
    );
    final defaultCodec = _settingsService.settings.defaultVideoCodec == 'hevc'
        ? VideoCodec.hevc
        : VideoCodec.h264;
    setState(() {
      if (_encodingOptions.speedPreset != preset) {
        _encodingOptions = _encodingOptions.copyWith(
          speedPreset: preset,
          crfValue: preset.defaultCrf,
        );
      }
      if (_videoInfo == null && _encodingOptions.codec != defaultCodec) {
        _encodingOptions = _encodingOptions.copyWith(codec: defaultCodec);
      }
    });
  }

  Future<void> _loadVideoFromPath(String path, {String? customName}) async {
    final l10n = _settingsService.l10n;

    String? resolvedName = customName;
    if (resolvedName != null) {
      resolvedName = HomeScreen.extractCleanFileName(resolvedName);
    } else {
      final rawName = File(path).uri.pathSegments.isNotEmpty
          ? File(path).uri.pathSegments.last
          : path;
      resolvedName = HomeScreen.extractCleanFileName(rawName);
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = l10n.t('loading_analyzing');
      _videoInfo = null;
      _selectedResolution = null;
      _videoThumbnail = null;
    });

    try {
      final info = await TransformerService.getVideoInfo(
        path,
        customName: resolvedName,
      );
      if (!mounted) return;
      final preferredCodec =
          _settingsService.savedEncodingOptions?.codec ??
          VideoCodec.fromName(_settingsService.settings.defaultVideoCodec);
      setState(() {
        _isLoading = false;
        _videoInfo = info;
        _encodingOptions = _encodingOptions.copyWith(codec: preferredCodec);
        if (info != null) {
          final resolutions = _getResolutionsForMode(_selectedMode, info);
          if (resolutions.isNotEmpty) {
            _selectedResolution = resolutions.first;
          }
        }
      });
      if (info != null) {
        _loadResolutionCapabilities(codec: preferredCodec.name);
        TransformerService.getVideoThumbnail(path).then((thumb) {
          if (mounted && _videoInfo?.filePath == path) {
            setState(() => _videoThumbnail = thumb);
          }
        });
      }
      if (info == null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.t('error_read_video'))));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.t('error_read_video')}: $e')),
        );
      }
    }
  }

  Future<void> _checkCrashedJob() async {
    final marker = await _settingsService.getJobMarker();
    if (marker == null || !mounted) return;

    final inputPath = marker['inputPath'] as String?;
    final outputPath = marker['outputPath'] as String?;
    final allocatedThreads = marker['allocatedThreads'] as int? ?? 4;
    final retryCount = marker['retryCount'] as int? ?? 0;
    final timestamp = marker['timestamp'] as int? ?? 0;

    // Clear stale marker (>24 hours)
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > 24 * 60 * 60 * 1000) {
      await _settingsService.clearJobMarker();
      return;
    }

    // Clean leftover partial file
    if (outputPath != null && outputPath.isNotEmpty) {
      try {
        final f = File(outputPath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }

    if (retryCount >= 2 || allocatedThreads <= 1) {
      await _settingsService.clearJobMarker();
      return;
    }

    final reducedThreads = (allocatedThreads - 1).clamp(1, 8);
    final l10n = _settingsService.l10n;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.t('recovery_title'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: Text(
            l10n.t('recovery_desc', args: {'cores': reducedThreads.toString()}),
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _settingsService.clearJobMarker();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(l10n.t('recovery_dismiss')),
            ),
            ElevatedButton(
              onPressed: () async {
                await _settingsService.setCpuThreads(reducedThreads);
                await _settingsService.clearJobMarker();
                if (ctx.mounted) Navigator.of(ctx).pop();

                // Auto-load input file if still available
                if (inputPath != null && File(inputPath).existsSync()) {
                  _loadVideoFromPath(inputPath);
                }
              },
              child: Text(
                l10n.t(
                  'recovery_retry',
                  args: {'cores': reducedThreads.toString()},
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  Future<void> _pickVideo() async {
    final l10n = _settingsService.l10n;

    await CacheManagerService().clearAllCache(
      specificInputPath: _videoInfo?.filePath,
    );

    setState(() {
      _isLoading = true;
      _loadingMessage = l10n.t('loading_pick');
      _videoInfo = null;
      _selectedResolution = null;
      _videoThumbnail = null;
    });

    try {
      if (TransformerService.canPickVideoNatively) {
        final picked = await TransformerService.pickVideo();
        if (!mounted) return;
        final pickedPath = picked?['path'];
        if (pickedPath != null && pickedPath.isNotEmpty) {
          await _loadVideoFromPath(pickedPath, customName: picked?['fileName']);
        } else {
          setState(() => _isLoading = false);
        }
        return;
      }

      final file = await FilePicker.pickFile(type: FileType.video);

      if (!mounted) return;

      if (file != null) {
        String? customName;
        String? effectivePath = file.path;

        try {
          final details = await TransformerService.resolveMediaDetails(
            uri: file.uri.toString(),
            fallbackPath: file.path,
          );
          if (details != null) {
            final resolvedName = details['fileName'];
            if (resolvedName != null && resolvedName.isNotEmpty) {
              customName = resolvedName;
            }
            final realPath = details['realPath'];
            if (realPath != null && realPath.isNotEmpty) {
              if (await File(realPath).exists()) {
                effectivePath = realPath;
              }
            }
          }
        } catch (e) {
          debugPrint('Error resolving media details: $e');
        }

        if (customName == null || customName.isEmpty) {
          customName = (file.name.isNotEmpty && !file.name.startsWith('cache_'))
              ? file.name
              : null;
        }

        if (effectivePath != null && effectivePath.isNotEmpty) {
          await _loadVideoFromPath(effectivePath, customName: customName);
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.t('error_read_video')}: $e')),
        );
      }
    }
  }

  void _resetVideo() {
    CacheManagerService().clearAllCache(
      specificInputPath: _videoInfo?.filePath,
    );
    setState(() {
      _videoInfo = null;
      _selectedResolution = null;
      _videoThumbnail = null;
    });
  }

  void _showRenameDialog() {
    if (_videoInfo == null) return;
    final l10n = _settingsService.l10n;
    final currentFileName = _videoInfo!.fileName;
    final lastDotIndex = currentFileName.lastIndexOf('.');
    final baseName = lastDotIndex != -1
        ? currentFileName.substring(0, lastDotIndex)
        : currentFileName;
    final ext = lastDotIndex != -1
        ? currentFileName.substring(lastDotIndex + 1)
        : '';

    final controller = TextEditingController(text: baseName);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(l10n.t('rename_dialog_title')),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.t('rename_dialog_hint')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                l10n.t('cancel'),
                style: const TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
            FilledButton(
              onPressed: () {
                final trimmedBase = controller.text.trim();
                if (trimmedBase.isNotEmpty) {
                  final newFileName = ext.isNotEmpty
                      ? '$trimmedBase.$ext'
                      : trimmedBase;
                  setState(() {
                    _videoInfo = _videoInfo!.copyWith(fileName: newFileName);
                  });
                }
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.t('dialog_save')),
            ),
          ],
        );
      },
    );
  }


  List<VideoResolution> _getResolutionsForMode(
    _AppMode mode, [
    VideoInfo? source,
  ]) {
    final info = source ?? _videoInfo;
    if (info == null) return [];

    final targets = <VideoResolution>[];

    if (mode == _AppMode.convert || mode == _AppMode.extractor) {
      targets.add(
        VideoResolution(
          label: 'Original (${info.resolution})',
          width: info.width,
          height: info.height,
        ),
      );
      return targets;
    }

    final dim = info.shortDimension;

    if (mode == _AppMode.downscale) {
      final downscaleOptions = VideoResolution.standardResolutions
          .where((r) => r.height < dim)
          .toList();
      if (downscaleOptions.isEmpty) {
        targets.add(
          VideoResolution(
            label: 'Original (${info.resolution})',
            width: info.width,
            height: info.height,
          ),
        );
      } else {
        targets.addAll(downscaleOptions);
      }
    }

    return targets;
  }

  void _onModeChanged(_AppMode mode) {
    if (_selectedMode == mode) return;
    setState(() {
      _selectedMode = mode;
      final resolutions = _getResolutionsForMode(mode);
      if (resolutions.isNotEmpty) {
        if (mode == _AppMode.downscale && _resolutionCapabilities != null) {
          _selectedResolution = resolutions.firstWhere(
            (r) => (_resolutionCapabilities![r.label] as bool? ?? true),
            orElse: () => resolutions.first,
          );
        } else {
          _selectedResolution = resolutions.first;
        }
      }
    });
  }

  void _startProcessing() async {
    if (_videoInfo == null) return;
    if (_selectedMode == _AppMode.extractor && !_videoInfo!.hasAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_settingsService.l10n.t('no_audio_track'))),
      );
      return;
    }
    if (_selectedMode != _AppMode.extractor && _selectedResolution == null) {
      return;
    }

    final fallbackRes =
        _selectedResolution ??
        VideoResolution(
          label: 'Original (${_videoInfo!.resolution})',
          width: _videoInfo!.width,
          height: _videoInfo!.height,
        );

    final EncodingOptions options = _encodingOptions;

    final isSource4K = _videoInfo!.is4K;
    final isTarget4K =
        fallbackRes.height >= 2160 ||
        fallbackRes.width >= 3840 ||
        (fallbackRes.width >= 2160 && fallbackRes.height >= 3840);
    final is4K = isSource4K || isTarget4K;
    final isLong = _videoInfo!.isLongDuration;
    final isMaxPresetHeavy =
        options.speedPreset == SpeedPreset.max && _videoInfo!.isHeavyProcessing;
    final isHeavyProcess = is4K || isLong || isMaxPresetHeavy;

    // Heavy processing confirmation dialog
    if (_selectedMode != _AppMode.extractor && isHeavyProcess) {
      final l10n = _settingsService.l10n;
      final String descText;
      if (is4K && isLong) {
        descText = l10n.t(
          'heavy_process_desc_4k_long',
          args: {'duration': _videoInfo!.formattedDuration},
        );
      } else if (is4K) {
        descText = l10n.t('heavy_process_desc_4k');
      } else if (isLong) {
        descText = l10n.t(
          'heavy_process_desc_long',
          args: {'duration': _videoInfo!.formattedDuration},
        );
      } else {
        descText = l10n.t('heavy_process_desc');
      }

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.t('heavy_process_title'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              descText,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: theme.colorScheme.onSurface.withAlpha(200),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(l10n.t('heavy_process_cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(l10n.t('heavy_process_continue')),
                  ),
                ],
              ),
            ],
          );
        },
      );

      if (proceed != true) return;
    }

    if (!mounted) return;

    final maxRes =
        _resolutionCapabilities?['maxResolution'] as String? ?? '1080p';
    final isSourceUnsupported =
        _resolutionCapabilities != null &&
        (_resolutionCapabilities![_videoInfo!.resolution] == false);

    if (_selectedMode == _AppMode.convert && isSourceUnsupported) {
      final l10n = _settingsService.l10n;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.t('hardware_limit_title'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              l10n.t(
                'hardware_limit_desc',
                args: {'source': _videoInfo!.resolution, 'target': maxRes},
              ),
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: theme.colorScheme.onSurface.withAlpha(200),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(l10n.t('hardware_limit_cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(l10n.t('hardware_limit_continue')),
                  ),
                ],
              ),
            ],
          );
        },
      );

      if (proceed != true) return;
    }

    if (!mounted) return;

    final targetResForProcessing =
        (_selectedMode == _AppMode.convert && isSourceUnsupported)
        ? (VideoResolution.standardResolutions.firstWhere(
            (r) => r.label == maxRes,
            orElse: () => fallbackRes,
          ))
        : fallbackRes;

    final configuredOptions = await Navigator.of(context).push<EncodingOptions>(
      MaterialPageRoute(
        builder: (context) => TrimPreviewScreen(
          videoInfo: _videoInfo!,
          targetResolution: targetResForProcessing,
          encodingOptions: options,
          appSettings: _settingsService.settings,
          isAudioExtraction: _selectedMode == _AppMode.extractor,
        ),
      ),
    );

    if (configuredOptions == null || !mounted) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ProcessingScreen(
          videoInfo: _videoInfo!,
          targetResolution: targetResForProcessing,
          encodingOptions: configuredOptions,
          appSettings: _settingsService.settings,
          isAudioExtraction: _selectedMode == _AppMode.extractor,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _videoInfo = null;
        _selectedResolution = null;
        _videoThumbnail = null;
      });
      CacheManagerService().clearAllCache();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = _settingsService.l10n;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: (_videoInfo != null && !_isLoading)
            ? IconButton(
                onPressed: _resetVideo,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: l10n.t('back_to_home'),
              )
            : null,
        title: AnimatedFlameTitle(title: l10n.t('app_title')),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.t('settings'),
          ),
        ],
      ),
      body: ThemeAnimatedBackground(
        child: SafeArea(
          child: _isLoading
              ? _buildLoadingState(theme, l10n)
              : _videoInfo == null
              ? _buildEmptyState(theme, l10n)
              : _buildContent(theme, l10n),
        ),
      ),
    );
  }


  Widget _buildLoadingState(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3.0,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _loadingMessage.isNotEmpty
                  ? _loadingMessage
                  : l10n.t('loading_analyzing'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('loading_large_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                color: theme.colorScheme.onSurface.withAlpha(150),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomOpticalOffset = constraints.maxHeight > 360 ? 64.0 : 0.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 16,
                  bottom: 16 + bottomOpticalOffset,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _buildImportCard(theme, l10n),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Unified segmented control for mode selection.
  Widget _buildSegmentedModeBar(ThemeData theme, AppLocalizations l10n) {
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.t('select_mode'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withAlpha(160),
              letterSpacing: 0,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.onSurface.withAlpha(isDark ? 20 : 28),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SegmentItem(
                  label: l10n.t('mode_convert'),
                  isSelected: _selectedMode == _AppMode.convert,
                  onTap: () => _onModeChanged(_AppMode.convert),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _SegmentItem(
                  label: l10n.t('mode_downscale'),
                  isSelected: _selectedMode == _AppMode.downscale,
                  onTap: () => _onModeChanged(_AppMode.downscale),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _SegmentItem(
                  label: l10n.t('mode_extractor'),
                  isSelected: _selectedMode == _AppMode.extractor,
                  onTap: () => _onModeChanged(_AppMode.extractor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Video selection card.
  Widget _buildImportCard(ThemeData theme, AppLocalizations l10n) {
    final isDark = theme.brightness == Brightness.dark;

    return AppGlassCard(
      onTap: _pickVideo,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      border: Border.all(
        color: theme.colorScheme.onSurface.withAlpha(isDark ? 22 : 28),
        width: 1.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withAlpha(isDark ? 14 : 10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.onSurface.withAlpha(isDark ? 22 : 26),
                width: 1.0,
              ),
            ),
            child: Icon(
              Icons.video_file_outlined,
              size: 24,
              color: theme.colorScheme.onSurface.withAlpha(210),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('supported_formats_hint'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.45,
              letterSpacing: 0,
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _pickVideo,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(l10n.t('pick_video')),
          ),
        ],
      ),
    );
  }


  /// Each mode carries its own accent so the active task reads at a glance.
  /// Sakura keeps its own brand color across modes.
  Color _modeAccent(ThemeData theme) {
    final mode = _settingsService.settings.themeMode;
    if (mode == 'sakura' || mode == 'oled_sakura') {
      return theme.colorScheme.primary;
    }
    switch (_selectedMode) {
      case _AppMode.convert:
        return theme.colorScheme.primary;
      case _AppMode.downscale:
        return theme.colorScheme.secondary;
      case _AppMode.extractor:
        return const Color(0xFFC2410C);
    }
  }

  Widget _buildContent(ThemeData baseTheme, AppLocalizations l10n) {
    final accent = _modeAccent(baseTheme);
    final theme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(primary: accent),
      sliderTheme: baseTheme.sliderTheme.copyWith(
        activeTrackColor: accent,
        inactiveTrackColor: accent.withAlpha(35),
        thumbColor: accent,
        overlayColor: accent.withAlpha(25),
        valueIndicatorColor: accent,
      ),
    );
    final isDark = theme.brightness == Brightness.dark;

    return Theme(data: theme, child: _buildContentBody(theme, l10n, isDark));
  }

  Widget _buildContentBody(
    ThemeData theme,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSegmentedModeBar(theme, l10n),
              const SizedBox(height: 16),

              VideoInfoCard(
                videoInfo: _videoInfo!,
                thumbnailBytes: _videoThumbnail,
                onRename: _showRenameDialog,
              ),
              const SizedBox(height: 16),

              if (_selectedMode == _AppMode.extractor)
                AudioExtractorCard(
                  sourceVideo: _videoInfo!,
                  encodingOptions: _encodingOptions,
                  onOptionsChanged: (opts) {
                    setState(() => _encodingOptions = opts);
                    _settingsService.saveEncodingOptions(opts);
                  },
                  l10n: l10n,
                )
              else
                ConversionOptionsCard(
                  sourceVideo: _videoInfo!,
                  resolutions: _getResolutionsForMode(_selectedMode),
                  selectedResolution: _selectedResolution,
                  encodingOptions: _encodingOptions,
                  resolutionCapabilities: _resolutionCapabilities,
                  onResolutionChanged: (res) =>
                      setState(() => _selectedResolution = res),
                  onOptionsChanged: (opts) {
                    final oldCodec = _encodingOptions.codec;
                    setState(() => _encodingOptions = opts);
                    _settingsService.saveEncodingOptions(opts);
                    if (oldCodec != opts.codec) {
                      _loadResolutionCapabilities(codec: opts.codec.name);
                    }
                  },
                  l10n: l10n,
                ),

              const SizedBox(height: 20),

              FilledButton(
                onPressed:
                    ((_selectedMode == _AppMode.extractor &&
                            (_videoInfo?.hasAudio ?? true)) ||
                        (_selectedMode != _AppMode.extractor &&
                            _selectedResolution != null))
                    ? _startProcessing
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _selectedMode == _AppMode.extractor
                      ? l10n.t('start_audio_extraction')
                      : l10n.t('start_conversion'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              () {
                final cardOpacity = _settingsService.settings.cardOpacity.clamp(
                  0.5,
                  1.0,
                );
                final buttonBg = cardOpacity < 1.0
                    ? theme.colorScheme.surface.withAlpha(
                        (255 * cardOpacity).round().clamp(0, 255),
                      )
                    : theme.colorScheme.surface;
                return OutlinedButton(
                  onPressed: _pickVideo,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: buttonBg,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withAlpha(
                        isDark ? 80 : 110,
                      ),
                      width: 1.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.t('change_video'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withAlpha(210),
                      letterSpacing: 0,
                    ),
                  ),
                );
              }(),
            ],
          ),
        ),
      ),
    );
  }
}


class _SegmentItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: const Cubic(0.22, 1, 0.36, 1),
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface.withAlpha(165),
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}
