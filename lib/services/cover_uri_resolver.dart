import '../models/music_track.dart';

String? resolveTrackCoverUri(MusicTrack track) {
  final raw = track.coverUri?.trim();
  if (raw != null && raw.isNotEmpty) return raw;

  if (track.sourceType != MusicSourceType.emby &&
      track.sourceType != MusicSourceType.jellyfin &&
      track.sourceType != MusicSourceType.navidrome) {
    return null;
  }

  if (track.sourceType == MusicSourceType.navidrome) return raw;

  final audioUri = Uri.tryParse(track.uri);
  if (audioUri == null || !audioUri.hasScheme || audioUri.host.isEmpty) {
    return null;
  }

  final segments = audioUri.pathSegments;
  final audioIndex = segments.indexWhere((e) => e.toLowerCase() == 'audio');
  final itemId = audioIndex >= 0 && audioIndex + 1 < segments.length
      ? segments[audioIndex + 1]
      : track.id;
  if (itemId.trim().isEmpty) return null;

  final prefix = audioIndex > 0 ? segments.sublist(0, audioIndex) : <String>[];
  final apiKey = audioUri.queryParameters['api_key'];

  return audioUri
      .replace(
        pathSegments: [
          ...prefix,
          'Items',
          itemId,
          'Images',
          'Primary',
        ],
        queryParameters: {
          if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
        },
      )
      .toString();
}
