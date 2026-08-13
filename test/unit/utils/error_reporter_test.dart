import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_feels_music/core/utils/error_reporter.dart';

void main() {
  group('ErrorReporter Tests', () {
    testWidgets('showError displays a red SnackBar with correct message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ErrorReporter.showError(context, 'Test error message');
                  },
                  child: const Text('Trigger Error'),
                );
              },
            ),
          ),
        ),
      );

      // Verify no SnackBar is present initially
      expect(find.byType(SnackBar), findsNothing);

      // Trigger error presentation
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(); // Start presentation animation

      // Assert SnackBar is shown with the correct message
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Test error message'), findsOneWidget);

      // Verify that the SnackBar is red
      final SnackBar snackBar = tester.widget(find.byType(SnackBar));
      expect(snackBar.backgroundColor, Colors.red);
    });
  });
}
