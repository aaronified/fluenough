// Pins which Ask a review chooses today, for every card of the frozen deck
// copy and every skill (docs/plans/question-engine.md, step 1). It is the
// safety net for the question engine's later steps: a step that is meant to
// change nothing must leave test/goldens/asks_pinned.txt as it is.
//
// What is recorded, per deck and card (see the golden's own header):
//  - the lesson's questions (lessonQuestions) and its Difficulty;
//  - for each skill the card can be drilled in, the Ask reviewAsks gives it
//    alone in a session, in four states: new, new where the learner starts at
//    recall (recallsFirst), last missed, and remembered;
//  - how many different options each kind of choice question can draw from
//    (choicePool), so that "no pool gets smaller" can be checked (step 3).
// Match pairs depends on the four items asked together, so a lone item is
// never recorded as matched; that grouping is not pinned here.
//
// The decks are a frozen copy under test/fixtures/ask_pin/, not decks/, so
// that this fails only when CODE changes which ask is chosen, and a deck-only
// pull request, which merges without Flutter checks (#524), cannot break it
// (owner, 2026-10-17: "Frozen deck copy"). The copy is three whole languages,
// not all nine, to stay near 1 MB: te has every card shape (vocabulary,
// grammar, rules cells, numbers, script and sound cards, layers), ipa is not
// typed, and es is a Latin-script language. Whole languages, because cards
// refer to their path and their sibling decks.
//
// Refresh the copy and the golden only for an intended change: new decks or
// a new card shape the pin should cover, or the path's unit order moving
// (the alphabet list decides hearsForm, "hf" below). Never in a deck pull
// request.
//   python3 tools/snapshot_ask_pin.py
//   UPDATE_ASK_PIN=1 flutter test test/core/scheduling/ask_pin_test.dart
// Without the variable the test compares and fails showing the first
// differences. It refuses to write when CI is set.

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/numbers/number_practice.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/lesson.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';

const String goldenPath = 'test/goldens/asks_pinned.txt';

/// The frozen copy's root: it holds decks/ and decks/index.json.
const String decksRoot = 'test/fixtures/ask_pin';

const List<String> states = <String>['new', 'recall', 'missed', 'known'];

FsrsState seen(int repetitions) => FsrsState(
  stability: 3,
  difficulty: 5,
  intervalDays: 3,
  dueAt: DateTime(2026, 9, 28),
  lastReviewAt: DateTime(2026, 9, 25),
  repetitions: repetitions,
);

/// Stable short id for a signature, so that a card's line does not change
/// when other signatures come or go.
String hashOf(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0').substring(0, 6);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('today\'s asks, for every card and skill, are as pinned', () async {
    final app = AppState.test(decks: RepositoryDeckSource(decksRoot));
    await app.load();

    String askOf(Card card, DrillMode mode, FsrsState? state, bool recall) {
      final item = SessionItem(card: card, mode: mode, state: state);
      final out = reviewAsks(
        <SessionItem>[item],
        canChoose: (i) =>
            app.canChoose(i.card, i.ask == Ask.own ? Ask.chooseMeaning : i.ask),
        hearsForm: (i) => app.hearsForm(i.card),
        recallsFirst: (i) => recall,
        typed: (i) => app.isTyped(i.card),
      );
      return out.single.ask.name;
    }

    String asksFor(Card card) {
      final modes = card.modesIn(ttsAvailable: true, speechAvailable: true);
      final parts = <String>[];
      for (final mode in DrillMode.values) {
        if (mode == DrillMode.reading || !modes.contains(mode)) continue;
        final asks = <String>[
          askOf(card, mode, null, false),
          askOf(card, mode, null, true),
          askOf(card, mode, seen(0), false),
          askOf(card, mode, seen(1), false),
        ];
        parts.add('${mode.name}=${asks.join(',')}');
      }
      return parts.join(' ');
    }

    String lessonFor(Card card, bool typed) {
      final qs = lessonQuestions(card, typed: typed);
      return '${Difficulty.of(card).name}:'
          '${qs.map((q) => '${q.mode.name}/${q.ask.name}').join(',')}';
    }

    int pool(Card card, Ask ask) =>
        app.choicePool(card, ask).map(ask.optionOf).toSet().length;

    String poolsFor(Card card) {
      final asks = card.rule != null
          ? <Ask>[Ask.chooseForm, Ask.chooseFormMeaning]
          : <Ask>[Ask.chooseMeaning, Ask.chooseWord];
      return asks.map((a) => pool(card, a)).join('/');
    }

    final signatures = <String, String>{}; // hash -> text
    final body = StringBuffer();
    for (final entry in app.decks) {
      final typed = entry.language.typed;
      body.writeln('## ${entry.id}');
      for (final card in entry.cards) {
        final sig =
            'hf=${app.hearsForm(card) ? 1 : 0} '
            'lesson=${lessonFor(card, typed)} ${asksFor(card)}';
        final key = hashOf(sig);
        final known = signatures[key];
        if (known != null && known != sig) fail('hash clash on $key');
        signatures[key] = sig;
        body.writeln('${card.id} $key ${poolsFor(card)}');
      }
    }

    // Generated numbers (NumberCard), a seeded few per number language.
    final numbers = StringBuffer('## numbers\n');
    final languages = <String>{};
    for (final entry in app.decks) {
      final rules = app.numberRulesFor(entry.language);
      if (rules == null || !languages.add(entry.language.code)) continue;
      final items = numberPractice(
        rules,
        deckId: entry.id,
        modes: numberPracticeModes.toSet(),
        random: Random(522),
        count: 9,
      );
      for (final item in items) {
        final asked = <String>[
          for (final s in <FsrsState?>[null, seen(0), seen(1)])
            askOf(item.card, item.mode, s, false),
        ];
        numbers.writeln(
          '${entry.language.code} ${item.card.id} ${item.mode.name}='
          '${asked.join(',')} '
          'hf=${app.hearsForm(item.card) ? 1 : 0} '
          'pools=${pool(item.card, Ask.chooseMeaning)}/'
          '${pool(item.card, Ask.chooseWord)}',
        );
      }
    }

    final out = StringBuffer()
      ..writeln('# Pinned asks (test/core/scheduling/ask_pin_test.dart).')
      ..writeln(
        '# Regenerate (see that file): UPDATE_ASK_PIN=1 flutter test <that file>',
      )
      ..writeln('# Card line: card-id signature pools')
      ..writeln(
        '# pools: distinct options for chooseMeaning/chooseWord, or for '
        'chooseForm/chooseFormMeaning on a rules cell',
      )
      ..writeln('# asks per skill, in order: ${states.join(',')}')
      ..writeln()
      ..writeln('# signatures');
    for (final k in signatures.keys.toList()..sort()) {
      out.writeln('$k ${signatures[k]}');
    }
    out
      ..writeln()
      ..write(body)
      ..writeln()
      ..write(numbers);
    final text = out.toString();

    final file = File(goldenPath);
    if (Platform.environment['UPDATE_ASK_PIN'] == '1') {
      if (Platform.environment.containsKey('CI')) {
        fail('refusing to write $goldenPath when CI is set');
      }
      // ignore: avoid_print
      print('UPDATE_ASK_PIN=1: writing $goldenPath');
      file.createSync(recursive: true);
      file.writeAsStringSync(text);
      return;
    }
    expect(file.existsSync(), isTrue, reason: 'run with UPDATE_ASK_PIN=1');
    final want = file.readAsStringSync().split('\n');
    final got = text.split('\n');
    final diffs = <String>[];
    for (
      var i = 0;
      i < max(want.length, got.length) && diffs.length < 20;
      i++
    ) {
      final w = i < want.length ? want[i] : '<end>';
      final g = i < got.length ? got[i] : '<end>';
      if (w != g) diffs.add('line ${i + 1}\n  pinned: $w\n  today:  $g');
    }
    expect(
      diffs,
      isEmpty,
      reason:
          'Asks changed (first ${diffs.length} differences). If intended, '
          'regenerate with UPDATE_ASK_PIN=1.\n${diffs.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}
