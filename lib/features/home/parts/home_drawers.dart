part of '../home_page.dart';

class _SourcesEndDrawer extends StatelessWidget {
  const _SourcesEndDrawer();

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    final scheme = Theme.of(context).colorScheme;
    final width = (MediaQuery.sizeOf(context).width * 0.88)
        .clamp(304.0, 392.0)
        .toDouble();

    return Drawer(
      width: width,
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Obx(() {
          final selected = home.selectedSourceType.value;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'common.library'.tr,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'common.close'.tr,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                'common.filterOrAdd'.tr,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              _DrawerSectionTitle('common.display'.tr),
              _SourceFilterChoice(
                title: 'common.allMusic'.tr,
                icon: Icons.library_music_rounded,
                count: home.tracks.length,
                selected: selected == null,
                onTap: () => home.selectSourceType(null),
              ),
              _SourceFilterChoice(
                title: 'common.localMusic'.tr,
                icon: Icons.phone_android_rounded,
                count: _sourceCount(home, MusicSourceType.localFile),
                selected: selected == MusicSourceType.localFile,
                onTap: () => home.selectSourceType(MusicSourceType.localFile),
              ),
              _SourceFilterChoice(
                title: 'common.nasMusic'.tr,
                icon: Icons.storage_rounded,
                count: _sourceCount(home, MusicSourceType.webDav),
                selected: selected == MusicSourceType.webDav,
                onTap: () => home.selectSourceType(MusicSourceType.webDav),
              ),
              _SourceFilterChoice(
                title: 'source.emby'.tr,
                icon: Icons.live_tv_rounded,
                count: _sourceCount(home, MusicSourceType.emby),
                selected: selected == MusicSourceType.emby,
                onTap: () => home.selectSourceType(MusicSourceType.emby),
              ),
              _SourceFilterChoice(
                title: 'source.jellyfin'.tr,
                icon: Icons.cast_connected_rounded,
                count: _sourceCount(home, MusicSourceType.jellyfin),
                selected: selected == MusicSourceType.jellyfin,
                onTap: () => home.selectSourceType(MusicSourceType.jellyfin),
              ),
              _SourceFilterChoice(
                title: 'source.navidrome'.tr,
                icon: Icons.cloud_queue_rounded,
                count: _sourceCount(home, MusicSourceType.navidrome),
                selected: selected == MusicSourceType.navidrome,
                onTap: () => home.selectSourceType(MusicSourceType.navidrome),
              ),
              const SizedBox(height: 22),
              _DrawerSectionTitle('common.addMusic'.tr),
              _SourceActionTile(
                icon: Icons.audio_file_rounded,
                title: 'common.localMusic'.tr,
                subtitle: 'drawer.addLocalSubtitle'.tr,
                onTap: () => _closeThen(context, home.importLocal),
              ),
              _SourceActionTile(
                icon: Icons.storage_rounded,
                title: 'WebDAV / NAS',
                subtitle: 'drawer.webdavSubtitle'.tr,
                onTap: () => _closeThen(context, () {
                  return showWebDavDialog(
                    context: context,
                    onTracksLoaded: (tracks) => home.replaceSourceTracks(
                        MusicSourceType.webDav, tracks),
                  );
                }),
              ),
              _SourceActionTile(
                icon: Icons.live_tv_rounded,
                title: 'Emby',
                subtitle: 'drawer.embySubtitle'.tr,
                onTap: () => _closeThen(context, () {
                  return showEmbyDialog(
                    context: context,
                    onTracksLoaded: (tracks) =>
                        home.replaceSourceTracks(MusicSourceType.emby, tracks),
                  );
                }),
              ),
              _SourceActionTile(
                icon: Icons.cast_connected_rounded,
                title: 'Jellyfin',
                subtitle: 'drawer.jellyfinSubtitle'.tr,
                onTap: () => _closeThen(context, () {
                  return showJellyfinDialog(
                    context: context,
                    onTracksLoaded: (tracks) => home.replaceSourceTracks(
                        MusicSourceType.jellyfin, tracks),
                  );
                }),
              ),
              _SourceActionTile(
                icon: Icons.cloud_queue_rounded,
                title: 'Navidrome',
                subtitle: 'drawer.navidromeSubtitle'.tr,
                onTap: () => _closeThen(context, () {
                  return showNavidromeDialog(
                    context: context,
                    onTracksLoaded: (tracks) => home.replaceSourceTracks(
                        MusicSourceType.navidrome, tracks),
                  );
                }),
              ),
            ],
          );
        }),
      ),
    );
  }

  int _sourceCount(HomeController home, MusicSourceType type) {
    return home.tracks.where((track) => track.sourceType == type).length;
  }

  Future<void> _closeThen(
      BuildContext context, Future<void> Function() action) async {
    Navigator.of(context).maybePop();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await action();
  }
}

class _DrawerSectionTitle extends StatelessWidget {
  const _DrawerSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _SourceFilterChoice extends StatelessWidget {
  const _SourceFilterChoice({
    required this.title,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : icon,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceActionTile extends StatelessWidget {
  const _SourceActionTile({
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          height: 1.28,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeDrawer extends StatelessWidget {
  const _ThemeDrawer();

  @override
  Widget build(BuildContext context) {
    final app = Get.find<AppController>();
    final home = Get.find<HomeController>();
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Obx(() {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
            children: [
              Text(
                'common.settings'.tr,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 24),
              _DrawerSectionTitle('theme.mode'.tr),
              _DrawerChoice(
                title: 'theme.system'.tr,
                icon: Icons.phone_android_rounded,
                selected: app.themeMode.value == AppThemeMode.system,
                onTap: () => app.setThemeMode(AppThemeMode.system),
              ),
              _DrawerChoice(
                title: 'theme.light'.tr,
                icon: Icons.light_mode_rounded,
                selected: app.themeMode.value == AppThemeMode.light,
                onTap: () => app.setThemeMode(AppThemeMode.light),
              ),
              _DrawerChoice(
                title: 'theme.dark'.tr,
                icon: Icons.dark_mode_rounded,
                selected: app.themeMode.value == AppThemeMode.dark,
                onTap: () => app.setThemeMode(AppThemeMode.dark),
              ),
              const SizedBox(height: 16),
              Material(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  value: app.useMonetColor.value,
                  onChanged: app.setUseMonetColor,
                  title: Text('theme.monet'.tr),
                  subtitle: Text('theme.monetDesc'.tr),
                  secondary: const Icon(Icons.palette_rounded),
                ),
              ),
              const SizedBox(height: 24),
              _DrawerSectionTitle('common.language'.tr),
              _DrawerChoice(
                title: 'common.chinese'.tr,
                icon: Icons.translate_rounded,
                selected: app.language.value == AppLanguage.zh,
                onTap: () => app.setLanguage(AppLanguage.zh),
              ),
              _DrawerChoice(
                title: 'common.english'.tr,
                icon: Icons.language_rounded,
                selected: app.language.value == AppLanguage.en,
                onTap: () => app.setLanguage(AppLanguage.en),
              ),
              if (!app.hideAboutEntry.value) ...[
                const SizedBox(height: 16),
                _DrawerChoice(
                  title: 'common.about'.tr,
                  icon: Icons.info_outline_rounded,
                  selected: false,
                  onTap: () => showFreshAboutSheet(context),
                ),
              ],
              const SizedBox(height: 24),
              _DrawerSectionTitle('common.cache'.tr),
              _DrawerCacheAction(
                icon: Icons.storage_rounded,
                title: 'cache.clearWebDav'.tr,
                count: _sourceCount(home, MusicSourceType.webDav),
                onTap: () => _confirmClearSource(
                    context, home, MusicSourceType.webDav, 'NAS / WebDAV'),
              ),
              _DrawerCacheAction(
                icon: Icons.live_tv_rounded,
                title: 'cache.clearEmby'.tr,
                count: _sourceCount(home, MusicSourceType.emby),
                onTap: () => _confirmClearSource(
                    context, home, MusicSourceType.emby, 'Emby'),
              ),
              _DrawerCacheAction(
                icon: Icons.cast_connected_rounded,
                title: 'cache.clearJellyfin'.tr,
                count: _sourceCount(home, MusicSourceType.jellyfin),
                onTap: () => _confirmClearSource(
                    context, home, MusicSourceType.jellyfin, 'Jellyfin'),
              ),
              _DrawerCacheAction(
                icon: Icons.cloud_queue_rounded,
                title: 'cache.clearNavidrome'.tr,
                count: _sourceCount(home, MusicSourceType.navidrome),
                onTap: () => _confirmClearSource(
                    context, home, MusicSourceType.navidrome, 'Navidrome'),
              ),
              _DrawerCacheAction(
                icon: Icons.delete_sweep_rounded,
                title: 'cache.clearAll'.tr,
                count: home.tracks.length,
                danger: true,
                onTap: () => _confirmClearAll(context, home),
              ),
            ],
          );
        }),
      ),
    );
  }

  int _sourceCount(HomeController home, MusicSourceType type) {
    return home.tracks.where((track) => track.sourceType == type).length;
  }

  Future<void> _confirmClearSource(
    BuildContext context,
    HomeController home,
    MusicSourceType type,
    String label,
  ) async {
    final count = _sourceCount(home, type);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('cache.clearSourceTitle'.trParams({'label': label})),
        content: Text('cache.confirmSource'.trParams({'count': '$count'})),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('common.cancel'.tr)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('common.clear'.tr)),
        ],
      ),
    );
    if (ok != true) return;
    await home.clearSourceCache(type);
    if (context.mounted) {
      Navigator.of(context).maybePop();
    }
    Get.snackbar('cache.cleared'.tr, 'cache.sourceCleared'.trParams({'title': label}), snackPosition: SnackPosition.TOP);
  }

  Future<void> _confirmClearAll(
      BuildContext context, HomeController home) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('cache.clearAll'.tr),
        content: Text('cache.confirmAll'.trParams({'count': '${home.tracks.length}'})),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('common.cancel'.tr)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('common.clear'.tr)),
        ],
      ),
    );
    if (ok != true) return;
    for (final type in MusicSourceType.values) {
      if (type != MusicSourceType.localFile &&
          type != MusicSourceType.directUrl) {
        await home.clearSourceCache(type);
      }
    }
    await home.clearCachedTracks();
    if (context.mounted) {
      Navigator.of(context).maybePop();
    }
    Get.snackbar('cache.cleared'.tr, 'cache.allCleared'.tr, snackPosition: SnackPosition.TOP);
  }
}

class _DrawerCacheAction extends StatelessWidget {
  const _DrawerCacheAction({
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : scheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: danger ? scheme.error : scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerChoice extends StatelessWidget {
  const _DrawerChoice({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_rounded, color: scheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
