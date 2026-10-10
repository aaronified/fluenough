import 'package:flutter/material.dart' hide Card;

import '../../app/app_state.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/target_text.dart';

/// One of a card's base words as a card shows it (#410): the base, its
/// reading and its meaning in the learner's language.
///
/// [word] is the word as it stands in the card's target, the key a layer
/// gives an inline base's meaning by; [inline] says whether the base is
/// written in full on the card, or taught by the card [ref] names, whose
/// target, reading and meaning these are.
typedef ShownBase = ({
  String word,
  String base,
  String? reading,
  String? meaning,
  bool inline,
  String? ref,
});

/// [card]'s base words as its face shows them, in order: each written in
/// full with its own meaning, or by ref as the card [find] finds for its id
/// teaches it. A ref to a card that is not on the phone, or to [card]
/// itself, is left out, and a base shown once is not shown again.
List<ShownBase> shownBases(Card card, Card? Function(String id) find) {
  final seen = <String>{};
  final out = <ShownBase>[];
  for (final b in card.bases) {
    final ShownBase shown;
    final base = b.base;
    final ref = b.ref;
    if (base != null && base.trim().isNotEmpty) {
      shown = (
        word: b.word,
        base: base,
        reading: b.reading,
        meaning: _text(b.meaning),
        inline: true,
        ref: null,
      );
    } else if (ref != null && ref != card.id) {
      final taught = find(ref);
      if (taught == null) continue;
      shown = (
        word: b.word,
        base: taught.target,
        reading: taught.reading,
        meaning: _text(taught.native),
        inline: false,
        ref: ref,
      );
    } else {
      continue;
    }
    if (seen.add('${shown.base}\u0000${shown.meaning}')) out.add(shown);
  }
  return out;
}

String? _text(String? text) =>
    text == null || text.trim().isEmpty ? null : text.trim();

/// Finds a card a base names by its id: from a deck of [language] taught
/// from [native] first, so that its meaning is in the learner's language,
/// then from any deck of [language].
Card? Function(String id) baseFinder(
  AppState state, {
  required String language,
  String? native,
}) => (id) {
  Card? other;
  for (final entry in state.decks) {
    if (entry.language.code != language) continue;
    for (final c in entry.cards) {
      if (c.id != id) continue;
      if (native == null || entry.deck.native.code == native) return c;
      other ??= c;
    }
  }
  return other;
};

/// [card]'s base words, found as [baseFinder] finds them for the deck that
/// holds it.
List<ShownBase> basesOf(AppState state, Card card, LanguageInfo language) =>
    card.bases.isEmpty
    ? const <ShownBase>[]
    : shownBases(
        card,
        baseFinder(
          state,
          language: language.code,
          native: state.deckOf(card)?.deck.native.code,
        ),
      );

/// One base as its line says it: "जाना (jānā) · to go", its reading only
/// where [reading] is true.
String baseText(AppLocalizations l10n, ShownBase base, {bool reading = true}) {
  final r = reading ? base.reading : null;
  final meaning = base.meaning;
  return switch ((r, meaning)) {
    (null, null) => base.base,
    (final r?, null) => l10n.cardBaseReading(base.base, r),
    (null, final m?) => l10n.cardBase(base.base, m),
    (final r?, final m?) => l10n.cardBaseReadingMeaning(base.base, r, m),
  };
}

/// A card's base words on one line, under its meaning and notes:
/// "Base: जाना (jānā) · to go", or "Bases: …" for several, the bases in the
/// language's own font. Nothing for a card without bases.
///
/// One line, small and muted, so that it does not crowd a drill's card; it
/// wraps when it must. [reading] says whether the bases' readings show.
class BaseLine extends StatelessWidget {
  const BaseLine({
    super.key,
    required this.bases,
    required this.language,
    this.reading = true,
    this.fontSize,
  });

  final List<ShownBase> bases;
  final LanguageInfo language;
  final bool reading;

  /// The text's size, or null for the theme's body size.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    if (bases.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final parts = <String>[
      for (final b in bases) baseText(l10n, b, reading: reading),
    ];
    final list = parts.skip(1).fold(parts.first, l10n.cardBasesJoin);
    return Text.rich(
      quotingTarget(l10n.cardBases(bases.length, list), <String>[
        for (final b in bases) b.base,
      ], language),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium!.copyWith(
        fontSize: fontSize,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
