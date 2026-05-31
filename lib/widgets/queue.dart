import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/spotify_provider.dart';
import '../services/ui_texts.dart';

class QueueDisplay extends StatelessWidget {
  const QueueDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final currentQueue =
        context.select<SpotifyProvider, List<Map<String, dynamic>>>(
      (provider) => provider.upcomingTracks,
    );
    final provider = context.read<SpotifyProvider>();

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentQueue.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  UiTexts.of(context).emptyQueue,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Card(
              elevation: 0,
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: currentQueue.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final track = currentQueue[index];
                  return ListTile(
                    leading: _QueueArtwork(track: track),
                    title: Text(
                      track['name']?.toString() ?? 'Unknown Track',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _artistName(track),
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _formatDuration(track['duration_ms']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () => provider.playItem(track),
                    onLongPress: () => provider.playItem(track),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(dynamic milliseconds) {
    final value = milliseconds is int
        ? milliseconds
        : int.tryParse(milliseconds?.toString() ?? '') ?? 0;
    final duration = Duration(milliseconds: value);
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _artistName(Map<String, dynamic> track) {
    final artists = track['artists'];
    if (artists is List && artists.isNotEmpty && artists.first is Map) {
      return (artists.first as Map)['name']?.toString() ?? '';
    }
    return track['sourceLabel']?.toString() ?? '';
  }
}

class _QueueArtwork extends StatelessWidget {
  const _QueueArtwork({required this.track});

  final Map<String, dynamic> track;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = _imageUrl(track);
    return SizedBox(
      width: 40,
      height: 40,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url == null
            ? Container(
                color: colorScheme.primaryContainer,
                child: Icon(
                  Icons.music_note_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                memCacheWidth:
                    (40 * MediaQuery.of(context).devicePixelRatio).round(),
                memCacheHeight:
                    (40 * MediaQuery.of(context).devicePixelRatio).round(),
                fit: BoxFit.cover,
                errorWidget: (context, _, __) => Container(
                  color: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
      ),
    );
  }

  String? _imageUrl(Map<String, dynamic> track) {
    final album = track['album'];
    if (album is! Map) return null;
    final images = album['images'];
    if (images is! List || images.isEmpty || images.first is! Map) return null;
    final url = (images.first as Map)['url']?.toString();
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return null;
  }
}
