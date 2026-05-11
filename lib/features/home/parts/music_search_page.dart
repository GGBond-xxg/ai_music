part of '../home_page.dart';

class _MusicSearchPage extends StatefulWidget {
  const _MusicSearchPage({required this.tracks});

  final List<MusicTrack> tracks;

  @override
  State<_MusicSearchPage> createState() => _MusicSearchPageState();
}

class _MusicSearchPageState extends State<_MusicSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<MusicTrack> _results() {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return widget.tracks.take(40).toList();

    return widget.tracks.where((track) {
      final haystack = [
        track.title,
        track.artist ?? '',
        track.album ?? '',
        musicSourceLabel(track.sourceType),
      ].join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final player = Get.find<PlayerController>();
    final result = _results();

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'common.back'.tr,
                    onPressed: () => Get.back<void>(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'search.hint'.tr,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'common.clear'.tr,
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        fillColor: scheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(
                              color: scheme.primary.withValues(alpha: 0.38)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  Text(
                    _query.trim().isEmpty ? 'common.recentMusic'.tr : 'common.searchResult'.tr,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${result.length}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: result.isEmpty
                  ? Center(
                      child: Text(
                        'common.noSearchResult'.tr,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : ListView.builder(
                      cacheExtent:
                          _GramophoneLibraryViewState._trackItemExtent * 6,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemExtent: 72,
                      itemCount: result.length,
                      itemBuilder: (context, index) {
                        final track = result[index];
                        return Obx(() {
                          final current = player.currentTrack;
                          final isCurrent = current?.id == track.id;
                          final isPlaying =
                              isCurrent && player.isPlayingNow.value;

                          return _TrackTile(
                            key: ValueKey('search-track-${track.id}'),
                            track: track,
                            index: index,
                            isCurrent: isCurrent,
                            isPlaying: isPlaying,
                            enableNetworkCover: true,
                            onTap: () {
                              Get.back<void>();
                              player.setQueue(result, initialIndex: index);
                            },
                          );
                        });
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
