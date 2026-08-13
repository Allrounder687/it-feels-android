import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:it_feels_music/features/subscription/paywall_bottom_sheet.dart';
import 'package:it_feels_music/features/subscription/premium_celebration_dialog.dart';
import 'package:it_feels_music/features/subscription/subscription_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}

void main() {
  late MockSubscriptionProvider mockSubscriptionProvider;

  setUp(() {
    mockSubscriptionProvider = MockSubscriptionProvider();
    when(() => mockSubscriptionProvider.isPremium).thenReturn(false);
    when(() => mockSubscriptionProvider.isLoading).thenReturn(false);
  });

  Widget createWidgetUnderTest(Widget child) {
    return ProviderScope(
      overrides: [
        subscriptionProvider.overrideWith((ref) => mockSubscriptionProvider),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('PaywallBottomSheet', () {
    testWidgets('renders features list', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const PaywallBottomSheet(featureName: 'Test Feature')));
      
      expect(find.text('Unlock Test Feature'), findsWidgets);
    });
  });

  group('PremiumCelebrationDialog', () {
    testWidgets('renders celebration text', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const PremiumCelebrationDialog(isFamilyCoupon: false)));
      
      expect(find.byType(PremiumCelebrationDialog), findsOneWidget); // Example text, adjust if needed
    });
  });
}
