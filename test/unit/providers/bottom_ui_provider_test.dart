import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';

void main() {
  group('BottomUiNotifier Tests', () {
    testWidgets('updateHeight updates state via post frame callback if delta > 1', (tester) async {
      late ProviderContainer container;
      
      await tester.pumpWidget(
        ProviderScope(
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      final notifier = container.read(bottomUiProvider.notifier);
      expect(container.read(bottomUiProvider), 0.0);

      // Call update height with a significant delta
      notifier.updateHeight(50.0);
      
      // Initially not updated (waiting for post frame callback)
      expect(container.read(bottomUiProvider), 0.0);

      // Pump a frame to execute the callback
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(bottomUiProvider), 50.0);

      // Call update height with an insignificant delta
      notifier.updateHeight(50.5);
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 100));
      
      // Should not have updated
      expect(container.read(bottomUiProvider), 50.0);
    });
  });

  group('MeasureSize Widget Tests', () {
    testWidgets('triggers onChange when child size changes', (tester) async {
      Size? reportedSize;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MeasureSize(
                onChange: (size) {
                  reportedSize = size;
                },
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      expect(reportedSize, const Size(100, 100));
    });
  });
}
