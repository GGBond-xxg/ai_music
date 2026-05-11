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

String _musicSourceLabel(MusicSourceType sourceType) {
  switch (sourceType) {
    case MusicSourceType.localFile:
      return 'source.local'.tr;
    case MusicSourceType.webDav:
      return 'WebDAV';
    case MusicSourceType.emby:
      return 'Emby';
    case MusicSourceType.jellyfin:
      return 'Jellyfin';
    case MusicSourceType.navidrome:
      return 'Navidrome';
    case MusicSourceType.directUrl:
      return 'common.networkMusic'.tr;
  }
}

Alignment _alignmentForTextAlign(TextAlign align) {
  switch (align) {
    case TextAlign.left:
    case TextAlign.start:
      return Alignment.centerLeft;
    case TextAlign.right:
    case TextAlign.end:
      return Alignment.centerRight;
    case TextAlign.center:
    default:
      return Alignment.center;
  }
}

class _SplitLyricLine {
  const _SplitLyricLine(this.primary, [this.secondary]);

  final String primary;
  final String? secondary;
}

final RegExp _cjkRegExp = RegExp(r'[\u3400-\u9FFF\uF900-\uFAFF]');
final RegExp _kanaRegExp = RegExp(r'[\u3040-\u30FF]');
final RegExp _latinRegExp = RegExp(r'[A-Za-z]');

int _scriptCount(String value, RegExp pattern) {
  var count = 0;
  for (final match in pattern.allMatches(value)) {
    count += match.group(0)?.length ?? 0;
  }
  return count;
}

bool _isMostlyLatin(String value) {
  final cleaned =
      value.replaceAll(RegExp(r'[^A-Za-z\u3400-\u9FFF\uF900-\uFAFF]'), '');
  if (cleaned.length < 4) return false;
  final latin = _scriptCount(cleaned, _latinRegExp);
  final cjk = _scriptCount(cleaned, _cjkRegExp);
  return latin >= 4 && cjk == 0;
}

bool _isMostlyCjk(String value) {
  final cleaned =
      value.replaceAll(RegExp(r'[^A-Za-z\u3400-\u9FFF\uF900-\uFAFF]'), '');
  if (cleaned.length < 2) return false;
  final latin = _scriptCount(cleaned, _latinRegExp);
  final cjk = _scriptCount(cleaned, _cjkRegExp);
  return cjk >= 2 && latin == 0;
}

bool _hasKana(String value) => _kanaRegExp.hasMatch(value);

bool _looksLikeChineseTranslation(String value) {
  final cleaned = value.replaceAll(
    RegExp(r'[^\u3400-\u9FFF\uF900-\uFAFF\u3040-\u30FF]'),
    '',
  );
  if (cleaned.length < 2) return false;
  return _cjkRegExp.hasMatch(cleaned) && !_kanaRegExp.hasMatch(cleaned);
}

bool _hasNaturalSplitBoundary(String value, int index) {
  final before = index > 0 ? value[index - 1] : '';
  final after = index < value.length ? value[index] : '';
  return RegExp(r'\s|[，。！？；：,.!?;:()（）「」『』《》\[\]]').hasMatch(before) ||
      RegExp(r'\s|[，。！？；：,.!?;:()（）「」『』《》\[\]]').hasMatch(after);
}

String _cleanLyricPart(String value) {
  return value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[·•\-–—|/]+$'), '')
      .trim();
}

/// 歌词展示文本只做清理，不再插入零宽空格。
///
/// 之前为了让超长英文 / URL 可换行，这里会主动插入 `\u200B`，
/// 但带翻译歌词会因此自动断行。现在统一交给 Text 的
/// `maxLines: 1 + overflow: ellipsis + softWrap: false` 单行省略。
String _safeLyricDisplayText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// 识别双语歌词的原文和翻译。
///
/// 注意：这里只负责识别，不负责换行显示。歌词列表会把原文和翻译
/// 拼成单行展示，超出宽度直接省略，避免带翻译歌词自动变成两行。
_SplitLyricLine _splitLyricLine(String text) {
  final hardLines = text
      .split(RegExp(r'\n+'))
      .map(_cleanLyricPart)
      .where((line) => line.isNotEmpty)
      .toList();

  if (hardLines.length >= 2) {
    return _SplitLyricLine(
      hardLines.first,
      hardLines.skip(1).join(' '),
    );
  }

  final normalized = _cleanLyricPart(text);
  if (normalized.isEmpty) return const _SplitLyricLine('');

  final hasCjk = _cjkRegExp.hasMatch(normalized);
  final hasKana = _kanaRegExp.hasMatch(normalized);
  final hasLatin = _latinRegExp.hasMatch(normalized);

  // 日文原文 + 中文翻译：两边都属于 CJK，不能只靠英文识别。
  // 一边含假名，另一边是纯中文时，也拆成上下两行。
  if (hasKana && hasCjk) {
    for (var i = 1; i < normalized.length; i++) {
      if (!_hasNaturalSplitBoundary(normalized, i)) continue;

      final left = _cleanLyricPart(normalized.substring(0, i));
      final right = _cleanLyricPart(normalized.substring(i));
      if (left.isEmpty || right.isEmpty) continue;

      final leftJapaneseRightChinese =
          _hasKana(left) && _looksLikeChineseTranslation(right);
      final leftChineseRightJapanese =
          _looksLikeChineseTranslation(left) && _hasKana(right);

      if (leftJapaneseRightChinese || leftChineseRightJapanese) {
        return _SplitLyricLine(left, right);
      }
    }
  }

  if (!hasCjk || !hasLatin) return _SplitLyricLine(normalized);

  // 只拆“明显的双语歌词”：一边主要是英文，另一边主要是中文，且中间有空格/标点边界。
  // 像“因为 MUSIC-MAN 的到来”这种中文句子中夹英文名词，不再误拆成翻译。
  for (var i = 1; i < normalized.length; i++) {
    if (!_hasNaturalSplitBoundary(normalized, i)) continue;

    final left = _cleanLyricPart(normalized.substring(0, i));
    final right = _cleanLyricPart(normalized.substring(i));
    if (left.isEmpty || right.isEmpty) continue;

    final leftLatinRightCjk = _isMostlyLatin(left) && _isMostlyCjk(right);
    final leftCjkRightLatin = _isMostlyCjk(left) && _isMostlyLatin(right);

    if (leftLatinRightCjk || leftCjkRightLatin) {
      return _SplitLyricLine(left, right);
    }
  }

  return _SplitLyricLine(normalized);
}

/// 将原文 + 翻译合成单行展示文本。
///
/// parseLrc 对同一时间戳的原文/翻译会用 \n 合并，
/// 这里统一改成空格连接，避免 UI 中出现第二行翻译。
String _singleLineLyricText(String text) {
  final split = _splitLyricLine(text);
  final parts = <String>[
    _safeLyricDisplayText(split.primary),
    if (split.secondary != null) _safeLyricDisplayText(split.secondary!),
  ].where((part) => part.isNotEmpty).toList();

  return parts.join('   ');
}

double _lyricRowHeightForText(
  String _, {
  required bool compactSingleLineRows,
}) {
  // 歌词列表统一单行：原文 + 翻译在同一行内展示，超出省略。
  // 不再因为有翻译而加高行高，避免视觉上变成“自动换行”。
  return compactSingleLineRows ? 60.0 : 68.0;
}

class _PlayerVisualPalette {
  const _PlayerVisualPalette({
    required this.background,
    required this.backgroundEnd,
    required this.onBackground,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.divider,
    required this.controlSurface,
  });

  final Color background;
  final Color backgroundEnd;
  final Color onBackground;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color divider;
  final Color controlSurface;
}

_PlayerVisualPalette _visualPaletteFor(ColorScheme scheme) {
  final isDark = scheme.brightness == Brightness.dark;
  return _PlayerVisualPalette(
    background: scheme.surface,
    backgroundEnd: scheme.surfaceContainerHighest,
    onBackground: scheme.onSurface,
    muted: scheme.onSurfaceVariant,
    accent: scheme.primary,
    onAccent: scheme.onPrimary,
    divider: scheme.onSurfaceVariant.withValues(alpha: isDark ? 0.22 : 0.16),
    controlSurface:
        isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerHighest,
  );
}

Color _mixColor(Color a, Color b, double amount) {
  return Color.lerp(a, b, amount) ?? a;
}

_PlayerVisualPalette _visualPaletteFromSeed(
  Color seed,
  Brightness brightness,
) {
  final isDark = brightness == Brightness.dark;
  final normalized = HSLColor.fromColor(seed).withSaturation(
    HSLColor.fromColor(seed).saturation.clamp(0.22, 0.72).toDouble(),
  );
  final tone = normalized.toColor();

  final background = isDark
      ? _mixColor(const Color(0xFF07080C), tone, 0.46)
      : _mixColor(const Color(0xFFF7F5FB), tone, 0.32);
  final backgroundEnd = isDark
      ? _mixColor(background, Colors.black, 0.14)
      : _mixColor(background, tone, 0.10);
  final controlSurface = isDark
      ? _mixColor(background, Colors.white, 0.12)
      : _mixColor(background, Colors.white, 0.16);
  final accent = isDark
      ? _mixColor(tone, Colors.white, 0.10)
      : _mixColor(tone, Colors.black, 0.08);

  final onBackground =
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
          ? Colors.white
          : const Color(0xFF131313);
  final onAccent =
      ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
          ? Colors.white
          : const Color(0xFF111111);

  return _PlayerVisualPalette(
    background: background,
    backgroundEnd: backgroundEnd,
    onBackground: onBackground,
    muted: onBackground.withValues(alpha: 0.74),
    accent: accent,
    onAccent: onAccent,
    divider: onBackground.withValues(alpha: isDark ? 0.18 : 0.12),
    controlSurface: controlSurface,
  );
}

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
      _coverPalette = _visualPaletteFromSeed(cachedSeed, scheme.brightness);
      return;
    }

    // 不要在切歌时先重置成默认色。
    // 启动首帧如果没有缓存，才使用当前主题色；只要缓存存在，第一帧就是封面色。
    _coverPalette ??= _visualPaletteFor(scheme);

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
      setState(() => _coverPalette = resolved);
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
                          child: Theme(
                            data: pageTheme,
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

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.onTap,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onVerticalDragCancel,
  });

  final VoidCallback onTap;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final GestureDragCancelCallback onVerticalDragCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top;
    final landscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final barHeight = top + (landscape ? 30 : 42);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onVerticalDragStart: onVerticalDragStart,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      onVerticalDragCancel: onVerticalDragCancel,
      child: SizedBox(
        height: barHeight,
        width: double.infinity,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: landscape ? 8 : 10),
            child: Container(
              width: 88,
              height: 5,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerCommonHeader extends StatelessWidget {
  const _PlayerCommonHeader({
    required this.track,
    required this.controller,
    required this.showLyricAlign,
  });

  final MusicTrack track;
  final PlayerController controller;
  final bool showLyricAlign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isLandscape ? 24 : 30,
        isLandscape ? 0 : 0,
        isLandscape ? 24 : 30,
        isLandscape ? 12 : 16,
      ),
      child: Row(
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: isLandscape ? 22 : 28,
                        height: 1.08,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  track.artist ?? 'Unknown Artist',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                ),
              ],
            ),
          ),
          // 右上角区域固定宽高，避免从播放页滑到歌词页时，
          // “靠左/居中/靠右”按钮出现后把标题区域顶一下。
          SizedBox(
            width: isLandscape ? 112 : 118,
            height: 38,
            child: Align(
              alignment: Alignment.topRight,
              child: showLyricAlign
                  ? _LyricAlignChip(controller: controller)
                  : _MusicSourceChip(track: track),
            ),
          ),
        ],
      ),
    );
  }
}

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
          height: 1.2,
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

enum _ControlsLayout {
  portrait,
  landscape,
}

class _Controls extends StatefulWidget {
  const _Controls({
    required this.controller,
    this.layout = _ControlsLayout.portrait,
  });

  final PlayerController controller;
  final _ControlsLayout layout;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  Duration? _dragPosition;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
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

  Future<void> _openSleepTimerSheet(BuildContext context) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (_) => _SleepTimerSheet(controller: widget.controller),
    );
  }

  Widget _buildProgressBar(
    BuildContext context, {
    required double verticalPadding,
    required double horizontalPadding,
  }) {
    final controller = widget.controller;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      // 这里控制整体左右边距，想更长就改小，比如 8 / 10 / 12
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
      child: StreamBuilder<Duration?>(
        stream: controller.player.durationStream,
        builder: (context, durationSnapshot) {
          final duration = durationSnapshot.data ?? Duration.zero;

          return StreamBuilder<Duration>(
            stream: controller.player.positionStream,
            builder: (context, positionSnapshot) {
              final rawPosition = positionSnapshot.data ?? Duration.zero;

              return Obx(() {
                final preview = controller.seekPreviewPosition.value;
                final effectivePosition = _dragPosition ??
                    (controller.isUserSeeking.value ? preview : null) ??
                    rawPosition;

                final safePosition = duration == Duration.zero
                    ? Duration.zero
                    : (effectivePosition > duration
                        ? duration
                        : effectivePosition);

                final maxMs = duration.inMilliseconds <= 0
                    ? 1.0
                    : duration.inMilliseconds.toDouble();

                final value = duration.inMilliseconds <= 0
                    ? 0.0
                    : safePosition.inMilliseconds
                        .clamp(0, duration.inMilliseconds)
                        .toDouble();

                final progress = (value / maxMs).clamp(0.0, 1.0).toDouble();

                Duration positionFromDx(double dx, double width) {
                  final ratio = (dx / width).clamp(0.0, 1.0);
                  return Duration(milliseconds: (ratio * maxMs).round());
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final barWidth = constraints.maxWidth;
                        const barHeight = 3.2;
                        const touchHeight = 28.0;

                        return GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapDown: (details) {
                            final pos = positionFromDx(
                              details.localPosition.dx,
                              barWidth,
                            );
                            unawaited(controller.commitSeek(pos));
                          },
                          onHorizontalDragStart: (details) {
                            final pos = positionFromDx(
                              details.localPosition.dx,
                              barWidth,
                            );
                            setState(() => _dragPosition = pos);
                            controller.beginSeek(pos);
                          },
                          onHorizontalDragUpdate: (details) {
                            final pos = positionFromDx(
                              details.localPosition.dx,
                              barWidth,
                            );
                            setState(() => _dragPosition = pos);
                            controller.previewSeek(pos);
                          },
                          onHorizontalDragEnd: (_) {
                            final pos = _dragPosition;
                            setState(() => _dragPosition = null);
                            if (pos != null) {
                              unawaited(controller.commitSeek(pos));
                            }
                          },
                          onHorizontalDragCancel: () {
                            setState(() => _dragPosition = null);
                          },
                          child: SizedBox(
                            width: double.infinity,
                            height: touchHeight,
                            child: Align(
                              alignment: Alignment.center,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: scheme.outline
                                          .withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: progress,
                                    child: Container(
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        borderRadius:
                                            BorderRadius.circular(999),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(safePosition),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              });
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactWidth = constraints.maxWidth < 360;
        final isLandscapeControls = widget.layout == _ControlsLayout.landscape;

        final sideIconSize = isLandscapeControls
            ? (compactWidth ? 24.0 : 26.0)
            : (compactWidth ? 24.0 : 27.0);

        final skipIconSize = isLandscapeControls
            ? (compactWidth ? 24.0 : 27.0)
            : (compactWidth ? 31.0 : 35.0);

        final playIconSize = isLandscapeControls
            ? (compactWidth ? 40.0 : 39.0)
            : (compactWidth ? 48.0 : 54.0);

        final progressPadding = isLandscapeControls
            ? (compactWidth ? 0.0 : 4.0)
            : (compactWidth ? 22.0 : 30.0);

        final buttonsPadding =
            isLandscapeControls ? 0.0 : (compactWidth ? 18.0 : 28.0);

        final controlGap = isLandscapeControls
            ? (compactWidth ? 8.0 : 13.0)
            : (compactWidth ? 12.0 : 16.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProgressBar(
              context,
              verticalPadding: controlGap,
              horizontalPadding: progressPadding,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: buttonsPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  isLandscapeControls
                      ? const SizedBox.shrink()
                      : Obx(() {
                          return _PlayerControlIconButton(
                            tooltip: controller.playMode.value.label,
                            icon: _modeIcon(controller.playMode.value),
                            iconSize: sideIconSize,
                            color: scheme.primary,
                            onPressed: controller.cyclePlayMode,
                          );
                        }),
                  _PlayerControlIconButton(
                    tooltip: 'common.previous'.tr,
                    icon: Icons.skip_previous_rounded,
                    iconSize: skipIconSize,
                    color: scheme.primary,
                    onPressed: controller.previous,
                  ),
                  Obx(() {
                    final playing = controller.isPlayingNow.value;
                    return _PlayerControlIconButton(
                      tooltip: playing ? 'common.pause'.tr : 'common.play'.tr,
                      icon: playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      iconSize: playIconSize,
                      color: scheme.primary,
                      onPressed: controller.togglePlay,
                    );
                  }),
                  _PlayerControlIconButton(
                    tooltip: 'common.next'.tr,
                    icon: Icons.skip_next_rounded,
                    iconSize: skipIconSize,
                    color: scheme.primary,
                    onPressed: controller.next,
                  ),
                  isLandscapeControls
                      ? const SizedBox.shrink()
                      : Obx(() {
                          final active =
                              controller.sleepTimerRemaining.value != null;
                          return _PlayerControlIconButton(
                            tooltip: active
                                ? 'player.timerWithLabel'.trParams(
                                    {'label': controller.sleepTimerLabel})
                                : 'player.timerLabel'.tr,
                            icon: active
                                ? Icons.timer_rounded
                                : Icons.timer_outlined,
                            iconSize: sideIconSize,
                            color: scheme.primary,
                            onPressed: () => _openSleepTimerSheet(context),
                          );
                        }),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                isLandscapeControls
                    ? Obx(() {
                        return _PlayerControlIconButton(
                          tooltip: controller.playMode.value.label,
                          icon: _modeIcon(controller.playMode.value),
                          iconSize: sideIconSize,
                          color: scheme.primary,
                          onPressed: controller.cyclePlayMode,
                        );
                      })
                    : const SizedBox.shrink(),
                isLandscapeControls
                    ? Obx(() {
                        final active =
                            controller.sleepTimerRemaining.value != null;
                        return _PlayerControlIconButton(
                          tooltip: active
                              ? 'player.timerWithLabel'.trParams(
                                  {'label': controller.sleepTimerLabel})
                              : 'player.timerLabel'.tr,
                          icon: active
                              ? Icons.timer_rounded
                              : Icons.timer_outlined,
                          iconSize: sideIconSize,
                          color: scheme.primary,
                          onPressed: () => _openSleepTimerSheet(context),
                        );
                      })
                    : const SizedBox.shrink(),
              ],
            ),
            // SizedBox(height: isLandscapeControls ? 58 : 0),
          ],
        );
      },
    );
  }
}

class _PlayerControlIconButton extends StatelessWidget {
  const _PlayerControlIconButton({
    required this.tooltip,
    required this.icon,
    required this.iconSize,
    required this.color,
    required this.onPressed, // 将方括号改为花括号
  });

  final String tooltip;
  final IconData icon;
  final double iconSize;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      iconSize: iconSize,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: BoxConstraints.tightFor(
        width: math.max(iconSize + 10, 34).toDouble(),
        height: math.max(iconSize + 10, 34).toDouble(),
      ),
      onPressed: onPressed,
      color: color,
      icon: Icon(
        icon,
      ),
    );
  }
}

class _SleepTimerSheet extends StatefulWidget {
  const _SleepTimerSheet({required this.controller});

  final PlayerController controller;

  @override
  State<_SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<_SleepTimerSheet> {
  late final TextEditingController _minutesController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _minutesController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _startTimer(int minutes) {
    if (minutes <= 0) return;
    widget.controller.startSleepTimer(Duration(minutes: minutes));
    Navigator.of(context).maybePop();
  }

  void _startCustomTimer() {
    final raw = _minutesController.text.trim();
    final minutes = int.tryParse(raw);
    if (minutes == null || minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('player.invalidMinutes'.tr)),
      );
      return;
    }
    _startTimer(minutes.clamp(1, 24 * 60).toInt());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final presets = const [5, 10, 15, 30];

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color:
                              scheme.onSurfaceVariant.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'player.sleepTimer'.tr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Obx(() {
                      final remaining =
                          widget.controller.sleepTimerRemaining.value;
                      return Text(
                        remaining == null
                            ? 'player.sleepTimerDesc'.tr
                            : 'player.currentRemaining'.trParams(
                                {'label': widget.controller.sleepTimerLabel}),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final minutes in presets)
                          FilledButton.tonal(
                            onPressed: () => _startTimer(minutes),
                            child: Text('player.minutes'
                                .trParams({'minutes': '$minutes'})),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minutesController,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _startCustomTimer(),
                            decoration: InputDecoration(
                              labelText: 'player.customMinutes'.tr,
                              hintText: 'player.customMinutesHint'.tr,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _startCustomTimer,
                          child: Text('player.start'.tr),
                        ),
                      ],
                    ),
                    Obx(() {
                      if (widget.controller.sleepTimerRemaining.value == null) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              widget.controller.cancelSleepTimer();
                              Navigator.of(context).maybePop();
                            },
                            child: Text('player.cancelCurrentTimer'.tr),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
