import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:it_feels_music/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late SubscriptionService subscriptionService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    when(() => mockAuth.currentUser).thenReturn(null); // return null by default for proxy bypass
    subscriptionService = SubscriptionService(firestore: fakeFirestore, auth: mockAuth);
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

  });
}
