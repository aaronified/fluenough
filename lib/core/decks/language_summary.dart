import 'dart:convert';

import '../models/deck.dart' show LanguageInfo;
import '../scheduling/skill_map.dart';
import 'language_catalog.dart' show B1Unit, milestoneNamed;
import 'sha256.dart';

/// What the screens that list or name languages read, per language, so that
/// no deck has to be parsed for them (ADR-0062, Plan-Lazy-Language-Loading,
/// 3.4). It is a cache: worked out by the unit job that parses the language,
/// kept in one file, and rebuilt whenever its [stamp] no longer matches the
/// files. Pure Dart, no Flutter: this is in `lib/core` and stays so.

/// A deck of a language, as a list of decks needs it.
class SummaryDeck {
  const SummaryDeck({
    required this.id,
    this.name = '',
    required this.path,
    required this.native,
    required this.kind,
    this.genre,
    this.theme,
    this.hidden = false,
    this.adult = false,
    this.cards = 0,
    this.bundled = true,
    this.private = false,
  });

  final String id;

  /// The deck's name, which a list of the learner's own decks shows.
  final String name;
  final String path;
  final String native;
  final String kind;
  final String? genre;
  final String? theme;
  final bool hidden;
  final bool adult;
  final int cards;
  final bool bundled;
  final bool private;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'path': path,
    'native': native,
    'kind': kind,
    'genre': ?genre,
    'theme': ?theme,
    if (hidden) 'hidden': true,
    if (adult) 'adult': true,
    'cards': cards,
    if (!bundled) 'bundled': false,
    if (private) 'private': true,
  };

  static SummaryDeck fromJson(Map<Object?, Object?> json) => SummaryDeck(
    id: json['id']! as String,
    name: (json['name'] as String?) ?? '',
    path: json['path']! as String,
    native: json['native']! as String,
    kind: json['kind']! as String,
    genre: json['genre'] as String?,
    theme: json['theme'] as String?,
    hidden: json['hidden'] == true,
    adult: json['adult'] == true,
    cards: json['cards']! as int,
    bundled: json['bundled'] != false,
    private: json['private'] == true,
  );
}

/// A letter of a script deck with its reading, which the language picker
/// previews: the first cards of the course's first script deck.
class SummaryLetter {
  const SummaryLetter({required this.letter, this.reading});

  final String letter;
  final String? reading;

  Map<String, Object?> toJson() => <String, Object?>{
    'letter': letter,
    'reading': ?reading,
  };

  static SummaryLetter fromJson(Map<Object?, Object?> json) => SummaryLetter(
    letter: json['letter']! as String,
    reading: json['reading'] as String?,
  );
}

/// How many letters of a script deck a summary keeps for the picker's
/// preview of a script.
const int summaryLetterCount = 8;

/// One course of a language: the language taught from one native language.
class SummaryCourse {
  const SummaryCourse({
    required this.native,
    required this.nativeName,
    required this.units,
    this.nativeInfo,
    this.decks = 0,
    this.cards = 0,
    this.words = 0,
    this.cultureCards = 0,
    this.hasPath = false,
    this.coveredUnits = 0,
    this.writtenUnits = 0,
    this.scriptLetters = const <SummaryLetter>[],
  });

  final String native;
  final String nativeName;

  /// The native language as its decks name it, or null in a summary written
  /// before it was kept.
  final LanguageInfo? nativeInfo;

  /// [nativeInfo], or the language [native] with only its name known.
  LanguageInfo get nativeLanguage =>
      nativeInfo ??
      LanguageInfo(code: native, iso639_3: native, name: nativeName);

  /// How many of the language's written units this course teaches, and how
  /// many units the language has written (`CoursePath.coveredUnits` and
  /// `writtenUnits`).
  final int coveredUnits;
  final int writtenUnits;

  /// The first letters of the course's first script deck, up to
  /// [summaryLetterCount], with their readings.
  final List<SummaryLetter> scriptLetters;

  /// The units of its path as completeness counts them (`B1Unit`).
  final List<B1Unit> units;
  final int decks;
  final int cards;

  /// Distinct cards that count as words.
  final int words;

  /// Cards of its culture decks.
  final int cultureCards;
  final bool hasPath;

  Map<String, Object?> toJson() => <String, Object?>{
    'native': native,
    'nativeName': nativeName,
    'units': <Object?>[for (final unit in units) _unitToJson(unit)],
    'decks': decks,
    'cards': cards,
    'words': words,
    'cultureCards': cultureCards,
    if (hasPath) 'hasPath': true,
    if (nativeInfo != null) 'nativeInfo': _infoToJson(nativeInfo!),
    if (coveredUnits != 0) 'coveredUnits': coveredUnits,
    if (writtenUnits != 0) 'writtenUnits': writtenUnits,
    if (scriptLetters.isNotEmpty)
      'scriptLetters': <Object?>[for (final l in scriptLetters) l.toJson()],
  };

  static SummaryCourse fromJson(Map<Object?, Object?> json) => SummaryCourse(
    native: json['native']! as String,
    nativeName: json['nativeName']! as String,
    nativeInfo: json['nativeInfo'] is Map
        ? _infoFromJson(json['nativeInfo']! as Map<Object?, Object?>)
        : null,
    coveredUnits: (json['coveredUnits'] as int?) ?? 0,
    writtenUnits: (json['writtenUnits'] as int?) ?? 0,
    scriptLetters: <SummaryLetter>[
      for (final l in (json['scriptLetters'] as List<Object?>?) ?? <Object?>[])
        SummaryLetter.fromJson(l! as Map<Object?, Object?>),
    ],
    units: <B1Unit>[
      for (final unit in json['units']! as List<Object?>)
        _unitFromJson(unit! as Map<Object?, Object?>),
    ],
    decks: json['decks']! as int,
    cards: json['cards']! as int,
    words: json['words']! as int,
    cultureCards: json['cultureCards']! as int,
    hasPath: json['hasPath'] == true,
  );
}

Map<String, Object?> _unitToJson(B1Unit unit) => <String, Object?>{
  if (unit.planned) 'planned': true,
  'words': ?unit.words,
  if (unit.milestone != null) 'milestone': unit.milestone!.name.toUpperCase(),
  if (unit.grammar.isNotEmpty) 'grammar': unit.grammar,
  'has': ?unit.has,
};

B1Unit _unitFromJson(Map<Object?, Object?> json) => B1Unit(
  planned: json['planned'] == true,
  words: json['words'] as int?,
  milestone: milestoneNamed(json['milestone'] as String?),
  grammar: <String>[
    for (final topic in (json['grammar'] as List<Object?>?) ?? <Object?>[])
      topic! as String,
  ],
  has: json['has'] as int?,
);

/// What a summary was worked out from, so that it can be checked without
/// parsing anything.
class SummaryStamp {
  const SummaryStamp({
    required this.format,
    required this.filesDigest,
    required this.app,
  });

  /// [LanguageSummary.format] when it was written.
  final int format;

  /// [filesDigestOf] the SHA-256s of the language's files.
  final String filesDigest;

  /// The app version that wrote it.
  final String app;

  Map<String, Object?> toJson() => <String, Object?>{
    'format': format,
    'filesDigest': filesDigest,
    'app': app,
  };

  static SummaryStamp fromJson(Map<Object?, Object?> json) => SummaryStamp(
    format: json['format']! as int,
    filesDigest: json['filesDigest']! as String,
    app: json['app']! as String,
  );
}

/// A SHA-256 over the sorted (path, SHA-256) pairs in [shas]: one value that
/// changes when a file of the language is added, removed or changed.
String filesDigestOf(Map<String, String> shas) {
  final lines = <String>[for (final e in shas.entries) '${e.key}\t${e.value}']
    ..sort();
  return sha256Hex(utf8.encode(lines.join('\n')));
}

/// One line of what a language credits: a source, a recording's or picture's
/// credit, or a project whose data its decks use.
class SummaryCreditLine {
  const SummaryCreditLine({
    required this.text,
    this.extra = '',
    this.adult = false,
  });

  /// The source's name, the credit, or the project's name.
  final String text;

  /// The kind of deck that names a source, or the licence of a credit.
  final String extra;

  /// Whether only adult decks gave it: the Sources page leaves it out while
  /// Adult content is off.
  final bool adult;

  Map<String, Object?> toJson() => <String, Object?>{
    'text': text,
    if (extra.isNotEmpty) 'extra': extra,
    if (adult) 'adult': true,
  };

  static SummaryCreditLine fromJson(Map<Object?, Object?> json) =>
      SummaryCreditLine(
        text: json['text']! as String,
        extra: (json['extra'] as String?) ?? '',
        adult: json['adult'] == true,
      );
}

/// What a language's decks credit, for Settings' Sources page, which lists
/// every language's from the directory (Plan-Lazy-Language-Loading, P-C5):
/// the books its decks name, the credits of its recordings and images, those
/// of the portraits and posters of its people and works, and the projects
/// whose data it uses.
class SummaryCredits {
  const SummaryCredits({
    this.sources = const <SummaryCreditLine>[],
    this.media = const <SummaryCreditLine>[],
    this.pictures = const <SummaryCreditLine>[],
    this.content = const <SummaryCreditLine>[],
  });

  /// Nothing credited.
  static const SummaryCredits none = SummaryCredits();

  final List<SummaryCreditLine> sources;
  final List<SummaryCreditLine> media;
  final List<SummaryCreditLine> pictures;
  final List<SummaryCreditLine> content;

  Map<String, Object?> toJson() => <String, Object?>{
    'sources': <Object?>[for (final line in sources) line.toJson()],
    'media': <Object?>[for (final line in media) line.toJson()],
    'pictures': <Object?>[for (final line in pictures) line.toJson()],
    'content': <Object?>[for (final line in content) line.toJson()],
  };

  static SummaryCredits fromJson(Map<Object?, Object?> json) {
    List<SummaryCreditLine> lines(Object? value) => <SummaryCreditLine>[
      for (final line in (value as List<Object?>?) ?? <Object?>[])
        SummaryCreditLine.fromJson(line! as Map<Object?, Object?>),
    ];
    return SummaryCredits(
      sources: lines(json['sources']),
      media: lines(json['media']),
      pictures: lines(json['pictures']),
      content: lines(json['content']),
    );
  }
}

/// One language on the phone, as the screens that list languages read it.
class LanguageSummary {
  const LanguageSummary({
    required this.code,
    required this.info,
    required this.courses,
    required this.decks,
    required this.stamp,
    this.scriptDecks = const <String>[],
    this.hasAlphabet = false,
    this.primaryScript = 'latin',
    this.formHeardCards = const <String>[],
    this.hasPath = false,
    this.planUnits = 0,
    this.hasFacts = false,
    this.hasSituations = false,
    this.hasTopics = false,
    this.hasCulture = false,
    this.hasRomanisation = false,
    this.hasSounds = false,
    this.hasNumbers = false,
    this.scriptGuideKeys = const <String>[],
    this.glyph = '',
    this.scriptCount = 0,
    this.ipaSymbols = const <String>[],
    this.voiceSample = const <String>[],
    this.privatelyModified = false,
    this.credits = SummaryCredits.none,
  });

  /// The layout of the JSON, and of what a summary holds. Raised when a field
  /// is added, removed or means something else: an older summary is then not
  /// trusted and is worked out again. 2 added the glyph, the script count and
  /// each course's native language, written units and script letters, for the
  /// screens that list languages (Plan-Lazy-Language-Loading, P-C1). 3 added
  /// the IPA symbols, for the IPA keyboard (P-C4). 4 added each deck's name,
  /// the voice sample, whether a private package modifies the language and
  /// what its decks credit, for Your decks, Voices, the "Privately modified"
  /// tag and Sources (P-C5).
  static const int format = 4;

  final String code;
  final LanguageInfo info;
  final List<SummaryCourse> courses;
  final List<SummaryDeck> decks;
  final SummaryStamp stamp;

  /// The decks its path lists under `alphabet` (the skill map's script
  /// decks), whether the language has any, and the script its course starts
  /// with.
  final List<String> scriptDecks;
  final bool hasAlphabet;
  final String primaryScript;

  /// The cards that ask for what is heard (`Card.hearsForm`).
  final List<String> formHeardCards;

  final bool hasPath;
  final int planUnits;
  final bool hasFacts;
  final bool hasSituations;
  final bool hasTopics;
  final bool hasCulture;
  final bool hasRomanisation;
  final bool hasSounds;
  final bool hasNumbers;
  final List<String> scriptGuideKeys;

  /// What the language's chip shows: its icon, else the glyph of its first
  /// deck, so that no deck is scanned for it.
  final String glyph;

  /// How many decks the language's path lists under `alphabet`, whether or
  /// not each is on the phone: the picker's "3 script decks".
  final int scriptCount;

  /// Every answer the IPA course asks for, and its alternatives, once each:
  /// the IPA keyboard's symbols are found from them, so that typing never
  /// waits for the course's unit. Empty for every other language.
  final List<String> ipaSymbols;

  /// Up to three target texts the Voices page's Play says for the language:
  /// the first words of its first vocabulary deck that are not rude ones.
  final List<String> voiceSample;

  /// Whether the language's path is that of a private package that modifies
  /// it (`LanguagePath.privatelyModified`).
  final bool privatelyModified;

  /// What the language's decks credit.
  final SummaryCredits credits;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'info': _infoToJson(info),
    'courses': <Object?>[for (final c in courses) c.toJson()],
    'decks': <Object?>[for (final d in decks) d.toJson()],
    'scriptDecks': scriptDecks,
    'hasAlphabet': hasAlphabet,
    'primaryScript': primaryScript,
    'formHeardCards': formHeardCards,
    'hasPath': hasPath,
    'planUnits': planUnits,
    'hasFacts': hasFacts,
    'hasSituations': hasSituations,
    'hasTopics': hasTopics,
    'hasCulture': hasCulture,
    'hasRomanisation': hasRomanisation,
    'hasSounds': hasSounds,
    'hasNumbers': hasNumbers,
    'scriptGuideKeys': scriptGuideKeys,
    'glyph': glyph,
    'scriptCount': scriptCount,
    'ipaSymbols': ipaSymbols,
    'voiceSample': voiceSample,
    'privatelyModified': privatelyModified,
    'credits': credits.toJson(),
    'stamp': stamp.toJson(),
  };

  /// [json] as a summary, or null when it is not one. Never throws.
  static LanguageSummary? tryFromJson(Object? json) {
    try {
      if (json is! Map) return null;
      List<String> strings(Object? value) => <String>[
        for (final item in value! as List<Object?>) item! as String,
      ];
      final credits = json['credits'];
      return LanguageSummary(
        code: json['code']! as String,
        info: _infoFromJson(json['info']! as Map<Object?, Object?>),
        courses: <SummaryCourse>[
          for (final c in json['courses']! as List<Object?>)
            SummaryCourse.fromJson(c! as Map<Object?, Object?>),
        ],
        decks: <SummaryDeck>[
          for (final d in json['decks']! as List<Object?>)
            SummaryDeck.fromJson(d! as Map<Object?, Object?>),
        ],
        scriptDecks: strings(json['scriptDecks']),
        hasAlphabet: json['hasAlphabet']! as bool,
        primaryScript: json['primaryScript']! as String,
        formHeardCards: strings(json['formHeardCards']),
        hasPath: json['hasPath']! as bool,
        planUnits: json['planUnits']! as int,
        hasFacts: json['hasFacts']! as bool,
        hasSituations: json['hasSituations']! as bool,
        hasTopics: json['hasTopics']! as bool,
        hasCulture: json['hasCulture']! as bool,
        hasRomanisation: json['hasRomanisation']! as bool,
        hasSounds: json['hasSounds']! as bool,
        hasNumbers: json['hasNumbers']! as bool,
        scriptGuideKeys: strings(json['scriptGuideKeys']),
        // Kept since format 2: a summary of format 1 still names its
        // languages while it is worked out again.
        glyph: (json['glyph'] as String?) ?? '',
        scriptCount: (json['scriptCount'] as int?) ?? 0,
        // Kept since format 3, in the same way.
        ipaSymbols: json['ipaSymbols'] == null
            ? const <String>[]
            : strings(json['ipaSymbols']),
        // Kept since format 4, in the same way.
        voiceSample: json['voiceSample'] == null
            ? const <String>[]
            : strings(json['voiceSample']),
        privatelyModified: json['privatelyModified'] == true,
        credits: credits is Map
            ? SummaryCredits.fromJson(credits)
            : SummaryCredits.none,
        stamp: SummaryStamp.fromJson(json['stamp']! as Map<Object?, Object?>),
      );
    } on Object {
      return null;
    }
  }
}

Map<String, Object?> _infoToJson(LanguageInfo info) => <String, Object?>{
  'code': info.code,
  'iso639_3': info.iso639_3,
  'name': info.name,
  'script': info.script,
  if (info.scripts.isNotEmpty) 'scripts': info.scripts,
  'tts': ?info.tts,
  if (info.rtl) 'rtl': true,
  'icon': ?info.icon,
  if (!info.typed) 'typed': false,
};

LanguageInfo _infoFromJson(Map<Object?, Object?> json) => LanguageInfo(
  code: json['code']! as String,
  iso639_3: json['iso639_3']! as String,
  name: json['name']! as String,
  script: json['script']! as String,
  scripts: <String>[
    for (final s in (json['scripts'] as List<Object?>?) ?? <Object?>[])
      s! as String,
  ],
  tts: json['tts'] as String?,
  rtl: json['rtl'] == true,
  icon: json['icon'] as String?,
  typed: json['typed'] != false,
);

/// The skill map (ADR-0034) of the languages in [summaries], which is what
/// `AppState` builds from every card of every deck: the cards that ask for
/// what is heard, the decks a path lists under `alphabet`, and each course's
/// primary script. A language with no deck to teach from adds nothing, as it
/// adds nothing to the map made from the decks.
SkillMap skillMapOf(Iterable<LanguageSummary> summaries) {
  final heard = <String>{};
  final scripts = <String>{};
  final primary = <String, String>{};
  for (final summary in summaries) {
    if (!summary.decks.any((deck) => !deck.hidden)) continue;
    heard.addAll(summary.formHeardCards);
    scripts.addAll(summary.scriptDecks);
    primary[summary.code] = summary.primaryScript;
  }
  return SkillMap(
    formHeardCards: heard,
    scriptDecks: scripts,
    primaryScripts: primary,
  );
}

/// How much a stored summary can be trusted (3.4): [fresh] is used as it is,
/// [refresh] is used and worked out again in idle time, [untrusted] is not
/// used until it has been worked out again.
enum SummaryFreshness { fresh, refresh, untrusted }

/// The summaries of every language on the phone as one file's text.
String encodeSummaries(Iterable<LanguageSummary> summaries) =>
    jsonEncode(<String, Object?>{
      'format': LanguageSummary.format,
      'summaries': <String, Object?>{
        for (final s in summaries) s.code: s.toJson(),
      },
    });

/// The summaries in [text], by language code: none when [text] is null or
/// damaged, and an entry that is damaged is left out. Never throws.
Map<String, LanguageSummary> decodeSummaries(String? text) {
  if (text == null || text.isEmpty) return const <String, LanguageSummary>{};
  try {
    final json = jsonDecode(text);
    if (json is! Map || json['summaries'] is! Map) {
      return const <String, LanguageSummary>{};
    }
    final out = <String, LanguageSummary>{};
    for (final e in (json['summaries'] as Map).entries) {
      final summary = LanguageSummary.tryFromJson(e.value);
      if (summary != null && e.key == summary.code) out[summary.code] = summary;
    }
    return out;
  } on Object {
    return const <String, LanguageSummary>{};
  }
}

/// How far [summary] can be trusted for files whose digest is [filesDigest]
/// under app version [app].
SummaryFreshness freshnessOf(
  LanguageSummary summary, {
  required String filesDigest,
  required String app,
}) {
  final stamp = summary.stamp;
  if (stamp.format != LanguageSummary.format ||
      stamp.filesDigest != filesDigest) {
    return SummaryFreshness.untrusted;
  }
  return stamp.app == app ? SummaryFreshness.fresh : SummaryFreshness.refresh;
}
