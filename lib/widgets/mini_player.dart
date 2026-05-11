import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/cover_palette_cache.dart';
import '../services/player_controller.dart';
import '../services/player_sheet_controller.dart';
import 'track_cover.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  double? _lastDragY;
  String? _seedKey;
  Color? _coverSeed;

  void _ensureCoverSeed(
    BuildContext context,
    PlayerController controller,
    ColorScheme scheme,
  ) {
    final track = controller.currentTrack;
    if (track == null) {
      _seedKey = null;
      _coverSeed = null;
      return;
    }

    final brightness = Theme.of(context).brightness;
    final fallbackColor = _coverSeed ?? scheme.primary;
    final key = CoverPaletteCache.instance.keyForTrack(track, brightness);
    if (_seedKey == key) return;

    _seedKey = key;
    final cached =
        CoverPaletteCache.instance.cachedSeedForTrack(track, brightness);
    if (cached != null) {
      _coverSeed = cached;
    }

    CoverPaletteCache.instance
        .resolveSeedForTrack(
      track,
      brightness,
      fallback: fallbackColor,
    )
        .then((seed) {
      if (!mounted) return;
      final latest = controller.currentTrack;
      if (latest == null) return;
      final latestKey = CoverPaletteCache.instance.keyForTrack(
        latest,
        brightness,
      );
      if (latestKey != key) return;
      setState(() => _coverSeed = seed);
    }).catchError((_) {});
  }

  Color _progressColor(BuildContext context, ColorScheme scheme) {
    final seed = _coverSeed ?? scheme.primary;
    final hsl = HSLColor.fromColor(seed);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return hsl
        .withSaturation((hsl.saturation * 0.95).clamp(0.30, 0.88).toDouble())
        .withLightness(isDark ? 0.68 : 0.48)
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    final sheetController = Get.find<PlayerSheetController>();
    final scheme = Theme.of(context).colorScheme;

    void openPlayer() => sheetController.openByTap(context);

    return Obx(() {
      final track = controller.currentTrack;
      if (track == null) return const SizedBox.shrink();

      _ensureCoverSeed(context, controller, scheme);
      final targetProgressColor = _progressColor(context, scheme);

      return TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: targetProgressColor),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, animatedColor, _) {
          final progressColor = animatedColor ?? targetProgressColor;
          final progressOnColor =
              ThemeData.estimateBrightnessForColor(progressColor) ==
                      Brightness.dark
                  ? Colors.white
                  : Colors.black;

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Material(
                color: scheme.surfaceContainerHigh,
                elevation: 0,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: openPlayer,
                  onVerticalDragStart: (details) {
                    _lastDragY = details.globalPosition.dy;
                    sheetController.beginInteractiveOpen(context);
                  },
                  onVerticalDragUpdate: (details) {
                    _lastDragY = details.globalPosition.dy;
                    sheetController.updateDrag(details.primaryDelta ?? 0);
                  },
                  onVerticalDragEnd: (details) {
                    sheetController.endDrag(
                      velocity: details.primaryVelocity ?? 0,
                      releaseY: _lastDragY,
                    );
                    _lastDragY = null;
                  },
                  onVerticalDragCancel: () {
                    sheetController.endDrag(releaseY: _lastDragY);
                    _lastDragY = null;
                  },
                  child: SizedBox(
                    height: 74,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _MiniPlayerProgressLayer(
                            controller: controller,
                            fallbackDuration: track.duration,
                            scheme: scheme,
                            progressColor: progressColor,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                          child: Row(
                            children: [
                              TrackCover(
                                track: track,
                                size: 52,
                                borderRadius: 16,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      track.artist ?? 'home.playingNow'.tr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'mini.openPlayer'.tr,
                                onPressed: openPlayer,
                                icon:
                                    const Icon(Icons.keyboard_arrow_up_rounded),
                              ),
                              Obx(() {
                                final playing = controller.isPlayingNow.value;
                                return IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: progressColor,
                                    foregroundColor: progressOnColor,
                                  ),
                                  icon: Icon(
                                    playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 28,
                                  ),
                                  onPressed: controller.togglePlay,
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

class _MiniPlayerProgressLayer extends StatelessWidget {
  const _MiniPlayerProgressLayer({
    required this.controller,
    required this.fallbackDuration,
    required this.scheme,
    required this.progressColor,
  });

  final PlayerController controller;
  final Duration? fallbackDuration;
  final ColorScheme scheme;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final duration =
          controller.displayDuration.value ?? fallbackDuration ?? Duration.zero;
      final position = controller.displayPosition.value;
      final progress = _progressValue(position, duration);

      return Stack(
        children: [
          Positioned.fill(
            child: _MiniPlayerProgressFill(
              progress: progress,
              scheme: scheme,
              progressColor: progressColor,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _MiniPlayerTopProgressLine(
              progress: progress,
              color: progressColor,
            ),
          ),
        ],
      );
    });
  }

  double _progressValue(Duration position, Duration duration) {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

class _MiniPlayerProgressFill extends StatelessWidget {
  const _MiniPlayerProgressFill({
    required this.progress,
    required this.scheme,
    required this.progressColor,
  });

  final double progress;
  final ColorScheme scheme;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0).toDouble();

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
            ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: safeProgress,
              heightFactor: 1,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.20),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniPlayerTopProgressLine extends StatelessWidget {
  const _MiniPlayerTopProgressLine({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0).toDouble();

    return SizedBox(
      height: 3,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: safeProgress,
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
