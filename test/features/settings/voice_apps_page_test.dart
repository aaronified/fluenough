import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/core/tts/voice_apps.dart';
import 'package:fluenough/features/settings/voices_page.dart';

import '../../support/harness.dart';

// The Voices page for a course that uses two voices, Hindustani's hi-IN and
// ur-PK (#641), and the voice apps it lists (#642).

/// A [FixedTtsEngine] whose voices can change, for the learner installing
/// one while away.
class _ChangingTts implements TtsEngine {
  _ChangingTts(this.voices, {this.named = const <String, List<TtsVoice>>{}});

  Set<String> voices;
  final Map<String, List<TtsVoice>> named;

  FixedTtsEngine get _now => FixedTtsEngine(voices, named: named);

  @override
  Future<bool> isLanguageAvailable(String bcp47) =>
      _now.isLanguageAvailable(bcp47);

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

final List<VoiceApp> _apps = parseVoiceApps(
  File('assets/voice_apps.yaml').readAsStringSync(),
);

/// A tall phone, so that the whole card is built.
void _useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 9000 * 3);
}

Finder _hindustani() => find.ancestor(
  of: find.textContaining('Hindustani', findRichText: true),
  matching: find.byType(LanguageVoiceCard),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

AppState _state(_ChangingTts tts, {FixedLinks? links}) => AppState.test(
  tts: tts,
  links: links,
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['hi'],
  ),
);

void main() {
  testWidgets('a course lists every voice it uses, says the backup, suggests '
      'a download and lists the voice apps', (tester) async {
    _useTallPhone(tester);
    final state = _state(_ChangingTts(<String>{'hi-in'}));
    await pumpScreen(tester, VoicesPage(apps: _apps), state: state);
    final l10n = l10nOf(tester);
    final card = _hindustani();

    expect(
      find.descendant(
        of: card,
        matching: find.text(l10n.voicesInUseAutomatic('hi-IN')),
      ),
      findsOneWidget,
      reason: 'hi-IN is installed and in use',
    );
    // ur-PK is listed too, with the voice that stands in for it.
    expect(
      find.descendant(
        of: card,
        matching: find.text(l10n.deckVoiceBackup('ur-PK', 'hi-IN')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text(l10n.voicesDownloadHint)),
      findsOneWidget,
    );
    // Open where a voice is missing, with the apps that cover the course.
    for (final name in <String>['eSpeak NG', 'Google Speech Services']) {
      expect(
        find.descendant(of: card, matching: find.text(name)),
        findsOneWidget,
        reason: name,
      );
    }
  });

  testWidgets('a store link opens, and coming back asks the phone again', (
    tester,
  ) async {
    _useTallPhone(tester);
    final semantics = tester.ensureSemantics();
    final tts = _ChangingTts(<String>{'hi-in'});
    final links = FixedLinks();
    final state = _state(tts, links: links);
    await pumpScreen(tester, VoicesPage(apps: _apps), state: state);
    final l10n = l10nOf(tester);
    final urdu = state.voiceBlocksOf('hi').firstWhere(
      (b) => b.ttsTag == 'ur-PK',
    );
    expect(state.voiceStatus(urdu), VoiceStatus.missing);

    await _tap(
      tester,
      find.bySemanticsLabel(
        l10n.voiceAppGetLabel('eSpeak NG', l10n.voiceAppFdroid),
      ),
    );
    expect(links.asked, <String>[
      'https://f-droid.org/packages/com.reecedunn.espeak/',
    ]);

    // The learner installs the Urdu voice, and returns to the app.
    tts.voices = <String>{'hi-in', 'ur-pk'};
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(state.voiceStatus(urdu), VoiceStatus.available);
    expect(
      find.descendant(
        of: _hindustani(),
        matching: find.text(l10n.deckVoiceInstalled('ur-PK')),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('the learner chooses, per language, among the voices of every '
      'tag, or Automatic, and it is kept', (tester) async {
    _useTallPhone(tester);
    final tts = _ChangingTts(
      <String>{'hi-in', 'ur-pk'},
      named: const <String, List<TtsVoice>>{
        'hi': <TtsVoice>[
          TtsVoice(name: 'hi-in-x-hia-local', locale: 'hi-IN'),
          TtsVoice(name: 'hi-in-x-hic-local', locale: 'hi-IN'),
        ],
        'ur': <TtsVoice>[TtsVoice(name: 'ur-pk-x-urm-local', locale: 'ur-PK')],
      },
    );
    final state = _state(tts);
    await pumpScreen(tester, VoicesPage(apps: _apps), state: state);
    final l10n = l10nOf(tester);

    expect(
      find.text(l10n.voicesInUseAutomatic('hi-IN')),
      findsOneWidget,
      reason: 'no voice is chosen: the deck\'s own',
    );
    await _tap(tester, find.text(l10n.voicesVoiceDefault));
    await _tap(tester, find.text('ur-pk-x-urm-local').last);
    expect(state.settings.voiceFor('hi'), 'ur-pk-x-urm-local');
    expect(find.text(l10n.voicesInUseChosen('ur-pk-x-urm-local')), findsOne);
    // Kept as set.
    final restored = SettingsNotifier()..restore(state.settings.toStored());
    expect(restored.voiceFor('hi'), 'ur-pk-x-urm-local');

    await _tap(tester, find.text('ur-pk-x-urm-local').last);
    await _tap(tester, find.text(l10n.voicesVoiceDefault).last);
    expect(state.settings.voiceFor('hi'), isNull);
    expect(find.text(l10n.voicesInUseAutomatic('hi-IN')), findsOneWidget);
  });
}
