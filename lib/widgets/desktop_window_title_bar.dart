import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowTitleBar extends StatefulWidget {
  const DesktopWindowTitleBar({
    super.key,
    this.height = 38,
  });

  final double height;

  @override
  State<DesktopWindowTitleBar> createState() => _DesktopWindowTitleBarState();
}

class _DesktopWindowTitleBarState extends State<DesktopWindowTitleBar>
    with WindowListener {
  bool _maximized = false;

  bool get _isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      _syncMaximized();
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _syncMaximized() async {
    final value = await windowManager.isMaximized();
    if (!mounted) return;
    setState(() => _maximized = value);
  }

  @override
  void onWindowMaximize() => _syncMaximized();

  @override
  void onWindowUnmaximize() => _syncMaximized();

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final subtle = scheme.onSurface.withValues(alpha: 0.62);

    return SizedBox(
      height: widget.height,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Container(
                height: widget.height,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 10),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: scheme.secondary.withValues(alpha: 0.42),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _WindowButton(
            tooltip: 'Minimize',
            icon: Icons.remove_rounded,
            color: subtle,
            onPressed: () {
              windowManager.minimize();
            },
          ),
          _WindowButton(
            tooltip: _maximized ? 'Restore' : 'Maximize',
            icon: _maximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            color: subtle,
            onPressed: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
              await _syncMaximized();
            },
          ),
          _WindowButton(
            tooltip: 'Close',
            icon: Icons.close_rounded,
            color: subtle,
            hoverColor: Colors.red.withValues(alpha: 0.16),
            hoverForeground: Colors.redAccent,
            onPressed: () {
              windowManager.close();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.hoverColor,
    this.hoverForeground,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final Color? hoverColor;
  final Color? hoverForeground;
  final VoidCallback onPressed;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 42,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.hoverColor ??
                      scheme.surfaceContainerHighest.withValues(alpha: 0.45)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              widget.icon,
              size: 17,
              color: _hovered
                  ? widget.hoverForeground ?? scheme.onSurface
                  : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
