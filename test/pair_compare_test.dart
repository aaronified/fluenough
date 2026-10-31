// The minimal-pair button and popup (#423, owner, 2026-10-31): a full-screen
// popup of two words side by side, stacked only when a word would wrap, to
// play, say and guess, and which records nothing.
import 'dart:math';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/card_blocks.dart';
import 'package:fluenough/features/drill/pair_compare.dart';
import 'package:fluenough/features/drill/taught_details.dart'
    show TaughtDetails, TaughtReading;
import 'package:fluenough/features/drill/teach_card.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

String _deck(String longMeaning) =>
    '''
schema: 1
id: es-en-probe
name: "Probe"
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: es-9001, target: "gato", native: "cat", pair: es-9002 }
  - { id: es-9002, target: "gata", native: "$longMeaning" }
  - { id: es-9003, target: "pero", native: "but", pair: es-9004, warning: none }
  - { id: es-9004, target: "perro", native: "dog" }
''';

class _Rig {
  _Rig(this.state, this.tts, this.speech);

  final AppState state;
  final FixedTtsEngine tts;
  final FixedSpeechEngine speech;

  Card get first => findCard(state, 'es-9001')!;
  Card get second => findCard(state, 'es-9002')!;
  LanguageInfo get language => state.deckOf(first)!.language;
}

Future<_Rig> _rig({String partnerMeaning = 'she-cat'}) async {
  final tts = FixedTtsEngine(<String>{'es'});
  final speech = FixedSpeechEngine(onDevice: <String>{'es'});
  final state = AppState.test(
    decks: MemoryDeckSource(<String, String>{
      'decks/es/es-en-probe.yaml': _deck(partnerMeaning),
    }),
    tts: tts,
    speech: speech,
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
      enabledSkills: <Skill>{
        ...Skill.values.where((s) => s.onByDefault),
        Skill.speaking,
      },
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  await state.startSpeech();
  return _Rig(state, tts, speech);
}

/// The teach card of "gato", with its Compare button, on a phone at 1.4x
/// text, and the popup the button opens, given a seed for the guessing.
Future<void> _open(WidgetTester tester, _Rig rig, {int seed = 1}) async {
  usePhone(tester, textScale: 1.4);
  await pumpScreen(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showPairCompare(
              context,
              card: rig.first,
              partner: rig.second,
              language: rig.language,
              random: Random(seed),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    state: rig.state,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the teach card of a word with a pair note offers Compare, '
      'which opens a popup with a close cross, and closes it', (tester) async {
    final rig = await _rig();
    usePhone(tester, textScale: 1.4);
    await pumpScreen(
      tester,
      Scaffold(
        body: TeachCard(
          card: rig.first,
          language: rig.language,
          reading: TaughtReading.always,
        ),
      ),
      state: rig.state,
    );
    final l10n = l10nOf(tester);
    expect(find.byType(PairCompareButton), findsOneWidget);
    await tester.ensureVisible(find.byType(PairCompareButton));
    await tester.tap(find.byType(PairCompareButton));
    await tester.pumpAndSettle();
    expect(find.text(l10n.pairCompareSounds), findsOneWidget);
    expect(find.text(l10n.pairPracticeOnly), findsOneWidget);
    expect(findTarget('gata'), findsWidgets);
    await tester.tap(find.byTooltip(l10n.hintClose));
    await tester.pumpAndSettle();
    expect(find.text(l10n.pairCompareSounds), findsNothing);
  });

  testWidgets('the details of a card with a pair offer Compare, but not when '
      'the card says warning none', (tester) async {
    final rig = await _rig();
    usePhone(tester);
    Future<void> show(String id) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: TaughtDetails(
              key: ValueKey<String>(id),
              card: findCard(rig.state, id)!,
              language: rig.language,
              reading: TaughtReading.always,
            ),
          ),
        ),
        state: rig.state,
      );
    }

    await show('es-9001');
    expect(find.byType(PairCompareButton), findsOneWidget);
    await show('es-9003');
    expect(find.byType(PairCompareButton), findsNothing);
  });

  testWidgets('a word with no pair note has no button', (tester) async {
    final rig = await _rig();
    usePhone(tester);
    await pumpScreen(
      tester,
      Scaffold(
        body: TeachCard(
          card: rig.second,
          language: rig.language,
          reading: TaughtReading.always,
        ),
      ),
      state: rig.state,
    );
    expect(find.byType(PairCompareButton), findsNothing);
  });

  testWidgets('the words stand side by side, and stack only when one would '
      'wrap', (tester) async {
    var rig = await _rig();
    await _open(tester, rig);
    expect(
      tester.getCenter(findTarget('gato')).dy,
      tester.getCenter(findTarget('gata')).dy,
    );
    expect(
      tester.getCenter(findTarget('gato')).dx,
      lessThan(tester.getCenter(findTarget('gata')).dx),
    );

    rig = await _rig(partnerMeaning: 'a female cat, as a pet is called');
    await _open(tester, rig);
    expect(
      tester.getCenter(findTarget('gata')).dy,
      greaterThan(tester.getCenter(findTarget('gato')).dy + 50),
    );
  });

  testWidgets('Say one says what the phone heard and which word it matched, '
      'never right or wrong, and records nothing', (tester) async {
    final rig = await _rig();
    await _open(tester, rig);
    final l10n = l10nOf(tester);

    rig.speech.next = <SpeechAlternative>[const SpeechAlternative('gata')];
    await tester.tap(find.byTooltip(l10n.hintSpeak));
    await tester.pumpAndSettle();
    expect(find.text(l10n.pairMatchedTag), findsOneWidget);
    expect(
      find.textContaining(l10n.pairMatchedWord('gata'), findRichText: true),
      findsOneWidget,
    );
    expect(find.text(l10n.pairCaveat), findsOneWidget);

    rig.speech.next = <SpeechAlternative>[const SpeechAlternative('perro')];
    await tester.tap(find.byTooltip(l10n.hintSpeak));
    await tester.pumpAndSettle();
    expect(find.text(l10n.pairMatchedTag), findsNothing);
    expect(
      find.textContaining(l10n.pairMatchedNeither, findRichText: true),
      findsOneWidget,
    );

    rig.speech.next = const <SpeechAlternative>[];
    await tester.tap(find.byTooltip(l10n.hintSpeak));
    await tester.pumpAndSettle();
    expect(find.text(l10n.drillUnheardNoMatch), findsOneWidget);
    expect(rig.state.progress.log, isEmpty);
  });

  testWidgets('Which did you hear plays one word, says right or wrong only '
      'once a word is tapped, and records nothing', (tester) async {
    final rig = await _rig();
    await _open(tester, rig);
    final l10n = l10nOf(tester);

    Finder answer(String word) => find.descendant(
      of: find.byType(OutlinedButton),
      matching: findTarget(word),
    );

    String named(String word) {
      final card = word == 'gato' ? rig.first : rig.second;
      return l10n.cardPartnerNoReading(card.target, card.native);
    }

    Finder said(String text) => find.textContaining(text, findRichText: true);

    await tester.tap(find.text(l10n.pairPlayOne));
    await tester.pumpAndSettle();
    var played = rig.tts.spoken.last.text;
    expect(said(l10n.pairRight(named(played))), findsNothing);
    await tester.ensureVisible(answer(played));
    await tester.tap(answer(played));
    await tester.pumpAndSettle();
    expect(said(l10n.pairRight(named(played))), findsOneWidget);

    await tester.ensureVisible(find.text(l10n.pairPlayAnother));
    await tester.tap(find.text(l10n.pairPlayAnother));
    await tester.pumpAndSettle();
    played = rig.tts.spoken.last.text;
    final other = played == 'gato' ? 'gata' : 'gato';
    await tester.ensureVisible(answer(other));
    await tester.tap(answer(other));
    await tester.pumpAndSettle();
    expect(said(l10n.pairWrong(named(played), other)), findsOneWidget);
    expect(rig.state.progress.log, isEmpty);
  });
}
