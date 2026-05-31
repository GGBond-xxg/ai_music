import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/music_track.dart';
import '../providers/spotify_provider.dart';
import '../providers/theme_provider.dart';
import '../services/app_locale_controller.dart';
import '../services/language_service.dart';
import '../services/ui_texts.dart';
import '../utils/responsive.dart';

const double kDefaultPadding = 16.0;
const double kElementSpacing = 16.0;
const double kSmallSpacing = 8.0;

class AboutLinkItem {
  const AboutLinkItem({
    required this.name,
    required this.icon,
    required this.url,
    this.subtitle,
  });

  final String name;
  final IconData icon;
  final String url;
  final String? subtitle;
}

class DonateItem {
  const DonateItem({
    required this.name,
    required this.icon,
    required this.address,
    this.subtitle,
  });

  final String name;
  final IconData icon;
  final String address;
  final String? subtitle;
}

/// 关于我们：技术栈 / 开源项目 / 相关链接
/// 以后要新增内容，只需要往这里加一条 AboutLinkItem。
const List<AboutLinkItem> aboutLinks = [
  AboutLinkItem(
    name: 'Flutter',
    subtitle: 'Cross-platform UI framework',
    icon: Icons.flutter_dash,
    url: 'https://flutter.dev',
  ),
  AboutLinkItem(
    name: 'Dart',
    subtitle: 'Programming language',
    icon: Icons.code_rounded,
    url: 'https://dart.dev',
  ),
  AboutLinkItem(
    name: 'ChatGPT',
    subtitle: 'AI development assistant',
    icon: Icons.smart_toy_outlined,
    url: 'https://chatgpt.com',
  ),
  AboutLinkItem(
    name: 'Media_kit',
    subtitle: 'Audio playback engine',
    icon: Icons.graphic_eq_rounded,
    url: 'https://pub.dev/packages/media_kit',
  ),
  AboutLinkItem(
    name: 'Spotoolfy Github',
    subtitle: 'Inspired by the spotoolfy project',
    icon: Icons.web,
    url: 'https://github.com/p2o51/spotoolfy_flutter',
  ),
  AboutLinkItem(
    name: 'Spotoolfy',
    subtitle: 'Spotoolfy official website',
    icon: Icons.web_asset,
    url: 'https://spotoolfy.gojyuplus.com/',
  ),
  AboutLinkItem(
    name: 'My GitHub',
    subtitle: 'Some small pieces written with AI.',
    icon: Icons.edit_document,
    url: 'https://github.com/GGBond-xxg',
  ),
];

/// 赞助地址
/// 以后要新增 BTC / SOL / ETH / USDT 等，直接往这里加一条 DonateItem。
const List<DonateItem> donateItems = [
  DonateItem(
    name: 'Tron Network / TRC20',
    icon: Icons.monetization_on,
    address: 'TXnGST3Qa1qGeFGcEivbdwtUBrWgNKeHdz',
  ),
  DonateItem(
    name: 'Ethereum Network / EVN',
    icon: Icons.wallet_rounded,
    address: '0x3732e8155cEd9Bd9C89a5bb8b197DC063570952B',
  ),
  DonateItem(
    name: 'Solana Network / SOL',
    icon: Icons.account_balance_wallet_rounded,
    address: '4YB3SxN4j7ADm6ZxdCXbrsQq5HJbCewwBTYXN2rEXGYp',
  ),
  DonateItem(
    name: 'Bitcoin Network/ BTC',
    icon: Icons.currency_bitcoin_rounded,
    address: 'bc1q3v73dxmd805t0x4nkr4mswhvrk4ragt7e0f5g5',
  ),
];

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final t = UiTexts.of(context);

    return Container(
      padding: ResponsivePadding.horizontal(
        context,
        pageType: ResponsivePageType.modal,
      ),
      width: double.infinity,
      child: SafeArea(
        child: ResponsivePageContainer(
          pageType: ResponsivePageType.modal,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: kDefaultPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: kSmallSpacing),
                      child: Text(
                        t.settings,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.primary.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: t.close,
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kElementSpacing),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Material(
                    color: colorScheme.surfaceContainerLowest,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: const [
                        _AutoPlaySection(),
                        SizedBox(height: 14),
                        _ThemeSection(),
                        SizedBox(height: 14),
                        _LanguageSection(),
                        SizedBox(height: 14),
                        _ClearMusicSection(),
                        SizedBox(height: 14),
                        _AboutSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.children,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: Icon(icon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
              if (children.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...children,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoPlaySection extends StatelessWidget {
  const _AutoPlaySection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SpotifyProvider>();
    final t = UiTexts.of(context);
    return _SettingsCard(
      icon: Icons.play_circle_outline_rounded,
      title: t.playback,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: provider.autoPlayOnOpen,
          onChanged: provider.libraryTracks.isEmpty
              ? null
              : (value) => provider.setAutoPlayOnOpen(value),
          title: Text(t.autoPlayOnOpen),
          subtitle: Text(
            provider.libraryTracks.isEmpty
                ? t.autoPlayDisabledNoMusic
                : t.autoPlaySubtitle,
          ),
        ),
      ],
    );
  }
}

class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    final t = UiTexts.of(context);
    return _SettingsCard(
      icon: Icons.dark_mode_outlined,
      title: t.themeMode,
      children: [
        _RadioTile<MusicThemeMode>(
          value: MusicThemeMode.system,
          groupValue: provider.themeMode,
          title: t.followSystem,
          icon: Icons.brightness_auto_rounded,
          onChanged: (mode) => provider.setThemeMode(mode, context),
        ),
        _RadioTile<MusicThemeMode>(
          value: MusicThemeMode.light,
          groupValue: provider.themeMode,
          title: t.lightMode,
          icon: Icons.light_mode_outlined,
          onChanged: (mode) => provider.setThemeMode(mode, context),
        ),
        _RadioTile<MusicThemeMode>(
          value: MusicThemeMode.dark,
          groupValue: provider.themeMode,
          title: t.darkMode,
          icon: Icons.nights_stay_outlined,
          onChanged: (mode) => provider.setThemeMode(mode, context),
        ),
      ],
    );
  }
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context) {
    final t = UiTexts.of(context);
    return ValueListenableBuilder<Locale?>(
      valueListenable: appLocaleNotifier,
      builder: (context, selectedLocale, _) {
        return _SettingsCard(
          icon: Icons.language_rounded,
          title: t.languageSwitch,
          children: [
            _RadioTile<String>(
              value: 'system',
              groupValue:
                  selectedLocale == null ? 'system' : selectedLocale.toString(),
              title: t.followSystem,
              icon: Icons.phone_android_rounded,
              onChanged: (_) async {
                await LanguageService.setAppLocale(null);
                appLocaleNotifier.value = null;
              },
            ),
            for (final locale in LanguageService.supportedLocales)
              _RadioTile<String>(
                value: locale.toString(),
                groupValue: selectedLocale == null
                    ? 'system'
                    : selectedLocale.toString(),
                title: LanguageService.getLanguageDisplayName(locale),
                icon: Icons.translate_rounded,
                onChanged: (_) async {
                  await LanguageService.setAppLocale(locale);
                  appLocaleNotifier.value = locale;
                },
              ),
            const SizedBox(height: 4),
            Text(
              '${t.currentAppName}: ${appNameForLocale(selectedLocale ?? Localizations.localeOf(context))}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _ClearMusicSection extends StatelessWidget {
  const _ClearMusicSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SpotifyProvider>();
    final t = UiTexts.of(context);
    final sourceTypes = provider.availableSourceTypes;
    if (sourceTypes.isEmpty) return const SizedBox.shrink();

    return _SettingsCard(
      icon: Icons.cleaning_services_outlined,
      title: t.clearMusicCache,
      children: [
        for (final sourceType in sourceTypes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_iconForSource(sourceType)),
            title: Text(t.clearSourceMusic(t.sourceName(sourceType))),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _confirmClearSource(context, sourceType),
          ),
      ],
    );
  }

  IconData _iconForSource(MusicSourceType sourceType) {
    switch (sourceType) {
      case MusicSourceType.localFile:
        return Icons.folder_rounded;
      case MusicSourceType.webDav:
        return Icons.storage_rounded;
      case MusicSourceType.emby:
      case MusicSourceType.jellyfin:
        return Icons.cast_rounded;
      case MusicSourceType.navidrome:
        return Icons.cloud_queue_rounded;
      case MusicSourceType.directUrl:
        return Icons.link_rounded;
    }
  }

  Future<void> _confirmClearSource(
    BuildContext context,
    MusicSourceType sourceType,
  ) async {
    final t = UiTexts.of(context);
    final provider = context.read<SpotifyProvider>();
    final sourceName = t.sourceName(sourceType);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.clearSourceConfirmTitle),
        content: Text(t.clearSourceConfirmMessage(sourceName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.clear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await provider.clearMusicBySource(sourceType);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.clearedSource(sourceName))),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final t = UiTexts.of(context);
    return _SettingsCard(
      icon: Icons.info_outline_rounded,
      title: t.aboutUs,
      onTap: () => _showAboutDialog(context),
      children: const [],
    );
  }

  void _showAboutDialog(BuildContext context) {
    final t = UiTexts.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(t.aboutDialogTitle),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          content: const _AboutDialogContent(),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.close),
            ),
          ],
        );
      },
    );
  }
}

class _AboutDialogContent extends StatelessWidget {
  const _AboutDialogContent();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.88,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AboutHeaderCard(scheme: scheme),
            const SizedBox(height: 18),
            _SectionTitle(
              title: UiTexts.of(context).openSourceSection,
              icon: Icons.code_rounded,
            ),
            const SizedBox(height: 8),
            for (final item in aboutLinks) ...[
              _AboutLinkTile(item: item),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 18),
            _SectionTitle(
              title: UiTexts.of(context).donateSection,
              icon: Icons.volunteer_activism_rounded,
            ),
            const SizedBox(height: 8),
            Text(
              UiTexts.of(context).donateDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            for (final item in donateItems) ...[
              _DonateTile(item: item),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _AboutHeaderCard extends StatelessWidget {
  const _AboutHeaderCard({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.music_note_rounded,
              size: 30,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appNameForContext(context),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  UiTexts.of(context).aboutAppTagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _AboutLinkTile extends StatelessWidget {
  const _AboutLinkTile({required this.item});

  final AboutLinkItem item;

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null) return;

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UiTexts.of(context).openFailed(item.name))),
      );
    }
  }


  String? _localizedSubtitle(BuildContext context) {
    final t = UiTexts.of(context);
    switch (item.name) {
      case 'Flutter':
        return t.choose(
          en: 'Cross-platform UI framework',
          zh: '跨平台 UI 框架',
          zhTw: '跨平台 UI 框架',
          ja: 'クロスプラットフォーム UI フレームワーク',
        );
      case 'Dart':
        return t.choose(
          en: 'Programming language',
          zh: '编程语言',
          zhTw: '程式語言',
          ja: 'プログラミング言語',
        );
      case 'ChatGPT':
        return t.choose(
          en: 'AI development assistant',
          zh: 'AI 开发助手',
          zhTw: 'AI 開發助手',
          ja: 'AI 開発アシスタント',
        );
      case 'Media_kit':
        return t.choose(
          en: 'Audio playback engine',
          zh: '音频播放引擎',
          zhTw: '音訊播放引擎',
          ja: 'オーディオ再生エンジン',
        );
      case 'Spotoolfy Github':
        return t.choose(
          en: 'Inspired by the spotoolfy project',
          zh: '灵感来自 spotoolfy 项目',
          zhTw: '靈感來自 spotoolfy 專案',
          ja: 'spotoolfy プロジェクトから着想',
        );
      case 'Spotoolfy':
        return t.choose(
          en: 'Spotoolfy official website',
          zh: 'Spotoolfy 官方网站',
          zhTw: 'Spotoolfy 官方網站',
          ja: 'Spotoolfy 公式サイト',
        );
      case 'My GitHub':
        return t.choose(
          en: 'Some small pieces written with AI.',
          zh: '一些用 AI 写的小作品。',
          zhTw: '一些用 AI 寫的小作品。',
          ja: 'AI で作った小さな作品集。',
        );
    }
    return item.subtitle;
  }

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: item.url));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(UiTexts.of(context).linkCopied(item.name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = _localizedSubtitle(context);

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openUrl(context),
        onLongPress: () => _copyUrl(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _IconBox(
                icon: item.icon,
                color: scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: UiTexts.of(context).copyLink,
                onPressed: () => _copyUrl(context),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
              const Icon(Icons.open_in_new_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonateTile extends StatelessWidget {
  const _DonateTile({required this.item});

  final DonateItem item;

  Future<void> _copyAddress(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: item.address));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(UiTexts.of(context).addressCopied(item.name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _IconBox(
              icon: item.icon,
              color: scheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (item.subtitle != null &&
                      item.subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    item.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: UiTexts.of(context).copyAddress,
              onPressed: () => _copyAddress(context),
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 23,
        color: color,
      ),
    );
  }
}

class _RadioTile<T> extends StatelessWidget {
  const _RadioTile({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.icon,
    required this.onChanged,
  });

  final T value;
  final T groupValue;
  final String title;
  final IconData icon;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.50)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onChanged(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title)),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
