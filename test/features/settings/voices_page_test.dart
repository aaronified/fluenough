import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/system_settings.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/features/settings/gallery_entries.dart';
import 'package:fluenough/features/settings/voices_page.dart';

import '../../support/harness.dart';
import 'support.dart';

/// A [FixedTtsEngine] whose voices can change, and whose answers can be
/// held back with [gate], to see "Checking…".
class _ChangingTts implements TtsEngine {
  Set<String> voices = <String>{};
  Completer<void>? gate;

  FixedTtsEngine get _now => FixedTtsEngine(voices);

  @override
  Future<bool> isLanguageAvailable(String bcp47) async {
    await gate?.future;
    return _now.isLanguageAvailable(bcp47);
  }

  @override
  Future<List<TtsVoice>> voicesFor(String bcp47) => _now.voicesFor(bcp47);

  @override
  Future<void> speak(
    String text, {
    required String bcp47,
    double rate = 0.5,
    String? voice,
  }) => _now.speak(text, bcp47: bcp47, rate: rate, voice: voice);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

LanguageInfo _language(AppState state, String code) =>
    state.languages.firstWhere((l) => l.code == code);

void main() {
  testWidgets('each loaded language shows its tag and whether it has a '
      'voice', (tester) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    final state = await pumpScreen(
      tester,
      const VoicesPage(),
      state: AppState.test(tts: FixedTtsEngine(const <String>{'es'})),
    );
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester);
    final es = _language(state, 'es');
    final hi = _language(state, 'hi');

    final others = state.languages.length - 1;
    expect(others, greaterThan(0));
    expect(find.textContaining(es.name, findRichText: true), findsOneWidget);
    expect(find.textContaining(es.ttsTag, findRichText: true), findsWidgets);
    expect(find.textContaining(hi.name, findRichText: true), findsOneWidget);
    expect(find.text(l10n.voicesInstalled(1)), findsOneWidget);
    expect(find.text(l10n.voicesMissing), findsNWidgets(others));

    // Test only where there is a voice.
    expect(find.bySemanticsLabel(l10n.voicesPlayLabel(es.name)), findsOne);
    expect(find.bySemanticsLabel(l10n.voicesPlayLabel(hi.name)), findsNothing);
    semantics.dispose();
  });

  testWidgets('the languages learned come first, as cards; every other '
      'language on the phone, reviewed ones too, is folded under Other '
      'languages on this phone (#463)', (tester) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    final state = await pumpScreen(
      tester,
      const VoicesPage(),
      state: AppState.test(
        tts: FixedTtsEngine(const <String>{'es'}),
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['es'],
        )..reviewLanguages = const <String>{'hi'},
      ),
    );
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester);
    final es = _language(state, 'es');
    final hi = _language(state, 'hi');
    expect(state.languages.length, greaterThan(1));
    expect(find.byType(LanguageVoiceCard), findsOneWidget);
    expect(find.textContaining(es.name, findRichText: true), findsOneWidget);
    expect(find.textContaining(hi.name, findRichText: true), findsNothing);
    final others = find.text(l10n.voicesOtherLanguages);
    expect(others, findsOneWidget);
    expect(
      tester.getSemantics(others),
      isSemantics(hasExpandedState: true, isExpanded: false),
    );

    await tester.ensureVisible(others);
    await tester.tap(others);
    await tester.pumpAndSettle();
    expect(
      find.byType(LanguageVoiceCard, skipOffstage: false),
      findsNWidgets(state.languages.length),
    );
    expect(
      find.textContaining(hi.name, findRichText: true, skipOffstage: false),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('Test speaks a real card from the language at the speech '
      'rate', (tester) async {
    usePhone(tester);
    final tts = FixedTtsEngine(const <String>{'es'});
    final state = await pumpScreen(
      tester,
      const VoicesPage(),
      state: AppState.test(tts: tts),
    );
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester);
    final es = _language(state, 'es');
    state.settings.speechRate = 1.5;

    await scrollTo(tester, find.text(l10n.voicesPlay));
    await tester.tap(find.text(l10n.voicesPlay));
    await tester.pumpAndSettle();

    final spoken = tts.spoken.single;
    final esCards = <String>{
      for (final deck in state.decks)
        if (deck.language.code == 'es') ...deck.cards.map((c) => c.target),
    };
    expect(esCards, contains(spoken.text));
    expect(spoken.bcp47, es.ttsTag);
    expect(spoken.rate, state.settings.ttsRate());
    expect(spoken.rate, closeTo(0.75, 1e-9));
    expect(find.text(l10n.voicesSpeaking(spoken.text)), findsOneWidget);
  });

  testWidgets('with sound off, voices read as they are, and Test says sound '
      'is off rather than speaking', (tester) async {
    usePhone(tester);
    final tts = FixedTtsEngine(const <String>{'es'});
    final state = AppState.test(tts: tts)..settings.soundOn = false;
    await pumpScreen(tester, const VoicesPage(), state: state);
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester);
    expect(find.text(l10n.voicesInstalled(1)), findsOneWidget);

    await scrollTo(tester, find.text(l10n.voicesPlay));
    await tester.tap(find.text(l10n.voicesPlay));
    await tester.pumpAndSettle();
    expect(tts.spoken, isEmpty);
    expect(find.text(l10n.speakerSoundOff), findsOneWidget);
  });

  testWidgets('Check again asks the phone again, checking meanwhile', (
    tester,
  ) async {
    usePhone(tester);
    // Tall enough for every bundled language's row and what is under them.
    tester.view.physicalSize = const Size(390 * 3, 8000 * 3);
    final tts = _ChangingTts();
    final state = await pumpScreen(
      tester,
      const VoicesPage(),
      state: AppState.test(tts: tts),
    );
    final l10n = l10nOf(tester);
    final languages = state.languages.length;
    expect(find.text(l10n.voicesMissing), findsNWidgets(languages));
    expect(find.text(l10n.voicesPlay), findsNothing);

    // The learner installs a Hindi voice and comes back.
    tts
      ..voices = <String>{'hi'}
      ..gate = Completer<void>();
    await tester.tap(find.text(l10n.voicesCheckAgain));
    await tester.pump();
    expect(find.text(l10n.voicesChecking), findsNWidgets(languages));
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text(l10n.voicesCheckAgain),
              matching: find.byWidgetPredicate((w) => w is TextButton),
            ),
          )
          .onPressed,
      isNull,
    );

    tts.gate!.complete();
    await tester.pumpAndSettle();
    expect(state.hasVoice(_language(state, 'hi')), isTrue);
    expect(find.text(l10n.voicesInstalled(1)), findsOneWidget);
    expect(find.text(l10n.voicesMissing), findsNWidgets(languages - 1));
    expect(find.text(l10n.voicesPlay), findsOneWidget);
  });

  Future<void> tapInstall(WidgetTester tester, AppState state) async {
    usePhone(tester);
    // Tall enough for every bundled language's row and what is under them.
    tester.view.physicalSize = const Size(390 * 3, 8000 * 3);
    await pumpScreen(tester, const VoicesPage(), state: state);
    await scrollTo(tester, find.text(l10nOf(tester).voicesInstall));
    await tester.tap(find.text(l10nOf(tester).voicesInstall));
    await tester.pumpAndSettle();
  }

  void expectExplained(WidgetTester tester) {
    final l10n = l10nOf(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l10n.voicesInstallTitle), findsOneWidget);
    expect(find.text(l10n.voicesInstallSteps), findsOneWidget);
  }

  testWidgets("Install opens the phone's text-to-speech settings", (
    tester,
  ) async {
    final phone = FixedSystemSettings();
    await tapInstall(tester, AppState.test(systemSettings: phone));
    expect(phone.voiceSettingsAsked, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets("Install opens an engine's voice data where there are no "
      'text-to-speech settings', (tester) async {
    final phone = FixedSystemSettings(opens: VoiceSettingsPage.installVoices);
    await tapInstall(tester, AppState.test(systemSettings: phone));
    expect(phone.voiceSettingsAsked, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Install explains how, in a dialog, when nothing opens', (
    tester,
  ) async {
    final phone = FixedSystemSettings(opens: VoiceSettingsPage.none);
    await tapInstall(tester, AppState.test(systemSettings: phone));
    expect(phone.voiceSettingsAsked, 1);
    expectExplained(tester);
    await tester.tap(find.text(l10nOf(tester).commonGotIt));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Install explains how when the phone cannot be asked', (
    tester,
  ) async {
    final phone = FixedSystemSettings(
      error: PlatformException(code: 'unavailable'),
    );
    await tapInstall(tester, AppState.test(systemSettings: phone));
    expect(phone.voiceSettingsAsked, 1);
    expectExplained(tester);
  });

  testWidgets('Install explains how even when the answer is not an '
      'Exception, such as a TypeError from a bad reply', (tester) async {
    final phone = FixedSystemSettings(error: TypeError());
    await tapInstall(tester, AppState.test(systemSettings: phone));
    expect(phone.voiceSettingsAsked, 1);
    expectExplained(tester);
  });

  testWidgets('Install explains how where there are no phone settings to '
      'open, as off Android', (tester) async {
    // AppState.test's own: settings that open nothing.
    await tapInstall(tester, AppState.test());
    expectExplained(tester);
  });

  testWidgets('with the link switched off, Install only explains', (
    tester,
  ) async {
    final phone = FixedSystemSettings();
    await tapInstall(
      tester,
      AppState.test(
        systemSettings: phone,
        features: const FeatureRegistry.only(<Feature>{}),
      ),
    );
    expect(phone.voiceSettingsAsked, 0);
    expectExplained(tester);
  });

  testWidgets('the checking and no-decks states', (tester) async {
    usePhone(tester);
    final app = AppState.test();
    await app.load();
    final entries = {for (final e in settingsGalleryStates) e.id: e};

    await pumpScreen(
      tester,
      GalleryPreview(entry: entries['voices-checking']!),
      state: app,
    );
    final l10n = l10nOf(tester);
    // The languages learned; the rest are folded (#463).
    expect(find.byType(LanguageVoiceCard), findsWidgets);
    expect(
      find.text(l10n.voicesChecking),
      findsNWidgets(find.byType(LanguageVoiceCard).evaluate().length),
    );
    expect(find.text(l10n.voicesPlay), findsNothing);

    await pumpScreen(
      tester,
      GalleryPreview(key: UniqueKey(), entry: entries['voices-none']!),
      state: app,
    );
    expect(find.text(l10n.voicesNone), findsOneWidget);
    expect(find.text(l10n.voicesCheckAgain), findsNothing);
    expect(find.text(l10n.voicesInstall), findsOneWidget);
  });
}
