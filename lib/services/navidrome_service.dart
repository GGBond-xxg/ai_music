import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../models/music_track.dart';

class NavidromeService {
  NavidromeService({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  static const _client = 'Music_flutter';
  static const _apiVersion = '1.16.1';

  final String serverUrl;
  final String username;
  final String password;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 18),
      receiveTimeout: const Duration(seconds: 35),
      sendTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
    ),
  );

  String get _baseUrl {
    var raw = serverUrl.trim();
    if (raw.isEmpty) {
      throw Exception('请输入 Navidrome 地址，例如 192.168.1.20:4533');
    }
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'http://$raw';
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) {
      throw Exception(
          'Navidrome 地址格式不正确，请填写 192.168.1.20:4533 或 http://192.168.1.20:4533');
    }

    final authority = uri.authority.split('@').last;
    final hasExplicitPort = RegExp(r':\d+$').hasMatch(authority);
    final portPart = hasExplicitPort ? ':${uri.port}' : '';
    final origin = '${uri.scheme}://${uri.host}$portPart';

    final segments =
        uri.pathSegments.where((e) => e.trim().isNotEmpty).where((e) {
      final lower = e.toLowerCase();
      return lower != 'rest' &&
          lower != 'ping.view' &&
          lower != 'stream.view' &&
          lower != 'getcoverart.view' &&
          lower != 'search3.view';
    }).toList();

    if (segments.isEmpty) return origin;
    return '$origin/${segments.join('/')}';
  }

  Map<String, String> get _authQuery {
    final user = username.trim();
    final pass = password;
    if (user.isEmpty || pass.isEmpty) {
      throw Exception('Navidrome 需要填写用户名和密码。');
    }

    final salt = _randomSalt();
    final token = md5.convert(utf8.encode('$pass$salt')).toString();
    return {
      'u': user,
      't': token,
      's': salt,
      'v': _apiVersion,
      'c': _client,
      'f': 'json',
    };
  }

  Future<List<MusicTrack>> listAudio() async {
    try {
      await _ping();

      var songs = await _searchAllSongs();
      if (songs.isEmpty) {
        songs = await _listSongsFromAlbums();
      }

      final lyricById = await _loadLyricsForSongs(songs);
      final tracks = <MusicTrack>[];
      for (final song in songs) {
        final track =
            _trackFromSong(song, lyricText: lyricById[_cleanText(song['id'])]);
        if (track.id.trim().isNotEmpty && track.uri.trim().isNotEmpty) {
          tracks.add(track);
        }
      }
      return tracks;
    } on DioException catch (e) {
      throw Exception(_formatDioError(e, '读取 Navidrome 音乐库失败'));
    }
  }

  Future<void> _ping() async {
    final response = await _dio.get(
      _endpoint('ping.view'),
      queryParameters: _authQuery,
    );
    _subsonicPayload(response.data, requestName: 'Navidrome ping');
  }

  Future<List<Map<String, dynamic>>> _searchAllSongs() async {
    final response = await _dio.get(
      _endpoint('search3.view'),
      queryParameters: {
        ..._authQuery,
        'query': '',
        'artistCount': '0',
        'albumCount': '0',
        'songCount': '10000',
      },
    );

    final payload =
        _subsonicPayload(response.data, requestName: 'Navidrome 搜索歌曲');
    final result = payload['searchResult3'];
    if (result is! Map) return [];
    return _mapList(result['song']);
  }

  Future<List<Map<String, dynamic>>> _listSongsFromAlbums() async {
    final albumResponse = await _dio.get(
      _endpoint('getAlbumList2.view'),
      queryParameters: {
        ..._authQuery,
        'type': 'alphabeticalByName',
        'size': '500',
        'offset': '0',
      },
    );

    final payload =
        _subsonicPayload(albumResponse.data, requestName: 'Navidrome 专辑列表');
    final list = payload['albumList2'];
    if (list is! Map) return [];
    final albums = _mapList(list['album']);
    final songs = <Map<String, dynamic>>[];

    for (final album in albums) {
      final id = _cleanText(album['id']);
      if (id == null) continue;
      try {
        final response = await _dio.get(
          _endpoint('getAlbum.view'),
          queryParameters: {..._authQuery, 'id': id},
        );
        final albumPayload =
            _subsonicPayload(response.data, requestName: 'Navidrome 专辑歌曲');
        final albumData = albumPayload['album'];
        if (albumData is Map) {
          songs.addAll(_mapList(albumData['song']));
        }
      } catch (_) {
        // 单个专辑失败不影响整个库扫描。
      }
    }
    return songs;
  }

  MusicTrack _trackFromSong(Map<String, dynamic> song, {String? lyricText}) {
    final id = _cleanText(song['id']) ?? '';
    final title = _cleanText(song['title']) ?? '未知歌曲';
    final artist = _cleanText(song['artist']) ??
        _cleanText(song['albumArtist']) ??
        '未知艺术家';
    final album = _cleanText(song['album']);
    final coverId = _cleanText(song['coverArt']) ?? id;
    final durationSeconds = int.tryParse(song['duration']?.toString() ?? '');

    return MusicTrack(
      id: 'navidrome:$id',
      title: title,
      uri: _streamUrl(id),
      sourceType: MusicSourceType.navidrome,
      artist: artist,
      album: album,
      coverUri: _coverUrl(coverId),
      lyricText: lyricText,
      duration:
          durationSeconds == null ? null : Duration(seconds: durationSeconds),
    );
  }

  Future<Map<String, String>> _loadLyricsForSongs(
      List<Map<String, dynamic>> songs) async {
    final result = <String, String>{};
    const batchSize = 5;

    for (var i = 0; i < songs.length; i += batchSize) {
      final batch = songs.skip(i).take(batchSize).toList();
      await Future.wait(batch.map((song) async {
        final id = _cleanText(song['id']);
        if (id == null) return;
        final lyric = await _fetchLyrics(
          artist: _cleanText(song['artist']) ?? '',
          title: _cleanText(song['title']) ?? '',
        );
        if (lyric != null && lyric.trim().isNotEmpty) {
          result[id] = lyric.trim();
        }
      }));
    }

    return result;
  }

  Future<String?> _fetchLyrics(
      {required String artist, required String title}) async {
    if (artist.trim().isEmpty || title.trim().isEmpty) return null;
    try {
      final response = await _dio.get(
        _endpoint('getLyrics.view'),
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          validateStatus: (status) => status != null && status < 500,
        ),
        queryParameters: {
          ..._authQuery,
          'artist': artist,
          'title': title,
        },
      );
      if ((response.statusCode ?? 0) >= 400) return null;
      final payload =
          _subsonicPayload(response.data, requestName: 'Navidrome 歌词');
      final lyrics = payload['lyrics'];
      if (lyrics is Map) {
        return _cleanText(lyrics['value']);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String _streamUrl(String id) {
    return Uri.parse(_endpoint('stream.view')).replace(
      queryParameters: {
        ..._authQuery,
        'id': id,
      },
    ).toString();
  }

  String _coverUrl(String id) {
    return Uri.parse(_endpoint('getCoverArt.view')).replace(
      queryParameters: {
        ..._authQuery,
        'id': id,
      },
    ).toString();
  }

  String _endpoint(String name) {
    return '${_baseUrl.replaceAll(RegExp(r'/+$'), '')}/rest/$name';
  }

  Map<String, dynamic> _subsonicPayload(dynamic data,
      {required String requestName}) {
    final map = _jsonMap(data, requestName: requestName);
    final payload = map['subsonic-response'] ?? map['subsonicResponse'];
    if (payload is! Map) {
      throw Exception('$requestName 返回数据格式异常。');
    }
    final result = Map<String, dynamic>.from(payload);
    final status = result['status']?.toString().toLowerCase();
    if (status == 'failed') {
      final error = result['error'];
      if (error is Map) {
        throw Exception(
            '$requestName 失败：${error['message'] ?? error['code'] ?? '未知错误'}');
      }
      throw Exception('$requestName 失败。');
    }
    return result;
  }

  Map<String, dynamic> _jsonMap(dynamic data, {required String requestName}) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final text = data.trim();
      if (text.startsWith('{')) {
        final decoded = jsonDecode(text);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
      if (text.startsWith('<')) {
        throw Exception(
            '$requestName 返回了网页 HTML，不是 Navidrome / Subsonic JSON。请检查地址是否正确。');
      }
    }
    throw Exception('$requestName 返回数据格式异常。');
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (value is Map) return [Map<String, dynamic>.from(value)];
    return [];
  }

  String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String? _cleanText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == '<unknown>') return null;
    return text;
  }

  String _formatDioError(DioException e, String prefix) {
    final uri = e.requestOptions.uri;
    final code = e.response?.statusCode;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '$prefix：连接超时，请确认手机能访问 $uri。';
    }
    if (code == 401 || code == 403) {
      return '$prefix：鉴权失败，请检查用户名、密码和 Navidrome 用户权限。';
    }
    if (code == 404) {
      return '$prefix：接口不存在，请确认地址是否为 Navidrome / Subsonic 服务。';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '$prefix：网络无法连接，请检查 Wi-Fi、热点、防火墙和端口。请求地址：$uri';
    }
    return '$prefix：${e.message ?? e.toString()}';
  }
}
