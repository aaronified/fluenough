// The web build (owner, 2026-11-05: "Now complete the web app works first"):
// the browser's speech recogniser behind the SpeechEngine interface, what a
// browser cannot do is not drawn in Settings, and the words about the
// microphone name the browser.

import 'dart:async';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/browser_words.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/speech/web_speech_browser.dart';
import 'package:fluenough/core/speech/web_speech_engine.dart';
import 'package:fluenough/features/drill/speaking_practice.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/app/placement.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/placement/placement_questions.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const BrowserHeard _heardHello = BrowserHeard(<SpeechAlternative>[
  SpeechAlternative('namaste', confidence: 0.9),
  SpeechAlternative('namaste ji'),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WebSpeechEngine', () {
    test('a browser with no recogniser (Firefox) is "no recogniser", not '
        '"refused"', () async {
      final engine = WebSpeechEngine(FixedSpeechBrowser(hasRecognition: false));
      // Nothing to refuse, so the app tells "no recogniser" from "refused".
      expect(await engine.hasPermission(), isTrue);
      expect(await engine.start(), isFalse);
      expect(await engine.languages(), isEmpty);
      final heard = await engine.listen(bcp47: 'hi-IN', onDevice: false);
      expect(heard.failure, SpeechFailure.noRecogniser);
    });

    test(
      'start asks for the microphone once, and a refusal is refused',
      () async {
        final allowed = FixedSpeechBrowser();
        final engine = WebSpeechEngine(allowed);
        expect(await engine.hasPermission(), isFalse, reason: 'never asks');
        expect(allowed.asked, 0);
        expect(await engine.start(), isTrue);
        expect(await engine.start(), isTrue);
        expect(allowed.asked, 1);
        expect(await engine.hasPermission(), isTrue);

        final refused = WebSpeechEngine(FixedSpeechBrowser(allows: false));
        expect(await refused.start(), isFalse);
        expect(await refused.hasPermission(), isFalse);
        final heard = await refused.listen(bcp47: 'hi-IN', onDevice: false);
        expect(heard.failure, SpeechFailure.permissionDenied);
      },
    );

    test(
      'a listen gives the readings, best first, without empty ones',
      () async {
        final browser = FixedSpeechBrowser(
          heard: const BrowserHeard(<SpeechAlternative>[
            SpeechAlternative('namaste', confidence: 0.9),
            SpeechAlternative('  '),
            SpeechAlternative('namaste ji'),
          ]),
        );
        final engine = WebSpeechEngine(browser);
        final heard = await engine.listen(bcp47: 'hi-IN', onDevice: false);
        expect(heard.failed, isFalse);
        expect(heard.alternatives.map((a) => a.text), <String>[
          'namaste',
          'namaste ji',
        ]);
        expect(heard.alternatives.first.confidence, 0.9);
        expect(heard.ownAudio, isNull, reason: 'a browser keeps no audio');
        expect(browser.listens, <String>['hi-IN']);
      },
    );

    test('an on-device listen is answered "not on device" without '
        'listening: a browser recognises online only', () async {
      final browser = FixedSpeechBrowser(heard: _heardHello);
      final engine = WebSpeechEngine(browser);
      final heard = await engine.listen(bcp47: 'hi-IN', onDevice: true);
      expect(heard.failure, SpeechFailure.notOnDevice);
      expect(browser.listens, isEmpty);
    });

    test('the Web Speech API error codes become the failures the app tells '
        'apart', () async {
      const expected = <String, SpeechFailure>{
        'no-speech': SpeechFailure.noMatch,
        'not-allowed': SpeechFailure.permissionDenied,
        'service-not-allowed': SpeechFailure.permissionDenied,
        'network': SpeechFailure.network,
        'language-not-supported': SpeechFailure.unsupported,
        'audio-capture': SpeechFailure.other,
        'aborted': SpeechFailure.other,
      };
      for (final MapEntry(key: code, value: failure) in expected.entries) {
        final engine = WebSpeechEngine(
          FixedSpeechBrowser(heard: BrowserHeard.error(code)),
        );
        final heard = await engine.listen(bcp47: 'hi-IN', onDevice: false);
        expect(heard.failure, failure, reason: code);
        expect(heard.code, code);
      }
    });

    test('a listen that says nothing at all is "no match"', () async {
      final engine = WebSpeechEngine(FixedSpeechBrowser());
      final heard = await engine.listen(bcp47: 'hi-IN', onDevice: false);
      expect(heard.failure, SpeechFailure.noMatch);
    });

    testWidgets('a listen that never answers is given up at its deadline and '
        'the browser told to stop', (tester) async {
      final browser = FixedSpeechBrowser(never: true);
      final engine = WebSpeechEngine(browser);
      SpeechHeard? heard;
      unawaited(
        engine
            .listen(bcp47: 'hi-IN', onDevice: false)
            .then((value) => heard = value),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(heard, isNull, reason: 'the default 8 s have not passed');
      await tester.pump(const Duration(seconds: 8));
      expect(heard?.failure, SpeechFailure.noMatch);
      expect(heard?.code, 'timeout');
      expect(browser.cancels, 1);
    });
  });

  group('Settings in a browser', () {
    testWidgets('the Reminders and Updates rows are not drawn: no dead '
        'switch for what a browser cannot do', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const SettingsPage(),
        state: AppState.test(features: const FeatureRegistry.web()),
      );
      final l10n = l10nOf(tester);
      await tester.scrollUntilVisible(
        find.text(l10n.settingsRowSupport),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.settingsRowReminders), findsNothing);
      expect(find.text(l10n.settingsRowUpdates), findsNothing);
      expect(find.text(l10n.settingsRowData), findsOneWidget);
    });

    testWidgets('the phone build still has both rows', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      await tester.scrollUntilVisible(
        find.text(l10n.settingsRowSupport),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.settingsRowReminders), findsOneWidget);
      expect(find.text(l10n.settingsRowUpdates), findsOneWidget);
    });

    test('only the web registry is a browser', () {
      expect(const FeatureRegistry.web().inBrowser, isTrue);
      expect(const FeatureRegistry.web().hasNotifications, isFalse);
      expect(const FeatureRegistry.web().hasApkUpdates, isFalse);
      expect(const FeatureRegistry.shipped().inBrowser, isFalse);
      expect(const FeatureRegistry.shipped().hasNotifications, isTrue);
      expect(FeatureRegistry.all().hasApkUpdates, isTrue);
    });
  });

  group('Say on the web engine, which listens online only', () {
    Future<(AppState, FixedSpeechBrowser)> webState({
      bool hasRecognition = true,
    }) async {
      final browser = FixedSpeechBrowser(
        hasRecognition: hasRecognition,
        heard: const BrowserHeard(<SpeechAlternative>[]),
      );
      final state = AppState.test(
        speech: WebSpeechEngine(browser),
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningChosen: true,
        ),
      );
      addTearDown(state.dispose);
      await state.load();
      await state.startSpeech();
      return (state, browser);
    }

    testWidgets('a language is online-only from the start: Find my level '
        'plans Say, and the learner is asked before anything is heard', (
      tester,
    ) async {
      usePhone(tester);
      final before = browserWords;
      addTearDown(() => browserWords = before);
      browserWords = true;
      final (state, browser) = await webState();
      final entry = state.decks.firstWhere((e) => e.language.code == 'hi');
      final card = entry.deck.cards.first;
      browser.heard = BrowserHeard(<SpeechAlternative>[
        SpeechAlternative(card.target),
      ]);
      expect(state.speechStatus(entry.language), SpeechStatus.onlineOnly);
      expect(state.canHear(entry.language), isFalse);
      expect(state.canHearAfterAsking(entry.language), isTrue);

      final answers = <bool>[];
      var declined = 0;
      await pumpScreen(
        tester,
        Scaffold(
          body: PlacementSay(
            question: SayQuestion(
              card: card,
              shown: card.target,
              language: entry.language,
            ),
            number: 1,
            onAnswer: answers.add,
            onCantSpeak: () => declined++,
          ),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);

      await tester.tap(find.text(l10n.placementSayStart));
      await tester.pumpAndSettle();
      expect(browser.listens, isEmpty, reason: 'no audio before consent');
      expect(
        find.text(l10n.drillOnlineAskWeb(entry.language.name)),
        findsOneWidget,
      );
      expect(answers, isEmpty);

      // Not now: Say is skipped, never a miss.
      await tester.tap(find.text(l10n.drillOnlineNotNow));
      await tester.pumpAndSettle();
      expect(declined, 1);
      expect(answers, isEmpty);
      expect(state.settings.allowsOnlineSpeech('hi'), isFalse);

      // Allow: it listens, and the answer is graded.
      await tester.tap(find.text(l10n.placementSayStart));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.drillOnlineAllow(entry.language.name)));
      await tester.pumpAndSettle();
      expect(state.settings.allowsOnlineSpeech('hi'), isTrue);
      expect(browser.listens, hasLength(1));
      expect(answers, <bool>[true]);
    });

    test('Firefox (no recogniser): Say is not planned', () async {
      final (state, _) = await webState(hasRecognition: false);
      const hindi = LanguageInfo(code: 'hi', iso639_3: 'hin', name: 'Hindi');
      expect(state.canHearAfterAsking(hindi), isFalse);
    });

    test('a device with no microphone is not "refused"', () async {
      final engine = WebSpeechEngine(FixedSpeechBrowser(noDevice: true));
      await expectLater(engine.start(), throwsA(isA<SpeechError>()));
      final state = AppState.test(speech: engine);
      addTearDown(state.dispose);
      await state.load();
      expect(await state.startSpeech(), SpeechSetup.noRecogniser);
    });

    test('a reminder restored from a backup is not available in a browser', () {
      expect(
        const FeatureRegistry.web().isAvailable(Feature.reminder),
        isFalse,
      );
      expect(
        const FeatureRegistry.shipped().isAvailable(Feature.reminder),
        isTrue,
      );
    });
  });

  group('the words about the microphone', () {
    const hindi = LanguageInfo(code: 'hi', iso639_3: 'hin', name: 'Hindi');
    test('name the browser on the web, and the phone elsewhere', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final before = browserWords;
      addTearDown(() => browserWords = before);

      browserWords = true;
      expect(
        unheardMessage(l10n, SpeechFailure.noRecogniser, hindi),
        l10n.drillUnheardNoRecogniserWeb,
      );
      expect(
        unheardMessage(l10n, SpeechFailure.permissionDenied, hindi),
        l10n.drillUnheardPermissionWeb,
      );
      expect(l10n.drillUnheardPermissionWeb, contains('browser'));
      expect(l10n.drillUnheardPermissionWeb, isNot(contains('Android')));

      browserWords = false;
      expect(
        unheardMessage(l10n, SpeechFailure.noRecogniser, hindi),
        l10n.drillUnheardNoRecogniser,
      );
      expect(
        unheardMessage(l10n, SpeechFailure.permissionDenied, hindi),
        l10n.drillUnheardPermission,
      );
    });
  });
}
