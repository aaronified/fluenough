/// A rules deck: one table of word forms, whose columns belong to rules
/// (the B1 format, spec section 4).
///
/// The table's rows are the language's words of one kind, each with every
/// form listed; its columns, the slots, belong to rules, each with its own
/// id, name and explanation. Each filled cell of a row whose word is taught
/// in the learner's language, under a rule the learner's layer gives, is a
/// card ([RuleCell]).
library;

/// A language fact a note's text or a rule's explanation quotes: written
/// once, in the core, and shown as `word (reading)` wherever the text says
/// `{1}`, `{2}`, … (spec 6.4).
class NoteWord {
  const NoteWord({required this.word, this.reading, this.ipa});

  final String word;
  final String? reading;
  final String? ipa;

  /// How a placeholder shows it: `word (reading)`, or `word` alone.
  String get shown => reading == null ? word : '$word ($reading)';
}

/// Which words are a rules table's rows.
class AppliesTo {
  const AppliesTo({
    required this.pos,
    this.tags = const <String>[],
    this.except = const <String>{},
  });

  /// The parts of speech of its words, never empty.
  final List<String> pos;

  /// When not empty, a word qualifies only if it has one of them.
  final List<String> tags;

  /// Card ids of words of the kind the rule does not apply to.
  final Set<String> except;
}

/// One row of a rules table: a word, by its card, and its forms.
class RuleRow {
  const RuleRow({
    required this.word,
    required this.forms,
    this.key,
    this.alternatives = const <String, List<String>>{},
    this.readings = const <String, List<String>>{},
    this.ipas = const <String, String>{},
    this.prompts = const <String, String>{},
  });

  /// The id of the vocab card that teaches the word, such as `te-0042`.
  final String word;

  /// The row's id part, kept from a converted grammar deck's entry. Null
  /// when the id part is the number of [word].
  final String? key;

  /// The form shown in each slot, in slot order; null where the word has no
  /// such form.
  final Map<String, String?> forms;

  /// Other forms accepted for a slot, after the one in [forms].
  final Map<String, List<String>> alternatives;

  /// Each form romanised, by slot.
  final Map<String, List<String>> readings;

  /// The form shown in each slot, in the IPA, by slot.
  final Map<String, String> ipas;

  /// Whole prompts for this row's cells, by slot, from the learner's layer,
  /// where the slot's label gets the phrase wrong.
  final Map<String, String> prompts;

  /// What every cell id of the row holds: [key], or else the digits of
  /// [word] (`0042` for `te-0042`). Changing it orphans the row's history.
  String get idPart => key ?? word.substring(word.lastIndexOf('-') + 1);
}

/// A rules deck's table, its core's forms with its layer's labels.
class RuleTable {
  const RuleTable({
    required this.appliesTo,
    required this.slots,
    required this.slotName,
    required this.labels,
    required this.rows,
  });

  final AppliesTo appliesTo;

  /// The column keys, in order. The order is load-bearing: a cell's id holds
  /// its slot's index, so new slots go at the end.
  final List<String> slots;

  /// What the slots are, in the learner's language: `case`, `person`…
  final String slotName;

  /// Each slot's label, which is also its cells' prompt template: it may
  /// say `{meaning}`, the word's meaning.
  final Map<String, String> labels;

  final List<RuleRow> rows;
}

/// One rule of a rules deck: one or more of its table's columns.
class Rule {
  const Rule({
    required this.id,
    required this.slots,
    required this.name,
    required this.explanation,
    this.words = const <NoteWord>[],
  });

  /// `<lang>-rule-<name>`, such as `te-rule-lo`. Permanent: sentences and
  /// paths name it.
  final String id;

  /// The table's slots this rule makes.
  final List<String> slots;

  /// Its name, in the learner's language.
  final String name;

  /// Its explanation, in the learner's language, placeholders filled.
  final String explanation;

  /// The language facts the explanation quotes.
  final List<NoteWord> words;
}

/// Another form of a rule cell's word, offered when the form is chosen.
class RuleOption {
  const RuleOption({required this.form, required this.prompt});

  /// Another cell's first form.
  final String form;

  /// That cell's meaning to express: "to mother".
  final String prompt;
}

/// What makes a card a rules table's cell: its rule, its word and the
/// other forms of that word.
class RuleCell {
  const RuleCell({
    required this.ruleId,
    required this.word,
    required this.wordTarget,
    required this.slot,
    this.wordReading,
    this.options = const <RuleOption>[],
  });

  /// The rule owning the cell's slot.
  final String ruleId;

  /// The row's card id.
  final String word;

  /// The word as its card writes it, shown with every typed cell: ఇల్లు.
  final String wordTarget;

  /// [wordTarget] romanised: illu. Null when the card gives none.
  final String? wordReading;

  /// The cell's slot key.
  final String slot;

  /// The row's other cells this expansion makes, in slot order: distinct
  /// forms, none the same as this cell's.
  final List<RuleOption> options;
}
