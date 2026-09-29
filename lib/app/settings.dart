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

/// The learner's settings. `StoredSettings` keeps them in the profile's
/// database ([toStored], [restore]).
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
    List<String> spokenLanguages = const <String>[],
  }) : _enabledSkills = Set<Skill>.unmodifiable(
         enabledSkills ?? Skill.values.toSet(),
       ),
       _spokenLanguages = List<String>.unmodifiable(spokenLanguages);

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
  List<String> _spokenLanguages;

  /// The languages the learner speaks, by code, best known first (#53).
  /// Empty until they have said, which is what sends a first launch to the
  /// setup screen. Kept apart from the interface language (#46).
  List<String> get spokenLanguages => _spokenLanguages;
  set spokenLanguages(List<String> codes) {
    final next = List<String>.unmodifiable(<String>{...codes});
    if (listEquals(next, _spokenLanguages)) return;
    _spokenLanguages = next;
    notifyListeners();
  }

  /// Where [code] ranks among [spokenLanguages], from 0, or null.
  int? rankOf(String code) {
    final i = _spokenLanguages.indexOf(code);
    return i < 0 ? null : i;
  }

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

  /// Every setting as text, by its stored name. The names are permanent:
  /// renaming one resets it for everyone.
  Map<String, String> toStored() => <String, String>{
    'new_cards_per_day': '$_newCardsPerDay',
    'enabled_skills': [for (final s in _enabledSkills) s.name].join(','),
    'show_romanisation': '$_showRomanisation',
    'speech_rate': '$_speechRate',
    'theme_mode': _themeMode.name,
    'seed': _seed.name,
    'dynamic_colour': '$_dynamicColour',
    'high_contrast': '$_highContrast',
    'card_text_scale': '$_cardTextScale',
    'reminder': '$_reminder',
    'reminder_time': '${_reminderTime.hour}:${_reminderTime.minute}',
    'spoken_languages': _spokenLanguages.join(','),
  };

  /// Applies [stored], as [toStored] wrote it, through the setters, so that
  /// ranges are clamped. A missing or unreadable value keeps its current
  /// setting.
  void restore(Map<String, String> stored) {
    T? pick<T>(String name, T? Function(String) parse) {
      final text = stored[name];
      return text == null ? null : parse(text);
    }

    bool? flag(String t) => bool.tryParse(t);
    E? named<E extends Enum>(List<E> values, String t) => values.asNameMap()[t];

    if (pick('new_cards_per_day', int.tryParse) case final v?) {
      newCardsPerDay = v;
    }
    if (pick('enabled_skills', (t) => t) case final names?) {
      final skills = <Skill>{
        for (final name in names.split(',')) ?Skill.values.asNameMap()[name],
      };
      for (final skill in Skill.values) {
        setSkillEnabled(skill, skills.contains(skill));
      }
    }
    if (pick('show_romanisation', flag) case final v?) showRomanisation = v;
    if (pick('speech_rate', _parseFinite) case final v?) speechRate = v;
    if (pick('theme_mode', (t) => named(ThemeMode.values, t)) case final v?) {
      themeMode = v;
    }
    if (pick('seed', (t) => named(ThemeSeed.values, t)) case final v?) {
      seed = v;
    }
    if (pick('dynamic_colour', flag) case final v?) dynamicColour = v;
    if (pick('high_contrast', flag) case final v?) highContrast = v;
    if (pick('card_text_scale', _parseFinite) case final v?) {
      cardTextScale = v;
    }
    if (pick('reminder', flag) case final v?) reminder = v;
    if (pick('reminder_time', _parseTime) case final v?) reminderTime = v;
    if (pick('spoken_languages', (t) => t) case final v?) {
      spokenLanguages = <String>[
        for (final code in v.split(','))
          if (RegExp(r'^[a-z]{2,3}$').hasMatch(code)) code,
      ];
    }
  }

  static TimeOfDay? _parseTime(String text) {
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  static double? _parseFinite(String text) {
    final value = double.tryParse(text);
    return value != null && value.isFinite ? value : null;
  }

  void _set<T>(T current, T next, void Function(T) assign) {
    if (current == next) return;
    assign(next);
    notifyListeners();
  }
}
