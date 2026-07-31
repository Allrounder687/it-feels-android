import 'package:it_feels_music/data/models/song_model.dart';

/// `LrcParser` is a utility class responsible for parsing raw LRC (LyRiCs) formatted
/// text into a structured list of [LyricLine] objects.
///
/// LRC files typically contain timestamps synchronized with song lyrics, enabling
/// real-time display and highlighting in music players.
class LrcParser {
  /// Parses a raw LRC text string into a list of [LyricLine] objects.
  /// Each [LyricLine] contains a [Duration] timestamp and the corresponding lyric [text].
  ///
  /// **LRC Format Support:**
  /// This parser supports standard LRC format where each line starts with a timestamp
  /// in the format `[mm:ss.xx]` or `[mm:ss]`, followed by the lyric text.
  ///
  /// Example Line: `[00:15.34]This is an example lyric line.`
  ///
  /// **Parameters:**
  /// - `lrcText`: The complete LRC content as a single string.
  ///
  /// **Returns:**
  /// A [List<LyricLine>] sorted in chronological order based on their timestamps.
  /// Returns an empty list if `lrcText` is empty or no valid lyric lines are found.
  ///
  /// **Process Flow:**
  /// 1.  Splits the input `lrcText` into individual lines.
  /// 2.  Iterates through each line, trimming whitespace and skipping empty lines.
  /// 3.  Uses a regular expression (`RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\](.*)')`)
  ///     to extract minutes, seconds, optional milliseconds, and the lyric text.
  ///     - `(\d+)`: Captures minutes (Group 1).
  ///     - `(\d+)`: Captures seconds (Group 2).
  ///     - `(?:\.(\d+))?`: Optionally captures milliseconds (Group 3), allowing for `[mm:ss]` format.
  ///     - `(.*)`: Captures the remaining text as the lyric (Group 4).
  /// 4.  Converts the captured time components into a [Duration] object.
  /// 5.  Creates a [LyricLine] object and adds it to the result list if the text is not empty.
  /// 6.  After processing all lines, the `result` list is sorted to ensure lyrics are in
  ///     chronological order, which is essential for proper synchronization during playback.
  ///
  /// **Error Handling:**
  /// - Malformed lines (that do not match the `RegExp`) are simply skipped.
  /// - Empty `lrcText` returns an empty list.
  static List<LyricLine> parse(String lrcText) {
    if (lrcText.isEmpty) return [];

    final lines = lrcText.split('\n');
    final List<LyricLine> result = [];
    // Regular expression to match LRC timestamp format [mm:ss.xx] and capture text
    final regExp = RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\](.*)');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      final match = regExp.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        // Milliseconds are optional and can be 2 or 3 digits. Pad and take first 3 if present.
        final millisStr = match.group(3) ?? '0';
        final millis = int.parse(millisStr.padRight(3, '0').substring(0, 3));
        final text = match.group(4)!.trim();

        final time = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );

        // Only add if there's actual lyric text
        if (text.isNotEmpty) {
          result.add(LyricLine(time: time, text: text));
        }
      }
    }

    // Ensure lyrics are sorted by time, crucial for correct display and synchronization
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }
}
