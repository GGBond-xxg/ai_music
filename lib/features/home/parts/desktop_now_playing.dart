part of '../home_page.dart';

class _DesktopNowPlayingPanel extends StatelessWidget {
  const _DesktopNowPlayingPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final player = Get.find<PlayerController>();
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final track = player.currentTrack;
      return Container(
        width: compact ? null : 340,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: compact ? 0.78 : 0.68),
          border: compact
              ? null
              : Border(
                  left: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.52),
                  ),
                ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 24,
            compact ? 18 : 28,
            compact ? 18 : 24,
            compact ? 18 : 28,
          ),
          child: track == null
              ? _NoDesktopTrack(compact: compact)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'home.playingNow'.tr,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    SizedBox(height: compact ? 16 : 24),
                    Center(
                      child: TrackCover(
                        track: track,
                        size: compact ? 180 : 220,
                        borderRadius: compact ? 22 : 28,
                        iconSize: compact ? 76 : 92,
                      ),
                    ),
                    SizedBox(height: compact ? 18 : 26),
                    Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      track.artist ?? 'common.unknownArtist'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(child: _SourcePill(type: track.sourceType)),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _DesktopLyricPreview(track: track),
                    ),
                  ],
                ),
        ),
      );
    });
  }
}

class _NoDesktopTrack extends StatelessWidget {
  const _NoDesktopTrack({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.album_outlined,
            size: compact ? 72 : 92,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.55)),
        const SizedBox(height: 18),
        Text(
          'home.chooseSong'.tr,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'home.pcHint'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DesktopLyricPreview extends StatelessWidget {
  const _DesktopLyricPreview({required this.track});
  final MusicTrack track;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = parsePlainLyrics(track.lyricText);
    if (lines.isEmpty) {
      return Center(
        child: Text(
          'common.noLyrics'.tr,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(22),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: ScrollConfiguration(
          behavior: const _FreshDesktopScrollBehavior(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            itemCount: lines.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  lines[index],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: index == 0
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                    fontWeight: index == 0 ? FontWeight.w900 : FontWeight.w700,
                    height: 1.34,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FreshDesktopScrollBehavior extends ScrollBehavior {
  const _FreshDesktopScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: false,
      child: child,
    );
  }
}
