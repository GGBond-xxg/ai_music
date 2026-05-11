import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../widgets/copy_link_tile.dart';

Future<void> showFreshAboutSheet(BuildContext context) async {
  final theme = Theme.of(context);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'common.close'.tr,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Theme(
        data: theme,
        child: const AboutPage(),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.18),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = _AboutPalette.fromScheme(scheme);
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 860;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: isWide ? Alignment.center : const Alignment(0, -0.22),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isWide ? 32 : 12,
              isWide ? 20 : 14,
              isWide ? 32 : 12,
              isWide ? 20 : 14,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 820 : size.width - 24,
                maxHeight: size.height * (isWide ? 0.74 : 0.82),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(isWide ? 34 : 28),
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 42,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isWide ? 34 : 28),
                  child: Column(
                    children: [
                      _AboutHeader(palette: palette),
                      Expanded(
                        child: isWide
                            ? Row(
                                children: [
                                  SizedBox(
                                    width: 350,
                                    child: _AboutHeroPane(palette: palette),
                                  ),
                                  VerticalDivider(
                                      width: 1, color: palette.border),
                                  Expanded(
                                      child:
                                          _AboutContentPane(palette: palette)),
                                ],
                              )
                            : ListView(
                                padding: EdgeInsets.zero,
                                children: [
                                  _AboutHeroPane(
                                      palette: palette, compact: true),
                                  _AboutContentPane(
                                      palette: palette, compact: true),
                                ],
                              ),
                      ),
                      _AboutBottomActions(palette: palette),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader({required this.palette});

  final _AboutPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.fromLTRB(22, 8, 14, 8),
      decoration: BoxDecoration(
        color: palette.header,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: palette.accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'about.title'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: 'common.close'.tr,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.close_rounded, color: palette.text),
          ),
        ],
      ),
    );
  }
}

class _AboutHeroPane extends StatelessWidget {
  const _AboutHeroPane({required this.palette, this.compact = false});

  final _AboutPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(28, compact ? 22 : 34, 28, compact ? 12 : 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Text(
            'Fresh Music',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: palette.text,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'about.sheetHint'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.muted,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _AboutChip(text: 'ChatGPT', palette: palette),
              _AboutChip(text: 'Flutter', palette: palette),
              _AboutChip(text: 'Media_kit', palette: palette),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutContentPane extends StatelessWidget {
  const _AboutContentPane({required this.palette, this.compact = false});

  final _AboutPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sections = <_AboutItemData>[
      _AboutItemData(
        icon: Icons.auto_awesome_rounded,
        title: 'about.aiTitle'.tr,
        body: 'about.aiBody'.tr,
        highlight: true,
      ),
      _AboutItemData(
        icon: Icons.favorite_rounded,
        title: 'about.thanksTitle'.tr,
        body: 'about.thanksBody'.tr,
      ),
      _AboutItemData(
        icon: Icons.hub_rounded,
        title: 'about.openTitle'.tr,
        body: 'about.openBody'.tr,
        links: [
          CopyLinkItem(
            label: 'about.getxSite'.tr,
            url: 'https://pub.dev/packages/get',
          ),
          CopyLinkItem(
            label: 'about.mediaKitSite'.tr,
            url: 'https://pub.dev/packages/media_kit',
          ),
          CopyLinkItem(
            label: 'about.chatgptSite'.tr,
            url: 'https://chatgpt.com/',
          ),
          CopyLinkItem(
            label: 'about.flutterSite'.tr,
            url: 'https://flutter.dev/',
          ),
        ],
      ),
      _AboutItemData(
          icon: Icons.money,
          title: 'about.supportTitle'.tr,
          body: 'about.supportBody'.tr,
          links: [
            CopyLinkItem(
                label: 'TRC20', url: 'TXnGST3Qa1qGeFGcEivbdwtUBrWgNKeHdz'),
            CopyLinkItem(
                label: 'ERC20',
                url: '0x3732e8155cEd9Bd9C89a5bb8b197DC063570952B'),
            CopyLinkItem(
                label: 'Bitcoin',
                url: 'bc1q3v73dxmd805t0x4nkr4mswhvrk4ragt7e0f5g5'),
            CopyLinkItem(
                label: 'Solana',
                url: '4YB3SxN4j7ADm6ZxdCXbrsQq5HJbCewwBTYXN2rEXGYp'),
            CopyLinkItem(
                label: 'Ton',
                url: 'UQDJHJKPZYHCOo24UnlJc_lcnnsFjfDT30r8rnVNhi4_yL6R'),
          ]),
    ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'common.about'.tr,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.35,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'about.summary'.tr,
          style: TextStyle(
            color: palette.muted,
            height: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < sections.length; i++) ...[
          _AboutLyricStyleCard(
              index: i + 1, data: sections[i], palette: palette),
          if (i != sections.length - 1) const SizedBox(height: 14),
        ],
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
        child: content,
      );
    }

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(34, 34, 34, 30),
      child: content,
    );
  }
}

class _AboutBottomActions extends StatelessWidget {
  const _AboutBottomActions({required this.palette});

  final _AboutPalette palette;

  @override
  Widget build(BuildContext context) {
    final app = Get.find<AppController>();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: palette.header,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          // Expanded(
          //   child: OutlinedButton(
          //     onPressed: () => Navigator.of(context).maybePop(),
          //     style: OutlinedButton.styleFrom(
          //       foregroundColor: palette.text,
          //       side: BorderSide(color: palette.border),
          //       padding: const EdgeInsets.symmetric(vertical: 14),
          //     ),
          //     child: Text('about.closeOnly'.tr),
          //   ),
          // ),
          // const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () async {
                await app.hideAboutPermanently();
                if (context.mounted) {
                  Navigator.of(context).maybePop();
                  Get.snackbar('common.done'.tr, 'about.hiddenTip'.tr,
                      snackPosition: SnackPosition.TOP);
                }
              },
              icon: const Icon(Icons.visibility_off_rounded),
              label: Text('about.hideButton'.tr),
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: palette.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutItemData {
  const _AboutItemData({
    required this.icon,
    required this.title,
    required this.body,
    this.highlight = false,
    this.links = const <CopyLinkItem>[],
  });

  final IconData icon;
  final String title;
  final String body;
  final bool highlight;
  final List<CopyLinkItem> links;
}

class _AboutLyricStyleCard extends StatelessWidget {
  const _AboutLyricStyleCard({
    required this.index,
    required this.data,
    required this.palette,
  });

  final int index;
  final _AboutItemData data;
  final _AboutPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = data.highlight ? palette.accent : palette.text;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: data.highlight
            ? palette.accent.withValues(alpha: 0.12)
            : palette.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: data.highlight
              ? palette.accent.withValues(alpha: 0.30)
              : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(data.icon, color: color, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: TextStyle(
                        color: color,
                        fontSize: data.highlight ? 20 : 17,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.body,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 14,
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: palette.muted.withValues(alpha: 0.45),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (data.links.isNotEmpty) ...[
            const SizedBox(height: 16),
            CopyLinkList(
              links: data.links,
              copyText: 'about.copy'.tr,
              copiedTitle: 'about.copied'.tr,
              cardColor: palette.background.withValues(alpha: 0.40),
              borderColor: palette.border,
              textColor: palette.text,
              mutedColor: palette.muted,
              accentColor: palette.accent,
            ),
          ],
        ],
      ),
    );
  }
}

class _AboutChip extends StatelessWidget {
  const _AboutChip({required this.text, required this.palette});

  final String text;
  final _AboutPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: palette.text,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AboutPalette {
  const _AboutPalette({
    required this.background,
    required this.header,
    required this.card,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.border,
  });

  final Color background;
  final Color header;
  final Color card;
  final Color text;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color border;

  factory _AboutPalette.fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final background = isDark
        ? Color.lerp(scheme.surface, scheme.primary, 0.10)!
        : Color.lerp(scheme.surface, scheme.primaryContainer, 0.20)!;
    final header = isDark
        ? Color.lerp(background, Colors.white, 0.04)!
        : Color.lerp(background, Colors.white, 0.40)!;
    final card = isDark
        ? Color.lerp(background, Colors.white, 0.08)!
        : Color.lerp(background, Colors.white, 0.62)!;
    return _AboutPalette(
      background: background,
      header: header,
      card: card,
      text: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      accent: scheme.primary,
      onAccent: scheme.onPrimary,
      border: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.65),
    );
  }
}
