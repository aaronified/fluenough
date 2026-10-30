import '../core/models/card.dart';
import '../core/models/situation.dart';
import '../core/progress/recent_answers.dart' show MasteryLevel;
import '../core/scheduling/ask.dart';
import '../core/scheduling/lesson.dart';
import '../core/scheduling/session_queue.dart';
import 'app_state.dart';
import 'deck_catalog.dart';
import 'session.dart';
import 'unlocks.dart';

/// A card on a situation sheet: the deck's own card, so that its progress,
/// its audio and its inspect view are the card's, and whether the learner
/// has not met it yet.
typedef SheetCard = ({Card card, DeckEntry deck, bool isNew});

/// How many cards a sheet's session teaches at most, as one lesson teaches up
/// to nine words: the rest of a long sheet is for the next session.
const int sheetNewCardsCap = 9;

/// Situation sheets (#724): lists of card ids, resolved against the decks.
extension SituationState on AppState {
  /// The language Today's situation buttons are for: the one the language
  /// bar shows, else the first language the profile learns that has sheets,
  /// else the first it learns. Null when the profile learns none.
  String? get situationsLanguage {
    final shown = shownLanguage;
    if (shown != null) return shown;
    final learned = <String>[
      for (final code in <String>{
        for (final entry in profileDecks) entry.language.code,
      })
        code,
    ];
    for (final code in learned) {
      if (situationsOf(code) != null) return code;
    }
    return learned.isEmpty ? null : learned.first;
  }

  /// The cards of [language]'s decks by id, as the learner's course teaches
  /// them: where two native languages write a card, the course's.
  Map<String, Card> _courseCards(String language) =>
      derived<Map<String, Card>>(('situationCards', language), () {
        final native = courseNative(language);
        final entries =
            <DeckEntry>[
              for (final entry in decks)
                if (entry.language.code == language) entry,
            ]..sort((a, b) {
              int rank(DeckEntry e) => e.deck.native.code == native ? 0 : 1;
              return rank(a).compareTo(rank(b));
            });
        final cards = <String, Card>{};
        for (final entry in entries) {
          for (final card in entry.cards) {
            cards.putIfAbsent(card.id, () => card);
          }
        }
        return cards;
      });

  /// [ids] as cards of [language]'s decks, in order. An id no deck writes is
  /// left out, as a deck's removal must not break a sheet.
  List<SheetCard> sheetCards(String language, Iterable<String> ids) {
    final cards = _courseCards(language);
    final recent = recentAnswers;
    return <SheetCard>[
      for (final id in ids)
        if (cards[id] case final card?)
          if (deckOf(card) case final deck?)
            (
              card: card,
              deck: deck,
              isNew: recent.of(card.id).level == MasteryLevel.fresh,
            ),
    ];
  }

  /// How many cards of [situation] the learner has not met yet.
  int newCardsIn(String language, Situation situation) =>
      sheetCards(language, situation.cardIds).where((c) => c.isNew).length;

  /// The items of a sheet's session ([DrillRequest.sheet]): the cards not
  /// taught yet, each taught, checked and practised as a lesson does, then
  /// the cards already taught, revised. With [DrillRequest.revise], the
  /// revising only. At most [sheetNewCardsCap] new cards are taught in one
  /// session, in the sheet's order.
  List<SessionItem> sheetSession(DrillRequest request) {
    final language = request.language;
    final ids = request.cardIds;
    if (language == null || ids == null) return const <SessionItem>[];
    final cards = <Card>[for (final c in sheetCards(language, ids)) c.card];
    final taught = <String>{
      for (final card in cards)
        if (isTaught(card)) card.id,
    };
    final modesOf = drillableModesNow();
    final gate = unlocks;
    final lesson = request.revise
        ? const <SessionItem>[]
        : lessonPlan(
            <Card>[
              for (final card in cards)
                if (!taught.contains(card.id) &&
                    gate.isOpen(card) &&
                    modesOf(card).isNotEmpty)
                  card,
            ].take(sheetNewCardsCap).toList(),
            modesOf: modesOf,
            canChoose: (card, ask) => canChoose(
              card,
              ask == Ask.hearMeaning && hearsForm(card)
                  ? Ask.hearAndChoose
                  : ask,
            ),
            typed: isTyped,
            siblingsOf: siblingsOf,
          );
    final revision = taught.isEmpty
        ? const <SessionItem>[]
        : <SessionItem>[
            for (final item in sessionItems(
              DrillRequest(revise: true, language: language),
            ))
              if (taught.contains(item.card.id)) item,
          ];
    return <SessionItem>[
      for (final item in lesson)
        item.ask == Ask.hearMeaning && hearsForm(item.card)
            ? item.askedAs(Ask.hearAndChoose)
            : item,
      ...revision,
    ];
  }
}
