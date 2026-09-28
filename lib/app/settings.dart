import 'package:flutter/material.dart' show ThemeMode, TimeOfDay;
import 'package:flutter/foundation.dart';

import 'skill.dart';

/// The colour seeds the Appearance screen offers. [forest] is the repository's
/// seed, and the default; the others are extras behind `Feature.colourSeeds`.
///
/// The colours are the tonal-spot primaries the design shows for each seed,
/// which `ColorScheme.fromSeed` turns back into the same hue.
enum ThemeSeed {
  forest(0xFF3F6C51),
  ocean(0xFF35618E),
  clay(0xFF8F4C36),
  iris(0xFF65558F);

  const ThemeSeed(this.argb);

  final int argb;
}

/// The learner's settings, in memory until #15 stores them.
///
/// Read through `AppState.settings` inside a `ListenableBuilder`, so that a
/// change rebuilds only what shows it. Every setter notifies only when the
/// value actually changes.
class SettingsNotifier extends ChangeNotifier {
  SettingsNotifier({
    this._newCardsPerDay = 20,
    Set<Skill>? enabledSkills,
    this._showRomanisation = true,
    this._speechRate = 1.0,
    this._themeMode = ThemeMode.system,
    this._seed = ThemeSeed.forest,
    this._dynamicColour = false,
    this._highContrast = false,
    this._cardTextScale = 1.0,
    this._reminder = false,
    this._reminderTime = const TimeOfDay(hour: 19, minute: 30),
  }) : _enabledSkills = Set<Skill>.unmodifiable(
         enabledSkills ?? Skill.values.toSet(),
       );

  /// The new-card slider's range and step, from the design.
  static const int maxNewCardsPerDay = 50;
  static const int newCardsStep = 5;

  /// The speech-rate slider's range and step, as a multiple of normal speed.
  static const double minSpeechRate = 0.5;
  static const double maxSpeechRate = 1.5;
  static const double speechRateStep = 0.1;

  /// The listening drill's "Slower" button, as a multiple of [speechRate].
  static const double slowerFactor = 0.7;

  /// The card-text-size slider's range and step.
  static const double minCardTextScale = 0.8;
  static const double maxCardTextScale = 1.4;

  int _newCardsPerDay;
  Set<Skill> _enabledSkills;
  bool _showRomanisation;
  double _speechRate;
  ThemeMode _themeMode;
  ThemeSeed _seed;
  bool _dynamicColour;
  bool _highContrast;
  double _cardTextScale;
  bool _reminder;
  TimeOfDay _reminderTime;

  /// How many new `(card, mode)` pairs a day may introduce.
  int get newCardsPerDay => _newCardsPerDay;
  set newCardsPerDay(int value) =>
      _set(_newCardsPerDay, value.clamp(0, maxNewCardsPerDay), (v) {
        _newCardsPerDay = v;
      });

  /// The skills the learner has switched on. A skill that is switched on but
  /// whose feature is incoming still never enters a session.
  Set<Skill> get enabledSkills => _enabledSkills;

  bool isEnabled(Skill skill) => _enabledSkills.contains(skill);

  void setSkillEnabled(Skill skill, bool enabled) {
    final next = Set<Skill>.of(_enabledSkills);
    enabled ? next.add(skill) : next.remove(skill);
    if (setEquals(next, _enabledSkills)) return;
    _enabledSkills = Set<Skill>.unmodifiable(next);
    notifyListeners();
  }

  /// Whether the reading line shows under a non-Latin target.
  bool get showRomanisation => _showRomanisation;
  set showRomanisation(bool value) =>
      _set(_showRomanisation, value, (v) => _showRomanisation = v);

  /// Speech speed as a multiple of normal, 0.5–1.5, shown as "1.0×".
  double get speechRate => _speechRate;
  set speechRate(double value) => _set(
    _speechRate,
    value.clamp(minSpeechRate, maxSpeechRate).toDouble(),
    (v) => _speechRate = v,
  );

  /// [speechRate] in the units `TtsEngine.speak` takes: 0.0–1.0, where the
  /// engines treat 0.5 as normal speed. [slower] applies [slowerFactor].
  double ttsRate({bool slower = false}) =>
      (0.5 * _speechRate * (slower ? slowerFactor : 1)).clamp(0.0, 1.0);

  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode value) =>
      _set(_themeMode, value, (v) => _themeMode = v);

  ThemeSeed get seed => _seed;
  set seed(ThemeSeed value) => _set(_seed, value, (v) => _seed = v);

  /// Wallpaper colours (Material You). Needs a dependency; see
  /// `Feature.dynamicColour`.
  bool get dynamicColour => _dynamicColour;
  set dynamicColour(bool value) =>
      _set(_dynamicColour, value, (v) => _dynamicColour = v);

  bool get highContrast => _highContrast;
  set highContrast(bool value) =>
      _set(_highContrast, value, (v) => _highContrast = v);

  /// A multiplier on target text in drills, 0.8–1.4. Menus follow the phone's
  /// own font size instead.
  double get cardTextScale => _cardTextScale;
  set cardTextScale(double value) => _set(
    _cardTextScale,
    value.clamp(minCardTextScale, maxCardTextScale).toDouble(),
    (v) => _cardTextScale = v,
  );

  bool get reminder => _reminder;
  set reminder(bool value) => _set(_reminder, value, (v) => _reminder = v);

  TimeOfDay get reminderTime => _reminderTime;
  set reminderTime(TimeOfDay value) =>
      _set(_reminderTime, value, (v) => _reminderTime = v);

  void _set<T>(T current, T next, void Function(T) assign) {
    if (current == next) return;
    assign(next);
    notifyListeners();
  }
}
