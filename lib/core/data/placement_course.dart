import 'package:yaml/yaml.dart';

import '../models/card.dart';
import '../models/deck.dart';
import '../models/sound_contrasts.dart';
import '../placement/placement_data.dart';
import 'course_path.dart';
import 'deck_parser.dart';
import 'guide_layers.dart';
import 'pattern_expander.dart';
import 'rule_expander.dart';
import 'sounds_parser.dart';
import 'yaml_tree.dart';

// A language's course read from its deck files as plain data, the way the app
// reads it for Find my level (`DeckCatalog` and `placementRunPlan` in
// lib/app), without Flutter: for the question-bank tool and the replay
// harness. Pure: the caller reads the files.

/// One language's course for a native language.
class PlacementCourse {
  PlacementCourse({
    required this.data,
    required this.deckIds,
    required this.grammarDecks,
    required this.broken,
  });

  /// What the question builder reads.
  final PlacementLanguageData data;

  /// The id of each word deck of [data], in path order.
  final List<String> deckIds;

  /// The deck indexes of the path's grammar units.
  final List<int> grammarDecks;

  /// Files that could not be read, with why.
  final Map<String, String> broken;
}

({String? kind, String? part, String? core}) _header(String text) {
  try {
    final root = loadYamlTree(text.startsWith('﻿') ? text.substring(1) : text)
        .value;
    String? field(String key) {
      final value = root is YamlMap ? root[key] : null;
      return value is String ? value : null;
    }

    return (kind: field('kind'), part: field('part'), core: field('core'));
  } on Object {
    return (kind: null, part: null, core: null);
  }
}

/// [language]'s course taught from [native], from [files] (path under the
/// decks root to text). The word decks are the course's decks in path order
/// up to the unit marked B1, with the path's level marks, grammar families
/// and the language's sounds, as `placementRunPlan` gives them. Script
/// checks are not read here (they need the app's script-deck reading).
PlacementCourse loadPlacementCourse(
  Map<String, String> files, {
  required String language,
  String native = 'en',
}) {
  final broken = <String, String>{};
  final paths = <String>[
    for (final path in files.keys)
      if (path.split('/').contains(language) &&
          path.endsWith('.yaml') &&
          !path.endsWith('index.json'))
        path,
  ]..sort();
  final headers = <String, ({String? kind, String? part, String? core})>{
    for (final path in paths) path: _header(files[path]!),
  };
  bool isLayer(String p) => headers[p]!.kind == 'layer';
  bool isGuide(String p) =>
      headers[p]!.kind == 'script' || headers[p]!.kind == 'sounds';
  bool isCore(String p) =>
      !isLayer(p) && !isGuide(p) && headers[p]!.part == 'core';
  final cores = <String, DeckCore>{};
  for (final path in paths.where(isCore)) {
    try {
      cores[path] = DeckParser.parseCore(
        files[path]!,
        source: path.split('/').last,
      );
    } on DeckParseException catch (e) {
      broken[path] = '$e';
    }
  }
  final soundCores = <String, SoundContrasts>{};
  for (final path in paths) {
    if (headers[path]!.kind == 'sounds' && headers[path]!.part == 'core') {
      try {
        soundCores[path] = parseSoundsCore(
          files[path]!,
          source: path.split('/').last,
        );
      } on DeckParseException catch (e) {
        broken[path] = '$e';
      }
    }
  }

  String coreOf(String path, String core) {
    final folders = path.split('/')..removeLast();
    final above = folders.isEmpty ? '' : (folders..removeLast()).join('/');
    return '${above.isEmpty ? '' : '$above/'}$core.yaml';
  }

  var decks = <Deck>[];
  SoundContrasts? sounds;
  LanguagePath? languagePath;
  for (final path in paths) {
    final text = files[path]!;
    final header = headers[path]!;
    final source = path.split('/').last;
    try {
      if (header.kind == 'path') {
        languagePath ??= parseLanguagePath(text, source: source);
      } else if (isLayer(path) && isGuideCoreId(header.core)) {
        final core = soundCores[coreOf(path, header.core!)];
        if (core != null) {
          final layer = parseGuideLayer(text, source: source);
          if (layer.native == native) {
            sounds = mergeSounds(core, layer, source: source);
          }
        }
      } else if (isLayer(path)) {
        final layer = DeckParser.parseLayer(text, source: source);
        final core = cores[coreOf(path, layer.core)];
        if (core == null) continue;
        final deck = mergeLayer(core, layer, source: source);
        if (deck.language.code == language && deck.native.code == native) {
          decks.add(deck);
        }
      } else if (!isCore(path) &&
          !isGuide(path) &&
          (header.kind == null ||
              <String>{'vocab', 'grammar', 'rules'}.contains(header.kind))) {
        final deck = DeckParser.parse(text, source: source);
        if (deck.language.code == language && deck.native.code == native) {
          decks.add(deck);
        }
      }
    } on DeckParseException catch (e) {
      broken[path] = '$e';
    }
  }
  decks = <Deck>[
    for (final deck in decks)
      deck.kind == DeckKind.grammar
          ? deck.withCards(expandPattern(deck))
          : deck,
  ];
  // Refs, as `DeckCatalog._withRefs` folds them.
  final written = <String, Card>{};
  for (final deck in decks) {
    if (deck.kind != DeckKind.vocab) continue;
    for (final card in deck.cards) {
      written.putIfAbsent(card.id, () => card);
    }
  }
  decks = <Deck>[
    for (final deck in decks)
      if (deck.refs.isEmpty) deck else deck.withCards(_resolved(deck, written)),
  ];
  // Rules decks expand into their cells.
  decks = <Deck>[
    for (final deck in decks)
      deck.kind == DeckKind.rules
          ? deck.withCards(expandRules(deck, wordOf: (id) => written[id]))
          : deck,
  ];
  // A hidden deck is never placed, nor is a deck with a genre, which is
  // beyond the basics the path's words are (deck-kinds plan, D3, D7).
  decks = <Deck>[
    for (final deck in decks)
      if (!deck.hidden && deck.genre == null) deck,
  ];
  final byId = <String, Deck>{for (final d in decks) d.id: d};
  final path = languagePath?.forNative(native, exists: byId.containsKey);
  final ordered = <Deck>[];
  if (path != null) {
    final alphabet = path.alphabet;
    for (final unit in path.units) {
      for (final id in unit) {
        final deck = byId.remove(id);
        if (deck != null && !alphabet.contains(id)) ordered.add(deck);
      }
    }
    for (final deck in decks) {
      if (byId.containsKey(deck.id) && !alphabet.contains(deck.id)) {
        ordered.add(deck);
      }
    }
  } else {
    ordered.addAll(decks);
  }
  var words = ordered;
  final plan = path?.plan ?? const <PlanUnit>[];
  final b1 = path?.milestoneIndex(Milestone.b1);
  if (b1 != null) {
    final upTo = <String>{for (final unit in plan.take(b1 + 1)) ...unit.decks};
    final cut = <Deck>[
      for (final deck in words)
        if (upTo.contains(deck.id)) deck,
    ];
    if (cut.isNotEmpty) words = cut;
  }
  final marks = <int>[];
  for (final milestone in Milestone.values) {
    final end = path?.milestoneIndex(milestone);
    if (end == null) continue;
    final ids = <String>{for (final unit in plan.take(end + 1)) ...unit.decks};
    final at = words.lastIndexWhere((deck) => ids.contains(deck.id));
    if (at >= 0 && !marks.contains(at)) marks.add(at);
  }
  final families = <String, List<String>>{
    for (final unit in plan)
      for (final id in unit.decks) id: unit.grammar,
  };
  final placementDecks = <PlacementDeck>[
    for (final deck in words)
      PlacementDeck(
        id: deck.id,
        cards: deck.cards,
        grammarFamilies: families[deck.id] ?? const <String>[],
      ),
  ];
  return PlacementCourse(
    data: PlacementLanguageData(
      language: language,
      decks: placementDecks,
      sounds: sounds,
      levelMarkDecks: marks,
    ),
    deckIds: <String>[for (final deck in words) deck.id],
    grammarDecks: <int>[
      for (final (i, deck) in placementDecks.indexed)
        if (deck.isGrammar) i,
    ],
    broken: broken,
  );
}

List<Card> _resolved(Deck deck, Map<String, Card> written) {
  final refAt = <int, CardRef>{for (final ref in deck.refs) ref.position: ref};
  final cards = <Card>[];
  var next = 0;
  for (var i = 0; i < deck.cards.length + deck.refs.length; i++) {
    final ref = refAt[i];
    if (ref == null) {
      cards.add(deck.cards[next++]);
      continue;
    }
    final home = written[ref.id];
    if (home != null) {
      final listed = ref.resolve(home, deckId: deck.id, sameNative: true);
      if (listed != null) cards.add(listed);
    }
  }
  return List<Card>.unmodifiable(cards);
}
