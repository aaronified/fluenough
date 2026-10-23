// A sentence that waits for words and rules (#416): the unit page greys it
// with what it waits for, a tap says why, and a lesson offers it only once
// every word and rule in it is known.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/unlocks.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/progress/unlocks.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:flutter/widgets.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// A Bengali sentence of the clothes unit: it names words and a rule.
const String _sentence = 'bn-1212';
const String _deck = 'bn-en-clothes-sentences';

Future<AppState> _bengali() async {
  final state = AppState.test(
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['bn'],
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

/// Answers the card [id] right ten times, so that it is known.
void _know(AppState state, String id) {
  final entry = state.decks.firstWhere((e) => e.cards.any((c) => c.id == id));
  for (var i = 0; i < 10; i++) {
    state.progress.record(
      deckId: entry.id,
      cardId: id,
      mode: DrillMode.recognition,
      grade: 4,
      now: state.now().subtract(Duration(days: 20 - i)),
    );
  }
}

void main() {
  test('a lesson offers a sentence only once every word and rule in it is '
      'known', () async {
    final state = await _bengali();
    final card = state.cardById(_sentence)!;
    expect(state.unlocks.isClosed(card), isTrue);
    expect(
      state.untaughtCards('bn', deckId: _deck).map((c) => c.id),
      isNot(contains(_sentence)),
    );

    // The last thing it waits for is known: a word, or a rule through one of
    // its cells.
    for (final need in state.unlocks.needsOf(card)) {
      final id = need.kind == NeedKind.word
          ? need.id
          : state.unlocks.cellsOf(need.id).first;
      _know(state, id);
    }
    expect(state.unlocks.waitingFor(card), isEmpty);
    expect(state.unlocks.isClosed(card), isFalse);
    expect(
      state.untaughtCards('bn', deckId: _deck).map((c) => c.id),
      contains(_sentence),
    );
  });

  testWidgets('the unit page greys a closed sentence with what it waits for, '
      'and a tap says why', (tester) async {
    usePhone(tester, textScale: 1.4);
    final state = await _bengali();
    await pumpScreen(tester, const UnitPage(deckId: _deck), state: state);
    final l10n = l10nOf(tester);

    final waiting = find.textContaining('Waiting for');
    await tester.scrollUntilVisible(
      waiting.first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(waiting, findsWidgets);
    expect(tester.takeException(), isNull, reason: 'no overflow at 1.4x');

    await tester.tap(waiting.first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.whyClosedTitle), findsOneWidget);
    expect(find.text(l10n.whyClosedIntro(9, 10)), findsOneWidget);
    expect(find.text(l10n.whyClosedReviewsNeverWait), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
