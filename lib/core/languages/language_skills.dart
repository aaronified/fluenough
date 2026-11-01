import '../scheduling/daily_budget.dart';

/// The Languages page's model (owner, 2026-10-30, #907): every language has
/// four skills, each Leave, Know or Learn. Plain Dart, with no Flutter, so
/// that it is tested on its own.
///
/// Speak and Hear belong to the language's one taught dialect; Read and
/// Write belong to a script, so a language written in two scripts has two
/// Read and two Write skills.
///
/// A script is shown as one pill with four levels ([ScriptLevel], owner,
/// 2026-11-01: "Scripts can actually have one pill, and cycle through read
/// and write as levels of know."), and so are Speak and Hear ([SpokenLevel],
/// owner, 2026-11-01: "Same for other skills, if you can speak, you can hear
/// as well."). The level is derived from the two skills, which stay what is
/// stored.

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

/// The four skills.
enum SkillKind {
  speak,
  hear,
  read,
  write;

  /// Whether the skill belongs to a script, not to the dialect.
  bool get isScript => this == read || this == write;
}

/// One skill of one language: [kind], and for Read and Write the [script]
/// as decks name it (`devanagari`, `perso_arabic`; `latin` for a language
/// that lists none).
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
/// [scripts], in the order shown (all Read, then all Write).
List<SkillKey> skillsOfLanguage(
  Iterable<String> scripts, {
  bool scriptOnly = false,
}) {
  final list = scripts.isEmpty ? const <String>['latin'] : scripts.toList();
  return <SkillKey>[
    if (!scriptOnly) ...<SkillKey>[
      const SkillKey(SkillKind.speak),
      const SkillKey(SkillKind.hear),
    ],
    for (final s in list) SkillKey(SkillKind.read, s),
    for (final s in list) SkillKey(SkillKind.write, s),
  ];
}

/// The levels of one script's pill (owner, 2026-11-01), in the order a tap
/// goes through them: Leave, Learn, Read, Read and Write, Leave. Read and
/// Read and Write are the two levels of Know: one cannot write a script one
/// cannot read.
enum ScriptLevel {
  /// Out: neither read nor written, not learned.
  leave,

  /// Learned: the script's decks are taught (Read and Write both Learn).
  learn,

  /// Known to read, not to write (Read Know, Write Leave).
  read,

  /// Known to read and to write (Read and Write both Know).
  readWrite;

  /// Whether this is one of the two levels of Know.
  bool get isKnow => this == read || this == readWrite;
}

/// The level a tap on a script's pill gives next: Leave, Learn, Read, Read
/// and Write, Leave. Where the language has no decks to learn ([canLearn]
/// false) Learn is skipped.
ScriptLevel nextScriptLevel(ScriptLevel level, {required bool canLearn}) =>
    switch (level) {
      ScriptLevel.leave => canLearn ? ScriptLevel.learn : ScriptLevel.read,
      ScriptLevel.learn => ScriptLevel.read,
      ScriptLevel.read => ScriptLevel.readWrite,
      ScriptLevel.readWrite => ScriptLevel.leave,
    };

/// The levels of the Spoken pill (Speak and Hear together), in the order a
/// tap goes through them: Leave, Learn, Hear, Hear and Speak, Leave. Hear
/// and Hear and Speak are the two levels of Know: one cannot speak a
/// language one cannot hear.
enum SpokenLevel {
  /// Out: neither spoken nor heard, not learned.
  leave,

  /// Learned: Speak and Hear both Learn.
  learn,

  /// Known to hear, not to speak (Hear Know, Speak Leave).
  hear,

  /// Known to hear and to speak (Speak and Hear both Know).
  hearSpeak;

  /// Whether this is one of the two levels of Know.
  bool get isKnow => this == hear || this == hearSpeak;
}

/// The level a tap on the Spoken pill gives next: Leave, Learn, Hear, Hear
/// and Speak, Leave. Without decks to learn ([canLearn] false) Learn is
/// skipped.
SpokenLevel nextSpokenLevel(SpokenLevel level, {required bool canLearn}) =>
    switch (level) {
      SpokenLevel.leave => canLearn ? SpokenLevel.learn : SpokenLevel.hear,
      SpokenLevel.learn => SpokenLevel.hear,
      SpokenLevel.hear => SpokenLevel.hearSpeak,
      SpokenLevel.hearSpeak => SpokenLevel.leave,
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

  /// The Read and Write skills of [script].
  List<SkillKey> keysOfScript(String script) => <SkillKey>[
    SkillKey(SkillKind.read, script),
    SkillKey(SkillKind.write, script),
  ];

  /// The one level of [script]'s pill, read from its Read and Write: Learn
  /// if either is Learn; else Read and Write if Write is Know (it implies
  /// Read, so Write alone is read as both); else Read if Read is Know.
  ScriptLevel scriptLevelOf(String script) {
    final read = stateOf(SkillKey(SkillKind.read, script));
    final write = stateOf(SkillKey(SkillKind.write, script));
    if (read == SkillState.learn || write == SkillState.learn) {
      return ScriptLevel.learn;
    }
    if (write == SkillState.know) return ScriptLevel.readWrite;
    if (read == SkillState.know) return ScriptLevel.read;
    return ScriptLevel.leave;
  }

  /// [script] at [level], written as its two stored skills: Learn is Learn
  /// and Learn, Read is Know and Leave, Read and Write is Know and Know.
  LanguageSkills withScriptLevel(String script, ScriptLevel level) {
    final (read, write) = switch (level) {
      ScriptLevel.leave => (SkillState.leave, SkillState.leave),
      ScriptLevel.learn => (SkillState.learn, SkillState.learn),
      ScriptLevel.read => (SkillState.know, SkillState.leave),
      ScriptLevel.readWrite => (SkillState.know, SkillState.know),
    };
    return withState(
      SkillKey(SkillKind.read, script),
      read,
    ).withState(SkillKey(SkillKind.write, script), write);
  }

  /// The level of the Spoken pill, read from Speak and Hear: Learn if either
  /// is Learn; else Hear and Speak if Speak is Know (it implies Hear, so
  /// Speak alone is read as both); else Hear if Hear is Know.
  SpokenLevel get spokenLevel {
    final speak = stateOf(const SkillKey(SkillKind.speak));
    final hear = stateOf(const SkillKey(SkillKind.hear));
    if (speak == SkillState.learn || hear == SkillState.learn) {
      return SpokenLevel.learn;
    }
    if (speak == SkillState.know) return SpokenLevel.hearSpeak;
    if (hear == SkillState.know) return SpokenLevel.hear;
    return SpokenLevel.leave;
  }

  /// Speak and Hear at [level], written as the two stored skills.
  LanguageSkills withSpokenLevel(SpokenLevel level) {
    final (speak, hear) = switch (level) {
      SpokenLevel.leave => (SkillState.leave, SkillState.leave),
      SpokenLevel.learn => (SkillState.learn, SkillState.learn),
      SpokenLevel.hear => (SkillState.leave, SkillState.know),
      SpokenLevel.hearSpeak => (SkillState.know, SkillState.know),
    };
    return withState(
      const SkillKey(SkillKind.speak),
      speak,
    ).withState(const SkillKey(SkillKind.hear), hear);
  }

  /// The Spoken pill after a tap.
  LanguageSkills cycledSpoken({required bool canLearn}) =>
      withSpokenLevel(nextSpokenLevel(spokenLevel, canLearn: canLearn));

  /// [script] after a tap on its pill.
  LanguageSkills cycledScript(String script, {required bool canLearn}) =>
      withScriptLevel(
        script,
        nextScriptLevel(scriptLevelOf(script), canLearn: canLearn),
      );

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
}) {
  if (!learned && !known) return LanguageSkills();
  final states = <SkillKey, SkillState>{};
  final all = scripts.isEmpty ? const <String>['latin'] : scripts.toList();
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
  final all = scripts.isEmpty ? const <String>[latinScript] : scripts;
  if (!all.contains(latinScript)) return skills;
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
enum SkillMark {
  leave,
  know,
  knowCovered,

  /// A pill known at its higher level (Read and Write, Hear and Speak: a
  /// tick and the second skill's icon), and the same with the level covering
  /// it (a double tick and the icon).
  knowBoth,
  knowBothCovered,
  learn,
}

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

/// The mark of a script's pill at [level].
SkillMark scriptMarkOf(ScriptLevel level, {required bool covered}) =>
    switch (level) {
      ScriptLevel.leave => SkillMark.leave,
      ScriptLevel.learn => SkillMark.learn,
      ScriptLevel.read => covered ? SkillMark.knowCovered : SkillMark.know,
      ScriptLevel.readWrite =>
        covered ? SkillMark.knowBothCovered : SkillMark.knowBoth,
    };

/// The mark of the Spoken pill at [level].
SkillMark spokenMarkOf(SpokenLevel level, {required bool covered}) =>
    switch (level) {
      SpokenLevel.leave => SkillMark.leave,
      SpokenLevel.learn => SkillMark.learn,
      SpokenLevel.hear => covered ? SkillMark.knowCovered : SkillMark.know,
      SpokenLevel.hearSpeak =>
        covered ? SkillMark.knowBothCovered : SkillMark.knowBoth,
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

/// Speak and Hear share one sound test per language.
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
    } else {
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
