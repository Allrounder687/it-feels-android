import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pixel_player_saavn/data/services/audio_player_handler.dart';
import 'package:pixel_player_saavn/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});

  testWidgets('PixelPlayerSaavnApp smoke test', (WidgetTester tester) async {
    final handler = AudioPlayerHandler();
    await tester.pumpWidget(PixelPlayerSaavnApp(audioHandler: handler));
    await tester.pump();
    expect(find.byType(PixelPlayerSaavnApp), findsOneWidget);
  });
}

