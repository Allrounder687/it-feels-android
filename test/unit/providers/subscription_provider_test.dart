import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/subscription/subscription_provider.dart';
import 'package:it_feels_music/services/subscription_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockSubscriptionService extends Mock implements SubscriptionService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockSubscriptionService mockSubscriptionService;

  setUpAll(() {
    // Mock the RevenueCat method channel so `Purchases` static calls don't crash
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('purchases_flutter'), (MethodCall methodCall) async {
      if (methodCall.method == 'setupPurchases') {
        return null;
      }
      return null;
    });
  });

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockSubscriptionService = MockSubscriptionService();

    when(() => mockUser.uid).thenReturn('user123');
    when(() => mockUser.isAnonymous).thenReturn(false);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockAuth.authStateChanges()).thenAnswer((_) => Stream.value(mockUser));

    when(() => mockSubscriptionService.initialize(any())).thenAnswer((_) async {});
    when(() => mockSubscriptionService.login(any())).thenAnswer((_) async {});
    when(() => mockSubscriptionService.logout()).thenAnswer((_) async {});

    if (locator.isRegistered<FirebaseAuth>()) {
      locator.unregister<FirebaseAuth>();
    }
    if (locator.isRegistered<FirebaseFirestore>()) {
      locator.unregister<FirebaseFirestore>();
    }
    locator.registerSingleton<FirebaseAuth>(mockAuth);
    locator.registerSingleton<FirebaseFirestore>(FakeFirebaseFirestore());
  });

  group('SubscriptionProvider Tests', () {
    test('initializes and checks status on creation', () async {
      when(() => mockSubscriptionService.checkPremiumStatus('user123'))
          .thenAnswer((_) async => true);

      final provider = SubscriptionProvider(service: mockSubscriptionService);
      
      // Wait for async _init
      await Future.delayed(Duration.zero);
      
      expect(provider.isPremium, true);
      expect(provider.isLoading, false);
      
      verify(() => mockSubscriptionService.initialize('user123')).called(1);
      verify(() => mockSubscriptionService.checkPremiumStatus('user123')).called(2);
    });

    test('redeemCoupon updates premium state on success', () async {
      when(() => mockSubscriptionService.checkPremiumStatus('user123'))
          .thenAnswer((_) async => false);
          
      final provider = SubscriptionProvider(service: mockSubscriptionService);
      await Future.delayed(Duration.zero);
      expect(provider.isPremium, false);

      when(() => mockSubscriptionService.redeemCustomCoupon('user123', 'FEELS2026'))
          .thenAnswer((_) async => true);

      final success = await provider.redeemCoupon('FEELS2026');
      
      expect(success, true);
      expect(provider.isPremium, true);
      expect(provider.isLoading, false);
    });
  });
}
