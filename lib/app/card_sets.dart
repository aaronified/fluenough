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
          ResolvedSet(
            set: set,
            members: setMembers(set, cards, ruleOf: (id) => rulesOf[id] ?? {}),
          ),
    ]);
  }

  /// Whether the card [id] has been taught: some mode of it reviewed.
  bool taughtId(String id) =>
      DrillMode.values.any((mode) => progress.stateOf(id, mode) != null);

  /// [set] as this learner sees it: a set of one slot across the words
  /// ("one person across the verbs taught") holds only the cells whose word
  /// the learner was taught, or which are taught already, or which [also]
  /// holds. Any other set is whole. Null when fewer than two are left.
  ResolvedSet? forLearner(ResolvedSet set, {Set<String> also = const {}}) {
    if (set.set.rule?.fixesRow != false) return set;
    final members = <Card>[
      for (final member in set.members)
        if (also.contains(member.id) ||
            taughtId(member.id) ||
            (member.rule != null && taughtId(member.rule!.word)))
          member,
    ];
    if (members.length < 2) return null;
    return ResolvedSet(set: set.set, members: members);
  }

  /// The sets [card] is a member of, as the learner sees them, that are
  /// split over more than one card: those whose question shows a Full list
  /// once answered (owner, 2026-10-16: "Split sets only"; a form in both
  /// sets: "Show both").
  List<ResolvedSet> splitSetsOf(Card card) {
    final entry = deckOf(card);
    if (entry == null) return const <ResolvedSet>[];
    return <ResolvedSet>[
      for (final set in courseSets(entry.language.code, entry.deck.native.code))
        if (set.has(card))
          if (forLearner(set, also: {card.id}) case final shown?
              when shown.isSplit && shown.has(card))
            shown,
    ];
  }
}
