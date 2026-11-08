import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/services/equalizer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EqualizerService & Sound Engineering Tests', () {
    late EqualizerService eqService;

    setUp(() {
      eqService = EqualizerService();
    });

    test('Initializes with standard 10 ISO frequency bands', () {
      final state = eqService.state;
      expect(state.bands.length, 10);
      expect(state.bands[0].frequencyHz, 31);
      expect(state.bands[1].frequencyHz, 62);
      expect(state.bands[4].frequencyHz, 500);
      expect(state.bands[5].frequencyHz, 1000);
      expect(state.bands[9].frequencyHz, 16000);
      expect(state.isEnabled, false);
      expect(state.isLoudnessNormalizationEnabled, false);
    });

    test('Applies Flat preset with 0dB gain across all bands', () async {
      await eqService.applyPreset('flat', null);
      final state = eqService.state;
      expect(state.activePresetId, 'flat');
      for (final band in state.bands) {
        expect(band.gainDb, 0.0);
      }
      expect(eqService.buildFilterString(), isEmpty);
    });

    test('Applies Bass Boost preset with elevated low frequencies', () async {
      await eqService.applyPreset('bass_boost', null);
      final state = eqService.state;
      expect(state.activePresetId, 'bass_boost');
      expect(state.bands[0].gainDb, 6.0); // 31 Hz
      expect(state.bands[1].gainDb, 5.0); // 62 Hz
      expect(state.bassBoost, 6.0);
    });

    test('Clamps band gain within -12.0 dB to +12.0 dB limits', () async {
      await eqService.setBandGain(62, 25.0, null);
      expect(eqService.state.bands[1].gainDb, 12.0);

      await eqService.setBandGain(62, -30.0, null);
      expect(eqService.state.bands[1].gainDb, -12.0);
    });

    test('Synthesizes valid libmpv filter string with loudness normalization', () async {
      await eqService.setEnabled(true, null);
      await eqService.setLoudnessNormalization(true, null);
      await eqService.setBandGain(62, 4.0, null);

      final filterStr = eqService.buildFilterString();
      expect(filterStr, contains('loudnorm=I=-16:TP=-1.5:LRA=11'));
      expect(filterStr, contains('equalizer=f=62:width_type=o:w=1:g='));
    });

    test('Serializes and deserializes EqualizerState accurately', () {
      final state = EqualizerState(
        isEnabled: true,
        isLoudnessNormalizationEnabled: true,
        activePresetId: 'rock',
        bands: EqualizerService.defaultBands(),
        bassBoost: 3.5,
        trebleBoost: 2.0,
        preampGain: -1.5,
      );

      final json = state.toJson();
      final revived = EqualizerState.fromJson(json);

      expect(revived.isEnabled, true);
      expect(revived.isLoudnessNormalizationEnabled, true);
      expect(revived.activePresetId, 'rock');
      expect(revived.bassBoost, 3.5);
      expect(revived.trebleBoost, 2.0);
      expect(revived.preampGain, -1.5);
      expect(revived.bands.length, 10);
    });
  });
}
