import 'package:yaml/yaml.dart';

/// Where the languages a learner can name are listed.
const String spokenLanguagesAsset = 'assets/languages.yaml';

/// A language a learner can say they speak (#53).
class SpokenLanguage {
  const SpokenLanguage({
    required this.code,
    required this.iso639_3,
    required this.name,
    required this.ownName,
    this.scripts = const <String>[],
    this.family,
    this.scriptQuestion,
    this.scriptCanRead,
    this.scriptsQuestion,
    this.scriptCanReadFor = const <String, String>{},
    this.scriptTextUnchecked = false,
    this.aliases = const <String>[],
    this.dialect,
    this.scriptOnly = false,
  });

  /// The same code decks use for `native.code`, such as `bn`.
  final String code;

  final String iso639_3;

  /// Its English name, such as "Bengali".
  final String name;

  /// Its name for itself, such as "বাংলা".
  final String ownName;

  /// The scripts it is written in, as decks name them (`latin`,
  /// `bengali`), its own first (#551): Punjabi's are `gurmukhi` and
  /// `shahmukhi`. Empty where the list does not say (#462).
  final List<String> scripts;

  /// Its own script, the first of [scripts]: the one its courses are
  /// written in. Null where the list does not say.
  String? get script => scripts.isEmpty ? null : scripts.first;

  /// Whether it is written in more than one script, so that Languages you
  /// know asks which of them are read (#551).
  bool get hasSeveralScripts => scripts.length > 1;

  /// Whether it is a sign language (family `sign`): it has one skill,
  /// Gestures (recognising and producing signs), and no script, dialect or
  /// voice.
  bool get isSign => family == 'sign';

  /// Where the answer for [script] is kept in what a learner says they
  /// read (`scripts_read`, #462, #551): its own script under the
  /// language's code, as every answer before #551 was kept, so that an old
  /// "reads" means its own script; any other under `code:script`.
  String readKey(String script) =>
      script == (this.script ?? '') ? code : '$code:$script';

  /// The scripts asked about: [scripts], or for a language the list gives
  /// none, one unnamed, `''`, kept under its code.
  List<String> get _asked => scripts.isEmpty ? const <String>[''] : scripts;

  /// The scripts of [scripts] that [answers] says are read, in their
  /// order; null when the language has not been answered. Empty is "I can
  /// only speak it".
  List<String>? scriptsReadIn(Map<String, bool> answers) {
    if (!answers.containsKey(code)) return null;
    return <String>[
      for (final s in _asked)
        if (answers[readKey(s)] ?? false) s,
    ];
  }

  /// The answers to keep for this language when [read] are the scripts
  /// read: one per script, each read or not.
  Map<String, bool> readAnswers(Iterable<String> read) {
    final set = read.toSet();
    return <String, bool>{for (final s in _asked) readKey(s): set.contains(s)};
  }

  /// The group it is listed in, folded by default (`indo_aryan`,
  /// `dravidian`, `tibeto_burman`, `austroasiatic`, `germanic`, `romance`,
  /// `sinitic`, `koreanic`, `japonic`, `constructed`), or null for a language
  /// the list puts in none (#490, #613).
  final String? family;

  /// The sheet's question, "Can you read the Bengali script?", written in
  /// the language's own script by a speaker of it, or null until one has
  /// (the sheet then asks in English) (#490).
  final String? scriptQuestion;

  /// The sheet's answer "I can read the Bengali script", in the same
  /// script, or null.
  final String? scriptCanRead;

  /// Whether the sheet asks in the language's own script: both sentences
  /// are there, checked or not (owner, 2026-10-18).
  bool get asksInOwnScript => scriptQuestion != null && scriptCanRead != null;

  /// Whether the texts above were written by Claude and no speaker has
  /// checked them (`script_text: "unchecked"`, #552). The sheet shows them all
  /// the same, with the English under them (owner, 2026-10-18: own-script
  /// texts for every language that has them, checked or not).
  final bool scriptTextUnchecked;

  /// For a language written in several scripts, the sheet's heading,
  /// "Which scripts do you read Punjabi in?", in its own first script, or
  /// null (the sheet then asks in English) (#552).
  final String? scriptsQuestion;

  /// For a language written in several scripts, the "I can read it" answer
  /// of each script, by script key, in the language's own first script. A
  /// script with none is answered in English (#552).
  final Map<String, String> scriptCanReadFor;

  /// Whether the sheet's heading for several scripts is in the language's
  /// own script.
  bool get asksScriptsInOwnScript => scriptsQuestion != null;

  /// The own-script "I can read it" answer for [script] of a language
  /// written in several, or null: none written.
  String? canReadIn(String script) => scriptCanReadFor[script];

  /// Whether [text] is written in the Perso-Arabic script (Urdu's, and
  /// Shahmukhi), which is drawn right to left. Decided by the text itself:
  /// a Shahmukhi answer written in Gurmukhi stays left to right.
  static bool isRtlText(String text) => text.runes.any(
    (r) =>
        (r >= 0x0600 && r <= 0x06FF) ||
        (r >= 0x0750 && r <= 0x077F) ||
        (r >= 0xFB50 && r <= 0xFDFF) ||
        (r >= 0xFE70 && r <= 0xFEFF),
  );

  /// The language code to mark [text], one of this language's own-script
  /// answers, with, for the voice and font that read it: Urdu for text in the
  /// Perso-Arabic script where that is not the language's own first script
  /// (Hindustani's second script), as the cards do, else the language's code.
  String localeCodeFor(String text) =>
      isRtlText(text) && !_ownScriptIsRtl ? 'ur' : code;

  /// Whether the language's own script is written right to left. Arabic is
  /// listed too, so a future Arabic-script own answer is drawn right to left.
  bool get _ownScriptIsRtl =>
      script == 'perso_arabic' || script == 'shahmukhi' || script == 'arabic';

  /// The one dialect the app teaches, by its proper name, such as
  /// "Majhi (ਮਾਝੀ), the Eastern Punjabi standard" (#907), or null where the
  /// list does not say: the page then says "Standard" and the language.
  final String? dialect;

  /// Whether the course teaches a script only, with no speech: English
  /// Braille. Such a language has Read and Write and no Speak or Hear.
  final bool scriptOnly;

  /// Other names a search finds it by (`aliases`), such as "Urdu" for
  /// Hindustani (#623).
  final List<String> aliases;

  /// Whether [query] is in its English name, its own name or an alias,
  /// ignoring case.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    return q.isNotEmpty &&
        (name.toLowerCase().contains(q) ||
            ownName.toLowerCase().contains(q) ||
            aliases.any((a) => a.toLowerCase().contains(q)));
  }
}

/// The scripts [answers] says the learner reads, each with the languages,
/// by code and in [all]'s order, that it was said for (#554). A script read
/// for one language is read for every language written in it: whoever reads
/// Eastern Nagari (`bengali`) through Bengali reads it for Assamese too. A
/// language [all] gives no script names none.
Map<String, List<String>> scriptReaders(
  List<SpokenLanguage> all,
  Map<String, bool> answers,
) {
  final readers = <String, List<String>>{};
  for (final language in all) {
    for (final script in language.scriptsReadIn(answers) ?? const <String>[]) {
      if (script.isEmpty) continue;
      readers.putIfAbsent(script, () => <String>[]).add(language.code);
    }
  }
  return readers;
}

/// The language code a key of `scripts_read` belongs to: the key itself,
/// or what comes before `:` (see [SpokenLanguage.readKey]).
String readKeyLanguage(String key) => key.split(':').first;

/// A key `scripts_read` keeps: a language's code, or a code and a script.
final RegExp readKeyPattern = RegExp(r'^[a-z]{2,3}(:[a-z_]+)?$');

/// The answers in [answers] for the languages [codes], every script's.
Map<String, bool> readAnswersOf(
  Iterable<String> codes,
  Map<String, bool> answers,
) {
  final keep = codes.toSet();
  return <String, bool>{
    for (final MapEntry(:key, :value) in answers.entries)
      if (keep.contains(readKeyLanguage(key))) key: value,
  };
}

/// The languages to offer first (#490): those of the phone's locales, then
/// English, then the languages of the phone's region, at most [limit], only
/// those in [all].
///
/// [locales] are the phone's languages as (language code, country code).
List<String> topPicksFor(
  List<(String, String?)> locales,
  List<SpokenLanguage> all, {
  int limit = 4,
}) {
  final known = <String>{for (final l in all) l.code};
  final picks = <String>[];
  void add(String code) {
    if (known.contains(code) && !picks.contains(code)) picks.add(code);
  }

  for (final (language, _) in locales) {
    add(language);
  }
  add('en');
  for (final (_, country) in locales) {
    for (final code
        in regionLanguages[country?.toUpperCase()] ?? const <String>[]) {
      add(code);
    }
  }
  return picks.take(limit).toList();
}

/// The languages most spoken in a region, for [topPicksFor]. A region not
/// here adds none.
const Map<String, List<String>> regionLanguages = <String, List<String>>{
  'IN': <String>['hi', 'bn', 'te', 'mr', 'ta'],
  'BD': <String>['bn'],
  'NP': <String>['ne'],
  'PK': <String>['hi'],
};

String? _optional(Object? item, String key, int i, [RegExp? pattern]) {
  final value = item is YamlMap ? item[key] : null;
  if (value == null) return null;
  if (value is! String ||
      value.trim().isEmpty ||
      (pattern != null && !pattern.hasMatch(value))) {
    throw FormatException('languages[$i]: $key is malformed');
  }
  return value.trim();
}

final _script = RegExp(r'^[a-z_]+$');

/// An entry's `aliases`: other names a search finds it by.
List<String> _aliases(Object? item, int i) {
  final list = item is YamlMap ? item['aliases'] : null;
  if (list == null) return const <String>[];
  if (list is! YamlList || list.any((a) => a is! String || a.trim().isEmpty)) {
    throw FormatException('languages[$i]: aliases is malformed');
  }
  return List<String>.unmodifiable(list.map((a) => (a as String).trim()));
}

/// An entry's `scripts`, its own first; or, as a list written before #551
/// has it, its one `script`.
List<String> _scripts(Object? item, int i) {
  final map = item is YamlMap ? item : null;
  final list = map?['scripts'];
  final one = map?['script'];
  if (list != null && one != null) {
    throw FormatException('languages[$i]: script and scripts both given');
  }
  if (one != null) {
    if (one is! String || !_script.hasMatch(one)) {
      throw FormatException('languages[$i]: script is malformed');
    }
    return <String>[one];
  }
  if (list == null) return const <String>[];
  if (list is! YamlList ||
      list.isEmpty ||
      list.any((s) => s is! String || !_script.hasMatch(s)) ||
      list.toSet().length != list.length) {
    throw FormatException('languages[$i]: scripts is malformed');
  }
  return List<String>.unmodifiable(list.cast<String>());
}

/// An entry's `script_can_read`: one sentence, or for a language written in
/// several scripts a map from script key to sentence (#552).
(String?, Map<String, String>) _canRead(
  Object? item,
  int i,
  List<String> scripts,
) {
  final value = item is YamlMap ? item['script_can_read'] : null;
  if (value is! YamlMap) {
    return (_optional(item, 'script_can_read', i), const <String, String>{});
  }
  if (scripts.length < 2) {
    throw FormatException(
      'languages[$i]: script_can_read is a map only for several scripts',
    );
  }
  final map = <String, String>{};
  for (final MapEntry(:key, :value) in value.entries) {
    if (key is! String ||
        !scripts.contains(key) ||
        value is! String ||
        value.trim().isEmpty) {
      throw FormatException('languages[$i]: script_can_read is malformed');
    }
    map[key] = value.trim();
  }
  return (null, Map<String, String>.unmodifiable(map));
}

/// Whether an entry's `script_text` says `unchecked` (#552). No other value
/// is known.
bool _unchecked(Object? item, int i) {
  final value = item is YamlMap ? item['script_text'] : null;
  if (value == null) return false;
  if (value != 'unchecked') {
    throw FormatException('languages[$i]: script_text is malformed');
  }
  return true;
}

final _code = RegExp(r'^[a-z]{2,3}$');
final _iso = RegExp(r'^[a-z]{3}$');

/// The languages in [text], `assets/languages.yaml`, in its order. Throws
/// [FormatException] naming the entry at fault.
List<SpokenLanguage> parseSpokenLanguages(String text) {
  final root = loadYaml(text);
  if (root is! YamlMap || root['kind'] != 'languages') {
    throw const FormatException('a languages file has "kind: languages"');
  }
  final list = root['languages'];
  if (list is! YamlList || list.isEmpty) {
    throw const FormatException('languages must be a non-empty list');
  }
  final seen = <String>{};
  final languages = <SpokenLanguage>[];
  for (final (i, item) in list.indexed) {
    String field(String key, [RegExp? pattern]) {
      final value = item is YamlMap ? item[key] : null;
      if (value is! String ||
          value.trim().isEmpty ||
          (pattern != null && !pattern.hasMatch(value))) {
        throw FormatException('languages[$i]: $key is missing or malformed');
      }
      return value.trim();
    }

    final code = field('code', _code);
    if (!seen.add(code)) {
      throw FormatException('languages[$i]: $code is listed twice');
    }
    final scripts = _scripts(item, i);
    final (canRead, canReadFor) = _canRead(item, i, scripts);
    final several = canReadFor.isNotEmpty;
    final scriptsQuestion = _optional(item, 'scripts_question', i);
    if (several
        ? (scriptsQuestion == null || item['script_question'] != null)
        : (scriptsQuestion != null ||
              (item['script_question'] == null) !=
                  (item['script_can_read'] == null))) {
      throw FormatException(
        'languages[$i]: script_question and script_can_read come together '
        '(scripts_question and a script_can_read map, for several scripts)',
      );
    }
    languages.add(
      SpokenLanguage(
        code: code,
        iso639_3: field('iso639_3', _iso),
        name: field('name'),
        ownName: field('own_name'),
        family: _optional(item, 'family', i, _script),
        scriptQuestion: _optional(item, 'script_question', i),
        scriptTextUnchecked: _unchecked(item, i),
        scriptCanRead: canRead,
        scriptsQuestion: scriptsQuestion,
        scriptCanReadFor: canReadFor,
        scripts: scripts,
        aliases: _aliases(item, i),
        dialect: _optional(item, 'dialect', i),
        scriptOnly: item['script_only'] == true,
      ),
    );
  }
  return languages;
}
