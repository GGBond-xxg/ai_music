class LyricLine {
  const LyricLine({required this.time, required this.text});
  final Duration time;
  final String text;
}

class _LyricGroup {
  _LyricGroup(this.time);

  final Duration time;
  final List<String> texts = [];
}

List<LyricLine> parseLrc(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];

  final groups = <int, _LyricGroup>{};
  // 支持 [01:23.45] / [01:23.456] / [01:23]，也支持一行多个时间标签。
  final timestampReg = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?\]');

  void addLine(Duration time, String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    final key = time.inMilliseconds;
    final group = groups.putIfAbsent(key, () => _LyricGroup(time));

    // 有些内嵌歌词会把同一时间戳的原文和翻译分成两行：
    // [00:07.00]振りかえれば 皆んな ほら
    // [00:07.00]回头看的话，看啊，大家
    // 这里合并成一条 LyricLine，用 \n 保留上下两行，避免 activeIndex 只命中最后一行。
    if (!group.texts.contains(cleaned)) {
      group.texts.add(cleaned);
    }
  }

  for (final row in raw.split(RegExp(r'\r?\n'))) {
    final trimmed = row.trim();
    if (trimmed.isEmpty) continue;

    final matches = timestampReg.allMatches(trimmed).toList();
    if (matches.isEmpty) continue;

    // 一行可能有多个时间标签：[00:10][00:20]歌词
    final text = trimmed.replaceAll(timestampReg, '').trim();
    if (text.isEmpty) continue;

    for (final match in matches) {
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final msRaw = match.group(3) ?? '0';
      final milliseconds = int.parse(msRaw.padRight(3, '0').substring(0, 3));
      addLine(
        Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        ),
        text,
      );
    }
  }

  final lines = groups.values
      .map(
        (group) => LyricLine(
          time: group.time,
          text: group.texts.join('\n'),
        ),
      )
      .toList();

  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}

List<String> parsePlainLyrics(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];

  final result = <String>[];
  final timestampReg = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?\]');
  final metaReg = RegExp(r'^\[(ti|ar|al|by|offset):.*\]$', caseSensitive: false);

  for (final row in raw.split(RegExp(r'\r?\n'))) {
    var text = row.trim();
    if (text.isEmpty) continue;
    if (metaReg.hasMatch(text)) continue;
    text = text.replaceAll(timestampReg, '').trim();
    if (text.isNotEmpty) result.add(text);
  }

  return result;
}
