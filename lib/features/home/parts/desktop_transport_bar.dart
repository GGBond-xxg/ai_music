part of '../home_page.dart';

class _DesktopTransportBar extends StatefulWidget {
  const _DesktopTransportBar();

  @override
  State<_DesktopTransportBar> createState() => _DesktopTransportBarState();
}

class _DesktopTransportBarState extends State<_DesktopTransportBar> {
  Duration? _dragPosition;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }

  IconData _modeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequence:
        return Icons.format_list_numbered_rounded;
      case PlayMode.shuffle:
        return Icons.shuffle_rounded;
      case PlayMode.repeatAll:
        return Icons.repeat_rounded;
      case PlayMode.repeatOne:
        return Icons.repeat_one_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Get.find<PlayerController>();
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface.withValues(alpha: 0.96),
      child: Container(
        // PC 底部控制栏：固定紧凑高度，避免 Slider 默认 48px 高度把内容顶出。
        height: 94,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.58),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: Row(
            children: [
              SizedBox(
                width: 310,
                child: _DesktopTransportTrackInfo(player: player),
              ),
              Expanded(
                child: _DesktopTransportCenter(
                  player: player,
                  formatDuration: _formatDuration,
                  modeIcon: _modeIcon,
                  dragPosition: _dragPosition,
                  onDragPositionChanged: (value) {
                    if (!mounted) return;
                    setState(() => _dragPosition = value);
                  },
                  onOpenSleepTimer: () =>
                      _showSleepTimerQuickSheet(context, player),
                ),
              ),
              SizedBox(
                width: 320,
                child: _DesktopTransportTools(player: player),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSleepTimerQuickSheet(
      BuildContext context, PlayerController player) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.timer_off_rounded),
                  title: Text('player.cancelCurrentTimer'.tr),
                  onTap: () => Navigator.of(context).pop(0),
                ),
                for (final minute in const [5, 10, 15, 30, 60])
                  ListTile(
                    leading: const Icon(Icons.timer_rounded),
                    title: Text('player.minutes'.trParams({'minutes': '$minute'})),
                    onTap: () => Navigator.of(context).pop(minute),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) return;
    if (selected == 0) {
      player.cancelSleepTimer(showMessage: true);
    } else {
      player.startSleepTimer(Duration(minutes: selected));
    }
  }
}

class _DesktopTransportTrackInfo extends StatelessWidget {
  const _DesktopTransportTrackInfo({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final track = player.currentTrack;
      return Row(
        children: [
          if (track == null)
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.music_note_rounded,
                  color: scheme.onSurfaceVariant),
            )
          else
            TrackCover(track: track, size: 58, borderRadius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track?.title ?? 'common.noCurrentTrack'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  track?.artist ?? 'common.freshMusic'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _DesktopTransportCenter extends StatelessWidget {
  const _DesktopTransportCenter({
    required this.player,
    required this.formatDuration,
    required this.modeIcon,
    required this.dragPosition,
    required this.onDragPositionChanged,
    required this.onOpenSleepTimer,
  });

  final PlayerController player;
  final String Function(Duration) formatDuration;
  final IconData Function(PlayMode) modeIcon;
  final Duration? dragPosition;
  final ValueChanged<Duration?> onDragPositionChanged;
  final VoidCallback onOpenSleepTimer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Obx(() {
              return _DesktopRoundIconButton(
                tooltip: player.playMode.value.label,
                icon: modeIcon(player.playMode.value),
                onPressed: player.cyclePlayMode,
              );
            }),
            _DesktopRoundIconButton(
              tooltip: 'common.previous'.tr,
              icon: Icons.skip_previous_rounded,
              onPressed: player.previous,
            ),
            Obx(() {
              final playing = player.isPlayingNow.value;
              final hasTrack = player.currentTrack != null;
              return Container(
                width: 46,
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: hasTrack
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: playing ? 'common.pause'.tr : 'common.play'.tr,
                  onPressed: hasTrack ? player.togglePlay : null,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color:
                        hasTrack ? scheme.onPrimary : scheme.onSurfaceVariant,
                    size: 27,
                  ),
                ),
              );
            }),
            _DesktopRoundIconButton(
              tooltip: 'common.next'.tr,
              icon: Icons.skip_next_rounded,
              onPressed: player.next,
            ),
            Obx(() {
              return _DesktopRoundIconButton(
                tooltip: player.sleepTimerRemaining.value == null
                    ? 'player.sleepTimer'.tr
                    : 'player.timerWithLabel'.trParams({'label': player.sleepTimerLabel}),
                icon: player.sleepTimerRemaining.value == null
                    ? Icons.timer_outlined
                    : Icons.timer_rounded,
                onPressed: onOpenSleepTimer,
              );
            }),
          ],
        ),
        _DesktopTransportSeekRow(
          player: player,
          formatDuration: formatDuration,
          dragPosition: dragPosition,
          onDragPositionChanged: onDragPositionChanged,
          leadingWidth: 48,
          trailingWidth: 48,
          fontSize: 12,
        ),
      ],
    );
  }
}

class _DesktopTransportSeekRow extends StatelessWidget {
  const _DesktopTransportSeekRow({
    required this.player,
    required this.formatDuration,
    required this.dragPosition,
    required this.onDragPositionChanged,
    this.leadingWidth = 48,
    this.trailingWidth = 48,
    this.fontSize = 12,
  });

  final PlayerController player;
  final String Function(Duration) formatDuration;
  final Duration? dragPosition;
  final ValueChanged<Duration?> onDragPositionChanged;
  final double leadingWidth;
  final double trailingWidth;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final track = player.currentTrack;
      final duration = player.displayDuration.value ??
          player.player.duration ??
          track?.duration ??
          Duration.zero;
      final position = player.displayPosition.value;
      final effective = dragPosition ?? position;
      final maxMs = duration.inMilliseconds <= 0
          ? 1.0
          : duration.inMilliseconds.toDouble();
      final safeMs =
          effective.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
      final progress = duration.inMilliseconds <= 0
          ? 0.0
          : (safeMs / maxMs).clamp(0.0, 1.0).toDouble();

      Duration positionFromDx(double dx, double width) {
        final ratio = width <= 0 ? 0.0 : (dx / width).clamp(0.0, 1.0);
        return Duration(milliseconds: (ratio * maxMs).round());
      }

      return SizedBox(
        height: 26,
        child: Row(
          children: [
            SizedBox(
              width: leadingWidth,
              child: Text(
                formatDuration(effective),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final enabled = duration > Duration.zero;
                  final barWidth = constraints.maxWidth;

                  void updateFromDx(double dx) {
                    if (!enabled) return;
                    final pos = positionFromDx(dx, barWidth);
                    onDragPositionChanged(pos);
                    player.previewSeek(pos);
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: enabled
                        ? (details) {
                            final pos = positionFromDx(
                              details.localPosition.dx,
                              barWidth,
                            );
                            unawaited(player.commitSeek(pos));
                          }
                        : null,
                    onHorizontalDragStart: enabled
                        ? (details) {
                            final pos = positionFromDx(
                              details.localPosition.dx,
                              barWidth,
                            );
                            onDragPositionChanged(pos);
                            player.beginSeek(pos);
                          }
                        : null,
                    onHorizontalDragUpdate: enabled
                        ? (details) => updateFromDx(details.localPosition.dx)
                        : null,
                    onHorizontalDragEnd: enabled
                        ? (_) {
                            final pos = dragPosition ?? effective;
                            onDragPositionChanged(null);
                            unawaited(player.commitSeek(pos));
                          }
                        : null,
                    onHorizontalDragCancel:
                        enabled ? () => onDragPositionChanged(null) : null,
                    child: SizedBox(
                      height: 26,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          Positioned(
                            left: (barWidth * progress - 7)
                                .clamp(0.0, barWidth - 14)
                                .toDouble(),
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        scheme.primary.withValues(alpha: 0.22),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: trailingWidth,
              child: Text(
                formatDuration(duration),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _DesktopTransportTools extends StatelessWidget {
  const _DesktopTransportTools({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Obx(() {
          final hasTrack = player.currentTrack != null;
          return _DesktopRoundIconButton(
            tooltip: 'common.lyrics'.tr,
            icon: Icons.lyrics_rounded,
            onPressed:
                hasTrack ? () => _openDesktopLyricsPage(context, player) : null,
          );
        }),
        const SizedBox(width: 10),
        Obx(() {
          return _DesktopRoundIconButton(
            tooltip: player.isMuted.value ? 'common.show'.tr : 'common.hide'.tr,
            icon: player.isMuted.value || player.volume.value <= 0.001
                ? Icons.volume_off_rounded
                : player.volume.value < 0.45
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            onPressed: player.toggleMute,
          );
        }),
        const SizedBox(width: 8),
        SizedBox(
          width: 156,
          child: _DesktopVolumeBar(player: player),
        ),
      ],
    );
  }
}

class _DesktopVolumeBar extends StatelessWidget {
  const _DesktopVolumeBar({required this.player});

  final PlayerController player;

  void _setFromDx(double dx, double width) {
    if (width <= 0) return;
    final value = (dx / width).clamp(0.0, 1.0).toDouble();
    unawaited(player.setVolume(value));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: Obx(() {
        final value = player.volume.value.clamp(0.0, 1.0).toDouble();

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) =>
                  _setFromDx(details.localPosition.dx, width),
              onHorizontalDragStart: (details) =>
                  _setFromDx(details.localPosition.dx, width),
              onHorizontalDragUpdate: (details) =>
                  _setFromDx(details.localPosition.dx, width),
              child: SizedBox(
                height: 28,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned(
                      left:
                          (width * value - 6).clamp(0.0, width - 12).toDouble(),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.18),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _DesktopRoundIconButton extends StatelessWidget {
  const _DesktopRoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        color: onPressed == null
            ? scheme.onSurfaceVariant.withValues(alpha: 0.42)
            : scheme.onSurface,
      ),
    );
  }
}

Future<void> _openDesktopLyricsPage(
  BuildContext context,
  PlayerController player,
) async {
  if (player.currentTrack == null) return;
  final capturedTheme = Theme.of(context);

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'common.close'.tr,
    barrierColor: Colors.black.withValues(alpha: 0.20),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Theme(
        data: capturedTheme,
        child: _DesktopLyricsPage(player: player),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return SlideTransition(
        // 打开：从下往上进入；关闭：从当前位置向下退出。
        // 去掉 Fade/Scale，减少桌面端打开大歌词页时首帧合成压力。
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class _DesktopLyricsPage extends StatefulWidget {
  const _DesktopLyricsPage({required this.player});

  final PlayerController player;

  @override
  State<_DesktopLyricsPage> createState() => _DesktopLyricsPageState();
}

class _DesktopLyricsPageState extends State<_DesktopLyricsPage> {
  static const double _lyricItemExtent = 70.0;
  static const double _activeLyricAnchor = 0.30;

  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Duration>? _positionSub;
  Duration? _dragPosition;
  final ValueNotifier<int> _activeIndexNotifier = ValueNotifier<int>(0);
  int _activeIndex = 0;
  String? _lastTrackId;
  String? _paletteKey;
  Color? _currentSeed;
  List<LyricLine> _timedLyrics = const [];
  List<String> _plainLyrics = const [];

  @override
  void initState() {
    super.initState();
    _syncLyrics();
    _positionSub = widget.player.player.positionStream.listen(_handlePosition);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _activeIndexNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }

  IconData _modeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequence:
        return Icons.format_list_numbered_rounded;
      case PlayMode.shuffle:
        return Icons.shuffle_rounded;
      case PlayMode.repeatAll:
        return Icons.repeat_rounded;
      case PlayMode.repeatOne:
        return Icons.repeat_one_rounded;
    }
  }

  void _syncLyrics() {
    final track = widget.player.currentTrack;
    if (track == null || track.id == _lastTrackId) return;
    _lastTrackId = track.id;
    _timedLyrics = parseLrc(track.lyricText);
    _plainLyrics = parsePlainLyrics(track.lyricText);
    _activeIndex = 0;
    _activeIndexNotifier.value = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  void _handlePosition(Duration position) {
    if (!mounted) return;
    _syncLyrics();
    if (_timedLyrics.isEmpty) return;

    final lyricPosition = widget.player.lyricPositionFor(position);
    final index =
        _timedLyrics.lastIndexWhere((line) => line.time <= lyricPosition);
    final safe =
        index < 0 ? 0 : index.clamp(0, _timedLyrics.length - 1).toInt();
    if (safe == _activeIndex) return;

    _activeIndex = safe;
    _activeIndexNotifier.value = safe;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = (safe * _lyricItemExtent -
              _scrollController.position.viewportDimension * _activeLyricAnchor)
          .clamp(0.0, _scrollController.position.maxScrollExtent)
          .toDouble();
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _seekToLyricIndex(int index) async {
    if (index < 0 || index >= _timedLyrics.length) return;

    final target = _timedLyrics[index].time;
    _activeIndex = index;
    _activeIndexNotifier.value = index;

    if (_scrollController.hasClients) {
      final targetOffset = (index * _lyricItemExtent -
              _scrollController.position.viewportDimension * _activeLyricAnchor)
          .clamp(0.0, _scrollController.position.maxScrollExtent)
          .toDouble();
      unawaited(_scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ));
    }

    await widget.player.commitSeek(target);
  }

  ThemeData _themeForTrack(BuildContext context, MusicTrack? track) {
    final baseTheme = Theme.of(context);
    final baseScheme = baseTheme.colorScheme;
    _ensurePalette(track, baseScheme);

    final scheme = _currentSeed == null
        ? baseScheme
        : _desktopColorSchemeFromSeed(_currentSeed!, baseScheme);

    return baseTheme.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      sliderTheme: baseTheme.sliderTheme.copyWith(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.onSurfaceVariant.withValues(alpha: 0.22),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.10),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
      ),
    );
  }

  void _ensurePalette(MusicTrack? track, ColorScheme scheme) {
    if (track == null) {
      if (_paletteKey != null) {
        _paletteKey = null;
        _currentSeed = null;
      }
      return;
    }

    final cache = CoverPaletteCache.instance;
    final key = cache.keyForTrack(track, scheme.brightness);
    if (_paletteKey == key) return;

    _paletteKey = key;

    // PC 歌词页也直接读持久化缓存，避免先出现默认背景色。
    final cached = cache.cachedSeedForKey(key);
    if (cached != null) {
      _currentSeed = cached;
      return;
    }

    final fallback = _currentSeed ?? scheme.primary;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _paletteKey != key) return;
      unawaited(_loadSeedFromCover(track, scheme, key, fallback));
    });
  }

  Future<void> _loadSeedFromCover(
    MusicTrack track,
    ColorScheme scheme,
    String key,
    Color fallback,
  ) async {
    final seed = await CoverPaletteCache.instance.resolveSeedForTrack(
      track,
      scheme.brightness,
      fallback: fallback,
      sampleSize: const Size(220, 220),
      maximumColorCount: 18,
    );

    if (!mounted || _paletteKey != key) return;
    setState(() => _currentSeed = seed);
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;

    return Obx(() {
      _syncLyrics();
      final track = player.currentTrack;
      final theme = _themeForTrack(context, track);
      final scheme = theme.colorScheme;

      if (track == null) {
        return const Material(
            color: Colors.transparent, child: SizedBox.shrink());
      }

      final lines = _timedLyrics.isNotEmpty
          ? _timedLyrics.map((line) => line.text).toList()
          : _plainLyrics;

      return Theme(
        data: theme,
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            color: scheme.surface,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        scheme.surface,
                        scheme.surfaceContainerHigh,
                        0.42,
                      ),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.48),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildHeader(context),
                        Expanded(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 380,
                                child: _buildCoverAndControls(context, track),
                              ),
                              VerticalDivider(
                                width: 1,
                                color: scheme.outlineVariant
                                    .withValues(alpha: 0.42),
                              ),
                              Expanded(child: _buildLyricList(context, lines)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 18, 8),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Row(
                children: [
                  Text(
                    'common.lyrics'.tr,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'common.coverColor'.tr,
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
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
    );
  }

  Widget _buildCoverAndControls(BuildContext context, MusicTrack track) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 16, 34, 34),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TrackCover(
                      track: track,
                      size: 244,
                      borderRadius: 32,
                      iconSize: 98,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w900,
                                height: 1.12,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      track.artist ?? 'common.unknownArtist'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.30),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: _DesktopLyricsPlaybackControls(
                player: widget.player,
                formatDuration: _formatDuration,
                modeIcon: _modeIcon,
                dragPosition: _dragPosition,
                onDragPositionChanged: (value) {
                  if (!mounted) return;
                  setState(() => _dragPosition = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricList(BuildContext context, List<String> lines) {
    final scheme = Theme.of(context).colorScheme;

    if (lines.isEmpty) {
      return Center(
        child: Text(
          'common.noLyrics'.tr,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.18),
      ),
      child: ScrollConfiguration(
        behavior: const _FreshDesktopScrollBehavior(),
        child: Obx(() {
          final textAlign = widget.player.lyricTextAlign.value;
          final lineAlignment = switch (textAlign) {
            TextAlign.left || TextAlign.start => Alignment.centerLeft,
            TextAlign.right || TextAlign.end => Alignment.centerRight,
            _ => Alignment.center,
          };

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(72, 130, 72, 120),
            itemExtent: _lyricItemExtent,
            cacheExtent: 420,
            itemCount: lines.length,
            itemBuilder: (context, index) {
              return _DesktopLyricLineTile(
                text: lines[index].replaceAll('\n', '  '),
                index: index,
                activeIndexListenable: _activeIndexNotifier,
                hasTimedLyrics: _timedLyrics.isNotEmpty,
                textAlign: textAlign,
                alignment: lineAlignment,
                onTap: _timedLyrics.isEmpty
                    ? null
                    : () => unawaited(_seekToLyricIndex(index)),
              );
            },
          );
        }),
      ),
    );
  }
}

class _DesktopLyricLineTile extends StatelessWidget {
  const _DesktopLyricLineTile({
    required this.text,
    required this.index,
    required this.activeIndexListenable,
    required this.hasTimedLyrics,
    required this.textAlign,
    required this.alignment,
    this.onTap,
  });

  final String text;
  final int index;
  final ValueListenable<int> activeIndexListenable;
  final bool hasTimedLyrics;
  final VoidCallback? onTap;
  final TextAlign textAlign;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<int>(
      valueListenable: activeIndexListenable,
      builder: (context, activeIndex, _) {
        final active = hasTimedLyrics && index == activeIndex;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: active
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.66),
              fontSize: active ? 31 : 23,
              height: 1.28,
              fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            ),
            child: Align(
              alignment: alignment,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopLyricsPlaybackControls extends StatelessWidget {
  const _DesktopLyricsPlaybackControls({
    required this.player,
    required this.formatDuration,
    required this.modeIcon,
    required this.dragPosition,
    required this.onDragPositionChanged,
  });

  final PlayerController player;
  final String Function(Duration) formatDuration;
  final IconData Function(PlayMode) modeIcon;
  final Duration? dragPosition;
  final ValueChanged<Duration?> onDragPositionChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DesktopTransportSeekRow(
          player: player,
          formatDuration: formatDuration,
          dragPosition: dragPosition,
          onDragPositionChanged: onDragPositionChanged,
          leadingWidth: 42,
          trailingWidth: 42,
          fontSize: 11.5,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Obx(() {
              return _DesktopRoundIconButton(
                tooltip: player.playMode.value.label,
                icon: modeIcon(player.playMode.value),
                onPressed: player.cyclePlayMode,
              );
            }),
            _DesktopRoundIconButton(
              tooltip: 'common.previous'.tr,
              icon: Icons.skip_previous_rounded,
              onPressed: player.previous,
            ),
            Obx(() {
              final playing = player.isPlayingNow.value;
              final hasTrack = player.currentTrack != null;
              return Container(
                width: 46,
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: hasTrack
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: playing ? 'common.pause'.tr : 'common.play'.tr,
                  onPressed: hasTrack ? player.togglePlay : null,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color:
                        hasTrack ? scheme.onPrimary : scheme.onSurfaceVariant,
                    size: 27,
                  ),
                ),
              );
            }),
            _DesktopRoundIconButton(
              tooltip: 'common.next'.tr,
              icon: Icons.skip_next_rounded,
              onPressed: player.next,
            ),
            Obx(() {
              return _DesktopRoundIconButton(
                tooltip: 'player.lyricAlign'.trParams({'label': player.lyricAlignLabel}),
                icon: player.lyricAlignIcon,
                onPressed: player.cycleLyricAlign,
              );
            }),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Obx(() {
              return _DesktopRoundIconButton(
                tooltip: player.isMuted.value ? 'common.show'.tr : 'common.hide'.tr,
                icon: player.isMuted.value || player.volume.value <= 0.001
                    ? Icons.volume_off_rounded
                    : player.volume.value < 0.45
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                onPressed: player.toggleMute,
              );
            }),
            const SizedBox(width: 8),
            Expanded(child: _DesktopVolumeBar(player: player)),
          ],
        ),
      ],
    );
  }
}
