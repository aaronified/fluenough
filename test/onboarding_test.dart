// Onboarding: the app opens on Today with real decks and the bar switches
// tabs; the tour walks, skips, goes back as Android back does, and claims
// only what ships; a double tap cannot skip a step; the sound check asks for
// the microphone only on Record and saves speaking and listening as it
// found them; Languages you know finds a language by its English or its own
// name, asks in that language, asks which script where there are several,
// and reads saves from before #551.

import 'dart:async' show unawaited;
import 'dart:io';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/sound/sound_check.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/onboarding/onboarding_flow.dart';
import 'package:fluenough/features/onboarding/sound_check_step.dart';
import 'package:fluenough/features/onboarding/tour_step.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/profiles/spoken_languages_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/stats/stats_page.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/fluenough_mark.dart';
import 'package:fluenough/ui/widgets/wave_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

// From app_shell_test.dart.
/// Whether [page] is the tab on screen, rather than kept alive offstage.
bool showing(WidgetTester tester, Type page) =>
    find.byType(page).hitTestable().evaluate().isNotEmpty;

// From sound_check_test.dart.
/// The first launch's microphone and sound check (#89): record two seconds,
/// play them back, and keep speaking or listening off where either failed.

void main() {
  group('the app shell', () {
    testWidgets(
      'starts on Today with the real decks; the bar switches tabs, and back '
      'returns to Today',
      (tester) async {
        usePhone(tester);
        final state = await pumpApp(tester);

        expect(state.status, CatalogStatus.ready);
        expect(state.deckById('es-en-core-100'), isNotNull);
        expect(state.deckById('hi-en-script-vowels'), isNotNull);
        expect(state.brokenDecks, isEmpty);
        expect(state.currentProfile.id, Profile.defaultProfile.id);

        expect(showing(tester, TodayPage), isTrue);
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(bar.selectedIndex, ShellTab.today.index);

        {
          usePhone(tester);
          final state = await pumpApp(tester);
          final l10n = l10nOf(tester);

          for (final (label, page, tab) in <(String, Type, ShellTab)>[
            (l10n.navDecks, DecksPage, ShellTab.decks),
            (l10n.navProgress, StatsPage, ShellTab.progress),
            (l10n.navSettings, SettingsPage, ShellTab.settings),
            (l10n.navToday, TodayPage, ShellTab.today),
          ]) {
            await tester.tap(
              find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text(label),
              ),
            );
            await tester.pumpAndSettle();
            expect(showing(tester, page), isTrue, reason: label);
            expect(state.shellTab.value, tab);
          }

          await tester.tap(find.text(l10n.navDecks));
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(showing(tester, TodayPage), isTrue);
        }
      },
    );
  });

  group('the tour', () {
    // A cached asset's future belongs to the test that first read it.
    setUp(rootBundle.clear);

    Future<SettingsNotifier> firstLaunch(WidgetTester tester) async {
      usePhone(tester);
      final settings = SettingsNotifier();
      final state = AppState.test(settings: settings);
      addTearDown(state.dispose);
      addTearDown(settings.dispose);
      await tester.pumpWidget(FluenoughApp(state: state));
      await tester.pumpAndSettle();
      return settings;
    }

    String title(AppLocalizations l10n, int slide) =>
        tourSlides[slide].title(l10n);

    test('the tour claims only what ships (ADR-0008)', () {
      expect(Feature.available, containsAll(tourClaims));
      for (final skill in tourSkills) {
        expect(tourClaims, contains(skill.feature), reason: skill.name);
      }
      expect(tourClaims, isNot(contains(Feature.drillPair)));
      expect(tourStep.pages, tourSlides.length);
    });

    testWidgets('Next walks the welcome, every slide and the question; a swipe turns '
        'the slide, Skip skips, back returns where it left', (tester) async {
      final semantics = tester.ensureSemantics();
      final settings = await firstLaunch(tester);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.appTitle), findsOneWidget);
      expect(find.byType(FluenoughMark), findsOneWidget, reason: 'the logo');
      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.text(l10n.onboardingStart));
      await tester.pumpAndSettle();

      final count = tourSlides.length;
      for (var i = 0; i < count; i++) {
        expect(find.text(title(l10n, i)), findsOneWidget, reason: '$i');
        expect(
          find.bySemanticsLabel(
            l10n.onboardingTourPosition(i + 1, count, title(l10n, i)),
          ),
          findsOneWidget,
        );
        expect(
          find.text(l10n.onboardingSkip),
          i == count - 1 ? findsNothing : findsOneWidget,
          reason: 'no Skip on the last slide',
        );
        await tester.tap(find.text(l10n.onboardingNext));
        await tester.pumpAndSettle();
      }

      // The sound check (#89), which Next passes without asking anything.
      expect(find.text(l10n.onboardingSoundTitle), findsOneWidget);
      await tester.tap(find.text(l10n.onboardingNext));
      await tester.pumpAndSettle();

      expect(find.text(l10n.onboardingSpokenTitle), findsOneWidget);
      // What the answer is for, where it is kept, and where to change it.
      expect(find.text(l10n.onboardingSpokenBody), findsOneWidget);
      final privacy = find.text(
        l10n.onboardingSpokenPrivacy(l10n.navSettings, l10n.settingsSpoken),
      );
      await scrollToFind(tester, privacy);
      expect(privacy, findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.byType(WaveProgress), findsNothing, reason: 'one question');
      expect(find.text(l10n.onboardingSpokenNeedOne), findsOneWidget);
      final go = find.widgetWithText(FilledButton, l10n.commonContinue);
      expect(tester.widget<FilledButton>(go).onPressed, isNull);
      // Choosing Hindustani asks which of its scripts are read (#462,
      // #490), which nothing assumes.
      await knowLanguage(tester, 'Hindustani');
      expect(find.text(l10n.onboardingSpokenNeedOne), findsNothing);
      expect(settings.spokenLanguages, isEmpty, reason: 'nothing saved yet');
      expect(tester.widget<FilledButton>(go).onPressed, isNotNull);

      await tester.tap(go);
      await tester.pumpAndSettle();
      expect(settings.spokenLanguages, ['hi']);
      // Then what to learn (#117), before the app.
      expect(find.byType(LanguagePickerPage), findsOneWidget);
      expect(find.byType(OnboardingFlow), findsNothing);
      semantics.dispose();

      {
        final settings = await firstLaunch(tester);
        final l10n = l10nOf(tester);
        await tester.tap(find.text(l10n.onboardingStart));
        await tester.pumpAndSettle();

        await tester.drag(find.byType(PageView), const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(find.text(title(l10n, 1)), findsOneWidget);

        await tester.tap(find.text(l10n.onboardingSkip));
        await tester.pumpAndSettle();
        expect(find.text(l10n.onboardingSoundTitle), findsOneWidget);

        // Android back: the slide it was left on, the one before, the welcome.
        for (final expected in <String>[
          title(l10n, 1),
          title(l10n, 0),
          l10n.onboardingStart,
        ]) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text(expected), findsOneWidget);
        }
        final scope = tester.widget<PopScope<Object?>>(
          find.byWidgetPredicate((w) => w is PopScope && w.child is Scaffold),
        );
        expect(scope.canPop, isTrue, reason: 'back on the welcome leaves');
        expect(settings.spokenLanguages, isEmpty);
      }
    });

    testWidgets(
      'the on-screen Back does what Android back does, and a double tap '
      'cannot skip a step',
      (tester) async {
        usePhone(tester);
        await pumpScreen(
          tester,
          const OnboardingFlow(startAt: 'tour', page: 2),
        );
        final l10n = l10nOf(tester);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text(title(l10n, 1)), findsOneWidget);

        {
          usePhone(tester);
          await pumpScreen(tester, const OnboardingFlow());
          final l10n = l10nOf(tester);
          await tester.tap(find.text(l10n.onboardingStart));
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(find.text(title(l10n, 0)), findsOneWidget);
        }
      },
    );

    // The words come first: at 1.0 they all fit beside the picture; larger,
    // the picture shrinks and then goes before a single word is cut, and what
    // still does not fit scrolls, with a scrollbar to say so.

    testWidgets('right to left, the frame and the pages mirror', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const Directionality(
          textDirection: TextDirection.rtl,
          child: OnboardingFlow(startAt: 'tour'),
        ),
      );
      final l10n = l10nOf(tester);
      expect(textStart(tester, find.text(title(l10n, 0))), 24);
      expect(
        tester.getTopRight(find.text(title(l10n, 0))).dx,
        390 - 24,
        reason: 'the inset is directional',
      );
      expect(tester.getCenter(find.byType(BackButton)).dx, greaterThan(195));
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.text(title(l10n, 1)), findsOneWidget);
    });
  });

  group('the sound check', () {
    setUp(rootBundle.clear);

    final choices = parseSpokenLanguages(
      File(SpokenLanguagesPage.asset).readAsStringSync(),
    );

    /// A first launch at the sound check, on [sound] and a recogniser that
    /// hears Spanish (or none, with [recogniser] false).
    Future<AppState> atSoundCheck(
      WidgetTester tester,
      FixedSoundCheck sound, {
      bool recogniser = true,
    }) async {
      usePhone(tester);
      final settings = SettingsNotifier();
      addTearDown(settings.dispose);
      final state = AppState.test(
        settings: settings,
        soundCheck: sound,
        speech: recogniser
            ? FixedSpeechEngine(onDevice: <String>{'es'})
            : FixedSpeechEngine(),
      );
      await pumpScreen(
        tester,
        OnboardingFlow(startAt: 'sound', choices: choices),
        state: state,
      );
      return state;
    }

    /// Scrolls the check until [finder] is built: at a large text size, or
    /// with a long message, part of it starts below the fold.
    Future<void> reveal(WidgetTester tester, Finder finder) async {
      final check = find.descendant(
        of: find.byType(SoundCheckContent),
        matching: find.byType(Scrollable),
      );
      if (finder.evaluate().isEmpty && check.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(finder, 120, scrollable: check.first);
      }
    }

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await reveal(tester, finder);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> record(WidgetTester tester) => tap(
      tester,
      find.bySemanticsLabel(l10nOf(tester).onboardingSoundRecord),
    );

    /// Goes on to the languages question, picks English and saves.
    Future<void> finish(WidgetTester tester) async {
      final l10n = l10nOf(tester);
      await tap(tester, find.text(l10n.onboardingNext));
      await knowLanguage(tester, 'English');
      await tap(tester, find.text(l10n.commonContinue));
    }

    testWidgets(
      'it asks for the microphone only when Record is tapped, and heard '
      'switches speaking and listening on',
      (tester) async {
        final sound = FixedSoundCheck();
        await atSoundCheck(tester, sound);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.onboardingSoundTitle), findsOneWidget);
        expect(sound.recordings, 0);
        await record(tester);
        expect(sound.recordings, 1);

        {
          final sound = FixedSoundCheck();
          final state = await atSoundCheck(tester, sound);
          final l10n = l10nOf(tester);
          await record(tester);
          expect(sound.playbacks, 1);
          expect(find.text(l10n.onboardingSoundHeardYou), findsOneWidget);
          await tap(tester, find.text(l10n.onboardingSoundYes));
          expect(find.text(l10n.onboardingSoundSpeakingOn), findsOneWidget);
          expect(find.text(l10n.onboardingSoundListeningOn), findsOneWidget);
          expect(find.text(l10n.commonRetry), findsNothing);
          expect(
            state.settings.isEnabled(Skill.speaking),
            isFalse,
            reason: 'nothing is saved before the last step',
          );
          await finish(tester);
          expect(state.settings.isEnabled(Skill.speaking), isTrue);
          expect(state.settings.isEnabled(Skill.listening), isTrue);
        }
      },
    );

    testWidgets('refused or silent: speaking stays off', (tester) async {
      final sound = FixedSoundCheck(grants: false);
      final state = await atSoundCheck(tester, sound);
      final l10n = l10nOf(tester);
      await record(tester);
      // Nothing recorded, so a beep tests the sound.
      expect(find.text(l10n.onboardingSoundHeardBeep), findsOneWidget);
      await tap(tester, find.text(l10n.onboardingSoundYes));
      expect(find.text(l10n.onboardingSoundRefused), findsOneWidget);
      expect(find.text(l10n.onboardingSoundListeningOn), findsOneWidget);

      sound.grants = true;
      await tap(tester, find.text(l10n.commonRetry));
      expect(sound.recordings, 2, reason: 'asked again');
      expect(find.text(l10n.onboardingSoundHeardYou), findsOneWidget);
      await tap(tester, find.text(l10n.onboardingSoundYes));
      expect(find.text(l10n.onboardingSoundSpeakingOn), findsOneWidget);
      await finish(tester);
      expect(state.settings.isEnabled(Skill.speaking), isTrue);

      {
        final sound = FixedSoundCheck(records: RecordFailure.silent);
        await atSoundCheck(tester, sound);
        final l10n = l10nOf(tester);
        await record(tester);
        await tap(tester, find.text(l10n.onboardingSoundYes));
        expect(find.text(l10n.onboardingSoundSilent), findsOneWidget);
      }
    });

    testWidgets('playback failing: listening is saved off without asking', (
      tester,
    ) async {
      final sound = FixedSoundCheck(plays: false);
      final state = await atSoundCheck(tester, sound);
      final l10n = l10nOf(tester);
      await record(tester);
      expect(find.text(l10n.onboardingSoundHeardYou), findsNothing);
      expect(find.text(l10n.onboardingSoundListeningOff), findsOneWidget);
      await finish(tester);
      expect(state.settings.isEnabled(Skill.listening), isFalse);
    });
  });

  group('Languages you know', () {
    Future<void> openPunjabi(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const ValueKey<String>('known-search')),
        'Punjabi',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('lang-pa')));
      await tester.pumpAndSettle();
    }

    FilledButton done(WidgetTester tester) => tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('know-done')),
    );

    // A cached asset's future belongs to the test that first read it.
    setUp(rootBundle.clear);

    /// The language [text] is marked as, for a screen reader, or null.
    Locale? markedAs(WidgetTester tester, Finder text) {
      Locale? found;
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)).first,
      );
      paragraph.text.visitChildren((span) {
        if (span is TextSpan && span.locale != null) found = span.locale;
        return true;
      });
      return found;
    }

    Future<AppState> openPage(WidgetTester tester, [SettingsNotifier? s]) =>
        pumpScreen(
          tester,
          const SpokenLanguagesPage(),
          state: AppState.test(settings: s ?? SettingsNotifier()),
        );

    group('Languages you know (#490)', () {
      testWidgets(
        'the search finds a language by its English or its own name, and its '
        'sheet asks in that language',
        (tester) async {
          usePhone(tester);
          await openPage(tester);
          final l10n = l10nOf(tester);
          final search = find.byKey(const ValueKey<String>('known-search'));
          await tester.enterText(search, 'hin');
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey<String>('lang-hi')), findsOneWidget);
          expect(find.byKey(const ValueKey<String>('lang-bn')), findsNothing);
          await tester.enterText(search, 'বাং');
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey<String>('lang-bn')), findsOneWidget);
          await tester.enterText(search, 'tel');
          await tester.pumpAndSettle();
          // Telugu is Dravidian, which was folded.
          expect(find.byKey(const ValueKey<String>('lang-te')), findsOneWidget);
          await tester.enterText(search, 'zzz');
          await tester.pumpAndSettle();
          expect(find.text(l10n.knownSearchNone('zzz')), findsOneWidget);
          await tester.enterText(search, '');
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey<String>('lang-te')), findsNothing);

          {
            usePhone(tester);
            final state = await openPage(tester);
            final l10n = l10nOf(tester);
            for (final (name, code, question, read, speak, answered, english)
                in <(String, String, String, String, String, String, String)>[
                  (
                    'Bengali',
                    'bn',
                    'আপনি কি পূর্ব নাগরী লিপি পড়তে পারেন?',
                    'আমি পূর্ব নাগরী লিপি পড়তে পারি',
                    'I can only speak Bengali',
                    'Can read the Eastern Nagari script',
                    'Eastern Nagari',
                  ),
                ]) {
              await tester.enterText(
                find.byKey(const ValueKey<String>('known-search')),
                name,
              );
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(ValueKey<String>('lang-$code')));
              await tester.pumpAndSettle();
              // The question and "can read" are in the language's own script,
              // marked as that language, with the English under each.
              expect(find.text(question), findsOneWidget);
              expect(find.text(read), findsOneWidget);
              expect(markedAs(tester, find.text(question)), Locale(code));
              expect(markedAs(tester, find.text(read)), Locale(code));
              expect(find.text(speak), findsOneWidget);
              expect(find.text('Do you read the $english script?'), findsOne);
              expect(find.text('I can read the $english script'), findsOne);
              // Never Yes or No.
              expect(find.text('Yes'), findsNothing);
              expect(find.text('No'), findsNothing);
              // Not chosen yet: nothing to remove.
              expect(
                find.byKey(const ValueKey<String>('know-remove')),
                findsNothing,
              );
              await tester.tap(
                find.byKey(
                  ValueKey<String>(code == 'bn' ? 'know-read' : 'know-speak'),
                ),
              );
              await tester.pumpAndSettle();
              expect(
                find.text(question),
                findsNothing,
                reason: 'the sheet closed',
              );
              await tester.enterText(
                find.byKey(const ValueKey<String>('known-search')),
                '',
              );
              await tester.pumpAndSettle();
              expect(find.text(answered), findsOneWidget, reason: name);
            }
            // Saved only by Save.
            expect(state.settings.spokenLanguages, isEmpty);
            await tester.tap(find.text(l10n.knownSave));
            await tester.pumpAndSettle();
            expect(state.settings.spokenLanguages, ['bn']);
            expect(state.settings.scriptsRead, <String, bool>{'bn': true});
          }
        },
      );

      testWidgets(
        'Save keeps the order chosen; a language of several scripts asks '
        'which are read',
        (tester) async {
          usePhone(tester);
          final state = await pumpApp(tester);
          final l10n = l10nOf(tester);
          unawaited(
            AppNavigator.openSpokenLanguages(
              tester.element(find.byType(AppShell)),
            ),
          );
          await tester.pumpAndSettle();
          await knowLanguage(tester, 'Hindustani');
          await tester.tap(find.text(l10n.knownSave));
          await tester.pumpAndSettle();
          expect(state.settings.spokenLanguages, ['en', 'hi']);
          expect(state.settings.scriptsRead['hi'], isTrue);
          expect(find.text(l10n.spokenTitle), findsNothing);

          {
            usePhone(tester, navBar: true);
            final state = await pumpScreen(
              tester,
              const SpokenLanguagesPage(),
              state: AppState.test(settings: SettingsNotifier()),
            );
            final l10n = l10nOf(tester);
            await openPunjabi(tester);
            // The unchecked texts are shown, with English under them, naming
            // each script by its own name (#552, owner, 2026-10-18).
            expect(
              find.text('Which scripts do you read Punjabi in?'),
              findsOne,
            );
            expect(find.textContaining('ਤੁਸੀਂ'), findsOneWidget);
            final sheet = tester.getRect(find.byType(BottomSheet));
            for (final (key, text) in <(String, String)>[
              ('know-script-gurmukhi', 'I can read the Gurmukhi script'),
              ('know-script-shahmukhi', 'I can read the Shahmukhi script'),
              ('know-speak', 'I can only speak Punjabi'),
              ('know-cancel', l10n.commonCancel),
              ('know-done', l10n.knownScriptsDone),
            ]) {
              final at = find.byKey(ValueKey<String>(key));
              expect(
                find.descendant(of: at, matching: find.text(text)),
                findsOneWidget,
                reason: key,
              );
              final rect = tester.getRect(at);
              expect(rect.height, greaterThanOrEqualTo(48), reason: key);
              expect(rect.top, greaterThanOrEqualTo(sheet.top), reason: key);
              expect(rect.bottom, lessThanOrEqualTo(sheet.bottom), reason: key);
              expect(rect.left, greaterThanOrEqualTo(sheet.left), reason: key);
              expect(rect.right, lessThanOrEqualTo(sheet.right), reason: key);
              // Above the 3-button bar (#489).
              expect(rect.bottom, lessThanOrEqualTo(844 - navBarHeight));
            }
            // No answer read in one tap: nothing is ticked, and Done waits.
            expect(
              find.byKey(const ValueKey<String>('know-read')),
              findsNothing,
            );
            expect(done(tester).onPressed, isNull);
            await tester.tap(
              find.byKey(const ValueKey<String>('know-script-shahmukhi')),
            );
            await tester.pumpAndSettle();
            expect(done(tester).onPressed, isNotNull);
            await tester.tap(find.byKey(const ValueKey<String>('know-done')));
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsNothing);
            await tester.enterText(
              find.byKey(const ValueKey<String>('known-search')),
              '',
            );
            await tester.pumpAndSettle();
            expect(find.text('Can read the Shahmukhi script'), findsOneWidget);
            await tester.tap(find.text(l10n.knownSave));
            await tester.pumpAndSettle();
            expect(state.settings.spokenLanguages, ['pa']);
            expect(state.settings.scriptsRead, <String, bool>{
              'pa': false,
              'pa:shahmukhi': true,
            });
          }
        },
      );
    });

    group('a language written in several scripts (#551)', () {
      testWidgets('a save from before #551 reads as the language\'s own '
          'script, and removing the language drops every answer', (
        tester,
      ) async {
        usePhone(tester);
        final settings = SettingsNotifier(
          spokenLanguages: const <String>['pa', 'as'],
        )..restore(const {'scripts_read': '{"pa":true,"as":true}'});
        await openPage(tester, settings);
        final l10n = l10nOf(tester);
        expect(find.text('Can read the Gurmukhi script'), findsOneWidget);
        expect(find.text('Can read the Eastern Nagari script'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey<String>('lang-pa')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey<String>('know-script-gurmukhi')),
              )
              .value,
          isTrue,
        );
        await tester.tap(find.byKey(const ValueKey<String>('know-remove')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.knownSave));
        await tester.pumpAndSettle();
        expect(settings.spokenLanguages, ['as']);
        expect(settings.scriptsRead, <String, bool>{'as': true});
      });
    });
  });
}
