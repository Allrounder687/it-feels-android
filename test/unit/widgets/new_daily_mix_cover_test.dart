import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/features/new_experience/widgets/new_daily_mix_cover.dart';
import 'package:it_feels_music/features/new_experience/widgets/new_card.dart';

void main() {
  group('NewDailyMixCover Widget Tests', () {
    testWidgets('renders Mix 1 Bollywood Romance with procedural cover correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NewDailyMixCover(
              mixIndex: 1,
              title: 'Bollywood Romance',
              subtitle: 'Arijit Singh, Pritam',
              width: 154,
              height: 154,
            ),
          ),
        ),
      );

      // Verify mix numeral
      expect(find.text('1'), findsOneWidget);
      // Verify header pill
      expect(find.text('DAILY MIX'), findsOneWidget);
      // Verify genre tag
      expect(find.text('ROMANCE'), findsOneWidget);
      // Verify CustomPaint for vinyl grooves
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders all 6 Mix presets with their respective genre tags', (tester) async {
      const expectedTags = [
        'ROMANCE',
        'INTERNATIONAL',
        'PUNJABI',
        'HIP-HOP',
        'ACOUSTIC',
        'CLUB & PARTY',
      ];

      for (int i = 1; i <= 6; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NewDailyMixCover(
                mixIndex: i,
                width: 154,
                height: 154,
              ),
            ),
          ),
        );

        expect(find.text('$i'), findsOneWidget);
        expect(find.text(expectedTags[i - 1]), findsOneWidget);
      }
    });

    testWidgets('integrates seamlessly with NewCard via customArtwork property', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewCard(
              title: 'Desi Hip-Hop',
              subtitle: 'DIVINE, Seedhe Maut',
              customArtwork: const NewDailyMixCover(
                mixIndex: 4,
                width: 154,
                height: 154,
              ),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // Verify title & subtitle
      expect(find.text('Desi Hip-Hop'), findsOneWidget);
      expect(find.text('DIVINE, Seedhe Maut'), findsOneWidget);
      // Verify customArtwork was rendered inside NewCard
      expect(find.byType(NewDailyMixCover), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('HIP-HOP'), findsOneWidget);

      // Tap test
      await tester.tap(find.text('Desi Hip-Hop'));
      expect(tapped, isTrue);
    });
  });
}
