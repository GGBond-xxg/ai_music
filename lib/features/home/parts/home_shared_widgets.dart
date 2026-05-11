part of '../home_page.dart';

Future<void> _showSortOptions(BuildContext context, HomeController home) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final media = MediaQuery.sizeOf(context);
      final isLandscape = media.width > media.height;
      final maxHeight = media.height * (isLandscape ? 0.86 : 0.72);

      return Obx(() {
        final current = home.sortMode.value;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, 0, 18, isLandscape ? 14 : 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'sort.title'.tr,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'sort.desc'.tr,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final mode in TrackSortMode.values)
                    _SortOptionTile(
                      mode: mode,
                      selected: current == mode,
                      dense: isLandscape,
                      onTap: () async {
                        await home.setSortMode(mode);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      });
    },
  );
}

class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.mode,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  final TrackSortMode mode;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 6 : 8),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 9 : 13),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.sort_rounded,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                      fontWeight: FontWeight.w900,
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

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary({
    required this.totalCount,
    required this.visibleCount,
    required this.selected,
  });

  final int totalCount;
  final int visibleCount;
  final MusicSourceType? selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = selected == null ? 'common.allMusic'.tr : musicSourceLabel(selected);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  totalCount == visibleCount
                      ? 'home.visibleCount'.trParams({'count': '$visibleCount'})
                      : 'home.visibleOfTotal'.trParams({'visible': '$visibleCount', 'total': '$totalCount'}),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    super.key,
    required this.track,
    required this.index,
    required this.isCurrent,
    required this.isPlaying,
    required this.enableNetworkCover,
    this.deferUncachedCoverListenable,
    required this.onTap,
  });

  final MusicTrack track;
  final int index;
  final bool isCurrent;
  final bool isPlaying;
  final bool enableNetworkCover;
  final ValueListenable<bool>? deferUncachedCoverListenable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);

    Widget cover(bool defer) => TrackCover(
          track: track,
          size: 52,
          borderRadius: 14,
          enableNetwork: enableNetworkCover,
          deferUncached: defer,
        );

    final coverWidget = deferUncachedCoverListenable == null
        ? cover(false)
        : ValueListenableBuilder<bool>(
            valueListenable: deferUncachedCoverListenable!,
            builder: (_, defer, __) => cover(defer),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isCurrent
                ? scheme.primaryContainer.withValues(alpha: 0.52)
                : Colors.transparent,
            borderRadius: radius,
          ),
          child: SizedBox(
            height: 68,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  coverWidget,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                track.artist ??
                                    musicSourceLabel(track.sourceType),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent
                                      ? scheme.onPrimaryContainer
                                          .withValues(alpha: 0.74)
                                      : scheme.onSurfaceVariant,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _SourcePill(
                              type: track.sourceType,
                              compact: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: isCurrent
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.type, this.compact = false});

  final MusicSourceType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 2 : 5,
        ),
        child: Text(
          _compactSourceLabel(type),
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class _SourceFilterBar extends StatelessWidget {
  const _SourceFilterBar({required this.home});
  final HomeController home;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sources = home.availableSourceTypes;
    final selected = home.selectedSourceType.value;
    final tabs = <MusicSourceType?>[null, ...sources];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = tabs[index];
          final active = selected == type;
          return FilterChip(
            label: Text(musicSourceLabel(type)),
            selected: active,
            onSelected: (_) => home.selectSourceType(type),
            showCheckmark: false,
            avatar: Icon(
              active ? Icons.check_rounded : _sourceIcon(type),
              size: 18,
              color:
                  active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
            labelStyle: TextStyle(
              color:
                  active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
            selectedColor: scheme.primaryContainer,
            backgroundColor: scheme.surfaceContainerHigh,
            side: BorderSide(
              color: active
                  ? scheme.primary.withValues(alpha: 0.32)
                  : scheme.outline.withValues(alpha: 0.12),
            ),
          );
        },
      ),
    );
  }

  IconData _sourceIcon(MusicSourceType? type) {
    switch (type) {
      case null:
        return Icons.library_music_rounded;
      case MusicSourceType.localFile:
        return Icons.phone_android_rounded;
      case MusicSourceType.webDav:
        return Icons.storage_rounded;
      case MusicSourceType.emby:
        return Icons.live_tv_rounded;
      case MusicSourceType.jellyfin:
        return Icons.cast_connected_rounded;
      case MusicSourceType.navidrome:
        return Icons.cloud_queue_rounded;
      case MusicSourceType.directUrl:
        return Icons.link_rounded;
    }
  }
}


String _compactSourceLabel(MusicSourceType type) {
  final label = musicSourceLabel(type);
  if (Get.locale?.languageCode == 'zh') {
    return label.replaceAll('音乐', '');
  }
  return label.replaceAll(' Music', '').replaceAll('Music', '').trim();
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onOpenSources});
  final VoidCallback onOpenSources;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music_rounded, size: 76, color: scheme.primary),
            const SizedBox(height: 18),
            Text(
              'home.emptyTitle'.tr,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'home.emptyBody'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                height: 1.42,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onOpenSources,
              icon: const Icon(Icons.add_rounded),
              label: Text('common.addSource'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySource extends StatelessWidget {
  const _EmptySource({required this.selected});
  final MusicSourceType? selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'home.sourceEmpty'.trParams({'source': musicSourceLabel(selected)}),
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
