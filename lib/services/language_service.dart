import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

final logger = Logger();

String appNameForLocale(Locale? locale) {
  if (locale == null) return 'Music';
  final languageCode = locale.languageCode.toLowerCase();
  final countryCode = locale.countryCode?.toUpperCase();
  if (languageCode == 'zh') {
    if (countryCode == 'TW' || countryCode == 'HK' || countryCode == 'MO') {
      return '音樂';
    }
    return '音乐';
  }
  return 'Music';
}

String appNameForContext(BuildContext context) {
  return appNameForLocale(Localizations.localeOf(context));
}

class LanguageService {
  static const String _languageKey = 'selected_language';
  static const MethodChannel _channel = MethodChannel('language_channel');

  // 只保留实际使用的语言。其他系统语言会回退到英文 UI / Music。
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// 获取当前保存的语言设置；null 表示跟随系统。
  static Future<Locale?> getSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey);

      if (languageCode == null) return null;

      final parts = languageCode.split('_');
      if (parts.length == 1) {
        return Locale(parts[0]);
      } else if (parts.length == 2) {
        return Locale(parts[0], parts[1]);
      }

      return null;
    } catch (e) {
      logger.d('Error getting saved locale: $e');
      return null;
    }
  }

  static Future<void> saveLocale(Locale locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = locale.countryCode != null
          ? '${locale.languageCode}_${locale.countryCode}'
          : locale.languageCode;

      await prefs.setString(_languageKey, languageCode);
    } catch (e) {
      logger.d('Error saving locale: $e');
    }
  }

  static Future<void> clearSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_languageKey);
    } catch (e) {
      logger.d('Error clearing saved locale: $e');
    }
  }

  /// 设置应用语言（Android 13+ 使用系统 API，旧版本使用应用内设置）。
  static Future<void> setAppLocale(Locale? locale) async {
    try {
      if (Platform.isAndroid) {
        if (locale == null) {
          await _channel.invokeMethod('clearAppLocale');
        } else {
          final languageTag = locale.countryCode != null
              ? '${locale.languageCode}-${locale.countryCode}'
              : locale.languageCode;
          await _channel.invokeMethod('setAppLocale', {'languageTag': languageTag});
        }
      }
    } catch (e) {
      logger.d('Error setting native app locale: $e');
    }

    if (locale == null) {
      await clearSavedLocale();
    } else {
      await saveLocale(locale);
    }
  }

  static Future<void> openSystemLanguageSettings() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('openSystemLanguageSettings');
    } catch (e) {
      logger.d('Error opening system language settings: $e');
    }
  }

  static Future<bool> supportsSystemLanguageSettings() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('supportsSystemLanguageSettings');
      return result as bool? ?? false;
    } catch (e) {
      logger.d('Error checking system language support: $e');
      return false;
    }
  }

  static String getLanguageDisplayName(Locale locale) {
    switch (locale.toString()) {
      case 'en':
        return 'English';
      case 'zh':
        return '简体中文';
      case 'zh_TW':
        return '繁體中文';
      default:
        return locale.toString();
    }
  }
}
