import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'shared_preferences_provider.dart';

const _kEqualizerKey = 'equalizer';

/// The preset id for gains the person set by hand.
const kCustomPreset = 'custom';

/// A named shape for the equalizer: gains in dB at five points spread evenly
/// from the lowest band to the highest. A phone's equalizer has anything from
/// three to a dozen bands, so [gainsFor] stretches the shape over them.
class EqualizerPreset {
  const EqualizerPreset(this.id, this.curve);

  final String id;
  final List<double> curve;

  List<double> gainsFor(int bands, {required double min, required double max}) {
    return [
      for (var i = 0; i < bands; i++)
        _at(bands == 1 ? .5 : i / (bands - 1)).clamp(min, max).toDouble(),
    ];
  }

  /// The curve's value [t] of the way (0 to 1) from its first point to its last.
  double _at(double t) {
    final position = t * (curve.length - 1);
    final low = position.floor();
    final high = (low + 1).clamp(0, curve.length - 1);
    return curve[low] + (curve[high] - curve[low]) * (position - low);
  }
}

const kEqualizerPresets = <EqualizerPreset>[
  EqualizerPreset('flat', [0, 0, 0, 0, 0]),
  EqualizerPreset('bass_boost', [6, 4, 0, 0, 0]),
  EqualizerPreset('treble_boost', [0, 0, 0, 4, 6]),
  EqualizerPreset('vocal', [-2, 0, 4, 3, -1]),
  EqualizerPreset('rock', [5, 2, -2, 3, 5]),
  EqualizerPreset('pop', [-1, 3, 4, 2, -1]),
];

class EqualizerState {
  const EqualizerState({
    this.supported = false,
    this.ready = false,
    this.enabled = false,
    this.preset = 'flat',
    this.gains = const [],
    this.frequencies = const [],
    this.minDb = -15,
    this.maxDb = 15,
  });

  /// Whether this phone has an equalizer to offer — Android only.
  final bool supported;

  /// Whether the bands are known: the phone only reports them once a song has
  /// been loaded into the player.
  final bool ready;
  final bool enabled;

  /// The id of one of [kEqualizerPresets], or [kCustomPreset].
  final String preset;

  /// Per band, low to high: the gain in dB and the centre frequency in Hz.
  final List<double> gains;
  final List<double> frequencies;
  final double minDb;
  final double maxDb;

  EqualizerState copyWith({
    bool? ready,
    bool? enabled,
    String? preset,
    List<double>? gains,
    List<double>? frequencies,
    double? minDb,
    double? maxDb,
  }) {
    return EqualizerState(
      supported: supported,
      ready: ready ?? this.ready,
      enabled: enabled ?? this.enabled,
      preset: preset ?? this.preset,
      gains: gains ?? this.gains,
      frequencies: frequencies ?? this.frequencies,
      minDb: minDb ?? this.minDb,
      maxDb: maxDb ?? this.maxDb,
    );
  }
}

/// The equalizer built into the player's audio pipeline — null anywhere but
/// Android, where just_audio has none. The player takes it when it is made, so
/// there is one for the whole app.
final equalizerEffectProvider = Provider<AndroidEqualizer?>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? AndroidEqualizer()
      : null,
);

/// The equalizer's on/off switch and band gains, kept on the phone and applied
/// to the player as soon as it reports its bands.
class EqualizerController extends Notifier<EqualizerState> {
  AndroidEqualizer? _effect;
  AndroidEqualizerParameters? _parameters;

  @override
  EqualizerState build() {
    final effect = _effect = ref.read(equalizerEffectProvider);
    if (effect == null) return const EqualizerState();

    final saved = _readSaved();
    // Before the player exists this only records the choice; it goes in with
    // the player's first load.
    unawaited(effect.setEnabled(saved.enabled));
    unawaited(effect.parameters.then(_onParameters));
    return EqualizerState(
      supported: true,
      enabled: saved.enabled,
      preset: saved.preset,
      gains: saved.gains,
    );
  }

  /// The first song has loaded: the bands are known, so check the saved gains
  /// fit them and put them on.
  void _onParameters(AndroidEqualizerParameters parameters) {
    _parameters = parameters;
    final bands = parameters.bands;
    var preset = state.preset;
    var gains = state.gains;
    if (gains.length != bands.length) {
      // Saved for a different number of bands (or never saved): start from the
      // preset, or flat when the saved gains were set by hand.
      if (!_isPreset(preset)) preset = kEqualizerPresets.first.id;
      gains = _presetGains(preset);
    }
    gains = [
      for (final gain in gains)
        gain.clamp(parameters.minDecibels, parameters.maxDecibels).toDouble(),
    ];
    state = state.copyWith(
      ready: true,
      preset: preset,
      gains: gains,
      frequencies: [for (final band in bands) band.centerFrequency],
      minDb: parameters.minDecibels,
      maxDb: parameters.maxDecibels,
    );
    _apply(gains);
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    _save();
    await _effect?.setEnabled(enabled);
  }

  void selectPreset(String id) {
    if (_parameters == null || !_isPreset(id)) return;
    final gains = _presetGains(id);
    state = state.copyWith(preset: id, gains: gains);
    _save();
    _apply(gains);
  }

  void reset() => selectPreset(kEqualizerPresets.first.id);

  /// A slider is being dragged: change the sound now, keep it once it is let go
  /// ([saveGains]).
  void setGain(int band, double decibels) {
    final parameters = _parameters;
    if (parameters == null || band < 0 || band >= state.gains.length) return;
    final gain = decibels
        .clamp(parameters.minDecibels, parameters.maxDecibels)
        .toDouble();
    final gains = [...state.gains]..[band] = gain;
    state = state.copyWith(preset: kCustomPreset, gains: gains);
    unawaited(parameters.bands[band].setGain(gain));
  }

  void saveGains() => _save();

  bool _isPreset(String id) => kEqualizerPresets.any((p) => p.id == id);

  List<double> _presetGains(String id) {
    final parameters = _parameters!;
    final preset = kEqualizerPresets.firstWhere(
      (p) => p.id == id,
      orElse: () => kEqualizerPresets.first,
    );
    return preset.gainsFor(
      parameters.bands.length,
      min: parameters.minDecibels,
      max: parameters.maxDecibels,
    );
  }

  void _apply(List<double> gains) {
    final bands = _parameters?.bands ?? const <AndroidEqualizerBand>[];
    for (var i = 0; i < bands.length && i < gains.length; i++) {
      unawaited(bands[i].setGain(gains[i]));
    }
  }

  ({bool enabled, String preset, List<double> gains}) _readSaved() {
    const none = (enabled: false, preset: 'flat', gains: <double>[]);
    final raw = ref.read(sharedPreferencesProvider).getString(_kEqualizerKey);
    if (raw == null) return none;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (
        enabled: json['enabled'] as bool? ?? false,
        preset: json['preset'] as String? ?? 'flat',
        gains: [
          for (final gain in json['gains'] as List? ?? const [])
            (gain as num).toDouble(),
        ],
      );
    } catch (_) {
      return none;
    }
  }

  void _save() {
    ref
        .read(sharedPreferencesProvider)
        .setString(
          _kEqualizerKey,
          jsonEncode({
            'enabled': state.enabled,
            'preset': state.preset,
            'gains': state.gains,
          }),
        );
  }
}

final equalizerProvider = NotifierProvider<EqualizerController, EqualizerState>(
  EqualizerController.new,
);
