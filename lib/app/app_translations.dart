import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

class FreshTranslations extends Translations {
  static const zhLocale = 'zh_CN';
  static const enLocale = 'en_US';

  static final Map<String, Map<String, String>> _keys = {};

  static Future<void> load() async {
    final zh = await _loadJson('assets/i18n/zh_CN.json');
    final en = await _loadJson('assets/i18n/en_US.json');

    _keys
      ..clear()
      ..addAll({
        zhLocale: zh,
        enLocale: en,
      });
  }

  static Future<Map<String, String>> _loadJson(String path) async {
    final raw = await rootBundle.loadString(path);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    return decoded.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );
  }

  @override
  Map<String, Map<String, String>> get keys => _keys;
}
