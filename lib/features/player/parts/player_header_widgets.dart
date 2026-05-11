part of '../player_page.dart';

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.onTap,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onVerticalDragCancel,
  });

  final VoidCallback onTap;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final GestureDragCancelCallback onVerticalDragCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top;
    final landscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final barHeight = top + (landscape ? 30 : 42);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onVerticalDragStart: onVerticalDragStart,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      onVerticalDragCancel: onVerticalDragCancel,
      child: SizedBox(
        height: barHeight,
        width: double.infinity,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: landscape ? 8 : 10),
            child: Container(
              width: 88,
              height: 5,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerCommonHeader extends StatelessWidget {
  const _PlayerCommonHeader({
    required this.track,
    required this.controller,
    required this.showLyricAlign,
  });

  final MusicTrack track;
  final PlayerController controller;
  final bool showLyricAlign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isLandscape ? 24 : 30,
        isLandscape ? 0 : 0,
        isLandscape ? 24 : 30,
        isLandscape ? 12 : 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: isLandscape ? 22 : 28,
                        height: 1.08,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  track.artist ?? 'Unknown Artist',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                ),
              ],
            ),
          ),
          // 右上角区域固定宽高，避免从播放页滑到歌词页时，
          // “靠左/居中/靠右”按钮出现后把标题区域顶一下。
          SizedBox(
            width: isLandscape ? 112 : 118,
            height: 38,
            child: Align(
              alignment: Alignment.topRight,
              child: showLyricAlign
                  ? _LyricAlignChip(controller: controller)
                  : _MusicSourceChip(track: track),
            ),
          ),
        ],
      ),
    );
  }
}
