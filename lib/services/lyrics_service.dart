import 'dart:convert';
import 'dart:async';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
// html_unescape is used in the provider classes
import '../models/lyrics_result.dart';
import 'lyrics/lyric_provider.dart';
import 'lyrics/qq_provider.dart';
import 'lyrics/netease_provider.dart';
import 'lyrics/lrclib_provider.dart';

export '../models/lyrics_result.dart';

class LyricsCandidate {
  const LyricsCandidate({
    required this.provider,
    required this.songId,
    required this.title,
    required this.artist,
    this.lyric,
    this.isEmbedded = false,
  });

  final String provider;
  final String songId;
  final String title;
  final String artist;
  final String? lyric;
  final bool isEmbedded;
}

class LyricsService {
  final Logger _logger = Logger();
  final List<LyricProvider> _providers;
  SharedPreferences? _prefsCache;

  // 缓存键的前缀
  static const String _cacheKeyPrefix = 'lyrics_cache_';
  // 缓存有效期（30天）
  static const int _cacheTtlDays = 30;

  LyricsService({List<LyricProvider>? providers, SharedPreferences? prefs})
      : _providers = providers ?? [NetEaseProvider(), QQProvider(), LRCLibProvider()],
        _prefsCache = prefs;

  /// 获取歌词
  ///
  /// 返回 [LyricsResult] 包含歌词文本、来源信息和翻译可用性
  Future<LyricsResult?> getLyrics(String songName, String artistName, String trackId) async {
    try {
      // 使用 trackId 作为缓存键
      final cacheKey = _cacheKeyPrefix + trackId;
      // 尝试从缓存获取
      final prefs = await _getPrefs();
      final cachedLyricsJson = prefs.getString(cacheKey);

      if (cachedLyricsJson != null) {
        try {
          final cacheData = LyricCacheData.fromJson(json.decode(cachedLyricsJson));

          // 检查缓存是否过期（30天）
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (now - cacheData.timestamp < _cacheTtlDays * 24 * 60 * 60) {
            _logger.i('从缓存获取歌词: $trackId (来源: ${cacheData.provider})');
            return LyricsResult(
              lyric: cacheData.lyric,
              provider: cacheData.provider,
              hasNeteaseTranslation: false,
            );
          } else {
            _logger.i('缓存已过期: $trackId');
          }
        } catch (e) {
          _logger.w('解析缓存数据失败: $e');
          // 如果解析失败，继续获取新数据
        }
      }

      // 如果缓存中没有或已过期，从网络获取
      _logger.i('从网络获取歌词: $songName - $artistName');

      // 并行从多个提供者获取歌词
      final lyrics = await _getFromProviders(songName, artistName);

      // 使用 trackId 存储缓存
      if (lyrics != null) {
        final provider = lyrics['provider'] as String;
        final lyricText = lyrics['lyric'] as String;
        final cacheData = LyricCacheData(
          provider: provider,
          lyric: lyricText,
          timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        await prefs.setString(cacheKey, json.encode(cacheData.toJson()));
        _logger.i('歌词已缓存: $trackId (来源: $provider)');

        return LyricsResult(
          lyric: lyricText,
          provider: provider,
          hasNeteaseTranslation: false,
        );
      }

      return null;
    } catch (e) {
      _logger.e('获取歌词失败: $e');
      return null;
    }
  }

  /// 从多个提供者并行获取歌词。
  ///
  /// v19 起删除歌词翻译逻辑，只获取原文歌词，不再请求或缓存翻译歌词。
  Future<Map<String, String>?> _getFromProviders(String title, String artist) async {
    try {
      final futures = _providers.map((provider) async {
        final lyric = await provider.getLyric(title, artist);
        return lyric != null ? {'provider': provider.name, 'lyric': lyric} : null;
      }).toList();

      final results = await Future.wait(futures);
      for (final result in results) {
        if (result != null) return result;
      }

      for (final provider in _providers) {
        _logger.i('尝试从 ${provider.name} 获取歌词');
        final lyric = await provider.getLyric(title, artist);
        if (lyric != null) {
          return {'provider': provider.name, 'lyric': lyric};
        }
      }

      return null;
    } catch (e) {
      _logger.e('从提供者获取歌词失败: $e');
      return null;
    }
  }

  // _evaluateLyricQuality method removed as it was unused


  Future<List<LyricsCandidate>> searchLyricsCandidates(
    String title,
    String artist, {
    int limitPerProvider = 4,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedArtist = artist.trim();
    if (trimmedTitle.isEmpty && trimmedArtist.isEmpty) return const [];

    final futures = _providers.map((provider) async {
      final matches = await provider.searchMultiple(
        trimmedTitle,
        trimmedArtist,
        limit: limitPerProvider,
      );
      return matches
          .map(
            (match) => LyricsCandidate(
              provider: provider.name,
              songId: match.songId,
              title: match.title,
              artist: match.artist,
            ),
          )
          .toList();
    }).toList();

    final grouped = await Future.wait(futures);
    final seen = <String>{};
    final candidates = <LyricsCandidate>[];
    for (final list in grouped) {
      for (final candidate in list) {
        final key = '${candidate.provider}|${candidate.songId}';
        if (seen.add(key)) candidates.add(candidate);
      }
    }
    return candidates;
  }

  Future<LyricsResult?> getLyricsForCandidate(
    LyricsCandidate candidate,
    String trackId,
  ) async {
    try {
      String? lyric = candidate.lyric;
      if (lyric == null || lyric.trim().isEmpty) {
        final provider = _providerByName(candidate.provider);
        if (provider == null) return null;
        final raw = await provider.fetchLyric(candidate.songId);
        if (raw == null || raw.trim().isEmpty) return null;
        lyric = provider.normalizeLyric(raw);
      }

      if (lyric.trim().isEmpty) return null;
      await _cacheLyrics(
        trackId: trackId,
        provider: candidate.provider,
        lyric: lyric,
      );
      return LyricsResult(
        lyric: lyric,
        provider: candidate.provider,
        hasNeteaseTranslation: false,
      );
    } catch (e) {
      _logger.e('切换歌词来源失败: $e');
      return null;
    }
  }

  Future<void> _cacheLyrics({
    required String trackId,
    required String provider,
    required String lyric,
  }) async {
    final prefs = await _getPrefs();
    final cacheData = LyricCacheData(
      provider: provider,
      lyric: lyric,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    await prefs.setString(
      _cacheKeyPrefix + trackId,
      json.encode(cacheData.toJson()),
    );
  }

  LyricProvider? _providerByName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final provider in _providers) {
      if (provider.name.trim().toLowerCase() == normalized) return provider;
    }
    return null;
  }

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys();

      // 只清除歌词缓存的键
      for (var key in keys) {
        if (key.startsWith(_cacheKeyPrefix)) {
          await prefs.remove(key);
        }
      }
      _logger.i('歌词缓存已清除');
    } catch (e) {
      _logger.e('清除缓存失败: $e');
    }
  }

  /// 获取缓存大小
  Future<int> getCacheSize() async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys();
      int totalSize = 0;
      int qqCount = 0;
      int neCount = 0;
      int lrclibCount = 0;
      int otherCount = 0;

      for (var key in keys) {
        if (key.startsWith(_cacheKeyPrefix)) {
          final value = prefs.getString(key);
          if (value != null) {
            totalSize += value.length;

            // 统计各提供者的缓存数量
            try {
              final cacheData = LyricCacheData.fromJson(json.decode(value));
              if (cacheData.provider == 'qq') {
                qqCount++;
              } else if (cacheData.provider == 'netease') {
                neCount++;
              } else if (cacheData.provider == 'lrclib') {
                lrclibCount++;
              } else {
                otherCount++;
              }
            } catch (e) {
              // 忽略解析错误，可能是旧格式缓存
              otherCount++;
            }
          }
        }
      }

      final totalCount = qqCount + neCount + lrclibCount + otherCount;
      _logger.i('缓存统计 - 总数: $totalCount, QQ音乐: $qqCount, 网易云: $neCount, LRCLIB: $lrclibCount, 其他: $otherCount');
      return totalSize;
    } catch (e) {
      _logger.e('获取缓存大小失败: $e');
      return 0;
    }
  }

  /// 获取当前使用的提供者列表
  List<String> getProviderNames() {
    return _providers.map((provider) => provider.name).toList();
  }

  Future<SharedPreferences> _getPrefs() async {
    final cached = _prefsCache;
    if (cached != null) {
      return cached;
    }
    final prefs = await SharedPreferences.getInstance();
    _prefsCache = prefs;
    return prefs;
  }
}
