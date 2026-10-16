import 'dart:io';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/aksharas.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/match_drill.dart';
import 'package:fluenough/features/drill/set_drill.dart';
import 'package:fluenough/features/drill/teach_drill.dart';
import 'package:fluenough/ui/widgets/target_text.dart';

import '../../support/harness.dart';

/// Set cards in a lesson (#515), as the approved mockup
/// `docs/mockups/set-cards.html` draws them: the set first, its members
/// marked New or Known, a split set in parts with a Full list, and the Full
/// list on an answered question.

const appendix = 'test/fixtures/b1/appendix-a/zz';
const home = 'zz-en-home';

/// The example set's files, with set cards added to its home deck: three
/// words, or five, split over two cards.
Map<String, String> files({bool split = false}) {
  final out = <String, String>{
    for (final file in Directory(appendix).listSync(recursive: true))
      if (file is File && file.path.endsWith('.yaml'))
        'decks/zz/${file.path.substring(appendix.length + 1)}': file
            .readAsStringSync(),
  };
  final members = split
      ? <String>['zz-9001', 'zz-9004', 'zz-9006', 'zz-9003', 'zz-9002']
      : <String>['zz-9001', 'zz-9004', 'zz-9006'];
  out['decks/zz/zz-home.yaml'] =
      '${out['decks/zz/zz-home.yaml']}'
      '  - id: "zz-9201"\n'
      '    kind: "set"\n'
      '    members: [${members.map((m) => '{ ref: "$m" }').join(', ')}]\n';
  out['decks/zz/en/zz-en-home.yaml'] = out['decks/zz/en/zz-en-home.yaml']!
      .replaceFirst(
        'cards:\n',
        'cards:\n'
            '  "zz-9201":\n'
            '    native: "First words"\n'
            '    explanation: "Words you meet first, together."\n',
      );
  return out;
}

AppState learner({bool split = false}) => AppState.test(
  decks: MemoryDeckSource(files(split: split)),
  progress: MemoryProgress(),
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['zz'],
  ),
);

DrillSession sessionOf(WidgetTester tester) {
  for (final widget in <Widget>[
    ...tester.widgetList(find.byType(SetDrill)),
    ...tester.widgetList(find.byType(TeachDrill)),
    ...tester.widgetList(find.byType(ChoiceDrill)),
    ...tester.widgetList(find.byType(MatchDrill)),
  ]) {
    return switch (widget) {
      SetDrill(:final session) => session,
      TeachDrill(:final session) => session,
      ChoiceDrill(:final session) => session,
      MatchDrill(:final session) => session,
      _ => throw StateError('$widget'),
    };
  }
  throw StateError('no drill');
}

Future<void> openLesson(WidgetTester tester, AppState state) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.lesson(language: 'zz', deckId: home),
  ),
  state: state,
);

void main() {
  testWidgets('the set comes first, every member new, and then the first '
      'member is taught', (tester) async {
    usePhone(tester);
    final state = learner();
    await openLesson(tester, state);
    final l10n = l10nOf(tester);
    expect(find.byType(SetDrill), findsOneWidget);
    expect(find.text(l10n.setTitle), findsOneWidget);
    expect(find.text('Words you meet first, together.'), findsOneWidget);
    expect(find.byType(SetMemberRow), findsNWidgets(3));
    expect(find.text(l10n.setNew), findsNWidgets(3));
    expect(find.text(l10n.setKnown), findsNothing);
    // It fits on one card: no Full list.
    expect(find.text(l10n.setFullList), findsNothing);
    expect(
      find.text(
        l10n.setNextWords(3, 'ఇల్లు (illu), అమ్మ (amma) and నేను (nēnu)'),
      ),
      findsOneWidget,
    );
    expect(
      find.text(l10n.drillPositionShort(1, sessionOf(tester).total)),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.commonContinue));
    await tester.pumpAndSettle();
    expect(find.byType(TeachDrill), findsOneWidget);
    expect(state.progress.log, isEmpty);
  });

  testWidgets('a known member is marked Known, and named as skipped', (
    tester,
  ) async {
    usePhone(tester);
    final state = learner();
    await state.load();
    final mother = state
        .deckById(home)!
        .cards
        .firstWhere((c) => c.id == 'zz-9004');
    state.record(
      SessionItem(card: mother, mode: DrillMode.recognition, state: null),
      4,
    );
    await openLesson(tester, state);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.setKnown), findsOneWidget);
    expect(find.text(l10n.setNew), findsNWidgets(2));
    expect(
      find.text(
        '${l10n.setNextWords(2, 'ఇల్లు (illu) and నేను (nēnu)')} '
        '${l10n.setKnownWords('అమ్మ (amma)')}',
      ),
      findsOneWidget,
    );
    // The known word is neither taught nor asked.
    final items = state.lessonFor(
      DrillRequest.lesson(language: 'zz', deckId: home),
    );
    expect(
      items.where((i) => i.card.id == 'zz-9004' && i.setPart == null),
      isEmpty,
    );
  });

  testWidgets('a split set shows its parts, each with a Full list', (
    tester,
  ) async {
    usePhone(tester);
    final state = learner(split: true);
    await openLesson(tester, state);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.setPartTitle(1, 2)), findsOneWidget);
    expect(find.byType(SetMemberRow), findsNWidgets(3));
    // Only the last part says what comes next.
    expect(find.textContaining('Next:'), findsNothing);
    expect(find.text(l10n.setFullList), findsOneWidget);

    await tester.tap(find.text(l10n.setFullList));
    await tester.pumpAndSettle();
    expect(find.text('First words'), findsOneWidget);
    expect(find.text(l10n.setSheetWords(5, 5)), findsOneWidget);
    expect(find.byType(SetMemberRow), findsNWidgets(3 + 5));
    await tester.tap(find.byTooltip(l10n.commonClose).last);
    await tester.pumpAndSettle();
    expect(find.byType(SetMemberRow), findsNWidgets(3));

    await tester.tap(find.text(l10n.commonContinue));
    await tester.pumpAndSettle();
    expect(find.text(l10n.setPartTitle(2, 2)), findsOneWidget);
    expect(find.textContaining('Next:'), findsOneWidget);
  });

  testWidgets('a question about a member of a split set shows the Full list '
      'only once answered', (tester) async {
    usePhone(tester);
    final state = learner(split: true);
    await openLesson(tester, state);
    final l10n = l10nOf(tester);
    // Past both parts, and on to a question about a member of the set.
    bool atMember() =>
        find.byType(ChoiceDrill).evaluate().isNotEmpty &&
        sessionOf(tester).item.card.id.startsWith('zz-90');
    while (!atMember()) {
      final session = sessionOf(tester);
      if (session.ask.onlyShows) {
        session.learnt();
      } else if (session.ask == Ask.matchPairs) {
        for (final entry in session.item.group) {
          session.match(entry, entry);
        }
        session.next();
      } else {
        session
          ..pick(
            session.options.firstWhere((o) => o.id == session.item.card.id),
          )
          ..next();
      }
      await tester.pumpAndSettle();
    }
    expect(find.text(l10n.setFullList), findsNothing);
    final session = sessionOf(tester);
    session.pick(
      session.options.firstWhere((o) => o.id == session.item.card.id),
    );
    await tester.pumpAndSettle();
    await scrollToFind(tester, find.text(l10n.setFullList));
    expect(find.text(l10n.setFullList), findsOneWidget);
  });

  testWidgets('a set card at 1.4x text lays out without overflow', (
    tester,
  ) async {
    usePhone(tester, textScale: 1.4, navBar: true);
    final state = learner(split: true);
    await openLesson(tester, state);
    expect(tester.takeException(), isNull);
    expect(find.byType(SetMemberRow), findsNWidgets(3));
  });

  testWidgets('a long word breaks only between its aksharas', (tester) async {
    usePhone(tester, textScale: 1.4);
    const word = 'తాగుతుందితాగుతుంది';
    const telugu = LanguageInfo(
      code: 'te',
      iso639_3: 'tel',
      name: 'Telugu',
      script: 'telugu',
    );
    await pumpScreen(
      tester,
      const Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            child: TargetText.hero(word, language: telugu),
          ),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText).last,
    );
    final shown = paragraph.text.toPlainText();
    expect(shown.replaceAll(breakOpportunity, ''), word);
    var at = 0;
    final lines = <double>{};
    for (final piece in shown.split(breakOpportunity)) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: at, extentOffset: at + piece.length),
      );
      // Every akshara on one line.
      expect(boxes.map((b) => b.top.round()).toSet(), hasLength(1));
      lines.add(boxes.first.top.roundToDouble());
      at += piece.length + 1;
    }
    expect(lines.length, greaterThan(1), reason: 'the word is long enough');
    // A screen reader reads the word as written.
    expect(find.bySemanticsLabel(word), findsOneWidget);
  });
}
