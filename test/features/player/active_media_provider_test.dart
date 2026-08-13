import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/player/active_media_provider.dart';

void main() {
  group('ActiveMediaNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is ActiveMediaType.none', () {
      final state = container.read(activeMediaProvider);
      expect(state, equals(ActiveMediaType.none));
    });

    test('setActiveMedia updates the state correctly', () {
      final notifier = container.read(activeMediaProvider.notifier);

      notifier.setActiveMedia(ActiveMediaType.audio);
      expect(container.read(activeMediaProvider), equals(ActiveMediaType.audio));

      notifier.setActiveMedia(ActiveMediaType.video);
      expect(container.read(activeMediaProvider), equals(ActiveMediaType.video));
    });

    test('setActiveMedia ignores duplicate state transitions', () {
      final notifier = container.read(activeMediaProvider.notifier);
      int listenerCount = 0;

      container.listen(activeMediaProvider, (prev, next) {
        listenerCount++;
      }, fireImmediately: false);

      notifier.setActiveMedia(ActiveMediaType.audio);
      expect(listenerCount, equals(1));

      // Duplicate call should not trigger listener again
      notifier.setActiveMedia(ActiveMediaType.audio);
      expect(listenerCount, equals(1));
    });
  });
}
