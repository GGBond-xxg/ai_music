import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MusicThemeMode {
  system,
  light,
  dark,
}

class ThemeProvider extends ChangeNotifier {
  ThemeProvider();

  static const String _themeModeKey = 'music_theme_mode';
  static const String _lastSeedColorKey = 'music_last_seed_color';
  static const String _imageColorCachePrefix = 'music_image_seed_color_';

  final Logger _logger = Logger();

  MusicThemeMode _themeMode = MusicThemeMode.system;
  Color? _seedColor;

  ColorScheme _colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6750A4),
    brightness: Brightness.light,
  );

  MusicThemeMode get themeMode => _themeMode;
  ColorScheme get colorScheme => _colorScheme;
  Color? get seedColor => _seedColor;

  Brightness resolveBrightness(BuildContext context) {
    return _resolveBrightness(MediaQuery.platformBrightnessOf(context));
  }

  Brightness _resolveBrightness(Brightness platformBrightness) {
    switch (_themeMode) {
      case MusicThemeMode.light:
        return Brightness.light;
      case MusicThemeMode.dark:
        return Brightness.dark;
      case MusicThemeMode.system:
        return platformBrightness;
    }
  }

  Future<void> loadThemeMode(BuildContext context) async {
    // 先读取系统亮度，避免 await 之后再使用 BuildContext。
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final prefs = await SharedPreferences.getInstance();

    final savedMode = prefs.getString(_themeModeKey);
    _themeMode = MusicThemeMode.values.firstWhere(
      (mode) => mode.name == savedMode,
      orElse: () => MusicThemeMode.system,
    );

    final savedSeedColor = prefs.getInt(_lastSeedColorKey);
    if (savedSeedColor != null) {
      _seedColor = Color(savedSeedColor);
    }

    _applyColorScheme(_resolveBrightness(platformBrightness));
    notifyListeners();
  }

  Future<void> setThemeMode(
    MusicThemeMode mode,
    BuildContext context,
  ) async {
    // 先读取系统亮度，避免 await 之后再使用 BuildContext。
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    _themeMode = mode;

    // 关键：先立即刷新 UI，避免设置页看起来“没反应”。
    _applyColorScheme(_resolveBrightness(platformBrightness));
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  /// 兼容旧测试和旧调用：系统亮度改变时，按当前模式重新应用主题。
  void updateThemeFromSystem(BuildContext context) {
    _applyColorScheme(resolveBrightness(context));
    notifyListeners();
  }

  Future<void> updateThemeFromImage({
    required ImageProvider imageProvider,
    required Brightness brightness,
    String? cacheKey,
  }) async {
    try {
      final normalizedCacheKey = _normalizeCacheKey(cacheKey);

      if (normalizedCacheKey != null) {
        final cachedColor = await _readCachedImageColor(normalizedCacheKey);
        if (cachedColor != null) {
          _seedColor = cachedColor;
          await _saveLastSeedColor(cachedColor);
          _applyColorScheme(brightness);
          notifyListeners();
          return;
        }
      }

      final color = await _extractSeedColor(imageProvider);
      if (color == null) return;

      _seedColor = color;
      await _saveLastSeedColor(color);

      if (normalizedCacheKey != null) {
        await _cacheImageColor(normalizedCacheKey, color);
      }

      _applyColorScheme(brightness);
      notifyListeners();

      _logger.d(
        '种子色: #${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      );
    } catch (e, stackTrace) {
      _logger.w(
        '封面取色失败',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void refreshForCurrentBrightness(BuildContext context) {
    _applyColorScheme(resolveBrightness(context));
    notifyListeners();
  }

  void _applyColorScheme(Brightness brightness) {
    final seed = _seedColor ?? const Color(0xFF6750A4);

    _colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
  }

  Future<Color?> _extractSeedColor(ImageProvider imageProvider) async {
    final completer = Completer<Color?>();

    late final ImageStreamListener listener;
    final stream = imageProvider.resolve(const ImageConfiguration());

    void complete(Color? color) {
      if (!completer.isCompleted) {
        completer.complete(color);
      }
    }

    listener = ImageStreamListener(
      (ImageInfo imageInfo, bool synchronousCall) async {
        try {
          final image = imageInfo.image;
          final pixels = await image.toByteData();

          if (pixels == null) {
            complete(null);
            return;
          }

          final pixelsList = <int>[];

          final width = image.width;
          final height = image.height;
          final stepX = (width / 64).ceil().clamp(1, width);
          final stepY = (height / 64).ceil().clamp(1, height);

          for (int y = 0; y < height; y += stepY) {
            for (int x = 0; x < width; x += stepX) {
              final byteOffset = (y * width + x) * 4;

              if (byteOffset + 3 >= pixels.lengthInBytes) continue;

              final r = pixels.getUint8(byteOffset);
              final g = pixels.getUint8(byteOffset + 1);
              final b = pixels.getUint8(byteOffset + 2);
              final a = pixels.getUint8(byteOffset + 3);

              if (a < 128) continue;

              final argb = (0xFF << 24) | (r << 16) | (g << 8) | b;
              pixelsList.add(argb);
            }
          }

          if (pixelsList.isEmpty) {
            complete(null);
            return;
          }

          final quantizerResult = await QuantizerCelebi().quantize(
            pixelsList,
            128,
          );
          final score = Score.score(quantizerResult.colorToCount);

          if (score.isEmpty) {
            complete(null);
            return;
          }

          complete(Color(score.first));
        } catch (_) {
          complete(null);
        } finally {
          stream.removeListener(listener);
        }
      },
      onError: (Object error, StackTrace? stackTrace) {
        complete(null);
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);

    return completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        stream.removeListener(listener);
        return null;
      },
    );
  }

  String? _normalizeCacheKey(String? value) {
    final key = value?.trim();
    if (key == null || key.isEmpty) return null;
    return key;
  }

  Future<Color?> _readCachedImageColor(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('$_imageColorCachePrefix$cacheKey');
    if (colorValue == null) return null;
    return Color(colorValue);
  }

  Future<void> _cacheImageColor(String cacheKey, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_imageColorCachePrefix$cacheKey', color.toARGB32());
  }

  Future<void> _saveLastSeedColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeedColorKey, color.toARGB32());
  }
}
