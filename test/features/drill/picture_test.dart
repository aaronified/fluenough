import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/ui/widgets/card_picture.dart';

import '../../support/harness.dart';

/// Pictures as cues (ADR-0034): beside the meaning in Write, and beside
/// each meaning Hear offers.
const String _deck = '''
schema: 1
id: es-fixture-pictures
name: "Spanish (pictures fixture)"
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-9101
    target: "la casa"
    native: "the house"
    picture: "🏠"
  - id: es-9102
    target: "el perro"
    native: "the dog"
  - id: es-9103
    target: "el pan"
    native: "the bread"
  - id: es-9104
    target: "la mesa"
    native: "the table"
''';

Future<void> pump(
  WidgetTester tester,
  Skill skill,
  String target,
  Ask ask,
) async {
  final state = AppState.test(
    decks: MemoryDeckSource(const <String, String>{
      'decks/es/es-fixture-pictures.yaml': _deck,
    }),
    tts: FixedTtsEngine(<String>{'es'}),
    speech: FixedSpeechEngine(onDevice: <String>{'es'}),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
      enabledSkills: Skill.values.toSet(),
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  await pumpScreen(
    tester,
    DrillPage(
      request: DrillRequest.untaught('es-fixture-pictures', skill: skill),
      preset: DrillPreset(target: target, ask: ask),
    ),
    state: state,
  );
}

Finder get picture => find.byKey(const ValueKey<String>('picture'));

void main() {
  test('a card reads its picture', () {
    final deck = DeckParser.parse(_deck, source: 'p.yaml');
    expect(deck.cards.first.picture, '🏠');
    expect(deck.cards[1].picture, isNull);
  });

  test('its image is named by its code points, as Noto names them', () {
    expect(picturePath('🏠'), 'assets/pictures/emoji_u1f3e0.png');
    expect(picturePath('☁️'), 'assets/pictures/emoji_u2601.png');
    expect(picturePath('🧑‍🏫'), 'assets/pictures/emoji_u1f9d1_200d_1f3eb.png');
  });

  testWidgets('Write shows the picture above the meaning', (tester) async {
    await pump(tester, Skill.production, 'la casa', Ask.own);
    expect(picture, findsOneWidget);
    expect(find.text('the house'), findsOneWidget);
  });

  testWidgets('choosing the word shows it too', (tester) async {
    await pump(tester, Skill.production, 'la casa', Ask.chooseWord);
    expect(picture, findsOneWidget);
  });

  testWidgets('a word with none shows none', (tester) async {
    await pump(tester, Skill.production, 'el perro', Ask.own);
    expect(picture, findsNothing);
  });

  testWidgets('Hear shows it beside its meaning among the options', (
    tester,
  ) async {
    await pump(tester, Skill.listening, 'el perro', Ask.hearMeaning);
    expect(find.text('the house'), findsOneWidget);
    expect(picture, findsOneWidget);
    expect(
      find.ancestor(of: picture, matching: find.byType(Row)),
      findsWidgets,
    );
  });

  testWidgets('the picture says nothing more to a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, Skill.production, 'la casa', Ask.own);
    expect(
      find.descendant(
        of: find.byType(CardPicture),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
