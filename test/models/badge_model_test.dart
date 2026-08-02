import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/models/badge_model.dart';

void main() {
  group('BadgeModel Tests', () {
    test('allBadges list is not empty', () {
      expect(BadgeModel.allBadges, isNotEmpty);
    });

    test('getById returns correct badge for valid ID', () {
      final platinumEarBadge = BadgeModel.getById('platinum_ear');
      expect(platinumEarBadge, isNotNull);
      expect(platinumEarBadge?.name, 'Platinum Ear');
    });

    test('getById returns null for invalid ID', () {
      final nonExistentBadge = BadgeModel.getById('non_existent');
      expect(nonExistentBadge, isNull);
    });

    test('BadgeModel properties are correctly assigned', () {
      const badge = BadgeModel(
        id: 'test_id',
        name: 'Test Badge',
        description: 'A badge for testing',
        imagePath: 'assets/test.jpg',
        colorHex: '#FFFFFF',
      );

      expect(badge.id, 'test_id');
      expect(badge.name, 'Test Badge');
      expect(badge.description, 'A badge for testing');
      expect(badge.imagePath, 'assets/test.jpg');
      expect(badge.colorHex, '#FFFFFF');
    });
  });
}
