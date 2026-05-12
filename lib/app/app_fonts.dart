import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_controller.dart';

/// Centralised Google Fonts configuration for the whole app.
///
/// The app contains Chinese UI, English UI, mixed-language song names and
/// lyrics. Keeping font selection here avoids scattered `GoogleFonts.*` calls
/// and makes every Material text style share the same typography rules.
class AppFonts {
  AppFonts._();

  static const List<String> fallbackFamilies = [
    'Noto Sans SC',
    'Noto Sans CJK SC',
    'Noto Sans JP',
    'Noto Sans KR',
    'Noto Color Emoji',
    'Roboto',
    'sans-serif',
  ];

  static TextTheme buildTextTheme({
    required AppLanguage language,
    required ColorScheme scheme,
  }) {
    final baseTextTheme = _baseTextTheme(language);

    return _applyFallback(baseTextTheme)
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        )
        .copyWith(
          displayLarge: _style(
            baseTextTheme.displayLarge,
            color: scheme.onSurface,
            weight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
          displayMedium: _style(
            baseTextTheme.displayMedium,
            color: scheme.onSurface,
            weight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
          displaySmall: _style(
            baseTextTheme.displaySmall,
            color: scheme.onSurface,
            weight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
          headlineLarge: _style(
            baseTextTheme.headlineLarge,
            color: scheme.onSurface,
            weight: FontWeight.w900,
            letterSpacing: -0.35,
          ),
          headlineMedium: _style(
            baseTextTheme.headlineMedium,
            color: scheme.onSurface,
            weight: FontWeight.w800,
            letterSpacing: -0.25,
          ),
          headlineSmall: _style(
            baseTextTheme.headlineSmall,
            color: scheme.onSurface,
            weight: FontWeight.w800,
            letterSpacing: -0.15,
          ),
          titleLarge: _style(
            baseTextTheme.titleLarge,
            color: scheme.onSurface,
            weight: FontWeight.w800,
          ),
          titleMedium: _style(
            baseTextTheme.titleMedium,
            color: scheme.onSurface,
            weight: FontWeight.w800,
          ),
          titleSmall: _style(
            baseTextTheme.titleSmall,
            color: scheme.onSurface,
            weight: FontWeight.w800,
          ),
          bodyLarge: _style(
            baseTextTheme.bodyLarge,
            color: scheme.onSurface,
            weight: FontWeight.w500,
          ),
          bodyMedium: _style(
            baseTextTheme.bodyMedium,
            color: scheme.onSurfaceVariant,
            weight: FontWeight.w500,
          ),
          bodySmall: _style(
            baseTextTheme.bodySmall,
            color: scheme.onSurfaceVariant,
            weight: FontWeight.w500,
          ),
          labelLarge: _style(
            baseTextTheme.labelLarge,
            color: scheme.onSurface,
            weight: FontWeight.w800,
          ),
          labelMedium: _style(
            baseTextTheme.labelMedium,
            color: scheme.onSurfaceVariant,
            weight: FontWeight.w700,
          ),
          labelSmall: _style(
            baseTextTheme.labelSmall,
            color: scheme.onSurfaceVariant,
            weight: FontWeight.w700,
          ),
        );
  }

  static TextTheme _baseTextTheme(AppLanguage language) {
    switch (language) {
      case AppLanguage.zh:
        // Chinese UI and mixed Chinese song metadata: Noto Sans SC has the
        // cleanest CJK rhythm while still looking natural for Latin text.
        return GoogleFonts.notoSansScTextTheme();
      case AppLanguage.en:
        // English UI: Inter is compact, modern and readable for app controls.
        // CJK lyrics / titles still use the fallback chain below.
        return GoogleFonts.interTextTheme();
    }
  }

  static TextTheme _applyFallback(TextTheme theme) {
    return theme.copyWith(
      displayLarge: _withFallback(theme.displayLarge),
      displayMedium: _withFallback(theme.displayMedium),
      displaySmall: _withFallback(theme.displaySmall),
      headlineLarge: _withFallback(theme.headlineLarge),
      headlineMedium: _withFallback(theme.headlineMedium),
      headlineSmall: _withFallback(theme.headlineSmall),
      titleLarge: _withFallback(theme.titleLarge),
      titleMedium: _withFallback(theme.titleMedium),
      titleSmall: _withFallback(theme.titleSmall),
      bodyLarge: _withFallback(theme.bodyLarge),
      bodyMedium: _withFallback(theme.bodyMedium),
      bodySmall: _withFallback(theme.bodySmall),
      labelLarge: _withFallback(theme.labelLarge),
      labelMedium: _withFallback(theme.labelMedium),
      labelSmall: _withFallback(theme.labelSmall),
    );
  }

  static TextStyle? _style(
    TextStyle? base, {
    required Color color,
    required FontWeight weight,
    double? letterSpacing,
  }) {
    return _withFallback(base)?.copyWith(
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle? _withFallback(TextStyle? style) {
    if (style == null) return null;
    return style.copyWith(fontFamilyFallback: fallbackFamilies);
  }
}
