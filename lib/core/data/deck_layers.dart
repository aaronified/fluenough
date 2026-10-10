part of 'deck_parser.dart';

// Cores and layers (B1 format, spec section 2): a deck written as one file
// for the language learnt, the core, and one for each language it is taught
// from, its layers. Merged, a core and one layer are today's [Deck], with
// the layer's id, so that everything keyed by deck id keeps working.
//
// These shapes are the parser's: nothing outside lib/core/data uses them,
// except to hand a core and a layer to [mergeLayer].

/// A core file (`part: "core"`): the language learnt's side of a deck, the
/// same for every learner.
class DeckCore {
  const DeckCore({
    required this.id,
    required this.kind,
    required this.language,
    required this.license,
    this.authors = const <Author>[],
    this.source,
    this.tags = const <String>[],
    this.theme,
    this.cards = const <CoreCard>[],
    this.pattern,
    this.table,
    this.rules = const <CoreRule>[],
    this.proposals = const <String, List<Proposal>>{},
  });

  /// `<lang>-<name>`, such as `te-home`.
  final String id;

  /// Vocab, grammar or rules.
  final DeckKind kind;
  final LanguageInfo language;
  final String license;
  final List<Author> authors;
  final String? source;
  final List<String> tags;
  final String? theme;

  /// A vocab core's cards, written or listed by ref, in order.
  final List<CoreCard> cards;

  /// A grammar core's slots and forms.
  final CorePattern? pattern;

  /// A rules core's table, without its labels, which are each layer's.
  final RuleTable? table;

  /// A rules core's rules, without their names and explanations.
  final List<CoreRule> rules;

  /// Proposed changes to its cards' language side, by card id (ADR-0038).
  final Map<String, List<Proposal>> proposals;

  @override
  String toString() => 'DeckCore($id)';
}

/// One of a core's cards.
sealed class CoreCard {
  const CoreCard(this.id);

  final String id;
}

/// A card a core writes: the language side of it.
class CoreWritten extends CoreCard {
  const CoreWritten({
    required String id,
    required this.target,
    this.reading,
    this.ipa,
    this.altTarget = const <String>[],
    this.pos,
    this.gender,
    this.tags = const <String>[],
    this.audio,
    this.examples = const <CoreExample>[],
    this.modes = const <DrillMode>{},
    this.picture,
    this.notes = const <CoreNote>[],
    this.phrasebook = false,
    this.bases = const <CardBase>[],
    this.rules = const <String>[],
  }) : super(id);

  final String target;
  final String? reading;
  final String? ipa;
  final List<String> altTarget;
  final String? pos;
  final String? gender;
  final List<String> tags;
  final String? audio;
  final List<CoreExample> examples;
  final Set<DrillMode> modes;
  final String? picture;
  final List<CoreNote> notes;
  final bool phrasebook;

  /// Its bases, an inline one without its meaning.
  final List<CardBase> bases;
  final List<String> rules;
}

/// A card a core lists by ref, written elsewhere in the language
/// (ADR-0018). Each field is null when the ref does not give it.
class CoreRef extends CoreCard {
  const CoreRef({
    required String id,
    this.reading,
    this.ipa,
    this.tags,
    this.modes,
    this.examples,
    this.notes,
  }) : super(id);

  final String? reading;
  final String? ipa;
  final List<String>? tags;
  final Set<DrillMode>? modes;
  final List<CoreExample>? examples;
  final List<CoreNote>? notes;
}

/// A core card's example, its translation being in each layer.
class CoreExample {
  const CoreExample({
    required this.target,
    this.reading,
    this.ipa,
    this.bases = const <CardBase>[],
  });

  final String target;
  final String? reading;
  final String? ipa;
  final List<CardBase> bases;
}

/// A core card's note: its language facts, its text being in each layer.
class CoreNote {
  const CoreNote({
    required this.id,
    required this.kind,
    this.ref,
    this.source,
    this.words = const <NoteWord>[],
    this.regions = const <String>[],
  });

  final String id;
  final NoteKind kind;
  final String? ref;
  final String? source;
  final List<NoteWord> words;

  /// A fact about the language, the same for every learner, so in the core.
  final List<String> regions;
}

/// A grammar core's pattern: its slots and its entries, without glosses.
class CorePattern {
  const CorePattern({required this.slots, required this.entries});

  final List<String> slots;

  /// Each with an empty gloss, which the layer gives.
  final List<PatternEntry> entries;
}

/// A rules core's rule: its slots and its language facts.
class CoreRule {
  const CoreRule({
    required this.id,
    required this.slots,
    this.words = const <NoteWord>[],
  });

  final String id;
  final List<String> slots;
  final List<NoteWord> words;
}

/// A layer (`kind: "layer"`): what one native language gives a core.
class DeckLayer {
  const DeckLayer({
    required this.id,
    required this.core,
    required this.native,
    required this.name,
    required this.license,
    required this.node,
    required this.idNode,
    required this.coreNode,
    this.description,
    this.authors = const <Author>[],
    this.source,
    this.tags = const <String>[],
    this.cards = const <String, LayerCard>{},
    this.pattern,
    this.table,
    this.rules = const <String, LayerRule>{},
    this.proposals = const <String, List<Proposal>>{},
  });

  /// `<lang>-<native>-<name>`: the merged deck's id.
  final String id;

  /// The core's id.
  final String core;
  final LanguageInfo native;
  final String name;
  final String? description;
  final String license;
  final List<Author> authors;
  final String? source;
  final List<String> tags;

  /// By card id, in file order.
  final Map<String, LayerCard> cards;
  final LayerPattern? pattern;
  final LayerTable? table;

  /// By rule id.
  final Map<String, LayerRule> rules;

  /// Proposed changes to its cards' meanings, by card id (ADR-0038).
  final Map<String, List<Proposal>> proposals;

  /// Where the layer and its id and core are, for messages.
  final YamlMap node;
  final YamlNode idNode;
  final YamlNode coreNode;

  @override
  String toString() => 'DeckLayer($id of $core)';
}

/// One entry of a layer's `cards`.
sealed class LayerCard {
  const LayerCard(this.key);

  /// The entry's key, the card id, for messages.
  final YamlNode key;
}

/// What a layer gives a card of its core.
class LayerEntry extends LayerCard {
  const LayerEntry({
    required YamlNode key,
    this.native,
    this.altNative,
    this.notes,
    this.examples,
    this.bases,
    this.wiktionary,
  }) : super(key);

  final String? native;
  final List<String>? altNative;

  /// Note texts, by the core note's id.
  final Map<String, LayerText>? notes;

  /// Translations, by the core example's target.
  final Map<String, LayerExample>? examples;

  /// Inline bases' meanings, by word.
  final Map<String, LayerBase>? bases;
  final bool? wiktionary;
}

/// A card only this layer has, written in full.
class LayerOnlyCard extends LayerCard {
  const LayerOnlyCard({required this.card, required YamlNode key}) : super(key);

  final Card card;
}

/// A text in the layer's language, and where it is.
class LayerText {
  const LayerText({required this.text, required this.key, required this.node});

  final String text;
  final YamlNode key;
  final YamlNode node;
}

class LayerExample {
  const LayerExample({
    required this.native,
    required this.key,
    this.bases = const <String, LayerBase>{},
  });

  final String native;
  final Map<String, LayerBase> bases;
  final YamlNode key;
}

class LayerBase {
  const LayerBase({
    required this.meaning,
    required this.key,
    this.wiktionary = false,
  });

  final String meaning;
  final bool wiktionary;
  final YamlNode key;
}

/// A grammar core's layer pattern: what the core leaves to the language
/// it is taught from.
class LayerPattern {
  const LayerPattern({
    required this.name,
    required this.slotName,
    required this.prompt,
    required this.entries,
    this.slots = const <String, LayerText>{},
    this.notes,
  });

  final String name;
  final String slotName;
  final String prompt;

  /// Slot labels, by slot.
  final Map<String, LayerText> slots;

  /// Glosses, by entry id part.
  final Map<String, LayerText> entries;
  final String? notes;
}

/// A rules core's layer table: its labels and prompts.
class LayerTable {
  const LayerTable({
    required this.slotName,
    required this.labels,
    this.prompts = const <String, LayerPrompts>{},
  });

  final String slotName;

  /// By slot.
  final Map<String, LayerText> labels;

  /// By row word.
  final Map<String, LayerPrompts> prompts;
}

/// One row's whole prompts, by slot.
class LayerPrompts {
  const LayerPrompts({required this.texts, required this.key});

  final Map<String, LayerText> texts;
  final YamlNode key;
}

class LayerRule {
  const LayerRule({
    required this.name,
    required this.explanation,
    required this.key,
    required this.node,
  });

  final String name;

  /// With its placeholders, unfilled.
  final String explanation;
  final YamlNode key;
  final YamlNode node;
}

/// [core] and [layer] as one deck, as section 2.7 of the spec defines.
/// Throws DeckParseException (source: the layer's) when the layer does not
/// fit its core: another core id, a card id that is neither the core's nor
/// a layer-only card, a note id or example target or base word the core
/// lacks, notes or examples on a ref the core gives none, a rule or slot
/// the core lacks, a gloss key that is not an entry, a placeholder past the
/// note's or rule's words or not counting from {1} (6.4).
///
/// The merged deck is today's [Deck]: a vocab deck with [Deck.refs] still
/// to resolve, a grammar deck with its pattern still to expand, or a rules
/// deck with its table still to expand (`expandRules`).
Deck mergeLayer(DeckCore core, DeckLayer layer, {required String source}) {
  final reader = _Reader(source)..lang = core.language.code;
  final lang = core.language.code;
  if (layer.core != core.id) {
    reader.fail(
      layer.coreNode,
      'core: this layer is of ${layer.core}, not of ${core.id}',
    );
  }
  final expected =
      '$lang-${layer.native.code}-${core.id.substring(lang.length + 1)}';
  if (layer.id != expected) {
    reader.fail(
      layer.idNode,
      'id: a layer of ${core.id} taught from ${layer.native.code} has id '
      '"$expected", got "${layer.id}"',
    );
  }

  YamlNode? keyOf(String key) => layer.node.nodes.keys
      .cast<YamlNode>()
      .where((k) => k.value == key)
      .firstOrNull;
  const sections = <String, DeckKind>{
    'cards': DeckKind.vocab,
    'pattern': DeckKind.grammar,
    'table': DeckKind.rules,
    'rules': DeckKind.rules,
  };
  for (final MapEntry(key: section, value: kind) in sections.entries) {
    final at = keyOf(section);
    if (at != null && core.kind != kind) {
      reader.fail(at, '$section: only a layer of a ${kind.name} core has it');
    }
    if (at == null && core.kind == kind) {
      reader.fail(
        layer.node,
        'missing required field "$section": a layer of a ${kind.name} core '
        'gives it',
      );
    }
  }

  final tags = <String>[];
  for (final tag in <String>[...core.tags, ...layer.tags]) {
    if (!tags.contains(tag)) tags.add(tag);
  }
  // A deck is unreviewed until both its files are checked (spec 6.5).
  if (tags.contains('unreviewed')) tags.remove('reviewed');

  var cards = const <Card>[];
  var refs = const <CardRef>[];
  GrammarPattern? pattern;
  RuleTable? table;
  var rules = const <Rule>[];
  final merge = _Merge(reader, core, layer);
  switch (core.kind) {
    case DeckKind.vocab:
      (:cards, :refs) = merge.cards();
    case DeckKind.grammar:
      pattern = merge.pattern();
    case DeckKind.rules:
      (:table, :rules) = merge.rules();
    case DeckKind.reading:
      throw StateError('a core is never a reading deck');
  }

  return Deck(
    id: layer.id,
    name: layer.name,
    kind: core.kind,
    language: core.language,
    native: layer.native,
    license: core.license == layer.license
        ? core.license
        : '${core.license} AND ${layer.license}',
    cards: cards,
    pattern: pattern,
    description: layer.description,
    tags: List<String>.unmodifiable(tags),
    authors: List<Author>.unmodifiable(<Author>[
      ...core.authors,
      ...layer.authors,
    ]),
    source: layer.source ?? core.source,
    theme: core.theme,
    refs: refs,
    table: table,
    rules: rules,
    proposals: Map<String, List<Proposal>>.unmodifiable(
      <String, List<Proposal>>{
        for (final card in <String>{
          ...core.proposals.keys,
          ...layer.proposals.keys,
        })
          card: List<Proposal>.unmodifiable(<Proposal>[
            ...?core.proposals[card],
            ...?layer.proposals[card],
          ]),
      },
    ),
  );
}

/// One merge of a core and a layer, failing through [reader].
class _Merge {
  _Merge(this.reader, this.core, this.layer);

  final _Reader reader;
  final DeckCore core;
  final DeckLayer layer;

  /// The core's cards the layer translates, then the layer's own; the
  /// core's refs, each with what the layer gives it (spec 2.7).
  ({List<Card> cards, List<CardRef> refs}) cards() {
    final ids = <String>{for (final card in core.cards) card.id};
    for (final MapEntry(key: id, value: entry) in layer.cards.entries) {
      if (entry is LayerOnlyCard && ids.contains(id)) {
        reader.fail(
          entry.key,
          'cards.$id: "target" belongs to the word, in the core; a layer '
          'gives native, alt_native, notes, examples, bases and wiktionary',
        );
      }
      if (entry is LayerEntry && !ids.contains(id)) {
        reader.fail(
          entry.key,
          'cards.$id: $id is not a card of ${core.id}; a card only this '
          'layer has gives its target too',
        );
      }
    }

    final cards = <Card>[];
    final refs = <CardRef>[];
    // Every entry included before a ref, cards and refs, so that the
    // catalog puts the ref back in its place.
    var position = 0;
    for (final card in core.cards) {
      final entry = layer.cards[card.id] as LayerEntry?;
      final path = 'cards.${card.id}';
      switch (card) {
        case CoreWritten():
          if (entry == null) continue;
          final native =
              entry.native ??
              reader.fail(
                entry.key,
                '$path: native is required: without it the card is not '
                'taught from ${layer.native.name}',
              );
          cards.add(written(card, entry, native, path));
          position++;
        case CoreRef():
          refs.add(ref(card, entry, path, position));
          position++;
      }
    }
    for (final entry in layer.cards.values) {
      if (entry is LayerOnlyCard) cards.add(entry.card);
    }
    return (
      cards: List<Card>.unmodifiable(cards),
      refs: List<CardRef>.unmodifiable(refs),
    );
  }

  Card written(CoreWritten card, LayerEntry entry, String native, String path) {
    final notes = this.notes(card.notes, entry.notes, '$path.notes');
    return Card(
      id: card.id,
      deckId: layer.id,
      target: card.target,
      native: native,
      reading: card.reading,
      ipa: card.ipa,
      altTarget: card.altTarget,
      altNative: entry.altNative ?? const <String>[],
      pos: card.pos,
      gender: card.gender,
      tags: card.tags,
      notes: notes,
      audio: card.audio,
      examples: examples(card.examples, entry.examples, '$path.examples'),
      modes: card.modes,
      // Pair notes are the one source of pairs in a core (OPEN-16).
      pair: notes.where((n) => n.kind == NoteKind.pair).firstOrNull?.ref,
      picture: card.picture,
      phrasebook: card.phrasebook,
      bases: bases(card.bases, entry.bases, '$path.bases'),
      rules: card.rules,
      wiktionary: entry.wiktionary ?? false,
    );
  }

  /// A core ref as a [CardRef], resolved by the catalog as any ref is: its
  /// native side from the layer, null where the layer gives none.
  CardRef ref(CoreRef card, LayerEntry? entry, String path, int position) {
    if (entry?.notes case final notes? when card.notes == null) {
      reader.fail(
        notes.values.firstOrNull?.key ?? entry!.key,
        '$path.notes: the core lists ${card.id} by ref without notes; give '
        "them in the core's ref",
      );
    }
    if (entry?.examples case final examples? when card.examples == null) {
      reader.fail(
        examples.values.firstOrNull?.key ?? entry!.key,
        '$path.examples: the core lists ${card.id} by ref without examples; '
        "give them in the core's ref",
      );
    }
    bases(const <CardBase>[], entry?.bases, '$path.bases');
    return CardRef(
      id: card.id,
      position: position,
      native: entry?.native,
      reading: card.reading,
      ipa: card.ipa,
      altNative: entry?.altNative,
      tags: card.tags,
      notes: card.notes == null
          ? null
          : notes(card.notes!, entry?.notes, '$path.notes'),
      examples: card.examples == null
          ? null
          : examples(card.examples!, entry?.examples, '$path.examples'),
      modes: card.modes,
      wiktionary: entry?.wiktionary,
    );
  }

  /// The core's notes that the layer gives a text, in the core's order,
  /// their placeholders filled from the core's words.
  List<CardNote> notes(
    List<CoreNote> notes,
    Map<String, LayerText>? texts,
    String path,
  ) {
    final ids = <String>{for (final note in notes) note.id};
    for (final MapEntry(key: id, value: text) in (texts ?? const {}).entries) {
      if (!ids.contains(id)) {
        reader.fail(text.key, '$path.$id: the core card has no note "$id"');
      }
    }
    final merged = <CardNote>[];
    for (final note in notes) {
      final text = texts?[note.id];
      if (text == null) continue;
      reader.placeholders(
        text.node,
        text.text,
        note.words.length,
        '$path.${note.id}',
        'note',
      );
      merged.add(
        CardNote(
          id: note.id,
          kind: note.kind,
          text: _filled(text.text, note.words),
          ref: note.ref,
          source: note.source,
          regions: note.regions,
        ),
      );
    }
    return List<CardNote>.unmodifiable(merged);
  }

  /// The core's examples that the layer translates, in the core's order.
  List<CardExample> examples(
    List<CoreExample> examples,
    Map<String, LayerExample>? translations,
    String path,
  ) {
    final targets = <String>{for (final example in examples) example.target};
    for (final MapEntry(key: target, value: translation)
        in (translations ?? const {}).entries) {
      if (!targets.contains(target)) {
        reader.fail(
          translation.key,
          '$path.$target: the core card has no example with this target',
        );
      }
    }
    return List<CardExample>.unmodifiable(<CardExample>[
      for (final example in examples)
        if (translations?[example.target] case final translation?)
          CardExample(
            target: example.target,
            native: translation.native,
            reading: example.reading,
            ipa: example.ipa,
            bases: bases(
              example.bases,
              translation.bases,
              '$path.${example.target}.bases',
            ),
          ),
    ]);
  }

  /// The core's bases, each written in full with the layer's meaning.
  List<CardBase> bases(
    List<CardBase> bases,
    Map<String, LayerBase>? meanings,
    String path,
  ) {
    final inline = <String>{
      for (final base in bases)
        if (base.base != null) base.word,
    };
    for (final MapEntry(key: word, value: meaning)
        in (meanings ?? const {}).entries) {
      if (!inline.contains(word)) {
        reader.fail(
          meaning.key,
          '$path.$word: the core card has no inline base for "$word"; a base '
          'given by ref takes its meaning from that card',
        );
      }
    }
    return List<CardBase>.unmodifiable(<CardBase>[
      for (final base in bases)
        if (base.base == null)
          base
        else
          CardBase(
            word: base.word,
            base: base.base,
            reading: base.reading,
            ipa: base.ipa,
            meaning: meanings?[base.word]?.meaning,
            wiktionary: meanings?[base.word]?.wiktionary ?? false,
          ),
    ]);
  }

  /// The core's pattern with the layer's names, prompt, notes, slot labels
  /// and glosses. An entry the layer gives no gloss is left out.
  GrammarPattern pattern() {
    final forms = core.pattern!;
    final words = layer.pattern!;
    for (final MapEntry(key: slot, value: label) in words.slots.entries) {
      if (!forms.slots.contains(slot)) {
        reader.fail(
          label.key,
          'pattern.slots: "$slot" is not a slot of the core',
        );
      }
    }
    final parts = <String>{for (final entry in forms.entries) entry.idPart};
    for (final MapEntry(key: part, value: gloss) in words.entries.entries) {
      if (!parts.contains(part)) {
        reader.fail(
          gloss.key,
          'pattern.entries: "$part" is not an entry of the core',
        );
      }
    }
    return GrammarPattern(
      name: words.name,
      slotName: words.slotName,
      slots: forms.slots,
      prompt: words.prompt,
      notes: words.notes,
      slotLabels: Map<String, String>.unmodifiable(<String, String>{
        for (final MapEntry(key: slot, value: label) in words.slots.entries)
          slot: label.text,
      }),
      entries: List<PatternEntry>.unmodifiable(<PatternEntry>[
        for (final entry in forms.entries)
          if (words.entries[entry.idPart] case final gloss?)
            PatternEntry(
              lemma: entry.lemma,
              gloss: gloss.text,
              forms: entry.forms,
              key: entry.key,
              alternatives: entry.alternatives,
              reading: entry.reading,
              readings: entry.readings,
              ipa: entry.ipa,
              ipas: entry.ipas,
            ),
      ]),
    );
  }

  /// The core's table with the layer's labels and prompts, and the rules
  /// the layer gives, in the core's order (spec 4.5).
  ({RuleTable table, List<Rule> rules}) rules() {
    final forms = core.table!;
    final words = layer.table!;
    for (final slot in forms.slots) {
      if (!words.labels.containsKey(slot)) {
        reader.fail(
          layer.node.nodes['table']!,
          'table.slots gives no label for "$slot"',
        );
      }
    }
    for (final MapEntry(key: slot, value: label) in words.labels.entries) {
      if (!forms.slots.contains(slot)) {
        reader.fail(
          label.key,
          'table.slots: "$slot" is not a slot of the core',
        );
      }
    }
    final rows = <String>{for (final row in forms.rows) row.word};
    for (final MapEntry(key: word, value: prompts) in words.prompts.entries) {
      if (!rows.contains(word)) {
        reader.fail(
          prompts.key,
          'table.prompts: "$word" is not a row of the core',
        );
      }
      for (final MapEntry(key: slot, value: prompt) in prompts.texts.entries) {
        if (!forms.slots.contains(slot)) {
          reader.fail(
            prompt.key,
            'table.prompts.$word: "$slot" is not a slot of the core',
          );
        }
      }
    }
    final ids = <String>{for (final rule in core.rules) rule.id};
    for (final MapEntry(key: id, value: rule) in layer.rules.entries) {
      if (!ids.contains(id)) {
        reader.fail(rule.key, 'rules: "$id" is not a rule of the core');
      }
    }

    final rules = <Rule>[];
    for (final rule in core.rules) {
      final text = layer.rules[rule.id];
      if (text == null) continue;
      reader.placeholders(
        text.node,
        text.explanation,
        rule.words.length,
        'rules.${rule.id}.explanation',
        'rule',
      );
      rules.add(
        Rule(
          id: rule.id,
          slots: rule.slots,
          name: text.name,
          explanation: _filled(text.explanation, rule.words),
          words: rule.words,
        ),
      );
    }
    return (
      table: RuleTable(
        appliesTo: forms.appliesTo,
        slots: forms.slots,
        slotName: words.slotName,
        labels: Map<String, String>.unmodifiable(<String, String>{
          for (final MapEntry(key: slot, value: label) in words.labels.entries)
            slot: label.text,
        }),
        rows: List<RuleRow>.unmodifiable(<RuleRow>[
          for (final row in forms.rows)
            RuleRow(
              word: row.word,
              key: row.key,
              forms: row.forms,
              alternatives: row.alternatives,
              readings: row.readings,
              ipas: row.ipas,
              prompts: Map<String, String>.unmodifiable(<String, String>{
                for (final MapEntry(key: slot, value: prompt)
                    in (words.prompts[row.word]?.texts ?? const {}).entries)
                  slot: prompt.text,
              }),
            ),
        ]),
      ),
      rules: List<Rule>.unmodifiable(rules),
    );
  }
}
