//nowplaying.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music/utils/responsive.dart';
import 'package:music/widgets/player.dart';
import 'package:music/widgets/lyrics.dart';
import 'package:music/services/ui_texts.dart';

class NowPlaying extends StatefulWidget {
  const NowPlaying({super.key});

  @override
  State<NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying> {
  bool _lyricsExpanded = false;

  void _toggleLyricsExpanded() {
    HapticFeedback.lightImpact();
    setState(() {
      _lyricsExpanded = !_lyricsExpanded;
    });
    lyricsCenterLineRequest.value++;
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen =
        context.layoutType(ResponsivePageType.shell).preferTwoPane;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, _) {
          final toggleRight = isLargeScreen ? 12.0 : 18.0;

          return Stack(
            children: [
              if (isLargeScreen)
                Row(
                  children: [
                    if (!_lyricsExpanded)
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Player(isLargeScreen: true),
                        ),
                      ),
                    Expanded(
                      flex: 1,
                      child: const _LyricsPane(),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      child: _lyricsExpanded
                          ? const SizedBox.shrink(
                              key: ValueKey('player_hidden'),
                            )
                          : const Player(
                              key: ValueKey('player_visible'),
                              isLargeScreen: false,
                            ),
                    ),
                    Expanded(
                      child: const _LyricsPane(),
                    ),
                  ],
                ),
              Positioned(
                right: toggleRight,
                bottom: 88 + MediaQuery.paddingOf(context).bottom,
                child: _LyricsToggleButton(
                  expanded: _lyricsExpanded,
                  onPressed: _toggleLyricsExpanded,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LyricsPane extends StatelessWidget {
  const _LyricsPane();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned.fill(child: LyricsWidget()),
      ],
    );
  }
}

class _LyricsToggleButton extends StatelessWidget {
  const _LyricsToggleButton({
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: expanded
          ? UiTexts.of(context).collapseLyrics
          : UiTexts.of(context).expandLyrics,
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(
          scheme.primaryContainer.withValues(alpha: 0.88),
        ),
        foregroundColor: WidgetStateProperty.all(scheme.onPrimaryContainer),
      ),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Icon(
          expanded
              ? Icons.keyboard_arrow_down_rounded
              : Icons.keyboard_arrow_up,
          key: ValueKey(expanded),
        ),
      ),
    );
  }
}
