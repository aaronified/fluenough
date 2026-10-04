import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/reading.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/features/drill/drill_session.dart';

/// The options of a multiple-choice question are shown in a new order each
/// time (#148), so the answer is not always in the same place.

const String sahajPath = 'bn-en-reading-sahaj-path-1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;
  late List<SessionItem> fromChoice;

  setUp(() async {
    state = AppState.test();
    await state.load();
    final items = state
        .buildSession(DrillRequest.untaught(sahajPath, skill: Skill.reading))
        .items;
    // The session from its first question with options.
    final first = items.indexWhere(
      (i) => !(i.card as QuestionCard).question.isTrueFalse,
    );
    fromChoice = items.sublist(first);
  });

  tearDown(() => state.dispose());

  test('every option is shown once, and the order changes', () {
    final orders = <String>{};
    for (var seed = 0; seed < 12; seed++) {
      final session = DrillSession(
        state: state,
        items: fromChoice,
        random: Random(seed),
      );
      final count = session.question!.question.choiceCount;
      final order = session.choiceOrder;
      expect(order.toList()..sort(), List<int>.generate(count, (i) => i));
      // Asked twice, the same order: it is drawn once per showing.
      expect(session.choiceOrder, order);
      orders.add(order.join());
      session.dispose();
    }
    expect(orders.length, greaterThan(1));
  });
}
