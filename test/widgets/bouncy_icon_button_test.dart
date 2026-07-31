import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/widgets/bouncy_icon_button.dart';

void main() {
  testWidgets('BouncyIconButton triggers onPressed when tapped', (WidgetTester tester) async {
    bool wasPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BouncyIconButton(
            onPressed: () {
              wasPressed = true;
            },
            child: const Icon(Icons.play_arrow),
          ),
        ),
      ),
    );

    expect(find.byType(Icon), findsOneWidget);

    await tester.tap(find.byType(BouncyIconButton));
    await tester.pumpAndSettle();

    expect(wasPressed, true);
  });

  testWidgets('BouncyIconButton scales down on tap down', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BouncyIconButton(
            onPressed: () {},
            child: const Icon(Icons.play_arrow),
          ),
        ),
      ),
    );

    final scaleTransitionFinder = find.descendant(of: find.byType(BouncyIconButton), matching: find.byType(ScaleTransition));
    expect(scaleTransitionFinder, findsOneWidget);

    // Initial scale should be 1.0
    ScaleTransition scaleTransition = tester.widget(scaleTransitionFinder);
    expect(scaleTransition.scale.value, 1.0);

    // Press down
    final gesture = await tester.startGesture(tester.getCenter(find.byType(BouncyIconButton)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50)); // Advance animation

    scaleTransition = tester.widget(scaleTransitionFinder);
    expect(scaleTransition.scale.value, lessThan(1.0)); // Should be scaling down

    // Release
    await gesture.up();
    await tester.pumpAndSettle();

    scaleTransition = tester.widget(scaleTransitionFinder);
    expect(scaleTransition.scale.value, 1.0); // Should be back to 1.0
  });
}
