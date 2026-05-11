part of '../home_page.dart';

class _GramophoneLibraryView extends StatefulWidget {
  const _GramophoneLibraryView({
    required this.onOpenDrawer,
    required this.onOpenSources,
  });

  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenSources;

  @override
  State<_GramophoneLibraryView> createState() => _GramophoneLibraryViewState();
}

class _GramophoneLibraryViewState extends State<_GramophoneLibraryView> {
  static const double _trackItemExtent = 72;

  final ScrollController _scrollController = ScrollController();
  // Timer? _coverLoadDelayTimer;
  // final ValueNotifier<bool> _deferCoverNotifier = ValueNotifier<bool>(false);
  // bool _deferNetworkCovers = false;
  int _lastVisibleCount = 0;

  @override
  void dispose() {
    // _coverLoadDelayTimer?.cancel();
    // _deferCoverNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // bool _handleScrollNotification(ScrollNotification notification) {
  //   if (notification.depth != 0) return false;

  //   MobilePerformanceLogger.instance.handleScrollNotification(
  //     notification,
  //     area: 'mobile_home_list',
  //     itemCount: _lastVisibleCount,
  //   );

  //   if (notification is ScrollStartNotification ||
  //       notification is ScrollUpdateNotification ||
  //       notification is OverscrollNotification) {
  //     _coverLoadDelayTimer?.cancel();
  //     _setCoverDefer(true, 'scroll');
  //     return false;
  //   }

  //   if (notification is ScrollEndNotification) {
  //     _scheduleCoverLoadAfterIdle();
  //   }

  //   return false;
  // }
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    MobilePerformanceLogger.instance.handleScrollNotification(
      notification,
      area: 'mobile_home_list',
      itemCount: _lastVisibleCount,
    );

    return false;
  }

  // void _setCoverDefer(bool value, String reason) {
  //   if (_deferNetworkCovers == value) return;
  //   _deferNetworkCovers = value;
  //   MobilePerformanceLogger.instance.mark(
  //     'COVER_DEFER',
  //     '${value ? 'on' : 'off'} reason=$reason',
  //     printNow: true,
  //   );
  //   _deferCoverNotifier.value = value;
  // }

  // void _scheduleCoverLoadAfterIdle() {
  //   _coverLoadDelayTimer?.cancel();

  //   // 日志显示 COVER_DEFER 在 180ms 内频繁 off -> on，会让整个列表反复重建，
  //   // 滚动时 build 直接冲到 50~80ms。这里把恢复封面加载延后，
  //   // 让连续甩动列表时保持占位图，等真正停下来后再加载封面。
  //   _coverLoadDelayTimer = Timer(const Duration(milliseconds: 900), () {
  //     if (!mounted) return;
  //     _setCoverDefer(false, 'scroll_idle');
  //   });
  // }

  void _openSearch(BuildContext context, List<MusicTrack> tracks) {
    if (tracks.isEmpty) return;
    Get.to<void>(
      () => _MusicSearchPage(tracks: tracks),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _jumpToLetter(
      String letter, List<MusicTrack> tracks, HomeController home) {
    final index =
        tracks.indexWhere((track) => home.indexLetterForTrack(track) == letter);
    if (index < 0 || !_scrollController.hasClients) return;

    // 前面的 AppBar / 统计 / 筛选 / 排序区域高度不是固定 Sliver，
    // 这里用一个稳定近似值，搭配固定歌曲行高，跳转体验会比较接近原生音乐播放器。
    final headerOffset = home.shouldShowSourceTabs ? 250.0 : 194.0;
    final target = (headerOffset + index * _trackItemExtent)
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    final player = Get.find<PlayerController>();
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final visibleTracks = home.visibleTracks;
      _lastVisibleCount = visibleTracks.length;
      final allTracks = home.sortedTracks;
      final selected = home.selectedSourceType.value;
      final indexLetters =
          visibleTracks.map(home.indexLetterForTrack).toSet().toList()
            ..sort((a, b) {
              if (a == '#') return 1;
              if (b == '#') return -1;
              return a.compareTo(b);
            });
      final hasAlphabetIndex = indexLetters.length > 2;
      return Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: CustomScrollView(
              controller: _scrollController,
              cacheExtent: _trackItemExtent * 4,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverAppBar.large(
                  pinned: true,
                  backgroundColor: scheme.surface,
                  foregroundColor: scheme.onSurface,
                  surfaceTintColor: Colors.transparent,
                  expandedHeight: 136,
                  leading: IconButton(
                    tooltip: 'common.settings'.tr,
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: widget.onOpenDrawer,
                  ),
                  title: Text('app.name'.tr),
                  actions: [
                    IconButton(
                      tooltip: 'common.sort'.tr,
                      icon: const Icon(Icons.sort_by_alpha_rounded),
                      onPressed: allTracks.isEmpty
                          ? null
                          : () => _showSortOptions(context, home),
                    ),
                    IconButton(
                      tooltip: 'common.search'.tr,
                      icon: const Icon(Icons.search_rounded),
                      onPressed: allTracks.isEmpty
                          ? null
                          : () => _openSearch(context, allTracks),
                    ),
                    IconButton(
                      tooltip: 'common.filterOrAdd'.tr,
                      icon: const Icon(Icons.add_rounded),
                      onPressed: widget.onOpenSources,
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: _LibrarySummary(
                    totalCount: allTracks.length,
                    visibleCount: visibleTracks.length,
                    selected: selected,
                  ),
                ),
                if (home.shouldShowSourceTabs)
                  SliverToBoxAdapter(child: _SourceFilterBar(home: home)),
                if (allTracks.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyLibrary(onOpenSources: widget.onOpenSources),
                  )
                else if (visibleTracks.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptySource(selected: selected),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      4,
                      hasAlphabetIndex ? 22 : 12,
                      104,
                    ),
                    sliver: SliverFixedExtentList(
                      itemExtent: _trackItemExtent,
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = visibleTracks[index];
                          return Obx(() {
                            final current = player.currentTrack;
                            final isCurrent = current?.id == track.id;
                            final isPlaying =
                                isCurrent && player.isPlayingNow.value;
                            return _TrackTile(
                              key: ValueKey('track-${track.id}'),
                              track: track,
                              index: index,
                              isCurrent: isCurrent,
                              isPlaying: isPlaying,
                              enableNetworkCover: true,
                              // deferUncachedCoverListenable: _deferCoverNotifier,
                              onTap: () {
                                final playQueue =
                                    List<MusicTrack>.of(visibleTracks);
                                final playIndex = playQueue.indexWhere(
                                  (item) => item.id == track.id,
                                );
                                unawaited(player.setQueue(
                                  playQueue,
                                  initialIndex:
                                      playIndex < 0 ? index : playIndex,
                                ));
                              },
                            );
                          });
                        },
                        childCount: visibleTracks.length,
                        addAutomaticKeepAlives: false,
                        addSemanticIndexes: false,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (hasAlphabetIndex)
            Positioned(
              top: MediaQuery.sizeOf(context).width >
                      MediaQuery.sizeOf(context).height
                  ? 88
                  : 180,
              right: 0,
              bottom: MediaQuery.sizeOf(context).width >
                      MediaQuery.sizeOf(context).height
                  ? 78
                  : 116,
              child: _AlphabetIndexBar(
                letters: indexLetters,
                onSelected: (letter) =>
                    _jumpToLetter(letter, visibleTracks, home),
              ),
            ),
        ],
      );
    });
  }
}

class _AlphabetIndexBar extends StatelessWidget {
  const _AlphabetIndexBar({required this.letters, required this.onSelected});

  final List<String> letters;
  final ValueChanged<String> onSelected;

  List<String> _fitLetters(double maxHeight) {
    if (letters.isEmpty) return const [];

    // 每个字母至少需要约 14px，高度不足时自动抽样，避免横屏溢出。
    final maxCount = math.max(6, (maxHeight / 15).floor());
    if (letters.length <= maxCount) return letters;

    final result = <String>[];
    final step = (letters.length - 1) / (maxCount - 1);
    for (var i = 0; i < maxCount; i++) {
      final letter =
          letters[(i * step).round().clamp(0, letters.length - 1).toInt()];
      if (result.isEmpty || result.last != letter) result.add(letter);
    }
    if (letters.contains('#') && !result.contains('#')) {
      if (result.isNotEmpty) result[result.length - 1] = '#';
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final displayLetters = _fitLetters(constraints.maxHeight);
        final itemHeight =
            (constraints.maxHeight - 12) / math.max(displayLetters.length, 1);
        final safeItemHeight = itemHeight.clamp(13.0, 18.0).toDouble();

        return Material(
          color: scheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final letter in displayLetters)
                _AlphabetIndexItem(
                  letter: letter,
                  height: safeItemHeight,
                  onTap: () => onSelected(letter),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AlphabetIndexItem extends StatelessWidget {
  const _AlphabetIndexItem({
    required this.letter,
    required this.height,
    required this.onTap,
  });

  final String letter;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: SizedBox(
        width: 20,
        height: height,
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: height < 16 ? 9.5 : 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
