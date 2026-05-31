import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/spotify_provider.dart';
import '../services/ui_texts.dart';

class LibraryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool isLoadingMore;
  final void Function(Map<String, dynamic>)? onItemTap;
  final void Function(Map<String, dynamic>)? onItemLongPress;
  final int gridCrossAxisCount;

  const LibraryGrid({
    super.key,
    required this.items,
    this.isLoadingMore = false,
    this.onItemTap,
    this.onItemLongPress,
    required this.gridCrossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && !isLoadingMore) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(UiTexts.of(context).noMusicFound),
          ),
        ),
      );
    }

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          return _LibraryGridItem(
            key: ValueKey(item['id'] ?? item['uri'] ?? index),
            item: item,
            onTap: onItemTap != null
                ? () => onItemTap!(item)
                : () => _playItem(context, item),
            onLongPress: onItemLongPress != null
                ? () => onItemLongPress!(item)
                : () => _playItem(context, item),
          );
        },
        childCount: items.length,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridCrossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
    );
  }

  void _playItem(BuildContext context, Map<String, dynamic> item) {
    Provider.of<SpotifyProvider>(context, listen: false).playItem(item);
  }
}

class LibraryList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic>)? onItemTap;

  const LibraryList({
    super.key,
    required this.items,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(UiTexts.of(context).noMusicFound),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, rawIndex) {
          if (rawIndex.isOdd) {
            return Divider(
              height: 1,
              indent: 72,
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.4),
            );
          }

          final item = items[rawIndex ~/ 2];
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: _Artwork(item: item, cacheSize: 112),
              ),
            ),
            title: Text(
              item['name']?.toString() ?? 'Unknown Track',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            subtitle: Text(
              _artistName(context, item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: SizedBox(
              width: 96,
              child: Text(
                _sourceLabel(context, item),
                maxLines: 1,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              if (onItemTap != null) {
                onItemTap!(item);
              } else {
                _playItem(context, item);
              }
            },
          );
        },
        childCount: items.isEmpty ? 0 : items.length * 2 - 1,
      ),
    );
  }

  void _playItem(BuildContext context, Map<String, dynamic> item) {
    Provider.of<SpotifyProvider>(context, listen: false).playItem(item);
  }

  String _sourceLabel(BuildContext context, Map<String, dynamic> item) {
    return UiTexts.of(context).sourceNameFromString(
      item['sourceType']?.toString(),
      fallback: item['sourceLabel']?.toString() ?? item['type']?.toString(),
    );
  }

  String _artistName(BuildContext context, Map<String, dynamic> item) {
    final artists = item['artists'];
    if (artists is List && artists.isNotEmpty) {
      final first = artists.first;
      if (first is Map && first['name'] != null) {
        final value = first['name'].toString().trim();
        if (value.isNotEmpty) return value;
      }
    }
    return _sourceLabel(context, item);
  }
}

class _LibraryGridItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LibraryGridItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
                    final cacheSize = constraints.maxWidth > 0
                        ? (constraints.maxWidth * pixelRatio).round()
                        : null;
                    return _Artwork(item: item, cacheSize: cacheSize);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item['name']?.toString() ?? 'Unknown Track',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          Text(
            _getItemSubtitle(context, item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  String _getItemSubtitle(BuildContext context, Map<String, dynamic> item) {
    final artists = item['artists'];
    final artistName = artists is List && artists.isNotEmpty
        ? ((artists.first as Map?)?['name']?.toString() ?? '')
        : '';
    final source = UiTexts.of(context).sourceNameFromString(
      item['sourceType']?.toString(),
      fallback: item['sourceLabel']?.toString() ?? item['type']?.toString(),
    );
    if (artistName.isEmpty) return source;
    return '$artistName • $source';
  }
}

class _Artwork extends StatelessWidget {
  final Map<String, dynamic> item;
  final int? cacheSize;

  const _Artwork({required this.item, required this.cacheSize});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = _imageUrl(item);
    if (url == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.secondaryContainer,
            ],
          ),
        ),
        child: Icon(
          Icons.music_note_rounded,
          size: 42,
          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
        ),
      );
    }

    if (url.startsWith('file://') || url.startsWith('/')) {
      try {
        final file = url.startsWith('file://')
            ? File(Uri.parse(url).toFilePath())
            : File(url);
        return Image.file(
          file,
          key: ValueKey(url),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, _, __) => _fallbackArtwork(context),
        );
      } catch (_) {
        return _fallbackArtwork(context);
      }
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      memCacheWidth: cacheSize,
      memCacheHeight: cacheSize,
      fit: BoxFit.cover,
      placeholder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
        ),
      ),
      errorWidget: (context, _, __) => _fallbackArtwork(context),
    );
  }

  Widget _fallbackArtwork(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.music_note_rounded,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  String? _imageUrl(Map<String, dynamic> item) {
    final images = item['images'];
    if (images is! List || images.isEmpty) return null;
    final first = images.first;
    if (first is! Map) return null;
    final url = first['url']?.toString();
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('file://') ||
        url.startsWith('/')) {
      return url;
    }
    return null;
  }
}

class LibraryGridSkeleton extends StatelessWidget {
  final int itemCount;
  final int gridCrossAxisCount;

  const LibraryGridSkeleton({
    super.key,
    this.itemCount = 12,
    required this.gridCrossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildSkeletonItem(context),
        childCount: itemCount,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridCrossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
    );
  }

  Widget _buildSkeletonItem(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 14,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 100,
          height: 12,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
