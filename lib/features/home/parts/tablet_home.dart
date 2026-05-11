part of '../home_page.dart';

class _TabletHomeShell extends StatelessWidget {
  const _TabletHomeShell();

  @override
  Widget build(BuildContext context) {
    final player = Get.find<PlayerController>();
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 920;

    return Scaffold(
      backgroundColor: scheme.surface,
      endDrawer: const _SourcesEndDrawer(),
      endDrawerEnableOpenDragGesture: true,
      extendBody: true,
      body: ColoredBox(
        color: scheme.surface,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Builder(
                builder: (context) {
                  return Row(
                    children: [
                      const _TabletSourceRail(),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 94),
                          child: _TabletLibraryPanel(
                            onOpenSources: () =>
                                Scaffold.of(context).openEndDrawer(),
                          ),
                        ),
                      ),
                      if (wide)
                        const SizedBox(
                          width: 300,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(0, 8, 12, 94),
                            child: _DesktopNowPlayingPanel(compact: true),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(),
            ),
            Obx(() {
              final hasTrack = player.currentTrack != null;
              if (!hasTrack) return const SizedBox.shrink();
              return const Positioned.fill(child: PlayerPage());
            }),
          ],
        ),
      ),
    );
  }
}
class _TabletSourceRail extends StatelessWidget {
  const _TabletSourceRail();

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final selected = home.selectedSourceType.value;
      final items = <MusicSourceType?>[
        null,
        MusicSourceType.localFile,
        MusicSourceType.webDav,
        MusicSourceType.emby,
        MusicSourceType.jellyfin,
        MusicSourceType.navidrome,
      ];

      return Container(
        width: 96,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer.withValues(alpha: 0.55),
          border: Border(
            right: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 14),
            IconButton.filledTonal(
              tooltip: 'common.addMusic'.tr,
              onPressed: () => Scaffold.maybeOf(context)?.openEndDrawer(),
              icon: const Icon(Icons.add_rounded),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final type = items[index];
                  final active = selected == type;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Tooltip(
                      message: musicSourceLabel(type),
                      child: Material(
                        color: active ? scheme.primaryContainer : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => home.selectSourceType(type),
                          child: SizedBox(
                            height: 58,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _sourceIconData(type),
                                  color: active
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_sourceCountFor(home, type)}',
                                  style: TextStyle(
                                    color: active
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _TabletLibraryPanel extends StatelessWidget {
  const _TabletLibraryPanel({required this.onOpenSources});

  final VoidCallback onOpenSources;

  @override
  Widget build(BuildContext context) {
    return _DesktopLibraryPanel(
      compact: true,
      rounded: true,
      onOpenSources: onOpenSources,
    );
  }
}
