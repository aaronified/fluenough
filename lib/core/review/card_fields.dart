/// The fields of a card as a reviewer sees them, one item at a time (#508):
/// the items of each list field, and the warnings the teach card can show.
/// Pure Dart, so that it is tested without a device.
library;

import '../models/card.dart';
import 'deck_review.dart';

/// Finds a card of the language by its id, or null when it is not on the
/// phone.
typedef FindCard = Card? Function(String id);

/// One item of a list field, as the sheet lists it: [key] names it in a
/// suggestion and in "Looks right"; [text] is what a suggestion edits, its
/// first line the item's word or text and any further lines its reading,
/// meaning or note.
class FieldItem {
  const FieldItem({
    required this.key,
    required this.text,
    this.quote,
    this.ref,
    this.wiktionary = false,
  });

  final String key;
  final String text;

  /// The part of the first line that is the language's own text, which the
  /// sheet writes in its font, or null when the line is in the learner's
  /// language.
  final String? quote;

  /// The card the item names, or null for an item written in full.
  final String? ref;

  /// Whether the item came from Wiktionary: semi-verified, and shown after
  /// the rest (owner, 2026-10-13, #508).
  final bool wiktionary;

  /// The first line of [text].
  String get title => text.split('\n').first;

  /// The lines after the first, or null when there are none.
  String? get detail {
    final rest = text
        .split('\n')
        .skip(1)
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
    return rest.isEmpty ? null : rest;
  }
}

/// Whether an item's `source` names Wiktionary.
bool fromWiktionary(String? source) =>
    source != null && source.toLowerCase().contains('wiktionary');

/// The text of [value] with its reading in brackets: "दंड (daṇḍ)".
String withReading(String value, String? reading) =>
    reading == null || reading.trim().isEmpty ? value : '$value ($reading)';

FieldItem _cardItem(CardItem item, FindCard find) {
  final taught = item.ref == null ? null : find(item.ref!);
  final word = item.word ?? taught?.target ?? item.ref ?? '';
  final detail = <String>[
    for (final line in <String?>[item.text ?? taught?.native, item.note])
      if (line != null && line.trim().isNotEmpty) line.trim(),
  ];
  return FieldItem(
    key: item.id,
    text: <String>[
      withReading(word, item.reading ?? taught?.reading),
      ...detail,
    ].join('\n'),
    quote: word.isEmpty ? null : word,
    ref: item.ref,
    wiktionary: fromWiktionary(item.source),
  );
}

FieldItem _example(int index, CardExample example) => FieldItem(
  key: '${index + 1}',
  text: <String>[
    example.target,
    if (example.reading case final r? when r.trim().isNotEmpty) r,
    example.native,
  ].join('\n'),
  quote: example.target,
  wiktionary: fromWiktionary(example.source),
);

/// The items of the list field [part] of [card], in the deck's order. The
/// facts that name the card come from the language's facts file, so the
/// caller gives them as [facts], each by its id. Empty for a part that is
/// not a list.
List<FieldItem> itemsOf(
  Card card,
  CardPart part,
  FindCard find, {
  List<({String id, String text})> facts = const <({String id, String text})>[],
}) {
  List<FieldItem> cardItems(List<CardItem> items) => <FieldItem>[
    for (final item in items) _cardItem(item, find),
  ];
  return switch (part) {
    CardPart.synonyms => cardItems(card.synonyms),
    CardPart.antonyms => cardItems(card.antonyms),
    CardPart.confusables => cardItems(card.confusables),
    CardPart.forms => cardItems(card.forms),
    CardPart.collocations => cardItems(card.collocations),
    CardPart.senses => <FieldItem>[
      for (final sense in card.senses)
        FieldItem(
          key: sense.id,
          text: sense.native,
          wiktionary: fromWiktionary(sense.source),
        ),
    ],
    CardPart.examples => <FieldItem>[
      for (final (i, example) in card.examples.indexed) _example(i, example),
    ],
    CardPart.pairs => <FieldItem>[
      for (final pair in _pairs(card))
        FieldItem(
          key: pair.id,
          text: <String>[
            withReading(
              find(pair.id)?.target ?? pair.id,
              find(pair.id)?.reading,
            ),
            ?pair.care,
          ].join('\n'),
          quote: find(pair.id)?.target,
          ref: pair.id,
        ),
    ],
    CardPart.facts => <FieldItem>[
      for (final fact in facts) FieldItem(key: fact.id, text: fact.text),
    ],
    CardPart.dictionary => <FieldItem>[
      for (final (i, sense)
          in (card.dictionary?.senses ?? const <String>[]).indexed)
        FieldItem(key: 'sense-${i + 1}', text: sense, wiktionary: true),
      if (card.dictionary?.etymology case final origin?
          when origin.trim().isNotEmpty)
        FieldItem(key: 'etymology', text: origin, wiktionary: true),
    ],
    _ => const <FieldItem>[],
  };
}

/// The words [card] sounds almost like, by card id, each once and in order:
/// its `pair`, then the partner of each of its pair notes, with that note's
/// text where it has one (the care note).
List<({String id, String? care})> _pairs(Card card) {
  final seen = <String>{};
  final out = <({String id, String? care})>[];
  String? careFor(String id) {
    for (final note in card.notes) {
      if (note.kind == NoteKind.pair &&
          note.ref == id &&
          note.text.trim().isNotEmpty) {
        return note.text;
      }
    }
    return null;
  }

  void add(String? id) {
    if (id == null || !seen.add(id)) return;
    out.add((id: id, care: careFor(id)));
  }

  add(card.pair);
  for (final note in card.notes) {
    if (note.kind == NoteKind.pair) add(note.ref);
  }
  return out;
}

/// The order the sheet lists [items] in: those still to check first, and
/// within each, Claude-written items before Wiktionary's (owner,
/// 2026-10-13, 2026-10-30: "checked items move down").
List<FieldItem> inReviewOrder(
  Iterable<FieldItem> items,
  CardPart part,
  Set<String> checked,
) {
  bool done(FieldItem item) =>
      checked.contains(CardReview.itemKey(part, item.key));
  int rank(FieldItem item) => (done(item) ? 2 : 0) + (item.wiktionary ? 1 : 0);
  final list = items.toList();
  // A stable sort: the deck's order is kept within a rank.
  final ranked = <(int, int, FieldItem)>[
    for (final (i, item) in list.indexed) (rank(item), i, item),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return <FieldItem>[for (final r in ranked) r.$3];
}

/// A warning the teach card can show, which a reviewer may pick (#691). The
/// warning's [id] is what `warning` holds: a note's id, `senses` or `none`.
class WarningOption {
  const WarningOption({
    required this.id,
    required this.kind,
    required this.text,
    this.enabled = true,
  });

  /// The id of a pair, homograph or lookalike note, [senses] or [none].
  final String id;

  /// The note's kind for a note, null for the other two.
  final NoteKind? kind;

  /// What it says: the note's text, the other meanings, or nothing.
  final String text;

  /// False for "Other meanings" on a card that has none.
  final bool enabled;

  static const String senses = 'senses';
  static const String none = 'none';
}

/// The warnings the teach card of [card] can show, and only those: each of
/// its pair, homograph and lookalike notes, its other meanings, and none.
/// There is no automatic choice: a picked warning is never taken back, the
/// review bot never removes a `warning` (owner, 2026-10-30, #508).
List<WarningOption> warningOptionsOf(Card card) => <WarningOption>[
  for (final note in card.notes)
    if (note.kind == NoteKind.pair ||
        note.kind == NoteKind.homograph ||
        note.kind == NoteKind.lookalike)
      WarningOption(id: note.id, kind: note.kind, text: note.text),
  WarningOption(
    id: WarningOption.senses,
    kind: null,
    text: card.senses.map((s) => s.native).join(', '),
    enabled: card.senses.isNotEmpty,
  ),
  const WarningOption(id: WarningOption.none, kind: null, text: ''),
];
