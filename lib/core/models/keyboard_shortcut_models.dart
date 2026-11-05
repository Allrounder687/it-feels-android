import 'package:flutter/services.dart';

enum PlayerActionCategory {
  playback('Playback Controls'),
  volume('Volume & Audio'),
  navigation('Navigation & Library');

  final String label;
  const PlayerActionCategory(this.label);
}

enum PlayerAction {
  playPause(
    id: 'play_pause',
    label: 'Play / Pause',
    description: 'Toggle playback of the current track',
    category: PlayerActionCategory.playback,
    defaultKeyId: 0x00000020, // LogicalKeyboardKey.space
    defaultKeyLabel: 'Space',
  ),
  nextTrack(
    id: 'next_track',
    label: 'Next Track',
    description: 'Skip to the next song in the queue',
    category: PlayerActionCategory.playback,
    defaultKeyId: 0x00100000105, // LogicalKeyboardKey.arrowRight
    defaultKeyLabel: 'Arrow Right',
    defaultCtrl: true,
  ),
  previousTrack(
    id: 'previous_track',
    label: 'Previous Track',
    description: 'Skip to the previous song or restart current song',
    category: PlayerActionCategory.playback,
    defaultKeyId: 0x00100000104, // LogicalKeyboardKey.arrowLeft
    defaultKeyLabel: 'Arrow Left',
    defaultCtrl: true,
  ),
  seekForward(
    id: 'seek_forward',
    label: 'Seek Forward (10s)',
    description: 'Jump 10 seconds ahead in the track',
    category: PlayerActionCategory.playback,
    defaultKeyId: 0x00100000105, // LogicalKeyboardKey.arrowRight
    defaultKeyLabel: 'Arrow Right',
    defaultShift: true,
  ),
  seekBackward(
    id: 'seek_backward',
    label: 'Seek Backward (10s)',
    description: 'Jump 10 seconds back in the track',
    category: PlayerActionCategory.playback,
    defaultKeyId: 0x00100000104, // LogicalKeyboardKey.arrowLeft
    defaultKeyLabel: 'Arrow Left',
    defaultShift: true,
  ),
  toggleShuffle(
    id: 'toggle_shuffle',
    label: 'Toggle Shuffle',
    description: 'Turn shuffle playback mode on or off',
    category: PlayerActionCategory.playback,
    defaultKeyId: 0x00000073, // LogicalKeyboardKey.keyS
    defaultKeyLabel: 'S',
    defaultCtrl: true,
  ),
  toggleRepeat(
    id: 'toggle_repeat',
    label: 'Toggle Repeat',
    description: 'Turn repeat playback mode on or off',
    category: PlayerActionCategory.playback,
    defaultKeyId: 0x00000072, // LogicalKeyboardKey.keyR
    defaultKeyLabel: 'R',
    defaultCtrl: true,
  ),
  volumeUp(
    id: 'volume_up',
    label: 'Volume Up (+5%)',
    description: 'Increase player volume',
    category: PlayerActionCategory.volume,
    defaultKeyId: 0x00100000106, // LogicalKeyboardKey.arrowUp
    defaultKeyLabel: 'Arrow Up',
    defaultCtrl: true,
  ),
  volumeDown(
    id: 'volume_down',
    label: 'Volume Down (-5%)',
    description: 'Decrease player volume',
    category: PlayerActionCategory.volume,
    defaultKeyId: 0x00100000107, // LogicalKeyboardKey.arrowDown
    defaultKeyLabel: 'Arrow Down',
    defaultCtrl: true,
  ),
  toggleMute(
    id: 'toggle_mute',
    label: 'Mute / Unmute',
    description: 'Instantly mute or unmute audio',
    category: PlayerActionCategory.volume,
    defaultKeyId: 0x0000006d, // LogicalKeyboardKey.keyM
    defaultKeyLabel: 'M',
    defaultCtrl: true,
  ),
  toggleFavorite(
    id: 'toggle_favorite',
    label: 'Like / Favorite Song',
    description: 'Save or remove current song from Favorites',
    category: PlayerActionCategory.navigation,
    defaultKeyId: 0x0000006c, // LogicalKeyboardKey.keyL
    defaultKeyLabel: 'L',
    defaultCtrl: true,
  ),
  openSearch(
    id: 'open_search',
    label: 'Focus Global Search',
    description: 'Jump directly to search bar',
    category: PlayerActionCategory.navigation,
    defaultKeyId: 0x0000006b, // LogicalKeyboardKey.keyK
    defaultKeyLabel: 'K',
    defaultCtrl: true,
  ),
  toggleLyrics(
    id: 'toggle_lyrics',
    label: 'Toggle Lyrics View',
    description: 'Open or close live synchronized lyrics',
    category: PlayerActionCategory.navigation,
    defaultKeyId: 0x00000079, // LogicalKeyboardKey.keyY
    defaultKeyLabel: 'Y',
    defaultCtrl: true,
  );

  final String id;
  final String label;
  final String description;
  final PlayerActionCategory category;
  final int defaultKeyId;
  final String defaultKeyLabel;
  final bool defaultCtrl;
  final bool defaultShift;
  bool get defaultAlt => false;
  bool get defaultMeta => false;

  const PlayerAction({
    required this.id,
    required this.label,
    required this.description,
    required this.category,
    required this.defaultKeyId,
    required this.defaultKeyLabel,
    this.defaultCtrl = false,
    this.defaultShift = false,
  });

  KeyboardShortcutCombination get defaultCombination => KeyboardShortcutCombination(
        keyId: defaultKeyId,
        keyLabel: defaultKeyLabel,
        ctrl: defaultCtrl,
        alt: defaultAlt,
        shift: defaultShift,
        meta: defaultMeta,
      );

  static PlayerAction? fromId(String id) {
    for (var a in PlayerAction.values) {
      if (a.id == id) return a;
    }
    return null;
  }
}

class KeyboardShortcutCombination {
  final int keyId;
  final String keyLabel;
  final bool ctrl;
  final bool alt;
  final bool shift;
  final bool meta;

  const KeyboardShortcutCombination({
    required this.keyId,
    required this.keyLabel,
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  LogicalKeyboardKey get logicalKey => LogicalKeyboardKey(keyId);

  bool get hasModifiers => ctrl || alt || shift || meta;

  String get displayLabel {
    final parts = <String>[];
    if (ctrl) parts.add('Ctrl');
    if (alt) parts.add('Alt');
    if (shift) parts.add('Shift');
    if (meta) parts.add('Win');

    String cleanKey = keyLabel;
    if (cleanKey.toLowerCase() == 'arrowright' || cleanKey == 'Arrow Right') cleanKey = '→';
    if (cleanKey.toLowerCase() == 'arrowleft' || cleanKey == 'Arrow Left') cleanKey = '←';
    if (cleanKey.toLowerCase() == 'arrowup' || cleanKey == 'Arrow Up') cleanKey = '↑';
    if (cleanKey.toLowerCase() == 'arrowdown' || cleanKey == 'Arrow Down') cleanKey = '↓';
    if (cleanKey.toLowerCase() == 'space') cleanKey = 'Space';

    parts.add(cleanKey);
    return parts.join(' + ');
  }

  bool matchesKeyEvent(KeyEvent event) {
    // Only trigger on KeyDown or KeyRepeat
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    if (event.logicalKey.keyId != keyId) return false;

    final isCtrlDown = HardwareKeyboard.instance.isControlPressed;
    final isAltDown = HardwareKeyboard.instance.isAltPressed;
    final isShiftDown = HardwareKeyboard.instance.isShiftPressed;
    final isMetaDown = HardwareKeyboard.instance.isMetaPressed;

    return isCtrlDown == ctrl &&
        isAltDown == alt &&
        isShiftDown == shift &&
        isMetaDown == meta;
  }

  Map<String, dynamic> toJson() => {
        'keyId': keyId,
        'keyLabel': keyLabel,
        'ctrl': ctrl,
        'alt': alt,
        'shift': shift,
        'meta': meta,
      };

  factory KeyboardShortcutCombination.fromJson(Map<String, dynamic> json) {
    return KeyboardShortcutCombination(
      keyId: json['keyId'] as int? ?? 0,
      keyLabel: json['keyLabel'] as String? ?? 'Unknown',
      ctrl: json['ctrl'] as bool? ?? false,
      alt: json['alt'] as bool? ?? false,
      shift: json['shift'] as bool? ?? false,
      meta: json['meta'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KeyboardShortcutCombination &&
        other.keyId == keyId &&
        other.ctrl == ctrl &&
        other.alt == alt &&
        other.shift == shift &&
        other.meta == meta;
  }

  @override
  int get hashCode => Object.hash(keyId, ctrl, alt, shift, meta);

  @override
  String toString() => displayLabel;
}
