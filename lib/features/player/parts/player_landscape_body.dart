part of '../player_page.dart';

class _LandscapePlayerBody extends StatefulWidget {
  const _LandscapePlayerBody({
    required this.track,
    required this.controller,
    required this.timedLyrics,
    required this.plainLyrics,
    required this.activeIndex,
    required this.currentPage,
    required this.onPageChanged,
    required this.lyricScrollController,
  });

  final MusicTrack track;
  final PlayerController controller;
  final List<LyricLine> timedLyrics;
  final List<String> plainLyrics;
  final int activeIndex;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final ScrollController lyricScrollController;

  @override
  State<_LandscapePlayerBody> createState() => _LandscapePlayerBodyState();
}

class _LandscapePlayerBodyState extends State<_LandscapePlayerBody> {
  int _visualPage = 0;
  bool _isDragging = false;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _visualPage = widget.currentPage.clamp(0, 1).toInt();
  }

  @override
  void didUpdateWidget(covariant _LandscapePlayerBody oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextPage = widget.currentPage.clamp(0, 1).toInt();

    // 外部切页时同步状态；手指正在拖动时不要抢控制权。
    if (!_isDragging && nextPage != _visualPage) {
      _visualPage = nextPage;
      _dragOffset = 0;
    }
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset = 0;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, double pageWidth) {
    final delta = details.primaryDelta ?? 0;
    var nextOffset = _dragOffset + delta;

    // 第 0 页：只能主要向左拖到歌词页；向右拖给一点阻尼
    if (_visualPage == 0) {
      if (nextOffset > 0) {
        nextOffset *= 0.25;
      }
      nextOffset = nextOffset.clamp(-pageWidth, pageWidth * 0.18).toDouble();
    }

    // 第 1 页：只能主要向右拖回播放页；向左拖给一点阻尼
    if (_visualPage == 1) {
      if (nextOffset < 0) {
        nextOffset *= 0.25;
      }
      nextOffset = nextOffset.clamp(-pageWidth * 0.18, pageWidth).toDouble();
    }

    setState(() {
      _dragOffset = nextOffset;
    });
  }

  void _handleDragEnd(DragEndDetails details, double pageWidth) {
    final velocity = details.primaryVelocity ?? 0;
    final dragRatio = (_dragOffset.abs() / pageWidth).clamp(0.0, 1.0);

    var targetPage = _visualPage;

    // 播放页 -> 歌词页
    if (_visualPage == 0) {
      if (_dragOffset < -pageWidth * 0.22 ||
          dragRatio > 0.28 ||
          velocity < -420) {
        targetPage = 1;
      }
    }

    // 歌词页 -> 播放页
    if (_visualPage == 1) {
      if (_dragOffset > pageWidth * 0.22 ||
          dragRatio > 0.28 ||
          velocity > 420) {
        targetPage = 0;
      }
    }

    setState(() {
      _isDragging = false;
      _dragOffset = 0;
      _visualPage = targetPage;
    });

    if (targetPage != widget.currentPage) {
      widget.onPageChanged(targetPage);
    }
  }

  void _handleDragCancel() {
    setState(() {
      _isDragging = false;
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final timedLyrics = widget.timedLyrics;
    final plainLyrics = widget.plainLyrics;
    final activeIndex = widget.activeIndex;

    final safeActiveIndex = timedLyrics.isEmpty
        ? 0
        : activeIndex.clamp(0, timedLyrics.length - 1).toInt();

    final currentLine = timedLyrics.isNotEmpty
        ? timedLyrics[safeActiveIndex].text
        : (plainLyrics.isNotEmpty ? plainLyrics.first : 'common.noLyrics'.tr);

    final nextLine = timedLyrics.length > activeIndex + 1
        ? timedLyrics[activeIndex + 1].text
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final compact = height < 330;

        final horizontalPadding = width < 760 ? 26.0 : 44.0;
        final bottomPadding = MediaQuery.paddingOf(context).bottom + 10;

        final leftWidth = math
            .min(width * 0.44, 520.0)
            .clamp(260.0, math.max(260.0, width * 0.48))
            .toDouble();

        final gap = width < 760 ? 0.0 : 0.0;
        // final gap = width < 760 ? 14.0 : 28.0;
        final pageSidePadding = width < 760 ? 20.0 : 34.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            compact ? 0 : 8,
            horizontalPadding,
            bottomPadding,
          ),
          child: Row(
            children: [
              SizedBox(
                width: leftWidth,
                child: _LandscapeCoverPane(
                  track: widget.track,
                  controller: widget.controller,
                  currentLine: currentLine,
                  nextLine: nextLine,
                  hasTimedLyrics: timedLyrics.isNotEmpty,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: _handleDragStart,
                  onHorizontalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    final pageWidth = box?.size.width ?? width;
                    _handleDragUpdate(details, pageWidth);
                  },
                  onHorizontalDragEnd: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    final pageWidth = box?.size.width ?? width;
                    _handleDragEnd(details, pageWidth);
                  },
                  onHorizontalDragCancel: _handleDragCancel,
                  child: ClipRect(
                    child: LayoutBuilder(
                      builder: (context, rightConstraints) {
                        final rightWidth = rightConstraints.maxWidth;

                        final baseOffset = -_visualPage * rightWidth;
                        final translateX = baseOffset + _dragOffset;

                        return OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: rightWidth * 2,
                          maxWidth: rightWidth * 2,
                          minHeight: rightConstraints.maxHeight,
                          maxHeight: rightConstraints.maxHeight,
                          child: AnimatedContainer(
                            duration: _isDragging
                                ? Duration.zero
                                : const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            transform: Matrix4.translationValues(
                              translateX,
                              0,
                              0,
                            ),
                            child: SizedBox(
                              width: rightWidth * 2,
                              height: rightConstraints.maxHeight,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: rightWidth,
                                    height: rightConstraints.maxHeight,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: pageSidePadding,
                                      ),
                                      child: _LandscapePlaybackPane(
                                        track: widget.track,
                                        controller: widget.controller,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: rightWidth,
                                    height: rightConstraints.maxHeight,
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        pageSidePadding + 10,
                                        0,
                                        pageSidePadding,
                                        0,
                                      ),
                                      child: _LandscapeLyricsPane(
                                        controller: widget.controller,
                                        timedLyrics: timedLyrics,
                                        plainLyrics: plainLyrics,
                                        activeIndex: activeIndex,
                                        scrollController:
                                            widget.lyricScrollController,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LandscapeCoverPane extends StatelessWidget {
  const _LandscapeCoverPane({
    required this.track,
    required this.controller,
    required this.currentLine,
    required this.nextLine,
    required this.hasTimedLyrics,
  });

  final MusicTrack track;
  final PlayerController controller;
  final String currentLine;
  final String? nextLine;
  final bool hasTimedLyrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final lyricHeight = height < 340 ? 48.0 : 58.0;
        final coverGap = height < 340 ? 10.0 : 16.0;
        final coverSize = math
            .min(width, height - lyricHeight - coverGap)
            .clamp(160.0, math.min(width, 460.0))
            .toDouble();
        final coverRadius = (coverSize * 0.045).clamp(12.0, 22.0).toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TrackCover(
                  track: track,
                  size: coverSize,
                  borderRadius: coverRadius,
                  iconSize: coverSize * 0.40,
                ),
              ),
            ),
            SizedBox(height: coverGap),
            SizedBox(
              height: lyricHeight,
              child: _NowPlayingTwoLineLyric(
                controller: controller,
                currentLine: currentLine,
                nextLine: nextLine,
                hasTimedLyrics: hasTimedLyrics,
                veryCompact: true,
                textAlign: TextAlign.left,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LandscapePlaybackPane extends StatelessWidget {
  const _LandscapePlaybackPane({
    required this.track,
    required this.controller,
  });

  final MusicTrack track;
  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 330;
        return Padding(
          padding: EdgeInsets.fromLTRB(0, compact ? 2 : 10, 0, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                height: 1.08,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          track.artist ?? 'Unknown Artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.78),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    height: 1.08,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _MusicSourceChip(track: track),
                ],
              ),
              SizedBox(height: compact ? 18 : 36),
              _Controls(
                controller: controller,
                layout: _ControlsLayout.landscape,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LandscapeLyricsPane extends StatelessWidget {
  const _LandscapeLyricsPane({
    required this.controller,
    required this.timedLyrics,
    required this.plainLyrics,
    required this.activeIndex,
    required this.scrollController,
  });

  final PlayerController controller;
  final List<LyricLine> timedLyrics;
  final List<String> plainLyrics;
  final int activeIndex;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: _LyricsPage(
        controller: controller,
        timedLyrics: timedLyrics,
        plainLyrics: plainLyrics,
        activeIndex: activeIndex,
        scrollController: scrollController,
        // 横屏给顶部和底部留空间，这样当前歌词可以滚到中间。
        // right 稍微小一点，避免横屏窄高度下文字被压出边界。
        padding: const EdgeInsets.fromLTRB(0, 42, 10, 86),
        compactSingleLineRows: true,
        fixedTextAlign: TextAlign.left,
        onLyricTap: (time) => unawaited(controller.commitSeek(time)),
      ),
    );
  }
}
