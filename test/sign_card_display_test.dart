// Sign cards on screen (ADR-0056): a card whose target is a sign in FSW is
// shown by its picture, never by its text; a choice of signs offers four
// pictures; no typed question is asked of one; a symbol card, whose target is
// Unicode SignWriting, is the text it was.
import 'dart:convert';
import 'dart:io';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/card_media.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/picture_tile.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const Map<String, (String, String)> signs = <String, (String, String)>{
  'ase-0001': ('M507x507S10000487x492', 'ant'),
  'ase-0002': ('M507x507S10100487x492', 'bee'),
  'ase-0003': ('M507x507S10200487x492', 'cat'),
  'ase-0004': ('M507x507S10300487x492', 'dog'),
  'ase-0005': ('M507x507S10400487x492', 'eel'),
  'ase-0006': ('M507x507S10500487x492', 'fox'),
};

/// A one pixel PNG: real bytes, so the picture decodes.
final List<int> pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Every card's image is the same file on the phone.
class OneFile implements CardMedia {
  const OneFile(this.path);

  final String path;

  @override
  String? localPath(String path) => this.path;
}

String signDeck({String typed = 'typed: false', bool modes = true}) {
  final rows = StringBuffer();
  for (final MapEntry(:key, :value) in signs.entries) {
    rows.writeln(
      '  - { id: $key, target: "${value.$1}", native: "${value.$2}", '
      'image: "decks/ase/images/$key.webp", '
      'image_credit: { source: "https://example.org/s", license: "CC0-1.0", '
      'credit: "Test" }${modes ? ', modes: [listening, speaking]' : ''} }',
    );
  }
  return '''
schema: 1
id: ase-en-signs
name: Signs
language: { code: ase, iso639_3: ase, name: American Sign Language, script: signwriting, $typed }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
$rows''';
}

const String symbolDeck = '''
schema: 1
id: ase-en-symbols
name: Symbols
language: { code: ase, iso639_3: ase, name: American Sign Language, script: signwriting, typed: false }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: ase-0101, target: "\u{1D85A}", native: "flat hand", modes: [listening, speaking] }
  - { id: ase-0102, target: "\u{1D800}", native: "index finger", modes: [listening, speaking] }
  - { id: ase-0103, target: "\u{1D876}", native: "circle", modes: [listening, speaking] }
  - { id: ase-0104, target: "\u{1D866}", native: "claw hand", modes: [listening, speaking] }
''';

AppState learner(String deckId, String yaml, {bool voice = false}) {
  final file = File('${Directory.systemTemp.createTempSync().path}/sign.png')
    ..writeAsBytesSync(pixel);
  return AppState.test(
    decks: MemoryDeckSource(<String, String>{'decks/ase/$deckId.yaml': yaml}),
    progress: MemoryProgress(),
    media: OneFile(file.path),
    tts: voice
        ? FixedTtsEngine(const <String>{'ase', 'en'})
        : const NullTtsEngine(),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['ase'],
    ),
  );
}

void useSmallPhone(WidgetTester tester, {double textScale = 1.4}) {
  tester.view
    ..physicalSize = const Size(360 * 3, 800 * 3)
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<AppState> open(
  WidgetTester tester, {
  required String deckId,
  required String yaml,
  required String target,
  required Skill skill,
  Ask ask = Ask.own,
  ThemeMode themeMode = ThemeMode.light,
}) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.untaught(deckId, skill: skill),
    preset: DrillPreset(target: target, ask: ask),
  ),
  state: learner(deckId, yaml),
  themeMode: themeMode,
);

void main() {
  const first = 'M507x507S10000487x492';

  testWidgets('the drill shows a sign as its picture, never its text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    usePhone(tester);
    await open(
      tester,
      deckId: 'ase-en-signs',
      yaml: signDeck(),
      target: first,
      skill: Skill.recognition,
    );

    expect(find.byKey(const ValueKey<String>('sign-image')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('M507x507'), findsNothing);
    expect(find.textContaining('S10000'), findsNothing);
    // Recognition: a screen reader is told "Sign", not the meaning, which
    // is the answer.
    expect(find.bySemanticsLabel(l10nOf(tester).signImageLabel), findsOneWidget);
    expect(find.bySemanticsLabel('ant'), findsNothing);
    semantics.dispose();
  });

  testWidgets('choosing the sign: the meaning shown, four pictures, a right '
      'pick is right and a wrong one is told in words', (tester) async {
    usePhone(tester);
    final state = await open(
      tester,
      deckId: 'ase-en-signs',
      yaml: signDeck(),
      target: first,
      skill: Skill.production,
      ask: Ask.chooseWord,
    );
    final l10n = l10nOf(tester);

    expect(find.text('ant'), findsOneWidget);
    expect(find.byType(PictureTile), findsNWidgets(4));
    expect(find.byKey(const ValueKey<String>('sign-image')), findsNWidgets(4));
    expect(find.textContaining('M507x507'), findsNothing);

    final session = tester
        .widget<ChoiceDrill>(find.byType(ChoiceDrill))
        .session;
    expect(state.isTyped(session.item.card), isFalse);
    final right = session.options.indexWhere(
      (c) => c.id == session.item.card.id,
    );
    final wrong = session.options.indexWhere(
      (c) => c.id != session.item.card.id,
    );

    await tester.tap(find.byType(PictureTile).at(wrong));
    await tester.pumpAndSettle();
    expect(find.text(l10n.feedbackWrong), findsOneWidget);
    expect(find.text(l10n.feedbackAnswer('ant')), findsOneWidget);
    expect(find.textContaining('M507x507'), findsNothing);

    // A fresh drill, to pick right.
    await open(
      tester,
      deckId: 'ase-en-signs',
      yaml: signDeck(),
      target: first,
      skill: Skill.production,
      ask: Ask.chooseWord,
    );
    final again = tester.widget<ChoiceDrill>(find.byType(ChoiceDrill)).session;
    final at = again.options.indexWhere((c) => c.id == again.item.card.id);
    expect(at >= 0 && right >= 0, isTrue);
    await tester.tap(find.byType(PictureTile).at(at));
    await tester.pumpAndSettle();
    expect(find.text(l10n.feedbackCorrect), findsOneWidget);
  });

  testWidgets('no typed question is offered for a sign, whatever its '
      'language block says', (tester) async {
    usePhone(tester);
    final state = await open(
      tester,
      deckId: 'ase-en-signs',
      yaml: signDeck(typed: 'tts: en'),
      target: first,
      skill: Skill.production,
    );
    for (final card in signs.keys) {
      final found = state.decks
          .expand((d) => d.cards)
          .firstWhere((c) => c.id == card);
      expect(state.isTyped(found), isFalse, reason: card);
      expect(found.isSign, isTrue, reason: card);
      expect(found.hasPicture, isFalse, reason: card);
    }
  });

  testWidgets('a symbol card is the text it was, drawn with no picture', (
    tester,
  ) async {
    usePhone(tester);
    await open(
      tester,
      deckId: 'ase-en-symbols',
      yaml: symbolDeck,
      target: '\u{1D85A}',
      skill: Skill.recognition,
    );
    expect(find.byKey(const ValueKey<String>('sign-image')), findsNothing);
    expect(find.text('\u{1D85A}'), findsOneWidget);
  });

  testWidgets('a choice of signs offers only signs where the deck has enough', (
    tester,
  ) async {
    usePhone(tester);
    final mixed = signDeck() + symbolDeck.split('cards:\n').last;
    await open(
      tester,
      deckId: 'ase-en-signs',
      yaml: mixed,
      target: first,
      skill: Skill.production,
      ask: Ask.chooseWord,
    );
    final session = tester
        .widget<ChoiceDrill>(find.byType(ChoiceDrill))
        .session;
    expect(session.options, hasLength(4));
    expect(session.options.every((c) => c.isSign), isTrue);
    expect(find.byKey(const ValueKey<String>('sign-image')), findsNWidgets(4));
  });

  testWidgets('a deck with too few signs still asks, with the meaning for the '
      'other cards', (tester) async {
    usePhone(tester);
    final few = signDeck()
        .split('\n')
        .where((l) => !l.contains('ase-0004') && !l.contains('ase-0005'))
        .where((l) => !l.contains('ase-0006'))
        .join('\n');
    await open(
      tester,
      deckId: 'ase-en-signs',
      yaml: few + symbolDeck.split('cards:\n').last,
      target: first,
      skill: Skill.production,
      ask: Ask.chooseWord,
    );
    expect(find.byType(PictureTile), findsNWidgets(4));
    expect(find.textContaining('M507x507'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sign is never heard or said, voices or no, modes or none', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const SizedBox(),
      state: learner(
        'ase-en-signs',
        signDeck(modes: false, typed: 'tts: en'),
        voice: true,
      ),
    );
    final cards = state.decks.expand((d) => d.cards).toList();
    expect(cards, isNotEmpty);
    for (final card in cards) {
      final modes = state.drillableModes(card);
      expect(modes, isNot(contains(DrillMode.listening)), reason: card.id);
      expect(modes, isNot(contains(DrillMode.speaking)), reason: card.id);
    }
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('signs fit a 360 wide phone at 1.4x text, ${mode.name}', (
      tester,
    ) async {
      useSmallPhone(tester);
      await open(
        tester,
        deckId: 'ase-en-signs',
        yaml: signDeck(),
        target: first,
        skill: Skill.recognition,
        themeMode: mode,
      );
      // About 45% of the width: 162 of 360.
      final hero = tester.getSize(
        find.byKey(const ValueKey<String>('sign-image')),
      );
      expect(hero.width, closeTo(162, 1));
      expect(tester.takeException(), isNull);

      await open(
        tester,
        deckId: 'ase-en-signs',
        yaml: signDeck(),
        target: first,
        skill: Skill.production,
        ask: Ask.chooseWord,
        themeMode: mode,
      );
      expect(find.byType(PictureTile), findsNWidgets(4));
      final screen = tester.getSize(find.byType(Scaffold).first);
      for (final tile
          in tester.widgetList<PictureTile>(find.byType(PictureTile)).indexed) {
        final box = tester.getRect(find.byType(PictureTile).at(tile.$1));
        expect(box.right, lessThanOrEqualTo(screen.width));
        expect(box.left, greaterThanOrEqualTo(0));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
