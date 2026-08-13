import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/widgets/animated_equalizer.dart';

void main() {
  group('AnimatedEqualizer', () {
    testWidgets('AnimatedEqualizer renders and animates', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedEqualizer(color: Colors.red),
          ),
        ),
      );

      // Verify the widget is in the tree
      expect(find.byType(AnimatedEqualizer), findsOneWidget);

      // Pump frames to ensure it doesn't crash during animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      
      // We don't use pumpAndSettle because the animation repeats infinitely and it would timeout
    });
  });
}
