/// Utility class for common string manipulation tasks.
class StringUtils {
  /// Cleans up common HTML entities and UTF-8 mojibake from an input string.
  /// Examples: `&quot;` -> `"`, `&amp;` -> `&`, `<br/>` -> `\n`, `Ã¢â‚¬Â¢` -> `•`.
  static String cleanText(String input) {
    if (input.isEmpty) return input;
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'<br\s*\/?>'), '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&bull;', '•')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        // Fix double-UTF8 / Latin-1 Mojibake common in Saavn / web metadata
        .replaceAll('Ã¢â‚¬Â¢', ' • ')
        .replaceAll('â‚¬Â¢', ' • ')
        .replaceAll('â€¢', ' • ')
        .replaceAll('Ã¢â‚¬â„¢', "'")
        .replaceAll('â€™', "'")
        .replaceAll('Ã¢â‚¬Å“', '"')
        .replaceAll('Ã¢â‚¬Â', '"')
        .replaceAll('â€œ', '"')
        .replaceAll('â€', '"')
        .replaceAll('Ã¢â‚¬â€œ', '–')
        .replaceAll('Ã¢â‚¬â€”', '—')
        .replaceAll('â€“', '–')
        .replaceAll('â€”', '—')
        .replaceAll('Ã¢â‚¬Â¦', '…')
        .replaceAll('â€¦', '…')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}
