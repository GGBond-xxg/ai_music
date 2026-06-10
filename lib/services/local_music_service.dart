import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/music_track.dart';

class LocalMusicService {
  static const allowed = [
    'mp3',
    'flac',
    'm4a',
    'm4b',
    'wav',
    'ogg',
    'opus',
    'aac',
    'wma',
    'ape',
    'aiff',
    'aif',
    'alac',
    'mka',
    'mpga',
    'mpeg',
    'amr',
  ];
  static const _allowedSet = {...allowed};

  /// 首次打开 App 时只做轻量扫描，避免递归扫完整个手机存储导致卡很久。
  ///
  /// 策略：
  /// - 只扫描几个常见音乐目录；
  /// - 每个目录最多向下扫描 2 层；
  /// - 总扫描时间超过 8 秒就提前结束；
  /// - 没找到就直接返回空列表，用户后续可以手动选择文件/文件夹导入。
  static const int _quickScanMaxDepth = 2;
  static const Duration _quickScanTimeout = Duration(seconds: 8);

  Future<List<MusicTrack>> scanDeviceAudio() async {
    final permitted = await _ensureAudioPermission();
    if (!permitted) return [];

    if (!Platform.isAndroid) return [];

    const roots = <String>[
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
      '/storage/emulated/0/MIUI/music',
      '/storage/emulated/0/Recordings',
    ];

    final paths = <String>[];
    final stopwatch = Stopwatch()..start();

    for (final root in roots) {
      if (stopwatch.elapsed >= _quickScanTimeout) break;

      paths.addAll(
        await _scanFolderPaths(
          root,
          maxDepth: _quickScanMaxDepth,
          timeout: _quickScanTimeout - stopwatch.elapsed,
        ),
      );
    }

    final uniquePaths = await _uniqueAudioPaths(paths);
    return _tracksFromPaths(uniquePaths);
  }

  Future<List<MusicTrack>> pickAudioFiles() async {
    final permitted = await _ensureAudioPermission();
    if (!permitted) return [];
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: false,
    );
    if (result == null) return [];

    final paths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .where(_isSupportedAudioPath)
        .toList();

    return _tracksFromPaths(await _uniqueAudioPaths(paths));
  }

  Future<List<MusicTrack>> pickAudioFolder() async {
    final permitted = await _ensureAudioPermission();
    if (!permitted) return [];

    final folderPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择音乐文件夹',
      lockParentWindow: true,
    );

    if (folderPath == null || folderPath.trim().isEmpty) return [];

    final paths = await _scanFolderPaths(folderPath);
    if (paths.isNotEmpty) {
      return _tracksFromPaths(paths);
    }

    // Android 11+ 的系统文件夹选择器有时只给“树目录授权”，
    // Dart 的 Directory.list 读不到内部文件。这里不要直接报错，
    // 改为自动弹出文件选择器，让用户在当前目录里全选音频文件。
    final fallback = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: false,
      dialogTitle: '请选择音频文件',
    );

    if (fallback == null) return [];

    final fallbackPaths = await _uniqueAudioPaths(
      fallback.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .where(_isSupportedAudioPath),
    );

    if (fallbackPaths.isEmpty) {
      throw Exception(
        '目录中没有找到音频文件，支持格式：${allowed.join(', ')}',
      );
    }

    return _tracksFromPaths(fallbackPaths);
  }

  Future<List<String>> _scanFolderPaths(
    String folderPath, {
    int? maxDepth,
    int? maxAudioFiles,
    Duration? timeout,
  }) async {
    final candidates = _folderCandidates(folderPath);
    final paths = <String>[];
    final stopwatch = timeout == null ? null : (Stopwatch()..start());

    bool shouldStop() {
      if (maxAudioFiles != null && paths.length >= maxAudioFiles) return true;
      if (timeout != null && stopwatch != null && stopwatch.elapsed >= timeout) {
        return true;
      }
      return false;
    }

    final scannedCandidateKeys = <String>{};
    for (final candidate in candidates) {
      if (shouldStop()) break;

      final rootDirectory = Directory(candidate);
      if (!await rootDirectory.exists()) continue;

      final candidateKey = _normalizeStorageAlias(candidate).toLowerCase();
      if (!scannedCandidateKeys.add(candidateKey)) continue;

      final queue = <MapEntry<String, int>>[MapEntry(candidate, 0)];
      var cursor = 0;

      while (cursor < queue.length && !shouldStop()) {
        final entry = queue[cursor++];
        final directory = Directory(entry.key);

        try {
          await for (final entity in directory.list(
            recursive: false,
            followLinks: false,
          )) {
            if (shouldStop()) break;

            if (entity is File) {
              if (_isSupportedAudioPath(entity.path)) paths.add(entity.path);
              continue;
            }

            if (entity is Directory &&
                (maxDepth == null || entry.value < maxDepth)) {
              queue.add(MapEntry(entity.path, entry.value + 1));
            }
          }
        } catch (_) {
          // 继续尝试其它候选路径。部分 Android 目录会因为 scoped storage 拒绝列举。
        }
      }
    }

    return _uniqueAudioPaths(paths);
  }

  List<String> _folderCandidates(String folderPath) {
    final normalized = p.normalize(folderPath.trim()).replaceAll('\\', '/');
    final candidates = <String>{normalized};

    // 某些 Android 文件选择器返回的路径不能直接用 Directory.list，
    // 但用户看到的是 “OnePlus Ace 5 > Music”，真实目录通常是下面这些。
    final name = p.basename(normalized).trim();
    if (Platform.isAndroid && name.isNotEmpty) {
      candidates.add('/storage/emulated/0/$name');
      candidates.add('/sdcard/$name');
      if (name.toLowerCase() == 'music') {
        candidates.add('/storage/emulated/0/Music');
        candidates.add('/sdcard/Music');
      }
    }

    return candidates.where((e) => e.trim().isNotEmpty).toList();
  }

  Future<List<String>> _uniqueAudioPaths(Iterable<String> input) async {
    final used = <String>{};
    final result = <String>[];

    for (final raw in input) {
      if (!_isSupportedAudioPath(raw)) continue;

      final normalized = _normalizeStorageAlias(p.normalize(raw.trim()));
      if (normalized.isEmpty) continue;

      final key = await _audioFileIdentityKey(normalized);
      if (used.add(key)) {
        result.add(normalized);
      }
    }

    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  Future<String> _audioFileIdentityKey(String path) async {
    var normalized = _normalizeStorageAlias(path);

    try {
      final resolved = await File(normalized).resolveSymbolicLinks();
      normalized = _normalizeStorageAlias(resolved);
    } catch (_) {}

    try {
      final file = File(normalized);
      final stat = await file.stat();
      final name = p.basename(normalized).toLowerCase();

      // 不把完整路径放进文件身份 key。
      // Android 上同一个文件可能会以 /sdcard、/storage/emulated/0、
      // tree 授权映射等多种路径出现；如果把路径也放进去，
      // 同一首歌会被当成不同文件重复导入。
      return [
        'audio',
        name,
        stat.size.toString(),
        stat.modified.millisecondsSinceEpoch.toString(),
      ].join('|');
    } catch (_) {
      return 'audio|${normalized.toLowerCase()}';
    }
  }

  String _normalizeStorageAlias(String path) {
    var value = path.trim().replaceAll('\\', '/');
    if (value.isEmpty) return value;

    value = p.normalize(value).replaceAll('\\', '/');

    if (Platform.isAndroid) {
      if (value == '/sdcard') return '/storage/emulated/0';
      if (value.startsWith('/sdcard/')) {
        value = '/storage/emulated/0/${value.substring('/sdcard/'.length)}';
      }

      if (value == '/storage/self/primary') return '/storage/emulated/0';
      if (value.startsWith('/storage/self/primary/')) {
        value = '/storage/emulated/0/${value.substring('/storage/self/primary/'.length)}';
      }

      if (value == '/mnt/sdcard') return '/storage/emulated/0';
      if (value.startsWith('/mnt/sdcard/')) {
        value = '/storage/emulated/0/${value.substring('/mnt/sdcard/'.length)}';
      }
    }

    return value.replaceAll(RegExp(r'/+'), '/');
  }

  Future<List<MusicTrack>> ensureWindowsPlayableCopies(
    List<MusicTrack> input,
  ) async {
    if (!Platform.isWindows || input.isEmpty) return input;

    final cacheDir = await getApplicationSupportDirectory();
    final playbackDir = Directory(
      p.join(_windowsPlaybackRoot(cacheDir.path),
          'fresh_music_windows_playback_cache'),
    );
    if (!await playbackDir.exists()) {
      await playbackDir.create(recursive: true);
    }

    final result = <MusicTrack>[];
    for (final track in input) {
      if (track.sourceType != MusicSourceType.localFile) {
        result.add(track);
        continue;
      }

      final sourcePath = _sourcePathForTrack(track);
      if (sourcePath == null || sourcePath.trim().isEmpty) {
        result.add(track);
        continue;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        // 原文件已经不存在时，保留原记录；外层会根据 uri 是否还可用决定是否展示。
        result.add(track);
        continue;
      }

      final playablePath = await _windowsPlayableCopyPath(
        sourcePath,
        playbackDir.path,
      );

      result.add(_copyTrackWithUri(track, playablePath));
    }

    return result;
  }

  Future<List<MusicTrack>> _tracksFromPaths(List<String> paths) async {
    final uniquePaths = await _uniqueAudioPaths(paths);

    if (uniquePaths.isEmpty) return [];

    final cacheDir = await getApplicationSupportDirectory();
    final coverDir =
        Directory(p.join(cacheDir.path, 'fresh_music_local_covers'));
    if (!await coverDir.exists()) await coverDir.create(recursive: true);

    final playbackDir = Directory(
      p.join(_windowsPlaybackRoot(cacheDir.path),
          'fresh_music_windows_playback_cache'),
    );
    if (Platform.isWindows && !await playbackDir.exists()) {
      await playbackDir.create(recursive: true);
    }

    final tracks = <MusicTrack>[];
    for (final path in uniquePaths) {
      tracks.add(await _trackFromPath(
        path,
        coverDir.path,
        playbackDir.path,
      ));
    }
    return tracks;
  }

  Future<bool> _ensureAudioPermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted || audioStatus.isLimited) return true;
    } catch (_) {
      // Permission.audio is unavailable on some old permission_handler builds/devices.
    }

    try {
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted || storageStatus.isLimited) return true;
    } catch (_) {}

    // 不再请求 MANAGE_EXTERNAL_STORAGE。
    // 该权限属于 Android 11+ “所有文件访问权限”，对音乐播放器来说过重，
    // 容易触发 Google Play 审核 / Play Protect 风险提示。
    // 本地音乐读取优先使用 READ_MEDIA_AUDIO / READ_EXTERNAL_STORAGE + FilePicker。
    return false;
  }

  bool _isSupportedAudioPath(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return _allowedSet.contains(ext);
  }

  Future<MusicTrack> _trackFromPath(
    String path,
    String coverDirPath,
    String playbackDirPath,
  ) async {
    final file = File(path);
    final fileTitle = p.basenameWithoutExtension(path).trim();
    final fallback = _parseNameFromFilename(fileTitle);

    String title = fallback.title;
    String? artist = fallback.artist;
    String? album;
    String? lyricText;
    Duration? duration;
    String? coverUri;

    try {
      final metadata = readMetadata(file, getImage: true);

      title = _cleanText(_readTitle(metadata)) ?? title;
      artist = _cleanText(_readArtist(metadata)) ?? artist ?? '本地音乐';
      album = _cleanText(_readAlbum(metadata));
      lyricText = _cleanText(_readLyrics(metadata));
      duration = _readDuration(metadata);

      coverUri = await _saveEmbeddedCoverIfNeeded(
        metadata: metadata,
        audioPath: path,
        coverDirPath: coverDirPath,
      );
    } catch (e) {
      debugLogLocalMetadata('读取本机音乐标签失败: $path, $e');
    }

    lyricText ??= await _readSidecarLyric(path);

    final playbackPath = Platform.isWindows
        ? await _windowsPlayableCopyPath(path, playbackDirPath)
        : path;

    return MusicTrack(
      id: path,
      title: title,
      uri: Uri.file(playbackPath, windows: Platform.isWindows).toString(),
      sourceType: MusicSourceType.localFile,
      artist: artist ?? '本地音乐',
      album: album,
      coverUri: coverUri,
      lyricText: lyricText,
      duration: duration,
    );
  }

  String _windowsPlaybackRoot(String supportDirPath) {
    if (!Platform.isWindows) return supportDirPath;
    if (!_containsNonAscii(supportDirPath)) return supportDirPath;

    // just_audio_windows 在部分环境下对中文/Unicode 路径会报
    // “系统找不到指定的路径”。如果 AppData 用户名本身是中文，
    // 缓存到 AppData 仍可能失败，因此退到 exe 所在目录。
    final exeDir = p.dirname(Platform.resolvedExecutable);
    return exeDir.trim().isEmpty ? supportDirPath : exeDir;
  }

  bool _containsNonAscii(String value) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit > 0x7f) return true;
    }
    return false;
  }

  Future<String> _windowsPlayableCopyPath(
    String sourcePath,
    String playbackDirPath,
  ) async {
    if (!Platform.isWindows) return sourcePath;

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return sourcePath;

    final ext = p.extension(sourcePath).toLowerCase();
    final stat = await sourceFile.stat();
    final keyInput =
        '$sourcePath|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
    final key = sha1.convert(utf8.encode(keyInput)).toString();
    final target = File(p.join(playbackDirPath, '$key$ext'));

    if (await target.exists()) {
      try {
        if (await target.length() == stat.size) return target.path;
      } catch (_) {}
    }

    await sourceFile.copy(target.path);
    return target.path;
  }

  String? _sourcePathForTrack(MusicTrack track) {
    final id = track.id.trim();
    if (id.isNotEmpty && File(id).existsSync()) return p.normalize(id);

    final raw = track.uri.trim();
    if (raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri != null && uri.isScheme('file')) {
      try {
        return p.normalize(uri.toFilePath(windows: Platform.isWindows));
      } catch (_) {
        try {
          return p.normalize(uri.toFilePath());
        } catch (_) {}
      }
    }

    if (File(raw).existsSync()) return p.normalize(raw);
    return null;
  }

  MusicTrack _copyTrackWithUri(MusicTrack track, String playbackPath) {
    return MusicTrack(
      id: track.id,
      title: track.title,
      uri: Uri.file(playbackPath, windows: Platform.isWindows).toString(),
      sourceType: track.sourceType,
      artist: track.artist,
      album: track.album,
      coverUri: track.coverUri,
      lyricText: track.lyricText,
      duration: track.duration,
    );
  }

  _FilenameInfo _parseNameFromFilename(String name) {
    final trimmed = name.trim();
    final match = RegExp(r'^(.+?)\s*[-–—]\s*(.+)$').firstMatch(trimmed);
    if (match != null) {
      final artist = match.group(1)?.trim();
      final title = match.group(2)?.trim();
      if (artist != null &&
          artist.isNotEmpty &&
          title != null &&
          title.isNotEmpty) {
        return _FilenameInfo(title: title, artist: artist);
      }
    }
    return _FilenameInfo(title: trimmed.isEmpty ? '未知歌曲' : trimmed);
  }

  String? _cleanText(dynamic value) {
    if (value == null) return null;
    if (value is List && value.isNotEmpty) return _cleanText(value.first);
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  dynamic _readTitle(dynamic metadata) {
    try {
      return metadata.title;
    } catch (_) {
      return null;
    }
  }

  dynamic _readArtist(dynamic metadata) {
    try {
      return metadata.artist;
    } catch (_) {}
    try {
      return metadata.artists;
    } catch (_) {}
    try {
      return metadata.albumArtist;
    } catch (_) {}
    return null;
  }

  dynamic _readAlbum(dynamic metadata) {
    try {
      return metadata.album;
    } catch (_) {
      return null;
    }
  }

  dynamic _readLyrics(dynamic metadata) {
    try {
      return metadata.lyrics;
    } catch (_) {
      return null;
    }
  }

  Duration? _readDuration(dynamic metadata) {
    try {
      final value = metadata.duration;
      if (value is Duration) return value;
      if (value is int) return Duration(milliseconds: value);
      if (value is double) return Duration(milliseconds: value.round());
    } catch (_) {}
    return null;
  }

  Future<String?> _saveEmbeddedCoverIfNeeded({
    required dynamic metadata,
    required String audioPath,
    required String coverDirPath,
  }) async {
    final pictures = _readPictures(metadata);
    if (pictures == null || pictures.isEmpty) return null;

    final picture = pictures.first;
    final bytes = _readPictureBytes(picture);
    if (bytes == null || bytes.isEmpty) return null;

    final ext = _pictureExtension(_readPictureMimeType(picture));
    final key = base64Url.encode(utf8.encode(audioPath)).replaceAll('=', '');
    final coverFile = File(p.join(coverDirPath, '$key.$ext'));

    if (!await coverFile.exists() || await coverFile.length() != bytes.length) {
      await coverFile.writeAsBytes(bytes, flush: false);
    }

    return coverFile.uri.toString();
  }

  List<dynamic>? _readPictures(dynamic metadata) {
    try {
      final value = metadata.pictures;
      if (value is List) return value;
    } catch (_) {}
    try {
      final value = metadata.picture;
      if (value is List) return value;
      if (value != null) return [value];
    } catch (_) {}
    return null;
  }

  Uint8List? _readPictureBytes(dynamic picture) {
    try {
      final value = picture.bytes;
      if (value is Uint8List) return value;
      if (value is List<int>) return Uint8List.fromList(value);
    } catch (_) {}
    try {
      final value = picture.data;
      if (value is Uint8List) return value;
      if (value is List<int>) return Uint8List.fromList(value);
    } catch (_) {}
    return null;
  }

  String? _readPictureMimeType(dynamic picture) {
    try {
      return picture.mimeType?.toString();
    } catch (_) {}
    try {
      return picture.mime?.toString();
    } catch (_) {}
    return null;
  }

  String _pictureExtension(String? mimeType) {
    final mime = mimeType?.toLowerCase() ?? '';
    if (mime.contains('png')) return 'png';
    if (mime.contains('webp')) return 'webp';
    return 'jpg';
  }

  Future<String?> _readSidecarLyric(String audioPath) async {
    final dir = p.dirname(audioPath);
    final name = p.basenameWithoutExtension(audioPath);
    final lrcFile = File(p.join(dir, '$name.lrc'));
    if (!await lrcFile.exists()) return null;

    try {
      final text = await lrcFile.readAsString(encoding: utf8);
      return _cleanText(text);
    } catch (_) {
      return null;
    }
  }
}

class _FilenameInfo {
  const _FilenameInfo({required this.title, this.artist});
  final String title;
  final String? artist;
}

void debugLogLocalMetadata(String message) {
  debugPrint(message);
}
