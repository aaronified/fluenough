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
import 'package:fluenough/core/models/deck.dart';
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

  group('the words about the microphone', () {
    const hindi = LanguageInfo(code: 'hi', iso639_3: 'hin', name: 'Hindi');
    testWidgets('name the browser on the web, and the phone elsewhere', (
      tester,
    ) async {
      await pumpScreen(tester, const SizedBox());
      final l10n = l10nOf(tester);
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
