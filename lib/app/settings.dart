import 'dart:convert';

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
    List<String> learningLanguages = const <String>[],
    Set<String> placedDecks = const <String>{},
    this._learningChosen = false,
    Set<String> speechOnline = const <String>{},
  }) : _enabledSkills = Set<Skill>.unmodifiable(
         enabledSkills ?? <Skill>{...Skill.values.where((s) => s.onByDefault)},
       ),
       _spokenLanguages = List<String>.unmodifiable(spokenLanguages),
       _learningLanguages = List<String>.unmodifiable(learningLanguages),
       _placedDecks = Set<String>.unmodifiable(placedDecks),
       _speechOnline = Set<String>.unmodifiable(speechOnline);

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
  List<String> _learningLanguages;
  Set<String> _placedDecks;
  bool _learningChosen;
  Set<String> _speechOnline;
  Set<String> _speechNotOnDevice = const <String>{};
  Set<String> _speechUnsupported = const <String>{};
  Set<String> _scriptGuidesSeen = const <String>{};
  Map<Skill, DateTime> _pausedUntil = const <Skill, DateTime>{};
  Map<Skill, Set<String>> _offFor = const <Skill, Set<String>>{};
  Map<String, DateTime> _factsShown = const <String, DateTime>{};

  /// When each daily fact was last shown (#48), by `<language>/<fact id>`.
  /// Not something the learner sets: kept here because it is small, per
  /// profile, and read synchronously, and the settings table stores it.
  DateTime? factShownAt(String language, String factId) =>
      _factsShown['$language/$factId'];

  /// When [language]'s facts were last shown, by fact id.
  Map<String, DateTime> factsShownFor(String language) => <String, DateTime>{
    for (final MapEntry(:key, :value) in _factsShown.entries)
      if (key.startsWith('$language/'))
        key.substring(language.length + 1): value,
  };

  /// Records that [factId] about [language] was shown at [at].
  void markFactShown(String language, String factId, DateTime at) {
    _factsShown = Map<String, DateTime>.unmodifiable(<String, DateTime>{
      ..._factsShown,
      '$language/$factId': at,
    });
    notifyListeners();
  }

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

  /// The languages the learner has chosen to learn, by code (#117). Empty
  /// until they have chosen, when the profile learns every language.
  List<String> get learningLanguages => _learningLanguages;
  set learningLanguages(List<String> codes) {
    final next = List<String>.unmodifiable(<String>{...codes});
    if (listEquals(next, _learningLanguages)) return;
    _learningLanguages = next;
    notifyListeners();
  }

  /// The decks placement found the learner already knows (#117,
  /// ADR-0013), by id. A placed deck reads Done and is not taught by Today,
  /// though it can still be studied; nothing is recorded as learned.
  Set<String> get placedDecks => _placedDecks;
  set placedDecks(Set<String> ids) {
    final next = Set<String>.unmodifiable(ids);
    if (setEquals(next, _placedDecks)) return;
    _placedDecks = next;
    notifyListeners();
  }

  bool isPlaced(String deckId) => _placedDecks.contains(deckId);

  /// Whether the learner has been through choosing what to learn and
  /// placement (#117). Until then the first launch, or the first after an
  /// update, asks.
  bool get learningChosen => _learningChosen;
  set learningChosen(bool value) =>
      _set(_learningChosen, value, (v) => _learningChosen = v);

  /// The languages, by code, whose speech the learner allows to be
  /// recognised online, where the phone cannot recognise them itself
  /// (ADR-0014). Audio then leaves the phone, so it is asked per language.
  Set<String> get speechOnline => _speechOnline;

  bool allowsOnlineSpeech(String code) => _speechOnline.contains(code);

  void allowOnlineSpeech(String code, bool allowed) {
    final next = Set<String>.of(_speechOnline);
    allowed ? next.add(code) : next.remove(code);
    if (setEquals(next, _speechOnline)) return;
    _speechOnline = Set<String>.unmodifiable(next);
    notifyListeners();
  }

  /// The languages, by code, that a listen found the phone cannot
  /// recognise by itself, and those that online recognition does not
  /// support either (ADR-0014). Like [factShownAt], not something the
  /// learner sets: kept so that a restart does not find them out again at
  /// the cost of a spoken word. Check again on the Voices page forgets them.
  Set<String> get speechNotOnDevice => _speechNotOnDevice;
  Set<String> get speechUnsupported => _speechUnsupported;

  /// Records that a listen found [code] not on the device, or with
  /// [unsupported], not online either.
  void foundSpeech(String code, {bool unsupported = false}) {
    final notOnDevice = <String>{..._speechNotOnDevice, code};
    final none = <String>{..._speechUnsupported, if (unsupported) code};
    if (setEquals(notOnDevice, _speechNotOnDevice) &&
        setEquals(none, _speechUnsupported)) {
      return;
    }
    _speechNotOnDevice = Set<String>.unmodifiable(notOnDevice);
    _speechUnsupported = Set<String>.unmodifiable(none);
    notifyListeners();
  }

  /// Whether the learner has seen [code]'s script guide (#30, ADR-0016),
  /// which the drill shows once, before the language's first script card.
  bool hasSeenScriptGuide(String code) => _scriptGuidesSeen.contains(code);

  void markScriptGuideSeen(String code) {
    if (_scriptGuidesSeen.contains(code)) return;
    _scriptGuidesSeen = Set<String>.unmodifiable(<String>{
      ..._scriptGuidesSeen,
      code,
    });
    notifyListeners();
  }

  /// Forgets what listens found, so that the next ones find out again.
  void forgetFoundSpeech() {
    if (_speechNotOnDevice.isEmpty && _speechUnsupported.isEmpty) return;
    _speechNotOnDevice = const <String>{};
    _speechUnsupported = const <String>{};
    notifyListeners();
  }

  /// When [skill] comes back after "Can't speak now" or "Can't listen now"
  /// (#89), or null if it is not paused.
  DateTime? pausedUntil(Skill skill) => _pausedUntil[skill];

  /// Whether [skill] is paused at [now].
  bool isPaused(Skill skill, DateTime now) =>
      _pausedUntil[skill]?.isAfter(now) ?? false;

  /// Pauses [skill] until [until]: an hour, from a drill's "Can't speak now"
  /// or "Can't listen now", or from Settings.
  void pause(Skill skill, {required DateTime until}) {
    _pausedUntil = Map<Skill, DateTime>.unmodifiable(<Skill, DateTime>{
      ..._pausedUntil,
      skill: until,
    });
    notifyListeners();
  }

  /// Ends a pause early.
  void resume(Skill skill) {
    if (!_pausedUntil.containsKey(skill)) return;
    _pausedUntil = Map<Skill, DateTime>.unmodifiable(
      Map<Skill, DateTime>.of(_pausedUntil)..remove(skill),
    );
    notifyListeners();
  }

  /// The languages, by code, [skill] is switched off for, while it stays on
  /// for the others (#89).
  Set<String> offFor(Skill skill) => _offFor[skill] ?? const <String>{};

  bool isOffFor(Skill skill, String code) => offFor(skill).contains(code);

  void setOffFor(Skill skill, String code, bool off) {
    final next = Set<String>.of(offFor(skill));
    off ? next.add(code) : next.remove(code);
    if (setEquals(next, offFor(skill))) return;
    _offFor = Map<Skill, Set<String>>.unmodifiable(<Skill, Set<String>>{
      ..._offFor,
      skill: Set<String>.unmodifiable(next),
    });
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
    'learning_languages': _learningLanguages.join(','),
    'placed_decks': (_placedDecks.toList()..sort()).join(','),
    'learning_chosen': '$_learningChosen',
    'speech_online': (_speechOnline.toList()..sort()).join(','),
    'speech_not_on_device': (_speechNotOnDevice.toList()..sort()).join(','),
    'speech_unsupported': (_speechUnsupported.toList()..sort()).join(','),
    'script_guides_seen': (_scriptGuidesSeen.toList()..sort()).join(','),
    'paused_until': jsonEncode(<String, int>{
      for (final MapEntry(:key, :value) in _pausedUntil.entries)
        key.name: value.millisecondsSinceEpoch,
    }),
    'off_for': jsonEncode(<String, List<String>>{
      for (final MapEntry(:key, :value) in _offFor.entries)
        if (value.isNotEmpty) key.name: value.toList()..sort(),
    }),
    'facts_shown': jsonEncode(<String, int>{
      for (final MapEntry(:key, :value) in _factsShown.entries)
        key: value.millisecondsSinceEpoch,
    }),
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
    if (pick('facts_shown', _parseShown) case final v?) {
      _factsShown = Map<String, DateTime>.unmodifiable(v);
      notifyListeners();
    }
    if (pick('spoken_languages', (t) => t) case final v?) {
      spokenLanguages = <String>[
        for (final code in v.split(','))
          if (RegExp(r'^[a-z]{2,3}$').hasMatch(code)) code,
      ];
    }
    if (pick('learning_languages', (t) => t) case final v?) {
      learningLanguages = <String>[
        for (final code in v.split(','))
          if (RegExp(r'^[a-z]{2,3}$').hasMatch(code)) code,
      ];
    }
    if (pick('learning_chosen', flag) case final v?) learningChosen = v;
    if (pick('paused_until', _parseJsonMap) case final v?) {
      for (final MapEntry(:key, :value) in v.entries) {
        final skill = Skill.values.asNameMap()[key];
        if (skill != null && value is int) {
          pause(skill, until: DateTime.fromMillisecondsSinceEpoch(value));
        }
      }
    }
    if (pick('off_for', _parseJsonMap) case final v?) {
      for (final MapEntry(:key, :value) in v.entries) {
        final skill = Skill.values.asNameMap()[key];
        if (skill == null || value is! List) continue;
        for (final code in value) {
          if (code is String && RegExp(r'^[a-z]{2,3}$').hasMatch(code)) {
            setOffFor(skill, code, true);
          }
        }
      }
    }
    if (pick('speech_online', (t) => t) case final v?) {
      for (final code in v.split(',')) {
        if (RegExp(r'^[a-z]{2,3}$').hasMatch(code)) {
          allowOnlineSpeech(code, true);
        }
      }
    }
    if (pick('script_guides_seen', (t) => t) case final v?) {
      for (final code in v.split(',')) {
        if (RegExp(r'^[a-z]{2,3}$').hasMatch(code)) markScriptGuideSeen(code);
      }
    }
    for (final (name, unsupported) in <(String, bool)>[
      ('speech_not_on_device', false),
      ('speech_unsupported', true),
    ]) {
      if (pick(name, (t) => t) case final v?) {
        for (final code in v.split(',')) {
          if (RegExp(r'^[a-z]{2,3}$').hasMatch(code)) {
            foundSpeech(code, unsupported: unsupported);
          }
        }
      }
    }
    if (pick('placed_decks', (t) => t) case final v?) {
      placedDecks = <String>{
        for (final id in v.split(','))
          if (RegExp(r'^[a-z0-9-]+$').hasMatch(id)) id,
      };
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

  static Map<String, DateTime>? _parseShown(String text) {
    try {
      final map = jsonDecode(text);
      if (map is! Map) return null;
      return <String, DateTime>{
        for (final MapEntry(:key, :value) in map.entries)
          if (key is String && value is int)
            key: DateTime.fromMillisecondsSinceEpoch(value),
      };
    } on FormatException {
      return null;
    }
  }

  static Map<String, Object?>? _parseJsonMap(String text) {
    try {
      final map = jsonDecode(text);
      return map is Map<String, Object?> ? map : null;
    } on FormatException {
      return null;
    }
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
