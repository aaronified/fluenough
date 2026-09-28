import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/features/settings/voices_page.dart';

import '../../support/harness.dart';

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
  Future<void> speak(String text, {required String bcp47, double rate = 0.5}) =>
      _now.speak(text, bcp47: bcp47, rate: rate);

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
    final ja = _language(state, 'ja');

    expect(state.languages, hasLength(2));
    expect(find.textContaining(es.name, findRichText: true), findsOneWidget);
    expect(find.textContaining(es.ttsTag, findRichText: true), findsWidgets);
    expect(find.textContaining(ja.name, findRichText: true), findsOneWidget);
    expect(find.text(l10n.voicesInstalled(1)), findsOneWidget);
    expect(find.text(l10n.voicesMissing), findsOneWidget);

    // Test only where there is a voice.
    expect(find.bySemanticsLabel(l10n.voicesTestLabel(es.name)), findsOne);
    expect(find.bySemanticsLabel(l10n.voicesTestLabel(ja.name)), findsNothing);
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

    await tester.tap(find.text(l10n.voicesTest));
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

  testWidgets('Check again asks the phone again, checking meanwhile', (
    tester,
  ) async {
    usePhone(tester);
    final tts = _ChangingTts();
    final state = await pumpScreen(
      tester,
      const VoicesPage(),
      state: AppState.test(tts: tts),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.voicesMissing), findsNWidgets(2));
    expect(find.text(l10n.voicesTest), findsNothing);

    // The learner installs a Japanese voice and comes back.
    tts
      ..voices = <String>{'ja'}
      ..gate = Completer<void>();
    await tester.tap(find.text(l10n.voicesCheckAgain));
    await tester.pump();
    expect(find.text(l10n.voicesChecking), findsNWidgets(2));
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
    expect(state.hasVoice(_language(state, 'ja')), isTrue);
    expect(find.text(l10n.voicesInstalled(1)), findsOneWidget);
    expect(find.text(l10n.voicesMissing), findsOneWidget);
    expect(find.text(l10n.voicesTest), findsOneWidget);
  });

  testWidgets('Install explains how, in a dialog', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, const VoicesPage());
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.voicesInstall));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l10n.voicesInstallTitle), findsOneWidget);
    expect(find.text(l10n.voicesInstallSteps), findsOneWidget);
    await tester.tap(find.text(l10n.commonGotIt));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
