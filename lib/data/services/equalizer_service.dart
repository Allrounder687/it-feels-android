import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/services/storage_service.dart';

/// Represents the 10 ISO frequency bands of the Graphic Equalizer
class EqualizerBand {
  final int frequencyHz;
  final String label;
  double gainDb; // -12.0 dB to +12.0 dB

  EqualizerBand({
    required this.frequencyHz,
    required this.label,
    this.gainDb = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'frequencyHz': frequencyHz,
    'label': label,
    'gainDb': gainDb,
  };

  factory EqualizerBand.fromJson(Map<String, dynamic> json) => EqualizerBand(
    frequencyHz: json['frequencyHz'] as int,
    label: json['label'] as String,
    gainDb: (json['gainDb'] as num).toDouble(),
  );
}

/// Represents an audio equalizer preset
class EqualizerPreset {
  final String id;
  final String name;
  final List<double> gains; // 10 gains for 31, 62, 125, 250, 500, 1k, 2k, 4k, 8k, 16k
  final double bassBoost;   // 0.0 to 10.0
  final double trebleBoost; // 0.0 to 10.0

  const EqualizerPreset({
    required this.id,
    required this.name,
    required this.gains,
    this.bassBoost = 0.0,
    this.trebleBoost = 0.0,
  });
}

/// Complete Equalizer and Audio DSP Configuration
class EqualizerState {
  final bool isEnabled;
  final bool isLoudnessNormalizationEnabled; // ReplayGain / EBU R128 Loudness Normalization
  final String activePresetId;
  final List<EqualizerBand> bands;
  final double bassBoost;   // 0.0 to 10.0 dB
  final double trebleBoost; // 0.0 to 10.0 dB
  final double preampGain;  // -12.0 to +12.0 dB

  EqualizerState({
    this.isEnabled = false,
    this.isLoudnessNormalizationEnabled = false,
    this.activePresetId = 'flat',
    required this.bands,
    this.bassBoost = 0.0,
    this.trebleBoost = 0.0,
    this.preampGain = 0.0,
  });

  EqualizerState copyWith({
    bool? isEnabled,
    bool? isLoudnessNormalizationEnabled,
    String? activePresetId,
    List<EqualizerBand>? bands,
    double? bassBoost,
    double? trebleBoost,
    double? preampGain,
  }) {
    return EqualizerState(
      isEnabled: isEnabled ?? this.isEnabled,
      isLoudnessNormalizationEnabled: isLoudnessNormalizationEnabled ?? this.isLoudnessNormalizationEnabled,
      activePresetId: activePresetId ?? this.activePresetId,
      bands: bands ?? this.bands,
      bassBoost: bassBoost ?? this.bassBoost,
      trebleBoost: trebleBoost ?? this.trebleBoost,
      preampGain: preampGain ?? this.preampGain,
    );
  }

  Map<String, dynamic> toJson() => {
    'isEnabled': isEnabled,
    'isLoudnessNormalizationEnabled': isLoudnessNormalizationEnabled,
    'activePresetId': activePresetId,
    'bands': bands.map((b) => b.toJson()).toList(),
    'bassBoost': bassBoost,
    'trebleBoost': trebleBoost,
    'preampGain': preampGain,
  };

  factory EqualizerState.fromJson(Map<String, dynamic> json) {
    final rawBands = json['bands'] as List<dynamic>?;
    final bandsList = rawBands != null
        ? rawBands.map((b) => EqualizerBand.fromJson(Map<String, dynamic>.from(b))).toList()
        : EqualizerService.defaultBands();

    return EqualizerState(
      isEnabled: json['isEnabled'] as bool? ?? false,
      isLoudnessNormalizationEnabled: json['isLoudnessNormalizationEnabled'] as bool? ?? false,
      activePresetId: json['activePresetId'] as String? ?? 'flat',
      bands: bandsList,
      bassBoost: (json['bassBoost'] as num?)?.toDouble() ?? 0.0,
      trebleBoost: (json['trebleBoost'] as num?)?.toDouble() ?? 0.0,
      preampGain: (json['preampGain'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Service managing the 10-band graphic equalizer, audio filters, and volume normalization
class EqualizerService {
  static const List<int> frequencies = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
  static const List<String> labels = ['31Hz', '62Hz', '125Hz', '250Hz', '500Hz', '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'];

  static List<EqualizerBand> defaultBands() {
    return List.generate(frequencies.length, (i) {
      return EqualizerBand(
        frequencyHz: frequencies[i],
        label: labels[i],
        gainDb: 0.0,
      );
    });
  }

  static const List<EqualizerPreset> builtInPresets = [
    EqualizerPreset(
      id: 'flat',
      name: 'Flat',
      gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ),
    EqualizerPreset(
      id: 'bass_boost',
      name: 'Bass Boost',
      gains: [6, 5, 4, 2, 0, 0, 0, 1, 2, 3],
      bassBoost: 6.0,
    ),
    EqualizerPreset(
      id: 'treble_boost',
      name: 'Treble Boost',
      gains: [-1, -1, 0, 0, 1, 2, 4, 5, 6, 7],
      trebleBoost: 6.0,
    ),
    EqualizerPreset(
      id: 'acoustic',
      name: 'Acoustic',
      gains: [3, 2, 1, 1, 2, 2, 3, 3, 3, 2],
    ),
    EqualizerPreset(
      id: 'rock',
      name: 'Rock',
      gains: [5, 4, 3, 1, -1, -1, 1, 3, 4, 5],
      bassBoost: 3.0,
      trebleBoost: 2.0,
    ),
    EqualizerPreset(
      id: 'pop',
      name: 'Pop',
      gains: [-1, 1, 3, 4, 4, 3, 1, -1, 2, 3],
    ),
    EqualizerPreset(
      id: 'electronic',
      name: 'Electronic',
      gains: [6, 5, 2, 0, -2, 2, 1, 2, 4, 5],
      bassBoost: 5.0,
    ),
    EqualizerPreset(
      id: 'vocal',
      name: 'Vocal Clarity',
      gains: [-2, -1, 0, 2, 4, 4, 3, 2, 1, 0],
    ),
    EqualizerPreset(
      id: 'jazz',
      name: 'Jazz',
      gains: [3, 2, 1, 2, -1, -1, 0, 1, 3, 4],
    ),
    EqualizerPreset(
      id: 'hip_hop',
      name: 'Hip Hop',
      gains: [6, 5, 3, 1, -1, 1, 2, 1, 3, 4],
      bassBoost: 5.0,
    ),
    EqualizerPreset(
      id: 'deep_lows',
      name: 'Deep Lows',
      gains: [8, 6, 4, 2, 0, -1, -2, -2, -1, 0],
      bassBoost: 7.0,
    ),
  ];

  EqualizerState _state = EqualizerState(bands: defaultBands());
  EqualizerState get state => _state;

  static const String _storageKey = 'obsidian_equalizer_settings_v1';

  // Lifecycle & Mutex Safeguards for Native libmpv
  bool _isDisposed = false;
  bool _isDetaching = false;
  dynamic _attachedPlayer;
  Future<void> _filterQueue = Future.value();

  bool get isDisposed => _isDisposed;

  /// Loads persisted settings or initializes default state
  Future<void> init() async {
    try {
      final jsonStr = await StorageService.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(jsonStr);
        _state = EqualizerState.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[EqualizerService] Failed to load settings: $e');
      _state = EqualizerState(bands: defaultBands());
    }
  }

  /// Saves the current equalizer state
  Future<void> _persistState() async {
    try {
      final jsonStr = json.encode(_state.toJson());
      await StorageService.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('[EqualizerService] Failed to persist settings: $e');
    }
  }

  /// Sets overall equalizer enabled flag
  Future<void> setEnabled(bool enabled, dynamic player) async {
    _state = _state.copyWith(isEnabled: enabled);
    await _applyFilterToPlayer(player);
    await _persistState();
  }

  /// Toggles volume normalization (ReplayGain / EBU R128)
  Future<void> setLoudnessNormalization(bool enabled, dynamic player) async {
    _state = _state.copyWith(isLoudnessNormalizationEnabled: enabled);
    await _applyFilterToPlayer(player);
    await _persistState();
  }

  /// Updates gain for a specific frequency band
  Future<void> setBandGain(int frequencyHz, double gainDb, dynamic player) async {
    final clamped = gainDb.clamp(-12.0, 12.0);
    final updatedBands = _state.bands.map((b) {
      if (b.frequencyHz == frequencyHz) {
        return EqualizerBand(frequencyHz: b.frequencyHz, label: b.label, gainDb: clamped);
      }
      return b;
    }).toList();

    _state = _state.copyWith(
      bands: updatedBands,
      activePresetId: 'custom',
    );
    await _applyFilterToPlayer(player);
    await _persistState();
  }

  /// Sets bass boost level (0.0 to 10.0 dB)
  Future<void> setBassBoost(double boost, dynamic player) async {
    _state = _state.copyWith(
      bassBoost: boost.clamp(0.0, 10.0),
      activePresetId: 'custom',
    );
    await _applyFilterToPlayer(player);
    await _persistState();
  }

  /// Sets treble boost level (0.0 to 10.0 dB)
  Future<void> setTrebleBoost(double boost, dynamic player) async {
    _state = _state.copyWith(
      trebleBoost: boost.clamp(0.0, 10.0),
      activePresetId: 'custom',
    );
    await _applyFilterToPlayer(player);
    await _persistState();
  }

  /// Sets preamp gain (-12.0 to +12.0 dB)
  Future<void> setPreampGain(double gain, dynamic player) async {
    _state = _state.copyWith(preampGain: gain.clamp(-12.0, 12.0));
    await _applyFilterToPlayer(player);
    await _persistState();
  }

  /// Applies a named preset
  Future<void> applyPreset(String presetId, dynamic player) async {
    final preset = builtInPresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => builtInPresets.first,
    );

    final updatedBands = List.generate(frequencies.length, (i) {
      return EqualizerBand(
        frequencyHz: frequencies[i],
        label: labels[i],
        gainDb: preset.gains[i],
      );
    });

    _state = _state.copyWith(
      activePresetId: preset.id,
      bands: updatedBands,
      bassBoost: preset.bassBoost,
      trebleBoost: preset.trebleBoost,
    );
    await _applyFilterToPlayer(player);
    await _persistState();
  }

  /// Resets equalizer to Flat (0dB across all bands)
  Future<void> resetToFlat(dynamic player) async {
    await applyPreset('flat', player);
  }

  /// Synthesizes libmpv audio filter string (`af`)
  String buildFilterString() {
    final List<String> filters = [];

    // 1. Loudness Normalization filter (ReplayGain equivalent)
    if (_state.isLoudnessNormalizationEnabled) {
      // EBU R128 loudness normalization: Integrated target -16 LUFS, True Peak -1.5 dB, LRA 11
      filters.add('loudnorm=I=-16:TP=-1.5:LRA=11');
    }

    // 2. Preamp gain adjustment if non-zero
    if (_state.isEnabled && _state.preampGain != 0.0) {
      filters.add('volume=volume=${_state.preampGain.toStringAsFixed(1)}dB');
    }

    // 3. 10-Band Biquad Graphic Equalizer & Bass/Treble boosters
    if (_state.isEnabled) {
      for (final band in _state.bands) {
        double effectiveGain = band.gainDb;
        // Blend bass boost into low frequencies (<= 125 Hz)
        if (band.frequencyHz <= 62) {
          effectiveGain += _state.bassBoost * 0.8;
        } else if (band.frequencyHz == 125) {
          effectiveGain += _state.bassBoost * 0.4;
        }
        // Blend treble boost into high frequencies (>= 4000 Hz)
        if (band.frequencyHz >= 8000) {
          effectiveGain += _state.trebleBoost * 0.8;
        } else if (band.frequencyHz == 4000) {
          effectiveGain += _state.trebleBoost * 0.4;
        }

        final roundedGain = effectiveGain.clamp(-12.0, 12.0);
        if (roundedGain.abs() > 0.05) {
          filters.add('equalizer=f=${band.frequencyHz}:width_type=o:w=1:g=${roundedGain.toStringAsFixed(1)}');
        }
      }
    }

    return filters.join(',');
  }

  /// Resets lifecycle flags when a new playback isolate or session is initialized
  void resetLifecycle() {
    _isDisposed = false;
    _isDetaching = false;
    _filterQueue = Future.value();
  }

  /// Detaches the player from EqualizerService, safely flushing filters and locking against new updates.
  /// This prevents native libmpv property-change callbacks from firing during or after player disposal.
  Future<void> detachPlayer([dynamic player]) async {
    _isDetaching = true;
    final target = player ?? _attachedPlayer;
    if (target != null) {
      try {
        final platform = target.platform;
        if (platform != null) {
          // Clear active audio filter chain in mpv
          await (platform as dynamic).setProperty('af', '');
          debugPrint('[EqualizerService] Cleared audio filter chain before player teardown.');
        }
      } catch (e) {
        debugPrint('[EqualizerService] Note: Non-critical failure clearing af filter during detach: $e');
      }
    }
    _attachedPlayer = null;
    _isDisposed = true;
    _isDetaching = false;
  }

  /// Full disposal of the EqualizerService
  Future<void> dispose() async {
    await detachPlayer();
  }

  /// Serialized application of audio filter strings to the underlying libmpv player instance.
  /// Uses a mutex queue to guarantee filter modifications are strictly serialized and cannot
  /// race or trigger native callbacks during teardown or hot restart.
  Future<void> _applyFilterToPlayer(dynamic player) {
    if (player == null || _isDisposed || _isDetaching) {
      return Future.value();
    }
    _attachedPlayer = player;
    _filterQueue = _filterQueue.then((_) async {
      if (_isDisposed || _isDetaching || player == null) return;
      try {
        final filterString = buildFilterString();
        final platform = player.platform;
        if (platform == null) return;
        
        try {
          await (platform as dynamic).setProperty('af', filterString);
          debugPrint('[EqualizerService] Applied audio filter: $filterString');
        } catch (e) {
          debugPrint('[EqualizerService] Platform does not support dynamic setProperty: $e');
        }
      } catch (e) {
        debugPrint('[EqualizerService] Error applying audio filter: $e');
      }
    }).catchError((e) {
      debugPrint('[EqualizerService] Error in filter serialization queue: $e');
    });

    return _filterQueue;
  }

  /// Re-applies current filters to a newly loaded audio player
  Future<void> syncWithPlayer(dynamic player) async {
    if (_isDisposed) {
      resetLifecycle();
    }
    await _applyFilterToPlayer(player);
  }
}
