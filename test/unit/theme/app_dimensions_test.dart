import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/theme/app_dimensions.dart';

void main() {
  group('AppDimensions', () {
    testWidgets('getBottomNavPadding returns correct padding based on viewPadding', (tester) async {
      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              viewPadding: EdgeInsets.only(bottom: 24.0),
            ),
            child: Builder(
              builder: (context) {
                testContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final padding = AppDimensions.getBottomNavPadding(testContext);

      expect(padding.left, 16.0);
      expect(padding.top, 16.0);
      expect(padding.right, 16.0);
      expect(padding.bottom, AppDimensions.bottomClearance + 24.0);
    });
  });
}
