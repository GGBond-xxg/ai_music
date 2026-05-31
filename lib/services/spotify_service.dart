/// 原来的在线账号 API 已从这个构建中移除。
///
/// This file remains as a compatibility shim because several preserved
/// Music UI/helper classes still reference [SpotifyAuthException] or
/// [SpotifyAuthService] types. Every method returns an empty/no-op value;
/// actual playback and library data now live in `SpotifyProvider` and the
/// ai_music source services.
class SpotifyAuthException implements Exception {
  SpotifyAuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => code == null ? message : '$message ($code)';
}

class SpotifyAuthService {
  const SpotifyAuthService();

  Future<List<Map<String, dynamic>>> getAllUserSavedTracks({
    void Function(int loaded, int? total)? onProgress,
  }) async {
    onProgress?.call(0, 0);
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> getUserSavedTracks({
    int offset = 0,
    int limit = 50,
  }) async {
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> getAvailableDevices() async {
    return <Map<String, dynamic>>[
      {
        'id': 'local-device',
        'name': '本机播放器',
        'type': 'Smartphone',
        'is_active': true,
        'is_private_session': false,
        'is_restricted': false,
        'volume_percent': 100,
        'supports_volume': true,
      },
    ];
  }

  Future<void> transferPlayback(String deviceId, {bool play = false}) async {}

  Future<void> setVolume(int volumePercent, {String? deviceId}) async {}

  Future<Map<String, dynamic>> getPlaybackQueue() async {
    return {'queue': <Map<String, dynamic>>[]};
  }

  Future<void> togglePlayPause() async {}

  Future<void> seekToPosition(Duration position) async {}

  Future<void> skipToNext() async {}

  Future<void> skipToPrevious() async {}

  Future<void> toggleTrackSave(String trackId) async {}

  Future<bool> isTrackSaved(String trackId) async => false;

  Future<Map<String, dynamic>> getPlaybackState() async {
    return {
      'repeat_state': 'context',
      'shuffle_state': false,
      'is_playing': false,
    };
  }

  Future<void> setRepeatMode(String mode) async {}

  Future<void> setShuffle(bool enabled) async {}
}
