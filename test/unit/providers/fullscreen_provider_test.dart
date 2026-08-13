import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/providers/fullscreen_provider.dart';

void main() {
  group('FullscreenProvider Tests', () {
    test('initial state is false', () {
      final container = ProviderContainer();
      
      expect(container.read(fullscreenProvider), false);
    });

    test('state can be toggled to true and back to false', () {
      final container = ProviderContainer();
      
      container.read(fullscreenProvider.notifier).state = true;
      expect(container.read(fullscreenProvider), true);

      container.read(fullscreenProvider.notifier).state = false;
      expect(container.read(fullscreenProvider), false);
    });
  });
}
