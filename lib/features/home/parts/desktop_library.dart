part of '../home_page.dart';

class _DesktopLibraryPanel extends StatefulWidget {
  const _DesktopLibraryPanel({
    this.compact = false,
    this.rounded = false,
    this.onOpenSources,
  });

  final bool compact;
  final bool rounded;
  final VoidCallback? onOpenSources;

  @override
  State<_DesktopLibraryPanel> createState() => _DesktopLibraryPanelState();
}

class _DesktopLibraryPanelState extends State<_DesktopLibraryPanel> {
  final ScrollController _scrollController = ScrollController();
  Timer? _coverLoadDelayTimer;
  bool _deferUncachedCovers = false;

  @override
  void dispose() {
    _coverLoadDelayTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      _coverLoadDelayTimer?.cancel();
      if (!_deferUncachedCovers) {
        setState(() => _deferUncachedCovers = true);
      }
      _coverLoadDelayTimer = Timer(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        if (_deferUncachedCovers) {
          setState(() => _deferUncachedCovers = false);
        }
      });
    }

    if (notification is ScrollEndNotification) {
      _coverLoadDelayTimer?.cancel();
      _coverLoadDelayTimer = Timer(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        if (_deferUncachedCovers) {
          setState(() => _deferUncachedCovers = false);
        }
      });
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    final player = Get.find<PlayerController>();
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final visibleTracks = home.visibleTracks;
      final allTracks = home.sortedTracks;
      final selected = home.selectedSourceType.value;
      final title = selected == null ? 'common.allMusic'.tr : musicSourceLabel(selected);

      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.compact ? 18 : 28,
              widget.compact ? 16 : 24,
              widget.compact ? 18 : 28,
              10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        allTracks.length == visibleTracks.length
                            ? 'home.visibleCount'.trParams({'count': '${visibleTracks.length}'})
                            : 'home.visibleOfTotal'.trParams({'visible': '${visibleTracks.length}', 'total': '${allTracks.length}'}),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.compact)
                  IconButton(
                    tooltip: 'common.search'.tr,
                    onPressed: allTracks.isEmpty
                        ? null
                        : () => _openSearch(context, allTracks),
                    icon: const Icon(Icons.search_rounded),
                  ),
                IconButton(
                  tooltip: 'common.sort'.tr,
                  onPressed: allTracks.isEmpty
                      ? null
                      : () => _showSortOptions(context, home),
                  icon: const Icon(Icons.sort_by_alpha_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.compact ? 18 : 24,
              0,
              widget.compact ? 18 : 24,
              8,
            ),
            child: _DesktopTableHeader(compact: widget.compact),
          ),
          Expanded(
            child: allTracks.isEmpty
                ? _EmptyLibrary(
                    onOpenSources: widget.onOpenSources ??
                        () => _runSourceImport(
                              context,
                              home,
                              MusicSourceType.localFile,
                            ),
                  )
                : visibleTracks.isEmpty
                    ? _EmptySource(selected: selected)
                    : NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                            widget.compact ? 14 : 24,
                            0,
                            widget.compact ? 14 : 24,
                            14,
                          ),
                          cacheExtent: 72 * 6,
                          itemCount: visibleTracks.length,
                          itemBuilder: (context, index) {
                            final track = visibleTracks[index];
                            return Obx(() {
                              final current = player.currentTrack;
                              final isCurrent = current?.id == track.id;
                              final isPlaying =
                                  isCurrent && player.isPlayingNow.value;
                              return _DesktopTrackRow(
                                key: ValueKey('desktop-track-${track.id}'),
                                track: track,
                                index: index,
                                compact: widget.compact,
                                isCurrent: isCurrent,
                                isPlaying: isPlaying,
                                deferUncachedCover: _deferUncachedCovers,
                                onTap: () {
                                  final playQueue =
                                      List<MusicTrack>.of(visibleTracks);
                                  final playIndex = playQueue.indexWhere(
                                    (item) => item.id == track.id,
                                  );
                                  DebugTrace.instance.log(
                                    'UI_CLICK',
                                    'desktop rowIndex=$index playIndex=$playIndex visible=${visibleTracks.length} track=${DebugTrace.instance.track(track)}',
                                  );
                                  unawaited(player.playFromQueueSnapshot(
                                    playQueue,
                                    initialIndex:
                                        playIndex < 0 ? index : playIndex,
                                  ));
                                },
                              );
                            });
                          },
                        ),
                      ),
          ),
        ],
      );

      if (!widget.rounded) return content;

      return Material(
        color: scheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    });
  }

  void _openSearch(BuildContext context, List<MusicTrack> tracks) {
    if (tracks.isEmpty) return;
    Get.to<void>(
      () => _MusicSearchPage(tracks: tracks),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }
}

class _DesktopTableHeader extends StatelessWidget {
  const _DesktopTableHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      color: scheme.onSurfaceVariant,
      fontSize: 12,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.2,
    );
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
              width: compact ? 38 : 44,
              child: Text(
                '#',
                style: style,
                textAlign: TextAlign.center,
              )),
          Text('Title', style: style),
          const SizedBox(width: 28),
          Expanded(flex: compact ? 5 : 6, child: SizedBox()),
          if (!compact) Expanded(flex: 3, child: Text('Artist', style: style)),
          SizedBox(
              width: compact ? 74 : 110, child: Text('Date', style: style)),
          const SizedBox(width: 42),
        ],
      ),
    );
  }
}

class _DesktopTrackRow extends StatelessWidget {
  const _DesktopTrackRow({
    super.key,
    required this.track,
    required this.index,
    required this.compact,
    required this.isCurrent,
    required this.isPlaying,
    required this.deferUncachedCover,
    required this.onTap,
  });

  final MusicTrack track;
  final int index;
  final bool compact;
  final bool isCurrent;
  final bool isPlaying;
  final bool deferUncachedCover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(14);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isCurrent
            ? scheme.primaryContainer.withValues(alpha: 0.72)
            : Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: isCurrent
              ? Colors.transparent
              : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          onTap: onTap,
          child: SizedBox(
            height: 62,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: compact ? 38 : 44,
                    child: Center(
                      child: isPlaying
                          ? Icon(Icons.graphic_eq_rounded,
                              color: scheme.primary, size: 20)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCurrent
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  TrackCover(
                    track: track,
                    size: 44,
                    borderRadius: 10,
                    deferUncached: deferUncachedCover,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: compact ? 5 : 6,
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
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                          ),
                        ),
                        if (compact) ...[
                          const SizedBox(height: 3),
                          Text(
                            track.artist ?? musicSourceLabel(track.sourceType),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent
                                  ? scheme.onPrimaryContainer
                                      .withValues(alpha: 0.74)
                                  : scheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!compact)
                    Expanded(
                      flex: 3,
                      child: Text(
                        track.artist ?? 'common.unknownArtist'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent
                              ? scheme.onPrimaryContainer
                                  .withValues(alpha: 0.78)
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: compact ? 74 : 110,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _SourcePill(type: track.sourceType, compact: true),
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: isCurrent
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
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
