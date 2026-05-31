import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/library_provider.dart';
import '../services/ui_texts.dart';
import '../utils/responsive.dart';
import 'library_grid.dart';
import 'materialui.dart' as custom_ui;

class LibrarySection extends StatefulWidget {
  final Function(Function() refreshCallback)? registerRefreshCallback;
  final Function(VoidCallback)? registerScrollToTopCallback;

  const LibrarySection({
    super.key,
    this.registerRefreshCallback,
    this.registerScrollToTopCallback,
  });

  @override
  State<LibrarySection> createState() => _LibrarySectionState();
}

enum _LibraryLayoutMode { grid, list }

class _LibrarySectionState extends State<LibrarySection> {
  static const _layoutModeKey = 'spotoolfy.library.layout_mode.v1';

  final ScrollController _scrollController = ScrollController();
  _LibraryLayoutMode _layoutMode = _LibraryLayoutMode.grid;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    widget.registerRefreshCallback?.call(_refreshData);
    widget.registerScrollToTopCallback?.call(_scrollToTop);

    _loadLayoutMode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final libraryProvider =
          Provider.of<LibraryProvider>(context, listen: false);
      if (libraryProvider.isFirstLoad && !libraryProvider.isLoading) {
        _refreshData();
      }
    });
  }

  Future<void> _loadLayoutMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_layoutModeKey);
    if (!mounted) return;
    setState(() {
      _layoutMode = value == _LibraryLayoutMode.list.name
          ? _LibraryLayoutMode.list
          : _LibraryLayoutMode.grid;
    });
  }

  Future<void> _setLayoutMode(_LibraryLayoutMode mode) async {
    if (_layoutMode == mode) return;
    HapticFeedback.lightImpact();
    setState(() => _layoutMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_layoutModeKey, mode.name);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      final libraryProvider =
          Provider.of<LibraryProvider>(context, listen: false);
      if (!libraryProvider.isLoading && !libraryProvider.isLoadingMore) {
        libraryProvider.loadMoreData();
      }
    }
  }

  Future<void> _refreshData() async {
    final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
    await libraryProvider.loadData();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleLibraryItemTap(BuildContext context, Map<String, dynamic> item) {
    Provider.of<LibraryProvider>(context, listen: false).playItem(item);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, libraryProvider, child) {
        final t = UiTexts.of(context);
        final browseLayout = context.layoutType(ResponsivePageType.browse);
        final gridCrossAxisCount = context.adaptiveColumns(
          minTileWidth: browseLayout.defaultMinTileWidth,
          min: 3,
          max: 6,
        );
        final horizontalPadding = browseLayout.horizontalPadding;

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  8,
                  horizontalPadding,
                  12,
                ),
                child: custom_ui.IconHeader(
                  icon: Icons.library_music_rounded,
                  text: t.myMusicLibrary,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_shouldShowSourceFilters(libraryProvider)) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            selected: libraryProvider.showPlaylists,
                            label: Text(t.localMusic),
                            onSelected: (bool selected) {
                              HapticFeedback.lightImpact();
                              libraryProvider.setFilters(showPlaylists: selected);
                            },
                          ),
                          FilterChip(
                            selected: libraryProvider.showAlbums,
                            label: Text(t.nasServer),
                            onSelected: (bool selected) {
                              HapticFeedback.lightImpact();
                              libraryProvider.setFilters(showAlbums: selected);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Text(
                          t.layoutMode,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(width: 12),
                        SegmentedButton<_LibraryLayoutMode>(
                          segments: [
                            ButtonSegment<_LibraryLayoutMode>(
                              value: _LibraryLayoutMode.grid,
                              icon: const Icon(Icons.grid_view_rounded),
                              label: Text(t.grid),
                            ),
                            ButtonSegment<_LibraryLayoutMode>(
                              value: _LibraryLayoutMode.list,
                              icon: const Icon(Icons.view_list_rounded),
                              label: Text(t.list),
                            ),
                          ],
                          selected: {_layoutMode},
                          onSelectionChanged: (selection) {
                            _setLayoutMode(selection.first);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              sliver: _buildContentSliver(
                context,
                libraryProvider,
                gridCrossAxisCount,
              ),
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowSourceFilters(LibraryProvider libraryProvider) {
    var hasLocal = false;
    var hasRemote = false;
    for (final item in libraryProvider.userPlaylists) {
      final sourceType = item['sourceType']?.toString();
      if (sourceType == 'localFile') {
        hasLocal = true;
      } else {
        hasRemote = true;
      }
      if (hasLocal && hasRemote) return true;
    }
    return false;
  }

  Widget _buildContentSliver(
    BuildContext context,
    LibraryProvider libraryProvider,
    int gridCrossAxisCount,
  ) {
    final hasItems = libraryProvider.filteredItems.isNotEmpty;
    if (libraryProvider.isLoading && libraryProvider.isFirstLoad && !hasItems) {
      return LibraryGridSkeleton(gridCrossAxisCount: gridCrossAxisCount);
    }

    final hasFatalError =
        !libraryProvider.hasData && libraryProvider.errorMessage != null;
    if (hasFatalError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  UiTexts.of(context).libraryLoadFailed,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  libraryProvider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _refreshData,
                  child: Text(UiTexts.of(context).retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final warningMessage = libraryProvider.refreshWarningMessage ??
        (libraryProvider.hasData ? libraryProvider.errorMessage : null);

    return SliverMainAxisGroup(
      slivers: [
        if (warningMessage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildWarningBanner(context, warningMessage),
            ),
          ),
        if (!hasItems && !libraryProvider.isLoading)
          _buildEmptyState(context)
        else
          _layoutMode == _LibraryLayoutMode.grid
              ? LibraryGrid(
                  items: libraryProvider.filteredItems,
                  gridCrossAxisCount: gridCrossAxisCount,
                  onItemTap: (item) => _handleLibraryItemTap(context, item),
                )
              : LibraryList(
                  items: libraryProvider.filteredItems,
                  onItemTap: (item) => _handleLibraryItemTap(context, item),
                ),
        if (libraryProvider.isLoading && !libraryProvider.isFirstLoad)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (libraryProvider.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.source_rounded,
                size: 56,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                UiTexts.of(context).noMusicYet,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                UiTexts.of(context).importFromSourcesHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningBanner(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
