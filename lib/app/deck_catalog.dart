import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:yaml/yaml.dart';

import '../core/data/deck_parser.dart';
import '../core/data/themes.dart';
import '../core/models/card.dart';
import '../core/models/deck.dart';

/// Where deck files come from: their paths, and each one's text.
///
/// [AssetDeckSource] reads the decks bundled with the app. #4 replaces the
/// catalog's source with the deck repository; nothing above it changes.
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

  /// The file's path in its [DeckSource], like `decks/es/es-core-100.yaml`.
  final String path;

  /// The last segment of [path], like `es-core-100.yaml`.
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

  /// Whether the deck shipped with the app rather than being imported.
  final bool bundled;

  String get id => deck.id;

  LanguageInfo get language => deck.language;

  List<Card> get cards => deck.cards;

  /// How many cards the deck has, as a deck row counts them. A grammar deck
  /// has no cards until the expander lands (#2), so it counts its pattern's
  /// cells that have a form: the cards it will expand to.
  int get itemCount {
    final pattern = deck.pattern;
    if (deck.cards.isNotEmpty || pattern == null) return deck.cards.length;
    var cells = 0;
    for (final entry in pattern.entries) {
      cells += entry.forms.values.where((form) => form != null).length;
    }
    return cells;
  }

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
  }) : decks = List<DeckEntry>.unmodifiable(decks),
       broken = List<BrokenDeck>.unmodifiable(broken),
       themes = List<DeckTheme>.unmodifiable(themes);

  static final Catalog empty = Catalog(decks: const [], broken: const []);

  /// In path order, which groups them by language directory, except that a
  /// course's theme decks come in the order of [themes], so that its new
  /// cards follow the theme path.
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
/// A stand-in for the deck repository (#4). It skips facts files, which live
/// beside the decks but are not decks (#48), and turns a file that fails to
/// parse into a [BrokenDeck] rather than an exception.
class DeckCatalog {
  DeckCatalog(this.source);

  /// The decks bundled with the app.
  factory DeckCatalog.bundled([AssetBundle? bundle]) =>
      DeckCatalog(AssetDeckSource(bundle));

  final DeckSource source;

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
    return parseAll(files);
  }

  /// Parses [files], keyed by path, into a catalog. Pure: no source, no IO.
  static Catalog parseAll(Map<String, String> files) {
    final decks = <DeckEntry>[];
    final broken = <BrokenDeck>[];
    var themes = const <DeckTheme>[];
    final firstPath = <String, String>{};
    final paths = files.keys.toList()..sort();
    for (final path in paths) {
      final text = files[path]!;
      final kind = kindOf(text);
      if (kind == 'facts') continue;
      if (kind == 'themes') {
        try {
          themes = parseThemes(text, source: path.split('/').last);
        } on DeckParseException catch (e) {
          broken.add(BrokenDeck(path: path, error: e));
        }
        continue;
      }
      final Deck deck;
      try {
        deck = DeckParser.parse(text, source: path.split('/').last);
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
      decks.add(DeckEntry(path: path, deck: deck));
    }
    return Catalog(
      decks: _inThemeOrder(decks, themes),
      broken: broken,
      themes: themes,
    );
  }

  /// [decks] with each course's theme decks put in [themes] order, in the
  /// places those decks held, so that everything else keeps its path order.
  /// A theme the path does not list goes after the ones it does.
  static List<DeckEntry> _inThemeOrder(
    List<DeckEntry> decks,
    List<DeckTheme> themes,
  ) {
    final rank = <String, int>{
      for (final (i, theme) in themes.indexed) theme.id: i,
    };
    int rankOf(DeckEntry e) => rank[e.deck.theme] ?? rank.length;
    final byCourse = <String, List<int>>{};
    for (final (i, entry) in decks.indexed) {
      if (entry.deck.theme == null) continue;
      final course = '${entry.language.code}/${entry.deck.native.code}';
      (byCourse[course] ??= <int>[]).add(i);
    }
    final ordered = List<DeckEntry>.of(decks);
    for (final slots in byCourse.values) {
      final inOrder = [for (final i in slots) decks[i]]
        ..sort((a, b) => rankOf(a).compareTo(rankOf(b)));
      for (final (n, slot) in slots.indexed) {
        ordered[slot] = inOrder[n];
      }
    }
    return ordered;
  }

  /// A file's `kind`, such as `facts` or `themes` for the files beside the
  /// decks that are not decks, or null. Decided by the file's `kind`, not
  /// its name. Text that is not a YAML mapping has none; the parser then
  /// reports what is wrong.
  static String? kindOf(String text) {
    try {
      final root = loadYaml(text.startsWith('﻿') ? text.substring(1) : text);
      final kind = root is YamlMap ? root['kind'] : null;
      return kind is String ? kind : null;
    } catch (_) {
      return null;
    }
  }

  /// Whether [text] is a facts file (`kind: facts`), which is valid beside
  /// the decks but is read by the facts loader, not `DeckParser`.
  static bool isFactsFile(String text) => kindOf(text) == 'facts';
}
