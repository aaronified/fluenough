// The picture choice on screen (#91): the word shown or heard, four pictures
// to choose from, a screen reader told nothing of what they show until the
// answer is in, and the answer recorded as Recognition.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/picture_choice_drill.dart';
import 'package:fluenough/features/drill/picture_tile.dart';
import 'package:fluenough/ui/widgets/feedback_banner.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const Map<String, (String, String)> things = <String, (String, String)>{
  'es-1': ('kalo', 'apple'),
  'es-2': ('mundu', 'dog'),
  'es-3': ('rifa', 'house'),
  'es-4': ('tosen', 'car'),
  'es-5': ('belu', 'tree'),
  'es-6': ('ganu', 'ball'),
};

const List<String> faces = <String>['🍎', '🐕', '🏠', '🚗', '🌳', '⚽'];

String deckYaml() {
  final rows = StringBuffer();
  var i = 0;
  for (final MapEntry(:key, :value) in things.entries) {
    rows.writeln(
      '  - { id: $key, target: "${value.$1}", native: "${value.$2}", '
      'pos: noun, picture: "${faces[i++]}" }',
    );
  }
  return '''
schema: 1
id: es-en-probe
name: Probe
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
$rows''';
}

AppState learner(MemoryProgress progress) => AppState.test(
  decks: MemoryDeckSource(<String, String>{
    'decks/es/es-en-probe.yaml': deckYaml(),
  }),
  progress: progress,
  tts: FixedTtsEngine(<String>{'es'}),
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['es'],
  ),
);

Future<(AppState, MemoryProgress)> open(
  WidgetTester tester, {
  Ask ask = Ask.choosePicture,
  ThemeMode themeMode = ThemeMode.light,
  TextDirection? direction,
}) async {
  final progress = MemoryProgress();
  final state = learner(progress);
  Widget page = DrillPage(
    request: DrillRequest.untaught('es-en-probe', skill: Skill.recognition),
    preset: DrillPreset(target: 'kalo', ask: ask),
  );
  if (direction != null) {
    page = Directionality(textDirection: direction, child: page);
  }
  await pumpScreen(tester, page, state: state, themeMode: themeMode);
  return (state, progress);
}

void main() {
  testWidgets('four pictures of the deck, and a screen reader is told only '
      '"Picture n of 4" until the answer is in', (tester) async {
    final semantics = tester.ensureSemantics();
    usePhone(tester);
    await open(tester);
    final l10n = l10nOf(tester);

    expect(find.byKey(const ValueKey<String>('picture')), findsNWidgets(4));
    expect(find.text('kalo'), findsOneWidget);
    for (var n = 1; n <= 4; n++) {
      expect(
        find.bySemanticsLabel(l10n.drillPictureOption(n, 4)),
        findsOneWidget,
      );
    }
    // Nothing says what a picture is: not the meanings, not the answer.
    for (final (_, meaning) in things.values) {
      expect(find.bySemanticsLabel(meaning), findsNothing);
      expect(find.text(meaning), findsNothing);
    }

    final session = tester
        .widget<PictureChoiceDrill>(find.byType(PictureChoiceDrill))
        .session;
    final right = session.options.indexWhere(
      (c) => c.id == session.item.card.id,
    );
    await tester.tap(find.byType(PictureTile).at(right));
    await tester.pumpAndSettle();

    // Answered: every picture says what it is, in words.
    for (final option in session.options) {
      expect(find.bySemanticsLabel(option.native), findsWidgets);
    }
    expect(find.bySemanticsLabel(l10n.drillPictureOption(1, 4)), findsNothing);
    expect(find.text(l10n.feedbackCorrect), findsOneWidget);
    // Disposed in the test body: the framework checks before teardowns run.
    semantics.dispose();
  });

  testWidgets('a right pick is recorded as Recognition, and only that', (
    tester,
  ) async {
    usePhone(tester);
    final (_, progress) = await open(tester);
    final session = tester
        .widget<PictureChoiceDrill>(find.byType(PictureChoiceDrill))
        .session;
    final card = session.item.card;
    expect(progress.stateOf(card.id, DrillMode.recognition), isNull);

    final right = session.options.indexWhere((c) => c.id == card.id);
    await tester.tap(find.byType(PictureTile).at(right));
    await tester.pumpAndSettle();

    final state = progress.stateOf(card.id, DrillMode.recognition)!;
    expect(state.repetitions, 1);
    expect(state.lapses, 0);
    for (final mode in DrillMode.drills) {
      if (mode != DrillMode.recognition) {
        expect(progress.stateOf(card.id, mode), isNull);
      }
    }
  });

  testWidgets('a wrong pick is a miss in Recognition, shows the answer, and '
      'the tiles stop taking taps', (tester) async {
    usePhone(tester);
    final (_, progress) = await open(tester);
    final l10n = l10nOf(tester);
    final session = tester
        .widget<PictureChoiceDrill>(find.byType(PictureChoiceDrill))
        .session;
    final card = session.item.card;
    final wrong = session.options.indexWhere((c) => c.id != card.id);
    await tester.tap(find.byType(PictureTile).at(wrong));
    await tester.pumpAndSettle();

    expect(find.text(l10n.feedbackWrong), findsOneWidget);
    expect(find.byType(FeedbackBanner), findsOneWidget);
    // A miss on a card never answered right is recorded (repetitions stay
    // 0) but is no lapse: a lapse is a miss after a right answer.
    final missed = progress.stateOf(card.id, DrillMode.recognition)!;
    expect(missed.repetitions, 0);
    expect(missed.lapses, 0);
    // A second tap changes nothing.
    final right = session.options.indexWhere((c) => c.id == card.id);
    await tester.tap(find.byType(PictureTile).at(right));
    await tester.pumpAndSettle();
    expect(session.isRight(session.picked!), isFalse);
    // Had the second tap counted as a right answer, repetitions would be 1.
    expect(progress.stateOf(card.id, DrillMode.recognition)!.repetitions, 0);
  });

  testWidgets('the heard form plays the word and does not write it until '
      'the answer is in', (tester) async {
    usePhone(tester);
    await open(tester, ask: Ask.hearPicture);
    expect(find.text('kalo'), findsNothing);
    expect(find.byKey(const ValueKey<String>('picture')), findsNWidgets(4));
    final session = tester
        .widget<PictureChoiceDrill>(find.byType(PictureChoiceDrill))
        .session;
    final right = session.options.indexWhere(
      (c) => c.id == session.item.card.id,
    );
    await tester.tap(find.byType(PictureTile).at(right));
    await tester.pumpAndSettle();
    expect(find.text('kalo'), findsWidgets);
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('at 1.4x text, ${mode.name}, answered or not, nothing '
        'overflows and the tiles stay in two rows of two', (tester) async {
      usePhone(tester, textScale: 1.4);
      await open(tester, themeMode: mode);
      expect(tester.takeException(), isNull);
      final tiles = find.byType(PictureTile);
      expect(tiles, findsNWidgets(4));
      expect(
        tester.getTopLeft(tiles.at(0)).dy,
        tester.getTopLeft(tiles.at(1)).dy,
      );
      expect(
        tester.getTopLeft(tiles.at(2)).dy,
        greaterThan(tester.getTopLeft(tiles.at(0)).dy),
      );
      await tester.tap(tiles.at(0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('right to left, the first picture is at the right', (
    tester,
  ) async {
    usePhone(tester);
    await open(tester, direction: TextDirection.rtl);
    final tiles = find.byType(PictureTile);
    expect(
      tester.getCenter(tiles.at(0)).dx,
      greaterThan(tester.getCenter(tiles.at(1)).dx),
    );
    expect(tester.takeException(), isNull);
  });
}
