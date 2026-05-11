import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class CopyLinkItem {
  const CopyLinkItem({
    required this.label,
    required this.url,
  });

  final String label;
  final String url;
}

class CopyLinkList extends StatelessWidget {
  const CopyLinkList({
    super.key,
    required this.links,
    this.spacing = 8,
    this.copyText,
    this.copiedTitle,
    this.cardColor,
    this.borderColor,
    this.textColor,
    this.mutedColor,
    this.accentColor,
  });

  final List<CopyLinkItem> links;
  final double spacing;

  final String? copyText;
  final String? copiedTitle;

  final Color? cardColor;
  final Color? borderColor;
  final Color? textColor;
  final Color? mutedColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in links) ...[
          CopyLinkTile(
            item: item,
            copyText: copyText,
            copiedTitle: copiedTitle,
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
            mutedColor: mutedColor,
            accentColor: accentColor,
          ),
          if (item != links.last) SizedBox(height: spacing),
        ],
      ],
    );
  }
}

class CopyLinkTile extends StatelessWidget {
  const CopyLinkTile({
    super.key,
    required this.item,
    this.copyText,
    this.copiedTitle,
    this.cardColor,
    this.borderColor,
    this.textColor,
    this.mutedColor,
    this.accentColor,
  });

  final CopyLinkItem item;

  final String? copyText;
  final String? copiedTitle;

  final Color? cardColor;
  final Color? borderColor;
  final Color? textColor;
  final Color? mutedColor;
  final Color? accentColor;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: item.url));

    if (!context.mounted) return;

    Get.snackbar(
      copiedTitle ?? 'about.copied'.tr,
      item.url,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(milliseconds: 1400),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final safeCardColor =
        cardColor ?? scheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final safeBorderColor =
        borderColor ?? scheme.outlineVariant.withValues(alpha: 0.45);
    final safeTextColor = textColor ?? scheme.onSurface;
    final safeMutedColor = mutedColor ?? scheme.onSurfaceVariant;
    final safeAccentColor = accentColor ?? scheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: safeCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: safeBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.link_rounded,
              size: 18,
              color: safeAccentColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: safeTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: safeMutedColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(copyText ?? 'about.copy'.tr),
              style: TextButton.styleFrom(
                foregroundColor: safeAccentColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
