import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/widgets/wavy_seek_bar.dart';

void main() {
  group('WavySeekBar', () {
    testWidgets('renders Slider correctly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WavySeekBar(
                position: Duration(seconds: 30),
                duration: Duration(seconds: 120),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('handles seeking', (tester) async {
      Duration? soughtPosition;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WavySeekBar(
                position: const Duration(seconds: 30),
                duration: const Duration(seconds: 120),
                onSeek: (pos) {
                  soughtPosition = pos;
                },
              ),
            ),
          ),
        ),
      );

      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);

      // Simulate dragging the slider to the middle
      await tester.tap(slider);
      await tester.pumpAndSettle();

      expect(soughtPosition, isNotNull);
      // Depending on the exact pixel tapped, it should be around 60 seconds (half of 120)
      expect(soughtPosition!.inSeconds, closeTo(60, 5));
    });
  });
}
