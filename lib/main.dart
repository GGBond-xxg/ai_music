import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'pages/library.dart';
import 'pages/settings_page.dart';
import 'pages/nowplaying.dart';
import 'pages/roam.dart';
import 'providers/library_provider.dart';
import 'providers/local_database_provider.dart';
import 'providers/search_provider.dart';
import 'providers/spotify_provider.dart';
import 'providers/theme_provider.dart';
import 'services/app_locale_controller.dart';
import 'services/language_service.dart';
import 'services/lyrics_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/ui_texts.dart';
import 'utils/responsive.dart';
import 'widgets/spotify_selectors.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MediaKit.ensureInitialized();

  final spotifyProvider = SpotifyProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: spotifyProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (context) => LibraryProvider(context.read<SpotifyProvider>()),
        ),
        ChangeNotifierProvider(
          create: (context) => SearchProvider(context.read<SpotifyProvider>()),
        ),
        ChangeNotifierProxyProvider<SpotifyProvider, LocalDatabaseProvider>(
          create: (context) =>
              LocalDatabaseProvider(context.read<SpotifyProvider>()),
          update: (context, spotify, previous) {
            final provider = previous ?? LocalDatabaseProvider(spotify);
            provider.spotifyProviderUpdated(spotify);
            return provider;
          },
        ),
        Provider<LyricsService>(create: (_) => LyricsService()),
        Provider<NotificationService>(
          create: (_) => NotificationService(scaffoldMessengerKey),
        ),
        Provider<SettingsService>(
            create: (_) => SettingsService()), // Add this line
      ],
      child: const MyThemedApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    spotifyProvider.autoLogin();
  });
}

class MyThemedApp extends StatefulWidget {
  const MyThemedApp({super.key});

  @override
  State<MyThemedApp> createState() => _MyThemedAppState();
}

class _MyThemedAppState extends State<MyThemedApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    appLocaleNotifier.addListener(_handleLocaleChanged);
    _loadSavedLocale();
  }

  @override
  void dispose() {
    appLocaleNotifier.removeListener(_handleLocaleChanged);
    super.dispose();
  }

  void _handleLocaleChanged() {
    if (!mounted) return;
    setState(() {
      _locale = appLocaleNotifier.value;
    });
  }

  Future<void> _loadSavedLocale() async {
    final savedLocale = await LanguageService.getSavedLocale();
    if (!mounted) return;
    appLocaleNotifier.value = savedLocale;
    setState(() {
      _locale = savedLocale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appNameForLocale(_locale),
      onGenerateTitle: (context) => appNameForContext(context),
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LanguageService.supportedLocales,
      theme: ThemeData(
        fontFamily: 'Spotify Mix',
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Selector<ThemeProvider, ColorScheme>(
          selector: (context, provider) => provider.colorScheme,
          builder: (context, colorScheme, _) {
            final brightness = colorScheme.brightness;
            final systemUiOverlayStyle = SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              statusBarIconBrightness: brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: brightness == Brightness.dark
                  ? Brightness.dark
                  : Brightness.light,
            );

            final themedData = ThemeData(
              fontFamily: 'Spotify Mix',
              colorScheme: colorScheme,
              useMaterial3: true,
              appBarTheme:
                  AppBarTheme(systemOverlayStyle: systemUiOverlayStyle),
              pageTransitionsTheme: PageTransitionsTheme(
                builders: <TargetPlatform, PageTransitionsBuilder>{
                  TargetPlatform.android: SharedAxisPageTransitionsBuilder(
                    transitionType: SharedAxisTransitionType.horizontal,
                  ),
                  TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
                },
              ),
            );
            final themedChild = child ?? const SizedBox.shrink();
            final baseMediaQuery = MediaQuery.of(context);
            final double textScaleMultiplier = kIsWeb ? 1.12 : 1.0;
            final baseScale = baseMediaQuery.textScaler.scale(1.0);
            final mediaData = baseMediaQuery.copyWith(
              textScaler: TextScaler.linear(baseScale * textScaleMultiplier),
            );

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: systemUiOverlayStyle,
              child: MediaQuery(
                data: mediaData,
                child: Theme(
                  data: themedData,
                  child: themedChild,
                ),
              ),
            );
          },
          child: child,
        );
      },
      home: const MyApp(),
    );
  }
}

class ProgressIndicator extends StatefulWidget {
  final double progress;
  final double duration;
  final bool isPlaying;
  final ValueChanged<int>? onSeek;

  const ProgressIndicator({
    super.key,
    required this.progress,
    required this.duration,
    required this.isPlaying,
    this.onSeek,
  });

  @override
  State<ProgressIndicator> createState() => _ProgressIndicatorState();
}

class _ProgressIndicatorState extends State<ProgressIndicator>
    with SingleTickerProviderStateMixin {
  late double _currentProgress;
  Timer? _progressTimer;
  late final AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _currentProgress = widget.progress;

    _progressAnimation = Tween<double>(
      begin: _currentProgress,
      end: _currentProgress,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _startProgressTimer();
  }

  @override
  void didUpdateWidget(ProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果进度差异大于1秒，使用动画过渡
    if ((widget.progress - _currentProgress).abs() > 1000) {
      _progressAnimation = Tween<double>(
        begin: _currentProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ));
      _currentProgress = widget.progress;
      _animationController.forward(from: 0);
    }
    // 播放状态改变时更新计时器
    if (widget.isPlaying != oldWidget.isPlaying) {
      _startProgressTimer();
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    if (widget.isPlaying) {
      _progressTimer =
          Timer.periodic(const Duration(milliseconds: 1000), (timer) {
        if (mounted) {
          setState(() {
            _currentProgress =
                math.min(_currentProgress + 1000, widget.duration);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        final displayProgress = _animationController.isAnimating
            ? _progressAnimation.value
            : _currentProgress;

        final safeDuration = widget.duration <= 0 ? 1.0 : widget.duration;
        final value = (displayProgress / safeDuration).clamp(0.0, 1.0);

        void seekFromDx(double dx, double width) {
          if (widget.onSeek == null || width <= 0) return;
          final ratio = (dx / width).clamp(0.0, 1.0);
          widget.onSeek!((safeDuration * ratio).round());
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  seekFromDx(details.localPosition.dx, constraints.maxWidth),
              onHorizontalDragUpdate: (details) =>
                  seekFromDx(details.localPosition.dx, constraints.maxWidth),
              child: SizedBox(
                height: 16,
                child: Center(
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 4.0,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  int _selectedIndex = 1;
  late final PageController _pageController;
  DateTime? _lastBackPressTime;
  SpotifyProvider? _themeSpotifyProvider;
  String? _lastThemeImageUrl;
  int _themeImageRequestId = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    WidgetsBinding.instance.addObserver(this);
    // 初始化时更新主题，并在首次启动时请求本地音乐权限/扫描设备音乐。
    // 封面取色不能只放在 Player 页面里触发，否则 App 打开后停在音乐库时切歌不会马上换色。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final spotifyProvider = context.read<SpotifyProvider>();
      _themeSpotifyProvider = spotifyProvider;
      spotifyProvider.addListener(_scheduleThemeFromCurrentTrack);
      unawaited(context.read<ThemeProvider>().loadThemeMode(context).then((_) {
        _scheduleThemeFromCurrentTrack(force: true);
      }));
      unawaited(spotifyProvider.requestInitialDeviceScan());
    });
  }

  @override
  void dispose() {
    _themeSpotifyProvider?.removeListener(_scheduleThemeFromCurrentTrack);
    _themeSpotifyProvider = null;
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  String? _coverUrlFromCurrentTrack() {
    final item = _themeSpotifyProvider?.currentTrack?['item'];
    if (item is! Map) return null;

    final album = item['album'];
    if (album is Map) {
      final images = album['images'];
      if (images is List && images.isNotEmpty) {
        final first = images.first;
        if (first is Map) {
          final url = first['url']?.toString().trim();
          if (url != null && url.isNotEmpty) return url;
        }
      }
    }

    final images = item['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map) {
        final url = first['url']?.toString().trim();
        if (url != null && url.isNotEmpty) return url;
      }
    }

    return null;
  }

  ImageProvider? _imageProviderForThemeCover(String coverUrl) {
    final value = coverUrl.trim();
    if (value.isEmpty) return null;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return NetworkImage(value);
    }

    try {
      final file = value.startsWith('file://')
          ? File(Uri.parse(value).toFilePath())
          : File(value);
      if (file.existsSync()) return FileImage(file);
    } catch (_) {}

    return null;
  }

  void _scheduleThemeFromCurrentTrack({bool force = false}) {
    if (!mounted) return;

    final coverUrl = _coverUrlFromCurrentTrack();
    if (coverUrl == null || coverUrl.isEmpty) return;
    if (!force && coverUrl == _lastThemeImageUrl) return;

    _lastThemeImageUrl = coverUrl;
    final requestId = ++_themeImageRequestId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || requestId != _themeImageRequestId) return;

      final imageProvider = _imageProviderForThemeCover(coverUrl);
      if (imageProvider == null) return;

      final themeProvider = context.read<ThemeProvider>();
      final brightness = themeProvider.resolveBrightness(context);

      unawaited(themeProvider.updateThemeFromImage(
        imageProvider: imageProvider,
        brightness: brightness,
        cacheKey: coverUrl,
      ));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 当应用从后台恢复时，刷新播放状态和主题
      final spotifyProvider =
          Provider.of<SpotifyProvider>(context, listen: false);
      // 仅在用户已登录时才执行刷新和启动定时器
      if (spotifyProvider.username != null) {
        // 调用 startTrackRefresh 会取消任何现有定时器并启动新的，同时会立即执行一次刷新
        spotifyProvider.startTrackRefresh();
      }
      // 刷新主题时优先使用当前播放封面；没有封面时才回退到当前种子色。
      _scheduleThemeFromCurrentTrack(force: true);
    }
  }

  @override
  void didChangePlatformBrightness() {
    // 当系统主题改变时，用当前封面重新生成对应亮度的主题。
    _scheduleThemeFromCurrentTrack(force: true);
  }

  // 页面顺序：播放中 / 音乐库 / 音乐源。默认停在音乐库，左右滑动切换。
  final List<Widget> _pages = [
    const NowPlaying(),
    const Library(),
    const Roam(),
  ];

  /// 处理返回键：如果不在首页则返回首页，否则双击退出
  void _handleBackPress(bool didPop) {
    if (didPop) return;

    // 如果不在默认音乐库页，返回音乐库页
    if (_selectedIndex != 1) {
      _switchToPage(1);
      return;
    }

    // 在首页，实现双击退出
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      final notificationService =
          Provider.of<NotificationService>(context, listen: false);
      final l10n = AppLocalizations.of(context);
      notificationService.showSnackBar(
        l10n?.pressAgainToExit ?? 'Press again to exit',
      );
    } else {
      // 双击确认退出
      SystemNavigator.pop();
    }
  }

  void _switchToPage(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() {
      _selectedIndex = index;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shellLayout = context.layoutType(ResponsivePageType.shell);
    final isLargeScreen = shellLayout.preferTwoPane;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handleBackPress(didPop),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/icons/app_icon_monochrome.png',
                width: 40,
                height: 40,
                color: Theme.of(context).colorScheme.onSurface,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.music_note_rounded,
                    size: 24,
                    color: Theme.of(context).colorScheme.onSurface,
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                // 使用 Expanded 防止文本溢出
                child: Selector<
                    SpotifyProvider,
                    ({
                      String? title,
                      String? source,
                      String? sourceType,
                      bool hasTrack
                    })>(
                  selector: (_, provider) {
                    final item = provider.currentTrack?['item'];
                    return (
                      title: item?['name'] as String?,
                      source: item?['sourceLabel'] as String?,
                      sourceType: item?['sourceType'] as String?,
                      hasTrack: item != null,
                    );
                  },
                  builder: (context, state, child) {
                    if (state.hasTrack &&
                        state.title != null &&
                        state.title!.trim().isNotEmpty) {
                      final source = UiTexts.of(context).sourceNameFromString(
                        state.sourceType,
                        fallback: state.source,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            state.title!,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            UiTexts.of(context).playingFrom(source),
                            style: Theme.of(context).textTheme.labelSmall,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      );
                    }
                    return Text(appNameForContext(context));
                  },
                ),
              ),
            ],
          ),
          actions: [
            Selector<SpotifyProvider, bool>(
              selector: (_, provider) => provider.currentTrack != null,
              builder: (context, hasTrack, _) {
                if (!hasTrack) return const SizedBox.shrink();
                return IconButton.filledTonal(
                  tooltip: UiTexts.of(context).next,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.read<SpotifyProvider>().skipToNext();
                  },
                  icon: const Icon(Icons.skip_next_rounded),
                );
              },
            ),
            Selector<SpotifyProvider, ({bool hasTrack, bool isPlaying})>(
              selector: (_, provider) => (
                hasTrack: provider.currentTrack != null,
                isPlaying: provider.currentTrack?['is_playing'] ?? false,
              ),
              builder: (context, state, _) {
                if (!state.hasTrack) return const SizedBox.shrink();
                return IconButton.filledTonal(
                  tooltip: state.isPlaying
                      ? UiTexts.of(context).pause
                      : UiTexts.of(context).play,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.read<SpotifyProvider>().togglePlayPause();
                  },
                  icon: Icon(
                    state.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                );
              },
            ),
            IconButton.filledTonal(
              onPressed: () {
                HapticFeedback.lightImpact();
                ResponsiveNavigation.showAdaptiveModalPage(
                  context: context,
                  showCloseButton: false,
                  child: const SettingsPage(),
                );
              },
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4.0),
            child: ProgressBarSelector(
              builder: (context, state, child) {
                if (!state.hasTrack) {
                  return const SizedBox.shrink();
                }

                return ProgressIndicator(
                  progress: state.progress.toDouble(),
                  duration: state.duration.toDouble(),
                  isPlaying: state.isPlaying,
                  onSeek: (positionMs) => context
                      .read<SpotifyProvider>()
                      .seekToPosition(positionMs),
                );
              },
            ),
          ),
        ),
        body: Row(
          children: [
            if (isLargeScreen)
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (int index) {
                  HapticFeedback.lightImpact();
                  _switchToPage(index);
                },
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.music_note),
                    label: Text(AppLocalizations.of(context)!.nowPlayingLabel),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.library_music_outlined),
                    label: Text(AppLocalizations.of(context)!.libraryLabel),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.storage_rounded),
                    label: Text(UiTexts.of(context).musicSources),
                  ),
                ],
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  if (_selectedIndex != index) {
                    setState(() => _selectedIndex = index);
                  }
                },
                children: _pages,
              ),
            ),
          ],
        ),
        bottomNavigationBar: isLargeScreen
            ? null
            : SafeArea(
                bottom: false,
                child: NavigationBar(
                  height: defaultTargetPlatform == TargetPlatform.iOS
                      ? 55
                      : null, // 只在 iOS 平台设置固定高度
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    HapticFeedback.lightImpact();
                    _switchToPage(index);
                  },
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.music_note),
                      label: AppLocalizations.of(context)!.nowPlayingLabel,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.library_music_outlined),
                      label: AppLocalizations.of(context)!.libraryLabel,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.storage_rounded),
                      label: UiTexts.of(context).musicSources,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
