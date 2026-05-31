import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../services/lyrics/lyric_provider.dart';
import '../services/lyrics/qq_provider.dart';
import '../services/lyrics/lrclib_provider.dart';
import '../services/lyrics/netease_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// 在页面中使用自己的数据结构表示搜索结�?final _logger = Logger();

class LyricsSearchResult {
  final SongMatch match;
  final LyricProvider provider;

  LyricsSearchResult({required this.match, required this.provider});
}

class LyricsSearchSelection {
  final String lyrics;
  final String provider;
  final bool hasNeteaseTranslation;

  const LyricsSearchSelection({
    required this.lyrics,
    required this.provider,
    this.hasNeteaseTranslation = false,
  });
}

/// 每个提供者的搜索状�?enum ProviderSearchState {
  idle,
  loading,
  loaded,
  error,
}

enum _LyricsSearchEntryType {
  header,
  result,
  loadingPlaceholder,
  divider,
}

class _LyricsSearchEntry {
  final _LyricsSearchEntryType type;
  final LyricProvider? provider;
  final LyricsSearchResult? result;

  const _LyricsSearchEntry.header(this.provider)
      : type = _LyricsSearchEntryType.header,
        result = null;

  const _LyricsSearchEntry.result(this.result)
      : type = _LyricsSearchEntryType.result,
        provider = null;

  const _LyricsSearchEntry.loadingPlaceholder(this.provider)
      : type = _LyricsSearchEntryType.loadingPlaceholder,
        result = null;

  const _LyricsSearchEntry.divider()
      : type = _LyricsSearchEntryType.divider,
        provider = null,
        result = null;
}

class LyricsSearchPage extends StatefulWidget {
  final String initialTrackTitle;
  final String initialArtistName;
  final String trackId; // 保存选择的歌词时需要trackId

  const LyricsSearchPage({
    super.key,
    required this.initialTrackTitle,
    required this.initialArtistName,
    required this.trackId,
  });

  @override
  State<LyricsSearchPage> createState() => _LyricsSearchPageState();
}

class _LyricsSearchPageState extends State<LyricsSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isFetchingLyric = false;
  String _currentQuery = '';

  // 每个提供者的搜索状态和结果
  final Map<String, ProviderSearchState> _providerStates = {};
  final Map<String, List<LyricsSearchResult>> _providerResults = {};

  // 提供者列�?  late final List<LyricProvider> _providers;

  // 注入服务
  late NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService =
        Provider.of<NotificationService>(context, listen: false);

    // 初始化提供�?    _providers = [
      QQProvider(),
      LRCLibProvider(),
      NetEaseProvider(),
    ];

    // 初始化每个提供者的状�?    for (final provider in _providers) {
      _providerStates[provider.name] = ProviderSearchState.idle;
      _providerResults[provider.name] = [];
    }

    // 设置初始查询并执行第一次搜�?    _currentQuery =
        '${widget.initialTrackTitle} ${widget.initialArtistName}'.trim();
    _searchController.text = _currentQuery;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _performSearch(_currentQuery);
      // 首帧后请求焦�?      FocusScope.of(context).requestFocus(_searchFocusNode);
      // 选择全部文本方便替换
      _searchController.selection = TextSelection(
          baseOffset: 0, extentOffset: _searchController.text.length);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// 检查是否有任何提供者正在加�?  bool get _isAnyProviderLoading {
    return _providerStates.values
        .any((state) => state == ProviderSearchState.loading);
  }

  /// 获取所有搜索结果（合并所有提供者）
  List<LyricsSearchResult> get _allResults {
    final results = <LyricsSearchResult>[];
    for (final provider in _providers) {
      results.addAll(_providerResults[provider.name] ?? []);
    }
    return results;
  }

  List<_LyricsSearchEntry> _buildSearchEntries() {
    final entries = <_LyricsSearchEntry>[];
    for (final provider in _providers) {
      final state = _providerStates[provider.name] ?? ProviderSearchState.idle;
      final results = _providerResults[provider.name] ?? [];

      if (state == ProviderSearchState.idle && _currentQuery.isEmpty) {
        continue;
      }

      entries.add(_LyricsSearchEntry.header(provider));

      if (results.isNotEmpty) {
        for (final result in results) {
          entries.add(_LyricsSearchEntry.result(result));
        }
      }

      if (state == ProviderSearchState.loading && results.isEmpty) {
        entries.add(_LyricsSearchEntry.loadingPlaceholder(provider));
      }

      if (_currentQuery.isNotEmpty) {
        entries.add(const _LyricsSearchEntry.divider());
      }
    }
    return entries;
  }

  Future<void> _performSearch(String query) async {
    if (!mounted || query.trim().isEmpty) {
      // 如果查询为空，清除结�?      setState(() {
        _currentQuery = '';
        for (final provider in _providers) {
          _providerStates[provider.name] = ProviderSearchState.idle;
          _providerResults[provider.name] = [];
        }
      });
      return;
    }

    _searchFocusNode.unfocus(); // 隐藏键盘

    setState(() {
      _currentQuery = query.trim();
      // 重置所有提供者状态为加载�?      for (final provider in _providers) {
        _providerStates[provider.name] = ProviderSearchState.loading;
        _providerResults[provider.name] = [];
      }
    });

    // 并行搜索所有提供�?    await Future.wait(
      _providers.map((provider) => _searchProvider(provider, _currentQuery)),
    );
  }

  /// 搜索单个提供�?  Future<void> _searchProvider(LyricProvider provider, String query) async {
    const int resultsPerProvider = 3;

    try {
      final matches =
          await provider.searchMultiple(query, '', limit: resultsPerProvider);

      if (!mounted) return;

      // 检查查询是否仍然是当前查询（避免过时的结果�?      if (query != _currentQuery) return;

      final results = matches
          .map((match) => LyricsSearchResult(match: match, provider: provider))
          .toList();

      setState(() {
        _providerResults[provider.name] = results;
        _providerStates[provider.name] = ProviderSearchState.loaded;
      });
    } catch (e) {
      _logger.d('Provider ${provider.name} search error: $e');

      if (!mounted) return;
      if (query != _currentQuery) return;

      setState(() {
        _providerStates[provider.name] = ProviderSearchState.error;
        _providerResults[provider.name] = [];
      });
    }
  }

  // 使用我们自己定义的LyricsSearchResult类型
  Future<void> _selectResult(LyricsSearchResult result) async {
    if (!mounted || _isFetchingLyric) return;

    // 在异步调用前捕获 Navigator
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isFetchingLyric = true;
    });

    try {
      _notificationService.showSnackBar(l10n.lyricsFetching);

      // 网易云特殊处理：获取翻译并保�?      if (result.provider is NetEaseProvider) {
        final neteaseProvider = result.provider as NetEaseProvider;
        final lyricResult =
            await neteaseProvider.fetchLyricWithTranslation(result.match.songId);

        if (!mounted) return;

        if (lyricResult != null) {
          final normalizedLyric =
              result.provider.normalizeLyric(lyricResult.lyric);
          if (normalizedLyric.isNotEmpty) {
            await _cacheLyric(
                widget.trackId, normalizedLyric, result.provider.name);

            // 如果有翻译，单独保存供后续使�?            if (lyricResult.hasTranslation) {
              await _cacheNeteaseTranslation(
                  widget.trackId, lyricResult.translation!);
              _notificationService.showSnackBar(l10n.neteaseTranslationSaved);
            }

            _logger.d(
                "手动获取的歌词已缓存，曲目ID�?{widget.trackId}，提供者：${result.provider.name}");
            navigator.pop(LyricsSearchSelection(
              lyrics: normalizedLyric,
              provider: result.provider.name,
              hasNeteaseTranslation: lyricResult.hasTranslation,
            ));
            return;
          }
        }
      } else {
        // 其他提供者使用原有逻辑
        final rawLyric = await result.provider.fetchLyric(result.match.songId);

        if (!mounted) return;

        if (rawLyric != null) {
          final normalizedLyric = result.provider.normalizeLyric(rawLyric);

          if (normalizedLyric.isNotEmpty) {
            await _cacheLyric(
                widget.trackId, normalizedLyric, result.provider.name);
            _logger.d(
                "手动获取的歌词已缓存，曲目ID�?{widget.trackId}，提供者：${result.provider.name}");
            navigator.pop(LyricsSearchSelection(
              lyrics: normalizedLyric,
              provider: result.provider.name,
            ));
            return;
          }
        }
      }

      if (mounted) {
        _notificationService.showErrorSnackBar(
            AppLocalizations.of(context)!.lyricsNotFoundForTrack);
      }
    } catch (e) {
      if (mounted) {
        _notificationService.showErrorSnackBar(
            AppLocalizations.of(context)!.lyricsFetchError(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLyric = false;
        });
      }
    }
  }

  /// 缓存网易云翻译歌词（供翻译风格切换使用）
  Future<void> _cacheNeteaseTranslation(
      String trackId, String translation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'netease_translation_$trackId';
      await prefs.setString(cacheKey, translation);
      _logger.d("网易云翻译已缓存: $trackId");
    } catch (e) {
      _logger.d('缓存网易云翻译失�? $e');
    }
  }

  // 手动将歌词缓存到共享首选项
  Future<void> _cacheLyric(
      String trackId, String lyric, String providerName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'manual_lyrics_cache_$trackId'; // 使用插�?
      // 使用 LyricCacheData 保存
      final cacheData = LyricCacheData(
        provider: providerName,
        lyric: lyric,
        timestamp: (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      );

      // 保存到缓�?      await prefs.setString(cacheKey, json.encode(cacheData.toJson()));

      // 同时保存�?LyricsService 使用的常规缓存位�?      // 不直接使用私有变�?      final regularCacheKey = 'lyrics_cache_$trackId'; // 使用插�?      await prefs.setString(regularCacheKey, json.encode(cacheData.toJson()));
    } catch (e) {
      _logger.d('缓存歌词失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final allResults = _allResults;
    final searchEntries = _buildSearchEntries();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchLyrics),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isAnyProviderLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : (_searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: l10n.clearSearch,
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                              _searchFocusNode.requestFocus();
                            },
                          )
                        : null),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {});
              },
              onSubmitted: (value) {
                _performSearch(value);
              },
              textInputAction: TextInputAction.search,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 初始状态提�?          if (!_isAnyProviderLoading &&
              allResults.isEmpty &&
              _currentQuery.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  l10n.searchHint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            )
          // 显示搜索结果（分组显示）
          else if (allResults.isNotEmpty || _isAnyProviderLoading)
            ListView.builder(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              itemCount: searchEntries.length,
              itemBuilder: (context, index) {
                final entry = searchEntries[index];
                switch (entry.type) {
                  case _LyricsSearchEntryType.header:
                    return _buildProviderHeader(entry.provider!);
                  case _LyricsSearchEntryType.result:
                    return _buildResultTile(entry.result!);
                  case _LyricsSearchEntryType.loadingPlaceholder:
                    return _buildLoadingPlaceholder();
                  case _LyricsSearchEntryType.divider:
                    return _buildSectionDivider();
                }
              },
            )
          // 无结果状态（所有提供者都加载完成但没有结果）
          else if (!_isAnyProviderLoading &&
              allResults.isEmpty &&
              _currentQuery.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.noResultsFound,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            ),
          // 只在获取歌词内容时显示遮�?          if (_isFetchingLyric)
            Positioned.fill(
              child: Container(
                color:
                    theme.scaffoldBackgroundColor.withAlpha((0.7 * 255).round()),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProviderHeader(LyricProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = _providerStates[provider.name] ?? ProviderSearchState.idle;
    final results = _providerResults[provider.name] ?? [];
    final providerDisplayName = _providerDisplayName(context, provider.name);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              providerDisplayName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 加载状态指�?          if (state == ProviderSearchState.loading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          else if (state == ProviderSearchState.loaded && results.isEmpty)
            Text(
              l10n.noResultsFound,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            )
          else if (state == ProviderSearchState.error)
            Icon(
              Icons.error_outline,
              size: 16,
              color: theme.colorScheme.error,
            ),
        ],
      ),
    );
  }

  Widget _buildResultTile(LyricsSearchResult result) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(result.match.title),
      subtitle: Text(result.match.artist),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.outline,
      ),
      onTap: _isFetchingLyric ? null : () => _selectResult(result),
      enabled: !_isFetchingLyric,
    );
  }

  Widget _buildLoadingPlaceholder() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 200,
            height: 16,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionDivider() {
    final theme = Theme.of(context);
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: theme.colorScheme.outlineVariant.withAlpha(80),
    );
  }

  String _providerDisplayName(BuildContext context, String providerName) {
    final l10n = AppLocalizations.of(context)!;
    switch (providerName) {
      case 'qq':
        return l10n.providerQQMusic;
      case 'lrclib':
        return l10n.providerLRCLIB;
      case 'netease':
        return l10n.providerNetease;
      default:
        return providerName;
    }
  }
}
