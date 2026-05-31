import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'spotify_provider.dart';

class SearchProvider extends ChangeNotifier {
  SearchProvider(this._spotifyProvider);

  final SpotifyProvider _spotifyProvider;
  final Logger _logger = Logger();
  Timer? _debounceTimer;
  static const Duration _debounceTime = Duration(milliseconds: 300);

  String _searchQuery = '';
  Map<String, List<Map<String, dynamic>>> _searchResults = {};
  bool _isSearching = false;
  String? _errorMessage;
  int _searchRequestId = 0;

  String get searchQuery => _searchQuery;
  bool get isSearchActive => _searchQuery.trim().isNotEmpty;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> get filteredResults {
    final result = <Map<String, dynamic>>[];
    for (final key in const ['tracks', 'albums', 'playlists', 'artists']) {
      final values = _searchResults[key];
      if (values != null) result.addAll(values);
    }
    return result;
  }

  void updateSearchQuery(String query) {
    if (query == _searchQuery) return;
    _debounceTimer?.cancel();
    _searchQuery = query;
    _errorMessage = null;

    if (query.trim().isEmpty) {
      _searchResults = {};
      _isSearching = false;
      _searchRequestId++;
      notifyListeners();
      return;
    }

    final requestId = ++_searchRequestId;
    _debounceTimer = Timer(_debounceTime, () {
      performSearch(query, requestId: requestId);
    });
    notifyListeners();
  }

  void submitSearch(String query) {
    _debounceTimer?.cancel();
    _searchQuery = query;
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }
    final requestId = ++_searchRequestId;
    performSearch(query, requestId: requestId);
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    _searchQuery = '';
    _searchResults = {};
    _errorMessage = null;
    _isSearching = false;
    _searchRequestId++;
    notifyListeners();
  }

  Future<void> performSearch(String query, {int? requestId}) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;

    final activeRequestId = requestId ?? ++_searchRequestId;
    _isSearching = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _spotifyProvider.searchItems(normalized);
      if (!_isLatestRequest(activeRequestId, query)) return;
      _searchResults = results;
    } catch (e, s) {
      _logger.w('Local library search failed', error: e, stackTrace: s);
      if (!_isLatestRequest(activeRequestId, query)) return;
      _errorMessage = '搜索失败：$e';
    } finally {
      if (_isLatestRequest(activeRequestId, query)) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  bool _isLatestRequest(int requestId, String query) {
    return requestId == _searchRequestId && query == _searchQuery;
  }

  void playItem(Map<String, dynamic> item) {
    final uri = item['uri']?.toString();
    if (uri == null || uri.isEmpty) return;
    _spotifyProvider.playTrack(trackUri: uri);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
