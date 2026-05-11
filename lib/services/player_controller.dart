import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_track.dart';
import 'debug_trace.dart';

import 'player/media_kit_player.dart';
import 'player/play_mode.dart';

export 'player/media_kit_player.dart' show ProcessingState;
export 'player/play_mode.dart';

class PlayerController extends GetxController with WidgetsBindingObserver {
  static const _lastTrackIdKey = 'player.last_track_id.v1';
  static const _lastTrackUriKey = 'player.last_track_uri.v1';
  static const _lastPositionMsKey = 'player.last_position_ms.v1';
  static const _lastUpdatedAtKey = 'player.last_updated_at.v1';
  static const _lyricAlignKey = 'player.lyric_align.v1';
  static const _playModeKey = 'player.play_mode.v1';
  static const _playerSheetPageKey = 'player.sheet_page.v1';
  static const _volumeKey = 'player.volume.v1';

  final FreshMediaKitPlayer player = FreshMediaKitPlayer();

  final queue = <MusicTrack>[].obs;
  final currentIndex = (-1).obs;
  final playMode = PlayMode.sequence.obs;
  final lastError = ''.obs;
  final isPlayingNow = false.obs;
  final volume = 1.0.obs;
  final isMuted = false.obs;

  final lyricTextAlign = TextAlign.center.obs;
  final playerSheetPage = 0.obs;
  final sleepTimerRemaining = Rxn<Duration>();
  final isUserSeeking = false.obs;
  final seekPreviewPosition = Rxn<Duration>();

  /// UI 展示用播放进度。
  ///
  /// 重新打开 App 时 media_kit 还没真正 load 音源，底层 position/duration
  /// 可能暂时都是 0。这里先用上次保存的进度和歌曲缓存时长兜底，避免
  /// PC 底部控制栏 / PC 歌词页显示 0:00 / 0:00。
  final displayPosition = Duration.zero.obs;
  final displayDuration = Rxn<Duration>();

  final _random = Random();

  Timer? _persistTimer;
  Timer? _volumeApplyTimer;
  Timer? _volumeSaveTimer;
  Timer? _sleepTimer;
  Timer? _sleepTicker;
  DateTime? _sleepTimerEndAt;

  StreamSubscription<String>? _mediaErrorSub;
  DateTime? _lastPlaybackErrorAt;

  double? _pendingNativeVolume;
  double? _lastNativeVolume;
  DateTime? _lastNativeVolumeAt;
  double _lastNonZeroVolume = 1.0;

  bool _restoreAttempted = false;
  bool _handlingCompleted = false;
  bool _holdPlayingDuringSwitch = false;
  int _playRequestToken = 0;
  Future<void> _playSwitchChain = Future<void>.value();
  String? _loadedTrackId;
  String? _pendingRestoreTrackId;
  Duration _pendingRestorePosition = Duration.zero;

  MusicTrack? get currentTrack {
    final index = currentIndex.value;
    if (index < 0 || index >= queue.length) return null;
    return queue[index];
  }

  bool get hasSleepTimer => sleepTimerRemaining.value != null;

  String get sleepTimerLabel {
    final remaining = sleepTimerRemaining.value;
    if (remaining == null) return 'player.timerLabel'.tr;
    final totalSeconds = remaining.inSeconds <= 0 ? 0 : remaining.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void onInit() {
    super.onInit();

    DebugTrace.instance.log(
      'PLAYER_INIT',
      'onInit engine=media_kit platform=${Platform.operatingSystem}',
    );

    WidgetsBinding.instance.addObserver(this);

    unawaited(_loadLyricAlign());
    unawaited(_loadPlayMode());
    unawaited(_loadPlayerSheetPage());
    unawaited(_loadVolume());

    player.positionStream.listen((position) {
      displayPosition.value = position;
      _schedulePersistPlaybackState();
    });

    player.durationStream.listen((duration) {
      displayDuration.value = duration ?? currentTrack?.duration;
    });

    player.playingStream.listen((playing) {
      DebugTrace.instance.log(
        'PLAYER_EVENT',
        'playing=$playing currentIndex=${currentIndex.value} loaded=$_loadedTrackId state=${player.processingState}',
      );

      // 手动切歌时会先 pause 旧音源再 open 新音源。
      // 这里不要把 UI 立即切成“播放”按钮，否则会看到播放/暂停闪一下。
      if (!playing && _holdPlayingDuringSwitch) {
        _schedulePersistPlaybackState();
        return;
      }

      isPlayingNow.value = playing;
      _schedulePersistPlaybackState();
    });

    player.currentIndexStream.listen((index) {
      DebugTrace.instance.log(
        'PLAYER_EVENT',
        'media_kit currentIndex=$index dartIndex=${currentIndex.value}',
      );
    });

    player.processingStateStream.listen((state) async {
      DebugTrace.instance.log(
        'PLAYER_EVENT',
        'processingState=$state currentIndex=${currentIndex.value} loaded=$_loadedTrackId playing=${player.playing}',
      );

      if (state == ProcessingState.completed) {
        await _handleCompleted();
      }
    });

    _mediaErrorSub = player.errorStream.listen((error) {
      _handlePlaybackError(error);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_persistPlaybackStateNow());
    }
  }

  Duration lyricPositionFor(Duration playerPosition) {
    if (isUserSeeking.value) {
      final preview = seekPreviewPosition.value;
      if (preview != null) return preview;
    }
    return playerPosition;
  }

  void beginSeek(Duration position) {
    isUserSeeking.value = true;
    seekPreviewPosition.value = position;
  }

  void previewSeek(Duration position) {
    isUserSeeking.value = true;
    seekPreviewPosition.value = position;
  }

  Future<void> commitSeek(Duration position) async {
    isUserSeeking.value = true;
    seekPreviewPosition.value = position;

    try {
      await player.seek(position);
      unawaited(_persistPlaybackStateNow());
    } finally {
      isUserSeeking.value = false;
      seekPreviewPosition.value = null;
    }
  }

  void cancelSeekPreview() {
    isUserSeeking.value = false;
    seekPreviewPosition.value = null;
  }

  void cycleLyricAlign() {
    switch (lyricTextAlign.value) {
      case TextAlign.left:
        lyricTextAlign.value = TextAlign.center;
        break;
      case TextAlign.center:
        lyricTextAlign.value = TextAlign.right;
        break;
      case TextAlign.right:
        lyricTextAlign.value = TextAlign.left;
        break;
      default:
        lyricTextAlign.value = TextAlign.center;
    }

    unawaited(_saveLyricAlign());
  }

  Future<void> _loadLyricAlign() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_lyricAlignKey);
      switch (value) {
        case 'left':
          lyricTextAlign.value = TextAlign.left;
          break;
        case 'right':
          lyricTextAlign.value = TextAlign.right;
          break;
        case 'center':
        default:
          lyricTextAlign.value = TextAlign.center;
          break;
      }
    } catch (_) {}
  }

  Future<void> _saveLyricAlign() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (lyricTextAlign.value) {
        TextAlign.left || TextAlign.start => 'left',
        TextAlign.right || TextAlign.end => 'right',
        _ => 'center',
      };
      await prefs.setString(_lyricAlignKey, value);
    } catch (_) {}
  }

  Future<void> _loadPlayMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_playModeKey);
      final mode = PlayMode.values.firstWhere(
        (item) => item.name == raw,
        orElse: () => PlayMode.sequence,
      );
      await setPlayMode(mode, persist: false);
    } catch (_) {
      await setPlayMode(PlayMode.sequence, persist: false);
    }
  }

  Future<void> _savePlayMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_playModeKey, playMode.value.name);
    } catch (_) {}
  }

  Future<void> _loadPlayerSheetPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final page = (prefs.getInt(_playerSheetPageKey) ?? 0).clamp(0, 1).toInt();
      playerSheetPage.value = page;
    } catch (_) {
      playerSheetPage.value = 0;
    }
  }

  Future<void> setPlayerSheetPage(int page, {bool persist = true}) async {
    final safePage = page.clamp(0, 1).toInt();
    if (playerSheetPage.value != safePage) {
      playerSheetPage.value = safePage;
    }

    if (!persist) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_playerSheetPageKey, safePage);
    } catch (_) {}
  }

  String get lyricAlignLabel {
    switch (lyricTextAlign.value) {
      case TextAlign.left:
        return 'player.alignLeft'.tr;
      case TextAlign.right:
        return 'player.alignRight'.tr;
      case TextAlign.center:
      default:
        return 'player.alignCenter'.tr;
    }
  }

  IconData get lyricAlignIcon {
    switch (lyricTextAlign.value) {
      case TextAlign.left:
        return Icons.format_align_left_rounded;
      case TextAlign.right:
        return Icons.format_align_right_rounded;
      case TextAlign.center:
      default:
        return Icons.format_align_center_rounded;
    }
  }

  Future<void> _loadVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getDouble(_volumeKey) ?? 1.0;
      final safe = raw.clamp(0.0, 1.0).toDouble();
      volume.value = safe;
      isMuted.value = safe <= 0.001;
      if (safe > 0.001) _lastNonZeroVolume = safe;
      await player.setVolume(safe);
    } catch (_) {
      volume.value = 1.0;
      isMuted.value = false;
      _lastNonZeroVolume = 1.0;
      try {
        await player.setVolume(1.0);
      } catch (_) {}
    }
  }

  Future<void> _saveVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
          _volumeKey, volume.value.clamp(0.0, 1.0).toDouble());
    } catch (_) {}
  }

  void _scheduleVolumeSave() {
    _volumeSaveTimer?.cancel();
    _volumeSaveTimer = Timer(const Duration(milliseconds: 420), () {
      unawaited(_saveVolume());
    });
  }

  Future<void> _applyNativeVolume(double safe) async {
    _pendingNativeVolume = null;
    _lastNativeVolume = safe;
    _lastNativeVolumeAt = DateTime.now();
    try {
      await player.setVolume(safe);
    } catch (_) {}
  }

  Future<void> setVolume(double value, {bool persist = true}) async {
    final safe = value.clamp(0.0, 1.0).toDouble();
    volume.value = safe;
    isMuted.value = safe <= 0.001;
    if (safe > 0.001) {
      _lastNonZeroVolume = safe;
    }

    final now = DateTime.now();
    final lastAt = _lastNativeVolumeAt;
    final lastVolume = _lastNativeVolume;
    final elapsedMs =
        lastAt == null ? 9999 : now.difference(lastAt).inMilliseconds;
    final changedALot =
        lastVolume == null || (lastVolume - safe).abs() >= 0.045;
    final shouldApplyNow = elapsedMs >= 70 || changedALot || !persist;

    _pendingNativeVolume = safe;
    if (shouldApplyNow) {
      _volumeApplyTimer?.cancel();
      await _applyNativeVolume(safe);
    } else {
      _volumeApplyTimer?.cancel();
      _volumeApplyTimer = Timer(Duration(milliseconds: 70 - elapsedMs), () {
        final pending = _pendingNativeVolume;
        if (pending != null) {
          unawaited(_applyNativeVolume(pending));
        }
      });
    }

    if (persist) {
      _scheduleVolumeSave();
    }
  }

  Future<void> toggleMute() async {
    if (isMuted.value || volume.value <= 0.001) {
      final restore = _lastNonZeroVolume.clamp(0.08, 1.0).toDouble();
      await setVolume(restore);
      return;
    }

    _lastNonZeroVolume = volume.value.clamp(0.08, 1.0).toDouble();
    await setVolume(0.0);
  }

  void startSleepTimer(Duration duration) {
    if (duration <= Duration.zero) return;

    _sleepTimer?.cancel();
    _sleepTicker?.cancel();

    _sleepTimerEndAt = DateTime.now().add(duration);
    sleepTimerRemaining.value = duration;

    _sleepTimer = Timer(duration, () async {
      try {
        await player.pause();
      } catch (_) {}
      _clearSleepTimerState();
      Get.snackbar(
        'player.sleepTimer'.tr,
        'player.sleepTimeUp'.tr,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(milliseconds: 1400),
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      );
    });

    _startSleepTicker();
  }

  void cancelSleepTimer({bool showMessage = false}) {
    final hadTimer = sleepTimerRemaining.value != null;
    _sleepTimer?.cancel();
    _clearSleepTimerState();

    if (showMessage && hadTimer) {
      Get.snackbar(
        'player.sleepTimer'.tr,
        'player.timerCanceled'.tr,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(milliseconds: 1000),
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      );
    }
  }

  void _clearSleepTimerState() {
    _sleepTimer = null;
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _sleepTimerEndAt = null;
    sleepTimerRemaining.value = null;
  }

  void _startSleepTicker() {
    _sleepTicker?.cancel();
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final endAt = _sleepTimerEndAt;
      if (endAt == null) return;

      final remaining = endAt.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        sleepTimerRemaining.value = Duration.zero;
        return;
      }
      sleepTimerRemaining.value = remaining;
    });
  }

  Future<void> restoreLastPlaybackIfPossible(
      List<MusicTrack> libraryTracks) async {
    DebugTrace.instance.log(
      'RESTORE',
      'start attempted=$_restoreAttempted library=${libraryTracks.length}',
    );
    if (_restoreAttempted || libraryTracks.isEmpty) return;
    _restoreAttempted = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTrackId = prefs.getString(_lastTrackIdKey)?.trim() ?? '';
      final lastTrackUri = prefs.getString(_lastTrackUriKey)?.trim() ?? '';
      final positionMs = prefs.getInt(_lastPositionMsKey) ?? 0;

      if (lastTrackId.isEmpty && lastTrackUri.isEmpty) return;

      final index = libraryTracks.indexWhere((track) {
        if (lastTrackId.isNotEmpty && track.id == lastTrackId) return true;
        if (lastTrackUri.isNotEmpty && track.uri == lastTrackUri) return true;
        return false;
      });

      DebugTrace.instance.log(
        'RESTORE',
        'lastTrackId=$lastTrackId lastTrackUri=$lastTrackUri matchedIndex=$index positionMs=$positionMs',
      );
      if (index < 0) return;

      queue.assignAll(libraryTracks);
      currentIndex.value = index;
      player.emitCurrentIndex(index);
      _pendingRestoreTrackId = libraryTracks[index].id;
      _pendingRestorePosition =
          Duration(milliseconds: positionMs.clamp(0, 1 << 31).toInt());
      displayPosition.value = _pendingRestorePosition;
      displayDuration.value = libraryTracks[index].duration;
      _loadedTrackId = null;
      DebugTrace.instance.log(
        'RESTORE',
        'defer media_kit load track=${DebugTrace.instance.track(libraryTracks[index])} position=$_pendingRestorePosition',
      );
    } catch (e) {
      debugPrint('恢复上次播放状态失败: $e');
    }
  }

  void _schedulePersistPlaybackState() {
    _persistTimer?.cancel();
    _persistTimer = Timer(
      const Duration(seconds: 2),
      () => unawaited(_persistPlaybackStateNow()),
    );
  }

  Future<void> _persistPlaybackStateNow() async {
    final track = currentTrack;
    if (track == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final duration = player.duration ?? displayDuration.value ?? track.duration;
      var position = player.position;
      final displayedPosition = displayPosition.value;
      if (position == Duration.zero && displayedPosition > Duration.zero) {
        position = displayedPosition;
      }
      if (duration != null &&
          duration.inMilliseconds > 0 &&
          position > duration) {
        position = duration;
      }

      await prefs.setString(_lastTrackIdKey, track.id);
      await prefs.setString(_lastTrackUriKey, track.uri);
      await prefs.setInt(_lastPositionMsKey, position.inMilliseconds);
      await prefs.setInt(
          _lastUpdatedAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('保存播放状态失败: $e');
    }
  }

  Future<void> clearSavedPlaybackState({bool stopPlayer = true}) async {
    _persistTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastTrackIdKey);
      await prefs.remove(_lastTrackUriKey);
      await prefs.remove(_lastPositionMsKey);
      await prefs.remove(_lastUpdatedAtKey);
    } catch (_) {}

    if (stopPlayer) {
      await _stopSilently();
      queue.clear();
      currentIndex.value = -1;
      displayPosition.value = Duration.zero;
      displayDuration.value = null;
      player.emitCurrentIndex(null);
    }
  }

  Uri _playbackUriFor(MusicTrack track) {
    if (track.sourceType != MusicSourceType.localFile) {
      return Uri.parse(track.uri);
    }

    final raw = track.uri.trim();
    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.isScheme('file')) {
      return parsed;
    }

    final path = raw.isNotEmpty ? raw : track.id;
    return Uri.file(path, windows: Platform.isWindows);
  }

  bool _isSameQueueSnapshot(List<MusicTrack> snapshot) {
    if (queue.length != snapshot.length) return false;
    for (var i = 0; i < snapshot.length; i++) {
      if (queue[i].id != snapshot[i].id) return false;
    }
    return true;
  }

  Future<void> setQueue(List<MusicTrack> tracks, {int initialIndex = 0}) async {
    DebugTrace.instance.log(
        'QUEUE', 'setQueue tracks=${tracks.length} initialIndex=$initialIndex');
    final snapshot = List<MusicTrack>.unmodifiable(tracks);
    queue.assignAll(snapshot);

    if (snapshot.isEmpty) {
      currentIndex.value = -1;
      player.emitCurrentIndex(null);
      await _stopSilently();
      return;
    }

    final safeIndex = initialIndex.clamp(0, snapshot.length - 1).toInt();
    await playTrack(snapshot[safeIndex], index: safeIndex);
  }

  Future<void> playFromQueueSnapshot(
    List<MusicTrack> tracks, {
    required int initialIndex,
  }) async {
    DebugTrace.instance.log('CLICK_TO_PLAY',
        'snapshot=${tracks.length} requestedIndex=$initialIndex');
    if (tracks.isEmpty) return;
    final snapshot = List<MusicTrack>.unmodifiable(tracks);
    final safeIndex = initialIndex.clamp(0, snapshot.length - 1).toInt();

    if (!_isSameQueueSnapshot(snapshot)) {
      queue.assignAll(snapshot);
    }

    DebugTrace.instance.log(
      'CLICK_TO_PLAY',
      'safeIndex=$safeIndex track=${DebugTrace.instance.track(snapshot[safeIndex])} queueSame=${_isSameQueueSnapshot(snapshot)}',
    );
    await playTrack(snapshot[safeIndex], index: safeIndex);
  }

  Future<void> _enqueueLatestPlayRequest(
    int token,
    Future<void> Function() action,
  ) async {
    DebugTrace.instance
        .log('PLAY_CHAIN', 'enqueue token=$token latest=$_playRequestToken');
    final previous = _playSwitchChain.catchError((_) {});
    final next = previous.then((_) async {
      DebugTrace.instance
          .log('PLAY_CHAIN', 'begin token=$token latest=$_playRequestToken');
      if (token != _playRequestToken) {
        DebugTrace.instance.log(
            'PLAY_CHAIN', 'skip stale token=$token latest=$_playRequestToken');
        return;
      }
      await action();
      DebugTrace.instance
          .log('PLAY_CHAIN', 'end token=$token latest=$_playRequestToken');
    });

    _playSwitchChain = next.catchError((e) {
      debugPrint('播放切换队列错误: $e');
    });

    await next;
  }

  Future<void> playTrack(MusicTrack track, {int? index}) async {
    final playIndex = index ?? queue.indexWhere((item) => item.id == track.id);
    DebugTrace.instance.log(
      'PLAY_TRACK',
      'request index=$playIndex queue=${queue.length} track=${DebugTrace.instance.track(track)}',
    );

    if (queue.isEmpty || playIndex < 0 || playIndex >= queue.length) {
      queue.assignAll([track]);
      currentIndex.value = 0;
    } else {
      currentIndex.value = playIndex;
    }
    player.emitCurrentIndex(currentIndex.value);

    displayPosition.value = Duration.zero;
    displayDuration.value = track.duration;

    await _switchToCurrentTrack(autoPlay: true);
  }

  void _handlePlaybackError(Object error) {
    final now = DateTime.now();

    // 防止同一个失效链接连续弹很多次。
    if (_lastPlaybackErrorAt != null &&
        now.difference(_lastPlaybackErrorAt!) < const Duration(seconds: 2)) {
      return;
    }

    _lastPlaybackErrorAt = now;

    final track = currentTrack;
    final title = track?.title ?? '当前歌曲';
    final rawMessage = error.toString().replaceFirst('Exception: ', '');

    lastError.value = rawMessage;
    _loadedTrackId = null;
    _holdPlayingDuringSwitch = false;
    isPlayingNow.value = false;
    player.markPlaybackFailed();

    DebugTrace.instance.log(
      'PLAY_ERROR',
      'track=${DebugTrace.instance.track(track)} error=$rawMessage',
    );

    Get.snackbar(
      'player.playFailed'.tr,
      'player.playFailedMessage'.trParams({'title': title}),
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    );
  }

  Future<void> _switchToCurrentTrack({required bool autoPlay}) async {
    final index = currentIndex.value;
    if (index < 0 || index >= queue.length) return;

    final token = ++_playRequestToken;
    cancelSeekPreview();

    final track = queue[index];
    final initialPosition = _pendingRestoreTrackId == track.id
        ? _consumePendingRestorePosition()
        : Duration.zero;

    displayPosition.value = initialPosition;
    displayDuration.value = track.duration ?? player.duration;

    final holdPlayingForSwitch = autoPlay && isPlayingNow.value;
    if (holdPlayingForSwitch) {
      _holdPlayingDuringSwitch = true;
    }

    // 先静音旧链路，避免 media_kit 正在加载新歌时仍听到旧歌，造成“串一下”。
    // UI 会保持暂停图标，避免切歌时播放键闪烁。
    try {
      await player.pause();
    } catch (_) {}

    // 快速连续点歌时，不要每次点击都立刻 open 原生音源。
    // 稍等一个很短的窗口，只让最后一次点击进入 media_kit，减少“卡住等一会”的感觉。
    final switchSettleDelay =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS
            ? const Duration(milliseconds: 90)
            : const Duration(milliseconds: 45);
    await Future<void>.delayed(switchSettleDelay);
    if (token != _playRequestToken) {
      DebugTrace.instance.log('PLAY_CHAIN',
          'drop before enqueue stale token=$token latest=$_playRequestToken');
      return;
    }

    await _enqueueLatestPlayRequest(token, () async {
      if (token != _playRequestToken) return;
      final current = currentTrack;
      if (current == null) return;

      DebugTrace.instance.log(
        'LOAD_MEDIA_KIT',
        'start token=$token index=${currentIndex.value} track=${DebugTrace.instance.track(current)} loaded=$_loadedTrackId state=${player.processingState}',
      );

      try {
        lastError.value = '';

        if (_loadedTrackId == current.id &&
            player.processingState != ProcessingState.idle) {
          if (initialPosition > Duration.zero) {
            await player.seek(initialPosition);
          }
        } else {
          final uri = _playbackUriFor(current);
          final sw = Stopwatch()..start();
          DebugTrace.instance.log('LOAD_MEDIA_KIT',
              'native open start token=$token uri=$uri position=$initialPosition');
          await player.openUri(uri,
              initialPosition: initialPosition, play: false);
          sw.stop();
          _loadedTrackId = current.id;
          displayDuration.value = player.duration ?? current.duration;
          displayPosition.value = initialPosition;
          DebugTrace.instance.log(
            'LOAD_MEDIA_KIT',
            'native open done token=$token cost=${sw.elapsedMilliseconds}ms duration=${player.duration} state=${player.processingState}',
          );
        }

        if (token != _playRequestToken) {
          DebugTrace.instance.log('LOAD_MEDIA_KIT',
              'loaded but stale token=$token latest=$_playRequestToken');
          return;
        }

        unawaited(_persistPlaybackStateNow());

        if (autoPlay) {
          await player.play();
          if (token == _playRequestToken) {
            _holdPlayingDuringSwitch = false;
            isPlayingNow.value = true;
          }
          DebugTrace.instance.log('PLAY_CALL',
              'media_kit play done token=$token playing=${player.playing}');
        } else if (token == _playRequestToken) {
          _holdPlayingDuringSwitch = false;
        }
      } catch (e) {
        if (token != _playRequestToken) return;

        DebugTrace.instance.log(
          'LOAD_MEDIA_KIT',
          'error token=$token error=$e',
        );

        _handlePlaybackError(e);
      }
    });
  }

  Duration _consumePendingRestorePosition() {
    final position = _pendingRestorePosition;
    _pendingRestorePosition = Duration.zero;
    _pendingRestoreTrackId = null;
    return position;
  }

  Future<void> _stopSilently() async {
    _loadedTrackId = null;
    displayPosition.value = Duration.zero;
    displayDuration.value = currentTrack?.duration;
    try {
      await player.stop();
    } catch (_) {}
  }

  Future<void> togglePlay() async {
    final track = currentTrack;
    DebugTrace.instance.log(
      'TOGGLE',
      'start playing=${player.playing} index=${currentIndex.value} loaded=$_loadedTrackId track=${DebugTrace.instance.track(track)} state=${player.processingState}',
    );
    if (track == null) return;

    if (player.playing) {
      _holdPlayingDuringSwitch = false;
      await player.pause();
      isPlayingNow.value = false;
      unawaited(_persistPlaybackStateNow());
      return;
    }

    if (_loadedTrackId != track.id ||
        player.processingState == ProcessingState.idle) {
      await _switchToCurrentTrack(autoPlay: true);
      return;
    }

    await player.play();
    unawaited(_persistPlaybackStateNow());
  }

  Future<void> next() async {
    DebugTrace.instance.log('NEXT',
        'manual start index=${currentIndex.value} queue=${queue.length} mode=${playMode.value}');
    if (queue.isEmpty) return;

    // 手动点“下一首”时始终按照当前播放队列顺序走。
    // 随机 / 单曲循环只影响歌曲自然播放完成后的自动下一首，避免按钮顺序和首页列表不一致。
    final current = currentIndex.value.clamp(0, queue.length - 1).toInt();
    final nextIndex = current >= queue.length - 1 ? 0 : current + 1;
    await playTrack(queue[nextIndex], index: nextIndex);
  }

  Future<void> previous() async {
    DebugTrace.instance.log('PREV',
        'start index=${currentIndex.value} queue=${queue.length} position=${player.position}');
    if (queue.isEmpty) return;

    final current = currentIndex.value.clamp(0, queue.length - 1).toInt();

    if (current <= 0 || player.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
      await player.play();
      unawaited(_persistPlaybackStateNow());
      return;
    }

    final previousIndex = current - 1;
    await playTrack(queue[previousIndex], index: previousIndex);
  }

  Future<void> cyclePlayMode() async {
    switch (playMode.value) {
      case PlayMode.sequence:
        await setPlayMode(PlayMode.shuffle);
        break;
      case PlayMode.shuffle:
        await setPlayMode(PlayMode.repeatAll);
        break;
      case PlayMode.repeatAll:
        await setPlayMode(PlayMode.repeatOne);
        break;
      case PlayMode.repeatOne:
        await setPlayMode(PlayMode.sequence);
        break;
    }

    Get.snackbar(
      'player.mode'.tr,
      playMode.value.label,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(milliseconds: 1200),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    );
  }

  Future<void> setPlayMode(PlayMode mode, {bool persist = true}) async {
    playMode.value = mode;
    if (persist) {
      unawaited(_savePlayMode());
    }
  }

  Future<void> _handleCompleted() async {
    if (_handlingCompleted) return;
    if (queue.isEmpty || currentTrack == null) return;

    _handlingCompleted = true;

    try {
      if (playMode.value == PlayMode.repeatOne) {
        await player.seek(Duration.zero);
        unawaited(player.play());
        return;
      }

      await _playNext(auto: true);
    } finally {
      _handlingCompleted = false;
    }
  }

  Future<void> _playNext({required bool auto}) async {
    if (queue.isEmpty) return;

    if (playMode.value == PlayMode.shuffle) {
      final nextIndex = _nextShuffleIndex();
      await playTrack(queue[nextIndex], index: nextIndex);
      return;
    }

    final index = currentIndex.value;
    final isLast = index >= queue.length - 1;

    if (auto && isLast && playMode.value == PlayMode.sequence) {
      await player.stop();
      displayPosition.value = Duration.zero;
      displayDuration.value = currentTrack?.duration;
      unawaited(_persistPlaybackStateNow());
      return;
    }

    final nextIndex = isLast ? 0 : index + 1;
    await playTrack(queue[nextIndex], index: nextIndex);
  }

  int _nextShuffleIndex() {
    if (queue.length <= 1) return 0;

    var nextIndex = currentIndex.value;

    while (nextIndex == currentIndex.value) {
      nextIndex = _random.nextInt(queue.length);
    }

    return nextIndex;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);

    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    _persistTimer?.cancel();
    _volumeApplyTimer?.cancel();
    _volumeSaveTimer?.cancel();

    _mediaErrorSub?.cancel();
    _mediaErrorSub = null;

    unawaited(_persistPlaybackStateNow());

    if (kDebugMode && Platform.isWindows) {
      // media_kit 在 Windows debug hot restart 时可能触发
      // “Callback invoked after it has been deleted”。
      // 开发期避免主动销毁原生播放器，正常退出进程时系统会回收资源。
      unawaited(player.pause().catchError((_) {}));
    } else {
      unawaited(player.dispose().catchError((_) {}));
    }

    super.onClose();
  }
}
