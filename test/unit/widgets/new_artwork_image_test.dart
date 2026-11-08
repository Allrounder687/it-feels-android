import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/features/new_experience/widgets/new_artwork_image.dart';

void main() {
  group('NewArtworkImage Tests', () {
    testWidgets('renders fallback placeholder container when imageUrl is null or empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NewArtworkImage(
              imageUrl: null,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('renders fallback placeholder when imageUrl is an empty string', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NewArtworkImage(
              imageUrl: '',
              width: 80,
              height: 80,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('handles custom borderRadius and size gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NewArtworkImage(
              imageUrl: null,
              width: 120,
              height: 120,
              borderRadius: BorderRadius.all(Radius.circular(16)),
              iconSize: 40,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.music_note_rounded));
      expect(icon.size, 40);
    });

    testWidgets('renders gracefully without crashing when width or height is double.infinity', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NewArtworkImage(
              imageUrl: 'https://example.com/banner.jpg',
              width: double.infinity,
              height: 170,
            ),
          ),
        ),
      );

      // Successfully built without "Unsupported operation: Infinity or NaN toInt"
      expect(find.byType(NewArtworkImage), findsOneWidget);
    });
  });
}
