import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:it_feels_music/features/social/unread_count_provider.dart';

class MockSocialService extends Mock implements SocialService {}

void main() {
  late MockSocialService mockSocialService;

  setUp(() {
    mockSocialService = MockSocialService();
    if (locator.isRegistered<SocialService>()) {
      locator.unregister<SocialService>();
    }
    locator.registerSingleton<SocialService>(mockSocialService);
  });

  group('UnreadCountProvider Tests', () {
    testWidgets('emits unread counts from social service stream', (tester) async {
      final streamController = StreamController<int>();
      when(() => mockSocialService.getUnreadCountStream())
          .thenAnswer((_) => streamController.stream);

      final container = ProviderContainer();
      
      // Initially loading
      expect(container.read(unreadCountProvider).isLoading, true);

      // Emit a value
      streamController.add(5);
      await tester.pump();
      
      expect(container.read(unreadCountProvider).value, 5);
      
      // Emit another value
      streamController.add(10);
      await tester.pump();
      
      expect(container.read(unreadCountProvider).value, 10);

      streamController.close();
      container.dispose();
    });
  });
}
