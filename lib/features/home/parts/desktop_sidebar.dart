part of '../home_page.dart';

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar();

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    final app = Get.find<AppController>();
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final selected = home.selectedSourceType.value;
      final sources = <MusicSourceType?>[
        null,
        MusicSourceType.localFile,
        MusicSourceType.webDav,
        MusicSourceType.emby,
        MusicSourceType.jellyfin,
        MusicSourceType.navidrome,
      ];

      return Container(
        width: 232,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.74),
          border: Border(
            right: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.52),
            ),
          ),
        ),
        child: ListView(
          // crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 18, 16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.music_note_rounded,
                        color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Fresh Music',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Material(
                color: scheme.primaryContainer.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: scheme.primaryContainer.withValues(alpha: 0.95),
                  onTap: () => _showDesktopImportMenu(context, home),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 22,
                          color: scheme.onPrimaryContainer,
                        ),
                        Text(
                          'common.addMusic'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _DesktopSectionLabel('common.library'.tr),
            for (final type in sources)
              _DesktopSidebarItem(
                icon: _sourceIconData(type),
                label: musicSourceLabel(type),
                count: _sourceCountFor(home, type),
                selected: selected == type,
                onTap: () => home.selectSourceType(type),
              ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              indent: 18,
              endIndent: 18,
              color: scheme.outlineVariant.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 12),
            _DesktopSectionLabel('common.playback'.tr),
            _DesktopActionItem(
              icon: Icons.sort_by_alpha_rounded,
              label: 'common.sort'.tr,
              onTap: () => _showSortOptions(context, home),
            ),
            _DesktopActionItem(
              icon: Icons.delete_outline_rounded,
              label: 'common.clearCache'.tr,
              onTap: home.tracks.isEmpty ? null : home.clearCachedTracks,
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              indent: 18,
              endIndent: 18,
              color: scheme.outlineVariant.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 12),
            _DesktopSectionLabel('common.settings'.tr),
            _DesktopActionItem(
              icon: Icons.language_rounded,
              label:
                  "${'common.language'.tr} · ${Get.find<AppController>().languageLabel}",
              onTap: () => _showDesktopLanguageDialog(context),
            ),
            if (!app.hideAboutEntry.value)
              _DesktopActionItem(
                icon: Icons.info_outline_rounded,
                label: 'common.about'.tr,
                onTap: () => showFreshAboutSheet(context),
              ),
            const SizedBox(height: 18),
          ],
        ),
      );
    });
  }

  Future<void> _showDesktopLanguageDialog(BuildContext context) async {
    final app = Get.find<AppController>();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Obx(() {
          return AlertDialog(
            title: Text('common.language'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DesktopLanguageOption(
                  label: 'common.chinese'.tr,
                  selected: app.language.value == AppLanguage.zh,
                  onTap: () async {
                    await app.setLanguage(AppLanguage.zh);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
                _DesktopLanguageOption(
                  label: 'common.english'.tr,
                  selected: app.language.value == AppLanguage.en,
                  onTap: () async {
                    await app.setLanguage(AppLanguage.en);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _showDesktopImportMenu(
      BuildContext context, HomeController home) async {
    final selected = await showModalBottomSheet<MusicSourceType>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final items = <MusicSourceType>[
          MusicSourceType.localFile,
          MusicSourceType.webDav,
          MusicSourceType.emby,
          MusicSourceType.jellyfin,
          MusicSourceType.navidrome,
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: ListView(
              children: [
                for (final type in items)
                  ListTile(
                    leading: Icon(_sourceIconData(type)),
                    title: Text(musicSourceLabel(type)),
                    subtitle: Text(_importSubtitleFor(type)),
                    onTap: () => Navigator.of(context).pop(type),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !context.mounted) return;
    await _runSourceImport(context, home, selected);
  }

  String _importSubtitleFor(MusicSourceType type) {
    switch (type) {
      case MusicSourceType.localFile:
        return 'common.importLocal'.tr;
      case MusicSourceType.webDav:
        return 'common.webdavImport'.tr;
      case MusicSourceType.emby:
        return 'common.embyImport'.tr;
      case MusicSourceType.jellyfin:
        return 'common.jellyfinImport'.tr;
      case MusicSourceType.navidrome:
        return 'common.navidromeImport'.tr;
      case MusicSourceType.directUrl:
        return 'source.directUrl'.tr;
    }
  }
}

class _DesktopLanguageOption extends StatelessWidget {
  const _DesktopLanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_off_rounded,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class _DesktopSectionLabel extends StatelessWidget {
  const _DesktopSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 18, 8),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _DesktopSidebarItem extends StatelessWidget {
  const _DesktopSidebarItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: selected
              ? Colors.transparent
              : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
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

class _DesktopActionItem extends StatelessWidget {
  const _DesktopActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        dense: true,
        enabled: onTap != null,
        leading: Icon(icon, color: scheme.onSurfaceVariant),
        title: Text(label),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onTap,
      ),
    );
  }
}
