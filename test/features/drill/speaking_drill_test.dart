import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/speaking_drill.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/voices_page.dart';

import '../../support/harness.dart';

/// The speaking drill, the switch that turns speaking on, and the Voices
/// page's speech section (#89, ADR-0014).

const String spanish = 'es-en-core-100';

AppState speakingState(FixedSpeechEngine speech, {bool on = true}) =>
    AppState.test(
      speech: speech,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
        enabledSkills: <Skill>{
          ...Skill.values.where((s) => s.onByDefault),
          if (on) Skill.speaking,
        },
      ),
    );

Future<AppState> pumpSpeaking(
  WidgetTester tester,
  FixedSpeechEngine speech,
) async {
  final state = speakingState(speech);
  await state.load();
  await state.startSpeech();
  await pumpScreen(
    tester,
    DrillPage(request: DrillRequest.deck(spanish, skill: Skill.speaking)),
    state: state,
  );
  return state;
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

Future<void> speak(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  final mic = find.bySemanticsLabel(l10n.drillSpeak);
  await tester.ensureVisible(mic);
  await tester.pumpAndSettle();
  await tester.tap(mic);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the meaning, hears the word and says it was right', (
    tester,
  ) async {
    usePhone(tester);
    final handle = tester.ensureSemantics();
    final speech = FixedSpeechEngine(onDevice: <String>{'es'});
    final state = await pumpSpeaking(tester, speech);
    final l10n = l10nOf(tester);
    expect(find.byType(SpeakingDrill), findsOneWidget);
    final card = state
        .buildSession(DrillRequest.deck(spanish, skill: Skill.speaking))
        .items
        .first
        .card;
    expect(find.text(l10n.drillSayIn('Spanish')), findsOneWidget);
    expect(find.text(card.native), findsOneWidget);

    speech.next = <SpeechAlternative>[SpeechAlternative(card.target)];
    await speak(tester);
    expect(find.text(l10n.feedbackCorrect), findsOneWidget);
    expect(state.progress.log.single.mode, DrillMode.speaking);
    expect(speech.listens.single.onDevice, isTrue);
    handle.dispose();
  });

  testWidgets('a wrong word says what was heard and the answer', (
    tester,
  ) async {
    usePhone(tester);
    final handle = tester.ensureSemantics();
    final speech = FixedSpeechEngine(onDevice: <String>{'es'});
    final state = await pumpSpeaking(tester, speech);
    final l10n = l10nOf(tester);
    final card = state
        .buildSession(DrillRequest.deck(spanish, skill: Skill.speaking))
        .items
        .first
        .card;
    speech.next = const <SpeechAlternative>[SpeechAlternative('el perro')];
    await speak(tester);
    expect(find.text(l10n.feedbackWrong), findsOneWidget);
    expect(
      find.text(l10n.feedbackSaidAnswer('el perro', card.target)),
      findsOneWidget,
    );
    expect(state.progress.log.single.grade, 1);
    handle.dispose();
  });

  testWidgets('nothing heard asks again and records nothing', (tester) async {
    usePhone(tester);
    final handle = tester.ensureSemantics();
    final speech = FixedSpeechEngine(onDevice: <String>{'es'});
    final state = await pumpSpeaking(tester, speech);
    final l10n = l10nOf(tester);
    await speak(tester);
    expect(find.text(l10n.drillUnheardNoMatch), findsOneWidget);
    expect(state.progress.log, isEmpty);
    handle.dispose();
  });

  testWidgets('a language the phone cannot hear by itself asks before going '
      'online, or skips the card unrecorded', (tester) async {
    usePhone(tester);
    final handle = tester.ensureSemantics();
    final speech = FixedSpeechEngine(online: <String>{'es'});
    final state = await pumpSpeaking(tester, speech);
    final l10n = l10nOf(tester);
    final items = state
        .buildSession(DrillRequest.deck(spanish, skill: Skill.speaking))
        .items;
    await speak(tester);
    expect(find.text(l10n.drillOnlineAsk('Spanish')), findsOneWidget);
    expect(speech.listens.single.onDevice, isTrue);

    speech.next = <SpeechAlternative>[
      SpeechAlternative(items.first.card.target),
    ];
    await tapText(tester, l10n.drillOnlineAllow('Spanish'));
    expect(state.settings.allowsOnlineSpeech('es'), isTrue);
    expect(speech.listens.last.onDevice, isFalse);
    expect(find.text(l10n.feedbackCorrect), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Skip this card moves on without recording', (tester) async {
    usePhone(tester);
    final handle = tester.ensureSemantics();
    final speech = FixedSpeechEngine(online: <String>{'es'});
    final state = await pumpSpeaking(tester, speech);
    final l10n = l10nOf(tester);
    await speak(tester);
    await tapText(tester, l10n.drillSkipCard);
    expect(state.progress.log, isEmpty);
    // The next card asks straight away, now that the phone is known not to
    // hear Spanish by itself.
    expect(
      state.speechStatus(state.deckById(spanish)!.language),
      SpeechStatus.onlineOnly,
    );
    handle.dispose();
  });

  testWidgets('the Speaking switch asks for the microphone, and stays off '
      'when it is refused', (tester) async {
    usePhone(tester);
    final speech = FixedSpeechEngine(onDevice: <String>{'es'}, grants: false);
    final state = await pumpApp(
      tester,
      state: speakingState(speech, on: false),
    );
    final l10n = l10nOf(tester);
    await tapText(tester, l10n.navSettings);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(speech.starts, 0);
    await tapText(tester, l10n.skillSpeaking);
    expect(speech.starts, 1);
    expect(state.settings.isEnabled(Skill.speaking), isFalse);
    expect(find.text(l10n.settingsSpeakingRefused), findsOneWidget);
  });

  testWidgets('the Speaking switch turns speaking on once the microphone is '
      'allowed', (tester) async {
    usePhone(tester);
    final speech = FixedSpeechEngine(onDevice: <String>{'es'});
    final state = await pumpApp(
      tester,
      state: speakingState(speech, on: false),
    );
    final l10n = l10nOf(tester);
    await tapText(tester, l10n.navSettings);
    await tapText(tester, l10n.skillSpeaking);
    expect(state.settings.isEnabled(Skill.speaking), isTrue);
    expect(state.speechReady, isTrue);
  });

  testWidgets('the Voices page offers to switch speaking on, then shows what '
      'each language can do', (tester) async {
    usePhone(tester);
    final speech = FixedSpeechEngine(
      onDevice: <String>{'es'},
      online: <String>{'hi'},
    );
    final state = speakingState(speech, on: false);
    await pumpScreen(tester, const VoicesPage(), state: state);
    final l10n = l10nOf(tester);
    await tester.scrollUntilVisible(
      find.text(l10n.voicesSpeechOff),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(l10n.voicesSpeechOff), findsOneWidget);
    await tapText(tester, l10n.voicesSpeechTurnOn);
    expect(state.settings.isEnabled(Skill.speaking), isTrue);

    await tester.scrollUntilVisible(
      find.text(l10n.voicesSpeechOnDevice).first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(l10n.voicesSpeechOnDevice), findsWidgets);
    expect(find.text(l10n.voicesSpeechMissing), findsWidgets);
  });

  testWidgets('every state fits at twice the text size, and meets the '
      'tap-target, label and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    Future<void> check(String state) async {
      expect(tester.takeException(), isNull, reason: state);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    for (final scale in <double>[1.0, 2.0]) {
      usePhone(tester, textScale: scale);
      // A fresh tree for each drill, rather than an update of the last.
      await tester.pumpWidget(const SizedBox.shrink());
      final speech = FixedSpeechEngine(onDevice: <String>{'es'});
      final state = await pumpSpeaking(tester, speech);
      await check('prompt $scale');
      speech.next = const <SpeechAlternative>[SpeechAlternative('el perro')];
      await speak(tester);
      await check('feedback $scale');
      expect(state.progress.log, hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      final offline = FixedSpeechEngine(online: <String>{'es'});
      await pumpSpeaking(tester, offline);
      await speak(tester);
      await check('online question $scale');
    }
    handle.dispose();
  });
}
