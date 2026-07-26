class HinglishTransliterator {
  static const Map<String, String> _vowels = {
    'अ': 'a',
    'आ': 'aa',
    'इ': 'i',
    'ई': 'ee',
    'उ': 'u',
    'ऊ': 'oo',
    'ऋ': 'ri',
    'ए': 'e',
    'ऐ': 'ai',
    'ओ': 'o',
    'औ': 'au',
    'अं': 'an',
    'अः': 'ah',
  };

  static const Map<String, String> _matras = {
    'ा': 'a',
    'ि': 'i',
    'ी': 'ee',
    'ु': 'u',
    'ू': 'oo',
    'ृ': 'ri',
    'े': 'e',
    'ै': 'ai',
    'ो': 'o',
    'ौ': 'au',
    'ं': 'n',
    'ँ': 'n',
    'ः': 'h',
  };

  static const Map<String, String> _consonants = {
    'क': 'k',
    'ख': 'kh',
    'ग': 'g',
    'घ': 'gh',
    'ङ': 'n',
    'च': 'ch',
    'छ': 'chh',
    'ज': 'j',
    'झ': 'jh',
    'ञ': 'n',
    'ट': 't',
    'ठ': 'th',
    'ड': 'd',
    'ढ': 'dh',
    'ण': 'n',
    'त': 't',
    'थ': 'th',
    'द': 'd',
    'ध': 'dh',
    'न': 'n',
    'प': 'p',
    'फ': 'ph',
    'ब': 'b',
    'भ': 'bh',
    'म': 'm',
    'य': 'y',
    'र': 'r',
    'ल': 'l',
    'व': 'v',
    'श': 'sh',
    'ष': 'sh',
    'स': 's',
    'ह': 'h',
    'क़': 'q',
    'ख़': 'kh',
    'ग़': 'g',
    'ज़': 'z',
    'ड़': 'd',
    'ढ़': 'dh',
    'फ़': 'f',
  };

  /// Check if text contains Devanagari characters
  static bool hasDevanagari(String text) {
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }

  /// Transliterate Devanagari text to Romanized Hinglish
  static String transliterate(String text) {
    if (!hasDevanagari(text)) return text;

    final StringBuffer buffer = StringBuffer();
    final chars = text.runes.map((r) => String.fromCharCode(r)).toList();

    for (int i = 0; i < chars.length; i++) {
      final ch = chars[i];

      if (_vowels.containsKey(ch)) {
        buffer.write(_vowels[ch]);
      } else if (_consonants.containsKey(ch)) {
        final base = _consonants[ch]!;
        // Check if next char is a matra or halant
        bool hasNextMatra = false;
        bool hasHalant = false;

        if (i + 1 < chars.length) {
          final next = chars[i + 1];
          if (_matras.containsKey(next)) {
            hasNextMatra = true;
          } else if (next == '्') {
            hasHalant = true;
          }
        }

        buffer.write(base);

        if (!hasNextMatra && !hasHalant) {
          // Check if it's end of word
          final isEnd = (i + 1 >= chars.length) || chars[i + 1] == ' ' || chars[i + 1] == '\n';
          if (!isEnd) {
            buffer.write('a');
          }
        }
      } else if (_matras.containsKey(ch)) {
        buffer.write(_matras[ch]);
      } else if (ch == '्') {
        // Halant suppresses preceding inherent 'a'
      } else {
        buffer.write(ch);
      }
    }

    return buffer.toString();
  }
}
