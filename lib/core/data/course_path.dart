import 'package:yaml/yaml.dart';

import 'deck_parser.dart';

/// A course's curated path (#117, ADR-0013): its decks in the order they are
/// taught, in units. A course is a language taught from another, such as
/// Hindi from English, and has one path.
///
/// A unit is what is taught together: a theme deck and the grammar that goes
/// with it, or a script. Today takes new cards from the first unfinished
/// unit and the one after it (`AppState.pendingUnits`), and placement passes
/// or places a unit whole (ADR-0013).
///
/// A unit may end in the wildcard `"*"`, which takes the course's decks the
/// path does not list, such as decks a learner adds (#22): those whose theme
/// is the unit's go at its bottom. A last unit of only `"*"` takes the rest,
/// so a deck whose theme no unit takes goes at the end ([placing]).
class CoursePath {
  const CoursePath({
    required this.id,
    required this.language,
    required this.native,
    required this.units,
    this.open = const <int>{},
    this.alphabet = const <String>{},
    this.plan = const <PlanUnit>[],
  });

  /// `<language>-<native>-path`, the file's name.
  final String id;

  /// The code of the language taught, such as `hi`.
  final String language;

  /// The code of the language it is taught from, such as `en`.
  final String native;

  /// Each unit's deck ids, in teaching order, without the wildcard. No deck
  /// is listed twice. Only a unit of the wildcard alone is empty.
  final List<List<String>> units;

  /// The units that end in the wildcard, by index.
  final Set<int> open;

  /// The decks that need the alphabet: its script, spelling and reading
  /// decks. A learner who skips the alphabet is not taught them.
  final Set<String> alphabet;

  /// Every unit in file order, written or planned, with what the B1 plan
  /// says of it (B1 format, spec 10). [units] and [open] are its written
  /// units only, so that Today, lessons and placement skip a planned one.
  final List<PlanUnit> plan;

  /// Whether the path has a B1 plan: some unit is a mapping that plans it,
  /// with a planned deck, a size, grammar topics or a milestone.
  bool get hasB1Plan => plan.any(
    (unit) =>
        unit.isPlanned ||
        unit.words != null ||
        unit.grammar.isNotEmpty ||
        unit.milestone != null,
  );

  /// The index in [plan] of the unit where [milestone] ends, or null.
  int? milestoneIndex(Milestone milestone) {
    for (final (i, unit) in plan.indexed) {
      if (unit.milestone == milestone) return i;
    }
    return null;
  }

  /// The units up to B1: every unit before the one marked B1, and that
  /// one; every unit when none is.
  Iterable<PlanUnit> get _upToB1 =>
      plan.take((milestoneIndex(Milestone.b1) ?? plan.length - 1) + 1);

  /// The grammar topics planned up to B1, in order, each once.
  List<String> get grammarTopics =>
      <String>{for (final unit in _upToB1) ...unit.grammar}.toList();

  /// The words planned up to B1: the sum of each unit's size.
  int get plannedWords =>
      _upToB1.fold(0, (sum, unit) => sum + (unit.words ?? 0));

  /// `hi/en`: the key the catalog finds a course's path by.
  String get course => '$language/$native';

  /// Every deck on the path, in order.
  Iterable<String> get deckIds => units.expand((unit) => unit);

  /// The index of the unit holding [deckId], or null if the path has none.
  int? unitOf(String deckId) {
    for (final (i, unit) in units.indexed) {
      if (unit.contains(deckId)) return i;
    }
    return null;
  }

  /// This path with [extra] decks, which it does not list, put where its
  /// wildcards say: each at the bottom of the first open unit that holds a
  /// deck of its theme ([themeOf] gives a listed deck's), else in the open
  /// unit of the wildcard alone. A deck no wildcard takes is left out, and
  /// follows the path as before. The result has no wildcards and no empty
  /// units.
  CoursePath placing(
    Iterable<({String id, String? theme})> extra,
    String? Function(String deckId) themeOf,
  ) {
    final placed = <List<String>>[for (final unit in units) List.of(unit)];
    final rest = <int>[
      for (final i in open)
        if (units[i].isEmpty) i,
    ];
    for (final deck in extra) {
      int? into;
      if (deck.theme != null) {
        for (final i in open.toList()..sort()) {
          if (units[i].any((id) => themeOf(id) == deck.theme)) {
            into = i;
            break;
          }
        }
      }
      into ??= rest.isEmpty ? null : rest.first;
      if (into != null) placed[into].add(deck.id);
    }
    return CoursePath(
      id: id,
      language: language,
      native: native,
      units: List<List<String>>.unmodifiable(<List<String>>[
        for (final unit in placed)
          if (unit.isNotEmpty) List<String>.unmodifiable(unit),
      ]),
      alphabet: alphabet,
      plan: plan,
    );
  }

  @override
  String toString() => 'CoursePath($id)';
}

/// The levels a B1 plan marks, written `A1`, `A2` and `B1` (spec 10.1).
enum Milestone { a1, a2, b1 }

/// A unit's deck not written yet, in a B1 plan.
class PlannedDeck {
  const PlannedDeck({required this.id, this.theme});

  /// The deck's id once written, such as `te-en-health`.
  final String id;

  /// A theme unit's theme; null for a grammar unit, whose topics are on
  /// its [PlanUnit].
  final String? theme;
}

/// One unit of a path as its B1 plan sees it: written, with its decks, or
/// planned.
class PlanUnit {
  const PlanUnit({
    this.decks = const <String>[],
    this.open = false,
    this.planned,
    this.words,
    this.grammar = const <String>[],
    this.milestone,
    this.listeningPassages = const <String>[],
    this.readingPassages = const <String>[],
  });

  /// The written unit's decks, without the wildcard; empty if planned.
  final List<String> decks;

  /// Whether the unit ends in the wildcard.
  final bool open;

  final PlannedDeck? planned;

  /// The unit's planned size in words: 0 or more on a written unit, 1 or
  /// more on a planned theme unit; null where the plan gives none.
  final int? words;

  /// The grammar topics it teaches, by topic id.
  final List<String> grammar;

  /// The level that ends with this unit.
  final Milestone? milestone;

  /// Short descriptions of the unit's listening and reading passages, in
  /// the course's native language. Both are given on a planned unit.
  final List<String> listeningPassages;
  final List<String> readingPassages;

  bool get isPlanned => planned != null;
}

/// The wildcard a path's unit may end in.
const String pathWildcard = '*';

const _unitFields = {
  'decks',
  'planned',
  'words',
  'grammar',
  'milestone',
  'listening_passages',
  'reading_passages',
};
const _plannedFields = {'id', 'theme', 'grammar', 'words'};
final _topic = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

final _code = RegExp(r'^[a-z]{2,3}$');
final _deckId = RegExp(r'^[a-z0-9-]+$');

/// The path in [text], a `kind: path` file such as `decks/hi/hi-en-path.yaml`.
/// Throws [DeckParseException] if it is not a path file or is malformed, so
/// the catalog can report it like a broken deck. Whether its decks exist is
/// for the catalog, and the validator, to say.
CoursePath parseCoursePath(String text, {String source = 'path.yaml'}) {
  DeckParseException bad(String message, [YamlNode? at]) => DeckParseException(
    message,
    source: source,
    line: at == null ? null : at.span.start.line + 1,
    column: at == null ? null : at.span.start.column + 1,
  );

  final YamlNode root;
  try {
    root = loadYamlNode(text);
  } on YamlException catch (e) {
    throw bad(e.message);
  }
  if (root is! YamlMap || root['kind'] != 'path') {
    throw bad('a path file is a mapping with "kind: path"', root);
  }
  final language = root['language'];
  final native = root['native'];
  for (final (key, value) in <(String, Object?)>[
    ('language', language),
    ('native', native),
  ]) {
    if (value is! String || !_code.hasMatch(value)) {
      throw bad(
        '$key must be a language code such as "hi", got "$value"',
        root.nodes[key] ?? root,
      );
    }
  }
  final id = root['id'];
  if (id != '$language-$native-path') {
    throw bad(
      'a path for $language from $native has id "$language-$native-path", '
      'got "$id"',
      root.nodes['id'] ?? root,
    );
  }
  final list = root.nodes['units'];
  if (list is! YamlList || list.nodes.isEmpty) {
    throw bad('units must be a non-empty list', list ?? root);
  }
  final seen = <String>{};
  final units = <List<String>>[];
  final open = <int>{};
  final plan = <PlanUnit>[];
  final milestones = <Milestone, int>{};
  for (final (u, item) in list.nodes.indexed) {
    // A unit is a list of deck ids, as it always was, or a mapping that
    // says what the B1 plan says of it (spec 10.1).
    final fields = item is YamlMap ? item : null;
    final decksNode = fields == null ? item : fields.nodes['decks'];
    if (fields != null) {
      for (final key in fields.nodes.keys.cast<YamlNode>()) {
        if (!_unitFields.contains(key.value)) {
          throw bad('units[$u]: unknown field "${key.value}" in a unit', key);
        }
      }
      if (decksNode != null && fields.nodes.containsKey('planned')) {
        throw bad('units[$u] has decks or planned, not both', item);
      }
      if (decksNode == null && !fields.nodes.containsKey('planned')) {
        throw bad('units[$u] has neither decks nor planned', item);
      }
    } else if (item is! YamlList) {
      throw bad(
        'units[$u] must be a non-empty list of deck ids, or a mapping with '
        'decks or planned',
        item,
      );
    }
    var unitOpen = false;
    final unit = <String>[];
    if (decksNode != null) {
      if (decksNode is! YamlList || decksNode.nodes.isEmpty) {
        throw bad('each unit is a non-empty list of deck ids', decksNode);
      }
      for (final (i, deck) in decksNode.nodes.indexed) {
        final value = deck.value;
        if (value == pathWildcard) {
          if (i != decksNode.nodes.length - 1) {
            throw bad('"$pathWildcard" can only end a unit', deck);
          }
          if (unit.isEmpty && u != list.nodes.length - 1) {
            throw bad(
              'a unit of "$pathWildcard" alone can only be the last',
              deck,
            );
          }
          unitOpen = true;
          continue;
        }
        if (value is! String || !_deckId.hasMatch(value)) {
          throw bad('a unit lists deck ids, got "$value"', deck);
        }
        if (!seen.add(value)) throw bad('deck "$value" is listed twice', deck);
        unit.add(value);
      }
      if (unitOpen) open.add(units.length);
      units.add(List<String>.unmodifiable(unit));
    }
    if (fields == null) {
      plan.add(
        PlanUnit(decks: List<String>.unmodifiable(unit), open: unitOpen),
      );
      continue;
    }

    final plannedNode = fields.nodes['planned'];
    final planned = plannedNode is YamlMap ? plannedNode : null;
    if (plannedNode != null && planned == null) {
      throw bad(
        'units[$u].planned must be a mapping with id, and theme or grammar',
        plannedNode,
      );
    }
    if (planned != null) {
      for (final key in planned.nodes.keys.cast<YamlNode>()) {
        if (!_plannedFields.contains(key.value)) {
          throw bad('units[$u].planned: unknown field "${key.value}"', key);
        }
      }
    }
    for (final key in const <String>['words', 'grammar']) {
      if (planned != null &&
          planned.nodes.containsKey(key) &&
          fields.nodes.containsKey(key)) {
        throw bad(
          'units[$u]: $key is given both in planned and beside it',
          fields.nodes[key],
        );
      }
    }
    YamlNode? either(String key) => fields.nodes[key] ?? planned?.nodes[key];

    PlannedDeck? plannedDeck;
    if (planned != null) {
      final idNode = planned.nodes['id'];
      final id = idNode?.value;
      if (id is! String ||
          !_deckId.hasMatch(id) ||
          !id.startsWith('$language-$native-')) {
        throw bad(
          'units[$u].planned.id must be a deck id starting with '
          '$language-$native-, the course, got "$id"',
          idNode ?? planned,
        );
      }
      final themeNode = planned.nodes['theme'];
      final hasGrammar = either('grammar') != null;
      if (themeNode != null && hasGrammar) {
        throw bad(
          'units[$u].planned names theme or grammar, not both',
          planned,
        );
      }
      if (themeNode == null && !hasGrammar) {
        throw bad(
          'units[$u].planned needs a theme or a grammar topic',
          planned,
        );
      }
      final theme = themeNode?.value;
      if (themeNode != null && (theme is! String || !_deckId.hasMatch(theme))) {
        throw bad(
          'units[$u].planned.theme must be a theme id, got "$theme"',
          themeNode,
        );
      }
      if (themeNode != null && either('words') == null) {
        throw bad(
          'units[$u].planned: a planned theme unit gives its size in words',
          planned,
        );
      }
      plannedDeck = PlannedDeck(id: id, theme: theme as String?);
    }

    final wordsNode = either('words');
    int? words;
    if (wordsNode != null) {
      final value = wordsNode.value;
      final least = plannedDeck?.theme != null ? 1 : 0;
      // A whole number, written as one: not a boolean, and not 1_000.
      if (value is! int || value < least) {
        throw bad(
          'units[$u].words must be a whole number of words, $least or more, '
          'got "${wordsNode.span.text}"',
          wordsNode,
        );
      }
      words = value;
    }

    final grammarNode = either('grammar');
    final grammar = <String>[];
    if (grammarNode != null) {
      final topics = grammarNode is YamlList
          ? grammarNode.nodes
          : <YamlNode>[grammarNode];
      for (final topic in topics) {
        final value = topic.value;
        if (value is! String || !_topic.hasMatch(value)) {
          throw bad(
            'units[$u].grammar must be a grammar topic id or a list of them, '
            'such as ["past"], got "$value"',
            topic,
          );
        }
        if (grammar.contains(value)) {
          throw bad('units[$u].grammar: "$value" is listed twice', topic);
        }
        grammar.add(value);
      }
    }

    final milestoneNode = fields.nodes['milestone'];
    Milestone? milestone;
    if (milestoneNode != null) {
      milestone = switch (milestoneNode.value) {
        'A1' => Milestone.a1,
        'A2' => Milestone.a2,
        'B1' => Milestone.b1,
        final other => throw bad(
          'units[$u].milestone must be "A1", "A2" or "B1", got "$other"',
          milestoneNode,
        ),
      };
      if (milestones[milestone] case final j?) {
        throw bad(
          'units[$u]: milestone "${milestoneNode.value}" is already on '
          'units[$j]',
          milestoneNode,
        );
      }
      if (milestones.keys.any((m) => m.index > milestone!.index)) {
        throw bad(
          'units: the B1 plan needs the milestones A1, A2 and B1, each once '
          'and in that order; found '
          '${[...milestones.keys, milestone].map(_milestoneName).join(', ')}',
          milestoneNode,
        );
      }
      milestones[milestone] = u;
    }

    List<String> passages(String key) {
      final node = fields.nodes[key];
      if (node == null) {
        if (plannedDeck != null) {
          throw bad(
            'units[$u]: a planned unit names its listening_passages and its '
            'reading_passages (b1-plans.md: each planned unit names its '
            'listening and reading passages)',
            item,
          );
        }
        return const <String>[];
      }
      if (node is! YamlList ||
          node.nodes.isEmpty ||
          node.nodes.any((p) => p.value is! String || '${p.value}'.isEmpty)) {
        throw bad(
          'units[$u].$key must be a non-empty list of short descriptions',
          node,
        );
      }
      return List<String>.unmodifiable(<String>[
        for (final p in node.nodes) p.value as String,
      ]);
    }

    plan.add(
      PlanUnit(
        decks: List<String>.unmodifiable(unit),
        open: unitOpen,
        planned: plannedDeck,
        words: words,
        grammar: List<String>.unmodifiable(grammar),
        milestone: milestone,
        listeningPassages: passages('listening_passages'),
        readingPassages: passages('reading_passages'),
      ),
    );
  }
  final alphabetNode = root.nodes['alphabet'];
  final alphabet = <String>{};
  if (alphabetNode != null) {
    if (alphabetNode is! YamlList) {
      throw bad('alphabet must be a list of deck ids', alphabetNode);
    }
    for (final deck in alphabetNode.nodes) {
      final value = deck.value;
      if (value is! String || !seen.contains(value)) {
        throw bad('alphabet lists "$value", which the path does not', deck);
      }
      alphabet.add(value);
    }
  }
  return CoursePath(
    id: id as String,
    language: language as String,
    native: native as String,
    units: List<List<String>>.unmodifiable(units),
    open: Set<int>.unmodifiable(open),
    alphabet: Set<String>.unmodifiable(alphabet),
    plan: List<PlanUnit>.unmodifiable(plan),
  );
}

String _milestoneName(Milestone milestone) => milestone.name.toUpperCase();
