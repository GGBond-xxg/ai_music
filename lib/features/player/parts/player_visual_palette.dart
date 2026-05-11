part of '../player_page.dart';

class _PlayerVisualPalette {
  const _PlayerVisualPalette({
    required this.background,
    required this.backgroundEnd,
    required this.onBackground,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.divider,
    required this.controlSurface,
  });

  final Color background;
  final Color backgroundEnd;
  final Color onBackground;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color divider;
  final Color controlSurface;
}

_PlayerVisualPalette _visualPaletteFor(ColorScheme scheme) {
  final isDark = scheme.brightness == Brightness.dark;
  return _PlayerVisualPalette(
    background: scheme.surface,
    backgroundEnd: scheme.surfaceContainerHighest,
    onBackground: scheme.onSurface,
    muted: scheme.onSurfaceVariant,
    accent: scheme.primary,
    onAccent: scheme.onPrimary,
    divider: scheme.onSurfaceVariant.withValues(alpha: isDark ? 0.22 : 0.16),
    controlSurface:
        isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerHighest,
  );
}

Color _mixColor(Color a, Color b, double amount) {
  return Color.lerp(a, b, amount) ?? a;
}

_PlayerVisualPalette _visualPaletteFromSeed(
  Color seed,
  Brightness brightness,
) {
  final isDark = brightness == Brightness.dark;
  final normalized = HSLColor.fromColor(seed).withSaturation(
    HSLColor.fromColor(seed).saturation.clamp(0.22, 0.72).toDouble(),
  );
  final tone = normalized.toColor();

  final background = isDark
      ? _mixColor(const Color(0xFF07080C), tone, 0.46)
      : _mixColor(const Color(0xFFF7F5FB), tone, 0.32);
  final backgroundEnd = isDark
      ? _mixColor(background, Colors.black, 0.14)
      : _mixColor(background, tone, 0.10);
  final controlSurface = isDark
      ? _mixColor(background, Colors.white, 0.12)
      : _mixColor(background, Colors.white, 0.16);
  final accent = isDark
      ? _mixColor(tone, Colors.white, 0.10)
      : _mixColor(tone, Colors.black, 0.08);

  final onBackground =
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
          ? Colors.white
          : const Color(0xFF131313);
  final onAccent =
      ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
          ? Colors.white
          : const Color(0xFF111111);

  return _PlayerVisualPalette(
    background: background,
    backgroundEnd: backgroundEnd,
    onBackground: onBackground,
    muted: onBackground.withValues(alpha: 0.74),
    accent: accent,
    onAccent: onAccent,
    divider: onBackground.withValues(alpha: isDark ? 0.18 : 0.12),
    controlSurface: controlSurface,
  );
}
