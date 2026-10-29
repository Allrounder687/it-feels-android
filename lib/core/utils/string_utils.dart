/// Utility class for common string manipulation tasks.
class StringUtils {
  static final RegExp _numericEntityRegex = RegExp(r'&#(\d+);');
  static final RegExp _hexEntityRegex = RegExp(r'&#x([0-9a-fA-F]+);', caseSensitive: false);
  static final RegExp _brRegex = RegExp(r'<br\s*\/?>', caseSensitive: false);
  static final RegExp _doubleSpacesRegex = RegExp(r'\s{2,}');

  /// Cleans up HTML entities, numeric character references, and UTF-8 mojibake.
  static String cleanText(String input) {
    if (input.isEmpty) return input;
    
    var result = input
        // Double-encoded entities
        .replaceAll('&amp;#039;', "'")
        .replaceAll('&amp;#39;', "'")
        .replaceAll('&amp;quot;', '"')
        .replaceAll('&amp;amp;', '&')
        .replaceAll('&amp;lt;', '<')
        .replaceAll('&amp;gt;', '>')
        .replaceAll('&amp;apos;', "'")
        // Standard named HTML entities
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&bull;', '•')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"')
        .replaceAll('&hellip;', '…')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™')
        .replaceAll(_brRegex, '\n');

    // Decode decimal numeric entities like &#8217; or &#39;
    result = result.replaceAllMapped(_numericEntityRegex, (match) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code != null && code > 0) {
        return String.fromCharCode(code);
      }
      return match.group(0)!;
    });

    // Decode hexadecimal numeric entities like &#x27; or &#x2019;
    result = result.replaceAllMapped(_hexEntityRegex, (match) {
      final code = int.tryParse(match.group(1) ?? '', radix: 16);
      if (code != null && code > 0) {
        return String.fromCharCode(code);
      }
      return match.group(0)!;
    });

    // Fix double-UTF8 / Latin-1 Mojibake common in web metadata
    result = result
        .replaceAll('Ã¢â‚¬Â¢', ' • ')
        .replaceAll('â‚¬Â¢', ' • ')
        .replaceAll('â€¢', ' • ')
        .replaceAll('Ã¢â‚¬â„¢', "'")
        .replaceAll('â€™', "'")
        .replaceAll('â€˜', "'")
        .replaceAll('Ã¢â‚¬Å“', '"')
        .replaceAll('Ã¢â‚¬Â', '"')
        .replaceAll('â€œ', '"')
        .replaceAll('â€', '"')
        .replaceAll('Ã¢â‚¬â€œ', '–')
        .replaceAll('Ã¢â‚¬â€”', '—')
        .replaceAll('â€“', '–')
        .replaceAll('â€”', '—')
        .replaceAll('Ã¢â‚¬Â¦', '…')
        .replaceAll('â€¦', '…')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã¨', 'è')
        .replaceAll('Ã¡', 'á')
        .replaceAll('Ã ', 'à')
        .replaceAll('Ã³', 'ó')
        .replaceAll('Ã±', 'ñ')
        .replaceAll('Ã§', 'ç')
        .replaceAll(_doubleSpacesRegex, ' ')
        .trim();

    return result;
  }
}
