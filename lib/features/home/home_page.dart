import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../models/lyric_line.dart';
import '../../models/music_track.dart';
import '../../services/cover_palette_cache.dart';
import '../../services/debug_trace.dart';
import '../../services/player_controller.dart';
import '../../services/player_sheet_controller.dart';
import '../../services/mobile_performance_logger.dart';
import '../../widgets/desktop_window_title_bar.dart';
import '../../widgets/mini_player.dart';
import '../../widgets/track_cover.dart';
import '../about/about_page.dart';
import '../player/player_page.dart';
import '../sources/sources_page.dart';
import 'home_controller.dart';
import 'package:window_manager/window_manager.dart';

part 'parts/tablet_home.dart';
part 'parts/desktop_shell.dart';
part 'parts/desktop_sidebar.dart';
part 'parts/desktop_library.dart';
part 'parts/desktop_now_playing.dart';
part 'parts/desktop_transport_bar.dart';
part 'parts/mobile_library_view.dart';
part 'parts/home_shared_widgets.dart';
part 'parts/home_drawers.dart';
part 'parts/music_search_page.dart';

enum _FreshDeviceClass { phone, tablet, desktop }

_FreshDeviceClass _deviceClassFor(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final platform = defaultTargetPlatform;
  final isDesktopPlatform = !kIsWeb &&
      (platform == TargetPlatform.windows ||
          platform == TargetPlatform.macOS ||
          platform == TargetPlatform.linux);

  if (isDesktopPlatform && size.width >= 760) {
    return _FreshDeviceClass.desktop;
  }

  if (size.shortestSide >= 600 || size.width >= 720) {
    return _FreshDeviceClass.tablet;
  }

  return _FreshDeviceClass.phone;
}

IconData _sourceIconData(MusicSourceType? type) {
  switch (type) {
    case null:
      return Icons.library_music_rounded;
    case MusicSourceType.localFile:
      return Icons.audio_file_rounded;
    case MusicSourceType.webDav:
      return Icons.storage_rounded;
    case MusicSourceType.emby:
      return Icons.live_tv_rounded;
    case MusicSourceType.jellyfin:
      return Icons.cast_connected_rounded;
    case MusicSourceType.navidrome:
      return Icons.cloud_queue_rounded;
    case MusicSourceType.directUrl:
      return Icons.link_rounded;
  }
}

int _sourceCountFor(HomeController home, MusicSourceType? type) {
  if (type == null) return home.tracks.length;
  return home.tracks.where((track) => track.sourceType == type).length;
}

Future<void> _runSourceImport(
  BuildContext context,
  HomeController home,
  MusicSourceType sourceType,
) async {
  switch (sourceType) {
    case MusicSourceType.localFile:
      await home.importLocal();
      break;
    case MusicSourceType.webDav:
      if (!context.mounted) return;
      await showWebDavDialog(
        context: context,
        onTracksLoaded: (tracks) =>
            home.replaceSourceTracks(MusicSourceType.webDav, tracks),
      );
      break;
    case MusicSourceType.emby:
      if (!context.mounted) return;
      await showEmbyDialog(
        context: context,
        onTracksLoaded: (tracks) =>
            home.replaceSourceTracks(MusicSourceType.emby, tracks),
      );
      break;
    case MusicSourceType.jellyfin:
      if (!context.mounted) return;
      await showJellyfinDialog(
        context: context,
        onTracksLoaded: (tracks) =>
            home.replaceSourceTracks(MusicSourceType.jellyfin, tracks),
      );
      break;
    case MusicSourceType.navidrome:
      if (!context.mounted) return;
      await showNavidromeDialog(
        context: context,
        onTracksLoaded: (tracks) =>
            home.replaceSourceTracks(MusicSourceType.navidrome, tracks),
      );
      break;
    case MusicSourceType.directUrl:
      Get.snackbar('source.urlComingTitle'.tr, 'source.urlComingBody'.tr, snackPosition: SnackPosition.TOP);
      break;
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    switch (_deviceClassFor(context)) {
      case _FreshDeviceClass.desktop:
        return const _DesktopHomeShell();
      case _FreshDeviceClass.tablet:
        return const _TabletHomeShell();
      case _FreshDeviceClass.phone:
        return const _PhoneHomeShell();
    }
  }
}

class _PhoneHomeShell extends StatelessWidget {
  const _PhoneHomeShell();

  @override
  Widget build(BuildContext context) {
    final sheet = Get.find<PlayerSheetController>();
    final player = Get.find<PlayerController>();
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final sheetOpen = sheet.isSheetMounted.value;

      return PopScope(
        canPop: !sheetOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (sheet.isSheetMounted.value) {
            sheet.close();
          }
        },
        child: Scaffold(
          backgroundColor: scheme.surface,
          drawer: const _ThemeDrawer(),
          endDrawer: const _SourcesEndDrawer(),
          endDrawerEnableOpenDragGesture: true,
          extendBody: true,
          body: ColoredBox(
            color: scheme.surface,
            child: Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: Builder(
                    builder: (context) => _GramophoneLibraryView(
                      onOpenDrawer: () => Scaffold.of(context).openDrawer(),
                      onOpenSources: () => Scaffold.of(context).openEndDrawer(),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MiniPlayer(),
                ),
                Obx(() {
                  final hasTrack = player.currentTrack != null;
                  if (!hasTrack) {
                    return const SizedBox.shrink();
                  }

                  return const Positioned.fill(child: PlayerPage());
                }),
              ],
            ),
          ),
        ),
      );
    });
  }
}
