enum MusicSourceType { localFile, webDav, emby, jellyfin, navidrome, directUrl }

class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.uri,
    required this.sourceType,
    this.artist,
    this.album,
    this.coverUri,
    this.lyricText,
    this.duration,
  });

  final String id;
  final String title;
  final String uri;
  final MusicSourceType sourceType;
  final String? artist;
  final String? album;
  final String? coverUri;
  final String? lyricText;
  final Duration? duration;

  bool get hasLyrics => lyricText != null && lyricText!.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'uri': uri,
      'sourceType': sourceType.name,
      'artist': artist,
      'album': album,
      'coverUri': coverUri,
      'lyricText': lyricText,
      'durationMs': duration?.inMilliseconds,
    };
  }

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    final sourceName = json['sourceType']?.toString();
    final sourceType = MusicSourceType.values.firstWhere(
      (e) => e.name == sourceName,
      orElse: () => MusicSourceType.localFile,
    );

    final durationMs = int.tryParse(json['durationMs']?.toString() ?? '');

    return MusicTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '未知歌曲',
      uri: json['uri']?.toString() ?? '',
      sourceType: sourceType,
      artist: json['artist']?.toString(),
      album: json['album']?.toString(),
      coverUri: json['coverUri']?.toString(),
      lyricText: json['lyricText']?.toString(),
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
    );
  }
}
