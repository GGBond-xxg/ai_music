import 'dart:async';

import 'package:media_kit/media_kit.dart' as mk;

enum ProcessingState { idle, loading, ready, completed }

class FreshMediaKitPlayer {
  FreshMediaKitPlayer() {
    _positionSub = _player.stream.position.listen((value) {
      position = value;
      if (!_positionController.isClosed) {
        _positionController.add(value);
      }
    });

    _durationSub = _player.stream.duration.listen((value) {
      duration = value == Duration.zero ? null : value;
      if (!_durationController.isClosed) {
        _durationController.add(duration);
      }
    });

    _playingSub = _player.stream.playing.listen((value) {
      playing = value;
      if (!_playingController.isClosed) {
        _playingController.add(value);
      }
    });

    _completedSub = _player.stream.completed.listen((value) {
      if (!value) return;
      _setProcessingState(ProcessingState.completed);
    });

    _errorSub = _player.stream.error.listen((value) {
      if (value.isEmpty) return;

      lastError = value;

      if (!_errorController.isClosed) {
        _errorController.add(value);
      }
    });
  }

  final mk.Player _player = mk.Player();

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _processingStateController =
      StreamController<ProcessingState>.broadcast();
  final _currentIndexController = StreamController<int?>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;

  Duration position = Duration.zero;
  Duration? duration;
  bool playing = false;
  ProcessingState processingState = ProcessingState.idle;
  String? lastError;

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<ProcessingState> get processingStateStream =>
      _processingStateController.stream;
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  /// media_kit 异步播放错误。
  ///
  /// 有些链接失效、NAS 离线、Emby/Jellyfin 临时地址过期，
  /// 不一定会在 openUri() 里直接 throw，而是从这里异步返回。
  Stream<String> get errorStream => _errorController.stream;

  void emitCurrentIndex(int? index) {
    if (!_currentIndexController.isClosed) {
      _currentIndexController.add(index);
    }
  }

  void _setProcessingState(ProcessingState state) {
    if (processingState == state) return;

    processingState = state;

    if (!_processingStateController.isClosed) {
      _processingStateController.add(state);
    }
  }

  Future<void> openUri(
    Uri uri, {
    Duration initialPosition = Duration.zero,
    bool play = false,
  }) async {
    lastError = null;
    _setProcessingState(ProcessingState.loading);

    await _player.open(
      mk.Media(uri.toString()),
      play: false,
    );

    duration =
        _player.state.duration == Duration.zero ? null : _player.state.duration;

    if (!_durationController.isClosed) {
      _durationController.add(duration);
    }

    if (initialPosition > Duration.zero) {
      await seek(initialPosition);
    }

    _setProcessingState(ProcessingState.ready);

    if (play) {
      await this.play();
    }
  }

  Future<void> play() async {
    await _player.play();
    playing = true;

    if (!_playingController.isClosed) {
      _playingController.add(true);
    }
  }

  Future<void> pause() async {
    await _player.pause();
    playing = false;

    if (!_playingController.isClosed) {
      _playingController.add(false);
    }
  }

  Future<void> stop() async {
    await _player.stop();

    position = Duration.zero;
    duration = null;
    playing = false;

    _setProcessingState(ProcessingState.idle);

    if (!_playingController.isClosed) {
      _playingController.add(false);
    }

    if (!_positionController.isClosed) {
      _positionController.add(Duration.zero);
    }

    if (!_durationController.isClosed) {
      _durationController.add(null);
    }
  }

  Future<void> seek(Duration position) async {
    this.position = position;

    if (!_positionController.isClosed) {
      _positionController.add(position);
    }

    await _player.seek(position);
  }

  Future<void> setVolume(double value) async {
    await _player.setVolume(value.clamp(0.0, 1.0).toDouble() * 100.0);
  }


  void markPlaybackFailed() {
    playing = false;
    _setProcessingState(ProcessingState.idle);

    if (!_playingController.isClosed) {
      _playingController.add(false);
    }

    if (!_processingStateController.isClosed) {
      _processingStateController.add(ProcessingState.idle);
    }
  }

  Future<void> dispose() async {
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _playingSub?.cancel();
    await _completedSub?.cancel();
    await _errorSub?.cancel();

    await _positionController.close();
    await _durationController.close();
    await _playingController.close();
    await _processingStateController.close();
    await _currentIndexController.close();
    await _errorController.close();

    await _player.dispose();
  }
}
