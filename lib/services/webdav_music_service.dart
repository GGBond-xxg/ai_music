import 'package:webdav_client/webdav_client.dart' as webdav;

import '../models/music_track.dart';

class WebDavMusicService {
  static const audioExts = [
    '.mp3',
    '.flac',
    '.m4a',
    '.m4b',
    '.wav',
    '.ogg',
    '.opus',
    '.aac',
    '.wma',
    '.ape',
    '.aiff',
    '.aif',
    '.alac',
    '.mka',
    '.mpga',
    '.mpeg',
    '.amr',
  ];

  Future<List<MusicTrack>> listAudio({
    required String baseUrl,
    required String username,
    required String password,
    String path = '/',
    bool recursive = true,
    int maxDepth = 12,
    int maxFiles = 10000,
  }) async {
    final rootUrl = _normalizeBaseUrl(baseUrl);
    final rootPath = _normalizeRemotePath(path);

    final client = webdav.newClient(
      rootUrl,
      user: username.trim(),
      password: password,
      debug: false,
    );
    client.setHeaders({'accept-charset': 'utf-8'});
    client.setConnectTimeout(15000);
    client.setSendTimeout(15000);
    client.setReceiveTimeout(30000);

    final tracks = <MusicTrack>[];
    final visited = <String>{};

    await _scanDirectory(
      client: client,
      baseUrl: rootUrl,
      username: username.trim(),
      password: password,
      currentPath: rootPath,
      depth: 0,
      recursive: recursive,
      maxDepth: maxDepth,
      maxFiles: maxFiles,
      visited: visited,
      tracks: tracks,
    );

    tracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return tracks;
  }

  Future<void> _scanDirectory({
    required webdav.Client client,
    required String baseUrl,
    required String username,
    required String password,
    required String currentPath,
    required int depth,
    required bool recursive,
    required int maxDepth,
    required int maxFiles,
    required Set<String> visited,
    required List<MusicTrack> tracks,
  }) async {
    if (depth > maxDepth || tracks.length >= maxFiles) return;

    final normalizedCurrent = _normalizeRemotePath(currentPath);
    if (!visited.add(normalizedCurrent)) return;

    final entries = await client.readDir(normalizedCurrent);

    for (final entry in entries) {
      if (tracks.length >= maxFiles) return;

      final name = (entry.name ?? '').trim();
      if (name.isEmpty || name == '.' || name == '..') continue;

      final entryPath = _entryRemotePath(
        currentPath: normalizedCurrent,
        entryPath: entry.path,
        name: name,
      );

      // Some WebDAV servers include the current directory itself in PROPFIND results.
      if (_normalizeRemotePath(entryPath) == normalizedCurrent) continue;

      if (entry.isDir == true) {
        if (recursive) {
          await _scanDirectory(
            client: client,
            baseUrl: baseUrl,
            username: username,
            password: password,
            currentPath: entryPath,
            depth: depth + 1,
            recursive: recursive,
            maxDepth: maxDepth,
            maxFiles: maxFiles,
            visited: visited,
            tracks: tracks,
          );
        }
        continue;
      }

      if (!_isAudio(name) && !_isAudio(entryPath)) continue;

      final playbackUrl = _buildPlaybackUrl(
        baseUrl: baseUrl,
        remotePath: entryPath,
        username: username,
        password: password,
      );
      final title = _titleFromName(name);

      tracks.add(
        MusicTrack(
          id: 'webdav:${_normalizeForId(playbackUrl)}',
          title: title,
          uri: playbackUrl,
          sourceType: MusicSourceType.webDav,
          artist: 'NAS / WebDAV',
          album: _folderNameOf(entryPath),
        ),
      );
    }
  }

  String _normalizeBaseUrl(String value) {
    var raw = value.trim();
    if (raw.isEmpty) throw Exception('请输入 WebDAV / NAS 地址。');
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'http://$raw';
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) {
      throw Exception('WebDAV 地址格式不正确，请填写类似 http://192.168.1.10:5244/dav 的地址。');
    }
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

  String _normalizeRemotePath(String path) {
    var value = path.trim();
    if (value.isEmpty) value = '/';
    value = value.replaceAll('\\', '/');
    if (!value.startsWith('/')) value = '/$value';
    value = value.replaceAll(RegExp(r'/+'), '/');
    if (value.length > 1) value = value.replaceAll(RegExp(r'/+$'), '');
    return value;
  }

  String _entryRemotePath({
    required String currentPath,
    required String? entryPath,
    required String name,
  }) {
    final rawPath = entryPath?.trim();
    if (rawPath != null && rawPath.isNotEmpty) {
      final uri = Uri.tryParse(rawPath);
      if (uri != null && uri.hasScheme) return uri.path;
      return _normalizeRemotePath(rawPath);
    }
    return _joinPath(currentPath, name);
  }

  String _joinPath(String dir, String child) {
    final left = _normalizeRemotePath(dir).replaceAll(RegExp(r'/+$'), '');
    final right = child.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
    return _normalizeRemotePath('$left/$right');
  }

  bool _isAudio(String value) {
    final lower = value.toLowerCase().split('?').first.split('#').first;
    return audioExts.any(lower.endsWith);
  }

  String _buildPlaybackUrl({
    required String baseUrl,
    required String remotePath,
    required String username,
    required String password,
  }) {
    final base = Uri.parse(baseUrl);
    final basePath = base.path.replaceAll(RegExp(r'/+$'), '');
    var path = _normalizeRemotePath(remotePath);

    // readDir() on many servers returns a path including the WebDAV base path.
    // If it does not, prefix the path from the base URL.
    if (basePath.isNotEmpty && basePath != '/' && !path.startsWith('$basePath/')) {
      path = _normalizeRemotePath('$basePath/$path');
    }

    final user = username.trim();
    final uri = base.replace(
      path: path,
      query: '',
      userInfo: user.isEmpty ? '' : '$user:$password',
    );
    return uri.toString();
  }

  String _titleFromName(String name) {
    return name
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[_]+'), ' ')
        .trim();
  }

  String _folderNameOf(String remotePath) {
    final parts = _normalizeRemotePath(remotePath)
        .split('/')
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (parts.length < 2) return 'NAS';
    return parts[parts.length - 2];
  }

  String _normalizeForId(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'//+'), '/');
  }
}
