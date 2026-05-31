import 'package:flutter/material.dart';

import '../models/music_track.dart';
import 'spotify_provider.dart';

class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._spotifyProvider) {
    _spotifyProvider.addListener(_syncFromSource);
    _syncFromSource();
  }

  final SpotifyProvider _spotifyProvider;

  List<Map<String, dynamic>> _items = [];
  final Set<MusicSourceType> _enabledSourceTypes = <MusicSourceType>{};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isFirstLoad = true;
  String? _errorMessage;
  String? _refreshWarningMessage;

  List<Map<String, dynamic>> get userPlaylists => _items;
  List<Map<String, dynamic>> get userSavedAlbums => _items;
  List<MusicSourceType> get availableSourceTypes {
    final types = <MusicSourceType>{};
    for (final item in _items) {
      final sourceName = item['sourceType']?.toString();
      final type = _sourceTypeFromName(sourceName);
      if (type != null) types.add(type);
    }
    final sorted = types.toList(growable: false)..sort((a, b) => a.index.compareTo(b.index));
    return sorted;
  }

  bool isSourceFilterEnabled(MusicSourceType type) {
    _ensureEnabledSources();
    return _enabledSourceTypes.contains(type);
  }
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isFirstLoad => _isFirstLoad;
  String? get errorMessage => _errorMessage;
  String? get refreshWarningMessage => _refreshWarningMessage;
  bool get hasData => _items.isNotEmpty;

  List<Map<String, dynamic>> get filteredItems {
    _ensureEnabledSources();
    if (availableSourceTypes.length <= 1) return List.unmodifiable(_items);
    return _items.where((item) {
      final sourceName = item['sourceType']?.toString();
      final type = _sourceTypeFromName(sourceName);
      if (type == null) return true;
      return _enabledSourceTypes.contains(type);
    }).toList(growable: false);
  }


  MusicSourceType? _sourceTypeFromName(String? sourceName) {
    if (sourceName == null) return null;
    for (final type in MusicSourceType.values) {
      if (type.name == sourceName) return type;
    }
    return null;
  }

  void _syncFromSource() {
    _items = _spotifyProvider.libraryItems;
    _ensureEnabledSources();
    _isFirstLoad = false;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void _ensureEnabledSources() {
    final types = availableSourceTypes;
    if (types.isEmpty) {
      _enabledSourceTypes.clear();
      return;
    }
    final typeSet = types.toSet();
    _enabledSourceTypes.removeWhere((type) => !typeSet.contains(type));
    if (_enabledSourceTypes.isEmpty) {
      _enabledSourceTypes.addAll(types);
    }
  }

  void setSourceFilter(MusicSourceType type, bool enabled) {
    _ensureEnabledSources();
    if (enabled) {
      _enabledSourceTypes.add(type);
    } else {
      _enabledSourceTypes.remove(type);
      if (_enabledSourceTypes.isEmpty) {
        _enabledSourceTypes.add(type);
      }
    }
    notifyListeners();
  }

  Future<void> loadData({bool forceRefresh = false}) async {
    _isLoading = true;
    notifyListeners();
    _syncFromSource();
  }

  Future<void> clearCache() async {
    await _spotifyProvider.clearLocalLibrary();
    _syncFromSource();
  }

  Future<void> handleTokenExpiration() async {}
  Future<bool> hasFallbackCache() async => hasData;
  Future<void> loadMoreData() async {
    _isLoadingMore = false;
  }

  void handleAuthStateChange(bool isAuthenticated) {
    _syncFromSource();
  }

  void playItem(Map<String, dynamic> item) {
    final uri = item['uri']?.toString();
    if (uri != null && uri.isNotEmpty) {
      _spotifyProvider.playTrack(trackUri: uri);
    }
  }

  @override
  void dispose() {
    _spotifyProvider.removeListener(_syncFromSource);
    super.dispose();
  }
}
