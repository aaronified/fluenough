import '../scheduling/daily_budget.dart';

/// The Languages page's model (owner, 2026-10-30, #907): every language has
/// four skills, each Leave, Know or Learn. Plain Dart, with no Flutter, so
/// that it is tested on its own.
///
/// Speak and Hear belong to the language's one taught dialect; Read and
/// Write belong to a script, so a language written in two scripts has two
/// Read and two Write skills. A sign language has neither: it has exactly
/// one skill, Gestures, tested both ways, recognising a sign and making one
/// (owner, 2026-11-01: "It is one skill, tested both ways. One cannot write
/// a script without being able to read it.").

/// What the learner says about one skill.
enum SkillState {
  /// Out: not known, not learned.
  leave,

  /// Known. Instant: no download and no test ("rely on the user to know
  /// what they know").
  know,

  /// Learned: the language's full decks are downloaded.
  learn,
}

/// The skills: four for a spoken language, one for a sign language.
enum SkillKind {
  speak,
  hear,
  read,
  write,

  /// A sign language's one skill: recognising gestures and producing them,
  /// one state for both. It stands in place of Speak, Hear, Read and Write.
  gesture;

  /// Whether the skill belongs to a script, not to the dialect.
  bool get isScript => this == read || this == write;

  /// Whether it is a sign language's skill.
  bool get isGesture => this == gesture;
}

/// One skill of one language: [kind], and for Read and Write the [script]
/// as decks name it (`devanagari`, `perso_arabic`).
class SkillKey {
  const SkillKey(this.kind, [this.script])
    : assert(
        (script != null) == (kind == SkillKind.read || kind == SkillKind.write),
        'Read and Write have a script; Speak and Hear have none',
      );

  final SkillKind kind;
  final String? script;

  /// What is stored: `speak`, `read:devanagari`.
  String get id => script == null ? kind.name : '${kind.name}:$script';

  /// The key stored as [id], or null for anything else.
  static SkillKey? parse(String id) {
    final parts = id.split(':');
    final kind = SkillKind.values.asNameMap()[parts.first];
    if (kind == null || parts.length > 2) return null;
    if (kind.isScript) {
      if (parts.length != 2 || !RegExp(r'^[a-z_]+$').hasMatch(parts[1])) {
        return null;
      }
      return SkillKey(kind, parts[1]);
    }
    return parts.length == 1 ? SkillKey(kind) : null;
  }

  @override
  bool operator ==(Object other) =>
      other is SkillKey && other.kind == kind && other.script == script;

  @override
  int get hashCode => Object.hash(kind, script);

  @override
  String toString() => id;
}

/// The skills a language has: Speak and Hear unless it is script only (a
/// course such as English Braille), then Read and Write for each of
/// [scripts], in the order shown (all Read, then all Write). A [sign]
/// language has only the Gestures skill; a language with no [scripts]
/// otherwise has nothing to read or write, so no Read or Write.
List<SkillKey> skillsOfLanguage(
  Iterable<String> scripts, {
  bool scriptOnly = false,
  bool sign = false,
}) {
  if (sign) {
    return const <SkillKey>[SkillKey(SkillKind.gesture)];
  }
  final list = scripts.toList();
  return <SkillKey>[
    if (!scriptOnly) ...<SkillKey>[
      const SkillKey(SkillKind.speak),
      const SkillKey(SkillKind.hear),
    ],
    for (final s in list) SkillKey(SkillKind.read, s),
    for (final s in list) SkillKey(SkillKind.write, s),
  ];
}

/// The next state a tap on a skill's pill gives: Leave, Know, Learn, Leave.
/// Where the language has no decks to learn ([canLearn] false) Learn is
/// skipped.
SkillState nextSkillState(SkillState state, {required bool canLearn}) =>
    switch (state) {
      SkillState.leave => SkillState.know,
      SkillState.know => canLearn ? SkillState.learn : SkillState.leave,
      SkillState.learn => SkillState.leave,
    };

/// What a learner said about each skill of one language. Immutable; only
/// skills that are not Leave are held.
class LanguageSkills {
  LanguageSkills([Map<SkillKey, SkillState> states = const {}])
    : _states = Map<SkillKey, SkillState>.unmodifiable(<SkillKey, SkillState>{
        for (final e in states.entries)
          if (e.value != SkillState.leave) e.key: e.value,
      });

  /// Read back from [stored], as [toStored] wrote it; anything unreadable
  /// is dropped.
  factory LanguageSkills.fromStored(Map<String, Object?> stored) {
    final states = <SkillKey, SkillState>{};
    for (final e in stored.entries) {
      final key = SkillKey.parse(e.key);
      final state = SkillState.values.asNameMap()[e.value];
      if (key != null && state != null) states[key] = state;
    }
    return LanguageSkills(states);
  }

  final Map<SkillKey, SkillState> _states;

  /// What is stored: skill id to `know` or `learn`.
  Map<String, String> toStored() => <String, String>{
    for (final e in _states.entries) e.key.id: e.value.name,
  };

  SkillState stateOf(SkillKey key) => _states[key] ?? SkillState.leave;

  LanguageSkills withState(SkillKey key, SkillState state) =>
      LanguageSkills(<SkillKey, SkillState>{..._states, key: state});

  /// [key] after a tap on its pill.
  LanguageSkills cycled(SkillKey key, {required bool canLearn}) =>
      withState(key, nextSkillState(stateOf(key), canLearn: canLearn));

  /// A language with every skill Leave goes back to the pool: it leaves the
  /// list, and its decks are removed the next time the app opens.
  bool get isAllLeave => _states.isEmpty;

  bool get anyLearn => _states.containsValue(SkillState.learn);

  /// How many of [shape] are in [state], for "4/6 skills known".
  int count(SkillState state, Iterable<SkillKey> shape) =>
      shape.where((k) => stateOf(k) == state).length;

  /// The scripts one of whose skills ([kinds], Read and Write by default)
  /// is in [state].
  Set<String> scriptsIn(
    SkillState state, {
    Set<SkillKind> kinds = const <SkillKind>{SkillKind.read, SkillKind.write},
  }) => <String>{
    for (final e in _states.entries)
      if (e.value == state && kinds.contains(e.key.kind)) e.key.script!,
  };

  /// The skills held (not Leave).
  Iterable<SkillKey> get held => _states.keys;

  @override
  bool operator ==(Object other) =>
      other is LanguageSkills && _sameStates(other);

  bool _sameStates(LanguageSkills other) {
    if (other._states.length != _states.length) return false;
    for (final e in _states.entries) {
      if (other._states[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    _states.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// What the app held before skills (#907), read as skills until the learner
/// edits the language, so that a current learner sees no change.
///
/// A language learned: Speak and Hear Learn, and Read and Write Learn for
/// each script in [learnedScripts]; a script it reads (in [readsScript])
/// but does not learn is Know for Read. A language only known: Speak and
/// Hear Know, and Read Know for each script the learner said they read.
LanguageSkills skillsFromLegacy({
  required Iterable<String> scripts,
  required bool learned,
  required bool known,
  required Set<String> learnedScripts,
  required bool Function(String script) readsScript,
  bool scriptOnly = false,
  bool sign = false,
}) {
  if (!learned && !known) return LanguageSkills();
  final states = <SkillKey, SkillState>{};
  if (sign) {
    final s = learned ? SkillState.learn : SkillState.know;
    states[const SkillKey(SkillKind.gesture)] = s;
    return LanguageSkills(states);
  }
  final all = scripts.toList();
  if (!scriptOnly) {
    final s = learned ? SkillState.learn : SkillState.know;
    states[const SkillKey(SkillKind.speak)] = s;
    states[const SkillKey(SkillKind.hear)] = s;
  }
  for (final script in all) {
    if (learned && learnedScripts.contains(script)) {
      states[SkillKey(SkillKind.read, script)] = SkillState.learn;
      states[SkillKey(SkillKind.write, script)] = SkillState.learn;
    } else if (readsScript(script)) {
      states[SkillKey(SkillKind.read, script)] = SkillState.know;
    }
  }
  return LanguageSkills(states);
}

/// The language code of English, which is fixed (owner, 2026-10-31): Know in
/// every skill, the level found, never changed and never tested.
const String englishCode = 'en';

/// English as every learner has it (owner, 2026-10-30, #926; locked
/// 2026-10-31): Speak, Hear, Read and Write of the Latin script, all Know.
/// The app is unusable without it, and it makes the Latin script known for
/// everyone.
LanguageSkills englishKnownByDefault() => LanguageSkills(<SkillKey, SkillState>{
  const SkillKey(SkillKind.speak): SkillState.know,
  const SkillKey(SkillKind.hear): SkillState.know,
  const SkillKey(SkillKind.read, latinScript): SkillState.know,
  const SkillKey(SkillKind.write, latinScript): SkillState.know,
});

/// The script every learner knows (#926), as decks name it.
const String latinScript = 'latin';

/// [skills] of a language written in [scripts], with the Latin script's Read
/// and Write Know (#926; owner, 2026-10-31): everyone who knows English
/// knows the Latin script, so a Leave or a legacy Learn of it becomes Know.
/// The diacritics of Spanish or French are still taught by their courses
/// (Speak and Hear stay Learn). A language with every skill Leave stays so
/// (it is in the pool, not on the page), and one that does not use the Latin
/// script is unchanged.
LanguageSkills withLatinKnown(LanguageSkills skills, Iterable<String> scripts) {
  if (skills.isAllLeave) return skills;
  var next = skills;
  if (!scripts.contains(latinScript)) return skills;
  for (final kind in const <SkillKind>[SkillKind.read, SkillKind.write]) {
    final key = SkillKey(kind, latinScript);
    if (next.stateOf(key) != SkillState.know) {
      next = next.withState(key, SkillState.know);
    }
  }
  return next;
}

/// Where a script the learner already knows from another language starts:
/// Read and Write start as Know in a new language when the same script's
/// Read or Write is Know in another, and the name of that language.
/// [others] is the other languages' skills by their names.
Map<SkillKey, String> autoKnownFrom({
  required Iterable<String> scripts,
  required Map<String, LanguageSkills> others,
}) {
  final found = <SkillKey, String>{};
  for (final script in scripts) {
    for (final kind in const <SkillKind>[SkillKind.read, SkillKind.write]) {
      final key = SkillKey(kind, script);
      for (final e in others.entries) {
        if (e.value.stateOf(key) == SkillState.know) {
          found[key] = e.key;
          break;
        }
      }
    }
  }
  return found;
}

/// How a skill is marked on the list and the pill.
enum SkillMark { leave, know, knowCovered, learn }

/// Whether the found level covers a skill: a level is found for the whole
/// language at once, and covers everything the app can teach in it, so
/// [taught] is whether the course teaches that skill (it has a course).
/// [english] is always covered: it has no course and is never tested.
bool levelCovers({
  required bool levelFound,
  required bool taught,
  bool english = false,
}) => english || (levelFound && taught);

/// The mark of a skill in [state]: Know with the level covering it is the
/// double tick.
SkillMark markOf(SkillState state, {required bool covered}) => switch (state) {
  SkillState.leave => SkillMark.leave,
  SkillState.learn => SkillMark.learn,
  SkillState.know => covered ? SkillMark.knowCovered : SkillMark.know,
};

/// Whether the sheet says "Fit your level to be able to review" under
/// [rows]: only with review turned on in Settings, and for a Know skill the
/// level does not cover.
bool needsLevelFit({
  required bool reviewOn,
  required LanguageSkills skills,
  required Iterable<SkillKey> rows,
  required bool Function(SkillKey key) covered,
}) =>
    reviewOn &&
    rows.any((k) => skills.stateOf(k) == SkillState.know && !covered(k));

/// One test run before a skill changed to Learn is left standing.
sealed class SkillCheck {
  const SkillCheck();
}

/// Speak and Hear share one sound test per language. The Gestures skill of a
/// sign language needs no check.
class SoundCheck extends SkillCheck {
  const SoundCheck();
}

/// Read and Write of one script share one visibility check.
class ScriptCheck extends SkillCheck {
  const ScriptCheck(this.script);
  final String script;
}

/// The checks owed after [before] became [after] in the page: one for each
/// skill changed TO Learn. Changing away from Learn needs none; changing to
/// Learn again repeats it.
List<SkillCheck> checksOwed(Iterable<SkillKey> changedToLearn) {
  final list = <SkillCheck>[];
  var sound = false;
  final scripts = <String>[];
  for (final key in changedToLearn) {
    if (key.kind.isScript) {
      if (!scripts.contains(key.script)) scripts.add(key.script!);
    } else if (!key.kind.isGesture) {
      sound = true;
    }
  }
  if (sound) list.add(const SoundCheck());
  for (final s in scripts) {
    list.add(ScriptCheck(s));
  }
  return list;
}

/// Whether [skills] needs the language's full decks on the phone: one Learn
/// skill, in any script, is enough.
bool needsFullDecks(LanguageSkills skills) => skills.anyLearn;

/// The step of the minutes-a-day stepper: [direction] is -1 or 1. Five
/// minutes at a time, from 5 to 60.
int stepMinutes(int current, int direction) =>
    DailyBudget.clampMinutes(current + direction * DailyBudget.stepMinutes);

/// Whether the stepper's minus or plus is disabled at [minutes].
bool minutesAtEnd(int minutes, int direction) => direction < 0
    ? minutes <= DailyBudget.minMinutes
    : minutes >= DailyBudget.maxMinutes;
