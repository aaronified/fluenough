import 'package:yaml/yaml.dart';

import '../models/author.dart';
import '../models/card.dart';
import '../models/deck.dart';
import '../models/drill_mode.dart';
import '../models/grammar_pattern.dart';
import '../models/reading.dart';
import '../models/rule.dart';

part 'deck_layers.dart';

/// A deck file that could not be read, and where in it the problem is.
///
/// A deck that fails to parse is skipped and shown as broken. It must never
/// take the app down, so [DeckParser.parse] reports every problem it finds in
/// a deck as this, for the caller to catch.
class DeckParseException implements Exception {
  const DeckParseException(
    this.message, {
    required this.source,
    this.line,
    this.column,
  });

  /// What is wrong, without the position.
  final String message;

  /// The file name or label that was passed to [DeckParser.parse].
  final String source;

  /// 1-based line of the offending key or value, or null if unknown.
  final int? line;

  /// 1-based column of the offending key or value, or null if unknown.
  final int? column;

  /// `es-en-core-100.yaml:12:5: <message>`, the way a compiler reports it.
  @override
  String toString() {
    final at = line == null
        ? source
        : '$source:$line${column == null ? '' : ':$column'}';
    return '$at: $message';
  }
}

/// Reads a deck file into a [Deck]. The format is `docs/DECK-FORMAT.md`.
///
/// `tools/validate_decks.py` is the reference for what a valid deck is, and CI
/// runs it on every deck in the repository. This checks less than it does:
/// the structure, and the rules that protect card ids. It must never reject a
/// deck the validator accepts, or that deck would pass CI and then fail on a
/// device, so every rule here is one the validator enforces too. It is still
/// strict enough to fail clearly on a deck a user imports, which CI never saw.
///
/// The exception is YAML that PyYAML loads and package:yaml does not, which no
/// rule here decides: a tag package:yaml does not build, or builds more
/// strictly, like `!!timestamp`, `!!float 1` or `!!bool yes`; and oddities
/// such as a `"\uD800"` escape or a U+2028 line break. A deck using one
/// passes CI and fails here. Plain scalars are not among them: both read them
/// as YAML 1.2's core schema does ([_value]).
///
/// Parsing stops at the first problem.
abstract final class DeckParser {
  /// Parses [yaml] into a [Deck], or throws a [DeckParseException].
  ///
  /// [source] names the deck in error messages, and is usually its file name.
  /// It is not compared with the deck id.
  ///
  /// A grammar deck comes back with [Deck.pattern] set and no cards. Expanding
  /// the pattern into cards is a separate step.
  static Deck parse(String yaml, {required String source}) =>
      _Reader(source).deck(_load(yaml, source));

  /// Parses [yaml], a core file (`part: "core"`, B1 format spec 2.2), into a
  /// [DeckCore], or throws a [DeckParseException]. A core is not a deck: it
  /// is merged with each of its layers by [mergeLayer].
  static DeckCore parseCore(String yaml, {required String source}) =>
      _Reader(source).core(_load(yaml, source));

  /// Parses [yaml], a layer (`kind: "layer"`, spec 2.6), into a
  /// [DeckLayer], or throws a [DeckParseException]. What it says about its
  /// core's cards is checked when the two are merged, by [mergeLayer].
  static DeckLayer parseLayer(String yaml, {required String source}) =>
      _Reader(source).layer(_load(yaml, source));

  static YamlNode _load(String yaml, String source) {
    final YamlNode root;
    try {
      // PyYAML, and so CI, skips a byte order mark. package:yaml does not.
      root = loadYamlNode(yaml.startsWith('\uFEFF') ? yaml.substring(1) : yaml);
    } on YamlException catch (e) {
      final start = e.span?.start;
      throw DeckParseException(
        'not valid YAML: ${e.message}',
        source: source,
        line: start == null ? null : start.line + 1,
        column: start == null ? null : start.column + 1,
      );
    } catch (e) {
      // package:yaml fails in other ways too, with no position: a RangeError
      // on `!!float 1`, an ArgumentError on a tag like `!<%ZZ>`, and a
      // StackOverflowError on nesting thousands of levels deep.
      throw DeckParseException('could not be read as YAML: $e', source: source);
    }
    return root;
  }
}

const _headerFields = {
  'schema',
  'id',
  'name',
  'kind',
  'language',
  'native',
  'license',
  'authors',
  'source',
  'description',
  'tags',
  'cards',
  'pattern',
  'theme',
  'passages',
};

const _cardFields = {
  'id',
  'target',
  'native',
  'reading',
  'ipa',
  'alt_target',
  'alt_native',
  'pos',
  'gender',
  'tags',
  'notes',
  'audio',
  'examples',
  'modes',
  'pair',
  'picture',
  'phrasebook',
  'bases',
  'rules',
  'wiktionary',
};

/// A layer-only card's fields: a single-file card's, its id being its key.
final _layerCardFields = _cardFields.difference(const {'id'});

/// What a ref may give: the native side of a card written in another deck
/// (ADR-0018).
const _refFields = {
  'ref',
  'native',
  'reading',
  'ipa',
  'alt_native',
  'tags',
  'notes',
  'examples',
  'modes',
  'wiktionary',
};

// The B1 format (spec sections 2 to 8).
const _coreHeaderFields = {
  'schema',
  'id',
  'part',
  'kind',
  'language',
  'license',
  'authors',
  'source',
  'tags',
  'theme',
  'cards',
  'pattern',
  'table',
  'rules',
};
const _layerHeaderFields = {
  'schema',
  'id',
  'kind',
  'core',
  'native',
  'name',
  'description',
  'license',
  'authors',
  'source',
  'tags',
  'cards',
  'pattern',
  'table',
  'rules',
};
const _coreCardFields = {
  'id',
  'target',
  'reading',
  'ipa',
  'alt_target',
  'pos',
  'gender',
  'tags',
  'audio',
  'examples',
  'modes',
  'picture',
  'notes',
  'phrasebook',
  'bases',
  'rules',
};
const _coreRefFields = {
  'ref',
  'reading',
  'ipa',
  'tags',
  'modes',
  'examples',
  'notes',
};
const _coreExampleFields = {'target', 'reading', 'ipa', 'bases'};
const _layerEntryFields = {
  'native',
  'alt_native',
  'notes',
  'examples',
  'bases',
  'wiktionary',
};
const _noteFields = {'kind', 'text', 'id', 'ref', 'source', 'words', 'region'};
const _noteWordFields = {'word', 'reading', 'ipa'};
const _baseFields = {
  'word',
  'ref',
  'base',
  'reading',
  'ipa',
  'meaning',
  'wiktionary',
};
const _tableFields = {'applies_to', 'slots', 'rows'};
const _appliesToFields = {'pos', 'tags', 'except'};
const _rowFields = {'word', 'key', 'forms', 'readings', 'ipas'};
const _ruleFields = {'id', 'slots', 'words'};

/// YAML 1.1's boolean words, which a slot key or a note id may not be:
/// other tools may still read them as booleans.
const _yaml11Words = {'yes', 'no', 'on', 'off', 'true', 'false', 'y', 'n'};

/// A slot key or a written note id: it starts with a letter, so it is never
/// a number, nor a note's position.
final _letterKey = RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$');

/// A placeholder in a note's text or a rule's explanation (spec 6.4), and
/// anything that looks like one.
final _placeholder = RegExp(r'\{([1-9][0-9]*)\}');
final _bracedNumber = RegExp(r'\{([0-9]+)\}');

const _patternFields = {
  'name',
  'slot_name',
  'slots',
  'prompt',
  'entries',
  'notes',
};

const _entryFields = {
  'lemma',
  'key',
  'gloss',
  'forms',
  'reading',
  'readings',
  'ipa',
  'ipas',
};
const _passageFields = {
  'id',
  'title',
  'sentences',
  'source',
  'theme',
  'questions',
  'glossary',
};
const _sentenceFields = {'text', 'reading', 'ipa'};
const _glossFields = {'word', 'modern', 'reading', 'ipa', 'meaning', 'note'};
const _questionFields = {'id', 'prompt', 'options', 'answer'};
const _exampleFields = {'target', 'native', 'reading', 'ipa', 'bases'};
const _authorFields = {'name', 'url'};

/// Deck and card ids: lowercase letters and digits, joined by single hyphens.
final _idPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

/// A language code keying a reading question's text, such as `en`.
final _languageCode = RegExp(r'^[a-z]{2,3}$');
final _iso639_3Pattern = RegExp(r'^[a-z]{3}$');

/// Walks one deck, knowing its [source] so that any failure can name it.
class _Reader {
  _Reader(this.source);

  final String source;

  /// The code of the language the file teaches, once it is known: what its
  /// rule ids start with. A layer, which has no language block, takes it
  /// from its id.
  String lang = '';

  Never fail(YamlNode node, String message) {
    final start = node.span.start;
    throw DeckParseException(
      message,
      source: source,
      line: start.line + 1,
      column: start.column + 1,
    );
  }

  /// The top-level fields of a deck, a core or a layer, its schema checked.
  _Fields top(YamlNode root) {
    if (root is! YamlMap) {
      fail(
        root,
        _value(root) == null
            ? 'the deck is empty'
            : 'a deck must be a mapping of fields, starting with "schema: 1"',
      );
    }
    final fields = _Fields(this, root, '');
    final schemaNode = fields.require('schema');
    final schema = _value(schemaNode);
    if (!_isNumber(schema) || schema != 1) {
      fail(schemaNode, 'schema must be 1, got ${_describe(schemaNode)}');
    }
    return fields;
  }

  /// Refuses a core, a layer, and what only they have, in a single-file
  /// deck, in the order the validator tells them apart (spec 2.2).
  void refuseCoreAndLayer(_Fields fields, YamlNode? kindNode) {
    if (kindNode != null && _value(kindNode) == 'layer') {
      fail(kindNode, 'this is a layer; it is read with DeckParser.parseLayer');
    }
    final partNode = fields.node('part');
    if (partNode != null) {
      if (_value(partNode) == 'core') {
        fail(
          partNode,
          'this is a core file; it is read with DeckParser.parseCore and '
          'merged with a layer',
        );
      }
      fail(
        partNode,
        'part must be "core", or left out on a single-file deck; got '
        '${_describe(partNode)}',
      );
    }
    if (fields.has('core')) {
      fail(fields.keyNode('core'), 'only a layer names a core (kind: "layer")');
    }
    for (final key in const <String>['table', 'rules']) {
      if (fields.has(key)) {
        fail(
          fields.keyNode(key),
          'only a rules core has $key; a rules deck is written as a core and '
          'layers',
        );
      }
    }
    if (kindNode != null && _value(kindNode) == 'rules') {
      fail(kindNode, 'a rules deck is written as a core and layers');
    }
  }

  Deck deck(YamlNode root) {
    final fields = top(root);

    final kindNode = fields.node('kind');
    refuseCoreAndLayer(fields, kindNode);
    final kind = kindNode == null
        ? DeckKind.vocab
        : switch (_value(kindNode)) {
            'vocab' => DeckKind.vocab,
            'grammar' => DeckKind.grammar,
            'reading' => DeckKind.reading,
            // Valid, but not a deck: its facts are not drilled, and a caller
            // loading a directory routes such files elsewhere (#48).
            'facts' => fail(
              kindNode,
              'this is a facts file, not a deck; it is read by the facts '
              'loader, not DeckParser',
            ),
            'themes' => fail(
              kindNode,
              'this is the themes file, not a deck; the catalog reads it '
              'with parseThemes',
            ),
            _ => fail(
              kindNode,
              'kind must be vocab, grammar or reading, got '
              '${_describe(kindNode)}',
            ),
          };

    // After the kind, so that a facts file, whose `facts` is no deck field,
    // is refused as a facts file rather than for an unknown field.
    fields.allowOnly(_headerFields);

    final id = this.id(fields.require('id'), 'id');
    final name = fields.string('name');
    final license = fields.string('license');
    final language = this.language(
      fields.require('language'),
      'language',
      full: true,
    );
    lang = language.code;
    final native = this.language(
      fields.require('native'),
      'native',
      full: false,
    );
    final tags = fields.strings('tags');
    final authors = this.authors(fields.node('authors'));
    final description = fields.optionalString('description');
    final deckSource = fields.optionalString('source');
    final theme = fields.has('theme')
        ? this.id(fields.require('theme'), 'theme')
        : null;

    var cards = const <Card>[];
    var refs = const <CardRef>[];
    GrammarPattern? pattern;
    var passages = const <Passage>[];
    if (kind != DeckKind.reading && fields.has('passages')) {
      fail(
        fields.keyNode('passages'),
        'passages are only for a reading deck; add "kind: reading" or '
        'remove them',
      );
    }
    switch (kind) {
      case DeckKind.vocab:
        if (fields.has('pattern')) {
          fail(
            fields.keyNode('pattern'),
            'pattern is only for a grammar deck; add "kind: grammar" or '
            'remove it',
          );
        }
        (:cards, :refs) = this.cards(fields.require('cards'), id);
      case DeckKind.grammar:
        if (fields.has('cards')) {
          fail(
            fields.keyNode('cards'),
            'a grammar deck has a pattern, not cards',
          );
        }
        pattern = this.pattern(fields.require('pattern'));
      case DeckKind.reading:
        for (final key in const <String>['cards', 'pattern']) {
          if (fields.has(key)) {
            fail(fields.keyNode(key), 'a reading deck has passages, not $key');
          }
        }
        passages = this.passages(fields.require('passages'));
        // Each question is a card, so that it is scheduled and recorded as
        // every card is (ADR-0019).
        cards = List<Card>.unmodifiable(<Card>[
          for (final passage in passages)
            for (final question in passage.questions)
              QuestionCard(
                deckId: id,
                passage: passage,
                question: question,
                source: passage.source ?? deckSource,
              ),
        ]);
      case DeckKind.rules:
        // Refused above, with the reason, before the fields are read.
        fail(kindNode!, 'a rules deck is written as a core and layers');
    }

    return Deck(
      id: id,
      name: name,
      kind: kind,
      language: language,
      native: native,
      license: license,
      cards: cards,
      pattern: pattern,
      passages: passages,
      description: description,
      tags: tags,
      authors: authors,
      source: deckSource,
      theme: theme,
      refs: refs,
    );
  }

  /// [node] as a mapping, failing if it is anything else.
  _Fields fields(YamlNode node, String path) {
    if (node is! YamlMap) fail(node, _wrongType(node, path, 'a mapping'));
    return _Fields(this, node, path);
  }

  /// [node] as a list, failing if it is anything else or, unless
  /// [allowEmpty], if it has no items.
  List<YamlNode> list(YamlNode node, String path, {bool allowEmpty = false}) {
    if (node is! YamlList) fail(node, _wrongType(node, path, 'a list'));
    if (!allowEmpty && node.nodes.isEmpty) {
      fail(node, '$path must not be empty');
    }
    return node.nodes;
  }

  /// [node] as text, failing on anything else, and on blank text unless
  /// [allowEmpty].
  String text(YamlNode node, String name, {bool allowEmpty = false}) {
    final value = _value(node);
    if (value is! String) fail(node, _notText(node, name));
    if (!allowEmpty && _blank.hasMatch(value)) {
      fail(node, '$name must not be empty');
    }
    return value;
  }

  /// A deck or card id. Card ids key every learner's review history, so a
  /// malformed one is refused rather than tidied.
  String id(YamlNode node, String name) {
    final id = text(node, name);
    if (!_idPattern.hasMatch(id)) {
      fail(
        node,
        '$name must be lowercase letters and digits joined by single hyphens, '
        'like "es-en-core-0001"; got "$id"',
      );
    }
    return id;
  }

  /// A three-letter ISO 639-3 code, such as `hin`.
  String iso639_3(YamlNode node, String name) {
    final code = text(node, name);
    if (!_iso639_3Pattern.hasMatch(code)) {
      fail(
        node,
        '$name must be the language\'s three-letter ISO 639-3 code, like '
        '"hin" for Hindi; got "$code"',
      );
    }
    return code;
  }

  LanguageInfo language(YamlNode node, String path, {required bool full}) {
    final fields = this.fields(node, path);
    return LanguageInfo(
      code: fields.string('code'),
      iso639_3: iso639_3(fields.require('iso639_3'), '$path.iso639_3'),
      name: fields.string('name'),
      // Any script name is accepted, so that a new one needs no parser change.
      script: full
          ? fields.string('script')
          : fields.optionalString('script', allowEmpty: false) ?? 'latin',
      tts: fields.optionalString('tts', allowEmpty: false),
      rtl: fields.optionalBool('rtl') ?? false,
      icon: fields.optionalString('icon', allowEmpty: false),
    );
  }

  List<Author> authors(YamlNode? node) {
    if (node == null || _value(node) == null) return const <Author>[];
    return List.unmodifiable([
      for (final (i, item) in list(node, 'authors', allowEmpty: true).indexed)
        author(item, 'authors[$i]'),
    ]);
  }

  Author author(YamlNode node, String path) {
    final fields = this.fields(node, path);
    fields.allowOnly(_authorFields);
    return Author(
      name: fields.string('name'),
      url: fields.optionalString('url'),
    );
  }

  /// The cards a deck writes, and the ones it lists by ref, each ref with
  /// its place in the list.
  ({List<Card> cards, List<CardRef> refs}) cards(YamlNode node, String deckId) {
    final seen = <String, YamlNode>{};
    final cards = <Card>[];
    final refs = <CardRef>[];
    for (final (i, item) in list(node, 'cards').indexed) {
      if (item is YamlMap && item.nodes.containsKey('ref')) {
        refs.add(ref(item, 'cards[$i]', i, seen));
      } else {
        cards.add(card(item, 'cards[$i]', deckId, seen));
      }
    }
    return (cards: List.unmodifiable(cards), refs: List.unmodifiable(refs));
  }

  /// A card written in another deck, listed here (ADR-0018).
  CardRef ref(
    YamlNode node,
    String path,
    int position,
    Map<String, YamlNode> seen,
  ) {
    final fields = this.fields(node, path);
    fields.allowOnly(_refFields);
    final idNode = fields.require('ref');
    final id = this.id(idNode, '$path.ref');
    final first = seen[id];
    if (first != null) {
      fail(
        idNode,
        '$path.ref: card "$id" is already in the deck, ${_firstUsed(first)}',
      );
    }
    seen[id] = idNode;
    return CardRef(
      id: id,
      position: position,
      native: fields.has('native') ? fields.string('native') : null,
      reading: fields.optionalString('reading', allowEmpty: false),
      ipa: fields.optionalString('ipa', allowEmpty: false),
      altNative: fields.has('alt_native') ? fields.strings('alt_native') : null,
      tags: fields.has('tags') ? fields.strings('tags') : null,
      notes: fields.has('notes')
          ? notes(fields.node('notes'), '$path.notes')
          : null,
      examples: fields.has('examples')
          ? examples(fields.node('examples'), '$path.examples')
          : null,
      modes: fields.has('modes')
          ? modes(fields.node('modes'), '$path.modes')
          : null,
      wiktionary: mark(fields, 'wiktionary', path, _wiktionaryRule)
          ? true
          : null,
    );
  }

  /// One card. [seen] maps each card id so far to where it was declared.
  /// A layer-only card is written without an id: its [key] in the layer's
  /// `cards` is its id.
  Card card(
    YamlNode node,
    String path,
    String deckId,
    Map<String, YamlNode> seen, {
    YamlNode? key,
  }) {
    final fields = this.fields(node, path);
    fields.allowOnly(key == null ? _cardFields : _layerCardFields);

    final idNode = key ?? fields.require('id');
    final id = this.id(idNode, key == null ? '$path.id' : path);
    final first = seen[id];
    if (first != null) {
      fail(idNode, '$path.id: duplicate card id "$id", ${_firstUsed(first)}');
    }
    seen[id] = idNode;

    final notes = this.notes(fields.node('notes'), '$path.notes');
    return Card(
      id: id,
      deckId: deckId,
      target: fields.string('target'),
      native: fields.string('native'),
      reading: fields.optionalString('reading', allowEmpty: false),
      ipa: fields.optionalString('ipa', allowEmpty: false),
      altTarget: fields.strings('alt_target'),
      altNative: fields.strings('alt_native'),
      pos: fields.optionalString('pos', allowEmpty: false),
      gender: fields.optionalString('gender'),
      tags: fields.strings('tags'),
      notes: notes,
      audio: fields.optionalString('audio'),
      examples: examples(fields.node('examples'), '$path.examples'),
      modes: modes(fields.node('modes'), '$path.modes'),
      // Pair notes are the one source of pairs (OPEN-16); a written pair
      // stays valid, and comes first.
      pair:
          fields.optionalString('pair', allowEmpty: false) ??
          notes.where((n) => n.kind == NoteKind.pair).firstOrNull?.ref,
      picture: fields.optionalString('picture', allowEmpty: false),
      phrasebook: mark(fields, 'phrasebook', path, _phrasebookRule),
      bases: bases(fields.node('bases'), '$path.bases', core: false),
      rules: ruleIds(fields.node('rules'), '$path.rules'),
      wiktionary: mark(fields, 'wiktionary', path, _wiktionaryRule),
    );
  }

  List<CardExample> examples(YamlNode? node, String path) {
    if (node == null || _value(node) == null) return const <CardExample>[];
    return List.unmodifiable([
      for (final (i, item) in list(node, path, allowEmpty: true).indexed)
        example(item, '$path[$i]'),
    ]);
  }

  CardExample example(YamlNode node, String path) {
    final fields = this.fields(node, path);
    fields.allowOnly(_exampleFields);
    return CardExample(
      target: fields.string('target'),
      native: fields.string('native'),
      reading: fields.optionalString('reading', allowEmpty: false),
      ipa: fields.optionalString('ipa', allowEmpty: false),
      bases: bases(fields.node('bases'), '$path.bases', core: false),
    );
  }

  /// Empty, meaning every applicable mode, when the card names none.
  Set<DrillMode> modes(YamlNode? node, String path) {
    if (node == null || _value(node) == null) return const <DrillMode>{};
    return Set.unmodifiable({
      for (final (i, item) in list(node, path, allowEmpty: true).indexed)
        mode(item, '$path[$i]'),
    });
  }

  DrillMode mode(YamlNode node, String path) {
    final name = text(node, path);
    final mode = DrillMode.tryParse(name);
    // Grammar understood is asked of a rules table's cells, which the
    // expander makes; a card cannot declare it (spec 4.7).
    if (mode == DrillMode.grammarUnderstood) {
      fail(node, "$path: grammarUnderstood is only for a rules table's cells");
    }
    // Only a reading deck's questions are read; a card has nothing to read.
    if (mode == null || mode == DrillMode.reading) {
      final modes = <String>[
        for (final m in DrillMode.values)
          if (m != DrillMode.reading && m != DrillMode.grammarUnderstood)
            m.name,
      ];
      fail(
        node,
        '$path: unknown mode "$name"; the modes are ${modes.join(', ')}',
      );
    }
    return mode;
  }

  // The B1 format's card fields (spec 3 to 8).

  /// A mark such as `phrasebook: true`: true, or left out. False is refused
  /// too, as the validator refuses it. [rule] says what it must be.
  bool mark(_Fields fields, String key, String path, String rule) {
    final node = fields.node(key);
    if (node == null) return false;
    if (_value(node) == true) return true;
    fail(node, '$path: $key must be $rule; got ${_describe(node)}');
  }

  /// A card's notes (spec 6.1): text, read as one note of kind `note`, or a
  /// list of typed notes, their placeholders filled. Blank text is no notes.
  List<CardNote> notes(YamlNode? node, String path) =>
      List<CardNote>.unmodifiable(<CardNote>[
        for (final note in noteItems(node, path, core: false))
          CardNote(
            id: note.id,
            kind: note.kind,
            text: _filled(note.text!, note.words),
            ref: note.ref,
            source: note.source,
            regions: note.regions,
          ),
      ]);

  /// A core card's notes (spec 6.2): each with its id and its language
  /// facts, its text being in each layer.
  List<CoreNote> coreNotes(YamlNode? node, String path) =>
      List<CoreNote>.unmodifiable(<CoreNote>[
        for (final note in noteItems(node, path, core: true))
          CoreNote(
            id: note.id,
            kind: note.kind,
            ref: note.ref,
            source: note.source,
            words: note.words,
            regions: note.regions,
          ),
      ]);

  List<_NoteItem> noteItems(YamlNode? node, String path, {required bool core}) {
    if (node == null || _value(node) == null) return const <_NoteItem>[];
    if (core && node is! YamlList) {
      fail(
        node,
        '$path must be a list of notes in a core file; their text is in each '
        'layer',
      );
    }
    if (node is YamlScalar) {
      final value = _value(node);
      if (value is! String) fail(node, _notText(node, path));
      // Today's validator accepts a blank note, which must not become one
      // empty note.
      if (_blank.hasMatch(value)) return const <_NoteItem>[];
      return <_NoteItem>[
        (
          id: '1',
          kind: NoteKind.note,
          text: value,
          ref: null,
          source: null,
          words: const <NoteWord>[],
          regions: const <String>[],
        ),
      ];
    }
    if (node is! YamlList) {
      fail(
        node,
        '$path must be text, or a list of notes, each with a kind and its '
        'text',
      );
    }
    if (node.nodes.isEmpty) {
      fail(node, '$path must not be an empty list; leave it out');
    }
    final ids = <String, YamlNode>{};
    return <_NoteItem>[
      for (final (i, item) in node.nodes.indexed)
        noteItem(item, '$path[$i]', i, ids, core: core),
    ];
  }

  _NoteItem noteItem(
    YamlNode node,
    String path,
    int index,
    Map<String, YamlNode> ids, {
    required bool core,
  }) {
    final fields = this.fields(node, path);
    fields.allowOnly(_noteFields);
    final kindNode = fields.require('kind');
    final kind = switch (_value(kindNode)) {
      'pair' => NoteKind.pair,
      'culture' => NoteKind.culture,
      'usage' => NoteKind.usage,
      'behaviour' => NoteKind.behaviour,
      'note' => NoteKind.note,
      _ => fail(
        kindNode,
        '$path.kind must be one of behaviour, culture, note, pair, usage, '
        'got ${_describe(kindNode)}',
      ),
    };

    final idNode = fields.node('id');
    final String id;
    if (idNode == null) {
      if (core) {
        fail(
          node,
          '$path.id is required in a core file: each layer names the note by '
          'it',
        );
      }
      // A note written without an id has its position: digits, which a
      // written id, starting with a letter, never is.
      id = '${index + 1}';
    } else {
      id = text(idNode, '$path.id');
      if (!_letterKey.hasMatch(id) || _yaml11Words.contains(id)) {
        fail(
          idNode,
          '$path.id must start with a letter and match [a-z0-9-]+, and not '
          'be a YAML 1.1 boolean word, got ${_describe(idNode)}',
        );
      }
      if (ids[id] case final first?) {
        fail(idNode, '$path.id "$id" is used twice, ${_firstUsed(first)}');
      }
      ids[id] = idNode;
    }

    String? noteText;
    final textNode = fields.node('text');
    if (core) {
      if (textNode != null) {
        fail(
          fields.keyNode('text'),
          "$path.text: a core note's text is in each layer, under "
          'cards.<id>.notes.$id',
        );
      }
    } else {
      noteText = text(fields.require('text'), '$path.text');
    }

    final refNode = fields.node('ref');
    String? ref;
    if (kind == NoteKind.pair) {
      ref = this.id(
        refNode ??
            fail(
              node,
              '$path.ref: a pair note names its partner, the id of another '
              '$lang card',
            ),
        '$path.ref',
      );
    } else if (refNode != null) {
      fail(fields.keyNode('ref'), '$path.ref is only for a pair note');
    }

    final String? source;
    if (kind == NoteKind.culture && !fields.has('source')) {
      fail(
        node,
        '$path.source: a culture note names where its claims can be checked',
      );
    }
    source = fields.has('source')
        ? text(fields.require('source'), '$path.source')
        : null;

    final words = noteWords(fields.node('words'), '$path.words');
    if (noteText != null) {
      placeholders(textNode!, noteText, words.length, '$path.text', 'note');
    }
    return (
      id: id,
      kind: kind,
      text: noteText,
      ref: ref,
      source: source,
      words: words,
      regions: noteRegions(fields.node('region'), '$path.region'),
    );
  }

  /// A region note's regions (spec 10.5): a region id, or a non-empty list
  /// of them. Whether each is a region of the language's path is the
  /// validator's to say.
  List<String> noteRegions(YamlNode? node, String path) {
    if (node == null) return const <String>[];
    final items = node is YamlList ? node.nodes : <YamlNode>[node];
    final regions = <String>[];
    for (final item in items) {
      final value = _value(item);
      if (value is! String ||
          !_letterKey.hasMatch(value) ||
          _yaml11Words.contains(value)) {
        fail(
          item,
          '$path must be a region id, or a list of them, such as '
          '"telangana", got ${_describe(node)}',
        );
      }
      if (regions.contains(value)) {
        fail(item, '$path lists "$value" twice');
      }
      regions.add(value);
    }
    if (regions.isEmpty) {
      fail(
        node,
        '$path must be a region id, or a list of them, such as "telangana", '
        'got ${_describe(node)}',
      );
    }
    return List<String>.unmodifiable(regions);
  }

  /// The language facts a note or a rule quotes: `{ word, reading, ipa? }`.
  List<NoteWord> noteWords(YamlNode? node, String path) {
    if (node == null || _value(node) == null) return const <NoteWord>[];
    if (node is! YamlList) {
      fail(node, '$path must be a list of { word, reading }');
    }
    return List<NoteWord>.unmodifiable(<NoteWord>[
      for (final (k, item) in node.nodes.indexed) noteWord(item, '$path[$k]'),
    ]);
  }

  NoteWord noteWord(YamlNode node, String path) {
    final fields = this.fields(node, path);
    fields.allowOnly(_noteWordFields);
    return NoteWord(
      word: fields.string('word'),
      reading: fields.optionalString('reading', allowEmpty: false),
      ipa: fields.optionalString('ipa', allowEmpty: false),
    );
  }

  /// Fails on a placeholder in [text] past its [count] words, and on a
  /// braced number that is not a placeholder, such as `{0}` or `{01}`
  /// (spec 6.4). [owner] is what has the words: a note or a rule.
  void placeholders(
    YamlNode node,
    String text,
    int count,
    String path,
    String owner,
  ) {
    for (final match in _bracedNumber.allMatches(text)) {
      final token = match[0]!;
      if (_placeholder.matchAsPrefix(token)?.end != token.length) {
        fail(
          node,
          '$path: $token is not a placeholder: placeholders count from {1}, '
          'without leading zeros',
        );
      }
      final n = int.tryParse(match[1]!);
      if (n == null || n > count) {
        fail(node, '$path uses $token, but the $owner has $count words');
      }
    }
  }

  /// A card's or an example's base words (spec 8.1). A [core] file gives a
  /// base written in full without its meaning, which is in each layer.
  List<CardBase> bases(YamlNode? node, String path, {required bool core}) {
    if (node == null || _value(node) == null) return const <CardBase>[];
    if (node is! YamlList) {
      fail(
        node,
        '$path must be a list of { word, ref } or { word, base, reading }',
      );
    }
    return List<CardBase>.unmodifiable(<CardBase>[
      for (final (i, item) in node.nodes.indexed)
        base(item, '$path[$i]', core: core),
    ]);
  }

  CardBase base(YamlNode node, String path, {required bool core}) {
    final fields = this.fields(node, path);
    fields.allowOnly(_baseFields);
    final word = fields.string('word');
    final byRef = fields.has('ref');
    final inFull = fields.has('base');
    if (byRef && inFull) fail(node, '$path gives ref or base, not both');
    if (!byRef && !inFull) {
      fail(node, '$path needs ref, or base and its reading');
    }
    if (byRef) {
      for (final key in const <String>[
        'reading',
        'ipa',
        'meaning',
        'wiktionary',
      ]) {
        if (fields.has(key)) {
          fail(
            fields.keyNode(key),
            '$path.$key is only for a base written in full',
          );
        }
      }
      return CardBase(word: word, ref: id(fields.require('ref'), '$path.ref'));
    }
    if (core) {
      for (final key in const <String>['meaning', 'wiktionary']) {
        if (fields.has(key)) {
          fail(
            fields.keyNode(key),
            "$path.$key: a core file's meanings are in each layer, under "
            'cards.<id>.bases',
          );
        }
      }
    } else if (!fields.has('meaning')) {
      fail(node, '$path.meaning is required beside base');
    }
    return CardBase(
      word: word,
      base: fields.string('base'),
      reading: fields.optionalString('reading', allowEmpty: false),
      ipa: fields.optionalString('ipa', allowEmpty: false),
      meaning: core ? null : fields.string('meaning'),
      wiktionary: !core && mark(fields, 'wiktionary', path, _wiktionaryRule),
    );
  }

  /// The rules a sentence uses, by rule id (spec 5).
  List<String> ruleIds(YamlNode? node, String path) {
    if (node == null || _value(node) == null) return const <String>[];
    if (node is! YamlList) {
      fail(
        node,
        '$path must be a list of rule ids, such as ["$lang-rule-past"]',
      );
    }
    final ids = <String>[];
    for (final (i, item) in node.nodes.indexed) {
      final id = text(item, '$path[$i]');
      if (!_ruleId(lang).hasMatch(id)) {
        fail(
          item,
          '$path[$i] must be a $lang rule id, $lang-rule- and a name, got '
          '"$id"',
        );
      }
      if (ids.contains(id)) fail(item, '$path lists "$id" twice');
      ids.add(id);
    }
    return List<String>.unmodifiable(ids);
  }

  /// The key of a mapping entry as text. A key YAML reads as anything else
  /// is refused, so that `1:` is never the number 1 (spec 2.6).
  String keyText(YamlNode key, String path) {
    final value = _value(key);
    if (value is String) return value;
    fail(
      key,
      '$path: key ${_pythonRepr(key)} was read as ${_pythonType(value)}; '
      'quote it',
    );
  }

  /// The entries of the mapping [node], each key read as text. [what] says
  /// what the mapping should be, for a node that is not one.
  List<(String, YamlNode, YamlNode)> keyed(
    YamlNode node,
    String path,
    String what,
  ) {
    if (node is! YamlMap) fail(node, '$path: $what');
    return <(String, YamlNode, YamlNode)>[
      for (final entry in node.nodes.entries)
        (
          keyText(entry.key as YamlNode, path),
          entry.key as YamlNode,
          entry.value,
        ),
    ];
  }

  // A core file (spec 2.2 to 2.5, 4.2).

  DeckCore core(YamlNode root) {
    final fields = top(root);
    final partNode = fields.node('part');
    final kindNode = fields.node('kind');
    if (kindNode != null && _value(kindNode) == 'layer') {
      fail(
        partNode ?? kindNode,
        'a layer has no part; only a core is marked part: "core"',
      );
    }
    if (partNode == null || _value(partNode) != 'core') {
      fail(
        partNode ?? fields.map,
        'a core file is marked part: "core"${partNode == null ? '' : ', got ${_describe(partNode)}'}',
      );
    }
    final kind = kindNode == null
        ? DeckKind.vocab
        : switch (_value(kindNode)) {
            'vocab' => DeckKind.vocab,
            'grammar' => DeckKind.grammar,
            'rules' => DeckKind.rules,
            'reading' => fail(
              kindNode,
              'a core is vocab, grammar or rules, got "reading"; a reading '
              'deck stays a single-file deck',
            ),
            _ => fail(
              kindNode,
              'a core is vocab, grammar or rules, got ${_describe(kindNode)}',
            ),
          };
    final language = this.language(
      fields.require('language'),
      'language',
      full: true,
    );
    lang = language.code;
    for (final (key, message) in <(String, String)>[
      (
        'native',
        'a core file has no native: the language it is taught from is in '
            'each layer, in decks/$lang/<native>/',
      ),
      (
        'name',
        "a core file's name is in each layer, in the learner's language",
      ),
      (
        'description',
        "a core file's description is in each layer, in the learner's "
            'language',
      ),
    ]) {
      if (fields.has(key)) fail(fields.keyNode(key), message);
    }
    fields.allowOnly(_coreHeaderFields);

    final idNode = fields.require('id');
    final id = this.id(idNode, 'id');
    if (!_coreId(lang).hasMatch(id)) {
      fail(
        idNode,
        'id must be $lang- and a name, the filename stem, got "$id"',
      );
    }
    final license = fields.string('license');
    final tags = fields.strings('tags');
    final authors = this.authors(fields.node('authors'));
    final coreSource = fields.optionalString('source');

    void refuse(String key, String message) {
      if (fields.has(key)) fail(fields.keyNode(key), message);
    }

    var cards = const <CoreCard>[];
    CorePattern? pattern;
    RuleTable? table;
    var rules = const <CoreRule>[];
    switch (kind) {
      case DeckKind.vocab:
        refuse(
          'pattern',
          'pattern is only for a grammar deck; add "kind: grammar" or remove '
              'it',
        );
        refuse('table', 'only a rules core has table');
        refuse('rules', 'only a rules core has rules');
        cards = coreCards(fields.require('cards'));
      case DeckKind.grammar:
        refuse('cards', 'a grammar deck has a pattern, not cards');
        refuse('table', 'only a rules core has table');
        refuse('rules', 'only a rules core has rules');
        pattern = corePattern(fields.require('pattern'));
      case DeckKind.rules:
        refuse('cards', 'a rules deck has a table and rules, not cards');
        refuse('pattern', 'a rules deck has a table and rules, not a pattern');
        refuse('theme', 'a rules deck has no theme');
        table = ruleTable(fields.require('table'));
        rules = coreRules(fields.require('rules'), table.slots);
      case DeckKind.reading:
        fail(kindNode!, 'a core is vocab, grammar or rules');
    }
    final theme = fields.has('theme')
        ? this.id(fields.require('theme'), 'theme')
        : null;

    return DeckCore(
      id: id,
      kind: kind,
      language: language,
      license: license,
      authors: authors,
      source: coreSource,
      tags: tags,
      theme: theme,
      cards: cards,
      pattern: pattern,
      table: table,
      rules: rules,
    );
  }

  /// A core's cards: each written, with the language side only, or listed
  /// by ref (spec 2.3).
  List<CoreCard> coreCards(YamlNode node) {
    final seen = <String, YamlNode>{};
    return List<CoreCard>.unmodifiable(<CoreCard>[
      for (final (i, item) in list(node, 'cards').indexed)
        if (item is YamlMap && item.nodes.containsKey('ref'))
          coreRef(item, 'cards[$i]', seen)
        else
          coreCard(item, 'cards[$i]', seen),
    ]);
  }

  /// [node]'s card id, failing if [seen] has it already.
  String cardId(YamlNode node, String path, Map<String, YamlNode> seen) {
    final id = this.id(node, path);
    final first = seen[id];
    if (first != null) {
      fail(
        node,
        '$path: card "$id" is already in the deck, ${_firstUsed(first)}',
      );
    }
    seen[id] = node;
    return id;
  }

  CoreWritten coreCard(YamlNode node, String path, Map<String, YamlNode> seen) {
    final fields = this.fields(node, path);
    final id = cardId(fields.require('id'), '$path.id', seen);
    for (final key in const <String>['native', 'alt_native', 'wiktionary']) {
      if (fields.has(key)) {
        fail(
          fields.keyNode(key),
          '$path: a core card\'s "$key" is in each layer, under cards.$id',
        );
      }
    }
    if (fields.has('pair')) {
      fail(
        fields.keyNode('pair'),
        '$path: pair: in a core file a pair note names the partner, '
        '{ kind: "pair", ref: ... }; Hear takes its sound-alike from there',
      );
    }
    fields.allowOnly(_coreCardFields);
    return CoreWritten(
      id: id,
      target: fields.string('target'),
      reading: fields.optionalString('reading', allowEmpty: false),
      ipa: fields.optionalString('ipa', allowEmpty: false),
      altTarget: fields.strings('alt_target'),
      pos: fields.optionalString('pos', allowEmpty: false),
      gender: fields.optionalString('gender'),
      tags: fields.strings('tags'),
      audio: fields.optionalString('audio'),
      examples: coreExamples(fields.node('examples'), '$path.examples'),
      modes: modes(fields.node('modes'), '$path.modes'),
      picture: fields.optionalString('picture', allowEmpty: false),
      notes: coreNotes(fields.node('notes'), '$path.notes'),
      phrasebook: mark(fields, 'phrasebook', path, _phrasebookRule),
      bases: bases(fields.node('bases'), '$path.bases', core: true),
      rules: ruleIds(fields.node('rules'), '$path.rules'),
    );
  }

  CoreRef coreRef(YamlNode node, String path, Map<String, YamlNode> seen) {
    final fields = this.fields(node, path);
    final id = cardId(fields.require('ref'), '$path.ref', seen);
    for (final key in const <String>['native', 'alt_native', 'wiktionary']) {
      if (fields.has(key)) {
        fail(
          fields.keyNode(key),
          '$path: a core card\'s "$key" is in each layer, under cards.$id',
        );
      }
    }
    fields.allowOnly(_coreRefFields);
    return CoreRef(
      id: id,
      reading: fields.optionalString('reading', allowEmpty: false),
      ipa: fields.optionalString('ipa', allowEmpty: false),
      tags: fields.has('tags') ? fields.strings('tags') : null,
      modes: fields.has('modes')
          ? modes(fields.node('modes'), '$path.modes')
          : null,
      examples: fields.has('examples')
          ? coreExamples(fields.node('examples'), '$path.examples')
          : null,
      notes: fields.has('notes')
          ? coreNotes(fields.node('notes'), '$path.notes')
          : null,
    );
  }

  /// A core card's examples, without their translations, which each layer
  /// gives keyed by the example's target: so no two targets are the same.
  List<CoreExample> coreExamples(YamlNode? node, String path) {
    if (node == null || _value(node) == null) return const <CoreExample>[];
    final targets = <String, int>{};
    final examples = <CoreExample>[];
    for (final (j, item) in list(node, path, allowEmpty: true).indexed) {
      final where = '$path[$j]';
      final fields = this.fields(item, where);
      if (fields.has('native')) {
        fail(
          fields.keyNode('native'),
          "$where: a core example's translation is in each layer, keyed by "
          'its target',
        );
      }
      fields.allowOnly(_coreExampleFields);
      final targetNode = fields.require('target');
      final target = text(targetNode, '$where.target');
      if (targets[target] case final k?) {
        fail(
          targetNode,
          '$where has the same target as $path[$k]; a layer names an example '
          'by its target',
        );
      }
      targets[target] = j;
      examples.add(
        CoreExample(
          target: target,
          reading: fields.optionalString('reading', allowEmpty: false),
          ipa: fields.optionalString('ipa', allowEmpty: false),
          bases: bases(fields.node('bases'), '$where.bases', core: true),
        ),
      );
    }
    return List<CoreExample>.unmodifiable(examples);
  }

  /// A grammar core's pattern: its slots and its entries' forms, without
  /// the names, prompt, notes and glosses, which each layer gives.
  CorePattern corePattern(YamlNode node) {
    final fields = this.fields(node, 'pattern');
    for (final key in const <String>['name', 'slot_name', 'prompt', 'notes']) {
      if (fields.has(key)) {
        fail(
          fields.keyNode(key),
          'pattern: a core pattern\'s "$key" is in each layer, under pattern',
        );
      }
    }
    fields.allowOnly(const {'slots', 'entries'});
    final slots = this.slots(fields.require('slots'));
    final lemmas = <String, YamlNode>{};
    final keys = <String, YamlNode>{};
    return CorePattern(
      slots: slots,
      entries: List<PatternEntry>.unmodifiable(<PatternEntry>[
        for (final (i, item) in list(
          fields.require('entries'),
          'pattern.entries',
        ).indexed)
          entry(item, 'pattern.entries[$i]', slots, lemmas, keys, core: true),
      ]),
    );
  }

  /// A rules core's table (spec 4.2): which words are its rows, its slots,
  /// and each row's forms. Its labels are each layer's.
  RuleTable ruleTable(YamlNode node) {
    final fields = this.fields(node, 'table');
    keyed(node, 'table', 'must be a mapping');
    fields.allowOnly(_tableFields);
    final appliesTo = this.appliesTo(fields.require('applies_to'));
    final slots = slotKeys(fields.require('slots'));
    final words = <String, YamlNode>{};
    final parts = <String, YamlNode>{};
    return RuleTable(
      appliesTo: appliesTo,
      slots: slots,
      slotName: '',
      labels: const <String, String>{},
      rows: List<RuleRow>.unmodifiable(<RuleRow>[
        for (final (i, item) in list(
          fields.require('rows'),
          'table.rows',
        ).indexed)
          ruleRow(item, 'table.rows[$i]', slots, words, parts),
      ]),
    );
  }

  AppliesTo appliesTo(YamlNode node) {
    final fields = this.fields(node, 'table.applies_to');
    keyed(node, 'table.applies_to', 'must be a mapping');
    fields.allowOnly(_appliesToFields);
    final posNode = fields.require('pos');
    final pos = fields.strings('pos');
    if (pos.isEmpty) {
      fail(
        posNode,
        'table.applies_to.pos must be a non-empty list of parts of speech',
      );
    }
    final exceptNode = fields.node('except');
    return AppliesTo(
      pos: pos,
      tags: fields.strings('tags'),
      except: Set<String>.unmodifiable(<String>{
        if (exceptNode != null && _value(exceptNode) != null)
          for (final (i, item) in list(
            exceptNode,
            'table.applies_to.except',
            allowEmpty: true,
          ).indexed)
            id(item, 'table.applies_to.except[$i]'),
      }),
    );
  }

  /// A rules table's slot keys, in order: each starts with a letter, so it
  /// is never a number, and is not a YAML 1.1 boolean word.
  List<String> slotKeys(YamlNode node) {
    final slots = <String>[];
    for (final (i, item) in list(node, 'table.slots').indexed) {
      final slot = text(item, 'table.slots[$i]');
      if (!_letterKey.hasMatch(slot) || _yaml11Words.contains(slot)) {
        fail(
          item,
          'table.slots[$i] must start with a letter and match [a-z0-9-]+, and '
          'not be a YAML 1.1 boolean word, got "$slot"',
        );
      }
      if (slots.contains(slot)) {
        fail(item, 'table.slots contains duplicates: "$slot"');
      }
      slots.add(slot);
    }
    return List<String>.unmodifiable(slots);
  }

  RuleRow ruleRow(
    YamlNode node,
    String path,
    List<String> slots,
    Map<String, YamlNode> words,
    Map<String, YamlNode> parts,
  ) {
    final fields = this.fields(node, path);
    keyed(node, path, 'must be a mapping');
    fields.allowOnly(_rowFields);
    final wordNode = fields.require('word');
    final word = id(wordNode, '$path.word');
    final where = 'table.rows[$word]';
    if (words[word] case final first?) {
      fail(wordNode, '$where: $word has a row already, ${_firstUsed(first)}');
    }
    words[word] = wordNode;
    final keyNode = fields.node('key');
    final key = keyNode == null ? null : id(keyNode, '$where.key');
    final part = key ?? word.substring(word.lastIndexOf('-') + 1);
    if (parts[part] != null) {
      fail(
        keyNode ?? wordNode,
        '$where: "$part" already names another row; give one of them a key',
      );
    }
    parts[part] = keyNode ?? wordNode;
    final (:forms, :alternatives) = this.forms(
      fields.require('forms'),
      '$where.forms',
      slots,
    );
    return RuleRow(
      word: word,
      key: key,
      forms: forms,
      alternatives: alternatives,
      readings: fields.has('readings')
          ? readings(fields.require('readings'), '$where.readings', forms)
          : const <String, List<String>>{},
      ipas: fields.has('ipas')
          ? ipas(fields.require('ipas'), '$where.ipas', forms)
          : const <String, String>{},
    );
  }

  /// A rules core's rules: each owns one or more of the table's slots, and
  /// every slot belongs to exactly one rule.
  List<CoreRule> coreRules(YamlNode node, List<String> slots) {
    final owner = <String, String>{};
    final ids = <String, YamlNode>{};
    final rules = <CoreRule>[];
    for (final (i, item) in list(node, 'rules').indexed) {
      final path = 'rules[$i]';
      final fields = this.fields(item, path);
      keyed(item, path, 'must be a mapping');
      fields.allowOnly(_ruleFields);
      final idNode = fields.require('id');
      final id = text(idNode, '$path.id');
      if (!_ruleId(lang).hasMatch(id)) {
        fail(
          idNode,
          '$path: id must be $lang-rule- and a name, such as $lang-rule-past, '
          'got "$id"',
        );
      }
      if (ids[id] case final first?) {
        fail(idNode, 'rule $id: duplicate rule id, ${_firstUsed(first)}');
      }
      ids[id] = idNode;
      final slotsNode = fields.require('slots');
      if (slotsNode is! YamlList || slotsNode.nodes.isEmpty) {
        fail(
          slotsNode,
          "rule $id: slots must be a non-empty list of the table's slots",
        );
      }
      final own = <String>[];
      for (final (k, item) in slotsNode.nodes.indexed) {
        final slot = text(item, 'rule $id: slots[$k]');
        if (!slots.contains(slot)) {
          fail(item, 'rule $id: "$slot" is not a slot of the table');
        }
        if (owner[slot] case final other?) {
          fail(
            item,
            'rule $id: "$slot" is also in rule $other; a slot belongs to one '
            'rule',
          );
        }
        owner[slot] = id;
        own.add(slot);
      }
      rules.add(
        CoreRule(
          id: id,
          slots: List<String>.unmodifiable(own),
          words: noteWords(fields.node('words'), 'rule $id: words'),
        ),
      );
    }
    for (final slot in slots) {
      if (!owner.containsKey(slot)) {
        fail(node, 'table.slots: "$slot" belongs to no rule');
      }
    }
    return List<CoreRule>.unmodifiable(rules);
  }

  // A layer (spec 2.6, 4.5).

  DeckLayer layer(YamlNode root) {
    final fields = top(root);
    final kindNode = fields.require('kind');
    if (_value(kindNode) != 'layer') {
      fail(
        kindNode,
        'a layer is marked kind: "layer", got ${_describe(kindNode)}',
      );
    }
    final coreNode = fields.require('core');
    final core = text(coreNode, 'core');
    if (!_idPattern.hasMatch(core)) {
      fail(
        coreNode,
        "core must be the id of a core file, such as 'te-home', got \"$core\"",
      );
    }
    for (final (key, message) in <(String, String)>[
      ('language', 'a layer takes its language from its core, $core'),
      ('theme', 'a layer takes its theme from its core, $core'),
      ('part', 'a layer has no part; only a core is marked part: "core"'),
    ]) {
      if (fields.has(key)) fail(fields.keyNode(key), message);
    }
    fields.allowOnly(_layerHeaderFields);

    final idNode = fields.require('id');
    final id = this.id(idNode, 'id');
    // A layer has no language block: its id starts with the language's
    // code, which merging checks against the core's.
    lang = id.split('-').first;
    final native = language(fields.require('native'), 'native', full: false);
    final name = fields.string('name');
    final license = fields.string('license');
    return DeckLayer(
      id: id,
      core: core,
      native: native,
      name: name,
      description: fields.optionalString('description'),
      license: license,
      authors: authors(fields.node('authors')),
      source: fields.optionalString('source'),
      tags: fields.strings('tags'),
      cards: fields.has('cards')
          ? layerCards(fields.require('cards'), id)
          : const <String, LayerCard>{},
      pattern: fields.has('pattern')
          ? layerPattern(fields.require('pattern'))
          : null,
      table: fields.has('table') ? layerTable(fields.require('table')) : null,
      rules: fields.has('rules')
          ? layerRules(fields.require('rules'))
          : const <String, LayerRule>{},
      node: fields.map,
      idNode: idNode,
      coreNode: coreNode,
    );
  }

  /// A layer's cards, by id: what this language gives each card of the
  /// core, or, for an entry with a target, a card only this layer has.
  Map<String, LayerCard> layerCards(YamlNode node, String deckId) {
    final cards = <String, LayerCard>{};
    for (final (id, key, value) in keyed(
      node,
      'cards',
      "a layer's cards is a mapping of card id to what this language gives it",
    )) {
      final path = 'cards.$id';
      this.id(key, path);
      cards[id] = value is YamlMap && value.nodes.containsKey('target')
          ? LayerOnlyCard(
              card: card(value, path, deckId, <String, YamlNode>{}, key: key),
              key: key,
            )
          : layerEntry(value, path, key);
    }
    return Map<String, LayerCard>.unmodifiable(cards);
  }

  LayerEntry layerEntry(YamlNode node, String path, YamlNode key) {
    final fields = this.fields(node, path);
    for (final (name, at, _) in keyed(node, path, 'must be a mapping')) {
      if (!_layerEntryFields.contains(name)) {
        fail(
          at,
          '$path: "$name" belongs to the word, in the core; a layer gives '
          'native, alt_native, notes, examples, bases and wiktionary',
        );
      }
    }
    return LayerEntry(
      native: fields.has('native') ? fields.string('native') : null,
      altNative: fields.has('alt_native') ? fields.strings('alt_native') : null,
      notes: fields.has('notes')
          ? layerTexts(
              fields.require('notes'),
              '$path.notes',
              "a mapping of the core note's id to its text",
            )
          : null,
      examples: fields.has('examples')
          ? layerExamples(fields.require('examples'), '$path.examples')
          : null,
      bases: fields.has('bases')
          ? layerBases(fields.require('bases'), '$path.bases')
          : null,
      wiktionary: mark(fields, 'wiktionary', path, _wiktionaryRule)
          ? true
          : null,
      key: key,
    );
  }

  /// A mapping of keys to text in the learner's language.
  Map<String, LayerText> layerTexts(YamlNode node, String path, String what) =>
      Map<String, LayerText>.unmodifiable(<String, LayerText>{
        for (final (name, key, value) in keyed(node, path, what))
          name: LayerText(
            text: text(value, '$path.$name'),
            key: key,
            node: value,
          ),
      });

  Map<String, LayerExample> layerExamples(YamlNode node, String path) {
    final examples = <String, LayerExample>{};
    for (final (target, key, value) in keyed(
      node,
      path,
      "a mapping of an example's target, as the core writes it, to its "
      'translation',
    )) {
      final where = '$path.$target';
      if (value is YamlMap) {
        final fields = this.fields(value, where);
        fields.allowOnly(const {'native', 'bases'});
        examples[target] = LayerExample(
          native: fields.string('native'),
          bases: fields.has('bases')
              ? layerBases(fields.require('bases'), '$where.bases')
              : const <String, LayerBase>{},
          key: key,
        );
      } else {
        examples[target] = LayerExample(native: text(value, where), key: key);
      }
    }
    return Map<String, LayerExample>.unmodifiable(examples);
  }

  /// An inline base's meaning, by its word: text, or `{ meaning,
  /// wiktionary }`.
  Map<String, LayerBase> layerBases(YamlNode node, String path) {
    final bases = <String, LayerBase>{};
    for (final (word, key, value) in keyed(
      node,
      path,
      "a mapping of an inline base's word to its meaning",
    )) {
      final where = '$path.$word';
      if (value is YamlMap) {
        final fields = this.fields(value, where);
        fields.allowOnly(const {'meaning', 'wiktionary'});
        bases[word] = LayerBase(
          meaning: fields.string('meaning'),
          wiktionary: mark(fields, 'wiktionary', where, _wiktionaryRule),
          key: key,
        );
      } else {
        bases[word] = LayerBase(meaning: text(value, where), key: key);
      }
    }
    return Map<String, LayerBase>.unmodifiable(bases);
  }

  LayerPattern layerPattern(YamlNode node) {
    final fields = this.fields(node, 'pattern');
    keyed(node, 'pattern', 'must be a mapping');
    fields.allowOnly(_patternFields);
    return LayerPattern(
      name: fields.string('name'),
      slotName: fields.string('slot_name'),
      prompt: fields.string('prompt'),
      slots: fields.has('slots')
          ? layerTexts(
              fields.require('slots'),
              'pattern.slots',
              'a mapping of a slot of the core to its label',
            )
          : const <String, LayerText>{},
      entries: layerTexts(
        fields.require('entries'),
        'pattern.entries',
        "a mapping of each core entry's id part to its gloss",
      ),
      notes: fields.optionalString('notes'),
    );
  }

  LayerTable layerTable(YamlNode node) {
    final fields = this.fields(node, 'table');
    keyed(node, 'table', 'must be a mapping');
    fields.allowOnly(const {'slot_name', 'slots', 'prompts'});
    final promptsNode = fields.node('prompts');
    return LayerTable(
      slotName: fields.string('slot_name'),
      labels: layerTexts(
        fields.require('slots'),
        'table.slots',
        'a mapping of each slot of the core to its label',
      ),
      prompts: promptsNode == null
          ? const <String, LayerPrompts>{}
          : Map<String, LayerPrompts>.unmodifiable(<String, LayerPrompts>{
              for (final (word, key, value) in keyed(
                promptsNode,
                'table.prompts',
                "a mapping of a row's word to its prompts, by slot",
              ))
                word: LayerPrompts(
                  texts: layerTexts(
                    value,
                    'table.prompts.$word',
                    'a mapping of a slot to its prompt',
                  ),
                  key: key,
                ),
            }),
    );
  }

  Map<String, LayerRule> layerRules(YamlNode node) {
    final rules = <String, LayerRule>{};
    for (final (id, key, value) in keyed(
      node,
      'rules',
      'a mapping of each rule id to its name and explanation',
    )) {
      final where = 'rules.$id';
      final fields = this.fields(value, where);
      fields.allowOnly(const {'name', 'explanation'});
      final explanation = fields.require('explanation');
      rules[id] = LayerRule(
        name: fields.string('name'),
        explanation: text(explanation, '$where.explanation'),
        key: key,
        node: explanation,
      );
    }
    return Map<String, LayerRule>.unmodifiable(rules);
  }

  /// A reading deck's passages. Passage and question ids share one
  /// namespace, and each must be new: a question id keys its review history.
  List<Passage> passages(YamlNode node) {
    final seen = <String, YamlNode>{};
    return List.unmodifiable([
      for (final (i, item) in list(node, 'passages').indexed)
        passage(item, 'passages[$i]', seen),
    ]);
  }

  /// A passage or question id, failing if [seen] has it already.
  String newId(YamlNode node, String path, Map<String, YamlNode> seen) {
    final id = this.id(node, path);
    final first = seen[id];
    if (first != null) {
      fail(node, '$path: duplicate id "$id", ${_firstUsed(first)}');
    }
    seen[id] = node;
    return id;
  }

  Passage passage(YamlNode node, String path, Map<String, YamlNode> seen) {
    final fields = this.fields(node, path);
    fields.allowOnly(_passageFields);
    final id = newId(fields.require('id'), '$path.id', seen);
    final title = fields.string('title');
    final sentences = [
      for (final (i, item) in list(
        fields.require('sentences'),
        '$path.sentences',
      ).indexed)
        sentence(item, '$path.sentences[$i]'),
    ];
    final source = fields.optionalString('source', allowEmpty: false);
    final theme = fields.has('theme')
        ? this.id(fields.require('theme'), '$path.theme')
        : null;
    final questions = [
      for (final (i, item) in list(
        fields.require('questions'),
        '$path.questions',
      ).indexed)
        question(item, '$path.questions[$i]', seen),
    ];
    final glossaryNode = fields.node('glossary');
    final glossary = glossaryNode == null || _value(glossaryNode) == null
        ? const <GlossEntry>[]
        : [
            for (final (i, item) in list(
              glossaryNode,
              '$path.glossary',
              allowEmpty: true,
            ).indexed)
              gloss(item, '$path.glossary[$i]', sentences),
          ];
    return Passage(
      id: id,
      title: title,
      sentences: List.unmodifiable(sentences),
      questions: List.unmodifiable(questions),
      source: source,
      theme: theme,
      glossary: List.unmodifiable(glossary),
    );
  }

  /// One glossary entry. Its word must occur in the passage exactly as
  /// written, and like the passage, nothing in it is trimmed or normalised.
  GlossEntry gloss(
    YamlNode node,
    String path,
    List<PassageSentence> sentences,
  ) {
    final fields = this.fields(node, path);
    fields.allowOnly(_glossFields);
    final wordNode = fields.require('word');
    final word = text(wordNode, '$path.word');
    if (!sentences.any((s) => s.text.contains(word))) {
      fail(
        wordNode,
        '$path.word: "$word" does not occur in the passage, letter for letter',
      );
    }
    final noteNode = fields.node('note');
    return GlossEntry(
      word: word,
      modern: fields.string('modern'),
      reading: fields.optionalString('reading', allowEmpty: false),
      ipa: fields.optionalString('ipa', allowEmpty: false),
      meaning: byLanguage(fields.require('meaning'), '$path.meaning'),
      note: noteNode == null || _value(noteNode) == null
          ? const <String, String>{}
          : byLanguage(noteNode, '$path.note'),
    );
  }

  /// One sentence. Its text is kept exactly as written, a quotation that
  /// must stay letter for letter: [text] neither trims nor normalises it.
  PassageSentence sentence(YamlNode node, String path) {
    final fields = this.fields(node, path);
    fields.allowOnly(_sentenceFields);
    return PassageSentence(
      text: fields.string('text'),
      reading: fields.optionalString('reading', allowEmpty: false),
      ipa: fields.optionalString('ipa', allowEmpty: false),
    );
  }

  ReadingQuestion question(
    YamlNode node,
    String path,
    Map<String, YamlNode> seen,
  ) {
    final fields = this.fields(node, path);
    fields.allowOnly(_questionFields);
    final id = newId(fields.require('id'), '$path.id', seen);
    final prompt = byLanguage(fields.require('prompt'), '$path.prompt');
    final optionsNode = fields.node('options');
    final options = optionsNode == null
        ? const <Map<String, String>>[]
        : [
            for (final (i, item) in list(optionsNode, '$path.options').indexed)
              byLanguage(item, '$path.options[$i]'),
          ];
    if (optionsNode != null && (options.length < 2 || options.length > 4)) {
      fail(optionsNode, '$path.options: a question has 2 to 4 options');
    }
    final answerNode = fields.require('answer');
    final answer = _value(answerNode);
    final int index;
    if (options.isEmpty) {
      if (answer is! bool) {
        fail(
          answerNode,
          '$path.answer: a question without options is true or false, so '
          'its answer is true or false, got ${_describe(answerNode)}',
        );
      }
      index = answer ? 0 : 1;
    } else {
      if (answer is! int || answer < 1 || answer > options.length) {
        fail(
          answerNode,
          '$path.answer: the number of the right option, from 1 to '
          '${options.length}, got ${_describe(answerNode)}',
        );
      }
      index = answer - 1;
    }
    return ReadingQuestion(
      id: id,
      prompt: prompt,
      options: List.unmodifiable(options),
      answer: index,
    );
  }

  /// Text keyed by language code, as a fact's is: `{ en: ..., bn: ... }`.
  /// English is required, so that every learner can be shown it.
  Map<String, String> byLanguage(YamlNode node, String path) {
    final map = fields(node, path).map;
    final texts = <String, String>{};
    for (final entry in map.nodes.entries) {
      final key = entry.key as YamlNode;
      final code = _value(key);
      if (code is bool || _isNumber(code)) {
        fail(key, _notText(key, 'the key ${_plainText(key)} in $path'));
      }
      if (code is! String || !_languageCode.hasMatch(code)) {
        fail(key, '$path: ${_describe(key)} is not a language code like "en"');
      }
      texts[code] = text(entry.value, '$path.$code');
    }
    if (!texts.containsKey('en')) {
      fail(node, '$path: missing "en"; English is required');
    }
    return Map.unmodifiable(texts);
  }

  GrammarPattern pattern(YamlNode node) {
    final fields = this.fields(node, 'pattern');
    fields.allowOnly(_patternFields);
    final name = fields.string('name');
    final slotName = fields.string('slot_name');
    final prompt = fields.string('prompt');
    final notes = fields.optionalString('notes');
    final slots = this.slots(fields.require('slots'));

    final lemmas = <String, YamlNode>{};
    final keys = <String, YamlNode>{};
    final entries = [
      for (final (i, item) in list(
        fields.require('entries'),
        'pattern.entries',
      ).indexed)
        entry(item, 'pattern.entries[$i]', slots, lemmas, keys),
    ];

    return GrammarPattern(
      name: name,
      slotName: slotName,
      slots: slots,
      prompt: prompt,
      entries: List.unmodifiable(entries),
      notes: notes,
    );
  }

  /// The slot labels, in order. An expanded card's id includes its slot's
  /// index, so the order is kept exactly as written.
  List<String> slots(YamlNode node) {
    final slots = <String>[];
    for (final (i, item) in list(node, 'pattern.slots').indexed) {
      final slot = text(item, 'pattern.slots[$i]');
      if (slots.contains(slot)) {
        fail(item, 'pattern.slots[$i]: duplicate slot "$slot"');
      }
      slots.add(slot);
    }
    return List.unmodifiable(slots);
  }

  /// One pattern row. [lemmas] and [keys] map each lemma and id part so far
  /// to where it was declared: the id part, the row's `key` or else its
  /// lemma, is in every expanded card id in its row.
  ///
  /// A [core] pattern's entry has no gloss: each layer gives it, keyed by
  /// the entry's id part, and until then it is empty.
  PatternEntry entry(
    YamlNode node,
    String path,
    List<String> slots,
    Map<String, YamlNode> lemmas,
    Map<String, YamlNode> keys, {
    bool core = false,
  }) {
    final fields = this.fields(node, path);
    fields.allowOnly(_entryFields);

    final lemmaNode = fields.require('lemma');
    final lemma = text(lemmaNode, '$path.lemma');
    final first = lemmas[lemma];
    if (first != null) {
      fail(
        lemmaNode,
        '$path.lemma: duplicate lemma "$lemma", ${_firstUsed(first)}',
      );
    }
    lemmas[lemma] = lemmaNode;

    // A card id is ASCII (AGENTS.md rule 1), so a lemma that cannot go into
    // one, like जाना, names its row with a key instead.
    final keyNode = fields.node('key');
    final String? key;
    final YamlNode idNode;
    if (keyNode != null) {
      key = id(keyNode, '$path.key');
      idNode = keyNode;
    } else {
      if (!_idPattern.hasMatch(lemma)) {
        fail(
          lemmaNode,
          '$path: the lemma "$lemma" cannot go into a card id; give the '
          'entry a key of lowercase letters and digits, like "jaanaa"',
        );
      }
      key = null;
      idNode = lemmaNode;
    }
    final idPart = key ?? lemma;
    final clash = keys[idPart];
    if (clash != null) {
      fail(
        idNode,
        '$path: "$idPart" already names a row, ${_firstUsed(clash)}',
      );
    }
    keys[idPart] = idNode;
    if (core && fields.has('gloss')) {
      fail(
        fields.keyNode('gloss'),
        "$path: a core entry's gloss is in each layer, under "
        'pattern.entries.$idPart',
      );
    }

    final (:forms, :alternatives) = this.forms(
      fields.require('forms'),
      '$path.forms',
      slots,
    );
    return PatternEntry(
      lemma: lemma,
      key: key,
      gloss: core ? '' : fields.string('gloss'),
      forms: forms,
      alternatives: alternatives,
      reading: fields.has('reading')
          ? text(fields.require('reading'), '$path.reading')
          : null,
      readings: fields.has('readings')
          ? readings(fields.require('readings'), '$path.readings', forms)
          : const <String, List<String>>{},
      ipa: fields.has('ipa') ? text(fields.require('ipa'), '$path.ipa') : null,
      ipas: fields.has('ipas')
          ? ipas(fields.require('ipas'), '$path.ipas', forms)
          : const <String, String>{},
    );
  }

  /// Each form romanised (#47): a reading or a list of them for every slot
  /// with a form, and none for a slot without: left out, or null.
  Map<String, List<String>> readings(
    YamlNode node,
    String path,
    Map<String, String?> forms,
  ) {
    final map = fields(node, path).map;
    final found = <String, List<String>>{};
    for (final entry in map.nodes.entries) {
      final key = entry.key as YamlNode;
      final slot = _value(key);
      if (slot is! String || !forms.containsKey(slot)) {
        fail(key, '$path: ${_describe(key)} is not a slot');
      }
      final value = entry.value;
      if (forms[slot] == null) {
        // A null reading under a null form is a reading left out, as the
        // validator reads it (spec 4.2).
        if (value is YamlScalar && _value(value) == null) continue;
        fail(key, '$path: "$slot" has no form, so it has no reading');
      }
      found[slot] = value is YamlList
          ? List.unmodifiable(<String>[
              for (final (i, item) in list(value, '$path.$slot').indexed)
                text(item, '$path.$slot[$i]'),
            ])
          : List.unmodifiable(<String>[text(value, '$path.$slot')]);
    }
    final missing = [
      for (final MapEntry(key: slot, value: form) in forms.entries)
        if (form != null && !found.containsKey(slot)) '"$slot"',
    ];
    if (missing.isNotEmpty) {
      fail(node, '$path: no reading for ${missing.join(', ')}');
    }
    return Map.unmodifiable(found);
  }

  /// The form shown in each slot, in the IPA (ADR-0025): one for every slot
  /// with a form, and none for a slot without: left out, or null.
  Map<String, String> ipas(
    YamlNode node,
    String path,
    Map<String, String?> forms,
  ) {
    final map = fields(node, path).map;
    final found = <String, String>{};
    for (final entry in map.nodes.entries) {
      final key = entry.key as YamlNode;
      final slot = _value(key);
      if (slot is! String || !forms.containsKey(slot)) {
        fail(key, '$path: ${_describe(key)} is not a slot');
      }
      if (forms[slot] == null) {
        // As a null reading under a null form: left out.
        if (entry.value is YamlScalar && _value(entry.value) == null) continue;
        fail(key, '$path: "$slot" has no form, so it has no IPA');
      }
      found[slot] = text(entry.value, '$path.$slot');
    }
    final missing = [
      for (final MapEntry(key: slot, value: form) in forms.entries)
        if (form != null && !found.containsKey(slot)) '"$slot"',
    ];
    if (missing.isNotEmpty) {
      fail(node, '$path: no IPA for ${missing.join(', ')}');
    }
    return Map.unmodifiable(found);
  }

  /// One form per slot, in slot order, and the other forms accepted for a
  /// slot whose cell lists several (#144). A null form is a cell with no
  /// valid form, and is kept so that the expander can skip it.
  ({Map<String, String?> forms, Map<String, List<String>> alternatives}) forms(
    YamlNode node,
    String path,
    List<String> slots,
  ) {
    final map = fields(node, path).map;
    final found = <String, String?>{};
    final alternatives = <String, List<String>>{};
    for (final entry in map.nodes.entries) {
      final key = entry.key as YamlNode;
      final slot = _value(key);
      if (slot is bool || _isNumber(slot)) {
        fail(key, _notText(key, 'the key ${_plainText(key)} in $path'));
      }
      if (slot is! String || !slots.contains(slot)) {
        fail(
          key,
          '$path: ${_describe(key)} is not a slot; the slots are '
          '${slots.join(', ')}',
        );
      }
      final value = entry.value;
      if (value is YamlList) {
        final listed = [
          for (final (i, item) in list(value, '$path.$slot').indexed)
            text(item, '$path.$slot[$i]'),
        ];
        if (listed.toSet().length != listed.length) {
          fail(value, '$path.$slot lists a form twice');
        }
        found[slot] = listed.first;
        if (listed.length > 1) {
          alternatives[slot] = List.unmodifiable(listed.skip(1));
        }
      } else {
        found[slot] = _value(value) == null ? null : text(value, '$path.$slot');
      }
    }

    final missing = [
      for (final slot in slots)
        if (!found.containsKey(slot)) '"$slot"',
    ];
    if (missing.isNotEmpty) {
      fail(
        node,
        '$path: missing ${missing.length == 1 ? 'slot' : 'slots'} '
        '${missing.join(', ')}',
      );
    }
    if (found.values.every((form) => form == null)) {
      fail(node, '$path: every form is null, so there is nothing to drill');
    }
    return (
      forms: Map.unmodifiable({for (final slot in slots) slot: found[slot]}),
      alternatives: Map.unmodifiable(alternatives),
    );
  }
}

/// One mapping in the deck, named by its [path] in messages.
class _Fields {
  _Fields(this.reader, this.map, this.path);

  final _Reader reader;
  final YamlMap map;

  /// Where [map] is, like `cards[3]`. Empty for the top level of the deck.
  final String path;

  String _name(String key) => path.isEmpty ? key : '$path.$key';

  String get _prefix => path.isEmpty ? '' : '$path: ';

  bool has(String key) => map.nodes.containsKey(key);

  YamlNode? node(String key) => map.nodes[key];

  YamlNode keyNode(String key) =>
      map.nodes.keys.cast<YamlNode>().firstWhere((k) => k.value == key);

  /// Fails on the first key that is not one of [allowed].
  void allowOnly(Set<String> allowed) {
    for (final key in map.nodes.keys.cast<YamlNode>()) {
      final name = _value(key);
      if (name is! String || !allowed.contains(name)) {
        reader.fail(key, '${_prefix}unknown field ${_describe(key)}');
      }
    }
  }

  /// The value of [key], failing at this mapping if there is no such key.
  YamlNode require(String key) =>
      map.nodes[key] ??
      reader.fail(map, '${_prefix}missing required field "$key"');

  /// A required, non-blank text field.
  String string(String key) => reader.text(require(key), _name(key));

  /// An optional text field, null when absent or empty in the YAML.
  String? optionalString(String key, {bool allowEmpty = true}) {
    final node = map.nodes[key];
    if (node == null || _value(node) == null) return null;
    return reader.text(node, _name(key), allowEmpty: allowEmpty);
  }

  /// An optional list of non-blank text, empty when absent.
  List<String> strings(String key) {
    final node = map.nodes[key];
    if (node == null) return const <String>[];
    final name = _name(key);
    return List.unmodifiable([
      for (final (i, item) in reader.list(node, name, allowEmpty: true).indexed)
        reader.text(item, '$name[$i]'),
    ]);
  }

  bool? optionalBool(String key) {
    final node = map.nodes[key];
    if (node == null) return null;
    final value = _value(node);
    if (value is bool) return value;
    reader.fail(
      node,
      '${_name(key)} must be true or false, got ${_describe(node)}',
    );
  }
}

/// A note as read, before it becomes a [CardNote] or a [CoreNote]: [text] is
/// null in a core.
typedef _NoteItem = ({
  String id,
  NoteKind kind,
  String? text,
  String? ref,
  String? source,
  List<NoteWord> words,
  List<String> regions,
});

const _phrasebookRule = 'true, unquoted, or left out';
const _wiktionaryRule = 'true, or left out where Wiktionary has no entry';

/// [text] with each placeholder replaced by the word it counts to, shown
/// with its reading (spec 6.4). One past [words] stays as written; the
/// reader refuses it first.
String _filled(String text, List<NoteWord> words) =>
    text.replaceAllMapped(_placeholder, (m) {
      final n = int.tryParse(m[1]!);
      return n != null && n <= words.length ? words[n - 1].shown : m[0]!;
    });

/// A rule id of the language [lang]: `te-rule-lo`.
RegExp _ruleId(String lang) =>
    RegExp('^${RegExp.escape(lang)}-rule-[a-z0-9]+(?:-[a-z0-9]+)*\$');

/// A core id of the language [lang]: `te-home`.
RegExp _coreId(String lang) =>
    RegExp('^${RegExp.escape(lang)}-[a-z0-9]+(?:-[a-z0-9]+)*\$');

/// How Python, and so the validator, writes [key]'s value: `True`, `1`.
String _pythonRepr(YamlNode key) => switch (_value(key)) {
  true => 'True',
  false => 'False',
  null => 'None',
  final int value => '$value',
  final BigInt value => '$value',
  final double value when value.isNaN => 'nan',
  final double value when value.isInfinite => value > 0 ? 'inf' : '-inf',
  final double value => '$value',
  _ => _plainText(key),
};

/// The name Python gives [value]'s type, as the validator says it.
String _pythonType(Object? value) => switch (value) {
  bool() => 'bool',
  int() || BigInt() => 'int',
  double() => 'float',
  null => 'NoneType',
  Map() => 'dict',
  List() => 'list',
  _ => value.runtimeType.toString(),
};

/// What [node] holds, typed the way the validator types it.
///
/// `tools/validate_decks.py` reads plain scalars as YAML 1.2's core schema
/// does (its `DeckResolver`; spec ground rule 8): only `true` and `false` in
/// three spellings are booleans, so a bare `no`, `yes`, `on` or `off` is text;
/// digits are a decimal integer (`060` is 60), `0o` and `0x` octal and
/// hexadecimal; `1_000`, `1:30` and `0b101` are text. package:yaml reads
/// nearly the same, but builds a few scalars by Dart's rules rather than the
/// schema's, so an unquoted scalar is retyped here by the validator's
/// patterns, character for character, and the two can never disagree.
///
/// A tag types a scalar in both parsers, as in `!!str 007`. The bare `!` is
/// the exception: after it PyYAML types even a quoted scalar by its look,
/// with the same patterns.
Object? _value(YamlNode node) {
  final value = node.value;
  if (node is! YamlScalar) return value;
  final tag = _tag(node);
  if (tag == null ? node.style != ScalarStyle.PLAIN : tag != '!') return value;

  final text = _plainText(node);
  if (_coreNull.hasMatch(text)) return null;
  if (_coreTrue.hasMatch(text)) return true;
  if (_coreFalse.hasMatch(text)) return false;
  if (_coreInt.hasMatch(text)) return _coreInteger(text);
  if (_coreFloat.hasMatch(text)) return _coreDouble(text);
  return text;
}

/// [text], which the validator reads as an integer, as the same integer:
/// decimal even with leading zeros, `0o` octal, `0x` hexadecimal. One too
/// long for an `int` is a [BigInt], as Python's int has no limit.
Object _coreInteger(String text) {
  final (digits, radix) = text.startsWith('0o')
      ? (text.substring(2), 8)
      : text.startsWith('0x')
      ? (text.substring(2), 16)
      : (text.startsWith('+') ? text.substring(1) : text, 10);
  return int.tryParse(digits, radix: radix) ??
      BigInt.parse(digits, radix: radix);
}

/// Whether [value] is a number: a Dart [num], or a [BigInt] for an integer
/// too long for an `int`.
bool _isNumber(Object? value) => value is num || value is BigInt;

/// [text], which the validator reads as a float, as the same double.
double _coreDouble(String text) {
  final lower = text.toLowerCase();
  final sign = lower.startsWith('-') ? -1.0 : 1.0;
  final unsigned = lower.startsWith('-') || lower.startsWith('+')
      ? lower.substring(1)
      : lower;
  if (unsigned == '.inf') return sign * double.infinity;
  if (unsigned == '.nan') return double.nan;
  return sign * double.parse(unsigned);
}

/// A scalar's text as written, without its anchor, tag or quotes.
String _plainText(YamlNode node) {
  final value = node.value;
  if (value is String) return value;
  // Only a tag makes a quoted scalar anything but text: `!!int "5"`.
  final written = node.span.text.replaceFirst(_properties, '').trim();
  return node is YamlScalar && node.style.isQuoted
      ? written.substring(1, written.length - 1)
      : written;
}

/// The tag [node] was written with, like `!!str`, or null if it has none.
String? _tag(YamlNode node) => _tagged.firstMatch(node.span.text)?[1];

/// How [node] reads in a message: `"text"`, `007`, `a list`.
String _describe(YamlNode node) {
  if (node is YamlMap) return 'a mapping';
  if (node is YamlList) return 'a list';
  final value = _value(node);
  if (value == null) return 'nothing';
  if (value is String) return '"$value"';
  return _plainText(node);
}

/// Why [node] is not the text that [name] should be. When YAML typed the
/// value as a boolean or a number, says why and how to fix it: an unquoted
/// value is typed by how it looks, and a tagged one by its tag.
String _notText(YamlNode node, String name) {
  final value = _value(node);
  if (value is! bool && !_isNumber(value)) {
    return value == null
        ? '$name has no value'
        : '$name must be text, not ${_describe(node)}';
  }
  final text = _plainText(node);
  final why = switch (_tag(node)) {
    // Quoting alone is not enough, because a tag types a quoted value too.
    final tag? => 'it is tagged $tag. Remove the tag and quote it',
    null when value is bool =>
      'YAML reads a bare true or false as a boolean. Quote it',
    null => 'YAML reads a bare $text as a number. Quote it',
  };
  final read = value is bool ? 'the boolean $value' : 'a number';
  return '$name was read as $read, not as text: $why: "$text"';
}

String _wrongType(YamlNode node, String name, String expected) =>
    _value(node) == null
    ? '$name has no value'
    : '$name must be $expected, not ${_describe(node)}';

String _firstUsed(YamlNode node) =>
    'first used on line ${node.span.start.line + 1}';

/// Blank as Python's `str.strip()` sees it, which is what the validator tests.
/// Dart's `trim()` differs: it also strips U+FEFF, and not U+001C to U+001F.
final _blank = RegExp(
  r'^[\t-\r\x1C-\x20\x85\xA0\u1680\u2000-\u200A'
  r'\u2028\u2029\u202F\u205F\u3000]*$',
);

/// The anchor and tag in front of a node, in either order.
final _properties = RegExp(r'^(?:[&!]\S*(?:\s+|$))*');

/// A node that starts with a tag, or with an anchor and then a tag. The tag
/// is the first group.
final _tagged = RegExp(r'^(?:&\S+\s+)?(!\S*)');

// The validator's resolvers for plain scalars, `DeckResolver` in
// tools/validate_decks.py: YAML 1.2's core schema.
final _coreNull = RegExp(r'^(?:null|Null|NULL|~|)$');
final _coreTrue = RegExp(r'^(?:true|True|TRUE)$');
final _coreFalse = RegExp(r'^(?:false|False|FALSE)$');
final _coreInt = RegExp(r'^(?:[-+]?[0-9]+|0o[0-7]+|0x[0-9a-fA-F]+)$');
final _coreFloat = RegExp(
  r'^(?:[-+]?(?:\.[0-9]+|[0-9]+(?:\.[0-9]*)?)(?:[eE][-+]?[0-9]+)?'
  r'|[-+]?\.(?:inf|Inf|INF)|\.(?:nan|NaN|NAN))$',
);
