import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/music_track.dart';
import '../services/cover_uri_resolver.dart';

class TrackCover extends StatelessWidget {
  const TrackCover({
    super.key,
    required this.track,
    this.size = 52,
    this.borderRadius = 16,
    this.iconSize,
    this.enableNetwork = true,
    this.deferUncached = false,
    this.forcePlaceholder = false,
  });

  final MusicTrack track;
  final double size;
  final double borderRadius;
  final double? iconSize;
  final bool enableNetwork;
  final bool forcePlaceholder;

  /// 滚动中是否延后加载未显示过的封面。
  ///
  /// 已经成功显示过的封面会继续显示；没显示过的封面先用占位图，
  /// 等滚动停止后再加载，避免列表边滚动边解码图片造成掉帧。
  final bool deferUncached;

  static final Set<String> _paintedCoverUris = <String>{};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverUri = resolveTrackCoverUri(track)?.trim();
    // Flutter 会把 cacheWidth/cacheHeight 下发到底层解码器。
    // Android 上这可以避免把 1000px+ 的封面完整解码到内存，再缩成 52px。
    // 大封面仍保留足够清晰度，小封面显著减少 GPU/raster 压力。
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (size * ratio)
        .round()
        .clamp(size >= 180 ? 384 : 96, size >= 180 ? 560 : 320)
        .toInt();

    if (forcePlaceholder) {
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: size,
            height: size,
            child: _FallbackCover(
              title: track.title,
              size: size,
              iconSize: iconSize,
            ),
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(color: scheme.primaryContainer),
            child: _buildCover(context, coverUri, cacheSize),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context, String? coverUri, int cacheSize) {
    if (coverUri == null || coverUri.isEmpty) {
      return _FallbackCover(title: track.title, size: size, iconSize: iconSize);
    }

    final uri = Uri.tryParse(coverUri);
    if (uri == null) {
      return _FallbackCover(title: track.title, size: size, iconSize: iconSize);
    }

    final hasPaintedBefore = _paintedCoverUris.contains(coverUri);
    if (deferUncached && !hasPaintedBefore) {
      return _FallbackCover(title: track.title, size: size, iconSize: iconSize);
    }

    if (uri.scheme == 'file') {
      return Image.file(
        File.fromUri(uri),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        gaplessPlayback: true,
        filterQuality: FilterQuality.none,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            _paintedCoverUris.add(coverUri);
          }
          return child;
        },
        errorBuilder: (_, __, ___) => _FallbackCover(
          title: track.title,
          size: size,
          iconSize: iconSize,
        ),
      );
    }

    if (!enableNetwork && !hasPaintedBefore) {
      return _FallbackCover(title: track.title, size: size, iconSize: iconSize);
    }

    return _NetworkTrackCover(
      imageUrl: coverUri,
      title: track.title,
      size: size,
      iconSize: iconSize,
      cacheSize: cacheSize,
      onImageReady: () => _paintedCoverUris.add(coverUri),
    );
  }
}

class _NetworkTrackCover extends StatelessWidget {
  const _NetworkTrackCover({
    required this.imageUrl,
    required this.title,
    required this.size,
    required this.cacheSize,
    required this.onImageReady,
    this.iconSize,
  });

  final String imageUrl;
  final String title;
  final double size;
  final int cacheSize;
  final double? iconSize;
  final VoidCallback onImageReady;

  Widget _fallback() => _FallbackCover(
        title: title,
        size: size,
        iconSize: iconSize,
      );

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      imageBuilder: (_, provider) {
        onImageReady();
        return Image(
          image: provider,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.none,
        );
      },
      memCacheWidth: cacheSize,
      memCacheHeight: cacheSize,
      maxWidthDiskCache: cacheSize,
      maxHeightDiskCache: cacheSize,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      placeholder: (_, __) => _fallback(),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover({
    required this.title,
    required this.size,
    this.iconSize,
  });

  final String title;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: iconSize ?? (size >= 96 ? size * 0.46 : size * 0.42),
        color: scheme.onSecondaryContainer,
      ),
    );
  }
}
