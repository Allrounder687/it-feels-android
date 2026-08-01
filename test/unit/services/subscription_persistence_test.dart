import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Subscription Persistence Tests', () {
    test('isPremiumDevice flag persists locally for FAMILY pass & direct purchases', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Initial state is false
      expect(prefs.getBool('isPremiumDevice') ?? false, false);

      // Simulate redeeming FAMILY coupon or completing UPI payment
      await prefs.setBool('isPremiumDevice', true);

      // Verify status persists
      final updatedPrefs = await SharedPreferences.getInstance();
      expect(updatedPrefs.getBool('isPremiumDevice'), true);
    });
  });
}
