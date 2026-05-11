import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/app.dart';
import 'app/app_controller.dart';
import 'app/app_translations.dart';
import 'features/home/home_controller.dart';
import 'services/cover_palette_cache.dart';
import 'services/debug_trace.dart';
import 'services/mobile_performance_logger.dart';
import 'services/player_controller.dart';
import 'services/player_sheet_controller.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 首页封面较多时，默认图片缓存偏小会导致滑动中反复解码。
  // 移动端控制在较低内存占用；桌面端适当放大。
  final imageCache = PaintingBinding.instance.imageCache;
  final isDesktopCache = defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
  imageCache.maximumSize = isDesktopCache ? 700 : 360;
  imageCache.maximumSizeBytes = (isDesktopCache ? 128 : 64) << 20;

  MediaKit.ensureInitialized();
  await _configureDesktopWindow();

  await DebugTrace.instance.init();
  await MobilePerformanceLogger.instance.init();
  DebugTrace.instance.log(
      'APP', 'main init start platform=$defaultTargetPlatform kIsWeb=$kIsWeb');

  // 先加载翻译，再读取语言并设置桌面窗口标题。
  // 否则 Windows 首次启动时任务栏缩略图标题会先是空白。
  await FreshTranslations.load();

  final appController = Get.put(AppController(), permanent: true);
  await appController.load();
  await CoverPaletteCache.instance.init();

  Get.put(PlayerController(), permanent: true);
  Get.put(PlayerSheetController(), permanent: true);
  final homeController = Get.put(HomeController(), permanent: true);
  // 先加载本地曲库缓存并恢复上次播放项，再绘制第一帧。
  // 这样 PC / 播放页可以第一帧就拿到当前歌曲和封面色缓存，
  // 避免出现“默认色 -> 当前歌曲封面色”的突兀闪烁。
  await homeController.loadCachedTracks();
  DebugTrace.instance.log('APP', 'loadCachedTracks done, runApp');

  runApp(const FreshMusicApp());
}

Future<void> _configureDesktopWindow() async {
  if (kIsWeb) return;

  final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
  if (!isDesktop) return;

  await windowManager.ensureInitialized();

  const initialSize = Size(1280, 720);
  const minimumSize = Size(1024, 768);

  const options = WindowOptions(
    size: initialSize,
    minimumSize: minimumSize,
    center: true,
    title: 'Fresh Music',
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Colors.transparent,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setMinimumSize(minimumSize);
    await windowManager.setSize(initialSize);
    await windowManager.setTitle('Fresh Music');
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  });
}
