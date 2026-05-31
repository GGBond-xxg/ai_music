import 'package:flutter/material.dart';

import 'spotify_provider.dart';

class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._spotifyProvider) {
    _spotifyProvider.addListener(_syncFromSource);
    _syncFromSource();
  }

  final SpotifyProvider _spotifyProvider;

  List<Map<String, dynamic>> _items = [];
  bool _showLocal = true;
  bool _showRemote = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isFirstLoad = true;
  String? _errorMessage;
  String? _refreshWarningMessage;

  List<Map<String, dynamic>> get userPlaylists => _items;
  List<Map<String, dynamic>> get userSavedAlbums => _items;
  bool get showPlaylists => _showLocal;
  bool get showAlbums => _showRemote;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isFirstLoad => _isFirstLoad;
  String? get errorMessage => _errorMessage;
  String? get refreshWarningMessage => _refreshWarningMessage;
  bool get hasData => _items.isNotEmpty;

  List<Map<String, dynamic>> get filteredItems {
    return _items.where((item) {
      final sourceType = item['sourceType']?.toString();
      final isLocal = sourceType == 'localFile';
      if (isLocal && !_showLocal) return false;
      if (!isLocal && !_showRemote) return false;
      return true;
    }).toList(growable: false);
  }

  void _syncFromSource() {
    _items = _spotifyProvider.libraryItems;
    _isFirstLoad = false;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void setFilters({bool? showPlaylists, bool? showAlbums}) {
    var changed = false;
    if (showPlaylists != null && showPlaylists != _showLocal) {
      _showLocal = showPlaylists;
      changed = true;
    }
    if (showAlbums != null && showAlbums != _showRemote) {
      _showRemote = showAlbums;
      changed = true;
    }
    if (changed) notifyListeners();
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
