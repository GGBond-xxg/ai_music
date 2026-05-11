part of '../player_page.dart';

class _NowPlayingPage extends StatelessWidget {
  const _NowPlayingPage({
    required this.track,
    required this.controller,
    required this.timedLyrics,
    required this.plainLyrics,
    required this.activeIndex,
  });

  final MusicTrack track;
  final PlayerController controller;
  final List<LyricLine> timedLyrics;
  final List<String> plainLyrics;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
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
        final compact = height < 500;
        final veryCompact = height < 430;
        final horizontalPadding = width < 360 ? 24.0 : 30.0;
        final lyricHeight = veryCompact ? 74.0 : 88.0;
        final topGap = veryCompact
            ? 2.0
            : compact
                ? 8.0
                : 18.0;
        final lyricGap = veryCompact ? 12.0 : 18.0;
        final maxCoverByHeight = height - topGap - lyricGap - lyricHeight - 4;
        final coverSize = math
            .min(width - horizontalPadding * 2, maxCoverByHeight)
            .clamp(178.0, math.min(width * 0.84, 420.0))
            .toDouble();
        final coverRadius = (coverSize * 0.08).clamp(16.0, 28.0).toDouble();

        return Padding(
          padding:
              EdgeInsets.symmetric(vertical: 0, horizontal: horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: topGap),
              Center(
                child: TrackCover(
                  track: track,
                  size: coverSize,
                  borderRadius: coverRadius,
                  iconSize: coverSize * 0.42,
                ),
              ),
              SizedBox(height: lyricGap),
              SizedBox(
                height: lyricHeight,
                child: _NowPlayingTwoLineLyric(
                  controller: controller,
                  currentLine: currentLine,
                  nextLine: nextLine,
                  hasTimedLyrics: timedLyrics.isNotEmpty,
                  veryCompact: veryCompact,
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NowPlayingTwoLineLyric extends StatelessWidget {
  const _NowPlayingTwoLineLyric({
    required this.controller,
    required this.currentLine,
    required this.nextLine,
    required this.hasTimedLyrics,
    required this.veryCompact,
    this.textAlign,
  });

  final PlayerController controller;
  final String currentLine;
  final String? nextLine;
  final bool hasTimedLyrics;
  final bool veryCompact;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final fixedAlign = textAlign;

    // 播放页会传入固定的 textAlign，这种情况下不需要 Obx。
    // 如果 Obx 内部没有读取任何 Rx 变量，GetX 会抛出 improper use of a GetX。
    if (fixedAlign != null) {
      return _buildLyricText(context, fixedAlign);
    }

    // 只有完整歌词页需要跟随 controller.lyricTextAlign 响应靠左/居中/靠右。
    return Obx(() => _buildLyricText(context, controller.lyricTextAlign.value));
  }

  Widget _buildLyricText(BuildContext context, TextAlign align) {
    final scheme = Theme.of(context).colorScheme;
    final firstLine = _singleLineLyricText(currentLine);
    final secondLine = nextLine == null ? '' : _singleLineLyricText(nextLine!);

    return SizedBox(
      height: veryCompact ? 74 : 88,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            firstLine,
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: hasTimedLyrics
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  fontSize: veryCompact ? 18 : 21,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            secondLine,
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                  fontSize: veryCompact ? 14 : 16,
                ),
          ),
        ],
      ),
    );
  }
}

class _LyricsPage extends StatelessWidget {
  const _LyricsPage({
    required this.controller,
    required this.timedLyrics,
    required this.plainLyrics,
    required this.activeIndex,
    required this.scrollController,
    this.padding,
    this.compactSingleLineRows = false,
    this.fixedTextAlign,
    this.onLyricTap,
  });

  final PlayerController controller;
  final List<LyricLine> timedLyrics;
  final List<String> plainLyrics;
  final int activeIndex;
  final ScrollController scrollController;
  final EdgeInsetsGeometry? padding;
  final bool compactSingleLineRows;
  final TextAlign? fixedTextAlign;
  final ValueChanged<Duration>? onLyricTap;

  @override
  Widget build(BuildContext context) {
    final hasTimed = timedLyrics.isNotEmpty;
    final lines =
        hasTimed ? timedLyrics.map((e) => e.text).toList() : plainLyrics;
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;

    return lines.isEmpty
        ? _EmptyLyricsState(controller: controller)
        : ClipRect(
            child: ListView.builder(
              controller: hasTimed ? scrollController : null,
              physics: isLandscape
                  ? const ClampingScrollPhysics()
                  : const BouncingScrollPhysics(),
              // 不再使用 itemExtent，避免有翻译 / 无翻译歌词高度不一致时溢出。
              itemExtent: null,
              padding: padding ??
                  EdgeInsets.fromLTRB(
                    isLandscape ? 24 : 30,
                    isLandscape ? 42 : 80,
                    isLandscape ? 24 : 30,
                    isLandscape ? 86 : 120,
                  ),
              itemCount: lines.length,
              itemBuilder: (context, i) {
                final active = hasTimed && i == activeIndex;

                final itemHeight = _lyricRowHeightForText(
                  lines[i],
                  compactSingleLineRows: compactSingleLineRows || isLandscape,
                );

                final seekTime = hasTimed ? timedLyrics[i].time : null;

                return _LyricListItem(
                  text: lines[i],
                  active: active,
                  controller: controller,
                  height: itemHeight,
                  fixedTextAlign: fixedTextAlign,
                  onTap: seekTime == null || onLyricTap == null
                      ? null
                      : () => onLyricTap!(seekTime),
                );
              },
            ),
          );
  }
}

class _LyricListItem extends StatelessWidget {
  const _LyricListItem({
    required this.text,
    required this.active,
    required this.controller,
    required this.height,
    this.fixedTextAlign,
    this.onTap,
  });

  final String text;
  final bool active;
  final PlayerController controller;
  final double height;
  final TextAlign? fixedTextAlign;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    final lyricText = _singleLineLyricText(text);

    final primaryFontSize =
        isLandscape ? (active ? 21.0 : 18.0) : (active ? 23.5 : 21.0);

    Widget buildContent(TextAlign align) {
      final textStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
            color: active
                ? scheme.onSurface
                : scheme.onSurfaceVariant.withValues(alpha: 0.34),
            fontWeight: active ? FontWeight.w900 : FontWeight.w800,
            fontSize: primaryFontSize,
            height: 1.06,
          );

      return Align(
        alignment: _alignmentForTextAlign(align),
        child: SizedBox(
          width: double.infinity,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 120),
            style: textStyle,
            child: _AutoScrollingSingleLineText(
              text: lyricText,
              textAlign: align,
              active: active,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: ClipRect(
          child: fixedTextAlign == null
              ? Obx(() => buildContent(controller.lyricTextAlign.value))
              : buildContent(fixedTextAlign!),
        ),
      ),
    );
  }
}

class _AutoScrollingSingleLineText extends StatefulWidget {
  const _AutoScrollingSingleLineText({
    required this.text,
    required this.textAlign,
    required this.active,
  });

  final String text;
  final TextAlign textAlign;
  final bool active;

  @override
  State<_AutoScrollingSingleLineText> createState() =>
      _AutoScrollingSingleLineTextState();
}

class _AutoScrollingSingleLineTextState
    extends State<_AutoScrollingSingleLineText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _lastOverflow = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _AutoScrollingSingleLineText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.active != widget.active) {
      _lastOverflow = 0;
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextPainter _textPainterFor(
    BuildContext context,
    TextStyle style,
  ) {
    return TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: double.infinity);
  }

  void _syncMarquee(double overflow) {
    if (!widget.active || overflow <= 0) {
      if (_controller.isAnimating) _controller.stop();
      if (_controller.value != 0) _controller.value = 0;
      return;
    }

    if ((_lastOverflow - overflow).abs() < 0.5 && _controller.isAnimating) {
      return;
    }

    _lastOverflow = overflow;
    final milliseconds =
        (overflow / 28 * 1000).round().clamp(2800, 12000).toInt();
    _controller.duration = Duration(milliseconds: milliseconds);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) return;
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (!maxWidth.isFinite || maxWidth <= 0) {
          return Text(
            widget.text,
            textAlign: widget.textAlign,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          );
        }

        final textPainter = _textPainterFor(context, style);
        final textWidth = textPainter.width;
        final overflow = math.max(0.0, textWidth - maxWidth);

        if (overflow <= 1) {
          _syncMarquee(0);
          return Text(
            widget.text,
            textAlign: widget.textAlign,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          );
        }

        if (!widget.active) {
          _syncMarquee(0);
          // 非当前歌词不再用省略号；保留单行完整文本，可左右拖动查看。
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Text(
              widget.text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          );
        }

        _syncMarquee(overflow);

        return ClipRect(
          child: SizedBox(
            width: maxWidth,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(-overflow * _controller.value, 0),
                  child: child,
                );
              },
              child: SizedBox(
                width: textWidth,
                child: Text(
                  widget.text,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyLyricsState extends StatelessWidget {
  const _EmptyLyricsState({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final align = controller.lyricTextAlign.value;

      return Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 64),
        child: Align(
          alignment: _alignmentForTextAlign(align),
          child: Text(
            'common.noLyrics'.tr,
            textAlign: align,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
          ),
        ),
      );
    });
  }
}

class _MusicSourceChip extends StatelessWidget {
  const _MusicSourceChip({required this.track});

  final MusicTrack track;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = _musicSourceLabel(track.sourceType);

    return Container(
      constraints:
          const BoxConstraints(minWidth: 75, maxWidth: 108, minHeight: 35),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8.5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          // height: 1.2,
        ),
      ),
    );
  }
}

class _LyricAlignChip extends StatelessWidget {
  const _LyricAlignChip({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: controller.cycleLyricAlign,
        child: Container(
          constraints:
              const BoxConstraints(minWidth: 75, maxWidth: 108, minHeight: 35),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(controller.lyricAlignIcon, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                controller.lyricAlignLabel,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
