import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lyric_line.dart';
import '../models/track.dart';
import '../models/translation.dart';
import '../models/lyrics_translation_error.dart';
import '../models/translation_load_result.dart';
import '../services/translation_service.dart';
import '../services/settings_service.dart';
import '../utils/structured_translation.dart';

/// 歌词翻译管理�?///
/// 职责:
/// - 管理歌词翻译的加载和缓存
/// - 处理翻译预加�?/// - 管理翻译状�?final _logger = Logger();

class LyricsTranslationManager {
  final TranslationService _translationService;
  final SettingsService _settingsService;

  // 翻译预加载状�?  Future<TranslationLoadResult>? _translationPreloadFuture;
  TranslationLoadResult? _preloadedTranslationResult;
  String? _preloadedTrackId;
  String? _preloadingTrackId;

  // 下一首歌曲预加载
  Future<void>? _nextTrackPreloadFuture;
  String? _nextTrackPreloadedId;
  String? _nextTrackPreloadingId;

  // 活动的翻译风�?  TranslationStyle? _activeTranslationStyle;

  LyricsTranslationManager({
    TranslationService? translationService,
    SettingsService? settingsService,
  })  : _translationService = translationService ?? TranslationService(),
        _settingsService = settingsService ?? SettingsService();

  // Getters
  TranslationStyle? get activeTranslationStyle => _activeTranslationStyle;
  bool get hasPreloadedTranslation => _preloadedTranslationResult != null;

  /// 检查是否有预加载的翻译可用于指定曲�?  bool hasPreloadedTranslationForTrack(String? trackId) {
    return trackId != null &&
        _preloadedTrackId == trackId &&
        _preloadedTranslationResult != null;
  }

  /// 获取预加载的翻译结果
  TranslationLoadResult? getPreloadedTranslation(String trackId) {
    if (_preloadedTrackId == trackId) {
      return _preloadedTranslationResult;
    }
    return null;
  }

  /// 加载翻译数据
  Future<TranslationLoadResult> loadTranslationForTrack({
    required String trackId,
    required List<String> originalLines,
    Map<String, dynamic>? trackItem,
    bool forceRefresh = false,
    TranslationStyle? style,
    required Future<Translation?> Function(
            String trackId, String languageCode, String style)
        fetchCachedTranslation,
    required Future<Track?> Function(String trackId) getTrack,
    required Future<void> Function(Track track) addTrack,
    required Future<void> Function(Translation translation) saveTranslation,
  }) async {
    final effectiveStyle = style ?? await _settingsService.getTranslationStyle();
    final currentLanguage = await _settingsService.getTargetLanguage();
    final styleString = translationStyleToString(effectiveStyle);

    // 网易云翻译特殊处�?    if (effectiveStyle == TranslationStyle.neteaseProvider) {
      return _loadNeteaseTranslation(trackId, originalLines);
    }

    // 首先检查缓�?    if (!forceRefresh) {
      final cached = await fetchCachedTranslation(
        trackId,
        currentLanguage,
        styleString,
      );

      if (cached != null) {
        final parsed = parseStructuredTranslation(
          cached.translatedLyrics,
          originalLines: originalLines,
        );

        _activeTranslationStyle = stringToTranslationStyle(cached.style);

        return TranslationLoadResult(
          rawTranslatedLyrics: cached.translatedLyrics,
          cleanedTranslatedLyrics: parsed.cleanedText,
          perLineTranslations: parsed.translations,
          style: stringToTranslationStyle(cached.style),
          languageCode: cached.languageCode,
        );
      }
    }

    // 构建结构化歌�?    final structuredLyrics = buildStructuredLyrics(originalLines);

    // 调用翻译服务
    final translationData = await _translationService.translateLyrics(
      structuredLyrics,
      trackId,
      targetLanguage: currentLanguage,
      forceRefresh: forceRefresh,
      originalLines: originalLines,
      style: effectiveStyle,
    );

    final textPayload = translationData['text'];
    if (textPayload is! String || textPayload.trim().isEmpty) {
      throw const LyricsTranslationException(
        code: LyricsTranslationErrorCode.invalidResponse,
        message: 'Missing translated text in response.',
      );
    }

    final rawText = textPayload.trim();
    final cleanedText =
        (translationData['cleanedText'] as String?)?.trim() ?? rawText;
    final languageCodeUsed =
        (translationData['languageCode'] as String?) ?? currentLanguage;
    final styleUsedString =
        (translationData['style'] as String?) ?? styleString;
    final resolvedStyle = stringToTranslationStyle(styleUsedString);

    // 解析每行翻译
    final perLineTranslations = <int, String>{};
    final lineTranslationsMap =
        translationData['lineTranslations'] as Map<String, dynamic>?;
    if (lineTranslationsMap != null) {
      for (final entry in lineTranslationsMap.entries) {
        final index = int.tryParse(entry.key);
        final value = (entry.value ?? '').toString().trim();
        if (index != null && value.isNotEmpty) {
          perLineTranslations[index] = value;
        }
      }
    }

    if (perLineTranslations.isEmpty) {
      final parsed = parseStructuredTranslation(
        rawText,
        originalLines: originalLines,
      );
      perLineTranslations.addAll(parsed.translations);
    }

    // 保存到缓�?    try {
      final existingTrack = await getTrack(trackId);
      if (existingTrack == null && trackItem != null) {
        final trackToAdd = Track(
          trackId: trackId,
          trackName: trackItem['name']?.toString() ?? '',
          artistName: _extractArtistNames(trackItem),
          albumName: _extractAlbumName(trackItem),
          albumCoverUrl: _extractAlbumCover(trackItem),
        );
        await addTrack(trackToAdd);
      }

      final translationToSave = Translation(
        trackId: trackId,
        languageCode: languageCodeUsed,
        style: styleUsedString,
        translatedLyrics: rawText,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await saveTranslation(translationToSave);
    } catch (e) {
      _logger.d('Error saving translation to DB: $e');
    }

    _activeTranslationStyle = resolvedStyle;

    return TranslationLoadResult(
      rawTranslatedLyrics: rawText,
      cleanedTranslatedLyrics: cleanedText,
      perLineTranslations: perLineTranslations,
      style: resolvedStyle,
      languageCode: languageCodeUsed,
    );
  }

  /// 开始翻译预加载
  Future<TranslationLoadResult?> startTranslationPreload({
    required String trackId,
    required List<LyricLine> lyrics,
    required bool triggerDisplayWhenReady,
    bool forceRefresh = false,
    required Future<TranslationLoadResult> Function({
      bool forceRefresh,
      TranslationStyle? style,
      List<String>? overrideOriginalLines,
    }) loadTranslation,
  }) async {
    if (lyrics.isEmpty) {
      return null;
    }

    // 检查是否已有预加载结果
    if (!forceRefresh &&
        _preloadedTrackId == trackId &&
        _preloadedTranslationResult != null) {
      return _preloadedTranslationResult;
    }

    // 检查是否正在预加载
    if (!forceRefresh &&
        _translationPreloadFuture != null &&
        _preloadingTrackId == trackId) {
      try {
        final result = await _translationPreloadFuture!;
        _preloadedTrackId = trackId;
        _preloadedTranslationResult = result;
        return result;
      } catch (e) {
        _logger.d('Translation preload failed: $e');
        return null;
      }
    }

    // 开始新的预加载
    _preloadingTrackId = trackId;
    final future = loadTranslation(forceRefresh: forceRefresh);
    _translationPreloadFuture = future;

    try {
      final result = await future;
      _preloadedTrackId = trackId;
      _preloadedTranslationResult = result;
      _translationPreloadFuture = null;
      _preloadingTrackId = null;
      _activeTranslationStyle = result.style;
      return result;
    } catch (e) {
      _translationPreloadFuture = null;
      _preloadingTrackId = null;
      _logger.d('Translation preload failed: $e');
      return null;
    }
  }

  /// 预加载下一首歌曲的资源
  ///
  /// [preloadTranslation] 是否预加载翻译。如果为 null，则根据用户的自动翻译设置决定�?  /// [loadTranslation] 翻译加载回调，当需要预加载翻译时调用�?  Future<void> preloadNextTrackResources({
    required String trackId,
    required String songName,
    required String artistName,
    required Map<String, dynamic> trackData,
    required Future<String?> Function(String songName, String artistName, String trackId)
        getLyrics,
    required List<LyricLine> Function(String rawLyrics) parseLyrics,
    bool? preloadTranslation,
    Future<void> Function(String trackId, List<String> originalLines, Map<String, dynamic> trackItem)? loadTranslation,
  }) async {
    if (_nextTrackPreloadedId == trackId ||
        (_nextTrackPreloadFuture != null && _nextTrackPreloadingId == trackId)) {
      return;
    }

    _nextTrackPreloadingId = trackId;
    _nextTrackPreloadFuture = Future(() async {
      try {
        // 始终预加载歌词（会自动缓存）
        final rawLyrics = await getLyrics(songName, artistName, trackId);
        if (rawLyrics == null) {
          _logger.d('Preloaded lyrics for next track: $trackId (no lyrics found)');
          return;
        }

        _logger.d('Preloaded lyrics for next track: $trackId');

        var lyricLines = parseLyrics(rawLyrics);
        List<String> originalLines =
            lyricLines.map((line) => line.text).toList(growable: false);

        if (originalLines.isEmpty) {
          originalLines = rawLyrics
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList();
        }

        if (originalLines.isEmpty) {
          return;
        }

        // 根据参数或用户设置决定是否预加载翻译
        final shouldPreloadTranslation = preloadTranslation ??
            await _settingsService.getAutoTranslateLyricsEnabled();

        if (shouldPreloadTranslation && loadTranslation != null) {
          await loadTranslation(trackId, originalLines, trackData);
          _logger.d('Preloaded translation for next track: $trackId');
        }

        _nextTrackPreloadedId = trackId;
      } catch (e) {
        _logger.d('Failed to preload next track resources: $e');
      } finally {
        if (_nextTrackPreloadingId == trackId) {
          _nextTrackPreloadingId = null;
        }
        _nextTrackPreloadFuture = null;
      }
    });
  }

  /// 应用翻译到歌�?  void applyTranslationToLyrics(
    List<LyricLine> lyrics,
    Map<int, String> translations,
  ) {
    for (var i = 0; i < lyrics.length; i++) {
      final translated = translations[i];
      if (translated != null && translated.trim().isNotEmpty) {
        lyrics[i].translation = translated.trim();
      } else {
        lyrics[i].translation = null;
      }
    }
  }

  /// 清除预加载状�?  void clearPreloadState() {
    _translationPreloadFuture = null;
    _preloadedTranslationResult = null;
    _preloadedTrackId = null;
    _preloadingTrackId = null;
    _nextTrackPreloadFuture = null;
    _nextTrackPreloadedId = null;
    _nextTrackPreloadingId = null;
    _activeTranslationStyle = null;
  }

  /// 清除当前曲目的预加载状�?  void clearCurrentTrackPreload() {
    _translationPreloadFuture = null;
    _preloadedTranslationResult = null;
    _preloadedTrackId = null;
    _preloadingTrackId = null;
    _activeTranslationStyle = null;
  }

  /// 加载网易云翻�?  Future<TranslationLoadResult> _loadNeteaseTranslation(
    String trackId,
    List<String> originalLines,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'netease_translation_$trackId';
    final cachedTranslation = prefs.getString(cacheKey);

    if (cachedTranslation == null || cachedTranslation.isEmpty) {
      throw const LyricsTranslationException(
        code: LyricsTranslationErrorCode.cacheFailure,
        message: 'No NetEase translation available for this track.',
      );
    }

    // 解析网易云翻译（LRC 格式�?    final timeRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    final translationMap = <Duration, String>{};

    for (final line in cachedTranslation.split('\n')) {
      final match = timeRegex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisecondsStr = match.group(3)!;
        int milliseconds = millisecondsStr.length == 2
            ? int.parse(millisecondsStr) * 10
            : int.parse(millisecondsStr);

        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
        final text = match.group(4)?.trim() ?? '';
        if (text.isNotEmpty) {
          translationMap[timestamp] = text;
        }
      }
    }

    // 将翻译映射到原文行（基于时间戳匹配）
    // 注意：这里需要原文行的时间戳信息，但 originalLines 只是文本
    // 简化处理：按行索引匹配（假设原文和翻译行数对应�?    final perLineTranslations = <int, String>{};
    final translationLines = translationMap.values.toList();

    for (var i = 0; i < originalLines.length && i < translationLines.length; i++) {
      if (translationLines[i].isNotEmpty) {
        perLineTranslations[i] = translationLines[i];
      }
    }

    _activeTranslationStyle = TranslationStyle.neteaseProvider;

    return TranslationLoadResult(
      rawTranslatedLyrics: cachedTranslation,
      cleanedTranslatedLyrics: translationLines.join('\n'),
      perLineTranslations: perLineTranslations,
      style: TranslationStyle.neteaseProvider,
      languageCode: 'zh-CN', // 网易云翻译只有中�?    );
  }

  // Helper methods
  String _extractArtistNames(Map<String, dynamic> trackItem) {
    final artists = trackItem['artists'];
    if (artists is List) {
      final names = artists
          .map((artist) {
            if (artist is Map && artist['name'] != null) {
              final value = artist['name'].toString().trim();
              if (value.isNotEmpty) {
                return value;
              }
            }
            return '';
          })
          .where((name) => name.isNotEmpty)
          .toList();
      if (names.isNotEmpty) {
        return names.join(', ');
      }
    }
    return 'Unknown Artist';
  }

  String? _extractAlbumCover(Map<String, dynamic> trackItem) {
    final album = trackItem['album'];
    if (album is Map) {
      final images = album['images'];
      if (images is List && images.isNotEmpty) {
        final first = images.first;
        if (first is Map && first['url'] != null) {
          final url = first['url'].toString();
          if (url.isNotEmpty) {
            return url;
          }
        }
      }
    }
    return null;
  }

  String _extractAlbumName(Map<String, dynamic> trackItem) {
    final album = trackItem['album'];
    if (album is Map && album['name'] != null) {
      final value = album['name'].toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return 'Unknown Album';
  }
}
