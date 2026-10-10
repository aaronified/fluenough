import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/features/settings/speech_test_sheet.dart';
import 'package:fluenough/features/settings/voices_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/harness.dart';
import '../../support/review_fixture.dart';

// One Voices card per language, with a test for hearing it and for
// speaking it (docs/plans/voices-per-language.md).

/// A phone tall enough for every bundled language's card.
void _useTallPhone(WidgetTester tester, {double textScale = 1.0}) {
  usePhone(tester, textScale: textScale);
  tester.view.physicalSize = const Size(390 * 3, 9000 * 3);
}

/// A recogniser whose listen goes on until it is stopped, as a phone's
/// does while the learner has not spoken.
class _UntilStopped extends FixedSpeechEngine {
  _UntilStopped() : super(onDevice: <String>{'hi', 'es'});

  Completer<SpeechHeard>? _pending;
  int stops = 0;

  @override
  Future<SpeechHeard> listen({
    required String bcp47,
    required bool onDevice,
    Duration listenFor = const Duration(seconds: 8),
  }) {
    listens.add((bcp47: bcp47, onDevice: onDevice));
    return (_pending = Completer<SpeechHeard>()).future;
  }

  @override
  Future<void> stop() async {
    stops++;
    _pending?.complete(const SpeechHeard.failed(SpeechFailure.noMatch));
    _pending = null;
  }
}

/// A state with [speech] set up and speaking on, and voices for [voices].
Future<AppState> _speaking(
  FixedSpeechEngine speech, {
  Set<String> voices = const <String>{'hi', 'es'},
  bool on = true,
}) async {
  final state = AppState.test(
    speech: speech,
    tts: FixedTtsEngine(voices),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
      enabledSkills: <Skill>{
        ...Skill.values.where((s) => s.onByDefault),
        if (on) Skill.speaking,
      },
    ),
  );
  await state.load();
  if (on) await state.startSpeech();
  return state;
}

LanguageInfo _language(AppState state, String code) =>
    state.languages.firstWhere((l) => l.code == code);

/// [language]'s card.
Finder _card(String name) => find.ancestor(
  of: find.textContaining(name, findRichText: true),
  matching: find.byType(LanguageVoiceCard),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens Hindi's speaking test.
Future<AppLocalizations> _openTest(WidgetTester tester, AppState state) async {
  await pumpScreen(tester, const VoicesPage(), state: state);
  final l10n = l10nOf(tester);
  await _tap(tester, find.bySemanticsLabel(l10n.voicesSayLabel('Hindi')));
  expect(find.byType(SpeechTestSheet), findsOneWidget);
  return l10n;
}

void main() {
  testWidgets('one card per language, the languages learned first, each '
      'with listening and speaking', (tester) async {
    _useTallPhone(tester);
    final state = await _speaking(FixedSpeechEngine(onDevice: {'hi', 'es'}));
    state.settings.learningLanguages = const <String>['te'];
    await pumpScreen(tester, const VoicesPage(), state: state);
    final l10n = l10nOf(tester);
    // Only Telugu, learned, until the other languages are unfolded (#463).
    expect(find.byType(LanguageVoiceCard), findsOneWidget);
    await _tap(tester, find.text(l10n.voicesOtherLanguages));
    final cards = tester.widgetList<LanguageVoiceCard>(
      find.byType(LanguageVoiceCard),
    );
    expect(cards, hasLength(state.languages.length));
    expect(cards.first.language.code, 'te');
    expect(
      find.text(l10n.voicesListening),
      findsNWidgets(state.languages.length),
    );
    expect(
      find.text(l10n.voicesSpeakingPart),
      findsNWidgets(state.languages.length),
    );
    // No second list for speech below the voices.
    expect(find.text('Recognising your speech'), findsNothing);
    final hindi = _card('Hindi');
    expect(
      find.descendant(of: hindi, matching: find.text(l10n.voicesPlay)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hindi, matching: find.text(l10n.voicesSay)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: hindi,
        matching: find.text(l10n.voicesSpeechOnDevice),
      ),
      findsOneWidget,
    );
    // Without a voice, Install a voice in place of Play.
    final telugu = _card('Telugu');
    expect(
      find.descendant(of: telugu, matching: find.text(l10n.voicesInstallOne)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: telugu, matching: find.text(l10n.voicesPlay)),
      findsNothing,
    );
  });

  testWidgets('with several voices, the card offers a choice, and Play '
      'speaks in the one chosen; Phone default goes back', (tester) async {
    _useTallPhone(tester);
    final tts = FixedTtsEngine(
      const <String>{'es'},
      named: const <String, List<TtsVoice>>{
        'es': <TtsVoice>[
          TtsVoice(name: 'es-es-x-eea-local', locale: 'es-ES'),
          TtsVoice(
            name: 'es-es-x-eed-network',
            locale: 'es-ES',
            networkRequired: true,
          ),
        ],
      },
    );
    final state = AppState.test(tts: tts);
    await pumpScreen(tester, const VoicesPage(), state: state);
    final l10n = l10nOf(tester);
    final es = _language(state, 'es');
    final spanish = _card('Spanish');
    expect(
      find.descendant(
        of: spanish,
        matching: find.text(l10n.voicesInstalled(2)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: spanish,
        matching: find.text(l10n.voicesVoiceDefault),
      ),
      findsOneWidget,
    );

    await _tap(tester, find.text(l10n.voicesVoiceDefault));
    // Marked where it needs a connection.
    await _tap(
      tester,
      find.text(l10n.voicesVoiceOnline('es-es-x-eed-network')).last,
    );
    expect(state.settings.voiceFor('es'), 'es-es-x-eed-network');
    // Kept as set.
    expect(
      (SettingsNotifier()..restore(state.settings.toStored())).voiceFor('es'),
      'es-es-x-eed-network',
    );

    await _tap(
      tester,
      find.descendant(of: spanish, matching: find.text(l10n.voicesPlay)),
    );
    expect(tts.spoken.last.voice, 'es-es-x-eed-network');
    expect(tts.spoken.last.bcp47, es.ttsTag);

    await _tap(
      tester,
      find.text(l10n.voicesVoiceOnline('es-es-x-eed-network')),
    );
    await _tap(tester, find.text(l10n.voicesVoiceDefault).last);
    expect(state.settings.voiceFor('es'), isNull);
    await _tap(
      tester,
      find.descendant(of: spanish, matching: find.text(l10n.voicesPlay)),
    );
    expect(tts.spoken.last.voice, isNull);
  });

  testWidgets('a voice removed since it was chosen is the default, and one '
      'voice offers no choice', (tester) async {
    _useTallPhone(tester);
    final tts = FixedTtsEngine(const <String>{'es'});
    final state = AppState.test(tts: tts);
    state.settings.chooseVoice('es', 'a-voice-since-removed');
    await pumpScreen(tester, const VoicesPage(), state: state);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.voicesVoice), findsNothing);
    await _tap(tester, find.text(l10n.voicesPlay));
    expect(tts.spoken.single.voice, isNull);
  });

  testWidgets('a failed Play shows the engine\'s error code in small print, '
      'and the app log has it, never the word', (tester) async {
    _useTallPhone(tester);
    final tts = FixedTtsEngine(const <String>{'es'})
      ..failing = const TtsFailure('-8');
    final state = AppState.test(tts: tts);
    await pumpScreen(tester, const VoicesPage(), state: state);
    final l10n = l10nOf(tester);
    await _tap(tester, find.text(l10n.voicesPlay));
    expect(find.text(l10n.voicesPlayFailed), findsOneWidget);
    expect(find.text(l10n.voicesErrorCode('-8')), findsOneWidget);
    final es = _language(state, 'es');
    final word = VoicesPage.sampleFor(state, es)!;
    expect(state.log.text, contains('Voice error: ${es.ttsTag} -8'));
    expect(state.log.text, isNot(contains(word)));
  });

  testWidgets('Say something offers a word of the course with its reading, '
      'and says what was heard and whether it is the word', (tester) async {
    _useTallPhone(tester);
    final speech = FixedSpeechEngine(onDevice: <String>{'hi'});
    final state = await _speaking(speech);
    final l10n = await _openTest(tester, state);
    final hi = _language(state, 'hi');
    final word = speechTestWords(state, hi).first;
    expect(find.text(l10n.voicesSayLabel('Hindi')), findsOneWidget);
    expect(find.text(word.target), findsOneWidget);
    expect(find.text(word.reading!), findsOneWidget);

    speech.next = <SpeechAlternative>[SpeechAlternative(word.target)];
    await _tap(tester, find.text(l10n.voicesSayWord));
    expect(
      find.text(l10n.voicesHeard(word.target), findRichText: true),
      findsOneWidget,
    );
    expect(find.text(l10n.voicesHeardMatch), findsOneWidget);
    expect(speech.listens.last.bcp47, hi.ttsTag);
    expect(speech.listens.last.onDevice, isTrue);

    speech.next = const <SpeechAlternative>[SpeechAlternative('पानी नहीं')];
    await _tap(tester, find.text(l10n.voicesSayWord));
    expect(find.text(l10n.voicesHeardNoMatch), findsOneWidget);

    // Anything at all: shown as heard, with no verdict.
    await _tap(tester, find.text(l10n.voicesSayAnything));
    expect(
      find.text(l10n.voicesHeard('पानी नहीं'), findRichText: true),
      findsOneWidget,
    );
    expect(find.text(l10n.voicesHeardMatch), findsNothing);
    expect(find.text(l10n.voicesHeardNoMatch), findsNothing);

    // Another word.
    await _tap(tester, find.text(l10n.voicesAnotherWord));
    expect(find.text(speechTestWords(state, hi)[1].target), findsOneWidget);

    // A test records nothing.
    expect(state.progress.log, isEmpty);
  });

  for (final (name, failure, code, message)
      in <(String, SpeechFailure, String, String Function(AppLocalizations))>[
        (
          'nothing heard',
          SpeechFailure.noMatch,
          'error_no_match',
          (l) => l.drillUnheardNoMatch,
        ),
        (
          'no network',
          SpeechFailure.network,
          'error_network',
          (l) => l.drillUnheardNetwork,
        ),
        (
          'the recogniser stopped',
          SpeechFailure.other,
          'error_client',
          (l) => l.drillUnheardOther,
        ),
        (
          'not recognised, even online',
          SpeechFailure.unsupported,
          'error_language_not_supported',
          (l) => l.drillUnheardUnsupported('Hindi'),
        ),
      ]) {
    testWidgets('a failed test, $name, says why in the drill\'s words with '
        'the recogniser\'s code, and the app log has the type and code', (
      tester,
    ) async {
      _useTallPhone(tester);
      final speech = FixedSpeechEngine(onDevice: <String>{'hi'})
        ..failing = SpeechHeard.failed(failure, code: code);
      final state = await _speaking(speech);
      final l10n = await _openTest(tester, state);
      await _tap(tester, find.text(l10n.voicesSayAnything));
      expect(find.text(message(l10n)), findsOneWidget);
      expect(find.text(l10n.voicesErrorCode(code)), findsOneWidget);
      expect(
        state.log.text,
        contains('Speech error: hi-IN ${failure.name} $code'),
      );
    });
  }

  testWidgets('a language heard only online asks first, as the drill does; '
      'Allow listens online', (tester) async {
    _useTallPhone(tester);
    // Android 13 and later list only the on-device languages: Hindi is
    // unlisted, so it can only be heard online.
    final speech = FixedSpeechEngine(
      onDevice: <String>{'es'},
      online: <String>{'hi'},
    );
    final state = await _speaking(speech);
    await pumpScreen(tester, const VoicesPage(), state: state);
    final l10n = l10nOf(tester);
    // The online switch is in the card, its line the state.
    final online = find.descendant(
      of: _card('Hindi'),
      matching: find.byWidgetPredicate(
        (w) => w is GroupedTile && w.toggleValue != null,
      ),
    );
    expect(tester.widget<GroupedTile>(online).toggleValue, isFalse);
    expect(
      tester.widget<GroupedTile>(online).line,
      l10n.voicesSpeechOnlineOnly,
    );

    await _tap(tester, find.bySemanticsLabel(l10n.voicesSayLabel('Hindi')));
    speech.next = const <SpeechAlternative>[SpeechAlternative('नमस्ते')];
    await _tap(tester, find.text(l10n.voicesSayAnything));
    expect(speech.listens, isEmpty);
    expect(find.text(l10n.drillOnlineAsk('Hindi')), findsOneWidget);
    await _tap(tester, find.text(l10n.drillOnlineAllow('Hindi')));
    expect(state.settings.allowsOnlineSpeech('hi'), isTrue);
    expect(speech.listens.single.onDevice, isFalse);
    expect(
      find.text(l10n.voicesHeard('नमस्ते'), findRichText: true),
      findsOneWidget,
    );

    Navigator.of(tester.element(find.byType(SpeechTestSheet))).pop();
    await tester.pumpAndSettle();
    expect(tester.widget<GroupedTile>(online).toggleValue, isTrue);
    expect(tester.widget<GroupedTile>(online).line, l10n.voicesSpeechOnline);
    await _tap(tester, online);
    expect(state.settings.allowsOnlineSpeech('hi'), isFalse);
  });

  testWidgets('the online switch is named for what it allows, not Speaking, '
      'which stays the heading above it', (tester) async {
    _useTallPhone(tester);
    final speech = FixedSpeechEngine(
      onDevice: <String>{'es'},
      online: <String>{'hi'},
    );
    final state = await _speaking(speech);
    await pumpScreen(tester, const VoicesPage(), state: state);
    final l10n = l10nOf(tester);
    final hindi = _card('Hindi');
    final online = tester.widget<GroupedTile>(
      find.descendant(
        of: hindi,
        matching: find.byWidgetPredicate(
          (w) => w is GroupedTile && w.toggleValue != null,
        ),
      ),
    );
    expect(online.title, l10n.voicesOnlineSwitch);
    expect(online.title, isNot(l10n.voicesSpeakingPart));
    expect(
      find.descendant(of: hindi, matching: find.text(l10n.voicesSpeakingPart)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: hindi,
        matching: find.text(l10n.voicesSpeechOnlyOnline),
      ),
      findsOneWidget,
    );
    expect(online.subtitleOn, isNot(online.subtitleOff));
  });

  group('a rude word is never offered to say or played', () {
    test('the speaking test passes over it', () async {
      final state = await reviewState();
      addTearDown(state.dispose);
      final telugu = _language(state, 'te');
      final words = speechTestWords(state, telugu).map((c) => c.id);
      expect(words, isNot(contains(rudeCard)));
      expect(words, containsAll(<String>[alikeCard, plainCard]));
    });

    test('Play passes over it, though its deck comes first', () async {
      // With no path, the decks come in the order of their files, and the
      // rude deck's sorts before the words'.
      final state = AppState.test(
        decks: MemoryDeckSource(
          reviewCourse()..remove('decks/te/te-path.yaml'),
        ),
      );
      addTearDown(state.dispose);
      await state.load();
      final telugu = _language(state, 'te');
      expect(
        state.decks.where((d) => d.language.code == 'te').first.id,
        rudeDeck,
      );
      expect(VoicesPage.sampleFor(state, telugu), 'విధవ');
    });
  });

  testWidgets('closing the speaking test while it listens stops the '
      'microphone; closing it otherwise stops nothing', (tester) async {
    _useTallPhone(tester);
    final speech = _UntilStopped();
    final state = await _speaking(speech);
    final l10n = await _openTest(tester, state);
    Navigator.of(tester.element(find.byType(SpeechTestSheet))).pop();
    await tester.pumpAndSettle();
    expect(speech.stops, 0);

    await _tap(tester, find.bySemanticsLabel(l10n.voicesSayLabel('Hindi')));
    await _tap(tester, find.text(l10n.voicesSayAnything));
    expect(speech.listens, hasLength(1));
    expect(find.text(l10n.drillHearingHint), findsOneWidget);
    Navigator.of(tester.element(find.byType(SpeechTestSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SpeechTestSheet), findsNothing);
    expect(speech.stops, 1);
  });

  testWidgets('a test that finds the language not on the phone moves it to '
      'only online, as a drill\'s listen does', (tester) async {
    _useTallPhone(tester);
    // A recogniser that lists nothing: every language is tried on the phone.
    final speech = FixedSpeechEngine(online: <String>{'hi'});
    final state = await _speaking(speech);
    final hi = _language(state, 'hi');
    expect(state.speechStatus(hi), SpeechStatus.onDevice);
    final l10n = await _openTest(tester, state);
    await _tap(tester, find.text(l10n.voicesSayAnything));
    expect(state.speechStatus(hi), SpeechStatus.onlineOnly);
    expect(find.text(l10n.drillOnlineAsk('Hindi')), findsOneWidget);
    expect(
      state.log.text,
      contains('Speech error: hi-IN notOnDevice error_language_unavailable'),
    );
  });

  testWidgets('with speaking off, each card offers Switch on speaking in '
      'place of the test', (tester) async {
    _useTallPhone(tester);
    final speech = FixedSpeechEngine(onDevice: <String>{'hi'});
    final state = await _speaking(speech, on: false);
    await pumpScreen(tester, const VoicesPage(), state: state);
    final l10n = l10nOf(tester);
    final hindi = _card('Hindi');
    expect(
      find.descendant(of: hindi, matching: find.text(l10n.voicesSpeechOff)),
      findsOneWidget,
    );
    expect(find.text(l10n.voicesSay), findsNothing);
    await _tap(
      tester,
      find.descendant(of: hindi, matching: find.text(l10n.voicesSpeechTurnOn)),
    );
    expect(state.settings.isEnabled(Skill.speaking), isTrue);
    expect(
      find.descendant(of: hindi, matching: find.text(l10n.voicesSay)),
      findsOneWidget,
    );
  });

  group('accessibility', () {
    for (final dark in <bool>[false, true]) {
      testWidgets('the cards and the test, at twice the text size'
          '${dark ? ', dark' : ''}, meet the guidelines', (tester) async {
        _useTallPhone(tester, textScale: 2.0);
        final handle = tester.ensureSemantics();
        final speech = FixedSpeechEngine(
          onDevice: <String>{'hi'},
          online: <String>{'te'},
        );
        final state = await _speaking(speech);
        await pumpScreen(
          tester,
          const VoicesPage(),
          state: state,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        Future<void> check(String what) async {
          expect(tester.takeException(), isNull, reason: what);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }

        await check('cards');
        final l10n = l10nOf(tester);
        await _tap(tester, find.bySemanticsLabel(l10n.voicesSayLabel('Hindi')));
        await check('test');
        speech.next = const <SpeechAlternative>[SpeechAlternative('नमस्ते')];
        await _tap(tester, find.text(l10n.voicesSayWord));
        await check('heard');
        speech.failing = const SpeechHeard.failed(
          SpeechFailure.network,
          code: 'error_network',
        );
        await _tap(tester, find.text(l10n.voicesSayWord));
        await check('failed');
        handle.dispose();
      });
    }
  });
}
