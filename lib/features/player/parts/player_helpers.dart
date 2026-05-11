part of '../player_page.dart';

String _musicSourceLabel(MusicSourceType sourceType) {
  switch (sourceType) {
    case MusicSourceType.localFile:
      return 'source.local'.tr;
    case MusicSourceType.webDav:
      return 'WebDAV';
    case MusicSourceType.emby:
      return 'Emby';
    case MusicSourceType.jellyfin:
      return 'Jellyfin';
    case MusicSourceType.navidrome:
      return 'Navidrome';
    case MusicSourceType.directUrl:
      return 'common.networkMusic'.tr;
  }
}

Alignment _alignmentForTextAlign(TextAlign align) {
  switch (align) {
    case TextAlign.left:
    case TextAlign.start:
      return Alignment.centerLeft;
    case TextAlign.right:
    case TextAlign.end:
      return Alignment.centerRight;
    case TextAlign.center:
    default:
      return Alignment.center;
  }
}

class _SplitLyricLine {
  const _SplitLyricLine(this.primary, [this.secondary]);

  final String primary;
  final String? secondary;
}

final RegExp _cjkRegExp = RegExp(r'[\u3400-\u9FFF\uF900-\uFAFF]');
final RegExp _kanaRegExp = RegExp(r'[\u3040-\u30FF]');
final RegExp _latinRegExp = RegExp(r'[A-Za-z]');

int _scriptCount(String value, RegExp pattern) {
  var count = 0;
  for (final match in pattern.allMatches(value)) {
    count += match.group(0)?.length ?? 0;
  }
  return count;
}

bool _isMostlyLatin(String value) {
  final cleaned =
      value.replaceAll(RegExp(r'[^A-Za-z\u3400-\u9FFF\uF900-\uFAFF]'), '');
  if (cleaned.length < 4) return false;
  final latin = _scriptCount(cleaned, _latinRegExp);
  final cjk = _scriptCount(cleaned, _cjkRegExp);
  return latin >= 4 && cjk == 0;
}

bool _isMostlyCjk(String value) {
  final cleaned =
      value.replaceAll(RegExp(r'[^A-Za-z\u3400-\u9FFF\uF900-\uFAFF]'), '');
  if (cleaned.length < 2) return false;
  final latin = _scriptCount(cleaned, _latinRegExp);
  final cjk = _scriptCount(cleaned, _cjkRegExp);
  return cjk >= 2 && latin == 0;
}

bool _hasKana(String value) => _kanaRegExp.hasMatch(value);

bool _looksLikeChineseTranslation(String value) {
  final cleaned = value.replaceAll(
    RegExp(r'[^\u3400-\u9FFF\uF900-\uFAFF\u3040-\u30FF]'),
    '',
  );
  if (cleaned.length < 2) return false;
  return _cjkRegExp.hasMatch(cleaned) && !_kanaRegExp.hasMatch(cleaned);
}

bool _hasNaturalSplitBoundary(String value, int index) {
  final before = index > 0 ? value[index - 1] : '';
  final after = index < value.length ? value[index] : '';
  return RegExp(r'\s|[，。！？；：,.!?;:()（）「」『』《》\[\]]').hasMatch(before) ||
      RegExp(r'\s|[，。！？；：,.!?;:()（）「」『』《》\[\]]').hasMatch(after);
}

String _cleanLyricPart(String value) {
  return value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[·•\-–—|/]+$'), '')
      .trim();
}

/// 歌词展示文本只做清理，不再插入零宽空格。
///
/// 之前为了让超长英文 / URL 可换行，这里会主动插入 `\u200B`，
/// 但带翻译歌词会因此自动断行。现在统一交给 Text 的
/// `maxLines: 1 + overflow: ellipsis + softWrap: false` 单行省略。
String _safeLyricDisplayText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// 识别双语歌词的原文和翻译。
///
/// 注意：这里只负责识别，不负责换行显示。歌词列表会把原文和翻译
/// 拼成单行展示，超出宽度直接省略，避免带翻译歌词自动变成两行。
_SplitLyricLine _splitLyricLine(String text) {
  final hardLines = text
      .split(RegExp(r'\n+'))
      .map(_cleanLyricPart)
      .where((line) => line.isNotEmpty)
      .toList();

  if (hardLines.length >= 2) {
    return _SplitLyricLine(
      hardLines.first,
      hardLines.skip(1).join(' '),
    );
  }

  final normalized = _cleanLyricPart(text);
  if (normalized.isEmpty) return const _SplitLyricLine('');

  final hasCjk = _cjkRegExp.hasMatch(normalized);
  final hasKana = _kanaRegExp.hasMatch(normalized);
  final hasLatin = _latinRegExp.hasMatch(normalized);

  // 日文原文 + 中文翻译：两边都属于 CJK，不能只靠英文识别。
  // 一边含假名，另一边是纯中文时，也拆成上下两行。
  if (hasKana && hasCjk) {
    for (var i = 1; i < normalized.length; i++) {
      if (!_hasNaturalSplitBoundary(normalized, i)) continue;

      final left = _cleanLyricPart(normalized.substring(0, i));
      final right = _cleanLyricPart(normalized.substring(i));
      if (left.isEmpty || right.isEmpty) continue;

      final leftJapaneseRightChinese =
          _hasKana(left) && _looksLikeChineseTranslation(right);
      final leftChineseRightJapanese =
          _looksLikeChineseTranslation(left) && _hasKana(right);

      if (leftJapaneseRightChinese || leftChineseRightJapanese) {
        return _SplitLyricLine(left, right);
      }
    }
  }

  if (!hasCjk || !hasLatin) return _SplitLyricLine(normalized);

  // 只拆“明显的双语歌词”：一边主要是英文，另一边主要是中文，且中间有空格/标点边界。
  // 像“因为 MUSIC-MAN 的到来”这种中文句子中夹英文名词，不再误拆成翻译。
  for (var i = 1; i < normalized.length; i++) {
    if (!_hasNaturalSplitBoundary(normalized, i)) continue;

    final left = _cleanLyricPart(normalized.substring(0, i));
    final right = _cleanLyricPart(normalized.substring(i));
    if (left.isEmpty || right.isEmpty) continue;

    final leftLatinRightCjk = _isMostlyLatin(left) && _isMostlyCjk(right);
    final leftCjkRightLatin = _isMostlyCjk(left) && _isMostlyLatin(right);

    if (leftLatinRightCjk || leftCjkRightLatin) {
      return _SplitLyricLine(left, right);
    }
  }

  return _SplitLyricLine(normalized);
}

/// 将原文 + 翻译合成单行展示文本。
///
/// parseLrc 对同一时间戳的原文/翻译会用 \n 合并，
/// 这里统一改成空格连接，避免 UI 中出现第二行翻译。
String _singleLineLyricText(String text) {
  final split = _splitLyricLine(text);
  final parts = <String>[
    _safeLyricDisplayText(split.primary),
    if (split.secondary != null) _safeLyricDisplayText(split.secondary!),
  ].where((part) => part.isNotEmpty).toList();

  return parts.join('   ');
}

double _lyricRowHeightForText(
  String _, {
  required bool compactSingleLineRows,
}) {
  // 歌词列表统一单行：原文 + 翻译在同一行内展示，超出省略。
  // 不再因为有翻译而加高行高，避免视觉上变成“自动换行”。
  return compactSingleLineRows ? 60.0 : 68.0;
}
