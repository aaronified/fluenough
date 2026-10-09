import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:yaml/yaml.dart';

import '../core/data/course_path.dart';
import '../core/data/deck_parser.dart';
import '../core/data/facts_parser.dart';
import '../core/data/script_guide_parser.dart';
import '../core/data/romanisation_parser.dart';
import '../core/data/sounds_parser.dart';
import '../core/models/script_guide.dart';
import '../core/models/romanisation.dart';
import '../core/models/sound_contrasts.dart';
import '../core/data/number_rules_parser.dart';
import '../core/data/pattern_expander.dart';
import '../core/data/rule_expander.dart';
import '../core/data/themes.dart';
import '../core/models/fact.dart';
import '../core/models/card.dart';
import '../core/models/deck.dart';
import '../core/models/number_rules.dart';
import 'added_decks.dart';

/// Where deck files come from: their paths, and each one's text.
///
/// [AssetDeckSource] reads what is bundled with the app, which is now only
/// `decks/themes.yaml`; the decks themselves are downloaded from the
/// repository (#210, ADR-0037) and read from `DownloadedDecks`, under the
/// same paths. [DeckSources] reads both as one; nothing above it changes.
abstract interface class DeckSource {
  /// Every deck file's path, sorted.
  Future<List<String>> list();

  Future<String> read(String path);
}

/// The decks bundled as Flutter assets under `decks/`.
///
/// Lists them through the [AssetManifest], so a new language directory needs
/// only its pubspec asset entry, not a code change.
class AssetDeckSource implements DeckSource {
  AssetDeckSource([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  @override
  Future<List<String>> list() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    return manifest.listAssets().where(isDeckPath).toList()..sort();
  }

  @override
  Future<String> read(String path) async {
    // Decoded here rather than with AssetBundle.loadString, which hands files
    // over 50 KB to an isolate: a large deck would then stall a widget test.
    final data = await _bundle.load(path);
    return utf8.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  /// Whether [path] is a deck file: YAML, somewhere under `decks/`.
  static bool isDeckPath(String path) =>
      path.startsWith('decks/') &&
      (path.endsWith('.yaml') || path.endsWith('.yml'));
}

/// Several sources read as one: every path of each, and a path two list read
/// from the first that lists it. The app reads its bundled theme list and
/// its downloaded decks so.
class DeckSources implements DeckSource {
  DeckSources(this.sources);

  final List<DeckSource> sources;
  final Map<String, DeckSource> _owner = <String, DeckSource>{};

  @override
  Future<List<String>> list() async {
    _owner.clear();
    for (final source in sources) {
      for (final path in await source.list()) {
        _owner.putIfAbsent(path, () => source);
      }
    }
    return _owner.keys.toList()..sort();
  }

  @override
  Future<String> read(String path) {
    final source = _owner[path];
    if (source == null) throw StateError('no deck file at $path');
    return source.read(path);
  }
}

/// Deck files held in memory, keyed by path. For tests and the gallery.
class MemoryDeckSource implements DeckSource {
  MemoryDeckSource(Map<String, String> files)
    : _files = Map<String, String>.unmodifiable(files);

  final Map<String, String> _files;

  @override
  Future<List<String>> list() async => _files.keys.toList()..sort();

  @override
  Future<String> read(String path) async =>
      _files[path] ?? (throw StateError('no deck file at $path'));
}

/// One deck file in the catalog: a deck, or a file that could not be read.
sealed class CatalogEntry {
  const CatalogEntry(this.path);

  /// The file's path in its [DeckSource], like `decks/es/es-en-core-100.yaml`.
  final String path;

  /// The last segment of [path], like `es-en-core-100.yaml`.
  String get fileName => path.split('/').last;
}

/// A deck that parsed.
final class DeckEntry extends CatalogEntry {
  const DeckEntry({
    required String path,
    required this.deck,
    this.bundled = true,
  }) : super(path);

  final Deck deck;

  /// Whether the deck is one of the app's own, bundled or downloaded from
  /// the repository (#210), rather than added by the learner from a file.
  final bool bundled;

  String get id => deck.id;

  LanguageInfo get language => deck.language;

  List<Card> get cards => deck.cards;

  /// How many cards the deck has, as a deck row counts them. A grammar
  /// deck's are its expanded cells (#2).
  int get itemCount => deck.cards.length;

  /// Whether this deck teaches a writing system. There is no such deck kind:
  /// a script deck is a vocab deck tagged `script`, as both bundled script
  /// decks are.
  bool get isScript => deck.tags.contains('script');

  /// The one character a deck tile shows: the first grapheme of the first
  /// card's target, or of the first lemma for a grammar deck, or of the
  /// deck's name if it has neither.
  ///
  /// Taken from the deck rather than from a table of languages, because a
  /// language is data (AGENTS.md).
  String get glyph {
    final pattern = deck.pattern;
    final source = deck.cards.isNotEmpty
        ? deck.cards.first.target
        : pattern != null && pattern.entries.isNotEmpty
        ? pattern.entries.first.lemma
        : deck.name;
    final trimmed = source.trim();
    return trimmed.isEmpty ? '' : trimmed.characters.first;
  }

  @override
  String toString() => 'DeckEntry($path, ${deck.id})';
}

/// A deck file that failed to parse. Shown as a "couldn't read" row, with the
/// file, line and message; it never takes the app down.
final class BrokenDeck extends CatalogEntry {
  const BrokenDeck({required String path, required this.error}) : super(path);

  /// What is wrong and where. Its message is exception text (ADR-0006): it is
  /// shown verbatim, inside interface text that is tokenised.
  final DeckParseException error;

  @override
  String toString() => 'BrokenDeck($path: ${error.message})';
}

/// The loaded catalog: the decks that parsed, and the files that did not.
class Catalog {
  Catalog({
    required List<DeckEntry> decks,
    required List<BrokenDeck> broken,
    List<DeckTheme> themes = const <DeckTheme>[],
    Map<String, FactsFile> facts = const <String, FactsFile>{},
    Map<String, NumberRules> numberRules = const <String, NumberRules>{},
    Map<String, CoursePath> paths = const <String, CoursePath>{},
    Map<String, LanguagePath> languagePaths = const <String, LanguagePath>{},
    Map<String, SoundContrasts> sounds = const <String, SoundContrasts>{},
    Map<String, Romanisation> romanisations = const <String, Romanisation>{},
    Map<String, ScriptGuide> scriptGuides = const <String, ScriptGuide>{},
  }) : decks = List<DeckEntry>.unmodifiable(decks),
       broken = List<BrokenDeck>.unmodifiable(broken),
       themes = List<DeckTheme>.unmodifiable(themes),
       facts = Map<String, FactsFile>.unmodifiable(facts),
       numberRules = Map<String, NumberRules>.unmodifiable(numberRules),
       paths = Map<String, CoursePath>.unmodifiable(paths),
       languagePaths = Map<String, LanguagePath>.unmodifiable(languagePaths),
       sounds = Map<String, SoundContrasts>.unmodifiable(sounds),
       romanisations = Map<String, Romanisation>.unmodifiable(romanisations),
       scriptGuides = Map<String, ScriptGuide>.unmodifiable(scriptGuides);

  /// Each language's daily facts (#48), by language code.
  final Map<String, FactsFile> facts;

  /// Each language's rules for spelling a generated number (#54), by
  /// language code. A language without a numbers file has none.
  final Map<String, NumberRules> numberRules;

  /// Each course's curated path (#117, ADR-0013), by `CoursePath.course`,
  /// such as `hi/en`: its language's path as the course's learners are
  /// taught it (ADR-0036). A course whose language has no path has none.
  final Map<String, CoursePath> paths;

  /// Each language's path (ADR-0036), by language code, with its regions:
  /// one per language learnt, shared by every native language.
  final Map<String, LanguagePath> languagePaths;

  /// Each language's sound contrasts (#89, ADR-0015), by language code. A
  /// language without a sounds file has none.
  final Map<String, SoundContrasts> sounds;

  /// Each language's romanisation (#47), by language code. A language
  /// without a romanisation file has none.
  final Map<String, Romanisation> romanisations;

  /// Each language's script guide (#30, ADR-0016), by language code. A
  /// language without one has none.
  final Map<String, ScriptGuide> scriptGuides;

  static final Catalog empty = Catalog(decks: const [], broken: const []);

  /// In file order, which groups them by language directory, except that a
  /// course's decks come in teaching order, so that its new cards do too:
  /// its path's order, or without a path, its theme decks in the order of
  /// [themes] and then the rest.
  final List<DeckEntry> decks;

  final List<BrokenDeck> broken;

  /// The shared theme path, from `decks/themes.yaml` (ADR-0010).
  final List<DeckTheme> themes;

  /// The theme with [id], or null if the path has none.
  DeckTheme? themeById(String? id) {
    for (final theme in themes) {
      if (theme.id == id) return theme;
    }
    return null;
  }

  /// The path of [entry]'s course, or null if it has none.
  CoursePath? pathOf(DeckEntry entry) =>
      paths['${entry.language.code}/${entry.deck.native.code}'];

  DeckEntry? byId(String id) {
    for (final entry in decks) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Every target language the decks teach, one per BCP-47 code, in the
  /// order the decks list them.
  List<LanguageInfo> get languages {
    final seen = <String, LanguageInfo>{};
    for (final entry in decks) {
      seen.putIfAbsent(entry.language.code, () => entry.language);
    }
    return List<LanguageInfo>.unmodifiable(seen.values);
  }
}

/// Lists and parses every deck file in a [DeckSource].
///
/// A stand-in for the deck repository (#4). It reads the files that live
/// beside the decks but are not decks: facts (#48), number rules (#54), the
/// theme path (#52) and each course's path (#117). It expands grammar decks
/// into cards (#2), and turns a file that fails to parse into a [BrokenDeck]
/// rather than an exception.
class DeckCatalog {
  DeckCatalog(this.source, {this.added});

  final DeckSource source;

  /// Where decks a learner adds are kept (#22), or null where none can be.
  final DeckStore? added;

  Future<Catalog>? _loading;

  /// Loads the catalog, once. Later calls return the same result, so several
  /// states in the gallery can share one catalog without parsing it again.
  Future<Catalog> load() => _loading ??= _load();

  /// Forgets the loaded catalog, so the next [load] reads the source again.
  void invalidate() => _loading = null;

  Future<Catalog> _load() async {
    final files = <String, String>{};
    for (final path in await source.list()) {
      files[path] = await source.read(path);
    }
    final added = this.added;
    if (added != null) {
      for (final path in await added.list()) {
        files[path] = await added.read(path);
      }
    }
    return parseAll(files);
  }

  /// Parses [files], keyed by path, into a catalog. Pure: no source, no IO.
  /// A deck whose path starts with [addedDeckPrefix] was added by the
  /// learner, not bundled.
  static Catalog parseAll(Map<String, String> files) {
    final decks = <DeckEntry>[];
    final broken = <BrokenDeck>[];
    var themes = const <DeckTheme>[];
    final facts = <String, FactsFile>{};
    final numberRules = <String, NumberRules>{};
    final languagePaths = <String, LanguagePath>{};
    final sounds = <String, SoundContrasts>{};
    final romanisations = <String, Romanisation>{};
    final scriptGuides = <String, ScriptGuide>{};
    final firstPath = <String, String>{};
    // Added decks after the bundled ones: a bundled deck keeps its id, and
    // the card a ref finds, when an added deck has them too.
    bool isAdded(String path) => path.startsWith(addedDeckPrefix);
    final paths = files.keys.toList()
      ..sort(
        (a, b) =>
            isAdded(a) != isAdded(b) ? (isAdded(a) ? 1 : -1) : a.compareTo(b),
      );
    final headers = <String, ({String? kind, String? part})>{
      for (final path in paths) path: _headerOf(files[path]!),
    };
    // A file a learner added is single-file (OPEN-19): DeckParser.parse
    // refuses a core or a layer among them.
    bool isLayer(String path) =>
        !isAdded(path) && headers[path]!.kind == 'layer';
    bool isCore(String path) =>
        !isAdded(path) && !isLayer(path) && headers[path]!.part == 'core';
    // Cores first, so that a layer finds its core wherever the two sort
    // (B1 format, spec 9.6). A core is not shown: each of its layers is,
    // merged with it.
    final cores = <String, DeckCore>{};
    final brokenCores = <String>{};
    for (final path in paths.where(isCore)) {
      try {
        cores[path] = DeckParser.parseCore(
          files[path]!,
          source: path.split('/').last,
        );
      } on DeckParseException catch (e) {
        broken.add(BrokenDeck(path: path, error: e));
        brokenCores.add(path);
      }
    }
    for (final path in paths) {
      final text = files[path]!;
      final kind = headers[path]!.kind;
      if (isCore(path)) continue;
      if (kind == 'facts') {
        try {
          final file = parseFacts(text, source: path.split('/').last);
          facts.putIfAbsent(file.languageCode, () => file);
        } on DeckParseException catch (e) {
          broken.add(BrokenDeck(path: path, error: e));
        }
        continue;
      }
      if (kind == 'numbers') {
        try {
          final rules = parseNumberRules(text, source: path.split('/').last);
          numberRules.putIfAbsent(rules.language.code, () => rules);
        } on DeckParseException catch (e) {
          broken.add(BrokenDeck(path: path, error: e));
        }
        continue;
      }
      if (kind == 'path') {
        // One path per language learnt (ADR-0036): a second is broken.
        try {
          final source = path.split('/').last;
          final languagePath = parseLanguagePath(text, source: source);
          final earlier = languagePaths[languagePath.language];
          if (earlier != null) {
            throw DeckParseException(
              '${languagePath.language} already has a path, ${earlier.id}; '
              'a language has one',
              source: source,
            );
          }
          languagePaths[languagePath.language] = languagePath;
        } on DeckParseException catch (e) {
          broken.add(BrokenDeck(path: path, error: e));
        }
        continue;
      }
      if (kind == 'romanisation') {
        try {
          final file = parseRomanisation(text, source: path.split('/').last);
          romanisations.putIfAbsent(file.language, () => file);
        } on DeckParseException catch (e) {
          broken.add(BrokenDeck(path: path, error: e));
        }
        continue;
      }
      if (kind == 'sounds') {
        try {
          final file = parseSounds(text, source: path.split('/').last);
          sounds.putIfAbsent(file.language, () => file);
        } on DeckParseException catch (e) {
          broken.add(BrokenDeck(path: path, error: e));
        }
        continue;
      }
      if (kind == 'script') {
        try {
          final guide = parseScriptGuide(text, source: path.split('/').last);
          scriptGuides.putIfAbsent(guide.language, () => guide);
        } on DeckParseException catch (e) {
          broken.add(BrokenDeck(path: path, error: e));
        }
        continue;
      }
      if (kind == 'themes') {
        try {
          themes = parseThemes(text, source: path.split('/').last);
        } on DeckParseException catch (e) {
          broken.add(BrokenDeck(path: path, error: e));
        }
        continue;
      }
      Deck deck;
      try {
        deck = isLayer(path)
            ? _merged(path, text, files, cores, brokenCores)
            : DeckParser.parse(text, source: path.split('/').last);
      } on DeckParseException catch (e) {
        broken.add(BrokenDeck(path: path, error: e));
        continue;
      }
      final earlier = firstPath[deck.id];
      if (earlier != null) {
        broken.add(
          BrokenDeck(
            path: path,
            error: DeckParseException(
              'deck id "${deck.id}" is already used by $earlier',
              source: path.split('/').last,
            ),
          ),
        );
        continue;
      }
      firstPath[deck.id] = path;
      // A grammar deck becomes cards here (#2), so that nothing after the
      // catalog needs to know which kind of deck a card came from.
      if (deck.kind == DeckKind.grammar) {
        deck = deck.withCards(expandPattern(deck));
      }
      decks.add(
        DeckEntry(
          path: path,
          deck: deck,
          bundled: !path.startsWith(addedDeckPrefix),
        ),
      );
    }
    final resolved = _withRules(_withRefs(decks));
    final placed = _placed(_coursePaths(languagePaths, resolved), resolved);
    return Catalog(
      decks: _inTeachingOrder(resolved, themes, placed),
      broken: broken,
      themes: themes,
      facts: facts,
      numberRules: numberRules,
      paths: placed,
      languagePaths: languagePaths,
      sounds: sounds,
      romanisations: romanisations,
      scriptGuides: scriptGuides,
    );
  }

  /// The layer at [path], whose text is [text], merged with its core: the
  /// file `<core>.yaml` in the folder above the layer's (spec 2.6).
  static Deck _merged(
    String path,
    String text,
    Map<String, String> files,
    Map<String, DeckCore> cores,
    Set<String> brokenCores,
  ) {
    final source = path.split('/').last;
    final layer = DeckParser.parseLayer(text, source: source);
    final folders = path.split('/')..removeLast();
    final above = folders.isEmpty ? '' : (folders..removeLast()).join('/');
    final corePath = '${above.isEmpty ? '' : '$above/'}${layer.core}.yaml';
    final core = cores[corePath];
    if (core != null) return mergeLayer(core, layer, source: source);
    throw DeckParseException(
      brokenCores.contains(corePath)
          ? 'its core, ${layer.core}.yaml, could not be read'
          : files.containsKey(corePath)
          ? '${layer.core}.yaml is not a core: it has no part: "core"'
          : "no core file ${layer.core}.yaml in ${above.isEmpty ? '.' : above}; "
                "a layer's core is in the folder above it",
      source: source,
    );
  }

  /// [decks] with each rules deck's table expanded into its cells (spec
  /// 4.6), once refs are resolved: a row's word is its card as a vocab deck
  /// of the same native language teaches it, and a row with none is left
  /// out.
  static List<DeckEntry> _withRules(List<DeckEntry> decks) {
    if (!decks.any((e) => e.deck.kind == DeckKind.rules)) return decks;
    final taught = <String, Map<String, Card>>{};
    for (final entry in decks) {
      if (entry.deck.kind != DeckKind.vocab) continue;
      final words = taught[entry.deck.native.code] ??= <String, Card>{};
      for (final card in entry.deck.cards) {
        words.putIfAbsent(card.id, () => card);
      }
    }
    return <DeckEntry>[
      for (final entry in decks)
        if (entry.deck.kind != DeckKind.rules)
          entry
        else
          DeckEntry(
            path: entry.path,
            deck: entry.deck.withCards(
              expandRules(
                entry.deck,
                wordOf: (id) => taught[entry.deck.native.code]?[id],
              ),
            ),
            bundled: entry.bundled,
          ),
    ];
  }

  /// Each course's path, by `CoursePath.course`: its language's path as a
  /// learner from the course's native language is taught it, for every
  /// course that has a deck. A core id becomes the course's deck where the
  /// catalog holds it, merged or single-file, bundled or added.
  static Map<String, CoursePath> _coursePaths(
    Map<String, LanguagePath> paths,
    List<DeckEntry> decks,
  ) {
    final ids = <String>{for (final e in decks) e.id};
    final courses = <String, (String, String)>{
      for (final e in decks)
        '${e.language.code}/${e.deck.native.code}': (
          e.language.code,
          e.deck.native.code,
        ),
    };
    return <String, CoursePath>{
      for (final MapEntry(key: course, value: (language, native))
          in courses.entries)
        if (paths[language] case final path?)
          course: path.forNative(native, exists: ids.contains),
    };
  }

  /// Each course's path with the course's decks it does not list put where
  /// its wildcards say (`CoursePath.placing`): an added deck at the bottom
  /// of its theme's unit, or at the end.
  static Map<String, CoursePath> _placed(
    Map<String, CoursePath> paths,
    List<DeckEntry> decks,
  ) {
    final themeOf = <String, String?>{
      for (final e in decks) e.id: e.deck.theme,
    };
    return <String, CoursePath>{
      for (final MapEntry(key: course, value: path) in paths.entries)
        course: path.placing(<({String id, String? theme})>[
          for (final e in decks)
            if ('${e.language.code}/${e.deck.native.code}' == course &&
                path.unitOf(e.id) == null)
              (id: e.id, theme: e.deck.theme),
        ], (id) => themeOf[id]),
    };
  }

  /// [decks] with each ref folded into its deck's cards, in its place
  /// (ADR-0018): the card as its own deck writes it, with what the ref
  /// gives. A ref to a card no deck writes, or from a deck taught from
  /// another language that gives no native, is left out; the validator
  /// refuses both.
  static List<DeckEntry> _withRefs(List<DeckEntry> decks) {
    // Each card as each native language's decks write it: a core card is
    // written once per layer that translates it, and a ref resolves through
    // the one of its own native language when there is one (spec 2.7).
    final written = <String, Map<String, Card>>{};
    for (final entry in decks) {
      if (entry.deck.kind != DeckKind.vocab) continue;
      for (final card in entry.deck.cards) {
        (written[card.id] ??= <String, Card>{}).putIfAbsent(
          entry.deck.native.code,
          () => card,
        );
      }
    }
    return <DeckEntry>[
      for (final entry in decks)
        if (entry.deck.refs.isEmpty)
          entry
        else
          DeckEntry(
            path: entry.path,
            deck: entry.deck.withCards(_resolved(entry.deck, written)),
            bundled: entry.bundled,
          ),
    ];
  }

  static List<Card> _resolved(
    Deck deck,
    Map<String, Map<String, Card>> written,
  ) {
    final refAt = <int, CardRef>{
      for (final ref in deck.refs) ref.position: ref,
    };
    final cards = <Card>[];
    var next = 0;
    for (var i = 0; i < deck.cards.length + deck.refs.length; i++) {
      final ref = refAt[i];
      if (ref == null) {
        cards.add(deck.cards[next++]);
        continue;
      }
      if (written[ref.id] case final homes?) {
        final own = homes[deck.native.code];
        final listed = ref.resolve(
          own ?? homes.values.first,
          deckId: deck.id,
          sameNative: own != null,
        );
        if (listed != null) cards.add(listed);
      }
    }
    return List<Card>.unmodifiable(cards);
  }

  /// [decks] with each course's put in teaching order, in the places that
  /// course's decks held, so that courses keep their file order.
  ///
  /// With a path, that is the path's order, and a deck the path leaves out,
  /// which the validator refuses, comes after it. Without one, it is the
  /// theme decks in [themes] order, a theme the list lacks last, and then
  /// the course's other decks, such as grammar, in file order (#80). A
  /// course with neither theme decks nor a path keeps its file order.
  static List<DeckEntry> _inTeachingOrder(
    List<DeckEntry> decks,
    List<DeckTheme> themes,
    Map<String, CoursePath> paths,
  ) {
    final themeRank = <String, int>{
      for (final (i, theme) in themes.indexed) theme.id: i,
    };
    final byCourse = <String, List<int>>{};
    for (final (i, entry) in decks.indexed) {
      final course = '${entry.language.code}/${entry.deck.native.code}';
      (byCourse[course] ??= <int>[]).add(i);
    }
    final ordered = List<DeckEntry>.of(decks);
    for (final MapEntry(key: course, value: slots) in byCourse.entries) {
      final path = paths[course];
      final pathRank = <String, int>{
        if (path != null)
          for (final (i, id) in path.deckIds.indexed) id: i,
      };
      // Decks a path or the theme list does not rank go last, in file order.
      final unranked = pathRank.length + themeRank.length + 1;
      int rankOf(DeckEntry e) => path != null
          ? pathRank[e.id] ?? unranked
          : e.deck.theme == null
          ? unranked
          : themeRank[e.deck.theme] ?? themeRank.length;
      final inOrder = slots.indexed.toList()
        ..sort((a, b) {
          final byRank = rankOf(decks[a.$2]).compareTo(rankOf(decks[b.$2]));
          return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
        });
      for (final (n, (_, from)) in inOrder.indexed) {
        ordered[slots[n]] = decks[from];
      }
    }
    return ordered;
  }

  /// A file's `kind`, such as `facts` or `themes` for the files beside the
  /// decks that are not decks, or null. Decided by the file's `kind`, not
  /// its name. Text that is not a YAML mapping has none; the parser then
  /// reports what is wrong.
  static String? kindOf(String text) => _headerOf(text).kind;

  /// A file's `kind` and `part`, each null when it has none: a layer is
  /// `kind: "layer"`, a core `part: "core"` (spec 2.2).
  static ({String? kind, String? part}) _headerOf(String text) {
    try {
      final root = loadYaml(text.startsWith('﻿') ? text.substring(1) : text);
      final kind = root is YamlMap ? root['kind'] : null;
      final part = root is YamlMap ? root['part'] : null;
      return (
        kind: kind is String ? kind : null,
        part: part is String ? part : null,
      );
    } catch (_) {
      return (kind: null, part: null);
    }
  }

  /// What is wrong with [text], the file at [path], read on its own as its
  /// `kind` says, or null if nothing is. A downloaded file is checked so
  /// before it replaces one on the phone (ADR-0037). A layer is read without
  /// its core, which the catalog merges it with.
  static String? checkFile(String path, String text) {
    final source = path.split('/').last;
    final header = _headerOf(text);
    try {
      switch (header.kind) {
        case 'layer':
          DeckParser.parseLayer(text, source: source);
        case 'facts':
          parseFacts(text, source: source);
        case 'numbers':
          parseNumberRules(text, source: source);
        case 'path':
          parseLanguagePath(text, source: source);
        case 'romanisation':
          parseRomanisation(text, source: source);
        case 'sounds':
          parseSounds(text, source: source);
        case 'script':
          parseScriptGuide(text, source: source);
        case 'themes':
          parseThemes(text, source: source);
        default:
          header.part == 'core'
              ? DeckParser.parseCore(text, source: source)
              : DeckParser.parse(text, source: source);
      }
      return null;
    } on DeckParseException catch (e) {
      return e.toString();
    } on Object catch (e) {
      return '$source: $e';
    }
  }

  /// Whether [text] is a facts file (`kind: facts`), which is valid beside
  /// the decks but is read by the facts loader, not `DeckParser`.
  static bool isFactsFile(String text) => kindOf(text) == 'facts';
}
