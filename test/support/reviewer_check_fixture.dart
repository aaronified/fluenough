// A fixture course for the reviewer check: decks of made-up words and
// meanings, and the items the placement generators would make from them
// (the pick formats the check may ask), so that the check's own rules, run
// and replay can be tested on a bank of a size and shape we control. No real
// language is in it.
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/placement/item_registry.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:fluenough/core/placement/reviewer_check_bank.dart';

/// The fixture's size: [decks] decks of [perDeck] cards, level marks at a
/// third, two thirds and the end.
class ReviewerFixture {
  ReviewerFixture({this.decks = 60, this.perDeck = 8}) {
    final all = <PlacementDeck>[];
    for (var d = 0; d < decks; d++) {
      all.add(
        PlacementDeck(
          id: 'fx-$d',
          cards: <Card>[
            for (var j = 0; j < perDeck; j++)
              Card(
                id: 'fx-$d-$j',
                deckId: 'fx-$d',
                target: 'zav${_letters(d)}${_letters(j)}o',
                native: 'meaning $d x $j',
                pos: 'noun',
              ),
          ],
        ),
      );
    }
    data = PlacementLanguageData(
      language: 'fx',
      decks: all,
      levelMarkDecks: <int>[decks ~/ 3 - 1, 2 * decks ~/ 3 - 1, decks - 1],
    );
  }

  final int decks;
  final int perDeck;
  late final PlacementLanguageData data;

  int get a1End => data.levelMarkDecks[0];
  int get a2End => data.levelMarkDecks[1];
  int get b1End => data.levelMarkDecks[2];

  static String _letters(int n) {
    const a = 'bdgklmnprstv';
    return '${a[n % a.length]}${a[(n ~/ a.length) % a.length]}';
  }

  Card card(int d, int j) => data.decks[d].cards[j];

  /// Three other cards of the same deck for card ([d], [j]).
  List<Card> _near(int d, int j, int count) {
    final pool = <Card>[
      for (var k = 0; k < perDeck; k++)
        if (k != j) card(d, k),
      // The neighbouring deck when the deck has too few cards.
      if (d + 1 < decks) ...data.decks[d + 1].cards,
      if (d > 0) ...data.decks[d - 1].cards,
    ];
    return pool.take(count).toList();
  }

  /// The pick items the generators make for every card, in the formats the
  /// check may ask, plus a yes/no and a typed item the check must never ask.
  List<RegItem> items() {
    final out = <RegItem>[];
    for (var d = 0; d < decks; d++) {
      for (var j = 0; j < perDeck; j++) {
        final c = card(d, j);
        List<String> meanings(int n) {
          final near = _near(d, j, n);
          final list = <String>[c.native, for (final x in near) x.native];
          return list;
        }

        List<String> words(int n) {
          final near = _near(d, j, n);
          return <String>[c.target, for (final x in near) x.target];
        }

        RegItem pick(
          String format,
          String prompt,
          List<String> options, {
          String? roman,
          int nonCognate = -1,
        }) => RegItem(
          id: '${c.id}:$format',
          format: format,
          cardId: c.id,
          deck: d,
          prompt: prompt,
          promptRoman: roman,
          options: options,
          correct: 0,
          nonCognateContent: nonCognate,
          lemmas: <String>{'l${c.id}'},
        );

        out.add(pick('F2', c.target, meanings(3)));
        out.add(pick('F27', c.target, meanings(5)));
        out.add(pick('F3', c.native, words(3)));
        out.add(pick('F13', c.target, meanings(3)));
        out.add(pick('F26', c.target, meanings(5)));
        out.add(
          pick(
            'F28',
            '${c.target} ___',
            words(3),
            roman: 'a sentence about ${c.native}',
            nonCognate: 2,
          ),
        );
        // Formats the check must never ask.
        out.add(
          RegItem(
            id: '${c.id}:F7',
            format: 'F7',
            cardId: c.id,
            deck: d,
            prompt: c.native,
            accepted: <String>[c.target],
            lemmas: <String>{'l${c.id}'},
          ),
        );
        out.add(
          RegItem(
            id: '${c.id}:F1',
            format: 'F1',
            cardId: c.id,
            deck: d,
            prompt: c.target,
            lemmas: <String>{'l${c.id}'},
          ),
        );
      }
    }
    return out;
  }

  /// A bank where every card is checked twice.
  ReviewerBank bank({
    CheckedTwice? checkedTwice,
    Iterable<FixHistoryEntry> history = const <FixHistoryEntry>[],
    ItemPromotion promotion = const NoItemPromoted(),
  }) => ReviewerBank.build(
    data: data,
    items: items(),
    checkedTwice: checkedTwice ?? (_, _) => true,
    history: history,
    promotion: promotion,
  );
}
