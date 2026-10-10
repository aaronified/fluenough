import 'dart:convert';

/// The newest index format this app reads. An index of a later version
/// asks for an app update instead (ADR-0037).
const int supportedIndexVersion = 1;

/// The newest deck schema this app reads. A file of a later schema is not
/// downloaded, and its language says the app needs updating.
const int supportedDeckSchema = 1;

/// How many decks of a language's path must be on the phone before it can
/// be learned: the rest download behind them (ADR-0037).
const int decksBeforeReady = 5;

/// Kinds of file that hold no deck: at most one of each per language.
const Set<String> languageFileKinds = <String>{
  'path',
  'facts',
  'numbers',
  'romanisation',
  'sounds',
  'script',
};

/// What a file path in the index must look like: a YAML file in a
/// language's folder, or in a native language's folder in it. Anything else,
/// such as `..`, is refused, so a bad index cannot write outside the
/// downloads.
final RegExp _filePath = RegExp(
  r'^decks/[a-z]{2,3}/(?:[a-z]{2,3}/)?[a-z0-9]+(?:-[a-z0-9]+)*\.yaml$',
);

final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

/// One file of a language in the index (`decks/index.json`).
class IndexFile {
  const IndexFile({
    required this.path,
    required this.size,
    required this.sha256,
    this.schema = 1,
    this.kind = 'vocab',
    this.native,
    this.deck,
    this.core = false,
    this.proposed = 0,
  });

  /// Where it is in the repository, which is also its path on the phone
  /// and in the catalog: `decks/hi/hi-en-family.yaml`.
  final String path;

  /// Its size in bytes.
  final int size;

  /// Its SHA-256, 64 lower-case hex digits. A download that does not match
  /// it is thrown away.
  final String sha256;

  final int schema;

  /// The file's `kind`: `vocab`, `grammar`, `layer`, `path`, `facts`…
  final String kind;

  /// The native language a deck or layer teaches from; null for a core and
  /// for the language's other files.
  final String? native;

  /// The core id a deck is listed as on its language's path (`hi-family`
  /// for `hi-en-family`); null for a file that is no deck.
  final String? deck;

  /// Whether it is a core (`part: "core"`), shared by every native
  /// language's layer.
  final bool core;

  /// How many changes reviewers have proposed in it and not yet agreed
  /// (ADR-0038). Learners never see them.
  final int proposed;

  /// The language it belongs to: its folder under `decks/`.
  String get language => path.split('/')[1];

  /// Whether it is one of the language's own files, not a deck.
  bool get isLanguageFile => languageFileKinds.contains(kind);

  /// Whether this app can read it.
  bool get readable => schema <= supportedDeckSchema;

  static IndexFile _parse(Object? json) {
    if (json is! Map) throw const FormatException('a file is not an object');
    final path = json['path'];
    final size = json['size'];
    final sha = json['sha256'];
    final schema = json['schema'];
    final kind = json['kind'];
    if (path is! String || !_filePath.hasMatch(path)) {
      throw FormatException('a file has a bad path: $path');
    }
    if (size is! int || size < 0) {
      throw FormatException('$path has a bad size');
    }
    if (sha is! String || !_hex64.hasMatch(sha)) {
      throw FormatException('$path has a bad sha256');
    }
    final native = json['native'];
    final deck = json['deck'];
    return IndexFile(
      path: path,
      size: size,
      sha256: sha,
      schema: schema is int ? schema : 1,
      kind: kind is String ? kind : 'vocab',
      native: native is String ? native : null,
      deck: deck is String ? deck : null,
      core: json['part'] == 'core',
      proposed: json['proposed'] is int ? json['proposed'] as int : 0,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'size': size,
    'sha256': sha256,
    'schema': schema,
    'kind': kind,
    'native': ?native,
    'deck': ?deck,
    if (core) 'part': 'core',
    if (proposed > 0) 'proposed': proposed,
  };

  /// What this file is to its language, so that a file it replaces can be
  /// found under another name: a deck by its core id and native language,
  /// a core by its id, and a language file by its kind.
  String get role => isLanguageFile
      ? 'kind:$kind'
      : core
      ? 'core:$deck'
      : deck == null
      ? 'file:$path'
      : 'deck:$deck:$native';
}

/// A unit of a language's path, as the index counts it.
class IndexUnit {
  const IndexUnit({
    this.decks = const <String>[],
    this.planned = false,
    this.words,
    this.milestone,
    this.grammar = const <String>[],
    this.has = const <String, int>{},
  });

  /// Its decks' core ids.
  final List<String> decks;

  /// Whether it is planned and not written yet.
  final bool planned;

  /// Its planned size in words, or null without a B1 plan.
  final int? words;

  /// `A1`, `A2` or `B1` where a level ends on it.
  final String? milestone;

  /// The grammar topics it teaches, or plans to, by topic id.
  final List<String> grammar;

  /// The words its decks have, by native language.
  final Map<String, int> has;

  static IndexUnit _parse(Object? json) {
    if (json is! Map) throw const FormatException('a unit is not an object');
    final has = json['has'];
    return IndexUnit(
      decks: _strings(json['decks']),
      planned: json['planned'] == true,
      words: json['words'] is int ? json['words'] as int : null,
      milestone: json['milestone'] is String
          ? json['milestone'] as String
          : null,
      grammar: _strings(json['grammar']),
      has: <String, int>{
        if (has is Map)
          for (final MapEntry(:key, :value) in has.entries)
            if (key is String && value is int) key: value,
      },
    );
  }
}

/// A native language a language is taught from.
typedef IndexNative = ({String code, String name});

/// A language the index offers.
class IndexLanguage {
  const IndexLanguage({
    required this.code,
    required this.name,
    this.ownName,
    this.icon,
    this.script,
    this.scriptDecks = false,
    this.natives = const <IndexNative>[],
    this.size = 0,
    this.path = const <String>[],
    this.units = const <IndexUnit>[],
    this.files = const <IndexFile>[],
  });

  final String code;

  /// Its English name.
  final String name;

  /// Its name for itself, where known.
  final String? ownName;

  /// What its chip shows (ADR-0027).
  final String? icon;
  final String? script;

  /// Whether its course has decks that teach the script.
  final bool scriptDecks;

  /// The native languages its decks teach from.
  final List<IndexNative> natives;

  /// Every file's size, added up, in bytes.
  final int size;

  /// Its decks' core ids, in teaching order.
  final List<String> path;
  final List<IndexUnit> units;
  final List<IndexFile> files;

  /// The native languages a learner who speaks [spoken], best known first,
  /// is taught this language from: those of [spoken] it has decks for, or
  /// where it has none, English, or failing that every one it has
  /// (ADR-0037).
  List<String> nativesFor(List<String> spoken) {
    final have = <String>{for (final n in natives) n.code};
    final mine = <String>[
      for (final code in spoken)
        if (have.contains(code)) code,
    ];
    if (mine.isNotEmpty) return mine;
    if (have.contains('en')) return const <String>['en'];
    return have.toList()..sort();
  }

  /// Whether a learner who speaks [spoken] is taught from a language they
  /// do not speak, which the app then says: "Taught from English".
  bool taughtFromOther(List<String> spoken) =>
      natives.isNotEmpty && !natives.any((n) => spoken.contains(n.code));

  /// The files a learner from [natives] downloads: the language's own
  /// files, its cores, and its decks and layers for [natives]. Files of a
  /// schema this app cannot read are left out ([unreadable]).
  List<IndexFile> filesFor(Iterable<String> natives) {
    final wanted = natives.toSet();
    return <IndexFile>[
      for (final file in files)
        if (file.readable &&
            (file.native == null || wanted.contains(file.native)))
          file,
    ];
  }

  /// The files [filesFor] leaves out because this app cannot read them.
  List<IndexFile> unreadable(Iterable<String> natives) {
    final wanted = natives.toSet();
    return <IndexFile>[
      for (final file in files)
        if (!file.readable &&
            (file.native == null || wanted.contains(file.native)))
          file,
    ];
  }

  /// The files that must be on the phone before the language can be
  /// learned from [natives]: its own files (its path, romanisation and the
  /// like, all small), and the first [count] decks of its path the learner
  /// has, each with its core. The rest of [filesFor] can follow.
  List<IndexFile> firstFiles(Iterable<String> natives, {int count = 5}) {
    final all = filesFor(natives);
    final byDeck = <String, List<IndexFile>>{};
    for (final file in all) {
      if (file.deck case final deck?) {
        (byDeck[deck] ??= <IndexFile>[]).add(file);
      }
    }
    // A deck counts once a learner can open it: a single-file deck, or a
    // layer with its core. A core alone teaches nobody.
    bool teaches(List<IndexFile> files) => files.any((f) => !f.core);
    final first = <IndexFile>[];
    var taken = 0;
    final order = <String>[
      ...path,
      // Decks the path leaves out, which the validator refuses, go last.
      for (final deck in byDeck.keys)
        if (!path.contains(deck)) deck,
    ];
    for (final deck in order) {
      if (taken >= count) break;
      final files = byDeck[deck];
      if (files == null || !teaches(files)) continue;
      first.addAll(files);
      taken++;
    }
    return <IndexFile>[
      for (final file in all)
        if (file.isLanguageFile || first.contains(file)) file,
    ];
  }

  static IndexLanguage _parse(Object? json) {
    if (json is! Map) {
      throw const FormatException('a language is not an object');
    }
    final code = json['code'];
    final name = json['name'];
    if (code is! String || !RegExp(r'^[a-z]{2,3}$').hasMatch(code)) {
      throw FormatException('a language has a bad code: $code');
    }
    final files = <IndexFile>[
      for (final file in _list(json['files'])) IndexFile._parse(file),
    ];
    for (final file in files) {
      if (file.language != code) {
        throw FormatException('${file.path} is not in decks/$code/');
      }
    }
    final natives = <IndexNative>[
      for (final n in _list(json['natives']))
        if (n is Map && n['code'] is String)
          (
            code: n['code'] as String,
            name: n['name'] is String
                ? n['name'] as String
                : n['code'] as String,
          ),
    ];
    return IndexLanguage(
      code: code,
      name: name is String ? name : code,
      ownName: json['own_name'] is String ? json['own_name'] as String : null,
      icon: json['icon'] is String ? json['icon'] as String : null,
      script: json['script'] is String ? json['script'] as String : null,
      scriptDecks: json['script_decks'] == true,
      natives: natives,
      size: json['size'] is int
          ? json['size'] as int
          : files.fold(0, (sum, f) => sum + f.size),
      path: _strings(json['path']),
      units: <IndexUnit>[
        for (final unit in _list(json['units'])) IndexUnit._parse(unit),
      ],
      files: files,
    );
  }
}

/// `decks/index.json`: every language on GitHub, and its files (#210,
/// ADR-0037). Written by `tools/deck_index.py`.
class DeckIndex {
  const DeckIndex({
    this.version = supportedIndexVersion,
    this.languages = const <IndexLanguage>[],
  });

  /// The index's format. Later than [supportedIndexVersion], the app cannot
  /// read it: [parse] refuses it with [IndexTooNewException].
  final int version;
  final List<IndexLanguage> languages;

  IndexLanguage? language(String code) {
    for (final language in languages) {
      if (language.code == code) return language;
    }
    return null;
  }

  /// Every file of every language, by path.
  Map<String, IndexFile> get filesByPath => <String, IndexFile>{
    for (final language in languages)
      for (final file in language.files) file.path: file,
  };

  /// Reads [text], the index as GitHub serves it.
  ///
  /// Throws [IndexTooNewException] for an index this app is too old to
  /// read, and [FormatException] for one that is not an index at all.
  static DeckIndex parse(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const FormatException('the index is not JSON');
    }
    if (json is! Map) throw const FormatException('the index is not an object');
    final version = json['version'];
    if (version is! int || version < 1) {
      throw const FormatException('the index has no version');
    }
    if (version > supportedIndexVersion) throw IndexTooNewException(version);
    final languages = <IndexLanguage>[
      for (final language in _list(json['languages']))
        IndexLanguage._parse(language),
    ];
    final codes = <String>{};
    for (final language in languages) {
      if (!codes.add(language.code)) {
        throw FormatException('${language.code} is listed twice');
      }
    }
    return DeckIndex(version: version, languages: languages);
  }
}

/// The index is of a format later than this app reads: the app needs an
/// update before it can download decks.
class IndexTooNewException implements Exception {
  const IndexTooNewException(this.version);

  final int version;

  @override
  String toString() =>
      'IndexTooNewException: index version $version, '
      'this app reads $supportedIndexVersion';
}

List<Object?> _list(Object? value) => value is List ? value : const <Object?>[];

List<String> _strings(Object? value) => <String>[
  for (final item in _list(value))
    if (item is String) item,
];

/// What bringing a language's files on the phone up to [IndexLanguage]
/// would do (ADR-0037).
class LanguageChanges {
  const LanguageChanges({
    required this.language,
    this.fetch = const <IndexFile>[],
    this.remove = const <String>[],
  });

  final String language;

  /// Files new to the phone, or changed since they were downloaded.
  final List<IndexFile> fetch;

  /// Files on the phone that a file in [fetch] replaces under another name:
  /// a deck split into a core and its layer, a path renamed. A file GitHub
  /// no longer lists, that nothing replaces, is never removed, so that a
  /// learner's cards do not vanish (ADR-0037).
  final List<String> remove;

  int get bytes => fetch.fold(0, (sum, f) => sum + f.size);

  bool get isEmpty => fetch.isEmpty && remove.isEmpty;
}

/// What it would take to bring [onPhone], the files of [language] on the
/// phone (their path, and what the index said of each when it was
/// downloaded), up to [wanted], the files the learner should have.
///
/// A file whose hash differs is fetched; so is one not on the phone. A file
/// on the phone that [wanted] does not list stays, unless a wanted file
/// takes its role ([IndexFile.role]) under another path.
LanguageChanges changesFor(
  String language,
  List<IndexFile> wanted,
  Map<String, IndexFile> onPhone,
) {
  final roles = <String>{for (final file in wanted) file.role};
  final paths = <String>{for (final file in wanted) file.path};
  return LanguageChanges(
    language: language,
    fetch: <IndexFile>[
      for (final file in wanted)
        if (onPhone[file.path]?.sha256 != file.sha256) file,
    ],
    remove: <String>[
      for (final MapEntry(key: path, value: file) in onPhone.entries)
        if (file.language == language &&
            !paths.contains(path) &&
            roles.contains(file.role))
          path,
    ]..sort(),
  );
}
