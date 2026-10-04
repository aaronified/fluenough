import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../app/deck_catalog.dart';
import '../../app/settings.dart';
import '../../app/skill.dart';
import '../../core/models/deck.dart';
import '../../core/models/drill_mode.dart';
import '../../l10n/app_localizations.dart';

/// What the deck screens read out of a deck, kept apart from the widgets so
/// that it can be tested without pumping anything.

/// The skills a deck's screen offers, in [Skill] order: the modes its cards
/// take part in, grammar for a pattern-table deck, and minimal pairs only for
/// a deck that declares pairs. Skills switched off in Settings are left out,
/// as the design leaves them out.
///
/// A skill's drill being incoming does not hide it: the row is shown
/// disabled (ADR-0008). Nor does a missing voice or speech recogniser: the
/// row says why and how to fix it.
List<Skill> deckSkills(DeckEntry entry, SettingsNotifier settings) {
  final modes = <DrillMode>{
    for (final card in entry.cards)
      ...card.modesIn(ttsAvailable: true, speechAvailable: true),
    if (entry.deck.pattern != null) DrillMode.grammar,
  };
  return <Skill>[
    for (final skill in Skill.values)
      if (settings.isEnabled(skill) &&
          (skill == Skill.pair
              ? declaresPairs(entry)
              : modes.contains(skill.mode)))
        skill,
  ];
}

/// Whether [entry] has minimal pairs to drill. None can yet: the deck format
/// has no pair data, and adding it needs an ADR (#31). The pair row, gated by
/// `Feature.drillPair`, appears only once this can be true.
bool declaresPairs(DeckEntry entry) => false;

/// Every tag the deck's cards carry, in the order they first appear. These
/// are what "Only these tags" filters on; the deck's own tags describe the
/// deck and filter nothing.
List<String> cardTagsOf(DeckEntry entry) =>
    <String>{for (final card in entry.cards) ...card.tags}.toList();

/// Whether the tag filter is worth showing: with fewer than two tags,
/// choosing one filters nothing out.
bool showsTagFilter(DeckEntry entry) => cardTagsOf(entry).length >= 2;

/// One line of a deck's card preview: deck content, never a card id.
typedef PreviewLine = ({
  String target,
  String native,
  String? reading,
  String? ipa,
});

/// The first [count] cards of [entry], as its screen previews them. A
/// grammar deck previews its pattern's cells that have a form: the form, and
/// "lemma — slot", which reads better than its cards' full prompts.
List<PreviewLine> previewOf(
  DeckEntry entry,
  AppLocalizations l10n, {
  int count = 4,
}) {
  final pattern = entry.deck.pattern;
  if (pattern != null) {
    return <PreviewLine>[
      for (final row in pattern.entries)
        for (final slot in pattern.slots)
          if (row.forms[slot] case final form?)
            (
              target: form,
              native: l10n.deckGrammarCell(row.lemma, slot),
              reading: null,
              ipa: row.ipas[slot],
            ),
    ].take(count).toList();
  }
  return <PreviewLine>[
    for (final card in entry.cards.take(count))
      (
        target: card.target,
        native: card.native,
        reading: card.reading,
        ipa: card.ipa,
      ),
  ];
}

/// "Script" for a deck tagged `script` (there is no such deck kind), then
/// the deck's own kind.
String deckKindLabel(AppLocalizations l10n, DeckEntry entry) => entry.isScript
    ? l10n.deckKindScript
    : switch (entry.deck.kind) {
        DeckKind.vocab => l10n.deckKindVocabulary,
        DeckKind.grammar => l10n.deckKindGrammar,
        DeckKind.reading => l10n.deckKindReading,
      };

/// Whether [entry] matches a search. The search is split into words, and
/// every word must be found, ignoring case, in the deck's name, its
/// language's name or any of [also]: the Decks tab passes the deck's theme
/// and kind. So "hindi market" finds Hindi's Market deck and the grammar
/// taught with it, and "market" alone finds every language's. An empty
/// search matches every deck.
bool deckMatches(
  DeckEntry entry,
  String query, {
  Iterable<String> also = const <String>[],
}) {
  final words = <String>[
    for (final word in query.toLowerCase().split(RegExp(r'\s+')))
      if (word.isNotEmpty) word,
  ];
  if (words.isEmpty) return true;
  final fields = <String>[
    for (final field in <String>[entry.deck.name, entry.language.name, ...also])
      field.toLowerCase(),
  ];
  return words.every((word) => fields.any((field) => field.contains(word)));
}

/// [n] written in the interface's locale, for a stat tile or a button.
String formatCount(BuildContext context, int n) =>
    NumberFormat.decimalPattern(AppLocalizations.of(context)!.localeName)
        .format(n);
