import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/home/home_page.dart';
import 'app_controller.dart';
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

          return _buildApp(
            appController: appController,
            lightScheme: lightScheme,
            darkScheme: darkScheme,
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
      theme: _theme(lightScheme, Brightness.light),
      darkTheme: _theme(darkScheme, Brightness.dark),
      home: const HomePage(),
    );
  }

  ThemeData _theme(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseTextTheme = GoogleFonts.notoSansTextTheme();

    final textTheme = baseTextTheme
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        )
        .copyWith(
          headlineLarge: baseTextTheme.headlineLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
          headlineSmall: baseTextTheme.headlineSmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          bodySmall: baseTextTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          labelMedium: baseTextTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
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
        selectedLabelTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
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
          return TextStyle(
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
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        subtitleTextStyle: TextStyle(
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
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle:
            TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.78)),
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
        contentTextStyle: TextStyle(
          color: isDark ? scheme.onSurface : scheme.onInverseSurface,
        ),
      ),
    );
  }
}
