import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/responsive.dart';
import '../services/ui_texts.dart';
import 'music_sources_page.dart';

const double kDefaultPadding = 16.0;
const double kSectionSpacing = 24.0;
const double kElementSpacing = 16.0;
const double kSmallSpacing = 8.0;

/// Settings modal preserved from Music's shell. Spotify login/API settings
/// were removed; source management is now handled here and in the third tab.
class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: ResponsivePadding.horizontal(
        context,
        pageType: ResponsivePageType.modal,
      ),
      width: double.infinity,
      child: SafeArea(
        child: ResponsivePageContainer(
          pageType: ResponsivePageType.modal,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: kDefaultPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: kSmallSpacing),
                      child: Text(
                        UiTexts.of(context).settings,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.primary.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: UiTexts.of(context).close,
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kElementSpacing),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: const MusicSourcesPage(showHeader: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
