import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:it_feels_music/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Test', () {
    testWidgets('Verify app launch and basic navigation', (WidgetTester tester) async {
      // Launch the app
      app.main([]);
      
      // Wait for the app to settle (might take longer due to initial API calls)
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify that the bottom navigation bar is present
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Verify Home tab is initially selected (look for some expected text or icon)
      // We can look for the Search icon in the bottom bar to tap it
      final searchTab = find.byIcon(Icons.search);
      expect(searchTab, findsOneWidget);

      // Tap on the Search tab
      await tester.tap(searchTab);
      await tester.pumpAndSettle();

      // Verify Search screen is now visible (e.g. look for TextField)
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Enter some text into the search field
      await tester.enterText(searchField, 'Arijit Singh');
      await tester.pumpAndSettle();

      // We expect the text to be entered
      expect(find.text('Arijit Singh'), findsOneWidget);
    });
  });
}
