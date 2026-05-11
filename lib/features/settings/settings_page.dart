import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../models/music_track.dart';
import '../about/about_page.dart';
import '../home/home_controller.dart';
import '../sources/sources_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    final home = Get.find<HomeController>();
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 120),
        children: [
          Text(
            'common.settings'.tr,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 22),
          _SectionTitle(title: 'common.addMusic'.tr),
          const SizedBox(height: 10),
          _SettingsActionCard(
            icon: Icons.folder_open_rounded,
            title: 'common.localMusic'.tr,
            subtitle: 'common.importLocal'.tr,
            onTap: home.importLocal,
          ),
          SourceActionCard(
            icon: Icons.storage_rounded,
            title: 'WebDAV / NAS',
            subtitle: 'source.webdavSubtitle'.tr,
            onTap: () => showWebDavDialog(
              context: context,
              onTracksLoaded: home.addTracks,
            ),
          ),
          SourceActionCard(
            icon: Icons.live_tv_rounded,
            title: 'Emby',
            subtitle: 'source.embySubtitle'.tr,
            onTap: () => showEmbyDialog(
              context: context,
              onTracksLoaded: home.addTracks,
            ),
          ),
          SourceActionCard(
            icon: Icons.cast_connected_rounded,
            title: 'Jellyfin',
            subtitle: 'source.jellyfinSubtitle'.tr,
            onTap: () => showJellyfinDialog(
              context: context,
              onTracksLoaded: home.addTracks,
            ),
          ),
          SourceActionCard(
            icon: Icons.cloud_queue_rounded,
            title: 'Navidrome',
            subtitle: 'source.navidromeSubtitle'.tr,
            onTap: () => showNavidromeDialog(
              context: context,
              onTracksLoaded: home.addTracks,
            ),
          ),
          const SizedBox(height: 22),
          _SectionTitle(title: 'common.cache'.tr),
          const SizedBox(height: 10),
          _CacheClearCard(
            icon: Icons.storage_rounded,
            title: 'cache.clearWebDavFull'.tr,
            subtitle: 'cache.clearWebDavDesc'.tr,
            sourceType: MusicSourceType.webDav,
          ),
          _CacheClearCard(
            icon: Icons.live_tv_rounded,
            title: 'cache.clearEmbyFull'.tr,
            subtitle: 'cache.clearEmbyDesc'.tr,
            sourceType: MusicSourceType.emby,
          ),
          _CacheClearCard(
            icon: Icons.cast_connected_rounded,
            title: 'cache.clearJellyfinFull'.tr,
            subtitle: 'cache.clearJellyfinDesc'.tr,
            sourceType: MusicSourceType.jellyfin,
          ),
          _CacheClearCard(
            icon: Icons.cloud_queue_rounded,
            title: 'cache.clearNavidromeFull'.tr,
            subtitle: 'cache.clearNavidromeDesc'.tr,
            sourceType: MusicSourceType.navidrome,
          ),
          _ClearAllCacheCard(home: home),
          const SizedBox(height: 22),
          _SectionTitle(title: 'theme.mode'.tr),
          const SizedBox(height: 10),
          _ThemeModeCard(
            value: appController.themeMode.value,
            onChanged: appController.setThemeMode,
          ),
          const SizedBox(height: 12),
          _MonetCard(
            value: appController.useMonetColor.value,
            onChanged: appController.setUseMonetColor,
          ),
          const SizedBox(height: 22),
          _SectionTitle(title: 'common.language'.tr),
          const SizedBox(height: 10),
          _LanguageCard(appController: appController),
          if (!appController.hideAboutEntry.value) ...[
            const SizedBox(height: 22),
            _SectionTitle(title: 'common.about'.tr),
            const SizedBox(height: 10),
            _SettingsActionCard(
              icon: Icons.info_outline_rounded,
              title: 'common.about'.tr,
              subtitle: 'about.subtitle'.tr,
              onTap: () => showFreshAboutSheet(context),
            ),
          ],
        ],
      );
    });
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

class _SettingsActionCard extends StatelessWidget {
  const _SettingsActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Icon(icon),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _CacheClearCard extends StatelessWidget {
  const _CacheClearCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.sourceType,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final MusicSourceType sourceType;

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    return _SettingsActionCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => _confirmClearSource(context, home, sourceType, title),
    );
  }

  Future<void> _confirmClearSource(
    BuildContext context,
    HomeController home,
    MusicSourceType sourceType,
    String title,
  ) async {
    final count = home.tracks.where((track) => track.sourceType == sourceType).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text('cache.confirmSource'.trParams({'count': '$count'})),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('common.cancel'.tr)),
          FilledButton(onPressed: () => Get.back(result: true), child: Text('common.clear'.tr)),
        ],
      ),
    );
    if (ok != true) return;
    await home.clearSourceCache(sourceType);
    Get.snackbar('cache.cleared'.tr, 'cache.sourceCleared'.trParams({'title': title}), snackPosition: SnackPosition.TOP);
  }
}

class _ClearAllCacheCard extends StatelessWidget {
  const _ClearAllCacheCard({required this.home});
  final HomeController home;

  @override
  Widget build(BuildContext context) {
    return _SettingsActionCard(
      icon: Icons.delete_sweep_rounded,
      title: 'cache.clearAll'.tr,
      subtitle: 'cache.clearAllDesc'.tr,
      onTap: () => _confirmClearAll(context),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('cache.clearAll'.tr),
        content: Text('cache.confirmAll'.trParams({'count': '${home.tracks.length}'})),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('common.cancel'.tr)),
          FilledButton(onPressed: () => Get.back(result: true), child: Text('common.clear'.tr)),
        ],
      ),
    );
    if (ok != true) return;
    await home.clearCachedTracks();
    Get.snackbar('cache.cleared'.tr, 'cache.allCleared'.tr, snackPosition: SnackPosition.TOP);
  }
}

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard({required this.value, required this.onChanged});
  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ThemeOptionTile(
            title: 'theme.system'.tr,
            value: AppThemeMode.system,
            groupValue: value,
            onChanged: onChanged,
          ),
          _ThemeOptionTile(
            title: 'theme.light'.tr,
            value: AppThemeMode.light,
            groupValue: value,
            onChanged: onChanged,
          ),
          _ThemeOptionTile(
            title: 'theme.dark'.tr,
            value: AppThemeMode.dark,
            groupValue: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final AppThemeMode value;
  final AppThemeMode groupValue;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = value == groupValue;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.20) : Colors.transparent,
        child: Row(
          children: [
            RadioGroup<AppThemeMode>(
              groupValue: groupValue,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              child: Radio<AppThemeMode>(
                value: value,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.appController});

  final AppController appController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _LanguageOptionTile(
            title: 'common.chinese'.tr,
            value: AppLanguage.zh,
            groupValue: appController.language.value,
            onChanged: appController.setLanguage,
          ),
          _LanguageOptionTile(
            title: 'common.english'.tr,
            value: AppLanguage.en,
            groupValue: appController.language.value,
            onChanged: appController.setLanguage,
          ),
        ],
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final AppLanguage value;
  final AppLanguage groupValue;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = value == groupValue;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.20) : Colors.transparent,
        child: Row(
          children: [
            RadioGroup<AppLanguage>(
              groupValue: groupValue,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              child: Radio<AppLanguage>(
                value: value,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonetCard extends StatelessWidget {
  const _MonetCard({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'theme.monet'.tr,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'theme.monetDesc'.tr,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
