import '../../data/models/song_model.dart';

class LrcParser {
  /// Parse raw LRC text into a list of [LyricLine] sorted by time
  static List<LyricLine> parse(String lrcText) {
    if (lrcText.isEmpty) return [];

    final lines = lrcText.split('\n');
    final List<LyricLine> result = [];
    final regExp = RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\](.*)');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      final match = regExp.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisStr = match.group(3) ?? '0';
        final millis = int.parse(millisStr.padRight(3, '0').substring(0, 3));
        final text = match.group(4)!.trim();

        final time = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );

        if (text.isNotEmpty) {
          result.add(LyricLine(time: time, text: text));
        }
      }
    }

    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }
}
