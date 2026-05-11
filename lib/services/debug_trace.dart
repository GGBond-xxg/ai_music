import '../models/music_track.dart';

class DebugTrace {
  DebugTrace._();

  static final DebugTrace instance = DebugTrace._();

  Future<void> init() async {}

  void log(String tag, String message) {}

  String track(MusicTrack? track) {
    if (track == null) return 'null';
    return 'id=${track.id} title="${track.title}" uri="${track.uri}"';
  }
}
