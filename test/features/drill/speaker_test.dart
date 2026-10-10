import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/ui/widgets/snack.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/grammar_drill.dart';
import 'package:fluenough/features/drill/match_drill.dart';
import 'package:fluenough/features/drill/pair_drill.dart';
import 'package:fluenough/features/drill/pair_fixture.dart';
import 'package:fluenough/features/drill/reading_fixture.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/ui/widgets/play_button.dart';
import 'package:fluenough/ui/widgets/speaker.dart';

import '../../support/harness.dart';

/// A speaker on every drill card (the owner's spec): a tap plays, a long
/// press switches Play words automatically, every tenth tap says so, and
/// with sound off it is greyed out and says why.

const String spanish = 'es-en-core-100';
const String hindi = 'hi-en-phrasebook';

AppState voiced({SettingsNotifier? settings, FixedTtsEngine? tts}) =>
    AppState.test(
      tts: tts ?? FixedTtsEngine(const <String>{'es', 'hi'}),
      settings: settings,
    );

/// [state]'s settings, past the first launch, with [change] made.
SettingsNotifier settingsWith(void Function(SettingsNotifier s) change) {
  final s = SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningChosen: true,
  );
  change(s);
  return s;
}

Future<AppState> pumpAsked(
  WidgetTester tester, {
  required Skill skill,
  required AppState state,
  String deck = spanish,
  String target = 'la casa',
  Ask ask = Ask.own,
}) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.untaught(deck, skill: skill),
    preset: DrillPreset(target: target, ask: ask),
  ),
  state: state,
);

Finder get speaker => find.byType(Speaker);

PlayButton playButton(WidgetTester tester) => tester.widget<PlayButton>(
  find.descendant(of: speaker, matching: find.byType(PlayButton)),
);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> clearSnackBars(WidgetTester tester) async {
  hideAppSnackBar();
  await tester.pumpAndSettle();
}

Card cardOf(AppState state, String deck, String target) =>
    state.deckById(deck)!.cards.firstWhere((c) => c.target == target);

void main() {
  group('a tap', () {
    testWidgets('plays the word on recognition, from the start, and showing '
        'the answer keeps it without playing it again', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      await pumpAsked(
        tester,
        skill: Skill.recognition,
        state: voiced(tts: tts),
      );
      final l10n = l10nOf(tester);
      expect(speaker, findsOneWidget);
      expect(tts.spoken, isEmpty, reason: 'not automatically, by default');

      await tester.tap(speaker);
      await tester.pumpAndSettle();
      expect(tts.spoken.single.text, 'la casa');

      await tapVisible(tester, find.text(l10n.drillShowAnswer));
      expect(speaker, findsOneWidget);
      expect(tts.spoken, hasLength(1));
    });

    testWidgets('no speaker where the phone has no voice', (tester) async {
      usePhone(tester);
      await pumpAsked(tester, skill: Skill.recognition, state: AppState.test());
      expect(speaker, findsNothing);
    });

    testWidgets('every tenth, while words do not play automatically, says '
        'that a long press makes them', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      final state = await pumpAsked(
        tester,
        skill: Skill.recognition,
        state: voiced(tts: tts),
      );
      final l10n = l10nOf(tester);
      for (var i = 1; i < SpeakerActions.tipEvery; i++) {
        await tester.tap(speaker);
        await tester.pumpAndSettle();
        expect(find.text(l10n.speakerAutoplayTip), findsNothing, reason: '$i');
      }
      expect(state.settings.speakerTaps, 9);
      await tester.tap(speaker);
      await tester.pumpAndSettle();
      expect(find.text(l10n.speakerAutoplayTip), findsOneWidget);
      expect(tts.spoken, hasLength(10), reason: 'the tenth plays too');

      // With words playing automatically, no tip, and taps not counted.
      await clearSnackBars(tester);
      state.settings.autoplay = true;
      for (var i = 0; i < SpeakerActions.tipEvery; i++) {
        await tester.tap(speaker);
        await tester.pumpAndSettle();
      }
      expect(find.text(l10n.speakerAutoplayTip), findsNothing);
      expect(state.settings.speakerTaps, 10);
    });
  });

  testWidgets('a long press switches playing words automatically, and says '
      'which it is now', (tester) async {
    usePhone(tester);
    final tts = FixedTtsEngine(const <String>{'es'});
    final state = await pumpAsked(
      tester,
      skill: Skill.recognition,
      state: voiced(tts: tts),
    );
    final l10n = l10nOf(tester);
    await tester.longPress(speaker);
    await tester.pumpAndSettle();
    expect(state.settings.autoplay, isTrue);
    expect(find.text(l10n.speakerAutoplayOn), findsOneWidget);

    await tester.longPress(speaker);
    await tester.pumpAndSettle();
    expect(state.settings.autoplay, isFalse);
    expect(find.text(l10n.speakerAutoplayOff), findsOneWidget);
    expect(tts.spoken, isEmpty, reason: 'a long press plays nothing');
    expect(state.settings.speakerTaps, 0);
  });

  testWidgets('a listening question\'s play button does the same: a long '
      'press switches playing words automatically', (tester) async {
    usePhone(tester);
    final state = await pumpAsked(
      tester,
      skill: Skill.listening,
      state: voiced(),
      ask: Ask.hearAndChoose,
    );
    final l10n = l10nOf(tester);
    expect(speaker, findsOneWidget);
    await tester.longPress(speaker);
    await tester.pumpAndSettle();
    expect(state.settings.autoplay, isTrue);
    expect(find.text(l10n.speakerAutoplayOn), findsOneWidget);
  });

  group('with sound off', () {
    testWidgets('a speaker is greyed out; a tap or a long press says sound '
        'is off, and nothing plays or changes', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      final state = await pumpAsked(
        tester,
        skill: Skill.recognition,
        state: voiced(
          tts: tts,
          settings: settingsWith((s) => s.soundOn = false),
        ),
      );
      final l10n = l10nOf(tester);
      expect(playButton(tester).muted, isTrue);
      expect(playButton(tester).onPressed, isNotNull, reason: 'still tapped');
      expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);

      await tester.tap(speaker);
      await tester.pumpAndSettle();
      expect(find.text(l10n.speakerSoundOff), findsOneWidget);
      expect(tts.spoken, isEmpty);
      expect(state.settings.speakerTaps, 0);

      await clearSnackBars(tester);
      await tester.longPress(speaker);
      await tester.pumpAndSettle();
      expect(find.text(l10n.speakerSoundOff), findsOneWidget);
      expect(state.settings.autoplay, isFalse);

      state.settings.soundOn = true;
      await tester.pumpAndSettle();
      expect(playButton(tester).muted, isFalse);
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    });

    testWidgets('a listening question\'s button is greyed out too', (
      tester,
    ) async {
      usePhone(tester);
      // The preset puts the card first even though sound off leaves
      // listening out of the session.
      final tts = FixedTtsEngine(const <String>{'es'});
      await pumpAsked(
        tester,
        skill: Skill.listening,
        state: voiced(
          tts: tts,
          settings: settingsWith((s) => s.soundOn = false),
        ),
      );
      expect(find.byType(TypedDrill), findsOneWidget);
      expect(playButton(tester).muted, isTrue);
      await tester.tap(speaker);
      await tester.pumpAndSettle();
      expect(find.text(l10nOf(tester).speakerSoundOff), findsOneWidget);
      expect(tts.spoken, isEmpty);
    });

    testWidgets('the teach card plays nothing', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      await pumpScreen(
        tester,
        DrillPage(request: DrillRequest.lesson(language: 'es')),
        state: voiced(
          tts: tts,
          settings: settingsWith((s) => s.soundOn = false),
        ),
      );
      expect(playButton(tester).muted, isTrue);
      expect(tts.spoken, isEmpty);
    });

    testWidgets('listening cards left in a session are skipped once sound is '
        'turned off', (tester) async {
      usePhone(tester);
      final state = voiced();
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(spanish, skill: Skill.listening),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      // New pairs, so Hear asks for the meaning to be chosen (ADR-0034).
      final session = tester
          .widget<ChoiceDrill>(find.byType(ChoiceDrill))
          .session;
      expect(session.total, greaterThan(1));
      state.settings.soundOn = false;
      session.pick(
        session.options.firstWhere(
          (option) => option.id != session.item.card.id,
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text(l10n.commonContinue));
      expect(session.finished, isTrue);
      expect(find.byType(SummaryPage), findsOneWidget);
    });
  });

  group('words played automatically', () {
    AppState autoplaying(FixedTtsEngine tts) =>
        voiced(tts: tts, settings: settingsWith((s) => s.autoplay = true));

    testWidgets('recognition plays the word as the card shows, once', (
      tester,
    ) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      await pumpAsked(
        tester,
        skill: Skill.recognition,
        state: autoplaying(tts),
      );
      expect(tts.spoken.single.text, 'la casa');
      await tapVisible(tester, find.text(l10nOf(tester).drillShowAnswer));
      expect(tts.spoken, hasLength(1));
    });

    testWidgets('choosing the meaning plays the word as it shows', (
      tester,
    ) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      await pumpAsked(
        tester,
        skill: Skill.recognition,
        state: autoplaying(tts),
        ask: Ask.chooseMeaning,
      );
      expect(speaker, findsOneWidget);
      expect(tts.spoken.single.text, 'la casa');
    });

    testWidgets('a listening question plays as it shows', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      await pumpAsked(tester, skill: Skill.listening, state: autoplaying(tts));
      expect(tts.spoken.single.text, 'la casa');
    });

    testWidgets('typed production: no speaker until the answer is in, then '
        'it plays', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      await pumpAsked(tester, skill: Skill.production, state: autoplaying(tts));
      final l10n = l10nOf(tester);
      expect(speaker, findsNothing);
      await tester.enterText(find.byType(TextField), 'la casa');
      await tester.pump();
      await tapVisible(tester, find.text(l10n.drillCheck));
      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
      expect(speaker, findsOneWidget);
      expect(tts.spoken.single.text, 'la casa');
    });

    testWidgets('choosing the word: no speaker until it is chosen', (
      tester,
    ) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      final state = await pumpAsked(
        tester,
        skill: Skill.production,
        state: autoplaying(tts),
        ask: Ask.chooseWord,
      );
      expect(speaker, findsNothing);
      expect(tts.spoken, isEmpty);
      await tapVisible(
        tester,
        find.text(cardOf(state, spanish, 'la casa').target),
      );
      expect(speaker, findsOneWidget);
      expect(tts.spoken.single.text, 'la casa');
    });

    testWidgets('rearrange: no speaker until the words are checked', (
      tester,
    ) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'hi'});
      final state = await pumpAsked(
        tester,
        deck: hindi,
        skill: Skill.production,
        target: 'आप कैसे हैं?',
        state: autoplaying(tts),
        ask: Ask.rearrange,
      );
      final l10n = l10nOf(tester);
      final card = cardOf(state, hindi, 'आप कैसे हैं?');
      expect(speaker, findsNothing);
      for (final word in tilesOf(card.reading!)) {
        await tapVisible(tester, find.text(word));
      }
      await tapVisible(tester, find.text(l10n.drillCheck));
      expect(speaker, findsOneWidget);
      expect(tts.spoken.single.text, card.target);
    });

    testWidgets('grammar: no speaker until the form is in', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(
            grammarFixtureDeckId,
            skill: Skill.grammar,
          ),
        ),
        state: autoplaying(tts),
      );
      final l10n = l10nOf(tester);
      final drill = tester.widget<GrammarDrill>(find.byType(GrammarDrill));
      final card = drill.session!.item.card;
      expect(speaker, findsNothing);
      await tapVisible(tester, find.text(l10n.drillDontKnow));
      expect(speaker, findsOneWidget);
      expect(tts.spoken.single.text, card.target);
    });

    testWidgets('speaking: no speaker until it is said', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      final state = AppState.test(
        tts: tts,
        speech: FixedSpeechEngine(onDevice: <String>{'es'}),
        settings: settingsWith(
          (s) => s
            ..autoplay = true
            ..setSkillEnabled(Skill.speaking, true),
        ),
      );
      await state.load();
      // Speaking enters a session only once the recogniser is ready.
      await state.startSpeech();
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(spanish, skill: Skill.speaking),
        ),
        state: state,
      );
      expect(speaker, findsNothing);
      await tapVisible(tester, find.text(l10nOf(tester).drillDontKnow));
      expect(speaker, findsOneWidget);
      expect(tts.spoken, hasLength(1));
    });

    testWidgets('the teach card plays as it shows, whether or not words play '
        'automatically', (tester) async {
      usePhone(tester);
      for (final autoplay in <bool>[false, true]) {
        final tts = FixedTtsEngine(const <String>{'es'});
        final state = voiced(
          tts: tts,
          settings: settingsWith((s) => s.autoplay = autoplay),
        );
        await pumpScreen(
          tester,
          DrillPage(
            key: UniqueKey(),
            request: DrillRequest.lesson(language: 'es'),
          ),
          state: state,
        );
        final card = state.lessonFor(DrillRequest.lesson(language: 'es')).first;
        expect(card.ask, Ask.teach);
        expect(tts.spoken.single.text, card.card.target, reason: '$autoplay');
      }
    });

    testWidgets('match pairs has no speaker of its own; a word tile tapped '
        'says its word whether or not words play automatically (ADR-0032)', (
      tester,
    ) async {
      usePhone(tester);
      for (final autoplay in <bool>[true, false]) {
        final tts = FixedTtsEngine(const <String>{'es'});
        // A key of its own, so that the second round is a new drill on its
        // new state rather than the first round's, still on screen.
        await pumpScreen(
          tester,
          DrillPage(
            key: UniqueKey(),
            request: DrillRequest.untaught(spanish, skill: Skill.recognition),
            preset: const DrillPreset(target: 'la casa', ask: Ask.matchPairs),
          ),
          state: voiced(
            tts: tts,
            settings: settingsWith((s) => s.autoplay = autoplay),
          ),
        );
        expect(find.byType(MatchDrill), findsOneWidget);
        expect(speaker, findsNothing);
        await tapVisible(tester, find.text('la casa'));
        expect(tts.spoken.map((s) => s.text), <String>[
          'la casa',
        ], reason: '$autoplay');
      }
    });

    testWidgets('a minimal pair plays as each round shows', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'hi'});
      final state = AppState.test(
        tts: tts,
        settings: settingsWith((s) => s.autoplay = true),
        features: const FeatureRegistry.only(<Feature>{
          ...Feature.available,
          Feature.drillPair,
        }),
      );
      await pumpScreen(tester, const PairDrill(), state: state);
      expect(tts.spoken.single.text, pairFixtureRounds.first.heard.target);
      await tapVisible(
        tester,
        find.text(pairFixtureRounds.first.pair.a.target),
      );
      await tapVisible(tester, find.text(l10nOf(tester).commonContinue));
      expect(tts.spoken.map((s) => s.text), <String>[
        pairFixtureRounds[0].heard.target,
        pairFixtureRounds[1].heard.target,
      ]);
    });

    testWidgets('a passage plays as it shows, read or heard, but not again '
        'on each of its questions', (tester) async {
      usePhone(tester);
      for (final skill in <Skill>[Skill.reading, Skill.listening]) {
        final tts = FixedTtsEngine(const <String>{'bn'});
        final state = AppState.test(
          decks: readingFixtureDecks(),
          tts: tts,
          settings: settingsWith((s) => s.autoplay = true),
        );
        await pumpScreen(
          tester,
          DrillPage(
            key: UniqueKey(),
            request: DrillRequest.untaught(readingFixtureDeckId, skill: skill),
          ),
          state: state,
        );
        final sentences = state
            .deckById(readingFixtureDeckId)!
            .deck
            .passages
            .first
            .sentences;
        expect(tts.spoken, hasLength(sentences.length), reason: '$skill');
        await tapVisible(tester, find.text(l10nOf(tester).readingToQuestions));
        expect(tts.spoken, hasLength(sentences.length), reason: '$skill');
      }
    });
  });

  testWidgets('a passage\'s sentence buttons are greyed out with sound off, '
      'and say so when tapped', (tester) async {
    usePhone(tester);
    final tts = FixedTtsEngine(const <String>{'bn'});
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.untaught(
          readingFixtureDeckId,
          skill: Skill.reading,
        ),
      ),
      state: AppState.test(
        decks: readingFixtureDecks(),
        tts: tts,
        settings: settingsWith((s) => s.soundOn = false),
      ),
    );
    final l10n = l10nOf(tester);
    final sentences = find.byType(SpeakerIcon);
    expect(sentences, findsNWidgets(4));
    expect(
      find.descendant(
        of: sentences.first,
        matching: find.byIcon(Icons.volume_off_outlined),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip(l10n.readingPlaySentence).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.speakerSoundOff), findsOneWidget);
    expect(tts.spoken, isEmpty);
  });
}
