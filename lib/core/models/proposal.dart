/// A change a reviewer proposed to one field of a card, waiting for other
/// reviewers to accept it (ADR-0038). The review bot writes it into the
/// deck, on the card, from a review mail; once enough other reviewers have
/// accepted it, the bot writes [text] into the field.
///
/// Only reviewer mode shows proposals. A learner never sees one.
library;

/// The fields a proposal may change. The names are the deck's, and are
/// written to review files, so they are permanent. [gender], [register],
/// [hears] and [warning] (#508) are the card's own scalars: each has a fixed
/// set of values, which the review bot checks before it writes one.
///
/// [altNativeAdd] and [notSynonymsAdd] (ADR-0050) add one item to a list on
/// the card's native side, an extra accepted answer and a refused synonym.
/// Their `now` is always "" and their `text` is the one item. Their names in
/// a deck are `alt_native_add` and `not_synonyms_add`: read and write a
/// field by [wire], never by `name`.
enum ProposalField {
  target,
  reading,
  ipa,
  native,
  notes,
  gender,
  register,
  hears,
  warning,
  altNativeAdd,
  notSynonymsAdd;

  /// The field's name in a deck and in a review file.
  String get wire => switch (this) {
    altNativeAdd => 'alt_native_add',
    notSynonymsAdd => 'not_synonyms_add',
    _ => name,
  };

  /// The field a deck names [wire], or null when the app does not know it.
  static ProposalField? fromWire(Object? wire) {
    for (final field in values) {
      if (field.wire == wire) return field;
    }
    return null;
  }

  /// Whether the field adds one item to a list and replaces nothing.
  bool get isAdd => this == altNativeAdd || this == notSynonymsAdd;
}

class Proposal {
  const Proposal({
    required this.id,
    required this.card,
    required this.field,
    required this.now,
    required this.text,
    required this.by,
    required this.date,
    this.why = '',
    this.accepted = const <String>[],
  });

  /// Ten hex digits, the hash of the facts below: the same proposal always
  /// has the same id.
  final String id;

  /// The card's id.
  final String card;
  final ProposalField field;

  /// What the field said when the reviewer proposed the change, "" when
  /// the card had none. A proposal whose field says something else now is
  /// outdated, and is not shown.
  final String now;

  /// The new text.
  final String text;

  /// The proposer's rater code.
  final String by;

  /// The day of the review, `YYYY-MM-DD`.
  final String date;

  /// The proposer's reason, or "".
  final String why;

  /// The rater codes that have accepted it, none of them [by].
  final List<String> accepted;

  @override
  String toString() => 'Proposal($id, $card.${field.name})';
}
