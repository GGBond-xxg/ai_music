import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/music_track.dart';

class JellyfinService {
  JellyfinService({
    required this.serverUrl,
    this.apiKey = '',
    this.username = '',
    this.password = '',
    this.prefetchLyrics = false,
  });

  static const _clientName = 'Music';
  static const _deviceName = 'Flutter';
  static const _deviceId = 'fresh_music_flutter';
  static const _clientVersion = '0.2.0';

  final String serverUrl;
  final String apiKey;
  final String username;
  final String password;
  final bool prefetchLyrics;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 18),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
    ),
  );

  _JellyfinAuth? _auth;

  /// 返回可直接拼接口的 Jellyfin 根地址，例如：
  /// http://192.168.1.20:8888
  /// 注意：真机访问电脑 Jellyfin 时不能填 localhost，要填电脑局域网 IP。
  String get _baseUrl {
    final raw = serverUrl.trim();
    if (raw.isEmpty) {
      throw Exception('请输入 Jellyfin 服务器地址，例如 192.168.1.20:8888');
    }

    if (RegExp(r'^[a-fA-F0-9]{24,}$').hasMatch(raw) && !raw.contains('.')) {
      throw Exception('第一个输入框只能填 Jellyfin 服务器地址，API Key 请填到 API Key 输入框。');
    }

    var value = raw;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      throw Exception('Jellyfin 地址格式不正确，请填写 192.168.1.20:8888 或 http://192.168.1.20:8888');
    }

    final authority = uri.authority.split('@').last;
    final hasExplicitPort = RegExp(r':\d+$').hasMatch(authority);
    final portPart = hasExplicitPort ? ':${uri.port}' : '';
    final origin = '${uri.scheme}://${uri.host}$portPart';

    final segments = uri.pathSegments
        .where((e) => e.trim().isNotEmpty)
        .where((e) {
          final lower = e.toLowerCase();
          return lower != 'system' &&
              lower != 'info' &&
              lower != 'public' &&
              lower != 'users' &&
              lower != 'items' &&
              lower != 'audio';
        })
        .toList();

    if (segments.isEmpty) return origin;
    return '$origin/${segments.join('/')}';
  }

  String? get _apiKeyFromInput {
    final direct = apiKey.trim();
    if (direct.isNotEmpty) return direct;

    final raw = serverUrl.trim();
    final withScheme = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'http://$raw';
    final uri = Uri.tryParse(withScheme);
    final fromApiKey = uri?.queryParameters['api_key']?.trim();
    if (fromApiKey != null && fromApiKey.isNotEmpty) return fromApiKey;

    final fromModern = uri?.queryParameters['ApiKey']?.trim();
    if (fromModern != null && fromModern.isNotEmpty) return fromModern;

    return null;
  }

  Future<void> testConnection() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/System/Info/Public',
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 400) {
        throw Exception('Jellyfin 服务已响应，但 /System/Info/Public 返回 $statusCode。请确认地址端口是 Jellyfin 根地址。');
      }

      _jsonMap(response.data, requestName: 'Jellyfin 服务检测');
    } on DioException catch (e) {
      throw Exception(_formatDioError(e, '连接 Jellyfin 服务失败'));
    }
  }

  Future<List<MusicTrack>> listAudio() async {
    try {
      final auth = await _ensureAuth();

      final response = await _dio.get(
        '$_baseUrl/Users/${auth.userId}/Items',
        options: _authOptions(auth),
        queryParameters: {
          // Jellyfin 推荐 Header Authorization，这里保留 ApiKey 兼容播放器/图片直链。
          if (auth.token.isNotEmpty) 'api_key': auth.token,
          'Recursive': 'true',
          'IncludeItemTypes': 'Audio',
          'Fields':
              'Path,MediaSources,Genres,Artists,Album,AlbumArtist,Overview,PrimaryImageAspectRatio,RunTimeTicks,Container',
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
          'Limit': '10000',
        },
      );

      final data = _jsonMap(response.data, requestName: 'Jellyfin 音乐列表');
      final items = data['Items'];
      if (items is! List) return [];

      final itemMaps = items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      // Jellyfin 10.9+ 提供 /Audio/{itemId}/Lyrics 接口。
      // 真机局域网下如果音乐库较大，逐首拉歌词会让“连接并扫描”卡很久，
      // 所以默认只扫描歌曲列表；需要歌词时在连接弹窗里手动开启。
      final lyricByItemId = prefetchLyrics
          ? await _loadLyricsForItems(itemMaps, auth)
          : <String, String>{};

      final tracks = <MusicTrack>[];
      for (final item in itemMaps) {
        final itemId = item['Id']?.toString() ?? '';
        final track = _trackFromItem(
          item,
          auth,
          lyricText: lyricByItemId[itemId],
        );
        if (track.id.trim().isNotEmpty && track.uri.trim().isNotEmpty) {
          tracks.add(track);
        }
      }
      return tracks;
    } on DioException catch (e) {
      throw Exception(_formatDioError(e, '读取 Jellyfin 音乐库失败'));
    }
  }

  Future<_JellyfinAuth> _ensureAuth() async {
    final cached = _auth;
    if (cached != null) return cached;

    final token = _apiKeyFromInput;
    final name = username.trim();

    if (token != null && token.isNotEmpty) {
      try {
        final userId = await _getFirstUserId(token: token);
        return _auth = _JellyfinAuth(token: token, userId: userId);
      } catch (_) {
        if (name.isNotEmpty && password.isNotEmpty) {
          return _auth = await _loginByPassword(username: name, password: password);
        }
        rethrow;
      }
    }

    if (name.isEmpty || password.isEmpty) {
      throw Exception('请输入 Jellyfin API Key，或者填写用户名和密码登录。');
    }

    return _auth = await _loginByPassword(username: name, password: password);
  }

  Future<_JellyfinAuth> _loginByPassword({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/Users/AuthenticateByName',
        options: _publicAuthOptions(),
        data: {
          'Username': username,
          'Pw': password,
        },
      );

      final data = _jsonMap(response.data, requestName: 'Jellyfin 登录');
      final token = _cleanText(data['AccessToken']);
      final user = data['User'];
      final userId = user is Map ? _cleanText(user['Id']) : null;

      if (token == null || userId == null) {
        throw Exception('Jellyfin 登录成功但没有返回 AccessToken/UserId。');
      }

      return _JellyfinAuth(token: token, userId: userId);
    } on DioException catch (e) {
      throw Exception(_formatDioError(e, 'Jellyfin 用户名密码登录失败'));
    }
  }

  Future<String> _getFirstUserId({required String token}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/Users',
        options: _authOptions(_JellyfinAuth(token: token, userId: '')),
        queryParameters: {'api_key': token},
      );

      final users = _jsonList(response.data, requestName: 'Jellyfin 用户列表');
      if (users.isEmpty) {
        throw Exception('没有读取到 Jellyfin 用户，请确认 API Key 有访问 Users 的权限。');
      }

      final firstUser = users.first;
      final userId = _cleanText(firstUser['Id']);
      if (userId == null) throw Exception('没有获取到 Jellyfin 用户 ID。');
      return userId;
    } on DioException catch (e) {
      throw Exception(_formatDioError(e, '获取 Jellyfin 用户失败'));
    }
  }

  MusicTrack _trackFromItem(
    Map<String, dynamic> item,
    _JellyfinAuth auth, {
    String? lyricText,
  }) {
    final id = item['Id']?.toString() ?? '';
    final title = _cleanText(item['Name']) ?? '未知歌曲';
    final artist = _firstText(item['Artists']) ?? _firstText(item['ArtistItems']) ?? '未知艺术家';
    final album = _cleanText(item['Album']);
    final duration = _parseDuration(item['RunTimeTicks']);

    return MusicTrack(
      id: 'jellyfin:$id',
      title: title,
      uri: _buildUniversalAudioUrl(id: id, auth: auth),
      sourceType: MusicSourceType.jellyfin,
      artist: artist,
      album: album,
      coverUri: _buildImageUrl(id, auth.token),
      lyricText: lyricText,
      duration: duration,
    );
  }

  Future<Map<String, String>> _loadLyricsForItems(
    List<Map<String, dynamic>> items,
    _JellyfinAuth auth,
  ) async {
    final result = <String, String>{};
    const batchSize = 6;

    for (var i = 0; i < items.length; i += batchSize) {
      final batch = items.skip(i).take(batchSize).toList();
      final futures = batch.map((item) async {
        final id = item['Id']?.toString() ?? '';
        if (id.isEmpty) return;

        final lyric = await _fetchLyricsForItem(id: id, auth: auth);
        if (lyric != null && lyric.trim().isNotEmpty) {
          result[id] = lyric.trim();
        }
      });

      await Future.wait(futures);
    }

    return result;
  }

  Future<String?> _fetchLyricsForItem({
    required String id,
    required _JellyfinAuth auth,
  }) async {
    try {
      final options = _authOptions(auth).copyWith(
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
        validateStatus: (status) => status != null && status < 500,
      );

      final response = await _dio.get(
        '$_baseUrl/Audio/$id/Lyrics',
        options: options,
        queryParameters: {
          if (auth.token.isNotEmpty) 'api_key': auth.token,
        },
      );

      if (response.statusCode == 204 || response.statusCode == 404) {
        return null;
      }

      if ((response.statusCode ?? 0) >= 400) {
        return null;
      }

      return _parseLyricsResponse(response.data);
    } catch (_) {
      // 单首歌词获取失败不应该影响整库扫描和播放。
      return null;
    }
  }

  String? _parseLyricsResponse(dynamic data) {
    if (data == null) return null;

    if (data is String) {
      final text = data.trim();
      if (text.isEmpty || text.startsWith('<')) return null;

      if (text.startsWith('{') || text.startsWith('[')) {
        try {
          return _parseLyricsResponse(jsonDecode(text));
        } catch (_) {
          return text;
        }
      }

      return text;
    }

    if (data is List) {
      return _lyricsFromLineList(data);
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);

      // Jellyfin 的 Lyrics API 常见结构：
      // { "Lyrics": [{ "Start": 1230000000, "Text": "..." }] }
      // 这里也兼容 Lines / LyricLines 等字段，避免不同版本字段名差异。
      for (final key in const ['Lyrics', 'lyrics', 'Lines', 'lines', 'LyricLines', 'lyricLines']) {
        final value = map[key];
        if (value is List) {
          final parsed = _lyricsFromLineList(value);
          if (parsed != null && parsed.trim().isNotEmpty) return parsed;
        }
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }

      for (final key in const ['Text', 'text', 'Content', 'content', 'Value', 'value']) {
        final value = _cleanText(map[key]);
        if (value != null) return value;
      }
    }

    return null;
  }

  String? _lyricsFromLineList(List<dynamic> lines) {
    if (lines.isEmpty) return null;

    final timedRows = <_JellyfinLyricRow>[];
    final plainRows = <String>[];

    for (final raw in lines) {
      if (raw is String) {
        final text = raw.trim();
        if (text.isNotEmpty) plainRows.add(text);
        continue;
      }

      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final text = _firstCleanText(row, const [
        'Text',
        'text',
        'Line',
        'line',
        'Value',
        'value',
        'Lyrics',
        'lyrics',
      ]);

      if (text == null) continue;

      final time = _parseLyricStart(
        _firstValue(row, const [
          'Start',
          'start',
          'StartTicks',
          'startTicks',
          'StartPositionTicks',
          'startPositionTicks',
          'Time',
          'time',
          'Timestamp',
          'timestamp',
        ]),
      );

      if (time == null) {
        plainRows.add(text);
      } else {
        timedRows.add(_JellyfinLyricRow(time: time, text: text));
      }
    }

    if (timedRows.isNotEmpty) {
      timedRows.sort((a, b) => a.time.compareTo(b.time));
      return timedRows
          .map((row) => '${_formatLrcTime(row.time)}${row.text}')
          .join('\n');
    }

    if (plainRows.isNotEmpty) return plainRows.join('\n');
    return null;
  }

  Object? _firstValue(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      if (row.containsKey(key)) return row[key];
    }
    return null;
  }

  String? _firstCleanText(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final text = _cleanText(row[key]);
      if (text != null) return text;
    }
    return null;
  }

  Duration? _parseLyricStart(Object? value) {
    if (value == null) return null;

    if (value is num) return _durationFromNumericStart(value);

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final number = num.tryParse(text);
    if (number != null) return _durationFromNumericStart(number);

    // 兼容 00:01.230 / 01:02:03.456 / 00:01,230
    final normalized = text.replaceAll(',', '.');
    final parts = normalized.split(':');
    if (parts.length >= 2) {
      final secondsPart = parts.last;
      final secPieces = secondsPart.split('.');
      final seconds = int.tryParse(secPieces.first) ?? 0;
      final milliseconds = secPieces.length > 1
          ? int.tryParse(secPieces[1].padRight(3, '0').substring(0, 3)) ?? 0
          : 0;
      final minutes = int.tryParse(parts[parts.length - 2]) ?? 0;
      final hours = parts.length >= 3 ? int.tryParse(parts[parts.length - 3]) ?? 0 : 0;

      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    }

    return null;
  }

  Duration _durationFromNumericStart(num value) {
    final raw = value.round();
    if (raw <= 0) return Duration.zero;

    // Jellyfin 的内部时间通常是 ticks：1 秒 = 10,000,000 ticks。
    // 如果数值较小，则按毫秒兜底处理。
    if (raw >= 1000000) {
      return Duration(microseconds: raw ~/ 10);
    }

    return Duration(milliseconds: raw);
  }

  String _formatLrcTime(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds = duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '[$minutes:$seconds.$milliseconds]';
  }

  String _buildUniversalAudioUrl({
    required String id,
    required _JellyfinAuth auth,
  }) {
    // Use the direct stream endpoint instead of the universal/transcoding URL.
    // It is more stable on Android media_kit, and avoids playback failures when
    // the library scan also fetched lyrics from Jellyfin.
    return Uri.parse('$_baseUrl/Audio/$id/stream').replace(
      queryParameters: {
        'api_key': auth.token,
        'UserId': auth.userId,
        'DeviceId': _deviceId,
        'Static': 'true',
        'Container': 'mp3,aac,m4a,flac,webma,webm,wav,ogg',
      },
    ).toString();
  }

  String _buildImageUrl(String id, String token) {
    return Uri.parse('$_baseUrl/Items/$id/Images/Primary').replace(
      queryParameters: {'api_key': token},
    ).toString();
  }

  Options _publicAuthOptions() {
    return Options(
      headers: {
        'Authorization': _authorizationHeader,
        'Content-Type': 'application/json',
      },
    );
  }

  Options _authOptions(_JellyfinAuth auth) {
    return Options(
      headers: {
        'Authorization': '$_authorizationHeader, Token="${auth.token}"',
        if (auth.token.isNotEmpty) 'X-Emby-Token': auth.token,
      },
    );
  }

  String get _authorizationHeader {
    return 'MediaBrowser Client="$_clientName", '
        'Device="$_deviceName", '
        'DeviceId="$_deviceId", '
        'Version="$_clientVersion"';
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
        throw Exception('$requestName 返回了网页 HTML，不是 Jellyfin JSON。请检查地址是否能被手机访问，真机不要填 localhost。');
      }
    }

    throw Exception('$requestName 返回数据格式异常。');
  }

  List<Map<String, dynamic>> _jsonList(dynamic data, {required String requestName}) {
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (data is String) {
      final text = data.trim();
      if (text.startsWith('[')) {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
      if (text.startsWith('<')) {
        throw Exception('$requestName 返回了网页 HTML，不是 Jellyfin JSON。请检查地址是否能被手机访问，真机不要填 localhost。');
      }
    }
    throw Exception('$requestName 返回数据格式异常。');
  }

  String _formatDioError(DioException e, String prefix) {
    final uri = e.requestOptions.uri;
    final code = e.response?.statusCode;

    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      return '$prefix：连接超时，请确认手机能访问 $uri。真机不要填 localhost，要填电脑局域网 IP。';
    }
    if (code == 401 || code == 403) {
      return '$prefix：鉴权失败，请检查 API Key、用户名、密码或用户权限。';
    }
    if (code == 404) {
      return '$prefix：接口不存在，请确认地址是否为 Jellyfin 服务，例如 192.168.1.20:8888。';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '$prefix：网络无法连接，请检查 Wi-Fi、热点、防火墙和 Jellyfin 端口。请求地址：$uri';
    }
    return '$prefix：${e.message ?? e.toString()}';
  }

  Duration? _parseDuration(dynamic runTimeTicks) {
    if (runTimeTicks == null) return null;
    final ticks = int.tryParse(runTimeTicks.toString());
    if (ticks == null || ticks <= 0) return null;
    return Duration(seconds: ticks ~/ 10000000);
  }

  String? _firstText(dynamic value) {
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is Map) return _cleanText(first['Name']);
      return _cleanText(first);
    }
    return _cleanText(value);
  }

  String? _cleanText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == '<unknown>') return null;
    return text;
  }
}

class _JellyfinLyricRow {
  const _JellyfinLyricRow({required this.time, required this.text});

  final Duration time;
  final String text;
}

class _JellyfinAuth {
  const _JellyfinAuth({required this.token, required this.userId});
  final String token;
  final String userId;
}
