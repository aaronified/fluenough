import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/decks/course_hours.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/path_fixture.dart';

import '../../support/harness.dart';

Future<AppState> teluguLearner() async {
  final app = AppState.test();
  await app.load();
  final state = PathFixtures.state(app, upTo: PathFixtures.familyDeck);
  await state.load();
  return state;
}

void main() {
  test('hours spent count each answer of the language, capped at a minute; '
      'hours left fall as pairs are remembered', () async {
    final state = await teluguLearner();
    final before = courseHours(state, 'te');
    expect(before.left, greaterThan(0));

    final deck = state.deckById(PathFixtures.familyDeck)!;
    final card = deck.cards.firstWhere(
      (c) => state.drillableModes(c).contains(DrillMode.recognition),
    );
    state.progress.record(
      deckId: deck.id,
      cardId: card.id,
      mode: DrillMode.recognition,
      grade: 4,
      now: DateTime.now(),
      elapsed: const Duration(minutes: 10),
    );
    final after = courseHours(state, 'te');
    expect(after.spent - before.spent, closeTo(60 / 3600, 1e-9));
    expect(after.left, lessThan(before.left));

    // Another language's hours are its own.
    expect(courseHours(state, 'zz'), (spent: 0.0, left: 0.0));
  });

  testWidgets('the course card shows the hours left in the decks so far and '
      'the hours spent', (tester) async {
    usePhone(tester);
    final state = await teluguLearner();
    await pumpScreen(tester, const DecksPage(), state: state);
    final hours = courseHours(state, 'te');
    expect(hours.left, greaterThan(0));
    final l10n = l10nOf(tester);
    expect(l10n.pathHoursTitle, 'Hours left in the decks so far');
    expect(find.text(l10n.pathHoursTitle), findsOneWidget);
    expect(
      find.text(
        l10n.pathHoursBody(
          l10n.pathHoursLeft(hours.left.ceil()),
          l10n.pathHoursSpent(hours.spent),
        ),
      ),
      findsOneWidget,
    );
    expect(l10n.pathHoursLeft(140), 'About 140 hours left');
    expect(l10n.pathHoursLeft(1), 'About 1 hour left');
    expect(l10n.pathHoursSpent(12.42), '12.4 hours spent so far');
  });
}
