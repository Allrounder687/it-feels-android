import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:it_feels_music/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore fakeFirestore;
  late SubscriptionService subscriptionService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeFirestore = FakeFirebaseFirestore();
    subscriptionService = SubscriptionService(firestore: fakeFirestore);
  });

  group('SubscriptionService Custom Coupons', () {
    test('redeemCustomCoupon fails when code does not exist', () async {
      final success = await subscriptionService.redeemCustomCoupon('user_123', 'INVALID_CODE');
      expect(success, isFalse);

      final doc = await fakeFirestore.collection('users').doc('user_123').collection('entitlements').doc('premium').get();
      expect(doc.exists, isFalse);
    });

    test('redeemCustomCoupon fails when coupon is inactive', () async {
      await fakeFirestore.collection('coupons').add({
        'code': 'EXPIRED2026',
        'isActive': false,
      });

      final success = await subscriptionService.redeemCustomCoupon('user_123', 'EXPIRED2026');
      expect(success, isFalse);
    });

    test('redeemCustomCoupon succeeds and sets entitlement for active coupon', () async {
      await fakeFirestore.collection('coupons').add({
        'code': 'FEELS2026',
        'isActive': true,
        'durationDays': 30,
      });

      final success = await subscriptionService.redeemCustomCoupon('user_123', 'FEELS2026');
      expect(success, isTrue);

      final doc = await fakeFirestore.collection('users').doc('user_123').collection('entitlements').doc('premium').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['isActive'], isTrue);
      expect(doc.data()!['grantedBy'], 'FEELS2026');
    });

    test('redeemCustomCoupon FAMILY unlocks lifetime premium without requiring pre-created Firestore doc', () async {
      final success = await subscriptionService.redeemCustomCoupon('user_family', 'FAMILY');
      expect(success, isTrue);

      final doc = await fakeFirestore.collection('users').doc('user_family').collection('entitlements').doc('premium').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['isActive'], isTrue);
      expect(doc.data()!['grantedBy'], 'FAMILY');
    });

    test('checkPremiumStatus returns true if Firestore entitlement is valid', () async {
      // Add a valid entitlement to the user
      final expiresAt = DateTime.now().add(const Duration(days: 10));
      await fakeFirestore.collection('users').doc('user_123').collection('entitlements').doc('premium').set({
        'isActive': true,
        'expiresAt': expiresAt,
        'grantedBy': 'FEELSFREE',
      });

      // Note: checkPremiumStatus will also try to check RevenueCat, but since kIsWeb isn't true here by default
      // and RevenueCat isn't initialized, it will throw an internal error and fall back to Firestore.
      final isPremium = await subscriptionService.checkPremiumStatus('user_123');
      expect(isPremium, isTrue);
    });
    
    test('checkPremiumStatus returns false if Firestore entitlement is expired', () async {
      // Add an expired entitlement to the user
      final expiresAt = DateTime.now().subtract(const Duration(days: 1));
      await fakeFirestore.collection('users').doc('user_123').collection('entitlements').doc('premium').set({
        'isActive': true,
        'expiresAt': expiresAt,
        'grantedBy': 'FEELSFREE',
      });

      final isPremium = await subscriptionService.checkPremiumStatus('user_123');
      expect(isPremium, isFalse);
    });

    test('checkPremiumStatus returns false for empty or unauthenticated uid', () async {
      final isPremium = await subscriptionService.checkPremiumStatus('');
      expect(isPremium, isFalse);
    });

    test('account-bound premium isolation: userA is premium, userB remains free tier', () async {
      // Grant premium to userA
      await subscriptionService.redeemCustomCoupon('userA', 'FAMILY');
      
      final isUserAPremium = await subscriptionService.checkPremiumStatus('userA');
      final isUserBPremium = await subscriptionService.checkPremiumStatus('userB');

      expect(isUserAPremium, isTrue);
      expect(isUserBPremium, isFalse);
    });
  });
}
