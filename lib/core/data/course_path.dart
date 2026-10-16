import 'package:yaml/yaml.dart';

import 'deck_parser.dart';

/// A language's path (#117, ADR-0013, ADR-0036): its decks in the order
/// they are taught, in units, one file per language learnt,
/// `decks/<lang>/<lang>-path.yaml`, shared by every native language it is
/// taught from.
///
/// The path names each deck by its core id, `te-home`. A learner from a
/// native language is taught that language's deck for it, `te-en-home`
/// from English, merged or single-file; [forNative] builds the path as one
/// course sees it.
class LanguagePath with _B1Plan {
  const LanguagePath({
    required this.id,
    required this.language,
    required this.plan,
    this.alphabet = const <String>{},
    this.regions = const <Region>[],
  });

  /// `<language>-path`, the file's name.
  final String id;

  /// The code of the language taught, such as `te`.
  final String language;

  /// The core ids of the decks that need the alphabet.
  final Set<String> alphabet;

  /// Every unit in file order, written or planned, its decks by core id.
  @override
  final List<PlanUnit> plan;

  /// The language's regions, in the order the app shows them. The app adds
  /// Elsewhere after them; it is no region of the file's.
  final List<Region> regions;

  /// The deck a learner from [native] is taught for [coreId]: `te-home`
  /// from `en` is `te-en-home`.
  String deckFor(String native, String coreId) =>
      '$language-$native-${coreId.substring(language.length + 1)}';

  /// The path as a learner from [native] is taught it: each core id
  /// becomes the course's deck for it, kept where [exists] says the
  /// catalog has that deck. A written unit left with none is not taught,
  /// as a planned unit is not, and its [plan] entry is coming.
  CoursePath forNative(
    String native, {
    required bool Function(String deckId) exists,
  }) {
    final units = <List<String>>[];
    final open = <int>{};
    final plan = <PlanUnit>[];
    for (final unit in this.plan) {
      if (unit.isPlanned) {
        plan.add(unit);
        continue;
      }
      final decks = List<String>.unmodifiable(<String>[
        for (final core in unit.decks)
          if (deckFor(native, core) case final id when exists(id)) id,
      ]);
      // The unit of "*" alone stays as it is; any other unit with no deck
      // in this native language is coming, and kept out of units and open,
      // where placing would take it for the unit of "*" alone.
      final starAlone = unit.open && unit.decks.isEmpty;
      if (decks.isEmpty && !starAlone) {
        plan.add(unit._course(const <String>[], coming: true));
        continue;
      }
      if (unit.open) open.add(units.length);
      units.add(decks);
      plan.add(unit._course(decks, coming: false));
    }
    return CoursePath(
      id: id,
      language: language,
      native: native,
      units: List<List<String>>.unmodifiable(units),
      open: Set<int>.unmodifiable(open),
      alphabet: Set<String>.unmodifiable(<String>{
        for (final core in alphabet)
          if (deckFor(native, core) case final id when exists(id)) id,
      }),
      plan: List<PlanUnit>.unmodifiable(plan),
    );
  }

  @override
  String toString() => 'LanguagePath($id)';
}

/// A course's path: its language's path as a learner from one native
/// language is taught it ([LanguagePath.forNative]). A course is a language
/// taught from another, such as Hindi from English.
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
class CoursePath with _B1Plan {
  const CoursePath({
    required this.id,
    required this.language,
    required this.native,
    required this.units,
    this.open = const <int>{},
    this.alphabet = const <String>{},
    this.plan = const <PlanUnit>[],
  });

  /// The language's path's id, `<language>-path`.
  final String id;

  /// The code of the language taught, such as `hi`.
  final String language;

  /// The code of the language it is taught from, such as `en`.
  final String native;

  /// Each unit's deck ids, in teaching order, without the wildcard: the
  /// written units with a deck in this native language. No deck is listed
  /// twice. Only a unit of the wildcard alone is empty.
  final List<List<String>> units;

  /// The units that end in the wildcard, by index.
  final Set<int> open;

  /// The decks that need the alphabet: its script, spelling and reading
  /// decks. A learner who skips the alphabet is not taught them.
  final Set<String> alphabet;

  /// Every unit of the language's path in file order, written or planned,
  /// with what the B1 plan says of it (ADR-0036) and its decks in this
  /// native language. [units] and [open] are its written units with a deck
  /// here only, so that Today, lessons and placement skip a planned or
  /// coming one.
  @override
  final List<PlanUnit> plan;

  /// How many of the language's written units this course teaches, a unit
  /// of `"*"` alone not counted: "30 of 34 units" ([writtenUnits]).
  int get coveredUnits =>
      plan.where((u) => !u.isComing && u.decks.isNotEmpty).length;

  /// The language's written units, a unit of `"*"` alone not counted.
  int get writtenUnits => plan
      .where((u) => !u.isPlanned && (u.isComing || u.decks.isNotEmpty))
      .length;

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
  String toString() => 'CoursePath($id, $native)';
}

/// What the B1 plan says, the same for the language's path and each
/// course's view of it.
mixin _B1Plan {
  List<PlanUnit> get plan;

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
}

/// The levels a B1 plan marks, written `A1`, `A2` and `B1` (ADR-0036).
enum Milestone { a1, a2, b1 }

/// A unit's deck not written yet, in a B1 plan.
class PlannedDeck {
  const PlannedDeck({required this.id, this.theme});

  /// The core id its decks will have, such as `te-health`; each course's
  /// deck for it is then `te-en-health`, `te-bn-health`, ….
  final String id;

  /// A theme unit's theme; null for a grammar unit, whose topics are on
  /// its [PlanUnit].
  final String? theme;
}

/// A passage a unit plans, named once in the path and described in each
/// native language.
class Passage {
  const Passage({required this.id, required this.texts});

  /// Unique in the path. It names the passage for every native language,
  /// so rewording a description leaves the others in place.
  final String id;

  /// Its description, by native language code.
  final Map<String, String> texts;

  /// The description for learners from [native], or null if it has none.
  String? textIn(String native) => texts[native];
}

/// One of a language's regions (ADR-0036): where a rater speaks the
/// language, and what a card's region note is about.
class Region {
  const Region({required this.id, required this.names});

  /// Permanent, as a card id: a rater's answers and region notes name it.
  final String id;

  /// Its name, by language code; English is always given.
  final Map<String, String> names;

  /// Its name in [code], else in English.
  String nameIn(String code) => names[code] ?? names['en']!;
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
    this.listeningPassages = const <Passage>[],
    this.readingPassages = const <Passage>[],
    this._coming = false,
  });

  /// The written unit's decks, without the wildcard: core ids in the
  /// language's path, the course's deck ids in a [CoursePath]. Empty if
  /// planned.
  final List<String> decks;

  /// Whether the unit ends in the wildcard.
  final bool open;

  final PlannedDeck? planned;

  /// The unit's planned size in words: 0 or more on a written unit, 1 or
  /// more on a planned theme unit; null where the plan gives none. One size
  /// for every native language.
  final int? words;

  /// The grammar topics it teaches, by topic id.
  final List<String> grammar;

  /// The level that ends with this unit.
  final Milestone? milestone;

  /// The unit's listening and reading passages. Both are given on a planned
  /// unit.
  final List<Passage> listeningPassages;
  final List<Passage> readingPassages;

  final bool _coming;

  bool get isPlanned => planned != null;

  /// Whether learners see it as "Coming": planned, or, in a [CoursePath],
  /// written but with no deck in its native language.
  bool get isComing => isPlanned || _coming;

  PlanUnit _course(List<String> decks, {required bool coming}) => PlanUnit(
    decks: decks,
    open: open,
    words: words,
    grammar: grammar,
    milestone: milestone,
    listeningPassages: listeningPassages,
    readingPassages: readingPassages,
    coming: coming,
  );
}

/// The wildcard a path's unit may end in.
const String pathWildcard = '*';

const _pathFields = {
  'schema',
  'kind',
  'id',
  'language',
  'description',
  'units',
  'alphabet',
  'regions',
};
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
const _passageFields = {'id', 'text'};
const _regionFields = {'id', 'name'};
final _name = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
final _code = RegExp(r'^[a-z]{2,3}$');
// A region id starts with a letter, as a note id does, and is none of
// YAML 1.1's boolean words.
final _regionId = RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$');
const _yaml11Bools = {'yes', 'no', 'on', 'off', 'true', 'false', 'y', 'n'};

/// The region the app keeps for its own answer, after the language's.
const String elsewhereRegion = 'elsewhere';

/// The language's path in [text], a `kind: path` file such as
/// `decks/hi/hi-path.yaml`. Throws [DeckParseException] if it is not a path
/// file, is still in the per-course form, or is malformed, so the catalog
/// can report it like a broken deck. Whether its decks exist, and the
/// other checks across files, are the validator's.
LanguagePath parseLanguagePath(String text, {String source = 'path.yaml'}) {
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
  if (language is! String || !_code.hasMatch(language)) {
    throw bad(
      'language must be a language code such as "hi", got "$language"',
      root.nodes['language'] ?? root,
    );
  }
  if (root.nodes.containsKey('native')) {
    throw bad(
      'native: a path is one per language learnt, '
      'decks/$language/$language-path.yaml, shared by every native language '
      '(ADR-0036); list core ids, such as "$language-home", and remove native',
      root.nodes['native'],
    );
  }
  for (final key in root.nodes.keys.cast<YamlNode>()) {
    if (!_pathFields.contains(key.value)) {
      throw bad('unknown field "${key.value}" in a path file', key);
    }
  }
  final id = root['id'];
  if (id != '$language-path') {
    throw bad(
      'a path of $language has id "$language-path", the filename stem, '
      'got "$id"',
      root.nodes['id'] ?? root,
    );
  }
  bool isCoreId(Object? value) =>
      value is String &&
      value.startsWith('$language-') &&
      _name.hasMatch(value.substring(language.length + 1));
  String notCoreId(Object? value) =>
      '"$value" is not a core id of $language: $language- and a name, such '
      'as $language-home';

  final regions = _regions(root.nodes['regions'], bad);
  final list = root.nodes['units'];
  if (list is! YamlList || list.nodes.isEmpty) {
    throw bad('units must be a non-empty list', list ?? root);
  }
  final seen = <String>{};
  final plan = <PlanUnit>[];
  final milestones = <Milestone, int>{};
  final passageIds = <String, int>{};
  for (final (u, item) in list.nodes.indexed) {
    // A unit is a list of core ids, or a mapping that says what the B1 plan
    // says of it (ADR-0036).
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
        'units[$u] must be a list of core ids, or a mapping with decks or '
        'planned',
        item,
      );
    }
    var unitOpen = false;
    final unit = <String>[];
    if (decksNode != null) {
      if (decksNode is! YamlList || decksNode.nodes.isEmpty) {
        throw bad('units[$u] must be a non-empty list of core ids', decksNode);
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
        if (!isCoreId(value)) throw bad('units[$u]: ${notCoreId(value)}', deck);
        if (!seen.add(value as String)) {
          throw bad('units[$u]: "$value" is listed twice', deck);
        }
        unit.add(value);
      }
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
      if (!isCoreId(id)) {
        throw bad(
          'units[$u].planned.id must be a core id of $language, $language- '
          'and a name, such as $language-health, got "$id"',
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
      if (themeNode != null && (theme is! String || !_name.hasMatch(theme))) {
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
      plannedDeck = PlannedDeck(id: id as String, theme: theme as String?);
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
        if (value is! String || !_name.hasMatch(value)) {
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

    List<Passage> passages(String key) {
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
        return const <Passage>[];
      }
      if (node is! YamlList ||
          node.nodes.isEmpty ||
          node.nodes.any((p) => p is! YamlMap)) {
        throw bad(
          'units[$u].$key must be a non-empty list of passages, each '
          '{ id, text }',
          node,
        );
      }
      return List<Passage>.unmodifiable(<Passage>[
        for (final (j, p) in node.nodes.cast<YamlMap>().indexed)
          _passage(p, 'units[$u].$key[$j]', u, passageIds, bad),
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
      throw bad('alphabet must be a list of core ids', alphabetNode);
    }
    for (final deck in alphabetNode.nodes) {
      final value = deck.value;
      if (!isCoreId(value)) throw bad('alphabet: ${notCoreId(value)}', deck);
      if (!seen.contains(value)) {
        throw bad('alphabet lists "$value", which the path does not', deck);
      }
      alphabet.add(value as String);
    }
  }
  return LanguagePath(
    id: id as String,
    language: language,
    alphabet: Set<String>.unmodifiable(alphabet),
    plan: List<PlanUnit>.unmodifiable(plan),
    regions: regions,
  );
}

Passage _passage(
  YamlMap node,
  String where,
  int unit,
  Map<String, int> seen,
  DeckParseException Function(String, [YamlNode?]) bad,
) {
  for (final key in node.nodes.keys.cast<YamlNode>()) {
    if (!_passageFields.contains(key.value)) {
      throw bad('$where: unknown field "${key.value}"', key);
    }
  }
  final id = node['id'];
  if (id is! String || !_name.hasMatch(id)) {
    throw bad('$where: id must match [a-z0-9-]+, got "$id"', node);
  }
  if (seen[id] case final k?) {
    throw bad(
      k == unit
          ? '$where: passage "$id" is also earlier in this unit'
          : '$where: passage "$id" is also in units[$k]',
      node.nodes['id'],
    );
  }
  seen[id] = unit;
  final texts = _byLanguage(
    node.nodes['text'],
    '$where.text',
    'must be a mapping of a native language\'s code to the passage\'s '
        'description, such as { "en": "..." }',
    bad,
    at: node,
  );
  return Passage(id: id, texts: texts);
}

List<Region> _regions(
  YamlNode? node,
  DeckParseException Function(String, [YamlNode?]) bad,
) {
  if (node == null) return const <Region>[];
  if (node is! YamlList || node.nodes.isEmpty) {
    throw bad(
      'regions must be a non-empty list of regions, each { id, name }',
      node,
    );
  }
  final regions = <Region>[];
  for (final (i, item) in node.nodes.indexed) {
    final where = 'regions[$i]';
    if (item is! YamlMap) throw bad('$where must be a mapping', item);
    for (final key in item.nodes.keys.cast<YamlNode>()) {
      if (!_regionFields.contains(key.value)) {
        throw bad('$where: unknown field "${key.value}"', key);
      }
    }
    final id = item['id'];
    if (id is! String || !_regionId.hasMatch(id) || _yaml11Bools.contains(id)) {
      throw bad(
        '$where.id must start with a letter and match [a-z0-9-]+, and not be '
        'a YAML 1.1 boolean word, got "$id"',
        item.nodes['id'] ?? item,
      );
    }
    if (id == elsewhereRegion) {
      throw bad(
        "$where.id: $elsewhereRegion is the app's own answer; give the "
        'region another id',
        item.nodes['id'],
      );
    }
    if (regions.any((r) => r.id == id)) {
      throw bad('$where.id: "$id" is used twice', item.nodes['id']);
    }
    final names = _byLanguage(
      item.nodes['name'],
      '$where.name',
      'must be a mapping of a language code to the region\'s name, with "en"',
      bad,
      at: item,
    );
    if (!names.containsKey('en')) {
      throw bad('$where.name has no "en"', item.nodes['name']);
    }
    regions.add(Region(id: id, names: names));
  }
  return List<Region>.unmodifiable(regions);
}

/// Text keyed by language code, as a facts file's texts are.
Map<String, String> _byLanguage(
  YamlNode? node,
  String where,
  String shape,
  DeckParseException Function(String, [YamlNode?]) bad, {
  required YamlNode at,
}) {
  if (node is! YamlMap || node.nodes.isEmpty) {
    throw bad('$where $shape', node ?? at);
  }
  final texts = <String, String>{};
  for (final MapEntry(:key, :value) in node.nodes.entries) {
    final code = (key as YamlNode).value;
    if (code is! String || !_code.hasMatch(code)) {
      throw bad('$where: "$code" is not a language code', key);
    }
    final text = value.value;
    if (text is! String || text.trim().isEmpty) {
      throw bad('$where: "$code" is not text', value);
    }
    texts[code] = text;
  }
  return Map<String, String>.unmodifiable(texts);
}

String _milestoneName(Milestone milestone) => milestone.name.toUpperCase();
