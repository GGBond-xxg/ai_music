import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PlaybackNotificationService {
  static const MethodChannel _channel = MethodChannel('music_playback_notification');
  static String? _lastSignature;
  static bool _permissionAsked = false;

  static Future<void> update({
    required String title,
    required String artist,
    required String source,
    required bool isPlaying,
    String? coverUrl,
    int positionMs = 0,
    int durationMs = 0,
  }) async {
    if (kIsWeb) return;

    final safeDurationMs = durationMs < 0 ? 0 : durationMs;
    final safePositionMs = _normalisePosition(positionMs, safeDurationMs);

    // 进度按秒去重：系统 MediaSession 会根据 position + speed 自己向前走，
    // 这里不需要每一帧都刷新通知，否则 Android 端会频繁 decode 封面。
    final coarsePositionSecond = safePositionMs ~/ 1000;
    final signature = [
      title,
      artist,
      source,
      isPlaying,
      coverUrl ?? '',
      safeDurationMs,
      coarsePositionSecond,
    ].join('|');
    if (_lastSignature == signature) return;
    _lastSignature = signature;

    try {
      if (Platform.isAndroid && !_permissionAsked) {
        _permissionAsked = true;
        await Permission.notification.request();
      }

      final nativeCover = await _coverForNativeNotification(coverUrl);

      await _channel.invokeMethod<void>('update', {
        'title': title,
        'artist': artist,
        'source': source,
        'isPlaying': isPlaying,
        'coverUrl': nativeCover,
        'positionMs': safePositionMs,
        'durationMs': safeDurationMs,
      });
    } catch (_) {
      // Notification support should never block playback.
    }
  }

  static Future<void> cancel() async {
    if (kIsWeb) return;
    _lastSignature = null;
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }

  static int _normalisePosition(int positionMs, int durationMs) {
    final positivePosition = positionMs < 0 ? 0 : positionMs;
    if (durationMs <= 0) return positivePosition;
    return positivePosition > durationMs ? durationMs : positivePosition;
  }

  static Future<String?> _coverForNativeNotification(String? coverUrl) async {
    final value = coverUrl?.trim();
    if (value == null || value.isEmpty) return null;

    if (value.startsWith('file://')) {
      try {
        final path = Uri.parse(value).toFilePath();
        return await File(path).exists() ? path : null;
      } catch (_) {
        return null;
      }
    }

    if (value.startsWith('/')) {
      return await File(value).exists() ? value : null;
    }

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return null;
    }

    try {
      final dir = Directory(
        '${(await getTemporaryDirectory()).path}/music_notification_covers',
      );
      if (!await dir.exists()) await dir.create(recursive: true);

      final uri = Uri.parse(value);
      final ext = _guessCoverExtension(uri.path);
      final key = sha1.convert(utf8.encode(value)).toString();
      final file = File('${dir.path}/$key$ext');
      if (await file.exists() && await file.length() > 0) return file.path;

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        final bytes = await consolidateHttpClientResponseBytes(response);
        if (bytes.isEmpty) return null;
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null;
    }
  }

  static String _guessCoverExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    return '.jpg';
  }
}
