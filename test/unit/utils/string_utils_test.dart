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
  });
}
