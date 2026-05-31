import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/music_track.dart';

class EmbyService {
  EmbyService({
    required this.serverUrl,
    this.apiKey = '',
    this.username = '',
    this.password = '',
  });

  static const _clientName = 'Music';
  static const _deviceName = 'Flutter';
  static const _deviceId = 'fresh_music_flutter';
  static const _clientVersion = '0.2.0';

  final String serverUrl;
  final String apiKey;
  final String username;
  final String password;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 18),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
    ),
  );

  _EmbyAuth? _auth;

  /// 返回可直接拼接口的 Emby 根地址，例如：
  /// http://192.168.137.177:8096/emby
  String get _embyBaseUrl {
    final raw = serverUrl.trim();
    if (raw.isEmpty) {
      throw Exception('请输入 Emby 服务器 IP，例如 192.168.137.177:8096');
    }

    // 常见误填：把 API Key 写到了服务器地址输入框。
    if (RegExp(r'^[a-fA-F0-9]{24,}$').hasMatch(raw) && !raw.contains('.')) {
      throw Exception('第一个输入框只能填 Emby 服务器 IP / 地址，API Key 请填到 API Key 输入框。');
    }

    var value = raw;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      throw Exception('Emby 地址格式不正确，请填写 192.168.137.177 或 192.168.137.177:8096');
    }

    final authority = uri.authority.split('@').last;
    final hasExplicitPort = RegExp(r':\d+$').hasMatch(authority);
    final port = hasExplicitPort ? uri.port : 8096;
    final origin = '${uri.scheme}://${uri.host}:$port';

    // 支持粘贴完整测试地址：/emby/Users/Query?api_key=xxx
    final segments = uri.pathSegments.where((e) => e.trim().isNotEmpty).toList();
    if (segments.isEmpty) return '$origin/emby';

    final embyIndex = segments.indexWhere((e) => e.toLowerCase() == 'emby');
    if (embyIndex >= 0) {
      final prefix = segments.take(embyIndex + 1).join('/');
      return '$origin/$prefix';
    }

    return '$origin/emby';
  }

  String? get _apiKeyFromInput {
    final direct = apiKey.trim();
    if (direct.isNotEmpty) return direct;

    final raw = serverUrl.trim();
    final withScheme = raw.startsWith('http://') || raw.startsWith('https://') ? raw : 'http://$raw';
    final uri = Uri.tryParse(withScheme);
    final fromUrl = uri?.queryParameters['api_key']?.trim();
    if (fromUrl != null && fromUrl.isNotEmpty) return fromUrl;

    return null;
  }

  Future<List<MusicTrack>> listAudio() async {
    try {
      final auth = await _ensureAuth();

      final response = await _dio.get(
        '$_embyBaseUrl/Users/${auth.userId}/Items',
        options: _authOptions(auth),
        queryParameters: {
          'api_key': auth.token,
          'Recursive': 'true',
          'IncludeItemTypes': 'Audio',
          'Fields':
              'Path,MediaSources,Genres,Artists,Album,AlbumArtist,Overview,PrimaryImageAspectRatio,RunTimeTicks,Container',
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
          'Limit': '10000',
        },
      );

      final data = _jsonMap(response.data, requestName: '音乐列表');
      final items = data['Items'];
      if (items is! List) return [];

      final tracks = <MusicTrack>[];
      for (final rawItem in items.whereType<Map>()) {
        final item = Map<String, dynamic>.from(rawItem);
        final track = _trackFromItem(item, auth);
        if (track.id.trim().isNotEmpty && track.uri.trim().isNotEmpty) {
          tracks.add(track);
        }
      }
      return tracks;
    } on DioException catch (e) {
      throw Exception(_formatDioError(e, '读取 Emby 音乐库失败'));
    }
  }

  Future<_EmbyAuth> _ensureAuth() async {
    final cached = _auth;
    if (cached != null) return cached;

    final token = _apiKeyFromInput;
    final name = username.trim();

    if (token != null && token.isNotEmpty) {
      try {
        final userId = await _getFirstUserId(token: token);
        return _auth = _EmbyAuth(token: token, userId: userId);
      } catch (_) {
        // 用户同时填写了用户名密码时，API Key 不可用就自动回退到密码登录。
        if (name.isNotEmpty && password.isNotEmpty) {
          return _auth = await _loginByPassword(username: name, password: password);
        }
        rethrow;
      }
    }

    if (name.isEmpty || password.isEmpty) {
      throw Exception('请输入 Emby API Key，或者填写用户名和密码登录。');
    }

    return _auth = await _loginByPassword(username: name, password: password);
  }

  Future<_EmbyAuth> _loginByPassword({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '$_embyBaseUrl/Users/AuthenticateByName',
        options: _publicAuthOptions(),
        data: {
          'Username': username,
          'Pw': password,
        },
      );

      final data = _jsonMap(response.data, requestName: 'Emby 登录');
      final token = _cleanText(data['AccessToken']);
      final user = data['User'];
      final userId = user is Map ? _cleanText(user['Id']) : null;

      if (token == null || userId == null) {
        throw Exception('Emby 登录成功但没有返回 AccessToken/UserId。');
      }

      return _EmbyAuth(token: token, userId: userId);
    } on DioException catch (e) {
      throw Exception(_formatDioError(e, 'Emby 用户名密码登录失败'));
    }
  }

  Future<String> _getFirstUserId({required String token}) async {
    try {
      final response = await _dio.get(
        '$_embyBaseUrl/Users/Query',
        options: _authOptions(_EmbyAuth(token: token, userId: '')),
        queryParameters: {'api_key': token},
      );

      final data = _jsonMap(response.data, requestName: '用户列表');
      final items = data['Items'];
      if (items is! List || items.isEmpty) {
        throw Exception('没有读取到 Emby 用户，请确认 API Key 有访问 Users/Query 的权限。');
      }

      final firstUser = items.first;
      if (firstUser is! Map) throw Exception('Emby 用户数据格式异常。');

      final userId = _cleanText(firstUser['Id']);
      if (userId == null) throw Exception('没有获取到 Emby 用户 ID。');
      return userId;
    } on DioException catch (e) {
      throw Exception(_formatDioError(e, '获取 Emby 用户失败'));
    }
  }

  MusicTrack _trackFromItem(Map<String, dynamic> item, _EmbyAuth auth) {
    final id = item['Id']?.toString() ?? '';
    final title = _cleanText(item['Name']) ?? '未知歌曲';
    final artist = _firstText(item['Artists']) ?? _firstText(item['ArtistItems']) ?? '未知艺术家';
    final album = _cleanText(item['Album']);
    final duration = _parseDuration(item['RunTimeTicks']);

    return MusicTrack(
      id: id,
      title: title,
      uri: _buildUniversalAudioUrl(id: id, auth: auth),
      sourceType: MusicSourceType.emby,
      artist: artist,
      album: album,
      coverUri: _buildImageUrl(id, auth.token),
      duration: duration,
    );
  }

  String _buildUniversalAudioUrl({
    required String id,
    required _EmbyAuth auth,
  }) {
    return Uri.parse('$_embyBaseUrl/Audio/$id/universal').replace(
      queryParameters: {
        'api_key': auth.token,
        'UserId': auth.userId,
        'DeviceId': _deviceId,
        'MaxStreamingBitrate': '140000000',
        'Container': 'mp3,aac,m4a,flac,webma,webm,wav,ogg',
        'AudioCodec': 'mp3,aac,flac',
        'TranscodingContainer': 'mp3',
        'TranscodingProtocol': 'http',
        'Static': 'false',
      },
    ).toString();
  }

  String _buildImageUrl(String id, String token) {
    return Uri.parse('$_embyBaseUrl/Items/$id/Images/Primary').replace(
      queryParameters: {'api_key': token},
    ).toString();
  }

  Options _publicAuthOptions() {
    return Options(headers: {'X-Emby-Authorization': _authorizationHeader});
  }

  Options _authOptions(_EmbyAuth auth) {
    return Options(
      headers: {
        'X-Emby-Authorization': _authorizationHeader,
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
        throw Exception('$requestName 返回了网页 HTML，不是 Emby JSON。请检查地址是否填成了 API Key。');
      }
    }

    throw Exception('$requestName 返回数据格式异常。');
  }

  String _formatDioError(DioException e, String prefix) {
    final uri = e.requestOptions.uri;
    final code = e.response?.statusCode;

    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      return '$prefix：连接超时，请确认手机能访问 $uri';
    }
    if (code == 401 || code == 403) {
      return '$prefix：鉴权失败，请检查 API Key、用户名、密码或用户权限。';
    }
    if (code == 404) {
      return '$prefix：接口不存在，请确认地址是否为 Emby 服务，例如 192.168.137.177:8096。';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '$prefix：网络无法连接，请检查 Wi-Fi、热点、防火墙和 Emby 端口。请求地址：$uri';
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
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }
}

class _EmbyAuth {
  const _EmbyAuth({required this.token, required this.userId});

  final String token;
  final String userId;
}
