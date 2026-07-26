/// Utility class for common string manipulation tasks.
class StringUtils {
  /// Cleans up common HTML entities from an input string.
  /// Examples: `&quot;` -> `"`, `&amp;` -> `&`, `<br/>` -> `\n`.
  static String cleanText(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'<br\s*\/?>'), '\n') // Replace all variations of <br> tags with newline
        .replaceAll('&nbsp;', ' ');
  }
}
