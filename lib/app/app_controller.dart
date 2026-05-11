import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

enum AppThemeMode { system, light, dark }

enum AppLanguage { zh, en }

class AppController extends GetxController with WidgetsBindingObserver {
  static const _themeKey = 'theme_mode';
  static const _monetKey = 'use_monet_color';
  static const _languageKey = 'language_mode';
  static const _hideAboutKey = 'hide_about_entry';

  final themeMode = AppThemeMode.system.obs;
  final language = AppLanguage.en.obs;
  final hideAboutEntry = false.obs;

  // 默认关闭系统动态取色，避免冷启动阶段读取系统 Core palette 抢首帧。
  // 用户仍可在设置里手动开启。
  final useMonetColor = false.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android 锁屏 / 解锁后，如果系统亮暗模式在后台发生过变化，
    // ThemeMode.system 需要主动刷新一次，避免回到前台后仍停留在旧外观。
    if (state == AppLifecycleState.resumed &&
        themeMode.value == AppThemeMode.system) {
      themeMode.refresh();
    }
  }

  @override
  void didChangePlatformBrightness() {
    // 跟随系统模式时，收到系统明暗变化通知就刷新根主题。
    if (themeMode.value == AppThemeMode.system) {
      themeMode.refresh();
    }
  }

  AppLanguage _systemLanguage() {
    final locale = PlatformDispatcher.instance.locale;
    final code = locale.languageCode.toLowerCase();

    if (code == 'zh') {
      return AppLanguage.zh;
    }

    if (code == 'en') {
      return AppLanguage.en;
    }

    // 没有适配的语言，默认英文
    return AppLanguage.en;
  }

  Future<void> _syncDesktopWindowTitle() async {
    if (kIsWeb) return;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await windowManager.setTitle('app.name'.tr);
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final rawTheme = prefs.getString(_themeKey);
    themeMode.value = AppThemeMode.values.firstWhere(
      (e) => e.name == rawTheme,
      orElse: () => AppThemeMode.system,
    );

    final rawLanguage = prefs.getString(_languageKey);

    if (rawLanguage == null || rawLanguage.isEmpty) {
      // 第一次打开，没有用户保存语言时，读取系统语言
      language.value = _systemLanguage();
    } else {
      // 用户切换过语言后，使用保存的语言
      language.value = AppLanguage.values.firstWhere(
        (e) => e.name == rawLanguage,
        orElse: () => AppLanguage.en,
      );
    }

    useMonetColor.value = prefs.getBool(_monetKey) ?? false;
    hideAboutEntry.value = prefs.getBool(_hideAboutKey) ?? false;

    await _syncDesktopWindowTitle();
  }

  ThemeMode get materialThemeMode {
    switch (themeMode.value) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  Locale get locale {
    switch (language.value) {
      case AppLanguage.zh:
        return const Locale('zh', 'CN');
      case AppLanguage.en:
        return const Locale('en', 'US');
    }
  }

  String get languageLabel {
    switch (language.value) {
      case AppLanguage.zh:
        return '中文';
      case AppLanguage.en:
        return 'English';
    }
  }

  Future<void> setThemeMode(AppThemeMode value) async {
    if (themeMode.value == value) {
      // 从锁屏恢复后，重新点一次相同选项也强制刷新，避免界面还停在旧外观。
      themeMode.refresh();
    } else {
      themeMode.value = value;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value.name);
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (language.value == value) return;

    language.value = value;
    Get.updateLocale(locale);

    await _syncDesktopWindowTitle();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value.name);
  }

  Future<void> hideAboutPermanently() async {
    hideAboutEntry.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideAboutKey, true);
  }

  Future<void> setUseMonetColor(bool value) async {
    useMonetColor.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monetKey, value);
  }
}
