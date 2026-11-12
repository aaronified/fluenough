// The on-device AI listener's row on the Voices page (#1004, task 12): not
// installed, downloading, installed and failed, the calls each button makes,
// and the page at 1.4x text, light and dark.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/speech/asr/asr_pack_installer.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/downloads/download_text.dart';
import 'package:fluenough/features/settings/voices_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/accessibility_shared.dart' as a11y;
import 'support/harness.dart';

/// Telugu learned, speaking on, and [installer] offering its listener.
Future<AppState> _state(FakeAsrPackInstaller installer) async {
  final state = AppState.test(
    asrPacks: installer,
    speech: FixedSpeechEngine(onDevice: <String>{'te'}),
    tts: FixedTtsEngine(const <String>{'te'}),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
      learningLanguages: const <String>['te'],
      enabledSkills: <Skill>{
        ...Skill.values.where((s) => s.onByDefault),
        Skill.speaking,
      },
    ),
  );
  await state.load();
  await state.startSpeech();
  return state;
}

Future<AppState> _stateIn(AsrInstallState installState) async {
  final installer = FakeAsrPackInstaller(
    states: <String, AsrInstallState>{'te': installState},
  );
  return _state(installer);
}

const _downloading = AsrInstallState(
  AsrInstallPhase.downloading,
  receivedBytes: 40000000,
  totalBytes: 137000000,
);
const _failed = AsrInstallState(
  AsrInstallPhase.failed,
  failure: AsrInstallFailure.network,
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('the AI listener row', () {
    testWidgets('not installed shows its size and Install, which installs, '
        'then Installed with Remove, which removes', (tester) async {
      usePhone(tester);
      final installer = FakeAsrPackInstaller();
      final state = await _state(installer);
      addTearDown(state.dispose);
      await pumpScreen(tester, const VoicesPage(), state: state);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.voicesAiTitle), findsOneWidget);
      expect(
        find.text(l10n.voicesAiNotInstalled(formatSize(l10n, 137000000))),
        findsOneWidget,
      );
      expect(installer.calls, contains('size te'));

      await _tap(tester, find.text(l10n.voicesAiInstall));
      expect(installer.calls, contains('install te'));
      expect(find.text(l10n.voicesAiInstalled), findsOneWidget);
      expect(find.text(l10n.voicesAiInstall), findsNothing);

      await _tap(tester, find.text(l10n.voicesAiRemove));
      expect(installer.calls, contains('remove te'));
      expect(find.text(l10n.voicesAiInstalled), findsNothing);
      expect(find.text(l10n.voicesAiInstall), findsOneWidget);
    });

    testWidgets('downloading shows progress and Cancel, which cancels', (
      tester,
    ) async {
      usePhone(tester);
      final installer = FakeAsrPackInstaller(
        states: <String, AsrInstallState>{'te': _downloading},
      );
      final state = await _state(installer);
      addTearDown(state.dispose);
      await pumpScreen(tester, const VoicesPage(), state: state);
      final l10n = l10nOf(tester);

      expect(
        find.text(
          l10n.voicesAiDownloading(
            formatSize(l10n, 40000000),
            formatSize(l10n, 137000000),
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text(l10n.voicesAiInstall), findsNothing);

      // Progress moves the line without rebuilding the page.
      installer.set(
        'te',
        const AsrInstallState(
          AsrInstallPhase.downloading,
          receivedBytes: 100000000,
          totalBytes: 137000000,
        ),
      );
      // The change reaches the page through a stream, so let it deliver.
      await tester.pumpAndSettle();
      expect(
        find.text(
          l10n.voicesAiDownloading(
            formatSize(l10n, 100000000),
            formatSize(l10n, 137000000),
          ),
        ),
        findsOneWidget,
      );

      await _tap(tester, find.text(l10n.voicesAiCancel));
      expect(installer.calls, contains('cancel te'));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(l10n.voicesAiInstall), findsOneWidget);
    });

    testWidgets('failed names the reason and Try again installs', (
      tester,
    ) async {
      usePhone(tester);
      final installer = FakeAsrPackInstaller(
        states: <String, AsrInstallState>{'te': _failed},
      );
      final state = await _state(installer);
      addTearDown(state.dispose);
      await pumpScreen(tester, const VoicesPage(), state: state);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.voicesAiFailedNetwork), findsOneWidget);
      await _tap(tester, find.text(l10n.voicesAiRetry));
      expect(installer.calls, contains('install te'));
      expect(find.text(l10n.voicesAiInstalled), findsOneWidget);
    });

    testWidgets('a language the installer does not offer has no row', (
      tester,
    ) async {
      usePhone(tester);
      final state = await _state(
        FakeAsrPackInstaller(languages: const <String>{'bn'}),
      );
      addTearDown(state.dispose);
      await pumpScreen(tester, const VoicesPage(), state: state);
      expect(find.text(l10nOf(tester).voicesAiTitle), findsNothing);
    });

    testWidgets('the buttons are native and labelled with the language', (
      tester,
    ) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final state = await _stateIn(AsrInstallState.notInstalled);
      addTearDown(state.dispose);
      await pumpScreen(tester, const VoicesPage(), state: state);
      final l10n = l10nOf(tester);
      expect(
        find.bySemanticsLabel(l10n.voicesAiInstallLabel('Telugu')),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsWidgets);
      semantics.dispose();
    });
  });

  a11y.screen(
    'Voices page, AI listener not installed',
    a11y.page(
      const VoicesPage(),
      state: () => _stateIn(AsrInstallState.notInstalled),
    ),
  );
  a11y.screen(
    'Voices page, AI listener downloading',
    a11y.page(const VoicesPage(), state: () => _stateIn(_downloading)),
  );
  a11y.screen(
    'Voices page, AI listener installed',
    a11y.page(
      const VoicesPage(),
      state: () => _stateIn(AsrInstallState.installed),
    ),
  );
  a11y.screen(
    'Voices page, AI listener failed',
    a11y.page(const VoicesPage(), state: () => _stateIn(_failed)),
  );
}
