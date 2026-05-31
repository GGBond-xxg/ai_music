import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/lyric_line.dart';
import '../providers/spotify_provider.dart';
import '../services/lyrics_service.dart';
import '../services/ui_texts.dart';
import '../utils/lyrics_parser.dart';
import '../utils/responsive.dart';

final ValueNotifier<int> lyricsCenterLineRequest = ValueNotifier<int>(0);

class LyricsWidget extends StatefulWidget {
  const LyricsWidget({super.key});

  @override
  State<LyricsWidget> createState() => _LyricsWidgetState();
}

class _LyricsWidgetState extends State<LyricsWidget>
    with AutomaticKeepAliveClientMixin<LyricsWidget> {
  final LyricsService _lyricsService = LyricsService();
  ScrollController _scrollController = ScrollController();

  String? _trackId;
  String? _scheduledTrackId;
  List<LyricLine> _lyrics = const [];
  List<GlobalKey> _lineKeys = const [];
  bool _isLoading = false;
  bool _synced = true;
  bool _autoScroll = true;
  bool _copyMode = false;
  bool _userScrolling = false;
  int _lastScrolledIndex = -1;
  Timer? _resumeAutoScrollTimer;
  Timer? _hideQuickActionsTimer;
  bool _manualQuickActionsVisible = false;
  String? _lyricsSourceLabel;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    lyricsCenterLineRequest.addListener(_handleCenterLineRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final item = context.read<SpotifyProvider>().currentTrack?['item']
          as Map<String, dynamic>?;
      _scheduleLoadForTrack(item, force: true);
    });
  }

  @override
  void dispose() {
    lyricsCenterLineRequest.removeListener(_handleCenterLineRequest);
    _resumeAutoScrollTimer?.cancel();
    _hideQuickActionsTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleLoadForTrack(Map<String, dynamic>? item, {bool force = false}) {
    final nextId = item?['id']?.toString();
    if (nextId == null || nextId.isEmpty) return;
    if (!force && nextId == _trackId) return;
    if (_scheduledTrackId == nextId) return;

    _scheduledTrackId = nextId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scheduledTrackId != nextId) return;
      _scheduledTrackId = null;
      unawaited(_loadForTrack(item));
    });
  }

  Future<void> _loadForTrack(Map<String, dynamic>? item) async {
    final nextId = item?['id']?.toString();
    if (nextId == null || nextId.isEmpty || nextId == _trackId) return;

    _trackId = nextId;
    _lastScrolledIndex = -1;
    _manualQuickActionsVisible = false;
    _lyricsSourceLabel = null;
    _resumeAutoScrollTimer?.cancel();
    _hideQuickActionsTimer?.cancel();
    _resetScrollController();

    if (mounted) {
      setState(() {
        _isLoading = true;
        _lyrics = const [];
        _lineKeys = const [];
        _synced = true;
        _autoScroll = true;
        _copyMode = false;
      });
      _jumpLyricsScrollToTop();
    }

    final embedded = item?['lyricText']?.toString().trim();
    String? rawLyrics =
        embedded != null && embedded.isNotEmpty ? embedded : null;
    String? sourceLabel =
        rawLyrics != null ? _embeddedLyricsSource(item) : null;

    if (rawLyrics == null) {
      final title = item?['name']?.toString() ?? '';
      final artists = item?['artists'];
      final artist = artists is List && artists.isNotEmpty
          ? artists.first['name']?.toString() ?? ''
          : '';
      final result = await _lyricsService.getLyrics(title, artist, nextId);
      rawLyrics = result?.lyric;
      sourceLabel =
          result == null ? null : _providerDisplayName(result.provider);
    }

    if (!mounted || nextId != _trackId) return;

    final parsed = _parseOriginalOnly(rawLyrics ?? '');
    setState(() {
      _lyrics = parsed.lines;
      _lineKeys = List.generate(parsed.lines.length, (_) => GlobalKey());
      _synced = parsed.synced;
      _lyricsSourceLabel = sourceLabel;
      _isLoading = false;
      _autoScroll = true;
      _copyMode = false;
      _userScrolling = false;
      _manualQuickActionsVisible = false;
    });
    _jumpLyricsScrollToTop();
  }

  String _embeddedLyricsSource(Map<String, dynamic>? item) {
    final sourceType = item?['sourceType']?.toString();
    final sourceLabel = item?['sourceLabel']?.toString();
    if (sourceLabel != null && sourceLabel.trim().isNotEmpty) {
      return sourceLabel.trim();
    }
    switch (sourceType) {
      case 'localFile':
        return '本地音乐';
      case 'webDav':
        return 'NAS / WebDAV';
      case 'emby':
        return 'Emby';
      case 'jellyfin':
        return 'Jellyfin';
      case 'navidrome':
        return 'Navidrome / Subsonic';
      default:
        return '内嵌歌词';
    }
  }

  String _providerDisplayName(String provider) {
    final normalized = provider.trim().toLowerCase();
    switch (normalized) {
      case 'netease':
        return '网易云音乐';
      case 'qq':
        return 'QQ音乐';
      case 'lrclib':
        return 'LRCLIB';
      default:
        return provider.trim().isEmpty ? '网络歌词' : provider.trim();
    }
  }

  void _resetScrollController() {
    final oldController = _scrollController;
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        oldController.dispose();
      } catch (_) {}
    });
  }

  void _jumpLyricsScrollToTop() {
    _lastScrolledIndex = -1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.pixels <= position.minScrollExtent + 1) return;
      try {
        _scrollController.jumpTo(position.minScrollExtent);
      } catch (_) {}
    });
  }

  _ParsedLyrics _parseOriginalOnly(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return const _ParsedLyrics([], true);

    final hasSynced = LyricsParser.hasSyncedTimestamps(value);
    final parsed = hasSynced
        ? LyricsParser.parseSyncedLyrics(value)
        : LyricsParser.parseUnsyncedLyrics(value);

    // 只删除翻译：很多 LRC 翻译行与原文共用同一个时间戳。
    // 同一时间戳保留第一行，后续重复时间戳视为翻译/附加行。
    final seenSyncedTimestamps = <int>{};
    final originalOnly = <LyricLine>[];
    for (final line in parsed) {
      final text = line.text.trim();
      if (text.isEmpty || _isMetadataLine(text)) continue;
      final key = line.timestamp.inMilliseconds;
      if (hasSynced && !seenSyncedTimestamps.add(key)) continue;
      originalOnly.add(LyricLine(line.timestamp, text));
    }

    return _ParsedLyrics(originalOnly, hasSynced);
  }

  bool _isMetadataLine(String text) {
    final lower = text.toLowerCase();
    const keywords = [
      '作词',
      '作曲',
      '编曲',
      '制作',
      '歌词贡献者',
      '翻译贡献者',
      'translator',
      'translation',
      'composer',
      'lyricist',
      'producer',
    ];
    return keywords.any((keyword) => lower.startsWith(keyword.toLowerCase()));
  }

  int _currentLineIndex(int progressMs) {
    if (_lyrics.isEmpty || !_synced) return -1;
    final position = Duration(milliseconds: progressMs);
    return LyricsParser.getCurrentLineIndex(_lyrics, position);
  }

  void _scrollToCurrentLine(int index, {bool force = false}) {
    if (index < 0 || index >= _lineKeys.length) return;
    if (!force && !_autoScroll) return;
    if (!force && (_userScrolling || _copyMode)) return;
    if (!force && index == _lastScrolledIndex) return;
    _lastScrolledIndex = index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scrollController.hasClients ||
          index >= _lineKeys.length) {
        return;
      }
      final targetContext = _lineKeys[index].currentContext;
      if (targetContext == null) return;
      final target = targetContext.findRenderObject();
      if (target == null) return;

      // Do not use Scrollable.ensureVisible here: LyricsWidget lives inside a
      // horizontal PageView, and ensureVisible can also scroll that PageView,
      // which makes the app jump back to the playing page while the user is in
      // Library or Music Sources. Calculate the offset for this vertical lyrics
      // scroll controller only.
      final viewport = RenderAbstractViewport.of(target);
      final position = _scrollController.position;
      final targetOffset = viewport.getOffsetToReveal(target, 0.44).offset;
      final clamped = targetOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );

      if ((position.pixels - clamped).abs() < 2) return;
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handleUserScroll(ScrollNotification notification) {
    final userInitiated = notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle ||
        notification is ScrollStartNotification &&
            notification.dragDetails != null ||
        notification is ScrollUpdateNotification &&
            notification.dragDetails != null ||
        notification is OverscrollNotification &&
            notification.dragDetails != null;
    if (!userInitiated) return;

    _userScrolling = true;
    _resumeAutoScrollTimer?.cancel();
    if (_autoScroll) {
      setState(() => _autoScroll = false);
    }
    _showManualQuickActionsTemporarily();
    _resumeAutoScrollTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      _userScrolling = false;
      if (!_copyMode && _synced && _lyrics.isNotEmpty) {
        setState(() {
          _autoScroll = true;
          _manualQuickActionsVisible = true;
        });
        final provider = context.read<SpotifyProvider>();
        final progress = provider.currentTrack?['progress_ms'] as int? ?? 0;
        _lastScrolledIndex = -1;
        _scrollToCurrentLine(_currentLineIndex(progress));
      }
    });
  }

  void _showManualQuickActionsTemporarily() {
    if (_lyrics.isEmpty || _copyMode) return;
    _hideQuickActionsTimer?.cancel();
    if (!_manualQuickActionsVisible) {
      setState(() => _manualQuickActionsVisible = true);
    }
  }

  void _handleCenterLineRequest() {
    if (!_synced || _lyrics.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumpToCurrentLine();
    });
  }

  void _jumpToCurrentLine() {
    if (!_synced || _lyrics.isEmpty) return;
    _resumeAutoScrollTimer?.cancel();
    _hideQuickActionsTimer?.cancel();
    if (mounted) {
      setState(() {
        _autoScroll = true;
        _copyMode = false;
        _userScrolling = false;
        _manualQuickActionsVisible = true;
      });
    }
    final provider = context.read<SpotifyProvider>();
    final progress = provider.currentTrack?['progress_ms'] as int? ?? 0;
    _lastScrolledIndex = -1;
    _scrollToCurrentLine(_currentLineIndex(progress), force: true);
    _hideQuickActionsTimer?.cancel();
    _hideQuickActionsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_copyMode) {
        setState(() => _manualQuickActionsVisible = false);
      }
    });
  }

  void _enableAutoScroll() => _jumpToCurrentLine();

  void _toggleCopyMode() {
    setState(() {
      _copyMode = !_copyMode;
      if (_copyMode) {
        _autoScroll = false;
        _manualQuickActionsVisible = true;
      } else {
        _autoScroll = true;
        _manualQuickActionsVisible = false;
      }
    });
  }

  Map<String, dynamic>? _currentTrackItem() {
    return context.read<SpotifyProvider>().currentTrack?['item']
        as Map<String, dynamic>?;
  }

  String _trackTitle(Map<String, dynamic>? item) =>
      item?['name']?.toString() ?? '';

  String _trackArtist(Map<String, dynamic>? item) {
    final artists = item?['artists'];
    if (artists is List && artists.isNotEmpty) {
      final first = artists.first;
      if (first is Map) return first['name']?.toString() ?? '';
    }
    return '';
  }

  Future<List<LyricsCandidate>> _loadLyricsCandidates(
    Map<String, dynamic>? item,
  ) async {
    final title = _trackTitle(item);
    final artist = _trackArtist(item);
    final results = <LyricsCandidate>[];

    final embedded = item?['lyricText']?.toString().trim();
    if (embedded != null && embedded.isNotEmpty) {
      results.add(
        LyricsCandidate(
          provider: 'embedded',
          songId: item?['id']?.toString() ?? 'embedded',
          title: title.isEmpty ? '当前歌曲' : title,
          artist: artist,
          lyric: embedded,
          isEmbedded: true,
        ),
      );
    }

    final networkResults = await _lyricsService.searchLyricsCandidates(
      title,
      artist,
      limitPerProvider: 4,
    );
    results.addAll(networkResults);
    return results;
  }

  Future<void> _showLyricsSourceSelector() async {
    final item = _currentTrackItem();
    final trackId = item?['id']?.toString();
    if (item == null || trackId == null || trackId.isEmpty) return;

    final future = _loadLyricsCandidates(item);
    final selected = await showModalBottomSheet<LyricsCandidate>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择歌词来源',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '为当前歌曲搜索可用歌词，点击即可切换。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FutureBuilder<List<LyricsCandidate>>(
                      future: future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator.adaptive(),
                          );
                        }
                        final candidates = snapshot.data ?? const [];
                        if (candidates.isEmpty) {
                          return Center(
                            child: Text(
                              '没有找到可用歌词',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: candidates.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final candidate = candidates[index];
                            final providerName = candidate.isEmbedded
                                ? _embeddedLyricsSource(item)
                                : _providerDisplayName(candidate.provider);
                            final selectedNow =
                                providerName == _lyricsSourceLabel;
                            return Material(
                              color: selectedNow
                                  ? scheme.primaryContainer
                                      .withValues(alpha: 0.60)
                                  : scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(18),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: scheme.primaryContainer,
                                  foregroundColor: scheme.onPrimaryContainer,
                                  child: Icon(
                                    candidate.isEmbedded
                                        ? Icons.library_music_rounded
                                        : Icons.cloud_sync_rounded,
                                  ),
                                ),
                                title: Text(
                                  providerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  [candidate.title, candidate.artist]
                                      .where((part) => part.trim().isNotEmpty)
                                      .join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: selectedNow
                                    ? Icon(Icons.check_circle_rounded,
                                        color: scheme.primary)
                                    : const Icon(Icons.chevron_right_rounded),
                                onTap: () =>
                                    Navigator.of(context).pop(candidate),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    await _applyLyricsCandidate(selected, item, trackId);
  }

  Future<void> _applyLyricsCandidate(
    LyricsCandidate candidate,
    Map<String, dynamic> item,
    String trackId,
  ) async {
    setState(() => _isLoading = true);
    LyricsResult? result;
    if (candidate.isEmbedded && candidate.lyric != null) {
      result = LyricsResult(
        lyric: candidate.lyric!,
        provider: 'embedded',
        hasNeteaseTranslation: false,
      );
    } else {
      result = await _lyricsService.getLyricsForCandidate(candidate, trackId);
    }

    if (!mounted || trackId != _trackId) return;
    if (result == null || result.lyric.trim().isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这个来源暂时没有可用歌词')),
      );
      return;
    }

    final parsed = _parseOriginalOnly(result.lyric);
    final sourceLabel = candidate.isEmbedded
        ? _embeddedLyricsSource(item)
        : _providerDisplayName(result.provider);
    _lastScrolledIndex = -1;
    _resetScrollController();
    setState(() {
      _lyrics = parsed.lines;
      _lineKeys = List.generate(parsed.lines.length, (_) => GlobalKey());
      _synced = parsed.synced;
      _lyricsSourceLabel = sourceLabel;
      _isLoading = false;
      _copyMode = false;
      _autoScroll = true;
      _userScrolling = false;
      _manualQuickActionsVisible = true;
    });
    _jumpLyricsScrollToTop();
    _hideQuickActionsTimer?.cancel();
    _hideQuickActionsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_copyMode) {
        setState(() => _manualQuickActionsVisible = false);
      }
    });
  }

  Future<void> _copyAllLyrics() async {
    if (_lyrics.isEmpty) return;
    final text = _lyrics.map((line) => line.text).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.copiedToClipboard(
            AppLocalizations.of(context)!.lyricsTitle,
          ),
        ),
      ),
    );
  }

  Future<void> _seekToLine(LyricLine line) async {
    if (!_synced) return;
    HapticFeedback.selectionClick();
    await context
        .read<SpotifyProvider>()
        .seekToPosition(line.timestamp.inMilliseconds);
    _enableAutoScroll();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Selector<SpotifyProvider,
        ({Map<String, dynamic>? item, int progress, bool hasTrack})>(
      selector: (_, provider) {
        final current = provider.currentTrack;
        return (
          item: current?['item'] as Map<String, dynamic>?,
          progress: current?['progress_ms'] as int? ?? 0,
          hasTrack: current?['item'] != null,
        );
      },
      builder: (context, state, _) {
        if (!state.hasTrack) {
          return _EmptyLyrics(text: UiTexts.of(context).noLyrics);
        }

        _scheduleLoadForTrack(state.item);

        if (_isLoading) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (_lyrics.isEmpty) {
          return _EmptyLyrics(text: l10n.lyricsNotAvailable);
        }

        final currentIndex = _currentLineIndex(state.progress);
        _scrollToCurrentLine(currentIndex);
        final showActions = _manualQuickActionsVisible || _copyMode;

        return Material(
          color: Colors.transparent,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _handleUserScroll(notification);
              return false;
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      context
                              .layoutType(ResponsivePageType.detail)
                              .preferTwoPane
                          ? 48
                          : 36,
                      76 + MediaQuery.paddingOf(context).top,
                      context
                              .layoutType(ResponsivePageType.detail)
                              .preferTwoPane
                          ? 48
                          : 36,
                      112 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < _lyrics.length; i++)
                          KeyedSubtree(
                            key: i < _lineKeys.length
                                ? _lineKeys[i]
                                : ValueKey('lyric-line-$i'),
                            child: _LyricLineView(
                              text: _lyrics[i].text,
                              active: i == currentIndex,
                              copyMode: _copyMode,
                              synced: _synced,
                              onTap: () => _seekToLine(_lyrics[i]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _TopGradient(color: Theme.of(context).scaffoldBackgroundColor),
                _BottomGradient(
                    color: Theme.of(context).scaffoldBackgroundColor),
                Positioned(
                  left: 16,
                  bottom: 24 + MediaQuery.paddingOf(context).bottom,
                  child: IgnorePointer(
                    ignoring: !showActions,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      opacity: showActions ? 1 : 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_synced)
                            IconButton.filledTonal(
                              tooltip: l10n.centerCurrentLine,
                              onPressed: _jumpToCurrentLine,
                              icon: const Icon(
                                  Icons.vertical_align_center_rounded),
                            ),
                          if (_synced) const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: '歌词来源',
                            onPressed: _showLyricsSourceSelector,
                            icon: const Icon(Icons.source_rounded),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: _copyMode
                                ? l10n.exitCopyModeResumeScroll
                                : l10n.enterCopyLyricsMode,
                            onPressed: _toggleCopyMode,
                            icon: Icon(
                              _copyMode
                                  ? Icons.playlist_play_rounded
                                  : Icons.edit_note_rounded,
                            ),
                          ),
                          if (_copyMode) ...[
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              onPressed: _copyAllLyrics,
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: Text(l10n.copyToClipboard),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (_copyMode)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 18 + MediaQuery.paddingOf(context).top,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Text(
                          l10n.copyLyricsModeHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LyricLineView extends StatelessWidget {
  const _LyricLineView({
    required this.text,
    required this.active,
    required this.copyMode,
    required this.synced,
    required this.onTap,
  });

  final String text;
  final bool active;
  final bool copyMode;
  final bool synced;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = active
        ? scheme.primary
        : copyMode
            ? scheme.onSurface.withValues(alpha: 0.78)
            : scheme.primary.withValues(alpha: 0.30);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: synced ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          style: theme.textTheme.titleLarge!.copyWith(
            height: 1.35,
            fontSize: active ? 23 : 21,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            color: color,
          ),
          child: Text(text),
        ),
      ),
    );
  }
}

class _EmptyLyrics extends StatelessWidget {
  const _EmptyLyrics({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _TopGradient extends StatelessWidget {
  const _TopGradient({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 56 + MediaQuery.paddingOf(context).top,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color,
                color.withValues(alpha: 0.90),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.58, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomGradient extends StatelessWidget {
  const _BottomGradient({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 82 + MediaQuery.paddingOf(context).bottom,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                color,
                color.withValues(alpha: 0.72),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.62, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParsedLyrics {
  const _ParsedLyrics(this.lines, this.synced);
  final List<LyricLine> lines;
  final bool synced;
}
