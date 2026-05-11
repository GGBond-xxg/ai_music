part of '../home_page.dart';

class _DesktopHomeShell extends StatelessWidget {
  const _DesktopHomeShell();

  @override
  Widget build(BuildContext context) {
    return const _DesktopTrackTheme(
      child: _DesktopHomeScaffold(),
    );
  }
}

class _DesktopHomeScaffold extends StatelessWidget {
  const _DesktopHomeScaffold();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          const Positioned.fill(child: _DesktopMoodBackground()),
          Column(
            children: const [
              DesktopWindowTitleBar(),
              Expanded(
                child: Row(
                  children: [
                    _DesktopSidebar(),
                    Expanded(child: _DesktopLibraryPanel()),
                    _DesktopNowPlayingPanel(),
                  ],
                ),
              ),
              _DesktopTransportBar(),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopTrackTheme extends StatefulWidget {
  const _DesktopTrackTheme({required this.child});

  final Widget child;

  @override
  State<_DesktopTrackTheme> createState() => _DesktopTrackThemeState();
}

class _DesktopTrackThemeState extends State<_DesktopTrackTheme> {
  String? _paletteKey;
  Color? _currentSeed;

  @override
  Widget build(BuildContext context) {
    final player = Get.find<PlayerController>();
    final baseTheme = Theme.of(context);
    // PC 端固定夜间模式；手机 / PAD 仍然走 AppController 里的主题设置。
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.dark,
    );

    return Obx(() {
      final track = player.currentTrack;
      _ensurePalette(track, baseScheme);

      final effectiveScheme = _currentSeed == null
          ? baseScheme
          : _desktopColorSchemeFromSeed(_currentSeed!, baseScheme);

      final themed = baseTheme.copyWith(
        brightness: Brightness.dark,
        colorScheme: effectiveScheme,
        scaffoldBackgroundColor: effectiveScheme.surface,
        textTheme: baseTheme.textTheme.apply(
          bodyColor: effectiveScheme.onSurface,
          displayColor: effectiveScheme.onSurface,
        ),
        sliderTheme: baseTheme.sliderTheme.copyWith(
          activeTrackColor: effectiveScheme.primary,
          inactiveTrackColor:
              effectiveScheme.onSurfaceVariant.withValues(alpha: 0.22),
          thumbColor: effectiveScheme.primary,
          overlayColor: effectiveScheme.primary.withValues(alpha: 0.10),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: effectiveScheme.onSurface),
        ),
      );

      return AnimatedTheme(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        data: themed,
        child: widget.child,
      );
    });
  }

  void _ensurePalette(MusicTrack? track, ColorScheme scheme) {
    DebugTrace.instance.log('PC_THEME', 'ensurePalette track=${DebugTrace.instance.track(track)} currentKey=$_paletteKey currentSeed=$_currentSeed');
    if (track == null) {
      if (_paletteKey != null) {
        _paletteKey = null;
        _currentSeed = null;
      }
      return;
    }

    final cache = CoverPaletteCache.instance;
    final key = cache.keyForTrack(track, scheme.brightness);
    if (_paletteKey == key) {
      DebugTrace.instance.log('PC_THEME', 'same palette key=$key');
      return;
    }

    DebugTrace.instance.log('PC_THEME', 'switch key old=$_paletteKey new=$key');
    _paletteKey = key;

    // 先同步读取磁盘缓存到内存。这样重新打开软件时，第一帧就是上次的封面色，
    // 不会先闪一下默认主题色。
    final cached = cache.cachedSeedForKey(key);
    if (cached != null) {
      DebugTrace.instance.log('PC_THEME', 'cache applied key=$key color=${cached.toARGB32().toRadixString(16)}');
      _currentSeed = cached;
      return;
    }

    final fallback = _currentSeed ?? scheme.primary;
    DebugTrace.instance.log('PC_THEME', 'cache miss key=$key fallback=${fallback.toARGB32().toRadixString(16)}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _paletteKey != key) return;
      unawaited(_loadSeedFromCover(track, scheme, key, fallback));
    });
  }

  Future<void> _loadSeedFromCover(
    MusicTrack track,
    ColorScheme scheme,
    String key,
    Color fallback,
  ) async {
    final sw = Stopwatch()..start();
    final seed = await CoverPaletteCache.instance.resolveSeedForTrack(
      track,
      scheme.brightness,
      fallback: fallback,
      sampleSize: const Size(220, 220),
      maximumColorCount: 18,
    );

    sw.stop();
    DebugTrace.instance.log('PC_THEME', 'async seed loaded key=$key color=${seed.toARGB32().toRadixString(16)} cost=${sw.elapsedMilliseconds}ms mounted=$mounted currentKey=$_paletteKey');
    if (!mounted || _paletteKey != key) return;
    setState(() => _currentSeed = seed);
  }

}

ColorScheme _desktopColorSchemeFromSeed(Color seed, ColorScheme base) {
  final isDark = base.brightness == Brightness.dark;
  final hsl = HSLColor.fromColor(seed);
  final normalized = hsl
      .withSaturation(hsl.saturation.clamp(0.26, 0.78).toDouble())
      .withLightness(hsl.lightness.clamp(0.30, 0.66).toDouble())
      .toColor();

  final generated = ColorScheme.fromSeed(
    seedColor: normalized,
    brightness: base.brightness,
  );

  Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  final surface = isDark
      ? mix(const Color(0xFF101017), normalized, 0.20)
      : mix(const Color(0xFFF9F6FF), normalized, 0.08);
  final surfaceContainer = isDark
      ? mix(surface, Colors.white, 0.035)
      : mix(surface, Colors.black, 0.025);
  final surfaceHigh = isDark
      ? mix(surface, Colors.white, 0.075)
      : mix(surface, Colors.black, 0.045);
  final primary = isDark
      ? mix(generated.primary, Colors.white, 0.10)
      : mix(generated.primary, Colors.black, 0.02);

  return base.copyWith(
    primary: primary,
    onPrimary: generated.onPrimary,
    primaryContainer: generated.primaryContainer,
    onPrimaryContainer: generated.onPrimaryContainer,
    secondary: generated.secondary,
    onSecondary: generated.onSecondary,
    secondaryContainer: generated.secondaryContainer,
    onSecondaryContainer: generated.onSecondaryContainer,
    tertiary: generated.tertiary,
    surface: surface,
    onSurface: generated.onSurface,
    onSurfaceVariant: generated.onSurfaceVariant,
    surfaceContainer: surfaceContainer,
    surfaceContainerLow: mix(surface, surfaceContainer, 0.55),
    surfaceContainerHigh: surfaceHigh,
    surfaceContainerHighest: mix(surfaceHigh, generated.primaryContainer, isDark ? 0.10 : 0.13),
    outline: generated.outline,
    outlineVariant: generated.outlineVariant,
  );
}

class _DesktopMoodBackground extends StatelessWidget {
  const _DesktopMoodBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      color: scheme.surface,
    );
  }
}
