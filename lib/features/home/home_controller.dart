import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/music_track.dart';
import '../../services/local_music_service.dart';
import '../../services/player_controller.dart';

class HomeController extends GetxController {
  static const _tracksCacheKey = 'music.cached_tracks.v1';
  static const _sortModeKey = 'music.sort_mode.v1';

  final _localService = LocalMusicService();

  final tracks = <MusicTrack>[].obs;
  final importing = false.obs;
  final selectedSourceType = Rxn<MusicSourceType>();
  final sortMode = TrackSortMode.titleAsc.obs;
  final cacheLoaded = false.obs;

  int _tracksVersion = 0;
  int _cachedSortedVersion = -1;
  TrackSortMode? _cachedSortedMode;
  List<MusicTrack> _cachedSortedTracks = const [];

  int _cachedVisibleVersion = -1;
  TrackSortMode? _cachedVisibleMode;
  MusicSourceType? _cachedVisibleSource;
  List<MusicTrack> _cachedVisibleTracks = const [];

  final Map<String, String> _sortKeyCache = <String, String>{};
  Future<void>? _loadCachedFuture;

  void _markTrackListChanged() {
    _tracksVersion++;
    _cachedSortedVersion = -1;
    _cachedVisibleVersion = -1;
    _sortKeyCache.clear();
  }

  void _setTracks(List<MusicTrack> value) {
    _markTrackListChanged();
    tracks.assignAll(value);
  }

  List<MusicSourceType> get availableSourceTypes {
    final set = <MusicSourceType>{};
    for (final track in tracks) {
      set.add(track.sourceType);
    }
    return MusicSourceType.values.where(set.contains).toList();
  }

  bool get shouldShowSourceTabs => availableSourceTypes.length >= 2;

  List<MusicTrack> get sortedTracks {
    final mode = sortMode.value;
    if (_cachedSortedVersion == _tracksVersion &&
        _cachedSortedMode == mode) {
      return _cachedSortedTracks;
    }

    _cachedSortedTracks = _sortTracks(tracks);
    _cachedSortedVersion = _tracksVersion;
    _cachedSortedMode = mode;
    return _cachedSortedTracks;
  }

  List<MusicTrack> get visibleTracks {
    final selected = selectedSourceType.value;
    final mode = sortMode.value;
    if (_cachedVisibleVersion == _tracksVersion &&
        _cachedVisibleMode == mode &&
        _cachedVisibleSource == selected) {
      return _cachedVisibleTracks;
    }

    final sorted = sortedTracks;
    _cachedVisibleTracks = selected == null
        ? sorted
        : List.unmodifiable(
            sorted.where((track) => track.sourceType == selected),
          );
    _cachedVisibleVersion = _tracksVersion;
    _cachedVisibleMode = mode;
    _cachedVisibleSource = selected;
    return _cachedVisibleTracks;
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(loadCachedTracks());
  }

  Future<void> loadCachedTracks() {
    return _loadCachedFuture ??= _loadCachedTracksInternal();
  }

  Future<void> _loadCachedTracksInternal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawSortMode = prefs.getString(_sortModeKey);
      sortMode.value = TrackSortMode.values.firstWhere(
        (mode) => mode.name == rawSortMode,
        orElse: () => TrackSortMode.titleAsc,
      );

      final raw = prefs.getString(_tracksCacheKey);
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final rawLoaded = decoded
          .whereType<Map>()
          .map((e) => MusicTrack.fromJson(Map<String, dynamic>.from(e)))
          .where(_isUsableCachedTrack)
          .toList();

      final loaded = await _localService.ensureWindowsPlayableCopies(rawLoaded);

      if (loaded.isNotEmpty) {
        _setTracks(_dedupeTracks(loaded));
        await _saveCachedTracks();
      }
    } catch (e) {
      debugPrint('读取音乐缓存失败: $e');
    } finally {
      cacheLoaded.value = true;
      await _restoreLastPlaybackSession();
    }
  }

  bool _isUsableCachedTrack(MusicTrack track) {
    if (track.id.trim().isEmpty || track.uri.trim().isEmpty) return false;

    // 本地音乐缓存只保留仍然存在的文件，避免列表里出现失效路径。
    if (track.sourceType == MusicSourceType.localFile) {
      final uri = Uri.tryParse(track.uri);
      try {
        final uriPath = uri?.isScheme('file') == true
            ? uri!.toFilePath(windows: Platform.isWindows)
            : '';
        if (uriPath.isNotEmpty && File(uriPath).existsSync()) return true;
      } catch (_) {}

      return File(track.id).existsSync();
    }

    // WebDAV / Emby / Jellyfin 是网络地址，先展示缓存；播放失败时再提示重新连接。
    return true;
  }

  Future<void> _saveCachedTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(tracks.map((e) => e.toJson()).toList());
      await prefs.setString(_tracksCacheKey, encoded);
    } catch (e) {
      debugPrint('保存音乐缓存失败: $e');
    }
  }

  Future<void> clearCachedTracks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tracksCacheKey);
    _setTracks(const []);
    selectedSourceType.value = null;
    try {
      await Get.find<PlayerController>().clearSavedPlaybackState();
    } catch (_) {}
  }

  Future<void> clearSourceCache(MusicSourceType sourceType, {bool clearConnection = true}) async {
    _setTracks(
      tracks.where((track) => track.sourceType != sourceType).toList(),
    );
    if (selectedSourceType.value == sourceType) {
      selectedSourceType.value = null;
    }
    await _saveCachedTracks();

    try {
      final player = Get.find<PlayerController>();
      if (player.currentTrack?.sourceType == sourceType) {
        await player.clearSavedPlaybackState();
      }
    } catch (_) {}

    if (clearConnection) {
      await _clearSourceConnectionCache(sourceType);
    }
  }

  Future<void> _clearSourceConnectionCache(MusicSourceType sourceType) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = switch (sourceType) {
      MusicSourceType.webDav => [
          'webdav.base_url',
          'webdav.username',
          'webdav.password',
          'webdav.path',
          'webdav.recursive',
        ],
      MusicSourceType.emby => [
          'emby.server_url',
          'emby.api_key',
          'emby.username',
          'emby.password',
        ],
      MusicSourceType.jellyfin => [
          'jellyfin.server_url',
          'jellyfin.api_key',
          'jellyfin.username',
          'jellyfin.password',
        ],
      MusicSourceType.navidrome => [
          'navidrome.server_url',
          'navidrome.username',
          'navidrome.password',
        ],
      MusicSourceType.localFile => <String>[],
      MusicSourceType.directUrl => <String>[],
    };

    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<void> importLocal() async {
    if (importing.value) return;

    final result = await Get.dialog<_LocalImportType>(
      const _LocalImportDialog(),
    );

    if (result == null) return;

    if (result == _LocalImportType.files) {
      await importLocalFiles();
    } else {
      await importLocalFolder();
    }
  }

  Future<void> importLocalFiles() async {
    await _importLocal(() => _localService.pickAudioFiles());
  }

  Future<void> importLocalFolder() async {
    await _importLocal(() => _localService.pickAudioFolder());
  }

  Future<void> _importLocal(Future<List<MusicTrack>> Function() picker) async {
    if (importing.value) return;
    importing.value = true;
    try {
      final picked = await picker();
      if (picked.isEmpty) return;
      final addedCount = addTracks(picked);
      final duplicateCount = picked.length - addedCount;
      final message = duplicateCount <= 0
          ? 'import.localPicked'.trParams({'count': '${picked.length}'})
          : 'import.localAdded'.trParams({'picked': '${picked.length}', 'added': '$addedCount', 'duplicate': '$duplicateCount'});
      Get.snackbar(
        'import.localSuccess'.tr,
        message,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.dialog(
        _SimpleErrorDialog(
          title: 'import.localFailed'.tr,
          message: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    } finally {
      importing.value = false;
    }
  }

  int addTracks(List<MusicTrack> value) {
    if (value.isEmpty) return 0;

    final before = tracks.length;
    final merged = _dedupeTracks([...tracks, ...value]);
    _setTracks(merged);
    _saveCachedTracks();

    final available = availableSourceTypes;
    final selected = selectedSourceType.value;
    if (selected != null && !available.contains(selected)) {
      selectedSourceType.value = null;
    }

    final added = tracks.length - before;
    return added < 0 ? 0 : added;
  }

  void replaceSourceTracks(MusicSourceType sourceType, List<MusicTrack> value) {
    final others = tracks.where((track) => track.sourceType != sourceType).toList();
    _setTracks(_dedupeTracks([...others, ...value]));
    _saveCachedTracks();
  }

  List<MusicTrack> _dedupeTracks(List<MusicTrack> input) {
    // 倒序处理：用户刚导入/刚扫描的新记录优先保留，旧缓存里的重复记录自动丢弃。
    final usedKeys = <String>{};
    final reversedResult = <MusicTrack>[];

    for (final track in input.reversed) {
      final keys = _trackKeys(track).where((key) => key.trim().isNotEmpty).toList();
      if (keys.isEmpty) continue;

      final duplicated = keys.any(usedKeys.contains);
      if (duplicated) continue;

      usedKeys.addAll(keys);
      reversedResult.add(track);
    }

    return reversedResult.reversed.toList();
  }

  List<String> _trackKeys(MusicTrack track) {
    switch (track.sourceType) {
      case MusicSourceType.localFile:
        // 本机音乐去重需要同时兼容两种情况：
        // 1. 正常场景：同一路径重复导入，只按路径去重，避免误删不同版本歌曲。
        // 2. Android 场景：同一个文件可能通过 /sdcard、/storage/emulated/0、
        //    tree 授权映射等不同路径进入缓存；这时还要用文件大小/修改时间，
        //    以及标题+歌手+时长做强去重。
        final keys = <String>[];

        for (final candidate in _localPathCandidates(track)) {
          final path = _normalizePath(candidate);
          if (path.isNotEmpty) keys.add('local:path:$path');
        }

        final statKey = _localFileStatKey(track);
        if (statKey.isNotEmpty) keys.add(statKey);

        final metadataKey = _localMetadataKey(track);
        if (metadataKey.isNotEmpty) keys.add(metadataKey);

        if (keys.isNotEmpty) return keys.toSet().toList();
        return ['local:uri:${track.uri.trim().toLowerCase()}'];

      case MusicSourceType.emby:
        final audioId = _audioIdOf(track);
        final title = _normalizeTrackText(track.title);
        final artist = _normalizeTrackText(track.artist ?? '');
        return [
          if (track.id.trim().isNotEmpty) 'emby:id:${track.id.trim().toLowerCase()}',
          if (audioId.isNotEmpty) 'emby:audio:$audioId',
          if (title.isNotEmpty && artist.isNotEmpty) 'emby:artist-title:$artist::$title',
        ];

      case MusicSourceType.jellyfin:
        final audioId = _audioIdOf(track);
        final title = _normalizeTrackText(track.title);
        final artist = _normalizeTrackText(track.artist ?? '');
        return [
          if (track.id.trim().isNotEmpty) 'jellyfin:id:${track.id.trim().toLowerCase()}',
          if (audioId.isNotEmpty) 'jellyfin:audio:$audioId',
          if (title.isNotEmpty && artist.isNotEmpty) 'jellyfin:artist-title:$artist::$title',
        ];

      case MusicSourceType.navidrome:
        final title = _normalizeTrackText(track.title);
        final artist = _normalizeTrackText(track.artist ?? '');
        final id = track.id.replaceFirst('navidrome:', '').trim().toLowerCase();
        return [
          if (id.isNotEmpty) 'navidrome:id:$id',
          if (title.isNotEmpty && artist.isNotEmpty) 'navidrome:artist-title:$artist::$title',
        ];

      case MusicSourceType.webDav:
        return ['webdav:${track.uri.trim().toLowerCase()}'];
      case MusicSourceType.directUrl:
        return ['url:${track.uri.trim().toLowerCase()}'];
    }
  }

  List<String> _localPathCandidates(MusicTrack track) {
    final values = <String>[];

    final id = track.id.trim();
    if (id.isNotEmpty) values.add(id);

    final raw = track.uri.trim();
    if (raw.isNotEmpty) {
      values.add(raw);
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.isScheme('file')) {
        try {
          values.add(uri.toFilePath(windows: Platform.isWindows));
        } catch (_) {
          try {
            values.add(uri.toFilePath());
          } catch (_) {}
        }
      }
    }

    final localPath = _localPathOf(track);
    if (localPath.isNotEmpty) values.add(localPath);

    return values
        .map(_safeDecode)
        .map((value) => value.replaceAll('\\', '/').trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  String _localFileStatKey(MusicTrack track) {
    for (final candidate in _localPathCandidates(track)) {
      try {
        final file = File(candidate);
        if (!file.existsSync()) continue;

        final stat = file.statSync();
        final name = candidate.split('/').last.toLowerCase();
        return [
          'local:stat',
          name,
          stat.size.toString(),
          stat.modified.millisecondsSinceEpoch.toString(),
        ].join('|');
      } catch (_) {}
    }

    return '';
  }

  String _localMetadataKey(MusicTrack track) {
    final title = _normalizeTrackText(track.title);
    final artist = _normalizeTrackText(track.artist ?? '');
    final duration = track.duration;

    if (title.isEmpty || artist.isEmpty || duration == null) return '';

    // 只在有时长时使用标题+歌手+时长去重，避免把同名但不同版本的歌曲误删。
    final roundedSeconds = duration.inMilliseconds <= 0
        ? 0
        : (duration.inMilliseconds / 1000).round();
    if (roundedSeconds <= 0) return '';

    return 'local:metadata:$artist::$title::$roundedSeconds';
  }

  String _localPathOf(MusicTrack track) {
    final raw = track.uri.trim().isNotEmpty ? track.uri : track.id;
    final uri = Uri.tryParse(raw);

    if (uri != null && uri.isScheme('file')) {
      try {
        return _safeDecode(uri.toFilePath()).replaceAll('\\', '/');
      } catch (_) {
        return _safeDecode(uri.path).replaceAll('\\', '/');
      }
    }

    if (raw.startsWith('file:')) {
      final fileUri = Uri.tryParse(raw);
      if (fileUri != null && fileUri.isScheme('file')) {
        try {
          return _safeDecode(fileUri.toFilePath()).replaceAll('\\', '/');
        } catch (_) {}
      }
    }

    return _safeDecode(track.id.replaceFirst('file:', '')).replaceAll('\\', '/');
  }

  String _normalizePath(String path) {
    var value = _safeDecode(path)
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+'), '/')
        .trim();

    if (Platform.isAndroid) {
      if (value == '/sdcard') value = '/storage/emulated/0';
      if (value.startsWith('/sdcard/')) {
        value = '/storage/emulated/0/${value.substring('/sdcard/'.length)}';
      }

      if (value == '/storage/self/primary') value = '/storage/emulated/0';
      if (value.startsWith('/storage/self/primary/')) {
        value = '/storage/emulated/0/${value.substring('/storage/self/primary/'.length)}';
      }

      if (value == '/mnt/sdcard') value = '/storage/emulated/0';
      if (value.startsWith('/mnt/sdcard/')) {
        value = '/storage/emulated/0/${value.substring('/mnt/sdcard/'.length)}';
      }
    }

    return value.replaceAll(RegExp(r'/+'), '/').toLowerCase();
  }

  String _safeDecode(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  String _audioIdOf(MusicTrack track) {
    final uri = Uri.tryParse(track.uri);
    final segments = uri?.pathSegments ?? const <String>[];
    final audioIndex = segments.indexWhere((e) => e.toLowerCase() == 'audio');
    if (audioIndex >= 0 && audioIndex + 1 < segments.length) {
      return segments[audioIndex + 1].toLowerCase();
    }
    return '';
  }

  String _normalizeTrackText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\.[a-z0-9]{2,5}$'), '')
        .replaceAll(RegExp(r'[\s_\-–—]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _restoreLastPlaybackSession() async {
    if (tracks.isEmpty) return;

    try {
      final player = Get.find<PlayerController>();
      await player.restoreLastPlaybackIfPossible(sortedTracks);
    } catch (e) {
      debugPrint('恢复上次播放失败: $e');
    }
  }

  void selectSourceType(MusicSourceType? type) {
    selectedSourceType.value = type;
    _cachedVisibleVersion = -1;
  }

  Future<void> setSortMode(TrackSortMode mode) async {
    sortMode.value = mode;
    _cachedSortedVersion = -1;
    _cachedVisibleVersion = -1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortModeKey, mode.name);

    // 如果当前播放队列来自首页，排序变化后不强制重建播放队列，避免打断播放。
    // 下一次点击歌曲时，会按新的排序生成队列。
  }

  List<MusicTrack> _sortTracks(Iterable<MusicTrack> input) {
    final list = input.toList();
    final mode = sortMode.value;

    list.sort((a, b) {
      final aPrimary = mode.isArtistMode ? a.artist ?? '' : a.title;
      final bPrimary = mode.isArtistMode ? b.artist ?? '' : b.title;

      final primary = _compareSortText(aPrimary, bPrimary);
      if (primary != 0) return mode.isDescending ? -primary : primary;

      final secondary = _compareSortText(a.title, b.title);
      if (secondary != 0) return secondary;

      return _compareSortText(a.id, b.id);
    });

    return List.unmodifiable(list);
  }

  int _compareSortText(String a, String b) {
    final aKey = _sortKeyCached(a);
    final bKey = _sortKeyCached(b);
    return aKey.compareTo(bKey);
  }

  String _sortKeyCached(String value) {
    return _sortKeyCache.putIfAbsent(value, () => _sortKey(value));
  }

  String _sortKey(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '~~~~';

    final buffer = StringBuffer();
    for (final rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      if (_isCjkRune(rune)) {
        try {
          buffer.write(PinyinHelper.getPinyinE(
            char,
            separator: '',
            defPinyin: char,
          ));
        } catch (_) {
          buffer.write(char);
        }
      } else {
        buffer.write(char);
      }
    }

    return buffer
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isCjkRune(int rune) {
    return (rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF) ||
        (rune >= 0x20000 && rune <= 0x2A6DF);
  }

  /// 当前排序维度下的首字母，用于首页右侧 A-Z 快速索引。
  String indexLetterForTrack(MusicTrack track) {
    final raw = sortMode.value.isArtistMode ? (track.artist ?? track.title) : track.title;
    final key = _sortKeyCached(raw);
    if (key.isEmpty) return '#';
    final first = key.substring(0, 1).toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
  }
}

// 首页歌曲排序方式。默认按歌曲名称 A-Z。
enum TrackSortMode { titleAsc, titleDesc, artistAsc, artistDesc }

extension TrackSortModeText on TrackSortMode {
  String get label {
    switch (this) {
      case TrackSortMode.titleAsc:
        return 'sort.titleAsc'.tr;
      case TrackSortMode.titleDesc:
        return 'sort.titleDesc'.tr;
      case TrackSortMode.artistAsc:
        return 'sort.artistAsc'.tr;
      case TrackSortMode.artistDesc:
        return 'sort.artistDesc'.tr;
    }
  }

  bool get isArtistMode {
    return this == TrackSortMode.artistAsc || this == TrackSortMode.artistDesc;
  }

  bool get isDescending {
    return this == TrackSortMode.titleDesc || this == TrackSortMode.artistDesc;
  }
}


enum _LocalImportType { files, folder }

class _LocalImportDialog extends StatelessWidget {
  const _LocalImportDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('import.localTitle'.tr),
      content: Text('import.localDesc'.tr),
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.audio_file_rounded),
          label: Text('import.files'.tr),
          onPressed: () => Get.back(result: _LocalImportType.files),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.folder_open_rounded),
          label: Text('import.folder'.tr),
          onPressed: () => Get.back(result: _LocalImportType.folder),
        ),
      ],
    );
  }
}

String musicSourceLabel(MusicSourceType? type) {
  switch (type) {
    case null:
      return 'source.all'.tr;
    case MusicSourceType.localFile:
      return 'source.local'.tr;
    case MusicSourceType.webDav:
      return 'source.webdav'.tr;
    case MusicSourceType.emby:
      return 'source.emby'.tr;
    case MusicSourceType.jellyfin:
      return 'source.jellyfin'.tr;
    case MusicSourceType.navidrome:
      return 'source.navidrome'.tr;
    case MusicSourceType.directUrl:
      return 'source.directUrl'.tr;
  }
}

class _SimpleErrorDialog extends StatelessWidget {
  const _SimpleErrorDialog({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('common.ok'.tr)),
      ],
    );
  }
}
