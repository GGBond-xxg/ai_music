import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_track.dart';
import '../models/play_mode.dart';
import '../models/spotify_device.dart';
import '../services/local_music_service.dart';
import '../services/playback_notification_service.dart';

export '../models/play_mode.dart';

/// Compatibility provider kept under the original name so the Music UI can
/// stay intact while playback/data now come from local/NAS/Emby/Jellyfin/
/// Navidrome sources instead of online streaming APIs.
class SpotifyProvider extends ChangeNotifier {
  SpotifyProvider() {
    mk.MediaKit.ensureInitialized();
    _player = mk.Player();
    _availableDevices = [
      SpotifyDevice(
        id: 'local-device',
        name: '本机播放器',
        type: SpotifyDeviceType.smartphone,
        isActive: true,
        isPrivateSession: false,
        isRestricted: false,
        volumePercent: 100,
        supportsVolume: true,
      ),
    ];
    _bindPlayerStreams();
    _bindNativeControlChannel();
    _libraryLoadFuture = _loadLibraryFromStorage();
  }

  static const _tracksKey = 'spotoolfy.local_sources.tracks.v1';
  static const _currentTrackIdKey = 'spotoolfy.local_sources.current_track_id.v1';
  static const _lastPlayedImageKey = 'last_played_image_url';
  static const _lastPlayedTrackNameKey = 'last_played_track_name';
  static const _lastPlayedArtistsKey = 'last_played_artists';
  static const _autoPlayOnOpenKey = 'spotoolfy.settings.auto_play_on_open.v1';
  static const _initialDeviceScanRequestedKey =
      'spotoolfy.settings.initial_device_scan_requested.v1';

  final Logger logger = Logger();
  final Random _random = Random();

  static const MethodChannel _widgetChannel = MethodChannel('com.chatlee.aimusic/widget');

  late final mk.Player _player;
  Future<void>? _libraryLoadFuture;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;

  String? username = 'Local Sources';
  bool isLoading = false;

  final List<MusicTrack> _libraryTracks = [];
  final List<MusicTrack> _queue = [];
  final List<Map<String, dynamic>> _recentlyPlayedRaw = [];
  int _currentIndex = -1;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  String? _loadedPlayerTrackKey; // 当前 media_kit 底层已真正 open 的歌曲，用于避免启动后先 seek 再 play 出现无声。
  bool? _isCurrentTrackSaved = true;
  bool _autoPlayOnOpen = false;
  bool _initialDeviceScanInProgress = false;
  bool _isHandlingCompletion = false;
  PlayMode _currentMode = PlayMode.sequential;
  String? _lastPlayedImageUrl;
  String? _lastPlayedTrackName;
  String? _lastPlayedArtists;
  String? _activeContextName;
  String? _activeContextType;
  Map<String, dynamic>? _currentTrack;
  Map<String, dynamic>? _previousTrack;
  Map<String, dynamic>? _nextTrack;
  List<Map<String, dynamic>> _upcomingTracks = [];
  List<SpotifyDevice> _availableDevices = [];
  String? _activeDeviceId = 'local-device';

  List<MusicTrack> get libraryTracks => List.unmodifiable(_libraryTracks);
  List<MusicSourceType> get availableSourceTypes {
    final types = <MusicSourceType>{};
    for (final track in _libraryTracks) {
      types.add(track.sourceType);
    }
    return types.toList(growable: false)
      ..sort((a, b) => a.index.compareTo(b.index));
  }

  List<Map<String, dynamic>> get libraryItems =>
      _libraryTracks.map(_trackToGridItem).toList(growable: false);

  Map<String, dynamic>? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  set currentTrack(Map<String, dynamic>? value) {
    _currentTrack = value;
    notifyListeners();
  }

  bool? get isCurrentTrackSaved => _isCurrentTrackSaved;
  bool get autoPlayOnOpen => _autoPlayOnOpen;
  bool get initialDeviceScanInProgress => _initialDeviceScanInProgress;

  set isCurrentTrackSaved(bool? value) {
    _isCurrentTrackSaved = value;
    notifyListeners();
  }

  Map<String, dynamic>? get previousTrack => _previousTrack;
  set previousTrack(Map<String, dynamic>? value) {
    _previousTrack = value;
    notifyListeners();
  }

  Map<String, dynamic>? get nextTrack => _nextTrack;
  set nextTrack(Map<String, dynamic>? value) {
    _nextTrack = value;
    notifyListeners();
  }

  List<Map<String, dynamic>> get upcomingTracks => _upcomingTracks;
  set upcomingTracks(List<Map<String, dynamic>> value) {
    _upcomingTracks = value;
    notifyListeners();
  }

  PlayMode get currentMode => _currentMode;
  List<SpotifyDevice> get availableDevices => _availableDevices;
  String? get activeDeviceId => _activeDeviceId;
  SpotifyDevice? get activeDevice => _availableDevices.isEmpty
      ? null
      : _availableDevices.firstWhere(
          (device) => device.id == _activeDeviceId,
          orElse: () => _availableDevices.first,
        );

  String? get lastPlayedImageUrl => _lastPlayedImageUrl;
  String? get lastPlayedTrackName => _lastPlayedTrackName;
  String? get lastPlayedArtists => _lastPlayedArtists;


  void _bindNativeControlChannel() {
    _widgetChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'togglePlayPause':
          await togglePlayPause();
          return null;
        case 'skipToPrevious':
          await skipToPrevious();
          return null;
        case 'skipToNext':
          await skipToNext();
          return null;
        default:
          return null;
      }
    });
  }

  void _bindPlayerStreams() {
    _positionSub = _player.stream.position.listen((value) {
      _position = value;
      _rebuildPlaybackMaps(notify: true);
    });

    _durationSub = _player.stream.duration.listen((value) {
      _duration = value;
      _rebuildPlaybackMaps(notify: true);
    });

    _playingSub = _player.stream.playing.listen((value) {
      _isPlaying = value;
      _rebuildPlaybackMaps(notify: true);
    });

    _completedSub = _player.stream.completed.listen((completed) {
      if (completed) {
        unawaited(_handleCompleted());
      }
    });

    _errorSub = _player.stream.error.listen((error) {
      if (error.trim().isEmpty) return;
      logger.w('本地播放器错误: $error');
      _isPlaying = false;
      _rebuildPlaybackMaps(notify: true);
    });
  }

  Future<void> _loadLibraryFromStorage() async {
    isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _lastPlayedImageUrl = prefs.getString(_lastPlayedImageKey);
      _lastPlayedTrackName = prefs.getString(_lastPlayedTrackNameKey);
      _lastPlayedArtists = prefs.getString(_lastPlayedArtistsKey);
      _autoPlayOnOpen = prefs.getBool(_autoPlayOnOpenKey) ?? false;

      final raw = prefs.getString(_tracksKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final list = jsonDecode(raw);
        if (list is List) {
          _libraryTracks
            ..clear()
            ..addAll(
              list.whereType<Map>().map(
                    (item) => MusicTrack.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  ),
            );
        }
      }

      _queue
        ..clear()
        ..addAll(_libraryTracks);

      final lastId = prefs.getString(_currentTrackIdKey);
      if (_queue.isNotEmpty) {
        final restoredIndex = lastId == null
            ? -1
            : _queue.indexWhere((track) => track.id == lastId || track.uri == lastId);
        _currentIndex = restoredIndex >= 0 ? restoredIndex : 0;
        _activeContextName = _sourceLabel(_queue[_currentIndex]);
        _activeContextType = 'source';
        _rebuildPlaybackMaps(notify: false);
        if (_autoPlayOnOpen && !_isPlaying) {
          unawaited(_playIndex(_currentIndex, contextName: _activeContextName));
        }
      } else if (_autoPlayOnOpen) {
        _autoPlayOnOpen = false;
        unawaited(prefs.setBool(_autoPlayOnOpenKey, false));
      }
    } catch (e, s) {
      logger.w('读取本地音乐库缓存失败', error: e, stackTrace: s);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setAutoPlayOnOpen(bool value) async {
    if (value && _libraryTracks.isEmpty) {
      value = false;
    }
    _autoPlayOnOpen = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPlayOnOpenKey, value);
    notifyListeners();
  }

  Future<void> requestInitialDeviceScan() async {
    await (_libraryLoadFuture ?? Future<void>.value());
    if (_initialDeviceScanInProgress || _libraryTracks.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    _initialDeviceScanInProgress = true;
    notifyListeners();

    try {
      final tracks = await LocalMusicService().scanDeviceAudio();
      await prefs.setBool(_initialDeviceScanRequestedKey, true);
      if (tracks.isNotEmpty) {
        await importTracks(
          tracks,
          sourceName: '本地音乐',
          playFirst: _autoPlayOnOpen,
        );
      } else if (_autoPlayOnOpen) {
        await setAutoPlayOnOpen(false);
      }
    } catch (e, s) {
      logger.w('首次扫描本地音乐失败', error: e, stackTrace: s);
      await prefs.setBool(_initialDeviceScanRequestedKey, true);
    } finally {
      _initialDeviceScanInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _persistLibrary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _tracksKey,
        jsonEncode(_libraryTracks.map((track) => track.toJson()).toList()),
      );
      final track = _currentQueueTrack;
      if (track != null) {
        await prefs.setString(_currentTrackIdKey, track.id);
      }
    } catch (e, s) {
      logger.w('保存本地音乐库失败', error: e, stackTrace: s);
    }
  }

  Future<void> importTracks(
    List<MusicTrack> tracks, {
    String? sourceName,
    bool replace = false,
    bool playFirst = false,
  }) async {
    if (tracks.isEmpty) return;

    isLoading = true;
    notifyListeners();

    try {
      if (replace) {
        _libraryTracks.clear();
        _queue.clear();
        _currentIndex = -1;
      }

      final hadCurrentTrack = _currentQueueTrack != null || _currentTrack != null;
      final currentKey = _currentQueueTrack == null ? null : _dedupeKey(_currentQueueTrack!);
      final wasPlaying = _isPlaying;
      final knownKeys = <String>{
        for (final track in _libraryTracks) _dedupeKey(track),
      };

      final inserted = <MusicTrack>[];
      for (final track in tracks) {
        final key = _dedupeKey(track);
        if (knownKeys.add(key)) {
          _libraryTracks.add(track);
          inserted.add(track);
        }
      }

      _libraryTracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      _queue
        ..clear()
        ..addAll(_libraryTracks);

      if (currentKey != null) {
        final preservedIndex = _queue.indexWhere((track) => _dedupeKey(track) == currentKey);
        if (preservedIndex >= 0) {
          _currentIndex = preservedIndex;
        }
      }

      if (_currentIndex < 0 && _queue.isNotEmpty) {
        _currentIndex = 0;
      }

      if (inserted.isNotEmpty) {
        final firstInserted = inserted.first;
        final index = _queue.indexWhere((track) => _dedupeKey(track) == _dedupeKey(firstInserted));
        if (playFirst && index >= 0 && !wasPlaying && !hadCurrentTrack) {
          await _playIndex(index, contextName: sourceName ?? _sourceLabel(firstInserted));
        } else {
          final current = _currentQueueTrack;
          if (current != null) {
            _activeContextName = _activeContextName ?? sourceName ?? _sourceLabel(current);
            _activeContextType = 'source';
            _rebuildPlaybackMaps(notify: false);
          }
        }
      }

      await _persistLibrary();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> replaceLibrary(List<MusicTrack> tracks, {String? sourceName}) {
    return importTracks(
      tracks,
      sourceName: sourceName,
      replace: true,
      playFirst: tracks.isNotEmpty && _autoPlayOnOpen,
    );
  }

  Future<void> clearLocalLibrary() async {
    _libraryTracks.clear();
    _queue.clear();
    _recentlyPlayedRaw.clear();
    _currentIndex = -1;
    _position = Duration.zero;
    _duration = Duration.zero;
    _loadedPlayerTrackKey = null;
    _currentTrack = null;
    _previousTrack = null;
    _nextTrack = null;
    _upcomingTracks = [];
    _autoPlayOnOpen = false;
    await _player.stop();
    _loadedPlayerTrackKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPlayOnOpenKey, false);
    await _persistLibrary();
    notifyListeners();
  }

  Future<void> clearMusicBySource(MusicSourceType sourceType) async {
    final currentTrack = _currentQueueTrack;
    final removingCurrent = currentTrack?.sourceType == sourceType;

    _libraryTracks.removeWhere((track) => track.sourceType == sourceType);
    _queue.removeWhere((track) => track.sourceType == sourceType);
    _recentlyPlayedRaw.removeWhere((item) => item['sourceType']?.toString() == sourceType.name);

    if (_queue.isEmpty) {
      _currentIndex = -1;
      _position = Duration.zero;
      _duration = Duration.zero;
      _currentTrack = null;
      _previousTrack = null;
      _nextTrack = null;
      _upcomingTracks = [];
      _autoPlayOnOpen = false;
      await _player.stop();
      _loadedPlayerTrackKey = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoPlayOnOpenKey, false);
    } else {
      if (_currentIndex >= _queue.length) _currentIndex = _queue.length - 1;
      if (_currentIndex < 0) _currentIndex = 0;
      _activeContextName = _sourceLabel(_queue[_currentIndex]);
      _activeContextType = 'source';
      if (removingCurrent) {
        await _player.stop();
        _loadedPlayerTrackKey = null;
        _position = Duration.zero;
        _duration = Duration.zero;
      }
      _rebuildPlaybackMaps(notify: false);
    }

    await _persistLibrary();
    notifyListeners();
  }

  String _dedupeKey(MusicTrack track) {
    final id = track.id.trim();
    if (id.isNotEmpty) return id.toLowerCase();
    return track.uri.trim().toLowerCase();
  }

  MusicTrack? get _currentQueueTrack {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return null;
    return _queue[_currentIndex];
  }

  Future<void> _handleCompleted() async {
    if (_isHandlingCompletion) return;
    _isHandlingCompletion = true;
    try {
      if (_currentMode == PlayMode.singleRepeat) {
        await seekToPosition(0);
        await _player.play();
        return;
      }
      await skipToNext();
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        _isHandlingCompletion = false;
      });
    }
  }

  Future<void> _playIndex(
    int index, {
    bool autoStart = true,
    String? contextName,
    String contextType = 'source',
  }) async {
    if (index < 0 || index >= _queue.length) return;

    _currentIndex = index;
    _position = Duration.zero;
    _duration = _queue[index].duration ?? Duration.zero;
    _activeContextName = contextName ?? _sourceLabel(_queue[index]);
    _activeContextType = contextType;
    _rebuildPlaybackMaps(notify: true);

    final uri = _playbackUri(_queue[index]);
    try {
      await _player.open(mk.Media(uri.toString()), play: autoStart);
      _loadedPlayerTrackKey = _dedupeKey(_queue[index]);
      _isPlaying = autoStart;
      _rememberPlayedTrack(_queue[index]);
      await _persistLibrary();
    } catch (e, s) {
      logger.w('打开音乐失败: $uri', error: e, stackTrace: s);
      _loadedPlayerTrackKey = null;
      _isPlaying = false;
    }
    _rebuildPlaybackMaps(notify: true);
  }

  bool get _isCurrentTrackLoaded {
    final track = _currentQueueTrack;
    if (track == null) return false;
    return _loadedPlayerTrackKey == _dedupeKey(track);
  }

  Future<bool> _ensureCurrentTrackLoaded({bool autoStart = false}) async {
    final track = _currentQueueTrack;
    if (track == null) return false;
    if (_isCurrentTrackLoaded) return true;

    final uri = _playbackUri(track);
    final targetPosition = _position;
    try {
      await _player.open(mk.Media(uri.toString()), play: autoStart);
      _loadedPlayerTrackKey = _dedupeKey(track);

      // App 刚启动后，UI 会恢复上次歌曲和进度，但 media_kit 底层还没有 open。
      // 如果用户这时先拖动进度条，再点播放，必须先 open 再 seek，否则会出现进度走但无声。
      if (targetPosition > Duration.zero) {
        await _player.seek(targetPosition);
        _position = targetPosition;
      }

      _isPlaying = autoStart;
      _rememberPlayedTrack(track);
      await _persistLibrary();
      _rebuildPlaybackMaps(notify: true);
      return true;
    } catch (e, s) {
      logger.w('准备播放器失败: $uri', error: e, stackTrace: s);
      _loadedPlayerTrackKey = null;
      _isPlaying = false;
      _rebuildPlaybackMaps(notify: true);
      return false;
    }
  }

  Uri _playbackUri(MusicTrack track) {
    final parsed = Uri.tryParse(track.uri);
    if (parsed != null && parsed.hasScheme) {
      if (track.sourceType == MusicSourceType.jellyfin &&
          parsed.path.contains('/Audio/') &&
          parsed.path.endsWith('/universal')) {
        final params = Map<String, String>.from(parsed.queryParameters)
          ..remove('AudioCodec')
          ..remove('TranscodingContainer')
          ..remove('TranscodingProtocol')
          ..remove('MaxStreamingBitrate');
        params['Static'] = 'true';
        return parsed.replace(
          path: parsed.path.replaceFirst('/universal', '/stream'),
          queryParameters: params,
        );
      }
      return parsed;
    }
    return Uri.file(track.uri);
  }

  void _rememberPlayedTrack(MusicTrack track) {
    _lastPlayedTrackName = track.title;
    _lastPlayedArtists = track.artist ?? 'Unknown Artist';
    final image = _networkCover(track);
    if (image != null) _lastPlayedImageUrl = image;

    final raw = {
      'track': _trackToSpotifyItem(track),
      'played_at': DateTime.now().toIso8601String(),
      'context': {
        'type': _activeContextType ?? 'source',
        'name': _activeContextName ?? _sourceLabel(track),
        'uri': 'local:source:${track.sourceType.name}',
      },
    };
    _recentlyPlayedRaw.insert(0, raw);
    if (_recentlyPlayedRaw.length > 100) {
      _recentlyPlayedRaw.removeRange(100, _recentlyPlayedRaw.length);
    }

    SharedPreferences.getInstance().then((prefs) {
      if (_lastPlayedTrackName != null) {
        prefs.setString(_lastPlayedTrackNameKey, _lastPlayedTrackName!);
      }
      if (_lastPlayedArtists != null) {
        prefs.setString(_lastPlayedArtistsKey, _lastPlayedArtists!);
      }
      if (_lastPlayedImageUrl != null) {
        prefs.setString(_lastPlayedImageKey, _lastPlayedImageUrl!);
      }
    });
  }

  void _rebuildPlaybackMaps({required bool notify}) {
    final track = _currentQueueTrack;
    if (track == null) {
      _currentTrack = null;
      _previousTrack = null;
      _nextTrack = null;
      _upcomingTracks = [];
      if (notify) {
        unawaited(PlaybackNotificationService.cancel());
        notifyListeners();
      }
      return;
    }

    final duration = _effectiveDuration(track);
    _currentTrack = {
      'is_playing': _isPlaying,
      'progress_ms': _position.inMilliseconds.clamp(0, duration.inMilliseconds).toInt(),
      'item': _trackToSpotifyItem(track, duration: duration),
      'context': {
        'type': _activeContextType ?? 'source',
        'name': _activeContextName ?? _sourceLabel(track),
        'uri': 'local:source:${track.sourceType.name}',
      },
      'device': activeDevice?.toJson(),
    };

    _previousTrack = _queue.length > 1
        ? _trackToSpotifyItem(_queue[(_currentIndex - 1 + _queue.length) % _queue.length])
        : null;
    _nextTrack = _queue.length > 1
        ? _trackToSpotifyItem(_queue[(_currentIndex + 1) % _queue.length])
        : null;
    _upcomingTracks = [
      for (var i = 1; i < min(21, _queue.length); i++)
        _trackToSpotifyItem(_queue[(_currentIndex + i) % _queue.length]),
    ];

    if (notify) {
      unawaited(_updateSystemPlaybackNotification(track));
      notifyListeners();
    }
  }

  Future<void> _updateSystemPlaybackNotification(MusicTrack track) async {
    await PlaybackNotificationService.update(
      title: track.title,
      artist: track.artist?.trim().isNotEmpty == true ? track.artist!.trim() : 'Unknown Artist',
      source: _sourceLabel(track),
      isPlaying: _isPlaying,
      coverUrl: _networkCover(track),
    );
  }

  Duration _effectiveDuration(MusicTrack track) {
    if (_duration > Duration.zero) return _duration;
    if (track.duration != null && track.duration! > Duration.zero) return track.duration!;
    return const Duration(milliseconds: 1);
  }

  Map<String, dynamic> _trackToGridItem(MusicTrack track) {
    final item = _trackToSpotifyItem(track);
    return {
      ...item,
      'type': 'track',
      'sourceType': track.sourceType.name,
      'sourceLabel': _sourceLabel(track),
    };
  }

  Map<String, dynamic> _trackToSpotifyItem(MusicTrack track, {Duration? duration}) {
    final cover = _networkCover(track);
    final albumName = (track.album?.trim().isNotEmpty ?? false)
        ? track.album!.trim()
        : _sourceLabel(track);
    final artistName = (track.artist?.trim().isNotEmpty ?? false)
        ? track.artist!.trim()
        : 'Unknown Artist';
    final durationMs = (duration ?? track.duration ?? const Duration(milliseconds: 1)).inMilliseconds;

    return {
      'id': track.id.isNotEmpty ? track.id : track.uri,
      'name': track.title,
      'title': track.title,
      'uri': track.uri,
      'href': track.uri,
      'duration_ms': durationMs <= 0 ? 1 : durationMs,
      'artists': [
        {
          'id': artistName,
          'name': artistName,
          'uri': 'local:artist:$artistName',
          'url': null,
          'external_urls': <String, dynamic>{},
        }
      ],
      'album': {
        'id': albumName,
        'name': albumName,
        'uri': 'local:album:$albumName',
        'images': cover == null
            ? <Map<String, dynamic>>[]
            : [
                {'url': cover}
              ],
        'external_urls': <String, dynamic>{},
      },
      'images': cover == null
          ? <Map<String, dynamic>>[]
          : [
              {'url': cover}
            ],
      'external_urls': <String, dynamic>{},
      'external_ids': <String, dynamic>{},
      'sourceType': track.sourceType.name,
      'sourceLabel': _sourceLabel(track),
      'lyricText': track.lyricText,
    };
  }

  String? _networkCover(MusicTrack track) {
    final cover = track.coverUri?.trim();
    if (cover == null || cover.isEmpty) return null;
    return cover;
  }

  String _sourceLabel(MusicTrack track) {
    switch (track.sourceType) {
      case MusicSourceType.localFile:
        return '本地音乐';
      case MusicSourceType.webDav:
        return 'NAS / WebDAV';
      case MusicSourceType.emby:
        return 'Emby';
      case MusicSourceType.jellyfin:
        return 'Jellyfin';
      case MusicSourceType.navidrome:
        return 'Navidrome / Subsonic';
      case MusicSourceType.directUrl:
        return 'Direct URL';
    }
  }

  void clearImageCache() {}
  bool isImageCached(String? imageUrl) => false;
  Future<void> loadLastPlayedTrackInfo() async {}
  Future<bool> checkAuthHealth() async => true;
  Future<void> setClientCredentials(String clientId) async {}
  Future<Map<String, String?>> getClientCredentials() async => {'clientId': null};
  Future<void> resetClientCredentials() async {}
  Future<void> refreshAvailableDevices() async {
    notifyListeners();
  }

  Future<void> transferPlaybackToDevice(String deviceId, {bool play = false}) async {
    _activeDeviceId = deviceId;
    if (play) await togglePlayPause();
    notifyListeners();
  }

  Future<void> setDeviceVolume(String deviceId, int volumePercent) async {
    final safe = volumePercent.clamp(0, 100).toInt();
    await _player.setVolume(safe.toDouble());
    _availableDevices = [
      SpotifyDevice(
        id: 'local-device',
        name: '本机播放器',
        type: SpotifyDeviceType.smartphone,
        isActive: true,
        isPrivateSession: false,
        isRestricted: false,
        volumePercent: safe,
        supportsVolume: true,
      ),
    ];
    notifyListeners();
  }

  void startTrackRefresh() => _rebuildPlaybackMaps(notify: true);
  Future<void> refreshCurrentTrack() async => _rebuildPlaybackMaps(notify: true);
  Future<void> checkCurrentTrackSaveState() async {
    _isCurrentTrackSaved = _currentQueueTrack != null;
    notifyListeners();
  }

  Future<void> handleCallbackToken(String accessToken, String? expiresIn) async {}
  Future<void> autoLogin() async {
    username = 'Local Sources';
    await (_libraryLoadFuture ?? Future<void>.value());
  }

  Future<void> login() async {
    username = 'Local Sources';
    notifyListeners();
  }

  Future<void> logout() async {
    await clearLocalLibrary();
    username = 'Local Sources';
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_queue.isEmpty && _libraryTracks.isNotEmpty) {
      _queue.addAll(_libraryTracks);
      _currentIndex = 0;
    }
    if (_currentQueueTrack == null) return;

    if (_isPlaying) {
      await _player.pause();
      _isPlaying = false;
    } else {
      final ready = await _ensureCurrentTrackLoaded(autoStart: false);
      if (!ready) return;
      await _player.play();
      _isPlaying = true;
    }
    _rebuildPlaybackMaps(notify: true);
  }

  Future<void> seekToPosition(int positionMs) async {
    if (_queue.isEmpty && _libraryTracks.isNotEmpty) {
      _queue.addAll(_libraryTracks);
      _currentIndex = 0;
    }
    if (_currentQueueTrack == null) return;

    final safeMs = positionMs < 0 ? 0 : positionMs;
    final position = Duration(milliseconds: safeMs);
    _position = position;

    final ready = await _ensureCurrentTrackLoaded(autoStart: false);
    if (ready) {
      await _player.seek(position);
      _position = position;
    }
    _rebuildPlaybackMaps(notify: true);
  }

  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    if (_currentMode == PlayMode.shuffle && _queue.length > 1) {
      var next = _random.nextInt(_queue.length);
      if (next == _currentIndex) next = (next + 1) % _queue.length;
      await _playIndex(next);
      return;
    }
    await _playIndex((_currentIndex + 1) % _queue.length);
  }

  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    await _playIndex((_currentIndex - 1 + _queue.length) % _queue.length);
  }

  Future<void> toggleTrackSave() async {
    _isCurrentTrackSaved = !(_isCurrentTrackSaved ?? false);
    notifyListeners();
  }

  Future<void> refreshPlaybackQueue() async => _rebuildPlaybackMaps(notify: true);
  Future<void> syncPlaybackMode() async => notifyListeners();

  Future<void> setPlayMode(PlayMode mode) async {
    _currentMode = mode;
    notifyListeners();
  }

  Future<void> togglePlayMode() async {
    switch (_currentMode) {
      case PlayMode.sequential:
        _currentMode = PlayMode.shuffle;
        break;
      case PlayMode.shuffle:
        _currentMode = PlayMode.singleRepeat;
        break;
      case PlayMode.singleRepeat:
        _currentMode = PlayMode.sequential;
        break;
    }
    notifyListeners();
  }

  Future<void> playItem(Map<String, dynamic> item) async {
    final uri = item['uri']?.toString();
    final id = item['id']?.toString();
    if (uri != null && uri.isNotEmpty) {
      await playTrack(trackUri: uri);
      return;
    }
    if (id != null && id.isNotEmpty) {
      await playTrack(trackUri: id);
    }
  }

  Future<void> playContext({
    required String type,
    required String id,
    String? deviceId,
  }) async {
    if (_libraryTracks.isEmpty) return;

    List<MusicTrack> contextTracks;
    String contextName;
    String contextType = type;

    if (type == 'album') {
      contextTracks = _libraryTracks.where((track) => (track.album ?? _sourceLabel(track)) == id).toList();
      if (contextTracks.isEmpty) {
        contextTracks = _libraryTracks.where((track) => track.id == id || track.uri == id).toList();
      }
      contextName = contextTracks.isEmpty ? 'Album' : (contextTracks.first.album ?? _sourceLabel(contextTracks.first));
    } else if (type == 'playlist' || type == 'source') {
      contextTracks = _libraryTracks.where((track) => track.sourceType.name == id || _sourceLabel(track) == id).toList();
      contextName = contextTracks.isEmpty ? '资料库' : _sourceLabel(contextTracks.first);
      contextType = 'source';
    } else if (type == 'track') {
      contextTracks = _libraryTracks.where((track) => track.id == id || track.uri == id).toList();
      contextName = contextTracks.isEmpty ? '资料库' : _sourceLabel(contextTracks.first);
    } else {
      contextTracks = _libraryTracks;
      contextName = '资料库';
    }

    if (contextTracks.isEmpty) contextTracks = _libraryTracks;
    _queue
      ..clear()
      ..addAll(contextTracks);
    await _playIndex(0, contextName: contextName, contextType: contextType);
  }

  Future<void> playTrack({
    required String trackUri,
    String? deviceId,
    String? contextUri,
  }) async {
    if (_libraryTracks.isEmpty) return;
    var index = _queue.indexWhere((track) => track.uri == trackUri || track.id == trackUri);
    if (index < 0) {
      _queue
        ..clear()
        ..addAll(_libraryTracks);
      index = _queue.indexWhere((track) => track.uri == trackUri || track.id == trackUri);
    }
    if (index < 0) return;
    await _playIndex(index, contextName: _sourceLabel(_queue[index]));
  }

  Future<void> playTrackInContext({
    required String contextUri,
    required String trackUri,
    int? offsetIndex,
    String? deviceId,
  }) async {
    if (offsetIndex != null && offsetIndex >= 0 && offsetIndex < _queue.length) {
      await _playIndex(offsetIndex);
      return;
    }
    await playTrack(trackUri: trackUri, contextUri: contextUri, deviceId: deviceId);
  }

  Future<void> playTracks({
    required List<String> trackUris,
    int offsetIndex = 0,
    String? deviceId,
  }) async {
    final selected = _libraryTracks
        .where((track) => trackUris.contains(track.uri) || trackUris.contains(track.id))
        .toList();
    if (selected.isEmpty) return;
    _queue
      ..clear()
      ..addAll(selected);
    await _playIndex(offsetIndex.clamp(0, selected.length - 1).toInt());
  }

  Future<Map<String, dynamic>> fetchAlbumDetails(String albumId, {bool forceRefresh = false}) async {
    final tracks = _libraryTracks.where((track) => (track.album ?? _sourceLabel(track)) == albumId || track.id == albumId).toList();
    final source = tracks.isNotEmpty ? tracks.first : (_libraryTracks.isNotEmpty ? _libraryTracks.first : null);
    final name = source?.album ?? albumId;
    return {
      'id': albumId,
      'name': name,
      'uri': 'local:album:$albumId',
      'artists': [
        {'name': source?.artist ?? 'Unknown Artist'}
      ],
      'images': _networkCover(source ?? const MusicTrack(id: '', title: '', uri: '', sourceType: MusicSourceType.localFile)) == null
          ? <Map<String, dynamic>>[]
          : [
              {'url': _networkCover(source!)}
            ],
      'tracks': {
        'items': tracks.map(_trackToSpotifyItem).toList(),
      },
    };
  }

  Future<Map<String, dynamic>> fetchPlaylistDetails(String playlistId, {bool forceRefresh = false}) async {
    final tracks = _libraryTracks.where((track) => track.sourceType.name == playlistId || _sourceLabel(track) == playlistId).toList();
    final contextTracks = tracks.isEmpty ? _libraryTracks : tracks;
    return {
      'id': playlistId,
      'name': contextTracks.isEmpty ? '资料库' : _sourceLabel(contextTracks.first),
      'uri': 'local:playlist:$playlistId',
      'images': <Map<String, dynamic>>[],
      'tracks': {
        'items': contextTracks.map(_trackToSpotifyItem).toList(),
      },
    };
  }

  List<Map<String, dynamic>> get recentPlaylists => getUserPlaylistsSync();
  List<Map<String, dynamic>> get recentAlbums => getUserSavedAlbumsSync();

  Future<void> refreshRecentlyPlayed() async => notifyListeners();
  Future<void> updateWidget() async {
    final track = _currentQueueTrack;
    try {
      await _widgetChannel.invokeMethod('updateWidget', {
        'songName': track?.title,
        'artistName': track?.artist,
        'albumArtUrl': track == null ? null : _networkCover(track),
        'isPlaying': _isPlaying,
      });
    } catch (_) {}
  }

  Future<Map<String, String>> getAuthenticatedHeaders() async => <String, String>{};

  Future<List<Map<String, dynamic>>> getUserPlaylists({int offset = 0, int limit = 50}) async => getUserPlaylistsSync();
  List<Map<String, dynamic>> getUserPlaylistsSync() {
    final bySource = <String, List<MusicTrack>>{};
    for (final track in _libraryTracks) {
      bySource.putIfAbsent(_sourceLabel(track), () => []).add(track);
    }
    return bySource.entries.map((entry) {
      final first = entry.value.first;
      final cover = _networkCover(first);
      return {
        'id': first.sourceType.name,
        'name': entry.key,
        'type': 'playlist',
        'uri': 'local:source:${first.sourceType.name}',
        'images': cover == null ? <Map<String, dynamic>>[] : [{'url': cover}],
        'tracks': {'total': entry.value.length},
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getUserSavedAlbums({int offset = 0, int limit = 50}) async => getUserSavedAlbumsSync();
  List<Map<String, dynamic>> getUserSavedAlbumsSync() {
    final byAlbum = <String, List<MusicTrack>>{};
    for (final track in _libraryTracks) {
      final album = (track.album?.trim().isNotEmpty ?? false) ? track.album!.trim() : _sourceLabel(track);
      byAlbum.putIfAbsent(album, () => []).add(track);
    }
    return byAlbum.entries.map((entry) {
      final first = entry.value.first;
      final cover = _networkCover(first);
      return {
        'id': entry.key,
        'name': entry.key,
        'type': 'album',
        'uri': 'local:album:${entry.key}',
        'artists': [
          {'name': first.artist ?? 'Unknown Artist'}
        ],
        'images': cover == null ? <Map<String, dynamic>>[] : [{'url': cover}],
        'tracks': {'total': entry.value.length},
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentlyPlayed() async {
    return _recentlyPlayedRaw.map((item) => Map<String, dynamic>.from(item['track'] as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentlyPlayedRawTracks({int limit = 50}) async {
    if (_recentlyPlayedRaw.isNotEmpty) {
      return _recentlyPlayedRaw.take(limit).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return _libraryTracks.take(limit).map((track) {
      return {
        'track': _trackToSpotifyItem(track),
        'played_at': DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  Future<Map<String, List<Map<String, dynamic>>>> searchItems(
    String query, {
    List<String> types = const ['track', 'album', 'artist', 'playlist'],
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return {'tracks': <Map<String, dynamic>>[]};
    final matched = _libraryTracks.where((track) {
      return track.title.toLowerCase().contains(q) ||
          (track.artist ?? '').toLowerCase().contains(q) ||
          (track.album ?? '').toLowerCase().contains(q) ||
          _sourceLabel(track).toLowerCase().contains(q);
    }).map(_trackToGridItem).toList();
    return {
      'tracks': matched,
      'albums': <Map<String, dynamic>>[],
      'artists': <Map<String, dynamic>>[],
      'playlists': <Map<String, dynamic>>[],
    };
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }
}
