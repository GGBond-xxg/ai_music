import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_track.dart';
import 'cover_uri_resolver.dart';
import 'debug_trace.dart';

/// 封面主色缓存。
///
/// 作用：
/// 1. 启动时可以同步读取上次提取过的封面色，避免先显示默认色再跳到封面色。
/// 2. 切歌 / 打开 PC 歌词页时复用已提取的颜色，减少首帧卡顿。
class CoverPaletteCache {
  CoverPaletteCache._();

  static final CoverPaletteCache instance = CoverPaletteCache._();

  static const _prefPrefix = 'cover_palette.seed.v2.';

  SharedPreferences? _prefs;
  final Map<String, Color> _memory = <String, Color>{};
  final Map<String, Future<Color>> _pending = <String, Future<Color>>{};

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String keyForTrack(MusicTrack track, Brightness brightness) {
    final coverUri = resolveTrackCoverUri(track)?.trim() ?? '';
    return '${track.id}|$coverUri|${brightness.name}';
  }

  Color? cachedSeedForTrack(MusicTrack track, Brightness brightness) {
    return cachedSeedForKey(keyForTrack(track, brightness));
  }

  Color? cachedSeedForKey(String key) {
    final inMemory = _memory[key];
    if (inMemory != null) {
      DebugTrace.instance
          .log('PALETTE', 'memory hit key=$key color=${_hex(inMemory)}');
      return inMemory;
    }

    final raw = _prefs?.getInt('$_prefPrefix$key');
    if (raw == null) {
      DebugTrace.instance.log('PALETTE', 'miss key=$key');
      return null;
    }

    final color = Color(raw);
    _memory[key] = color;
    DebugTrace.instance
        .log('PALETTE', 'disk hit key=$key color=${_hex(color)}');
    return color;
  }

  Future<Color> resolveSeedForTrack(
    MusicTrack track,
    Brightness brightness, {
    required Color fallback,
    Size sampleSize = const Size(220, 220),
    int maximumColorCount = 18,
  }) {
    final key = keyForTrack(track, brightness);
    return resolveSeed(
      key: key,
      coverUri: resolveTrackCoverUri(track)?.trim() ?? '',
      fallback: fallback,
      sampleSize: sampleSize,
      maximumColorCount: maximumColorCount,
    );
  }

  Future<Color> resolveSeed({
    required String key,
    required String coverUri,
    required Color fallback,
    Size sampleSize = const Size(220, 220),
    int maximumColorCount = 18,
  }) {
    final cached = cachedSeedForKey(key);
    if (cached != null) return Future<Color>.value(cached);

    final pending = _pending[key];
    if (pending != null) {
      DebugTrace.instance.log('PALETTE', 'pending reuse key=$key');
      return pending;
    }

    final future = _extractSeed(
      key: key,
      coverUri: coverUri,
      fallback: fallback,
      sampleSize: sampleSize,
      maximumColorCount: maximumColorCount,
    );
    _pending[key] = future;
    return future.whenComplete(() => _pending.remove(key));
  }

  Future<Color> _extractSeed({
    required String key,
    required String coverUri,
    required Color fallback,
    required Size sampleSize,
    required int maximumColorCount,
  }) async {
    if (coverUri.isEmpty) {
      DebugTrace.instance
          .log('PALETTE', 'empty cover key=$key fallback=${_hex(fallback)}');
      await _save(key, fallback);
      return fallback;
    }

    try {
      final sw = Stopwatch()..start();
      DebugTrace.instance
          .log('PALETTE', 'extract start key=$key cover=$coverUri');
      final uri = Uri.tryParse(coverUri);
      if (uri == null) throw ArgumentError('invalid cover uri');

      final isNetworkCover = uri.scheme == 'http' || uri.scheme == 'https';

      final ImageProvider provider;
      if (uri.scheme == 'file') {
        provider = FileImage(File.fromUri(uri));
      } else if (isNetworkCover) {
        // Jellyfin / Emby / NAS / WebDAV 这类网络封面不能直接 NetworkImage 取色，
        // 否则服务器离线或链接失效时会卡住 UI。
        // 这里仅使用 CachedNetworkImage 已经写入本地的缓存文件。
        final cached = await DefaultCacheManager().getFileFromCache(coverUri);
        final cachedFile = cached?.file;
        if (cachedFile == null || !await cachedFile.exists()) {
          DebugTrace.instance.log(
            'PALETTE',
            'network cover cache miss key=$key cover=$coverUri fallback=${_hex(fallback)}',
          );
          // 不保存 fallback，避免之后封面缓存成功后仍然一直使用默认色。
          return fallback;
        }

        provider = FileImage(cachedFile);
      } else {
        provider = FileImage(File(coverUri));
      }

      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        size: sampleSize,
        maximumColorCount: maximumColorCount,
      );

      final seed = palette.vibrantColor?.color ??
          palette.darkVibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.mutedColor?.color ??
          fallback;

      sw.stop();
      DebugTrace.instance.log('PALETTE',
          'extract done key=$key color=${_hex(seed)} cost=${sw.elapsedMilliseconds}ms');
      await _save(key, seed);
      return seed;
    } catch (e) {
      DebugTrace.instance.log('PALETTE',
          'extract error key=$key fallback=${_hex(fallback)} error=$e');
      await _save(key, fallback);
      return fallback;
    }
  }

  Future<void> _save(String key, Color color) async {
    _memory[key] = color;
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await prefs.setInt('$_prefPrefix$key', color.toARGB32());
    } catch (_) {}
  }
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
