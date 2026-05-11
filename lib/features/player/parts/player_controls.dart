part of '../player_page.dart';

enum _ControlsLayout {
  portrait,
  landscape,
}

class _Controls extends StatefulWidget {
  const _Controls({
    required this.controller,
    this.layout = _ControlsLayout.portrait,
  });

  final PlayerController controller;
  final _ControlsLayout layout;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  Duration? _dragPosition;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  IconData _modeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequence:
        return Icons.format_list_numbered_rounded;
      case PlayMode.shuffle:
        return Icons.shuffle_rounded;
      case PlayMode.repeatAll:
        return Icons.repeat_rounded;
      case PlayMode.repeatOne:
        return Icons.repeat_one_rounded;
    }
  }

  Future<void> _openSleepTimerSheet(BuildContext context) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (_) => _SleepTimerSheet(controller: widget.controller),
    );
  }

  Widget _buildProgressBar(
    BuildContext context, {
    required double verticalPadding,
    required double horizontalPadding,
  }) {
    final controller = widget.controller;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      // 这里控制整体左右边距，想更长就改小，比如 8 / 10 / 12
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
      child: StreamBuilder<Duration?>(
        stream: controller.player.durationStream,
        builder: (context, durationSnapshot) {
          final duration = durationSnapshot.data ?? Duration.zero;

          return StreamBuilder<Duration>(
            stream: controller.player.positionStream,
            builder: (context, positionSnapshot) {
              final rawPosition = positionSnapshot.data ?? Duration.zero;

              return Obx(() {
                final preview = controller.seekPreviewPosition.value;
                final effectivePosition = _dragPosition ??
                    (controller.isUserSeeking.value ? preview : null) ??
                    rawPosition;

                final safePosition = duration == Duration.zero
                    ? Duration.zero
                    : (effectivePosition > duration
                        ? duration
                        : effectivePosition);

                final maxMs = duration.inMilliseconds <= 0
                    ? 1.0
                    : duration.inMilliseconds.toDouble();

                final value = duration.inMilliseconds <= 0
                    ? 0.0
                    : safePosition.inMilliseconds
                        .clamp(0, duration.inMilliseconds)
                        .toDouble();

                final progress = (value / maxMs).clamp(0.0, 1.0).toDouble();

                Duration positionFromDx(double dx, double width) {
                  final ratio = (dx / width).clamp(0.0, 1.0);
                  return Duration(milliseconds: (ratio * maxMs).round());
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final barWidth = constraints.maxWidth;
                        const barHeight = 3.2;
                        const touchHeight = 28.0;

                        return GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapDown: (details) {
                            final pos = positionFromDx(
                              details.localPosition.dx,
                              barWidth,
                            );
                            unawaited(controller.commitSeek(pos));
                          },
                          onHorizontalDragStart: (details) {
                            final pos = positionFromDx(
                              details.localPosition.dx,
                              barWidth,
                            );
                            setState(() => _dragPosition = pos);
                            controller.beginSeek(pos);
                          },
                          onHorizontalDragUpdate: (details) {
                            final pos = positionFromDx(
                              details.localPosition.dx,
                              barWidth,
                            );
                            setState(() => _dragPosition = pos);
                            controller.previewSeek(pos);
                          },
                          onHorizontalDragEnd: (_) {
                            final pos = _dragPosition;
                            setState(() => _dragPosition = null);
                            if (pos != null) {
                              unawaited(controller.commitSeek(pos));
                            }
                          },
                          onHorizontalDragCancel: () {
                            setState(() => _dragPosition = null);
                          },
                          child: SizedBox(
                            width: double.infinity,
                            height: touchHeight,
                            child: Align(
                              alignment: Alignment.center,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: scheme.outline
                                          .withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: progress,
                                    child: Container(
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(safePosition),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              });
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactWidth = constraints.maxWidth < 360;
        final isLandscapeControls = widget.layout == _ControlsLayout.landscape;

        final sideIconSize = isLandscapeControls
            ? (compactWidth ? 24.0 : 26.0)
            : (compactWidth ? 24.0 : 27.0);

        final skipIconSize = isLandscapeControls
            ? (compactWidth ? 24.0 : 27.0)
            : (compactWidth ? 31.0 : 35.0);

        final playIconSize = isLandscapeControls
            ? (compactWidth ? 40.0 : 39.0)
            : (compactWidth ? 48.0 : 54.0);

        final progressPadding = isLandscapeControls
            ? (compactWidth ? 0.0 : 4.0)
            : (compactWidth ? 22.0 : 30.0);

        final buttonsPadding =
            isLandscapeControls ? 0.0 : (compactWidth ? 18.0 : 28.0);

        final controlGap = isLandscapeControls
            ? (compactWidth ? 8.0 : 13.0)
            : (compactWidth ? 12.0 : 16.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProgressBar(
              context,
              verticalPadding: controlGap,
              horizontalPadding: progressPadding,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: buttonsPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  isLandscapeControls
                      ? const SizedBox.shrink()
                      : Obx(() {
                          return _PlayerControlIconButton(
                            tooltip: controller.playMode.value.label,
                            icon: _modeIcon(controller.playMode.value),
                            iconSize: sideIconSize,
                            color: scheme.primary,
                            onPressed: controller.cyclePlayMode,
                          );
                        }),
                  _PlayerControlIconButton(
                    tooltip: 'common.previous'.tr,
                    icon: Icons.skip_previous_rounded,
                    iconSize: skipIconSize,
                    color: scheme.primary,
                    onPressed: controller.previous,
                  ),
                  Obx(() {
                    final playing = controller.isPlayingNow.value;
                    return _PlayerControlIconButton(
                      tooltip: playing ? 'common.pause'.tr : 'common.play'.tr,
                      icon: playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      iconSize: playIconSize,
                      color: scheme.primary,
                      onPressed: controller.togglePlay,
                    );
                  }),
                  _PlayerControlIconButton(
                    tooltip: 'common.next'.tr,
                    icon: Icons.skip_next_rounded,
                    iconSize: skipIconSize,
                    color: scheme.primary,
                    onPressed: controller.next,
                  ),
                  isLandscapeControls
                      ? const SizedBox.shrink()
                      : Obx(() {
                          final active =
                              controller.sleepTimerRemaining.value != null;
                          return _PlayerControlIconButton(
                            tooltip: active
                                ? 'player.timerWithLabel'.trParams(
                                    {'label': controller.sleepTimerLabel})
                                : 'player.timerLabel'.tr,
                            icon: active
                                ? Icons.timer_rounded
                                : Icons.timer_outlined,
                            iconSize: sideIconSize,
                            color: scheme.primary,
                            onPressed: () => _openSleepTimerSheet(context),
                          );
                        }),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                isLandscapeControls
                    ? Obx(() {
                        return _PlayerControlIconButton(
                          tooltip: controller.playMode.value.label,
                          icon: _modeIcon(controller.playMode.value),
                          iconSize: sideIconSize,
                          color: scheme.primary,
                          onPressed: controller.cyclePlayMode,
                        );
                      })
                    : const SizedBox.shrink(),
                isLandscapeControls
                    ? Obx(() {
                        final active =
                            controller.sleepTimerRemaining.value != null;
                        return _PlayerControlIconButton(
                          tooltip: active
                              ? 'player.timerWithLabel'.trParams(
                                  {'label': controller.sleepTimerLabel})
                              : 'player.timerLabel'.tr,
                          icon: active
                              ? Icons.timer_rounded
                              : Icons.timer_outlined,
                          iconSize: sideIconSize,
                          color: scheme.primary,
                          onPressed: () => _openSleepTimerSheet(context),
                        );
                      })
                    : const SizedBox.shrink(),
              ],
            ),
            // SizedBox(height: isLandscapeControls ? 58 : 0),
          ],
        );
      },
    );
  }
}

class _PlayerControlIconButton extends StatelessWidget {
  const _PlayerControlIconButton({
    required this.tooltip,
    required this.icon,
    required this.iconSize,
    required this.color,
    required this.onPressed, // 将方括号改为花括号
  });

  final String tooltip;
  final IconData icon;
  final double iconSize;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      iconSize: iconSize,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: BoxConstraints.tightFor(
        width: math.max(iconSize + 10, 34).toDouble(),
        height: math.max(iconSize + 10, 34).toDouble(),
      ),
      onPressed: onPressed,
      color: color,
      icon: Icon(
        icon,
      ),
    );
  }
}

class _SleepTimerSheet extends StatefulWidget {
  const _SleepTimerSheet({required this.controller});

  final PlayerController controller;

  @override
  State<_SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<_SleepTimerSheet> {
  late final TextEditingController _minutesController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _minutesController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _startTimer(int minutes) {
    if (minutes <= 0) return;
    widget.controller.startSleepTimer(Duration(minutes: minutes));
    Navigator.of(context).maybePop();
  }

  void _startCustomTimer() {
    final raw = _minutesController.text.trim();
    final minutes = int.tryParse(raw);
    if (minutes == null || minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('player.invalidMinutes'.tr)),
      );
      return;
    }
    _startTimer(minutes.clamp(1, 24 * 60).toInt());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final presets = const [5, 10, 15, 30];

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'player.sleepTimer'.tr,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Obx(() {
                  final remaining = widget.controller.sleepTimerRemaining.value;
                  return Text(
                    remaining == null
                        ? 'player.sleepTimerDesc'.tr
                        : 'player.currentRemaining'.trParams(
                            {'label': widget.controller.sleepTimerLabel}),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final minutes in presets)
                      FilledButton.tonal(
                        onPressed: () => _startTimer(minutes),
                        child: Text(
                            'player.minutes'.trParams({'minutes': '$minutes'})),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minutesController,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _startCustomTimer(),
                        decoration: InputDecoration(
                          labelText: 'player.customMinutes'.tr,
                          hintText: 'player.customMinutesHint'.tr,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _startCustomTimer,
                      child: Text('player.start'.tr),
                    ),
                  ],
                ),
                Obx(() {
                  if (widget.controller.sleepTimerRemaining.value == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          widget.controller.cancelSleepTimer();
                          Navigator.of(context).maybePop();
                        },
                        child: Text('player.cancelCurrentTimer'.tr),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
