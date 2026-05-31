import 'package:flutter/material.dart';

/// App-wide locale notifier used by the settings page and MaterialApp.
/// null means following the device/system language.
final ValueNotifier<Locale?> appLocaleNotifier = ValueNotifier<Locale?>(null);

bool isTraditionalChineseLocale(Locale locale) {
  if (locale.languageCode.toLowerCase() != 'zh') return false;
  final country = locale.countryCode?.toUpperCase();
  final script = locale.scriptCode?.toUpperCase();
  return country == 'TW' || country == 'HK' || country == 'MO' || script == 'HANT';
}

String localizedAppName(Locale locale) {
  if (locale.languageCode.toLowerCase() == 'zh') {
    return isTraditionalChineseLocale(locale) ? '音樂' : '音乐';
  }
  return 'Music';
}

String localizedAppNameForOptionalLocale(Locale? locale, Locale fallback) {
  return localizedAppName(locale ?? fallback);
}

String localizedPlayingFrom(Locale locale, String source) {
  if (locale.languageCode.toLowerCase() == 'zh') {
    return '播放自 $source';
  }
  return 'Playing from $source';
}
