// Today says when speech works only online (#233): an alert once per
// language, a line under the day's cards with a button to that language's
// card on the Voices page, and nothing when speech works offline.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/settings/voices_page.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/accessibility_shared.dart' as a11y;
import 'support/harness.dart';

/// A learner of [learns] with speaking on, on a phone that recognises
/// [onDevice] languages itself and [online] ones only online.
Future<AppState> _state({
  Set<String> onDevice = const <String>{'hi'},
  Set<String> online = const <String>{'te'},
  List<String> learns = const <String>['te'],
}) async {
  final state = AppState.test(
    speech: FixedSpeechEngine(onDevice: onDevice, online: online),
    tts: FixedTtsEngine(const <String>{'te'}),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
      learningLanguages: learns,
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

Finder _line() => find.byKey(const ValueKey<String>('speech-online-line'));

Finder _teCard() => find.byWidgetPredicate(
  (w) => w is LanguageVoiceCard && w.language.code == 'te',
);

void main() {
  group('speech that works only online', () {
    testWidgets('the alert shows once per language, and not again', (
      tester,
    ) async {
      usePhone(tester, textScale: 1.4);
      final state = await _state(
        online: const <String>{'te', 'bn'},
        learns: const <String>['te', 'bn'],
      );
      addTearDown(state.dispose);
      state.showLanguage('te');
      await pumpScreen(tester, const TodayPage(), state: state);
      final l10n = l10nOf(tester);
      final telugu = state.languageByCode('te')!.name;

      expect(find.text(l10n.speechOnlineAlertTitle(telugu)), findsOneWidget);
      expect(state.settings.hasSpeechAlert('te'), isTrue);
      await tester.tap(find.text(l10n.speechOnlineNotNow));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      // Drawn again, the same language does not alert; its line stays.
      await pumpScreen(tester, const TodayPage(), state: state);
      expect(find.byType(AlertDialog), findsNothing);
      expect(_line(), findsOneWidget);

      // Another language alerts for itself, once.
      final bengali = state.languageByCode('bn')!.name;
      state.showLanguage('bn');
      await tester.pumpAndSettle();
      expect(find.text(l10n.speechOnlineAlertTitle(bengali)), findsOneWidget);
      await tester.tap(find.text(l10n.speechOnlineNotNow));
      await tester.pumpAndSettle();
      expect(state.settings.speechAlerted, <String>{'te', 'bn'});
      state.showLanguage('te');
      await tester.pumpAndSettle();
      state.showLanguage('bn');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('the alert remembers across launches', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = await _state();
      addTearDown(state.dispose);
      await pumpScreen(tester, const TodayPage(), state: state);
      await tester.tap(find.text(l10nOf(tester).speechOnlineNotNow));
      await tester.pumpAndSettle();

      final stored = state.settings.toStored();
      expect(stored['speech_alerted'], 'te');
      final again = SettingsNotifier()..restore(stored);
      expect(again.hasSpeechAlert('te'), isTrue);
    });

    testWidgets('Open settings in the alert opens the language on the '
        'Voices page', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = await _state();
      addTearDown(state.dispose);
      await pumpScreen(tester, const TodayPage(), state: state);
      final l10n = l10nOf(tester);

      await tester.tap(find.text(l10n.speechOnlineOpenSettings).last);
      await tester.pumpAndSettle();
      expect(find.byType(VoicesPage), findsOneWidget);
      expect(_teCard(), findsOneWidget);
      expect(tester.getRect(_teCard()).top, lessThan(844));
    });

    testWidgets('the line stays on Today and its button opens the '
        'language on the Voices page', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = await _state();
      addTearDown(state.dispose);
      await pumpScreen(tester, const TodayPage(), state: state);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.speechOnlineNotNow));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: _line(),
          matching: find.text(
            l10n.speechOnlineLine(state.languageByCode('te')!.name),
          ),
        ),
        findsOneWidget,
      );
      final button = find.descendant(
        of: _line(),
        matching: find.text(l10n.speechOnlineOpenSettings),
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(VoicesPage), findsOneWidget);
      expect(_teCard(), findsOneWidget);
    });

    testWidgets('allowing it online takes the line away', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = await _state();
      addTearDown(state.dispose);
      await pumpScreen(tester, const TodayPage(), state: state);
      await tester.tap(find.text(l10nOf(tester).speechOnlineNotNow));
      await tester.pumpAndSettle();
      expect(_line(), findsOneWidget);

      state.settings.allowOnlineSpeech('te', true);
      await tester.pumpAndSettle();
      expect(_line(), findsNothing);
    });

    testWidgets('nothing shows when speech works offline', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = await _state(
        onDevice: const <String>{'te'},
        online: const <String>{},
      );
      addTearDown(state.dispose);
      await pumpScreen(tester, const TodayPage(), state: state);

      expect(find.byType(AlertDialog), findsNothing);
      expect(_line(), findsNothing);
      expect(state.settings.hasSpeechAlert('te'), isFalse);
    });

    testWidgets('nothing shows while speaking is off', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = await _state();
      addTearDown(state.dispose);
      state.settings.setSkillEnabled(Skill.speaking, false);
      await pumpScreen(tester, const TodayPage(), state: state);

      expect(find.byType(AlertDialog), findsNothing);
      expect(_line(), findsNothing);
    });
  });

  group('Today with the speech line', () {
    a11y.screen('the line under the cards', (tester, mode) async {
      final state = await _state();
      addTearDown(state.dispose);
      state.settings.themeMode = mode;
      await pumpApp(tester, state: state);
      state.shellTab.value = ShellTab.today;
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nOf(tester).speechOnlineNotNow));
      await tester.pumpAndSettle();
      expect(_line(), findsOneWidget);
    });
  });
}
