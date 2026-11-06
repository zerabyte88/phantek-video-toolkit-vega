import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_settings.dart';
import '../services/device_spec_helper.dart';
import '../services/license_service.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_glass_card.dart';
import '../widgets/progress_animation_painter.dart';
import '../widgets/theme_animated_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();
  Map<String, dynamic>? _hardwareInfo;
  String _appVersion = 'v2.5.4';
  String _buildNumber = '25004';
  double? _dragCardOpacity;

  @override
  void initState() {
    super.initState();
    _settingsService.addListener(_onSettingsChanged);
    _loadHardwareInfo();
    _loadAppVersion();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${packageInfo.version}';
          _buildNumber = packageInfo.buildNumber.isNotEmpty
              ? packageInfo.buildNumber
              : '25004';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _appVersion = 'v2.5.4';
          _buildNumber = '25004';
        });
      }
    }
  }

  Future<void> _loadHardwareInfo() async {
    final info = await DeviceSpecHelper.getHardwareInfo();
    if (mounted) {
      setState(() {
        _hardwareInfo = info;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = _settingsService.settings;
    final l10n = _settingsService.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.t('settings_title'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ThemeAnimatedBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _buildSectionTitle(
                icon: Icons.palette_outlined,
                title: l10n.t('theme_appearance'),
                theme: theme,
              ),
              const SizedBox(height: 8),
              _buildModernCard(
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLanguageTile(context, theme, settings, l10n),
                    _buildDivider(theme),

                    Row(
                      children: [
                        Icon(
                          Icons.contrast_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.t('settings_theme'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    _buildThemeGrid(theme, settings, l10n),

                    _buildDivider(theme),

                    _buildCardOpacitySlider(theme, settings, l10n),

                    _buildDivider(theme),

                    _buildWakelockTile(theme, settings, l10n),

                    _buildDivider(theme),

                    _buildProgressStyleTile(context, theme, settings, l10n),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _buildSectionTitle(
                icon: Icons.memory_rounded,
                title: l10n.t('settings_transcode_engine'),
                theme: theme,
              ),
              const SizedBox(height: 8),
              _buildTranscodeEngineCard(theme, settings, l10n),

              const SizedBox(height: 20),

              _buildSectionTitle(
                icon: Icons.folder_copy_outlined,
                title: l10n.t('storage_cache'),
                theme: theme,
              ),
              const SizedBox(height: 8),
              _buildModernCard(
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFolderTile(
                      icon: Icons.video_library_outlined,
                      title: l10n.t('settings_output_folder'),
                      currentPath: settings.outputDirectory,
                      defaultLabel: l10n.t('settings_folder_default'),
                      theme: theme,
                      onChange: () async {
                        try {
                          final selected = await FilePicker.getDirectoryPath(
                            dialogTitle: l10n.t('settings_output_folder'),
                          );
                          if (selected != null && selected.trim().isNotEmpty) {
                            await _settingsService.setOutputDirectory(
                              selected.trim(),
                            );
                            if (context.mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.t('settings_folder_changed'),
                                  ),
                                ),
                              );
                            }
                          }
                        } catch (_) {}
                      },
                      onReset: settings.outputDirectory.isNotEmpty
                          ? () async {
                              await _settingsService.setOutputDirectory('');
                              if (context.mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.t('settings_folder_changed'),
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                      l10n: l10n,
                    ),

                    _buildDivider(theme),

                    _buildFolderTile(
                      icon: Icons.music_note_outlined,
                      title: l10n.t('settings_audio_output_folder'),
                      currentPath: settings.audioOutputDirectory,
                      defaultLabel: l10n.t('settings_audio_folder_default'),
                      theme: theme,
                      onChange: () async {
                        try {
                          final selected = await FilePicker.getDirectoryPath(
                            dialogTitle: l10n.t('settings_audio_output_folder'),
                          );
                          if (selected != null && selected.trim().isNotEmpty) {
                            await _settingsService.setAudioOutputDirectory(
                              selected.trim(),
                            );
                            if (context.mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.t('settings_audio_folder_changed'),
                                  ),
                                ),
                              );
                            }
                          }
                        } catch (_) {}
                      },
                      onReset: settings.audioOutputDirectory.isNotEmpty
                          ? () async {
                              await _settingsService.setAudioOutputDirectory(
                                '',
                              );
                              if (context.mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.t('settings_audio_folder_changed'),
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                      l10n: l10n,
                    ),

                    _buildDivider(theme),

                    _buildFileNamingSection(theme, settings, l10n),

                    _buildDivider(theme),

                    _buildPreserveMediaDateTile(theme, settings, l10n),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _buildSectionTitle(
                icon: Icons.info_outline_rounded,
                title: l10n.t('device_specs_title'),
                theme: theme,
              ),
              const SizedBox(height: 8),
              if (_hardwareInfo != null) ...[
                _buildModernCard(
                  theme: theme,
                  child: Column(
                    children: [
                      _buildSpecRow(
                        theme,
                        l10n.t('device_name'),
                        _hardwareInfo!['deviceName'] as String? ??
                            '${_hardwareInfo!['manufacturer']} ${_hardwareInfo!['model']}',
                      ),
                      const SizedBox(height: 7),
                      _buildSpecRow(
                        theme,
                        l10n.t('device_model'),
                        _hardwareInfo!['modelCode'] as String? ??
                            _hardwareInfo!['model'] as String? ??
                            l10n.t('unknown'),
                      ),
                      const SizedBox(height: 7),
                      _buildCpuSpecRow(
                        theme: theme,
                        l10n: l10n,
                        soc:
                            _hardwareInfo!['socDescription'] as SocDescription?,
                        fallbackText:
                            _hardwareInfo!['cpu'] as String? ??
                            _hardwareInfo!['hardware'] as String? ??
                            'Standard Processor',
                        cores:
                            _hardwareInfo!['cores'] as int? ??
                            AppSettings.deviceCoreCount,
                      ),
                      const SizedBox(height: 7),
                      _buildSpecRow(
                        theme,
                        l10n.t('device_gpu'),
                        _hardwareInfo!['gpu'] as String? ??
                            l10n.t('hardware_accel'),
                      ),
                      const SizedBox(height: 7),
                      _buildSpecRow(
                        theme,
                        l10n.t('device_ram'),
                        _hardwareInfo!['ram'] as String? ??
                            '${_hardwareInfo!['ramMb']} MB',
                      ),
                      const SizedBox(height: 7),
                      _buildSpecRow(
                        theme,
                        l10n.t('device_storage'),
                        '${_hardwareInfo!['storage'] ?? '256 GB'} (${_hardwareInfo!['storageFree'] ?? '142 GB'} ${l10n.t('storage_free')})',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _buildAboutCard(theme, l10n),

              const SizedBox(height: 20),

              Center(
                child: () {
                  final effectiveOpacity =
                      (_dragCardOpacity ?? settings.cardOpacity).clamp(
                        0.5,
                        1.0,
                      );
                  final resetBtnBg = effectiveOpacity < 1.0
                      ? theme.colorScheme.surface.withAlpha(
                          (255 * effectiveOpacity).round().clamp(0, 255),
                        )
                      : theme.colorScheme.surface;
                  return OutlinedButton.icon(
                    onPressed: () => _confirmResetDefaults(context),
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: Text(
                      l10n.t('settings_reset_default'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: resetBtnBg,
                      foregroundColor: const Color(0xFFEF4444),
                      side: BorderSide(
                        color: const Color(0xFFEF4444).withAlpha(120),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required ThemeData theme,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: theme.colorScheme.onSurface.withAlpha(220),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildModernCard({
    required Widget child,
    required ThemeData theme,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return AppGlassCard(padding: padding, child: child);
  }

  Widget _buildDivider(ThemeData theme, {double vertical = 12}) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vertical),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
      ),
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    ThemeData theme,
    AppSettings settings,
    AppLocalizations l10n,
  ) {
    final active = AppLocalizations.supportedLanguages.firstWhere(
      (l) =>
          l['code'] == settings.languageCode ||
          (settings.languageCode == 'zh' && l['code'] == 'zh_CN'),
      orElse: () => {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    );

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showLanguageModal(context, theme, settings, l10n),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.translate_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.t('settings_language'),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                l10n.t('settings_language_desc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  color: theme.colorScheme.onSurface.withAlpha(130),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary.withAlpha(45),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    active['flag'] ?? '',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      active['name'] ?? 'Language',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageModal(
    BuildContext context,
    ThemeData theme,
    AppSettings settings,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            return Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withAlpha(50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.language_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.t('select_language_title'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    itemCount: AppLocalizations.supportedLanguages.length,
                    itemBuilder: (_, index) {
                      final item = AppLocalizations.supportedLanguages[index];
                      final code = item['code']!;
                      final isSelected =
                          settings.languageCode == code ||
                          (settings.languageCode == 'zh' && code == 'zh_CN');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: isSelected
                              ? theme.colorScheme.primary.withAlpha(25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await _settingsService.setLanguage(code);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline.withAlpha(20),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    item['flag'] ?? '',
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      item['name'] ?? code,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_rounded,
                                            size: 13,
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            l10n.t('active_language_badge'),
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  theme.colorScheme.onPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildThemeGrid(
    ThemeData theme,
    AppSettings settings,
    AppLocalizations l10n,
  ) {
    final staticThemes = [
      {
        'id': 'oled_pure',
        'title': l10n.t('theme_oled_pure'),
        'desc': l10n.t('theme_oled_pure_desc'),
        'icon': Icons.brightness_2_outlined,
        'accent': const Color(0xFF60A5FA),
        'badge': l10n.t('badge_static'),
      },
      {
        'id': 'light_clean',
        'title': l10n.t('theme_light_clean'),
        'desc': l10n.t('theme_light_clean_desc'),
        'icon': Icons.wb_sunny_outlined,
        'accent': const Color(0xFF0EA5E9),
        'badge': l10n.t('badge_static'),
      },
    ];

    final animatedThemes = [
      {
        'id': 'oled_snowfall',
        'title': l10n.t('theme_oled_snowfall'),
        'desc': l10n.t('theme_oled_snowfall_desc'),
        'icon': Icons.ac_unit_rounded,
        'accent': const Color(0xFF38BDF8),
        'badge': l10n.t('badge_live'),
      },
      {
        'id': 'light',
        'title': l10n.t('theme_light'),
        'desc': l10n.t('theme_light_desc'),
        'icon': Icons.light_mode_rounded,
        'accent': const Color(0xFFFBBF24),
        'badge': l10n.t('badge_live'),
      },
      {
        'id': 'oled_midnight',
        'title': l10n.t('theme_oled_midnight'),
        'desc': l10n.t('theme_oled_midnight_desc'),
        'icon': Icons.nightlight_round,
        'accent': const Color(0xFFA78BFA),
        'badge': l10n.t('badge_live'),
      },
      {
        'id': 'oled_sakura',
        'title': l10n.t('theme_oled_sakura'),
        'desc': l10n.t('theme_oled_sakura_desc'),
        'icon': Icons.local_florist_rounded,
        'accent': const Color(0xFFF472B6),
        'badge': l10n.t('badge_live'),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < staticThemes.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _buildThemeCard(
                  item: staticThemes[i],
                  isSelected: settings.themeMode == staticThemes[i]['id'],
                  theme: theme,
                  isCompact: false,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < animatedThemes.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _buildThemeCard(
                  item: animatedThemes[i],
                  isSelected: settings.themeMode == animatedThemes[i]['id'],
                  theme: theme,
                  isCompact: true,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildThemeCard({
    required Map<String, dynamic> item,
    required bool isSelected,
    required ThemeData theme,
    required bool isCompact,
  }) {
    final id = item['id'] as String;
    final accent = item['accent'] as Color;
    final badge = item['badge'] as String?;
    final icon = item['icon'] as IconData;
    final title = item['title'] as String;

    return Material(
      color: isSelected
          ? accent.withAlpha(25)
          : theme.colorScheme.surfaceContainerHighest.withAlpha(35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _settingsService.setThemeMode(id);
        },
        child: Container(
          height: isCompact ? 80 : 68,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 4 : 10,
            vertical: isCompact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? accent
                  : theme.colorScheme.outline.withAlpha(30),
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: isCompact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected ? accent : theme.colorScheme.onSurface,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected
                              ? accent
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: accent.withAlpha(120),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          badge,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: accent,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected ? accent : theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? accent
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: accent.withAlpha(120),
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                badge,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCardOpacitySlider(
    ThemeData theme,
    AppSettings settings,
    AppLocalizations l10n,
  ) {
    final effectiveOpacity = _dragCardOpacity ?? settings.cardOpacity;
    final opacity = effectiveOpacity.clamp(0.5, 1.0);
    final percentage = (opacity * 100).round();
    final isNotDefault = (settings.cardOpacity - 1.0).abs() > 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.opacity_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.t('settings_card_opacity'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withAlpha(60),
                ),
              ),
              child: Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            if (isNotDefault) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                tooltip: l10n.t('reset'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: theme.colorScheme.primary,
                onPressed: () {
                  setState(() {
                    _dragCardOpacity = null;
                  });
                  _settingsService.setCardOpacity(1.0);
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l10n.t('settings_card_opacity_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurface.withAlpha(130),
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: theme.sliderTheme.copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: opacity,
            min: 0.50,
            max: 1.00,
            divisions: 10,
            label: '$percentage%',
            onChanged: (val) {
              final rounded = (val * 20).round() / 20.0;
              if (_dragCardOpacity != rounded) {
                setState(() {
                  _dragCardOpacity = rounded;
                });
                _settingsService.setCardOpacityFast(rounded);
              }
            },
            onChangeEnd: (val) {
              final rounded = (val * 20).round() / 20.0;
              setState(() {
                _dragCardOpacity = null;
              });
              _settingsService.setCardOpacity(rounded);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '50%',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '100% (Default)',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTranscodeEngineCard(
    ThemeData theme,
    AppSettings settings,
    AppLocalizations l10n,
  ) {
    final isSoftware = settings.transcodeEngine == 'software';

    return _buildModernCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.speed_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.t('settings_transcode_engine'),
                style: TextStyle(
                  fontSize: 13.5,
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
              runSpacing: 6,
              children: [
                _buildChoiceChip(
                  theme: theme,
                  label: l10n.t('engine_hardware_title'),
                  selected: !isSoftware,
                  onSelected: () =>
                      _settingsService.setTranscodeEngine('hardware'),
                ),
                _buildChoiceChip(
                  theme: theme,
                  label: l10n.t('engine_software_title'),
                  selected: isSoftware,
                  onSelected: () =>
                      _settingsService.setTranscodeEngine('software'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                isSoftware
                    ? l10n.t('engine_software_desc')
                    : l10n.t('engine_hardware_desc'),
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: theme.colorScheme.onSurface.withAlpha(140),
                ),
              ),
            ),
          ),

          _buildDivider(theme),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.alt_route_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.t('engine_fallback_toggle_title'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RepaintBoundary(
                child: Switch(
                  value: settings.enableEngineFallback,
                  onChanged: (val) {
                    _settingsService.setEnableEngineFallback(val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              l10n.t('engine_fallback_toggle_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurface.withAlpha(130),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWakelockTile(
    ThemeData theme,
    AppSettings settings,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                settings.keepScreenAwake
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.t('settings_wakelock'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            RepaintBoundary(
              child: Switch(
                value: settings.keepScreenAwake,
                onChanged: (val) {
                  _settingsService.setKeepScreenAwake(val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l10n.t('settings_wakelock_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurface.withAlpha(130),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressStyleTile(
    BuildContext context,
    ThemeData theme,
    AppSettings settings,
    AppLocalizations l10n,
  ) {
    final vStyle = settings.videoProgressStyle.toUpperCase();
    final aStyle = settings.audioProgressStyle.toUpperCase();
    final subtitle = vStyle == aStyle
        ? '$vStyle (${l10n.t('scope_both')})'
        : '${l10n.t('scope_video')}: $vStyle • ${l10n.t('scope_audio')}: $aStyle';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showProgressStyleModal(context, theme, l10n),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.motion_photos_on_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('settings_progress_style_title'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                l10n.t('settings_progress_style_subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  color: theme.colorScheme.onSurface.withAlpha(130),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProgressStyleModal(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    String currentScope = 'both'; // 'video', 'audio', 'both'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        double previewProgress = 0.68;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final settings = _settingsService.settings;
            final isDark = theme.brightness == Brightness.dark;
            final primary = theme.colorScheme.primary;

            final activeStyle = currentScope == 'video'
                ? settings.videoProgressStyle
                : currentScope == 'audio'
                ? settings.audioProgressStyle
                : (settings.videoProgressStyle == settings.audioProgressStyle
                      ? settings.videoProgressStyle
                      : null);

            final styles = [
              {
                'id': 'v1',
                'title': l10n.t('style_v1_title'),
                'icon': Icons.radio_button_checked_rounded,
              },
              {
                'id': 'v2',
                'title': l10n.t('style_v2_title'),
                'icon': Icons.sensors_rounded,
              },
              {
                'id': 'v3',
                'title': l10n.t('style_v3_title'),
                'icon': Icons.waves_rounded,
              },
              {
                'id': 'v4',
                'title': l10n.t('style_v4_title'),
                'icon': Icons.water_drop_rounded,
              },
              {
                'id': 'v5',
                'title': l10n.t('style_v5_title'),
                'icon': Icons.view_stream_rounded,
              },
              {
                'id': 'v6',
                'title': l10n.t('style_v6_title'),
                'icon': Icons.gesture_rounded,
              },
            ];

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.90,
              minChildSize: 0.50,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withAlpha(50),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.motion_photos_on_rounded,
                            color: primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.t('settings_progress_style_title'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildScopeButton(
                              label: l10n.t('scope_video'),
                              isSelected: currentScope == 'video',
                              theme: theme,
                              onTap: () {
                                setModalState(() => currentScope = 'video');
                              },
                            ),
                            _buildScopeButton(
                              label: l10n.t('scope_audio'),
                              isSelected: currentScope == 'audio',
                              theme: theme,
                              onTap: () {
                                setModalState(() => currentScope = 'audio');
                              },
                            ),
                            _buildScopeButton(
                              label: l10n.t('scope_both'),
                              isSelected: currentScope == 'both',
                              theme: theme,
                              onTap: () {
                                setModalState(() => currentScope = 'both');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ProgressStylePreviewBox(
                      style: activeStyle ?? settings.videoProgressStyle,
                      theme: theme,
                      progress: previewProgress,
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B).withAlpha(120)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155).withAlpha(180)
                                : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 18, color: primary),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 38,
                              child: Text(
                                '${(previewProgress * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3.5,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6.5,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14,
                                  ),
                                  activeTrackColor: primary,
                                  inactiveTrackColor: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFCBD5E1),
                                  thumbColor: primary,
                                ),
                                child: Slider(
                                  value: previewProgress,
                                  min: 0.0,
                                  max: 1.0,
                                  divisions: 100,
                                  onChanged: (val) {
                                    setModalState(() => previewProgress = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        children: styles.map((item) {
                          final id = item['id'] as String;
                          final title = item['title'] as String;
                          final icon = item['icon'] as IconData;
                          final isSelected = activeStyle == id;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: isSelected
                                  ? primary.withAlpha(25)
                                  : isDark
                                  ? const Color(0xFF1E293B).withAlpha(120)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  if (currentScope == 'video') {
                                    await _settingsService
                                        .setVideoProgressStyle(id);
                                  } else if (currentScope == 'audio') {
                                    await _settingsService
                                        .setAudioProgressStyle(id);
                                  } else {
                                    await _settingsService
                                        .setBothProgressStyles(id);
                                  }
                                  setModalState(() {});
                                  if (mounted) setState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? primary
                                          : isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0),
                                      width: isSelected ? 1.8 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? primary.withAlpha(30)
                                              : primary.withAlpha(15),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          icon,
                                          size: 20,
                                          color: isSelected
                                              ? primary
                                              : theme.colorScheme.onSurface
                                                    .withAlpha(180),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? primary
                                                : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle_rounded
                                            : Icons
                                                  .radio_button_unchecked_rounded,
                                        size: 22,
                                        color: isSelected
                                            ? primary
                                            : theme.colorScheme.onSurface
                                                  .withAlpha(80),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildScopeButton({
    required String label,
    required bool isSelected,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? primary.withAlpha(200) : primary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurface.withAlpha(160),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileNamingSection(
    ThemeData theme,
    AppSettings settings,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.t('settings_file_naming'),
              style: TextStyle(
                fontSize: 13.5,
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
            runSpacing: 6,
            children: [
              _buildChoiceChip(
                theme: theme,
                label: l10n.t('naming_format_suffix'),
                selected: settings.fileNamingFormat == 'suffix',
                onSelected: () =>
                    _settingsService.setFileNamingFormat('suffix'),
              ),
              _buildChoiceChip(
                theme: theme,
                label: l10n.t('naming_format_timestamp'),
                selected: settings.fileNamingFormat == 'timestamp',
                onSelected: () =>
                    _settingsService.setFileNamingFormat('timestamp'),
              ),
              _buildChoiceChip(
                theme: theme,
                label: l10n.t('naming_format_simple'),
                selected: settings.fileNamingFormat == 'simple',
                onSelected: () =>
                    _settingsService.setFileNamingFormat('simple'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            settings.fileNamingFormat == 'timestamp'
                ? l10n.t('naming_format_timestamp_desc')
                : (settings.fileNamingFormat == 'simple'
                      ? l10n.t('naming_format_simple_desc')
                      : l10n.t('naming_format_suffix_desc')),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: theme.colorScheme.onSurface.withAlpha(140),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreserveMediaDateTile(
    ThemeData theme,
    AppSettings settings,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                settings.preserveMediaDate
                    ? Icons.event_available_rounded
                    : Icons.event_busy_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.t('settings_preserve_date'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            RepaintBoundary(
              child: Switch(
                value: settings.preserveMediaDate,
                onChanged: (val) {
                  _settingsService.setPreserveMediaDate(val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l10n.t('settings_preserve_date_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: theme.colorScheme.onSurface.withAlpha(140),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderTile({
    required IconData icon,
    required String title,
    required String currentPath,
    required String defaultLabel,
    required ThemeData theme,
    required VoidCallback onChange,
    required VoidCallback? onReset,
    required AppLocalizations l10n,
  }) {
    final isCustom = currentPath.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCustom ? currentPath : defaultLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isCustom
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isCustom
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withAlpha(140),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: onChange,
                icon: const Icon(Icons.folder_open_rounded, size: 15),
                label: Text(l10n.t('settings_change_folder')),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              if (onReset != null)
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restore_rounded, size: 15),
                  label: Text(l10n.t('settings_reset_folder')),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutCard(ThemeData theme, AppLocalizations l10n) {
    return _buildModernCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Color(0xFF06B6D4),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.t('settings_about'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildDetailRow(theme, l10n.t('app_version'), _appVersion),
          const SizedBox(height: 6),
          _buildDetailRow(theme, l10n.t('build_label'), _buildNumber),
          const SizedBox(height: 6),
          _buildDetailRow(
            theme,
            l10n.t('license_label'),
            'MIT License',
            onTap: () => _showAppLicensePage(context, theme),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withAlpha(35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.primary.withAlpha(50),
                      width: 1.2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.8),
                    child: Image.asset(
                      'assets/icon/developer_avatar.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: theme.colorScheme.primary.withAlpha(22),
                        child: Icon(
                          Icons.person_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Developer: zerabyte88',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'github.com/zerabyte88',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withAlpha(130),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final uri = Uri.parse(
                        'https://github.com/zerabyte88/phantek-video-toolkit-vega',
                      );
                      try {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (_) {}
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withAlpha(70),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 13,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'GitHub',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAppLicensePage(BuildContext context, ThemeData theme) {
    LicenseService.registerCustomLicenses();
    showLicensePage(
      context: context,
      applicationName: 'Phantek - Video Toolkit Vega',
      applicationVersion: '',
      applicationLegalese: '',
      applicationIcon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 56,
              height: 56,
              fit: BoxFit.contain,
            ),
          ),
          Text(
            '$_appVersion ($_buildNumber)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withAlpha(140),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Text(
              'Copyright © 2026 zerabyte88\n'
              'Licensed under the MIT License.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: theme.colorScheme.onSurface.withAlpha(160),
              ),
            ),
          ),
          _buildLicenseLinkTile(
            theme: theme,
            icon: Icons.code_rounded,
            label: 'Source code',
            url: 'https://github.com/zerabyte88/phantek-video-toolkit-vega',
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLicenseLinkTile({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String url,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            try {
              await launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              );
            } catch (_) {}
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withAlpha(12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outline.withAlpha(35),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF06B6D4)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        url,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: const Color(0xFF06B6D4),
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFF06B6D4)
                              .withAlpha(120),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 13,
                  color: theme.colorScheme.onSurface.withAlpha(130),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required ThemeData theme,
    required String label,
    required bool selected,
    required VoidCallback? onSelected,
    bool enabled = true,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return ChoiceChip(
      showCheckmark: false,
      selected: selected && enabled,
      selectedColor: theme.colorScheme.primary,
      backgroundColor: !enabled
          ? (isDark
                ? theme.colorScheme.surfaceContainerHighest.withAlpha(20)
                : theme.colorScheme.surfaceContainerHighest.withAlpha(50))
          : (isDark
                ? theme.colorScheme.surfaceContainerHighest.withAlpha(40)
                : theme.colorScheme.surface),
      side: BorderSide(
        color: !enabled
            ? theme.colorScheme.outline.withAlpha(40)
            : (selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withAlpha(60)),
        width: selected && enabled ? 1.4 : 1.0,
      ),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected && enabled ? FontWeight.w600 : FontWeight.w500,
          color: !enabled
              ? theme.colorScheme.onSurface.withAlpha(80)
              : (selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface),
        ),
      ),
      onSelected: enabled && onSelected != null ? (_) => onSelected() : null,
    );
  }

  Widget _buildCpuSpecRow({
    required ThemeData theme,
    required AppLocalizations l10n,
    required SocDescription? soc,
    required String fallbackText,
    required int cores,
  }) {
    final String cpuDisplay;
    if (soc != null && soc.isPrecise) {
      cpuDisplay = soc.displayName;
    } else if (soc != null && soc.displayName.isNotEmpty) {
      cpuDisplay = '${soc.displayName} · $cores ${l10n.t('unit_core')}';
    } else {
      cpuDisplay =
          '${l10n.t('device_cpu_generic')} · $cores ${l10n.t('unit_core')}';
    }

    return _buildSpecRow(theme, l10n.t('device_cpu'), cpuDisplay);
  }

  Widget _buildSpecRow(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withAlpha(140),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
    String label,
    String value, {
    VoidCallback? onTap,
    bool showChevron = false,
  }) {
    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onTap != null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (showChevron && onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: rowContent,
      );
    }
    return rowContent;
  }

  void _confirmResetDefaults(BuildContext context) {
    final l10n = _settingsService.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.t('settings_reset_confirm_title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.t('settings_reset_confirm_desc'),
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: theme.colorScheme.onSurface.withAlpha(190),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white : Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await _settingsService.resetToDefaults();
              if (mounted) {
                nav.pop();
                setState(() {});
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.t('settings_reset_success'))),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            ),
            child: Text(
              l10n.t('proc_dialog_yes'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
