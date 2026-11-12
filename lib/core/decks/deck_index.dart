import 'dart:convert';

import 'app_version.dart';
import '../models/level.dart';
import 'shared_data.dart';

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
  'situations',
  'topics',
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

/// What a recording's or an image's path must look like (#518, #523): in
/// its language's `audio` or `images` folder, named by its card's id.
final RegExp mediaPathPattern = RegExp(
  r'^decks/([a-z]{2,3})/(?:audio/\1-[0-9]{4,}\.opus|images/\1-[0-9]{4,}\.webp)$',
);

/// Whether [path] is a deck file's path, as the index may list it.
bool isDeckFilePath(String path) => _filePath.hasMatch(path);

/// What a script font's path must look like (ADR-0042): a TrueType file in
/// its script's folder under `decks/fonts/`. Group 1 is the script.
final RegExp fontPathPattern = RegExp(
  r'^decks/fonts/([a-z]+(?:_[a-z]+)*)/[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*\.ttf$',
);

final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

/// One file of a language in the index (`decks/index.json`).
class IndexFile {
  const IndexFile({
    required this.path,
    required this.size,
    required this.sha256,
    String? contentSha256,
    this.schema = 1,
    this.kind = 'vocab',
    this.native,
    this.deck,
    this.core = false,
    this.proposed = 0,
    this.minApp,
    this.appTooOld = false,
  }) : contentSha256 = contentSha256 ?? sha256;

  /// Where it is in the repository, which is also its path on the phone
  /// and in the catalog: `decks/hi/hi-en-family.yaml`.
  final String path;

  /// Its size in bytes.
  final int size;

  /// Its SHA-256, 64 lower-case hex digits. A download that does not match
  /// it is thrown away.
  final String sha256;

  /// The SHA-256 of the file with its proposals taken out (ADR-0038,
  /// #444): what a learner sees of it. A learner is offered an update only
  /// when this changes; a reviewer when [sha256] does. Where the index or
  /// the phone does not know it, it is [sha256].
  final String contentSha256;

  final int schema;

  /// The file's `kind`: `vocab`, `grammar`, `layer`, `path`, `facts`…, or
  /// for a card's recording or image, `audio` or `image` ([isMedia]).
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

  /// The oldest app version that can read it (`min_app`, ADR-0052): its own,
  /// or its language's if that is newer. Null where the index names none.
  final String? minApp;

  /// Whether this app is older than [minApp]. Set when the index is read
  /// against the app's version ([DeckIndex.parse]); such a file is not
  /// downloaded, and its language says the app needs updating.
  final bool appTooOld;

  /// The language it belongs to: its folder under `decks/`.
  String get language => path.split('/')[1];

  /// Whether it is one of the language's own files, not a deck: a script
  /// guide or sounds file, say, or the layer of one (#498), a layer listed
  /// as no deck.
  bool get isLanguageFile =>
      languageFileKinds.contains(kind) || kind == 'layer' && deck == null;

  /// Whether it is a card's own recording or image (#518, #523), not a
  /// deck: it downloads after the decks, and is never read as one.
  bool get isMedia => mediaPathPattern.hasMatch(path);

  /// Whether this app can read it: its schema is not newer than the app's
  /// ([supportedDeckSchema]) and the app is not older than its [minApp].
  bool get readable => schema <= supportedDeckSchema && !appTooOld;

  static IndexFile _parse(
    Object? json, {
    bool media = false,
    String? appVersion,
    String? languageMinApp,
  }) {
    if (json is! Map) throw const FormatException('a file is not an object');
    final path = json['path'];
    final size = json['size'];
    final sha = json['sha256'];
    final schema = json['schema'];
    final kind = json['kind'];
    if (path is! String ||
        !(mediaPathPattern.hasMatch(path) ||
            !media && _filePath.hasMatch(path))) {
      throw FormatException('a file has a bad path: $path');
    }
    if (size is! int || size < 0) {
      throw FormatException('$path has a bad size');
    }
    if (sha is! String || !_hex64.hasMatch(sha)) {
      throw FormatException('$path has a bad sha256');
    }
    final content = json['content_sha256'];
    if (content != null && (content is! String || !_hex64.hasMatch(content))) {
      throw FormatException('$path has a bad content_sha256');
    }
    final native = json['native'];
    final deck = json['deck'];
    final minApp = newestAppVersion(
      cleanMinApp(json['min_app']),
      languageMinApp,
    );
    return IndexFile(
      path: path,
      size: size,
      sha256: sha,
      contentSha256: content as String?,
      schema: schema is int ? schema : 1,
      kind: kind is String ? kind : 'vocab',
      native: native is String ? native : null,
      deck: deck is String ? deck : null,
      core: json['part'] == 'core',
      proposed: json['proposed'] is int ? json['proposed'] as int : 0,
      minApp: minApp,
      appTooOld: appVersion != null && appIsOlderThan(appVersion, minApp),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'size': size,
    'sha256': sha256,
    'content_sha256': contentSha256,
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
  String get role => kind == 'layer' && deck == null
      ? 'file:$path'
      : isLanguageFile
      ? 'kind:$kind'
      : core
      ? 'core:$deck'
      : deck == null
      ? 'file:$path'
      : 'deck:$deck:$native';
}

/// A deck file with a `genre` in the index (`shelves`, deck-kinds plan, D9): a
/// [file] entry plus what search and the Decks tab need before the file is
/// downloaded. Hidden decks are listed here and nowhere else, and are fetched
/// on demand; the visible ones also download with the language.
class IndexShelf {
  const IndexShelf({
    required this.file,
    required this.genre,
    this.level,
    this.hidden = false,
    this.professional,
    this.section,
    this.weave = false,
    this.title,
    this.cards = 0,
    this.coreId,
  });

  /// The file, as `files` would list it.
  final IndexFile file;

  /// The deck's genre, a string looked up in the sections file.
  final String genre;

  /// The lowest level the deck suits, or null for none (also for a value that
  /// is no level).
  final Level? level;

  /// Whether the deck is kept out of the Decks tab, Today, the path,
  /// placement and the counts until a learner adds it.
  final bool hidden;

  /// The profession of a professional deck.
  final String? professional;

  /// The Decks tab section the deck is in, as the tool resolved it.
  final String? section;

  /// Whether the deck may be woven into the course.
  final bool weave;

  /// The deck's name, in the language its file is written in.
  final String? title;

  /// How many cards (or passages) the file has.
  final int cards;

  /// The core id of the deck: the same for a core, its layers and a single
  /// file's own id.
  final String? coreId;

  /// What names the deck across its files: [coreId], else the id the index
  /// lists it as, else its path.
  String get deckKey => coreId ?? file.deck ?? file.path;

  /// Whether the file is a core, which is never listed as a deck of its own.
  bool get isCore => file.core;

  /// [json] as a shelf entry. Throws [FormatException] for one that is not
  /// (the caller costs the entry and logs it).
  static IndexShelf parse(
    Object? json, {
    String? appVersion,
    String? languageMinApp,
  }) {
    if (json is! Map) throw const FormatException('a shelf is not an object');
    final file = IndexFile._parse(
      json,
      appVersion: appVersion,
      languageMinApp: languageMinApp,
    );
    final genre = json['genre'];
    if (genre is! String || genre.isEmpty) {
      throw FormatException('${file.path} has no genre');
    }
    String? text(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final cards = json['cards'];
    return IndexShelf(
      file: file,
      genre: genre,
      level: Level.tryParse(json['level']),
      hidden: json['hidden'] == true,
      professional: text('professional'),
      section: text('section'),
      weave: json['weave'] == true,
      title: text('title'),
      cards: cards is int && cards >= 0 ? cards : 0,
      coreId: text('core'),
    );
  }

  @override
  String toString() => 'IndexShelf(${file.path}, $genre)';
}

/// A creator's image in the index (`shared_media`): downloaded on demand when
/// a creator is shown, checked by its hash alone, never as a deck.
class SharedMediaFile {
  const SharedMediaFile({
    required this.path,
    required this.size,
    required this.sha256,
    required this.kind,
    this.language,
  });

  final String path;
  final int size;
  final String sha256;

  /// `image`.
  final String kind;

  /// The language whose creator it shows.
  final String? language;

  /// [json] as a media entry, or null for one that is not (the caller logs
  /// it).
  static SharedMediaFile? tryParse(Object? json) {
    if (json is! Map) return null;
    final path = json['path'];
    final size = json['size'];
    final sha = json['sha256'];
    if (path is! String ||
        !path.startsWith('decks/creators/images/') ||
        path.contains('..') ||
        size is! int ||
        size <= 0 ||
        sha is! String ||
        !_hex64.hasMatch(sha)) {
      return null;
    }
    final kind = json['kind'];
    final language = json['language'];
    return SharedMediaFile(
      path: path,
      size: size,
      sha256: sha,
      kind: kind is String ? kind : 'image',
      language: language is String ? language : null,
    );
  }
}

/// A script's font in the index (ADR-0042), listed under a language's
/// `fonts`: one OFL-licensed Noto font, downloaded with the course that
/// needs it and drawn under the family name [scriptFontFamily] gives its
/// script. Courses in one script list the same file, which downloads once.
///
/// Listed apart from [IndexLanguage.files], which the released app reads,
/// so that an app too old to know fonts passes them by.
class IndexFont {
  const IndexFont({
    required this.path,
    required this.size,
    required this.sha256,
    required this.script,
    this.family = '',
  });

  /// Where it is in the repository, which is also its path on the phone:
  /// `decks/fonts/telugu/NotoSansTelugu.ttf`.
  final String path;

  /// Its size in bytes.
  final int size;

  /// Its SHA-256, 64 lower-case hex digits. A download that does not match
  /// it is thrown away.
  final String sha256;

  /// The script it draws, as the decks name it: `telugu`.
  final String script;

  /// The font's own family name, `Noto Sans Telugu`, for credits.
  final String family;

  /// The font [json] describes, or null when it is not one. A bad entry
  /// costs its font and never the decks: the index is read whole without
  /// it.
  static IndexFont? tryParse(Object? json) {
    if (json is! Map) return null;
    final path = json['path'];
    final size = json['size'];
    final sha = json['sha256'];
    final script = json['script'];
    if (path is! String || script is! String) return null;
    if (fontPathPattern.firstMatch(path)?.group(1) != script) return null;
    if (size is! int || size <= 0) return null;
    if (sha is! String || !_hex64.hasMatch(sha)) return null;
    final family = json['family'];
    return IndexFont(
      path: path,
      size: size,
      sha256: sha,
      script: script,
      family: family is String ? family : '',
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'size': size,
    'sha256': sha256,
    'script': script,
    'family': family,
  };
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
    this.media = const <IndexFile>[],
    this.fonts = const <IndexFont>[],
    this.resources = const <IndexFile>[],
    this.shelves = const <IndexShelf>[],
    this.topics = const <IndexFile>[],
    this.problems = const <String>[],
    this.minApp,
    this.appTooOld = false,
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

  /// Its files but not its media. The script guides of its other scripts,
  /// which the index lists apart as `script_guides`, and the situations
  /// file (#724), listed apart as `situations`, are among them.
  final List<IndexFile> files;

  /// Its cards' recordings and images (#518, #523), listed apart from
  /// [files] so that an app too old to read them passes them by.
  final List<IndexFile> media;

  /// The fonts of the scripts its decks are shown in (ADR-0042), downloaded
  /// with the decks and kept apart from [files], so that an app too old to
  /// read them passes them by. Not counted in [size].
  final List<IndexFont> fonts;

  /// The language's resources file (#832), `kind: resources`: where else to
  /// learn it. Listed apart from [files], so that an app too old to read it
  /// passes it by, and not counted in [size]. The app fetches it on its own,
  /// not with the decks; at most one.
  final List<IndexFile> resources;

  /// Its decks with a `genre`, hidden ones too (`shelves`, deck-kinds plan,
  /// D9). The visible ones are also among [files], so they download with the
  /// language; a hidden one is only here, fetched on demand ([hiddenFilesFor]).
  final List<IndexShelf> shelves;

  /// Its topics file (`topics`), listed apart from [files] so that an app too
  /// old to read it passes it by. It is also among [files], so it downloads
  /// with the language, as the situations file does.
  final List<IndexFile> topics;

  /// What in the language's new keys (`shelves`, `topics`) could not be read
  /// and cost only itself, one line each, for the log.
  final List<String> problems;

  /// The oldest app version that can read the language at all (`min_app`,
  /// ADR-0052), or null. An app older than this does not download any of
  /// its files and says it needs updating.
  final String? minApp;

  /// Whether this app is older than [minApp]: set when the index is read
  /// against the app's version ([DeckIndex.parse]).
  final bool appTooOld;

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

  /// The hidden decks the index lists, one entry for each deck taught from
  /// one of [natives] (its layer, or its single file), never a core: what
  /// search lists before anything is downloaded.
  List<IndexShelf> hiddenDecksFor(Iterable<String> natives) {
    final wanted = natives.toSet();
    return <IndexShelf>[
      for (final shelf in shelves)
        if (shelf.hidden &&
            !shelf.isCore &&
            (shelf.file.native == null || wanted.contains(shelf.file.native)))
          shelf,
    ];
  }

  /// The files that put the hidden deck [deckKey] on the phone for a learner
  /// from [natives]: its core and the layers (or its single file) taught from
  /// one of them, that this app can read. Empty where the index lists no such
  /// hidden deck. Never a visible deck's files, which download with the
  /// language.
  List<IndexFile> hiddenFilesFor(String deckKey, Iterable<String> natives) {
    final wanted = natives.toSet();
    return <IndexFile>[
      for (final shelf in shelves)
        if (shelf.hidden &&
            shelf.deckKey == deckKey &&
            shelf.file.readable &&
            (shelf.file.native == null || wanted.contains(shelf.file.native)))
          shelf.file,
    ];
  }

  /// The newest app version the hidden deck [deckKey]'s files need that this
  /// app is too old for, or null when it reads them all (`min_app`).
  String? hiddenAppNeeded(String deckKey, Iterable<String> natives) {
    final wanted = natives.toSet();
    String? newest;
    for (final shelf in shelves) {
      if (!shelf.hidden ||
          shelf.deckKey != deckKey ||
          !shelf.file.appTooOld ||
          shelf.file.native != null && !wanted.contains(shelf.file.native)) {
        continue;
      }
      newest = newestAppVersion(newest, shelf.file.minApp);
    }
    return newest;
  }

  /// The files a learner from [natives] downloads: the language's own
  /// files, its cores, and its decks and layers for [natives], then its
  /// cards' recordings and images ([media]). Files of a schema this app
  /// cannot read are left out ([unreadable]).
  List<IndexFile> filesFor(Iterable<String> natives) {
    final wanted = natives.toSet();
    return <IndexFile>[
      for (final file in files)
        if (file.readable &&
            (file.native == null || wanted.contains(file.native)))
          file,
      for (final file in media)
        if (file.readable) file,
    ];
  }

  /// The files of [natives] that the app is too old for ([IndexFile.minApp],
  /// ADR-0052), not those of a newer schema: the decks "need app X".
  List<IndexFile> needingNewerApp(Iterable<String> natives) {
    final wanted = natives.toSet();
    return <IndexFile>[
      for (final file in files)
        if (file.appTooOld &&
            (file.native == null || wanted.contains(file.native)))
          file,
    ];
  }

  /// The newest app version any of [natives]' files needs that this app is
  /// too old for, or null when it reads them all: the version to say.
  String? appNeededFor(Iterable<String> natives) {
    String? newest = appTooOld ? minApp : null;
    for (final file in needingNewerApp(natives)) {
      newest = newestAppVersion(newest, file.minApp);
    }
    return newest;
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

  /// The resources file [json] describes, or null when it is not one: a bad
  /// entry costs the suggestion and never the decks.
  static IndexFile? _tryParseResources(Object? json, String code) {
    try {
      final file = IndexFile._parse(json);
      return file.path == 'decks/$code/$code-resources.yaml' ? file : null;
    } on FormatException {
      return null;
    }
  }

  static IndexLanguage _parse(Object? json, {String? appVersion}) {
    if (json is! Map) {
      throw const FormatException('a language is not an object');
    }
    final code = json['code'];
    final name = json['name'];
    if (code is! String || !RegExp(r'^[a-z]{2,3}$').hasMatch(code)) {
      throw FormatException('a language has a bad code: $code');
    }
    // A guide for one of the language's other scripts is listed under
    // `script_guides`, apart from `files`, so that an app too old to read
    // it passes it by (ADR-0016); here it is a file like any other.
    // The language's `min_app` (ADR-0052) holds for every file of it.
    final minApp = cleanMinApp(json['min_app']);
    IndexFile parse(Object? file, {bool media = false}) => IndexFile._parse(
      file,
      media: media,
      appVersion: appVersion,
      languageMinApp: minApp,
    );
    final problems = <String>[];
    // The decks with a genre and a language's topics file are listed under
    // keys of their own (D9), so that a release that reads `files` never
    // sees them. A bad entry costs itself, and is named for the log.
    final shelves = <IndexShelf>[];
    for (final item in _list(json['shelves'])) {
      try {
        final shelf = IndexShelf.parse(
          item,
          appVersion: appVersion,
          languageMinApp: minApp,
        );
        if (shelf.file.language != code) {
          throw FormatException('${shelf.file.path} is not in decks/$code/');
        }
        shelves.add(shelf);
      } on Object catch (e) {
        problems.add('$code: a shelf entry was left out: $e');
      }
    }
    final topics = <IndexFile>[];
    for (final item in _list(json['topics'])) {
      try {
        final file = parse(item);
        if (file.language != code) {
          throw FormatException('${file.path} is not in decks/$code/');
        }
        topics.add(file);
      } on Object catch (e) {
        problems.add('$code: a topics entry was left out: $e');
      }
    }
    final files = <IndexFile>[
      for (final file in _list(json['files'])) parse(file),
      for (final file in _list(json['script_guides'])) parse(file),
      // The situations file (#724) is listed under its own key for the same
      // reason: the released app has no case for its kind.
      for (final file in _list(json['situations'])) parse(file),
      // A language's topics file (deck-kinds plan, D6) downloads with the
      // language, as the situations file does; the entries already read
      // above (a bad one cost itself).
      ...topics,
      // A visible genre deck downloads with the language; a hidden one is
      // fetched when a learner adds it.
      for (final shelf in shelves)
        if (!shelf.hidden) shelf.file,
    ];
    final media = <IndexFile>[
      for (final file in _list(json['media'])) parse(file, media: true),
    ];
    for (final file in <IndexFile>[...files, ...media]) {
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
          : <IndexFile>[...files, ...media].fold(0, (sum, f) => sum + f.size),
      path: _strings(json['path']),
      units: <IndexUnit>[
        for (final unit in _list(json['units'])) IndexUnit._parse(unit),
      ],
      files: files,
      media: media,
      fonts: <IndexFont>[
        for (final font in _list(json['fonts'])) ?IndexFont.tryParse(font),
      ],
      resources: <IndexFile>[
        for (final file in _list(json['resources']))
          ?_tryParseResources(file, code),
      ],
      shelves: List<IndexShelf>.unmodifiable(shelves),
      topics: List<IndexFile>.unmodifiable(topics),
      problems: List<String>.unmodifiable(problems),
      minApp: minApp,
      appTooOld: appVersion != null && appIsOlderThan(appVersion, minApp),
    );
  }
}

/// `decks/index.json`: every language on GitHub, and its files (#210,
/// ADR-0037). Written by `tools/deck_index.py`.
class DeckIndex {
  const DeckIndex({
    this.version = supportedIndexVersion,
    this.languages = const <IndexLanguage>[],
    this.shared = const <SharedFile>[],
    this.sharedProblems = const <String>[],
    this.sharedMedia = const <SharedMediaFile>[],
  });

  /// The index's format. Later than [supportedIndexVersion], the app cannot
  /// read it: [parse] refuses it with [IndexTooNewException].
  final int version;
  final List<IndexLanguage> languages;

  /// The deck-owned files the app can read from the downloads, such as the
  /// theme list (owner, 2026-11-11). Empty for an index that lists none.
  final List<SharedFile> shared;

  /// Why entries of the index's `shared` list were left out, for the log.
  final List<String> sharedProblems;

  /// The creators' images (`shared_media`), downloaded on demand and checked
  /// by hash alone. Empty for an index that lists none.
  final List<SharedMediaFile> sharedMedia;

  /// Every entry of the index that could not be read and cost only itself:
  /// the shared list's, the media's and each language's new keys', one line
  /// each, for the log.
  List<String> get problems => <String>[
    ...sharedProblems,
    for (final language in languages) ...language.problems,
  ];

  IndexLanguage? language(String code) {
    for (final language in languages) {
      if (language.code == code) return language;
    }
    return null;
  }

  /// Every file of every language, by path, its recordings and images too.
  Map<String, IndexFile> get filesByPath => <String, IndexFile>{
    for (final language in languages)
      for (final file in <IndexFile>[...language.files, ...language.media])
        file.path: file,
  };

  /// Reads [text], the index as GitHub serves it.
  ///
  /// With [appVersion], the app's own, a language or file whose `min_app`
  /// (ADR-0052) is newer is marked [IndexFile.appTooOld]: it is not
  /// downloaded, and the app says it needs updating. Without it, nothing is
  /// held back.
  ///
  /// Throws [IndexTooNewException] for an index this app is too old to
  /// read, and [FormatException] for one that is not an index at all.
  static DeckIndex parse(String text, {String? appVersion}) {
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
        IndexLanguage._parse(language, appVersion: appVersion),
    ];
    final codes = <String>{};
    for (final language in languages) {
      if (!codes.add(language.code)) {
        throw FormatException('${language.code} is listed twice');
      }
    }
    final shared = parseSharedFiles(json['shared'], appVersion: appVersion);
    final media = <SharedMediaFile>[];
    final mediaProblems = <String>[];
    final rawMedia = json['shared_media'];
    if (rawMedia != null && rawMedia is! List) {
      mediaProblems.add('the shared_media list of the index is not a list');
    }
    for (final item in _list(rawMedia)) {
      final file = SharedMediaFile.tryParse(item);
      if (file == null) {
        mediaProblems.add('a shared_media entry was left out');
      } else {
        media.add(file);
      }
    }
    return DeckIndex(
      version: version,
      languages: languages,
      shared: shared.files,
      sharedProblems: <String>[...shared.problems, ...mediaProblems],
      sharedMedia: List<SharedMediaFile>.unmodifiable(media),
    );
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
    this.quiet = const <IndexFile>[],
    this.remove = const <String>[],
    this.fonts = const <IndexFont>[],
  });

  final String language;

  /// Files new to the phone, or changed since they were downloaded.
  final List<IndexFile> fetch;

  /// Those of [fetch] whose only change is in reviewers' proposals, which
  /// learners never see (ADR-0038, #444): they come along with a change
  /// that is real, and are never one by themselves for a learner.
  final List<IndexFile> quiet;

  /// Files on the phone that a file in [fetch] replaces under another name:
  /// a deck split into a core and its layer, a path renamed. A file GitHub
  /// no longer lists, that nothing replaces, is never removed, so that a
  /// learner's cards do not vanish (ADR-0037).
  final List<String> remove;

  /// Fonts new to the phone, or changed since they were downloaded
  /// (ADR-0042). A font a course gained, as when the app first knew fonts,
  /// is an update like any other.
  final List<IndexFont> fonts;

  int get bytes =>
      fetch.fold(0, (sum, f) => sum + f.size) +
      fonts.fold(0, (sum, f) => sum + f.size);

  bool get isEmpty => fetch.isEmpty && remove.isEmpty && fonts.isEmpty;
}

/// What it would take to bring [onPhone], the files of [language] on the
/// phone (their path, and what the index said of each when it was
/// downloaded), up to [wanted], the files the learner should have.
///
/// A file not on the phone is fetched. So is one whose content hash
/// ([IndexFile.contentSha256]) differs: a change a learner sees. A file
/// whose only change is in reviewers' proposals, its [IndexFile.sha256]
/// differing and its content hash not, is [LanguageChanges.quiet]: for a
/// [reviewer], who sees proposals, it is a change like any other; for a
/// learner it comes along with a real change, and with none there is
/// nothing to fetch (#444). A file on the phone that [wanted] does not list
/// stays, unless a wanted file takes its role ([IndexFile.role]) under
/// another path.
///
/// Of the language's [fonts] (ADR-0042), those not among [fontsOnPhone], or
/// whose hash differs, come with the changes, or alone.
LanguageChanges changesFor(
  String language,
  List<IndexFile> wanted,
  Map<String, IndexFile> onPhone, {
  bool reviewer = false,
  List<IndexFont> fonts = const <IndexFont>[],
  Map<String, IndexFont> fontsOnPhone = const <String, IndexFont>{},
}) {
  final newFonts = <IndexFont>[
    for (final font in fonts)
      if (fontsOnPhone[font.path]?.sha256 != font.sha256) font,
  ];
  final roles = <String>{for (final file in wanted) file.role};
  final paths = <String>{for (final file in wanted) file.path};
  final fetch = <IndexFile>[];
  final quiet = <IndexFile>[];
  var real = false;
  for (final file in wanted) {
    final phone = onPhone[file.path];
    if (phone != null && phone.sha256 == file.sha256) continue;
    fetch.add(file);
    if (phone != null && phone.contentSha256 == file.contentSha256) {
      quiet.add(file);
    } else {
      real = true;
    }
  }
  if (!real && !reviewer) {
    return LanguageChanges(language: language, fonts: newFonts);
  }
  return LanguageChanges(
    language: language,
    fetch: fetch,
    quiet: quiet,
    fonts: newFonts,
    remove: <String>[
      for (final MapEntry(key: path, value: file) in onPhone.entries)
        if (file.language == language &&
            !paths.contains(path) &&
            roles.contains(file.role))
          path,
    ]..sort(),
  );
}
