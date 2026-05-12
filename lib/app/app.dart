import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import '../features/home/home_page.dart';
import 'app_controller.dart';
import 'app_fonts.dart';
import 'app_translations.dart';

class FreshMusicApp extends StatelessWidget {
  const FreshMusicApp({super.key});

  static const fallbackSeed = Color(0xFF6750A4);

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();

    return Obx(() {
      final useMonet = appController.useMonetColor.value;

      if (!useMonet) {
        return _buildApp(
          appController: appController,
          lightScheme: ColorScheme.fromSeed(
            seedColor: fallbackSeed,
            brightness: Brightness.light,
          ),
          darkScheme: ColorScheme.fromSeed(
            seedColor: fallbackSeed,
            brightness: Brightness.dark,
          ),
        );
      }

      // 只有用户开启“跟随系统取色”时才读取 dynamic_color，减少冷启动开销。
      return DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          final lightScheme = lightDynamic?.harmonized() ??
              ColorScheme.fromSeed(
                seedColor: fallbackSeed,
                brightness: Brightness.light,
              );
          final darkScheme = darkDynamic?.harmonized() ??
              ColorScheme.fromSeed(
                seedColor: fallbackSeed,
                brightness: Brightness.dark,
              );

          // DynamicColorBuilder 的 builder 会在外层 Obx 之外执行。
          // 莫奈取色开启后，如果这里直接返回 GetMaterialApp，
          // themeMode / locale 的变化就不会被 GetX 继续追踪，导致冷启动后
          // 切换浅色 / 深色没有反应。这里再包一层 Obx，让动态取色模式下
          // 主题和语言仍然保持响应式。
          return Obx(
            () => _buildApp(
              appController: appController,
              lightScheme: lightScheme,
              darkScheme: darkScheme,
            ),
          );
        },
      );
    });
  }

  Widget _buildApp({
    required AppController appController,
    required ColorScheme lightScheme,
    required ColorScheme darkScheme,
  }) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'app.name'.tr,
      translations: FreshTranslations(),
      locale: appController.locale,
      fallbackLocale: const Locale('en', 'US'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: appController.materialThemeMode,
      theme: _theme(
        lightScheme,
        Brightness.light,
        appController.language.value,
      ),
      darkTheme: _theme(
        darkScheme,
        Brightness.dark,
        appController.language.value,
      ),
      home: const HomePage(),
    );
  }

  ThemeData _theme(
    ColorScheme scheme,
    Brightness brightness,
    AppLanguage language,
  ) {
    final isDark = brightness == Brightness.dark;
    final textTheme = AppFonts.buildTextTheme(
      language: language,
      scheme: scheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? scheme.surfaceContainer : scheme.surface,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color:
                selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.onSurfaceVariant.withValues(alpha: 0.22),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          overlayColor: Colors.transparent,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? scheme.surfaceContainerHighest : scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? scheme.onSurface : scheme.onInverseSurface,
        ),
      ),
    );
  }
}
