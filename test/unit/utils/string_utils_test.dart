import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';

void main() {
  test('StringUtils.cleanText cleans double UTF-8 / mojibake', () {
    expect(
      StringUtils.cleanText('Polina Cherkas Ã¢â‚¬Â¢ Believer'),
      'Polina Cherkas • Believer',
    );
    expect(
      StringUtils.cleanText('Itâ€™s Alright &quot;Baby&quot;'),
      'It\'s Alright "Baby"',
    );
    expect(
      StringUtils.cleanText('Song &#039;Title&#039; &amp;#039;Test&amp;#039;'),
      "Song 'Title' 'Test'",
    );
    expect(
      StringUtils.cleanText('Unicode &#8217;Quotes&#8217; &#x27;Hex&#x27;'),
      "Unicode ’Quotes’ 'Hex'",
    );
    expect(
      StringUtils.cleanText('Hindi Text: दिल दियां गल्लां'),
      'Hindi Text: दिल दियां गल्लां',
    );
  });
}
