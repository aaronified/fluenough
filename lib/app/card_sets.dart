import '../core/models/card.dart';
import '../core/models/card_set.dart';
import '../core/models/deck.dart';
import '../core/models/drill_mode.dart';
import 'app_state.dart';

/// Each course's sets with their members resolved, by the catalog's deck
/// list, so that they are worked out once per catalog.
final Expando<Map<String, List<ResolvedSet>>> _resolved =
    Expando<Map<String, List<ResolvedSet>>>('card sets');

/// The set cards of the learner's courses (DECK-FORMAT.md, Set cards;
/// #515), and which a card belongs to.
extension CardSets on AppState {
  /// Every set of [language]'s course from [native], each with every member
  /// the course teaches, in the set's order: a set by refs takes each ref's
  /// card; a rules set the cells of its table with the value it fixes.
  List<ResolvedSet> courseSets(String language, String native) {
    final byCourse = _resolved[decks] ??= <String, List<ResolvedSet>>{};
    return byCourse['$language/$native'] ??= _resolve(language, native);
  }

  List<ResolvedSet> _resolve(String language, String native) {
    final course = <Deck>[
      for (final entry in decks)
        if (entry.language.code == language && entry.deck.native.code == native)
          entry.deck,
    ];
    if (!course.any((deck) => deck.sets.isNotEmpty)) {
      return const <ResolvedSet>[];
    }
    final cards = <Card>[for (final deck in course) ...deck.cards];
    // A rules set may name a whole rules core: its merged deck is
    // `<lang>-<native>-<name>` for the core `<lang>-<name>`.
    final rulesOf = <String, Set<String>>{
      for (final deck in course)
        if (deck.kind == DeckKind.rules)
          '$language-${deck.id.substring(language.length + native.length + 2)}':
              <String>{for (final rule in deck.rules) rule.id},
    };
    return List<ResolvedSet>.unmodifiable(<ResolvedSet>[
      for (final deck in course)
        for (final set in deck.sets)
          resolveSet(set, cards, ruleOf: (id) => rulesOf[id] ?? {}),
    ]);
  }

  /// Whether the card [id] has been taught: some mode of it reviewed.
  bool taughtId(String id) =>
      DrillMode.values.any((mode) => progress.stateOf(id, mode) != null);

  /// The sets whose Full list [card]'s question shows once answered: a
  /// set split over more than one card that [card] is a member of (owner,
  /// 2026-10-16: "Split sets only"), and a set of one slot across the
  /// words whose Full list holds it, every verb of the course; a form in
  /// both sets: "Show both".
  List<ResolvedSet> fullListSetsOf(Card card) {
    final entry = deckOf(card);
    if (entry == null) return const <ResolvedSet>[];
    return <ResolvedSet>[
      for (final set in courseSets(entry.language.code, entry.deck.native.code))
        if (set.set.acrossRows ? set.lists(card) : set.isSplit && set.has(card))
          set,
    ];
  }
}
