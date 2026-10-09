import 'package:yaml/yaml.dart';

import '../models/author.dart';
import '../models/card.dart';
import '../models/deck.dart';
import '../models/drill_mode.dart';
import '../models/grammar_pattern.dart';
import '../models/reading.dart';

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
/// strictly, like `!!timestamp`, `!!float 1` or `!!bool yes`; two keys that
/// YAML 1.2 reads as the same number and YAML 1.1 does not, like `010` and
/// `10`; and oddities such as a `"\uD800"` escape or a U+2028 line break. A
/// deck using one passes CI and fails here.
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
  static Deck parse(String yaml, {required String source}) {
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
    return _Reader(source).deck(root);
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
};

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
};

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
const _exampleFields = {'target', 'native', 'reading', 'ipa'};
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

  Never fail(YamlNode node, String message) {
    final start = node.span.start;
    throw DeckParseException(
      message,
      source: source,
      line: start.line + 1,
      column: start.column + 1,
    );
  }

  Deck deck(YamlNode root) {
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
    if (schema is! num || schema != 1) {
      fail(schemaNode, 'schema must be 1, got ${_describe(schemaNode)}');
    }

    final kindNode = fields.node('kind');
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
      notes: fields.optionalString('notes'),
      examples: fields.has('examples')
          ? examples(fields.node('examples'), '$path.examples')
          : null,
      modes: fields.has('modes')
          ? modes(fields.node('modes'), '$path.modes')
          : null,
    );
  }

  /// One card. [seen] maps each card id so far to where it was declared.
  Card card(
    YamlNode node,
    String path,
    String deckId,
    Map<String, YamlNode> seen,
  ) {
    final fields = this.fields(node, path);
    fields.allowOnly(_cardFields);

    final idNode = fields.require('id');
    final id = this.id(idNode, '$path.id');
    final first = seen[id];
    if (first != null) {
      fail(idNode, '$path.id: duplicate card id "$id", ${_firstUsed(first)}');
    }
    seen[id] = idNode;

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
      notes: fields.optionalString('notes'),
      audio: fields.optionalString('audio'),
      examples: examples(fields.node('examples'), '$path.examples'),
      modes: modes(fields.node('modes'), '$path.modes'),
      pair: fields.optionalString('pair', allowEmpty: false),
      picture: fields.optionalString('picture', allowEmpty: false),
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
    // Only a reading deck's questions are read; a card has nothing to read.
    if (mode == null || mode == DrillMode.reading) {
      final modes = <String>[
        for (final m in DrillMode.values)
          if (m != DrillMode.reading) m.name,
      ];
      fail(
        node,
        '$path: unknown mode "$name"; the modes are ${modes.join(', ')}',
      );
    }
    return mode;
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
      if (code is bool || code is num) {
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
  PatternEntry entry(
    YamlNode node,
    String path,
    List<String> slots,
    Map<String, YamlNode> lemmas,
    Map<String, YamlNode> keys,
  ) {
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

    final (:forms, :alternatives) = this.forms(
      fields.require('forms'),
      '$path.forms',
      slots,
    );
    return PatternEntry(
      lemma: lemma,
      key: key,
      gloss: fields.string('gloss'),
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
  /// with a form, and none for a slot without.
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
      if (forms[slot] == null) {
        fail(key, '$path: "$slot" has no form, so it has no reading');
      }
      final value = entry.value;
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
  /// with a form, and none for a slot without.
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
      if (slot is bool || slot is num) {
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

/// What [node] holds, typed the way PyYAML types it.
///
/// `tools/validate_decks.py` reads decks with PyYAML, which follows YAML 1.1:
/// there a bare `no`, `yes`, `on` or `off` is a boolean, `1:30` is a number and
/// `08` is text. package:yaml follows YAML 1.2, which disagrees on all of
/// those. So an unquoted scalar is retyped here by PyYAML's rules, and
/// `native: no` is the boolean false in both places, rather than the text "no"
/// in one of them.
///
/// Only nulls, booleans and numbers are retyped. PyYAML also reads a bare
/// `2001-12-14` as a date, which the validator rejects wherever it wants text,
/// and refuses a bare `=` outright. Reading both as text only accepts more.
Object? _value(YamlNode node) {
  final value = node.value;
  if (node is! YamlScalar) return value;
  // A tag types the scalar in both parsers, as in `!!str 007`. The bare `!`
  // is the exception: after it PyYAML types even a quoted scalar by its look.
  final tag = _tag(node);
  if (tag == null ? node.style != ScalarStyle.PLAIN : tag != '!') return value;

  final text = _plainText(node);
  // PyYAML picks its patterns by the first character, then matches with
  // Python's `$`, which also matches before a final newline. Only a quoted
  // scalar tagged `!` can end in one.
  final look = text.length > 1 && text.endsWith('\n')
      ? text.substring(0, text.length - 1)
      : text;
  if (_yaml11Null.hasMatch(look)) return null;
  if (_yaml11True.hasMatch(look)) return true;
  if (_yaml11False.hasMatch(look)) return false;
  if (_yaml11Int.hasMatch(look) || _yaml11Float.hasMatch(look)) {
    return _yaml11Number(look);
  }
  return text;
}

/// [text], which PyYAML types as a number, as a number with the same answer
/// to the one question asked of it.
///
/// Only `schema` uses the value, to ask whether it is 1, and CI says yes to
/// `0b1` and `0:1.0` as well as to `01` and `0x1`. So binary and base 60 are
/// read as PyYAML reads them, in yaml/constructor.py. Octal is read as decimal,
/// which gives the same answer, and whatever Dart cannot read, like `.inf`, is
/// NaN: still a number, and never 1.
num _yaml11Number(String text) {
  var digits = text.replaceAll('_', '');
  final sign = digits.startsWith('-') ? -1 : 1;
  if (digits.startsWith('-') || digits.startsWith('+')) {
    digits = digits.substring(1);
  }
  if (digits.contains(':')) {
    // In doubles, so that a long one cannot wrap round to a small int.
    return sign *
        digits.split(':').fold(0.0, (sum, part) => sum * 60 + _double(part));
  }
  if (digits.startsWith('0b')) {
    return sign * (int.tryParse(digits.substring(2), radix: 2) ?? double.nan);
  }
  return sign * (num.tryParse(digits) ?? double.nan);
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
  if (value is! bool && value is! num) {
    return value == null
        ? '$name has no value'
        : '$name must be text, not ${_describe(node)}';
  }
  final text = _plainText(node);
  final why = switch (_tag(node)) {
    // Quoting alone is not enough, because a tag types a quoted value too.
    final tag? => 'it is tagged $tag. Remove the tag and quote it',
    null when value is bool =>
      'YAML reads a bare no, yes, on, off, true or false as a boolean. '
          'Quote it',
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

/// [text] as a double, or NaN if it is not one.
double _double(String text) => double.tryParse(text) ?? double.nan;

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

// PyYAML's implicit resolvers for plain scalars, from yaml/resolver.py.
final _yaml11Null = RegExp(r'^(?:~|null|Null|NULL|)$');
final _yaml11True = RegExp(r'^(?:yes|Yes|YES|true|True|TRUE|on|On|ON)$');
final _yaml11False = RegExp(r'^(?:no|No|NO|false|False|FALSE|off|Off|OFF)$');
final _yaml11Int = RegExp(
  r'^(?:[-+]?0b[0-1_]+'
  r'|[-+]?0[0-7_]+'
  r'|[-+]?(?:0|[1-9][0-9_]*)'
  r'|[-+]?0x[0-9a-fA-F_]+'
  r'|[-+]?[1-9][0-9_]*(?::[0-5]?[0-9])+)$',
);
final _yaml11Float = RegExp(
  r'^(?:[-+]?(?:[0-9][0-9_]*)\.[0-9_]*(?:[eE][-+][0-9]+)?'
  r'|\.[0-9][0-9_]*(?:[eE][-+][0-9]+)?'
  r'|[-+]?[0-9][0-9_]*(?::[0-5]?[0-9])+\.[0-9_]*'
  r'|[-+]?\.(?:inf|Inf|INF)'
  r'|\.(?:nan|NaN|NAN))$',
);
