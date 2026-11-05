import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/models/keyboard_shortcut_models.dart';
import 'package:it_feels_music/core/utils/windows_shortcut_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('KeyboardShortcutCombination Tests', () {
    test('displayLabel formats keys and modifiers accurately', () {
      const combo1 = KeyboardShortcutCombination(
        keyId: 0x00000020,
        keyLabel: 'Space',
      );
      expect(combo1.displayLabel, 'Space');

      const combo2 = KeyboardShortcutCombination(
        keyId: 0x00100000105,
        keyLabel: 'Arrow Right',
        ctrl: true,
      );
      expect(combo2.displayLabel, 'Ctrl + →');

      const combo3 = KeyboardShortcutCombination(
        keyId: 0x00000070,
        keyLabel: 'P',
        ctrl: true,
        alt: true,
        shift: true,
      );
      expect(combo3.displayLabel, 'Ctrl + Alt + Shift + P');

      const combo4 = KeyboardShortcutCombination(
        keyId: 0x0000006c,
        keyLabel: 'L',
        meta: true,
      );
      expect(combo4.displayLabel, 'Win + L');
    });

    test('toJson and fromJson preserves all attributes', () {
      const original = KeyboardShortcutCombination(
        keyId: 12345,
        keyLabel: 'K',
        ctrl: true,
        alt: false,
        shift: true,
        meta: false,
      );

      final json = original.toJson();
      final parsed = KeyboardShortcutCombination.fromJson(json);

      expect(parsed, equals(original));
      expect(parsed.keyId, 12345);
      expect(parsed.keyLabel, 'K');
      expect(parsed.ctrl, isTrue);
      expect(parsed.shift, isTrue);
      expect(parsed.alt, isFalse);
      expect(parsed.meta, isFalse);
    });

    test('equality and hashCode match correctly', () {
      const comboA = KeyboardShortcutCombination(keyId: 100, keyLabel: 'A', ctrl: true);
      const comboB = KeyboardShortcutCombination(keyId: 100, keyLabel: 'A', ctrl: true);
      const comboC = KeyboardShortcutCombination(keyId: 100, keyLabel: 'A', ctrl: false);

      expect(comboA == comboB, isTrue);
      expect(comboA.hashCode == comboB.hashCode, isTrue);
      expect(comboA == comboC, isFalse);
    });
  });

  group('PlayerAction Defaults Tests', () {
    test('All player actions have unique IDs and valid default combinations', () {
      final ids = <String>{};
      for (final action in PlayerAction.values) {
        expect(ids.add(action.id), isTrue, reason: 'Duplicate action ID found: ${action.id}');
        final defaultCombo = action.defaultCombination;
        expect(defaultCombo.keyId, isNonZero);
        expect(defaultCombo.keyLabel, isNotEmpty);
      }
    });

    test('PlayerAction.fromId matches valid IDs', () {
      expect(PlayerAction.fromId('play_pause'), PlayerAction.playPause);
      expect(PlayerAction.fromId('next_track'), PlayerAction.nextTrack);
      expect(PlayerAction.fromId('volume_up'), PlayerAction.volumeUp);
      expect(PlayerAction.fromId('non_existent'), isNull);
    });
  });

  group('WindowsShortcutDetector Tests', () {
    test('Detects internal overlap when combination is already assigned', () {
      const combo = KeyboardShortcutCombination(
        keyId: 0x00100000105,
        keyLabel: 'Arrow Right',
        ctrl: true,
      );

      final currentBindings = {
        PlayerAction.nextTrack: combo,
        PlayerAction.previousTrack: const KeyboardShortcutCombination(
          keyId: 0x00100000104,
          keyLabel: 'Arrow Left',
          ctrl: true,
        ),
      };

      // Trying to assign the same combo to seekForward
      final conflict = WindowsShortcutDetector.checkConflict(
        combo,
        currentAction: PlayerAction.seekForward,
        allBindings: currentBindings,
      );

      expect(conflict.hasConflict, isTrue);
      expect(conflict.severity, ConflictSeverity.warning);
      expect(conflict.title, 'Internal Shortcut Overlap');
      expect(conflict.message, contains('Next Track'));
    });

    test('Does not flag self-assignment as an internal overlap', () {
      const combo = KeyboardShortcutCombination(
        keyId: 0x00100000105,
        keyLabel: 'Arrow Right',
        ctrl: true,
      );

      final currentBindings = {
        PlayerAction.nextTrack: combo,
      };

      // Checking nextTrack against itself
      final conflict = WindowsShortcutDetector.checkConflict(
        combo,
        currentAction: PlayerAction.nextTrack,
        allBindings: currentBindings,
      );

      expect(conflict.overlappingAction, isNull);
    });

    test('Detects Alt + F4 as critical Windows system conflict', () {
      const altF4 = KeyboardShortcutCombination(
        keyId: 0x00000000,
        keyLabel: 'F4',
        alt: true,
      );

      final conflict = WindowsShortcutDetector.checkConflict(altF4);
      expect(conflict.hasConflict, isTrue);
      expect(conflict.severity, ConflictSeverity.critical);
      expect(conflict.title, contains('Alt + F4'));
    });

    test('Detects Alt + Tab as critical Windows system conflict', () {
      const altTab = KeyboardShortcutCombination(
        keyId: 0x00000000,
        keyLabel: 'Tab',
        alt: true,
      );

      final conflict = WindowsShortcutDetector.checkConflict(altTab);
      expect(conflict.hasConflict, isTrue);
      expect(conflict.severity, ConflictSeverity.critical);
      expect(conflict.title, contains('Alt + Tab'));
    });

    test('Detects Win + L and Win + D as Windows shell reserved shortcuts', () {
      const winL = KeyboardShortcutCombination(
        keyId: 0x0000006c,
        keyLabel: 'L',
        meta: true,
      );

      final conflictL = WindowsShortcutDetector.checkConflict(winL);
      expect(conflictL.hasConflict, isTrue);
      expect(conflictL.title, contains('Win + L'));
      expect(conflictL.message, contains('Lock Computer'));

      const winD = KeyboardShortcutCombination(
        keyId: 0x00000064,
        keyLabel: 'D',
        meta: true,
      );

      final conflictD = WindowsShortcutDetector.checkConflict(winD);
      expect(conflictD.hasConflict, isTrue);
      expect(conflictD.title, contains('Win + D'));
      expect(conflictD.message, contains('Desktop'));
    });

    test('Detects Ctrl + Shift + Esc as Windows Task Manager shortcut', () {
      const ctrlShiftEsc = KeyboardShortcutCombination(
        keyId: 0x00000000,
        keyLabel: 'Esc',
        ctrl: true,
        shift: true,
      );

      final conflict = WindowsShortcutDetector.checkConflict(ctrlShiftEsc);
      expect(conflict.hasConflict, isTrue);
      expect(conflict.title, contains('Ctrl + Shift + Esc'));
      expect(conflict.message, contains('Task Manager'));
    });

    test('Maps standard LogicalKeyboardKeys to Win32 Virtual Key codes', () {
      expect(WindowsShortcutDetector.getVkCode(LogicalKeyboardKey.space), 0x20);
      expect(WindowsShortcutDetector.getVkCode(LogicalKeyboardKey.enter), 0x0D);
      expect(WindowsShortcutDetector.getVkCode(LogicalKeyboardKey.arrowRight), 0x27);
      expect(WindowsShortcutDetector.getVkCode(LogicalKeyboardKey.arrowLeft), 0x25);
      expect(WindowsShortcutDetector.getVkCode(LogicalKeyboardKey.mediaPlayPause), 0xB3);
      expect(WindowsShortcutDetector.getVkCode(LogicalKeyboardKey.keyA), 0x41);
      expect(WindowsShortcutDetector.getVkCode(LogicalKeyboardKey.keyZ), 0x5A);
    });
  });
}
