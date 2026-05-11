import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/music_track.dart';
import 'cover_uri_resolver.dart';
import 'player/media_kit_player.dart';
import 'player_controller.dart';

/// 把现有播放器状态同步给系统媒体中心。
///
/// 真正播放仍然由 [PlayerController] + media_kit 负责；这里仅负责：
/// 1. 安卓通知栏 / 锁屏媒体卡片；
/// 2. 耳机、蓝牙、系统媒体按键回调；
/// 3. 当前歌曲、队列和播放状态广播。
class SystemMediaService {
  SystemMediaService._();

  static final SystemMediaService instance = SystemMediaService._();

  FreshMusicAudioHandler? _handler;
  bool _initialized = false;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  Future<void> init(PlayerController controller) async {
    if (_initialized || !_isSupportedPlatform) return;

    final handler = await AudioService.init(
      builder: () => FreshMusicAudioHandler(controller),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.chatlee.aimusic.audio',
        androidNotificationChannelName: '音乐播放',
        // Android 12+ 在后台重新拉起前台服务限制更严格。
        // 媒体播放场景暂停后仍保留服务，恢复播放时会更稳定。
        androidStopForegroundOnPause: false,
      ),
    );
    _handler = handler as FreshMusicAudioHandler;
    _initialized = true;
  }

  FreshMusicAudioHandler? get handler => _handler;
}

class FreshMusicAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  FreshMusicAudioHandler(this._controller) {
    _queueWorker = ever(_controller.queue, (_) {
      _broadcastQueue();
      _broadcastCurrentItem();
      _broadcastPlaybackState();
    });
    _indexWorker = ever(_controller.currentIndex, (_) {
      _broadcastCurrentItem();
      _broadcastPlaybackState();
    });
    _playingWorker = ever(_controller.isPlayingNow, (_) {
      _broadcastPlaybackState();
    });
    _durationWorker = ever(_controller.displayDuration, (_) {
      _broadcastCurrentItem();
      _broadcastPlaybackState();
    });
    _positionWorker = interval(
      _controller.displayPosition,
      (_) => _broadcastPlaybackState(),
      time: const Duration(seconds: 2),
    );
    _processingSub = _controller.player.processingStateStream.listen((_) {
      _broadcastPlaybackState();
    });

    _broadcastQueue();
    _broadcastCurrentItem();
    _broadcastPlaybackState();
  }

  final PlayerController _controller;

  late final Worker _queueWorker;
  late final Worker _indexWorker;
  late final Worker _playingWorker;
  late final Worker _durationWorker;
  late final Worker _positionWorker;
  StreamSubscription<ProcessingState>? _processingSub;

  MediaItem _toMediaItem(MusicTrack track) {
    final rawCover = resolveTrackCoverUri(track)?.trim();
    final artUri =
        rawCover == null || rawCover.isEmpty ? null : Uri.tryParse(rawCover);

    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: _controller.currentTrack?.id == track.id
          ? (_controller.displayDuration.value ?? track.duration)
          : track.duration,
      artUri: artUri,
      extras: {
        'uri': track.uri,
        'sourceType': track.sourceType.name,
      },
    );
  }

  void _broadcastQueue() {
    queue.add(_controller.queue.map(_toMediaItem).toList(growable: false));
  }

  void _broadcastCurrentItem() {
    final track = _controller.currentTrack;
    if (track == null) {
      mediaItem.add(null);
      return;
    }
    mediaItem.add(_toMediaItem(track));
  }

  AudioProcessingState _audioProcessingState() {
    switch (_controller.player.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  void _broadcastPlaybackState() {
    final index = _controller.currentIndex.value;
    final safeIndex = index < 0 ? null : index;
    final playing = _controller.isPlayingNow.value;

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: _audioProcessingState(),
        playing: playing,
        updatePosition: _controller.displayPosition.value,
        bufferedPosition: _controller.displayPosition.value,
        speed: 1.0,
        queueIndex: safeIndex,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (_controller.currentTrack == null) return;
    if (!_controller.isPlayingNow.value) {
      await _controller.togglePlay();
    }
    _broadcastPlaybackState();
  }

  @override
  Future<void> pause() async {
    if (_controller.isPlayingNow.value) {
      await _controller.togglePlay();
    }
    _broadcastPlaybackState();
  }

  @override
  Future<void> stop() async {
    await _controller.stopPlayback();
    await super.stop();
    _broadcastPlaybackState();
  }

  @override
  Future<void> seek(Duration position) async {
    await _controller.commitSeek(position);
    _broadcastPlaybackState();
  }

  @override
  Future<void> skipToNext() async {
    await _controller.next();
    _broadcastPlaybackState();
  }

  @override
  Future<void> skipToPrevious() async {
    await _controller.previous();
    _broadcastPlaybackState();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _controller.queue.length) return;
    await _controller.playTrack(_controller.queue[index], index: index);
    _broadcastPlaybackState();
  }

  Future<void> disposeHandler() async {
    _queueWorker.dispose();
    _indexWorker.dispose();
    _playingWorker.dispose();
    _durationWorker.dispose();
    _positionWorker.dispose();
    await _processingSub?.cancel();
    _processingSub = null;
  }
}
