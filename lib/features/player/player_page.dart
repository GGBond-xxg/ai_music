import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/lyric_line.dart';
import '../../models/music_track.dart';
import '../../services/cover_palette_cache.dart';
import '../../services/player_controller.dart';
import '../../services/player_sheet_controller.dart';
import '../../widgets/track_cover.dart';

part 'parts/player_helpers.dart';
part 'parts/player_visual_palette.dart';
part 'parts/player_header_widgets.dart';
part 'parts/player_landscape_body.dart';
part 'parts/player_lyrics_widgets.dart';
part 'parts/player_controls.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  // 普通歌词行的默认高度。实际列表高度统一通过
  // _lyricRowHeightForText 计算，滚动定位和 ListView 渲染共用同一套逻辑。
  static const double _lyricRowHeight = 68;

  late final PageController _pageController;
  final _lyricScrollController = ScrollController();

  late final PlayerController controller;
  late final PlayerSheetController sheetController;

  int _activeLyric = 0;
  int _currentPage = 0;
  bool _landscapeLyricPrepared = false;
  String? _lastTrackId;
  double? _lastVerticalDragY;
  StreamSubscription<Duration>? _positionSub;
  Worker? _seekPreviewWorker;
  Worker? _seekStateWorker;
  Worker? _savedPageWorker;
  Worker? _sheetMountedWorker;
  List<LyricLine> _latestTimedLyrics = const [];
  String? _lastParsedLyricRaw;
  List<LyricLine> _cachedTimedLyrics = const [];
  List<String> _cachedPlainLyrics = const [];
  _PlayerVisualPalette? _coverPalette;
  String? _coverPaletteKey;
  Color? _coverSeed;

  @override
  void initState() {
    super.initState();
    controller = Get.find<PlayerController>();
    sheetController = Get.find<PlayerSheetController>();
    _currentPage = controller.playerSheetPage.value.clamp(0, 1).toInt();
    _pageController = PageController(initialPage: _currentPage);

    _positionSub =
        controller.player.positionStream.listen(_handleLyricPosition);
    _seekPreviewWorker = ever<Duration?>(
      controller.seekPreviewPosition,
      (_) => _handleLyricPosition(controller.player.position),
    );
    _seekStateWorker = ever<bool>(
      controller.isUserSeeking,
      (_) => _handleLyricPosition(controller.player.position),
    );
    _savedPageWorker = ever<int>(controller.playerSheetPage, (page) {
      final safePage = page.clamp(0, 1).toInt();
      if (safePage == _currentPage) return;
      _currentPage = safePage;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;

        _pageController.jumpToPage(safePage);

        final isLandscape = MediaQuery.sizeOf(context).width >
            MediaQuery.sizeOf(context).height;

        if (safePage == 0) {
          _landscapeLyricPrepared = false;
          return;
        }

        if (safePage == 1) {
          if (isLandscape) {
            _landscapeLyricPrepared = true;
            _prepareLandscapeLyricScroll(_activeLyric);
          } else {
            _scheduleLyricScroll(_activeLyric, animate: false);
          }
        }
      });
    });
    _sheetMountedWorker =
        ever<bool>(sheetController.isSheetMounted, (mountedSheet) {
      if (!mountedSheet) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleLyricPosition(controller.player.position);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sheetController.setScreenHeight(MediaQuery.sizeOf(context).height);
  }

  void _closePage() {
    if (!mounted) return;
    sheetController.close();
  }

  void _handlePageChanged(int page) {
    if (!mounted) return;

    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    setState(() {
      _currentPage = page;
      if (page == 0) {
        _landscapeLyricPrepared = false;
      }
    });

    unawaited(controller.setPlayerSheetPage(page));

    if (page == 1) {
      if (isLandscape) {
        _landscapeLyricPrepared = true;
        _prepareLandscapeLyricScroll(_activeLyric);
      } else {
        _scheduleLyricScroll(_activeLyric, animate: false);
      }
    }
  }

  void _handlePlayerDragStart(DragStartDetails details) {
    if (!mounted || _currentPage != 0) return;
    _lastVerticalDragY = details.globalPosition.dy;
    sheetController.setScreenHeight(MediaQuery.sizeOf(context).height);
    sheetController.beginInteractiveClose(context);
  }

  void _handlePlayerDragUpdate(DragUpdateDetails details) {
    if (!mounted || _currentPage != 0) return;
    _lastVerticalDragY = details.globalPosition.dy;
    sheetController.isDragging.value = true;
    sheetController.updateDrag(details.primaryDelta ?? 0);
  }

  void _handlePlayerDragEnd(DragEndDetails details) {
    if (!mounted || _currentPage != 0) return;
    sheetController.endDrag(
      velocity: details.primaryVelocity ?? 0,
      releaseY: _lastVerticalDragY,
    );
    _lastVerticalDragY = null;
  }

  void _handlePlayerDragCancel() {
    if (!mounted || _currentPage != 0) return;
    sheetController.endDrag(releaseY: _lastVerticalDragY);
    _lastVerticalDragY = null;
  }

  // 顶部小横条专用拖拽：播放页和歌词页都允许通过小横条下滑关闭。
  // 歌词列表本身不监听下滑，避免和歌词滚动冲突。
  void _handleSheetHandleDragStart(DragStartDetails details) {
    if (!mounted) return;
    _lastVerticalDragY = details.globalPosition.dy;
    sheetController.setScreenHeight(MediaQuery.sizeOf(context).height);
    sheetController.beginInteractiveClose(context);
  }

  void _handleSheetHandleDragUpdate(DragUpdateDetails details) {
    if (!mounted) return;
    _lastVerticalDragY = details.globalPosition.dy;
    sheetController.isDragging.value = true;
    sheetController.updateDrag(details.primaryDelta ?? 0);
  }

  void _handleSheetHandleDragEnd(DragEndDetails details) {
    if (!mounted) return;
    sheetController.endDrag(
      velocity: details.primaryVelocity ?? 0,
      releaseY: _lastVerticalDragY,
    );
    _lastVerticalDragY = null;
  }

  void _handleSheetHandleDragCancel() {
    if (!mounted) return;
    sheetController.endDrag(releaseY: _lastVerticalDragY);
    _lastVerticalDragY = null;
  }

  void _scheduleLyricScroll(int index, {bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (var i = 0; i < 8; i++) {
        if (!mounted) return;
        if (_lyricScrollController.hasClients) {
          _scrollLyricsToActive(index, animate: animate);
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    });
  }

  void _prepareLandscapeLyricScroll(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // 横屏歌词页在 PageView 第二页，切页过程中 ListView 可能还没完成 layout。
      // 多等几帧，确保 controller attach 后立即定位当前歌词。
      for (var i = 0; i < 12; i++) {
        if (!mounted) return;

        if (_lyricScrollController.hasClients) {
          _scrollLyricsToActive(index, animate: false);
          return;
        }

        await Future<void>.delayed(const Duration(milliseconds: 24));
      }
    });
  }

  void _scrollLyricsToActive(int index, {bool animate = true}) {
    if (!mounted || !_lyricScrollController.hasClients) return;

    final position = _lyricScrollController.position;
    final max = position.maxScrollExtent;
    final viewport = position.viewportDimension;
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    var offset = 0.0;
    var currentRowHeight = _lyricRowHeight;

    if (_latestTimedLyrics.isNotEmpty) {
      final safeIndex = index.clamp(0, _latestTimedLyrics.length - 1).toInt();

      for (var i = 0; i < safeIndex; i++) {
        offset += _lyricRowHeightForText(
          _latestTimedLyrics[i].text,
          compactSingleLineRows: isLandscape,
        );
      }

      currentRowHeight = _lyricRowHeightForText(
        _latestTimedLyrics[safeIndex].text,
        compactSingleLineRows: isLandscape,
      );
    } else {
      offset = index * _lyricRowHeight;
    }

    // 用当前歌词的中心点来定位，避免动态行高后当前句偏上。
    final activeCenter = offset + currentRowHeight / 2;

    final target = (activeCenter - viewport * 0.35).clamp(0.0, max).toDouble();

    if (animate) {
      _lyricScrollController.animateTo(
        target,
        duration: Duration(milliseconds: isLandscape ? 120 : 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _lyricScrollController.jumpTo(target);
    }
  }

  int _activeLyricIndex(List<LyricLine> lyrics, Duration position) {
    if (lyrics.isEmpty) return 0;
    final index = lyrics.lastIndexWhere((line) => line.time <= position);
    if (index < 0) return 0;
    if (index >= lyrics.length) return lyrics.length - 1;
    return index;
  }

  void _resetLyricStateIfNeeded(MusicTrack track) {
    if (_lastTrackId == track.id) return;

    _coverPaletteKey = null;
    _lastTrackId = track.id;
    _activeLyric = 0;
    _landscapeLyricPrepared = false;

    if (_currentPage == 1) {
      final isLandscape =
          MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

      if (isLandscape) {
        _prepareLandscapeLyricScroll(0);
      } else {
        _scheduleLyricScroll(0, animate: false);
      }
    }
  }

  void _handleLyricPosition(Duration rawPosition) {
    if (!mounted ||
        !sheetController.isSheetMounted.value ||
        _latestTimedLyrics.isEmpty) {
      return;
    }

    final lyricPosition = controller.lyricPositionFor(rawPosition);
    final nextIndex = _activeLyricIndex(_latestTimedLyrics, lyricPosition);
    if (nextIndex == _activeLyric) return;

    setState(() => _activeLyric = nextIndex);

    if (_currentPage == 1) {
      final isLandscape =
          MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

      if (isLandscape && !_landscapeLyricPrepared) {
        _landscapeLyricPrepared = true;
        _prepareLandscapeLyricScroll(nextIndex);
      } else {
        _scheduleLyricScroll(nextIndex, animate: !isLandscape);
      }
    }
  }

  void _refreshLyricCache(String? rawLyricText) {
    if (_lastParsedLyricRaw == rawLyricText) {
      _latestTimedLyrics = _cachedTimedLyrics;
      return;
    }

    _lastParsedLyricRaw = rawLyricText;
    _cachedTimedLyrics = parseLrc(rawLyricText);
    _cachedPlainLyrics = parsePlainLyrics(rawLyricText);
    _latestTimedLyrics = _cachedTimedLyrics;
  }

  void _ensureCoverPalette(MusicTrack track, ColorScheme scheme) {
    final cache = CoverPaletteCache.instance;
    final requestKey = cache.keyForTrack(track, scheme.brightness);
    if (_coverPaletteKey == requestKey) return;

    _coverPaletteKey = requestKey;

    final cachedSeed = cache.cachedSeedForKey(requestKey);
    if (cachedSeed != null) {
      _coverSeed = cachedSeed;
      _coverPalette = _visualPaletteFromSeed(cachedSeed, scheme.brightness);
      return;
    }

    // 不要在切歌时先重置成默认色。
    // 启动首帧如果没有缓存，才使用当前主题色；只要已有封面 seed，
    // 切换明暗模式时就先用同一 seed 生成新亮度的调色板，避免锁屏恢复后
    // 页面仍短暂停留在旧亮度外观。
    final previousSeed = _coverSeed;
    if (previousSeed != null) {
      _coverPalette = _visualPaletteFromSeed(previousSeed, scheme.brightness);
    } else {
      _coverPalette ??= _visualPaletteFor(scheme);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadCoverPalette(track, scheme, requestKey));
    });
  }

  Future<void> _loadCoverPalette(
    MusicTrack track,
    ColorScheme scheme,
    String requestKey,
  ) async {
    try {
      final seed = await CoverPaletteCache.instance.resolveSeedForTrack(
        track,
        scheme.brightness,
        fallback: scheme.primary,
        sampleSize: const Size(320, 320),
        maximumColorCount: 20,
      );

      if (!mounted || _coverPaletteKey != requestKey) return;

      final resolved = _visualPaletteFromSeed(seed, scheme.brightness);
      setState(() {
        _coverSeed = seed;
        _coverPalette = resolved;
      });
    } catch (_) {
      if (!mounted || _coverPaletteKey != requestKey) return;
      if (_coverPalette == null) {
        setState(() => _coverPalette = _visualPaletteFor(scheme));
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _seekPreviewWorker?.dispose();
    _seekStateWorker?.dispose();
    _savedPageWorker?.dispose();
    _sheetMountedWorker?.dispose();
    _pageController.dispose();
    _lyricScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Obx(() {
      final track = controller.currentTrack;
      if (track == null) {
        return Material(
          type: MaterialType.transparency,
          child: Center(
            child: Text('common.noCurrentTrack'.tr,
                style: TextStyle(color: scheme.onSurface)),
          ),
        );
      }

      _resetLyricStateIfNeeded(track);
      _refreshLyricCache(track.lyricText);
      _ensureCoverPalette(track, scheme);
      final timedLyrics = _cachedTimedLyrics;
      final plainLyrics = _cachedPlainLyrics;
      final visualPalette = _coverPalette ?? _visualPaletteFor(scheme);
      final themePrimary =
          Color.lerp(scheme.primary, visualPalette.accent, 0.45)!;
      final pageScheme = scheme.copyWith(
        surface: visualPalette.background,
        onSurface: visualPalette.onBackground,
        onSurfaceVariant: visualPalette.muted,
        primary: themePrimary,
        onPrimary: scheme.onPrimary,
        surfaceContainer: visualPalette.controlSurface,
        surfaceContainerHigh: visualPalette.controlSurface,
        surfaceContainerHighest: visualPalette.controlSurface,
        outline: visualPalette.divider,
      );
      final pageTheme = Theme.of(context).copyWith(
        colorScheme: pageScheme,
        sliderTheme: SliderTheme.of(context).copyWith(
          activeTrackColor: themePrimary,
          inactiveTrackColor: visualPalette.divider,
          thumbColor: themePrimary,
          overlayColor: themePrimary.withValues(alpha: 0.12),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: themePrimary,
            foregroundColor: scheme.onPrimary,
          ),
        ),
      );

      final isLandscape =
          MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

      return Obx(() {
        final sheetMounted = sheetController.isSheetMounted.value;

        return TickerMode(
          enabled: sheetMounted,
          child: IgnorePointer(
            ignoring: !sheetMounted,
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                children: [
                  Obx(() {
                    final progress =
                        sheetMounted ? sheetController.openProgress : 0.0;
                    return Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: sheetController.isDragging.value
                              ? Duration.zero
                              : PlayerSheetController.sheetAnimationDuration,
                          color: Colors.black.withValues(
                              alpha: PlayerSheetController.backdropMaxOpacity *
                                  progress),
                        ),
                      ),
                    );
                  }),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: screenHeight,
                    child: Obx(() {
                      final offset = sheetMounted
                          ? sheetController.sheetOffset.value
                          : screenHeight;
                      final progress =
                          sheetMounted ? sheetController.openProgress : 0.0;
                      final opacity = progress <= 0
                          ? 0.0
                          : progress >= 0.98
                              ? 1.0
                              : (PlayerSheetController.sheetMinOpacity +
                                      progress *
                                          (1 -
                                              PlayerSheetController
                                                  .sheetMinOpacity))
                                  .clamp(0.0, 1.0)
                                  .toDouble();
                      final duration = sheetController.isDragging.value
                          ? Duration.zero
                          : PlayerSheetController.sheetAnimationDuration;

                      return AnimatedContainer(
                        duration: duration,
                        curve: Curves.easeOutQuart,
                        transform: Matrix4.translationValues(0, offset, 0),
                        child: AnimatedOpacity(
                          duration: duration,
                          opacity: opacity,
                          child: AnimatedTheme(
                            data: pageTheme,
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutCubic,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    visualPalette.background,
                                    visualPalette.backgroundEnd,
                                  ],
                                ),
                              ),
                              child: SafeArea(
                                top: false,
                                child: Column(
                                  children: [
                                    _PlayerTopBar(
                                      onTap: _closePage,
                                      onVerticalDragStart:
                                          _handleSheetHandleDragStart,
                                      onVerticalDragUpdate:
                                          _handleSheetHandleDragUpdate,
                                      onVerticalDragEnd:
                                          _handleSheetHandleDragEnd,
                                      onVerticalDragCancel:
                                          _handleSheetHandleDragCancel,
                                    ),
                                    if (isLandscape)
                                      Expanded(
                                        child: _LandscapePlayerBody(
                                          track: track,
                                          controller: controller,
                                          timedLyrics: timedLyrics,
                                          plainLyrics: plainLyrics,
                                          activeIndex: _activeLyric,
                                          currentPage: _currentPage,
                                          onPageChanged: _handlePageChanged,
                                          lyricScrollController:
                                              _lyricScrollController,
                                        ),
                                      )
                                    else ...[
                                      _PlayerCommonHeader(
                                        track: track,
                                        controller: controller,
                                        showLyricAlign: _currentPage == 1,
                                      ),
                                      Expanded(
                                        child: PageView(
                                          controller: _pageController,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          onPageChanged: _handlePageChanged,
                                          children: [
                                            GestureDetector(
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onVerticalDragStart:
                                                  _handlePlayerDragStart,
                                              onVerticalDragUpdate:
                                                  _handlePlayerDragUpdate,
                                              onVerticalDragEnd:
                                                  _handlePlayerDragEnd,
                                              onVerticalDragCancel:
                                                  _handlePlayerDragCancel,
                                              child: _NowPlayingPage(
                                                track: track,
                                                controller: controller,
                                                timedLyrics: timedLyrics,
                                                plainLyrics: plainLyrics,
                                                activeIndex: _activeLyric,
                                              ),
                                            ),
                                            _LyricsPage(
                                              controller: controller,
                                              timedLyrics: timedLyrics,
                                              plainLyrics: plainLyrics,
                                              activeIndex: _activeLyric,
                                              scrollController:
                                                  _lyricScrollController,
                                              onLyricTap: (time) => unawaited(
                                                  controller.commitSeek(time)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _Controls(
                                        controller: controller,
                                        layout: _ControlsLayout.portrait,
                                      ),
                                      SizedBox(
                                        height: MediaQuery.paddingOf(context)
                                                    .bottom >
                                                0
                                            ? 10
                                            : 22,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        );
      });
    });
  }
}
