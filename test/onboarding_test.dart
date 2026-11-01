// Onboarding: the app opens on Today with real decks and the bar switches
// tabs; the tour walks, skips, goes back as Android back does, and claims
// only what ships; a double tap cannot skip a step; the sound check asks for
// the microphone only on Record and saves speaking and listening as it
// found them; the first launch explains what Know and Learn mean, then lists
// the languages, finds one by its English or its own name or an alias, asks
// which script is read in the language's own script (the English under the
// question only), takes Know and Learn on the Languages page's skills sheet,
// saves them as skills with the older lists in step, and reads saves from
// before skills as skills.

import 'dart:io';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/language_skills.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/core/sound/sound_check.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/languages/skill_widgets.dart';
import 'package:fluenough/features/onboarding/languages_step.dart';
import 'package:fluenough/features/onboarding/onboarding_flow.dart';
import 'package:fluenough/features/onboarding/onboarding_step.dart';
import 'package:fluenough/features/onboarding/sound_check_step.dart';
import 'package:fluenough/features/onboarding/tour_step.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/profiles/spoken_languages_picker.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/stats/stats_page.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/fluenough_mark.dart';
import 'package:fluenough/ui/widgets/language_bar.dart';
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

    testWidgets(
      'a sideways swipe changes tab and stops at the ends; the language bar '
      'and an upright drag keep theirs (#683)',
      (tester) async {
        usePhone(tester);
        final state = await pumpApp(
          tester,
          state: AppState.test(
            settings: SettingsNotifier(
              spokenLanguages: const <String>['en'],
              learningLanguages: const <String>['hi', 'bn'],
              learningChosen: true,
              languageChoice: 'hi',
            ),
          ),
        );
        Future<void> swipeOn(Type page, Offset by) async {
          await tester.dragFrom(
            tester.getCenter(find.byType(page).hitTestable()),
            by,
          );
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }

        int selected() => tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .selectedIndex;

        // Left on Home: Decks, and the bar follows. Right: back to Home.
        await swipeOn(TodayPage, const Offset(-250, 0));
        expect(state.shellTab.value, ShellTab.decks);
        expect(showing(tester, DecksPage), isTrue);
        expect(selected(), ShellTab.decks.index);
        await swipeOn(DecksPage, const Offset(250, 0));
        expect(state.shellTab.value, ShellTab.today);
        // Right on Home: nothing before it.
        await swipeOn(TodayPage, const Offset(250, 0));
        expect(state.shellTab.value, ShellTab.today);

        // An upright drag scrolls, and the tab stays.
        await swipeOn(TodayPage, const Offset(30, -300));
        expect(state.shellTab.value, ShellTab.today);

        // A swipe on the language bar changes the language, not the tab.
        await tester.drag(
          find
              .descendant(
                of: find.byType(LanguageBar),
                matching: find.byType(GestureDetector),
              )
              .hitTestable()
              .first,
          const Offset(-44, 0),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(state.shownLanguage, 'bn');
        expect(state.shellTab.value, ShellTab.today);

        // Left on Settings: nothing after it.
        state.shellTab.value = ShellTab.settings;
        await tester.pumpAndSettle();
        await swipeOn(SettingsPage, const Offset(-250, 0));
        expect(state.shellTab.value, ShellTab.settings);
        expect(selected(), ShellTab.settings.index);
      },
    );

    testWidgets(
      'the pages follow the finger and the bar follows them; a short slow '
      'drag springs back, a tap on the bar slides to the tab (#683)',
      (tester) async {
        usePhone(tester);
        final state = await pumpApp(
          tester,
          state: AppState.test(
            settings: SettingsNotifier(
              spokenLanguages: const <String>['en'],
              learningLanguages: const <String>['hi', 'bn'],
              learningChosen: true,
              languageChoice: 'hi',
            ),
          ),
        );
        int selected() => tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .selectedIndex;
        final width = tester.getSize(find.byType(TodayPage)).width;

        // Held a little way across, the pages are between the two tabs, and
        // the bar is on the nearer one.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(TodayPage)),
        );
        // The first move only wins the drag: the pages follow the finger from
        // where it won, like a finger that moves in many small steps.
        await gesture.moveBy(const Offset(-24, 0));
        await tester.pump();
        await gesture.moveBy(Offset(-width * 0.3, 0));
        await tester.pump();
        expect(
          tester.getTopLeft(find.byType(DecksPage)).dx,
          closeTo(width * 0.7, 30),
        );
        expect(selected(), ShellTab.today.index);
        await gesture.moveBy(Offset(-width * 0.3, 0));
        await tester.pump();
        expect(selected(), ShellTab.decks.index);

        // Let go slowly, less than half a page from Home: it springs back.
        await gesture.moveBy(Offset(width * 0.4, 0));
        await tester.pump(const Duration(seconds: 1));
        await gesture.up();
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(state.shellTab.value, ShellTab.today);
        expect(selected(), ShellTab.today.index);
        expect(tester.getTopLeft(find.byType(TodayPage)).dx, 0);

        // A tap on the bar slides there.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.byIcon(Icons.insert_chart_outlined),
          ),
        );
        await tester.pump(); // the slide's first frame starts its clock
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.getTopLeft(find.byType(StatsPage)).dx, greaterThan(0));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(state.shellTab.value, ShellTab.progress);
        expect(showing(tester, StatsPage), isTrue);
        expect(tester.getTopLeft(find.byType(StatsPage)).dx, 0);
      },
    );
  });

  group('the tab pager', () {
    Future<AppState> pumpPager(WidgetTester tester) async {
      usePhone(tester);
      return pumpApp(
        tester,
        state: AppState.test(
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningLanguages: const <String>['hi', 'bn'],
            learningChosen: true,
            languageChoice: 'hi',
          ),
        ),
      );
    }

    int selected(WidgetTester tester) =>
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

    Finder barIcon(IconData icon) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(icon),
    );

    List<String> opened(AppState state) => <String>[
      for (final e in state.log.entries)
        if (e.message.startsWith('Opened tab')) e.message,
    ];

    testWidgets('a fast fling commits to the next tab however short it is', (
      tester,
    ) async {
      final state = await pumpPager(tester);
      await tester.fling(find.byType(TodayPage), const Offset(-60, 0), 1500);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shellTab.value, ShellTab.decks);
      expect(showing(tester, DecksPage), isTrue);
      expect(selected(tester), ShellTab.decks.index);
    });

    testWidgets('a cancelled drag springs back to the page it started on', (
      tester,
    ) async {
      final state = await pumpPager(tester);
      final width = tester.getSize(find.byType(TodayPage)).width;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TodayPage)),
      );
      await gesture.moveBy(const Offset(-24, 0)); // wins the drag
      await tester.pump();
      await gesture.moveBy(Offset(-width * 0.7, 0));
      await tester.pump();
      expect(selected(tester), ShellTab.decks.index);
      await gesture.cancel();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shellTab.value, ShellTab.today);
      expect(selected(tester), ShellTab.today.index);
      expect(tester.getTopLeft(find.byType(TodayPage)).dx, 0);
    });

    testWidgets('with reduce motion a tap on the bar switches at once', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final state = await pumpPager(tester);
      await tester.tap(barIcon(Icons.insert_chart_outlined));
      await tester.pump();
      expect(state.shellTab.value, ShellTab.progress);
      expect(tester.getTopLeft(find.byType(StatsPage)).dx, 0);
      expect(showing(tester, StatsPage), isTrue);
    });

    testWidgets('a touch catches the pages mid-slide and sets them down on '
        'the nearest tab', (tester) async {
      final state = await pumpPager(tester);
      // Today is offstage once the pages slide away: read its width first.
      final width = tester.getSize(find.byType(TodayPage)).width;
      await tester.tap(barIcon(Icons.insert_chart_outlined));
      await tester.pump(); // the slide's first frame starts its clock
      await tester.pump(const Duration(milliseconds: 100));
      final caught = tester.getTopLeft(find.byType(StatsPage)).dx;
      expect(caught, greaterThan(0));
      final gesture = await tester.startGesture(const Offset(200, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getTopLeft(find.byType(StatsPage)).dx, closeTo(caught, 1));
      // Stats is the third page: its left edge is two pages less the offset.
      final nearest = ShellTab.values[((2 * width - caught) / width).round()];
      await gesture.up();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shellTab.value, nearest);
      expect(selected(tester), nearest.index);
      expect(
        tester
            .getTopLeft(
              find.byType(nearest == ShellTab.decks ? DecksPage : StatsPage),
            )
            .dx,
        0,
      );
    });

    testWidgets('a tap on the bar selects the target throughout, with no '
        'flicker back and no walk through the middle tabs', (tester) async {
      final state = await pumpPager(tester);
      await tester.tap(barIcon(Icons.settings_outlined));
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(selected(tester), ShellTab.settings.index);
        expect(state.shellTab.value, ShellTab.settings);
      }
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(showing(tester, SettingsPage), isTrue);
    });

    testWidgets('only the tab the pages settle on is logged', (tester) async {
      final state = await pumpPager(tester);
      final width = tester.getSize(find.byType(TodayPage)).width;

      // Over halfway and back: the bar passes Decks, nothing is logged.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TodayPage)),
      );
      await gesture.moveBy(Offset(-width * 0.7, 0));
      await tester.pump();
      await gesture.moveBy(Offset(width * 0.6, 0));
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shellTab.value, ShellTab.today);
      expect(opened(state), isEmpty);

      // A tap two tabs away logs the target once, not Decks on the way.
      await tester.tap(barIcon(Icons.settings_outlined));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(opened(state), <String>['Opened tab settings']);

      // A swipe back one tab logs that tab once.
      await tester.fling(find.byType(SettingsPage), const Offset(300, 0), 1500);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(opened(state), <String>[
        'Opened tab settings',
        'Opened tab progress',
      ]);
    });
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
      await tester.pumpWidget(FluenoughApp(key: UniqueKey(), state: state));
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

      // What Know and Learn mean comes first (owner, 2026-11-01), with what
      // the answer is for and where it is kept, and where to change it.
      expect(find.text(l10n.onboardingLanguagesTitle), findsOneWidget);
      final privacy = find.text(
        l10n.onboardingSpokenPrivacy(l10n.navSettings, l10n.languagesTitle),
      );
      await scrollToFind(tester, privacy);
      expect(privacy, findsOneWidget);
      await tester.tap(find.text(l10n.onboardingLanguagesAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.onboardingLanguagesListTitle), findsOneWidget);
      expect(find.text(l10n.onboardingLanguagesListBody), findsOneWidget);
      expect(find.byType(WaveProgress), findsNothing, reason: 'one question');
      expect(find.text(l10n.onboardingSpokenNeedOne), findsOneWidget);
      final go = find.widgetWithText(FilledButton, l10n.commonContinue);
      expect(tester.widget<FilledButton>(go).onPressed, isNull);
      // Choosing Hindustani asks which of its scripts are read (#462,
      // #490), which nothing assumes.
      await knowLanguage(tester, 'hi', 'Hindustani');
      expect(find.text(l10n.onboardingSpokenNeedOne), findsNothing);
      expect(settings.spokenLanguages, isEmpty, reason: 'nothing saved yet');
      expect(tester.widget<FilledButton>(go).onPressed, isNotNull);

      await tester.tap(go);
      await tester.pumpAndSettle();
      // English is known by default (#926), so Continue adds it, last.
      expect(settings.spokenLanguages, ['hi', 'en']);
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
      File(spokenLanguagesAsset).readAsStringSync(),
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

    /// Goes on to the languages question, picks Bengali and saves.
    Future<void> finish(WidgetTester tester) async {
      final l10n = l10nOf(tester);
      await tap(tester, find.text(l10n.onboardingNext));
      await tap(tester, find.text(l10n.onboardingLanguagesAction));
      await knowLanguage(tester, 'bn', 'Bengali');
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

  group('Languages on the first launch', () {
    // A cached asset's future belongs to the test that first read it.
    setUp(rootBundle.clear);

    final choices = parseSpokenLanguages(
      File(spokenLanguagesAsset).readAsStringSync(),
    );
    SpokenLanguage language(String code) =>
        choices.firstWhere((l) => l.code == code);

    const devanagariAnswer = 'मुझे देवनागरी लिपि पढ़नी आती है';
    const urduAnswer = 'مجھے فارسی-عربی (اردو) رسم الخط پڑھنا آتا ہے';

    /// The first launch at its list of languages, at 1.4x text.
    Future<AppState> atList(
      WidgetTester tester, {
      SettingsNotifier? settings,
      ThemeMode mode = ThemeMode.light,
    }) {
      usePhone(tester, textScale: 1.4);
      return pumpScreen(
        tester,
        OnboardingFlow(startAt: 'languages', choices: choices),
        state: AppState.test(settings: settings ?? SettingsNotifier()),
        themeMode: mode,
      );
    }

    Finder continueButton(WidgetTester tester) =>
        find.widgetWithText(FilledButton, l10nOf(tester).commonContinue);

    Future<void> tapKey(WidgetTester tester, String key) async {
      final finder = find.byKey(ValueKey<String>(key));
      await scrollListTo(tester, finder);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    /// Add a language, the search and the row of [code]: opens the Know sheet
    /// of a language that asks one, else its skills sheet.
    Future<void> openAdd(WidgetTester tester, String code, String name) async {
      await tapKey(tester, 'onboarding-add-language');
      await tester.enterText(
        find.byKey(const ValueKey<String>('languages-add-search')),
        name,
      );
      await tester.pumpAndSettle();
      await tapKey(tester, 'add-$code');
    }

    /// A section heading of the list ("Know · 1"), scrolled to first: the list
    /// builds its children as they come into view, so one below the fold is
    /// not in the tree yet.
    Future<void> expectHeading(WidgetTester tester, String text) async {
      final heading = find.text(text);
      await scrollToFind(tester, heading);
      expect(heading, findsOneWidget);
    }

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

    TextDirection directionOf(WidgetTester tester, Finder text) => tester
        .renderObject<RenderParagraph>(
          find.descendant(of: text, matching: find.byType(RichText)).first,
        )
        .textDirection;

    SkillMark markOfPill(WidgetTester tester, String key) =>
        tester.widget<SkillBadge>(find.byKey(ValueKey<String>(key))).mark;

    testWidgets('the explanation says what the options mean in plain words, '
        'then Choose my languages goes on to the list', (tester) async {
      usePhone(tester, textScale: 1.4);
      await pumpScreen(
        tester,
        OnboardingFlow(startAt: 'languages-intro', choices: choices),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.onboardingLanguagesTitle), findsOneWidget);
      expect(find.text(l10n.onboardingLanguagesIntro), findsOneWidget);
      for (final meaning in <String>[
        l10n.onboardingLanguagesLearnMeaning,
        l10n.onboardingLanguagesKnowMeaning,
        l10n.onboardingLanguagesLeaveMeaning,
      ]) {
        expect(
          find.textContaining(meaning, findRichText: true),
          findsOneWidget,
          reason: meaning,
        );
      }
      // The pills as the learner will meet them: three levels, the four a tap
      // steps through, and the double tick. Icons only: a touch and hold says
      // each in words.
      expect(find.byType(SkillBadge), findsNWidgets(8));
      expect(find.byTooltip(l10n.languagesPillLeave), findsNWidgets(2));
      expect(find.byTooltip(l10n.languagesPillLearning), findsNWidgets(2));
      expect(
        find.byTooltip(l10n.languagesPillChecked(l10n.languagesPillHearSpeak)),
        findsOneWidget,
      );
      for (final skill in <String>[
        l10n.languagesSkillRead,
        l10n.languagesSkillWrite,
        l10n.languagesSkillHear,
        l10n.languagesSkillSpeak,
      ]) {
        expect(find.text(skill), findsOneWidget, reason: skill);
      }
      expect(
        find.text(l10n.onboardingLanguagesChecked(l10n.languagesFindLevel)),
        findsOneWidget,
      );
      expect(find.text(l10n.onboardingSkip), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(l10n.onboardingLanguagesAction));
      await tester.pumpAndSettle();
      expect(find.text(l10n.onboardingLanguagesListTitle), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(l10n.onboardingLanguagesTitle), findsOneWidget);
      await tester.tap(find.text(l10n.onboardingSkip));
      await tester.pumpAndSettle();
      expect(find.text(l10n.onboardingLanguagesListTitle), findsOneWidget);
    });

    testWidgets('the list starts with English known; Next waits for a '
        'language besides it, and nothing is saved before the last button', (
      tester,
    ) async {
      final settings = SettingsNotifier();
      await atList(tester, settings: settings);
      final l10n = l10nOf(tester);
      await expectHeading(tester, l10n.languagesSectionKnow(1));
      expect(find.byKey(const ValueKey<String>('language-en')), findsOneWidget);
      expect(find.text(l10n.onboardingSpokenNeedOne), findsOneWidget);
      expect(
        tester.widget<FilledButton>(continueButton(tester)).onPressed,
        isNull,
      );

      await knowLanguage(tester, 'bn', 'Bengali');
      expect(find.text(l10n.onboardingSpokenNeedOne), findsNothing);
      expect(find.byKey(const ValueKey<String>('language-bn')), findsOneWidget);
      await expectHeading(tester, l10n.languagesSectionKnow(2));
      expect(
        tester.widget<FilledButton>(continueButton(tester)).onPressed,
        isNotNull,
      );
      expect(settings.spokenLanguages, isEmpty);
      expect(settings.languageSkillsOf('bn'), isNull);
    });

    testWidgets('Know and Learn set on the shared sheet are saved as skills, '
        'and the older lists follow', (tester) async {
      final settings = SettingsNotifier();
      final state = await atList(tester, settings: settings);
      final l10n = l10nOf(tester);
      // Bengali: the Know sheet reads its script, the sheet adds it as known.
      await knowLanguage(tester, 'bn', 'Bengali');
      // Spanish is written in Latin letters, which everyone who knows English
      // reads: no script question, the skills sheet at once, the Latin
      // script already known from English. Learn it (a check that needs no
      // voice), then Add.
      await openAdd(tester, 'es', 'Spanish');
      expect(find.byKey(const ValueKey<String>('know-read')), findsNothing);
      expect(markOfPill(tester, 'skill-script:latin'), SkillMark.knowBoth);
      await tapKey(tester, 'skill-script:latin');
      await tapKey(tester, 'skill-script:latin');
      expect(markOfPill(tester, 'skill-script:latin'), SkillMark.learn);
      await tester.tap(find.text(l10n.languagesCheck));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.languagesAddLanguage('Spanish')));
      await tester.pumpAndSettle();

      await expectHeading(tester, l10n.languagesSectionLearning(1));
      await expectHeading(tester, l10n.languagesSectionKnow(2));
      expect(settings.spokenLanguages, isEmpty, reason: 'nothing saved yet');
      expect(settings.languageSkillsOf('es'), isNull);

      await tester.tap(continueButton(tester));
      await tester.pumpAndSettle();
      expect(
        settings.languageSkillsOf('es'),
        containsPair('read:latin', 'learn'),
      );
      expect(
        settings.languageSkillsOf('bn'),
        allOf(
          containsPair('speak', 'know'),
          containsPair('hear', 'know'),
          containsPair('read:bengali', 'know'),
        ),
      );
      expect(state.learningCodes, contains('es'));
      expect(settings.learningChosen, isTrue);
      expect(settings.spokenLanguages, ['bn', 'en']);
      expect(settings.scriptsRead, <String, bool>{'bn': true, 'en': true});
    });

    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('the Know sheet of a language in several scripts asks in its '
          'own script, with English under the question only, and the '
          'Perso-Arabic answer reads right to left (${mode.name}, 1.4x)', (
        tester,
      ) async {
        await atList(tester, mode: mode);
        final l10n = l10nOf(tester);
        await openAdd(tester, 'hi', 'Hindustani');

        // The question: own script, with its English under it.
        expect(
          find.text('आप हिन्दुस्तानी किन लिपियों में पढ़ सकते हैं?'),
          findsOneWidget,
        );
        expect(
          find.text(l10n.knownReadsWhichScripts('Hindustani')),
          findsOneWidget,
        );
        // Every answer line is its own script alone.
        expect(find.text('I can read the Devanagari script'), findsNothing);
        expect(find.text('I can read the Perso-Arabic script'), findsNothing);
        expect(find.text(devanagariAnswer), findsOneWidget);
        expect(
          markedAs(tester, find.text(devanagariAnswer)),
          const Locale('hi'),
        );
        expect(
          directionOf(tester, find.text(devanagariAnswer)),
          TextDirection.ltr,
        );
        // The Perso-Arabic answer is in Perso-Arabic script: Urdu, right to
        // left.
        expect(find.text(urduAnswer), findsOneWidget);
        expect(markedAs(tester, find.text(urduAnswer)), const Locale('ur'));
        expect(directionOf(tester, find.text(urduAnswer)), TextDirection.rtl);
        // Not checked by a speaker yet: the bug icon is there.
        expect(find.byKey(const ValueKey<String>('know-report')), findsOne);
        // "Only speak" is English only.
        expect(find.text('I can only speak Hindustani'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Done waits for a script; Perso-Arabic ticked and the skills sheet
        // opens with it known and Devanagari not.
        final done = find.byKey(const ValueKey<String>('know-done'));
        expect(tester.widget<FilledButton>(done).onPressed, isNull);
        await tester.tap(
          find.byKey(const ValueKey<String>('know-script-perso_arabic')),
        );
        await tester.pumpAndSettle();
        await tester.tap(done);
        await tester.pumpAndSettle();
        expect(markOfPill(tester, 'skill-script:perso_arabic'), SkillMark.know);
        expect(markOfPill(tester, 'skill-script:devanagari'), SkillMark.leave);
        expect(markOfPill(tester, 'skill-spoken'), SkillMark.knowBoth);
        await tester.tap(find.text(l10n.languagesAddLanguage('Hindustani')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('language-hi')), findsOne);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the Know sheet of a language in one script asks in it, with '
        'English under the question only', (tester) async {
      await atList(tester);
      await openAdd(tester, 'bn', 'Bengali');
      expect(
        find.text('আপনি কি পূর্ব নাগরী লিপি পড়তে পারেন?'),
        findsOneWidget,
      );
      expect(find.text('Do you read the Eastern Nagari script?'), findsOne);
      expect(find.text('আমি পূর্ব নাগরী লিপি পড়তে পারি'), findsOneWidget);
      expect(find.text('I can read the Eastern Nagari script'), findsNothing);
      expect(
        markedAs(tester, find.text('আমি পূর্ব নাগরী লিপি পড়তে পারি')),
        const Locale('bn'),
      );
      expect(find.text('I can only speak Bengali'), findsOneWidget);
      // Never Yes or No.
      expect(find.text('Yes'), findsNothing);
      expect(find.text('No'), findsNothing);
    });

    testWidgets('leaving the Know sheet unanswered goes on to an empty '
        'skills sheet, which waits for a skill', (tester) async {
      await atList(tester);
      final l10n = l10nOf(tester);
      await openAdd(tester, 'bn', 'Bengali');
      await tapKey(tester, 'know-cancel');
      expect(find.text(l10n.languagesSetOne), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l10n.languagesSetOne),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('a language already on the list opens its skills sheet with '
        'what was set, and setting every skill to Leave takes it off', (
      tester,
    ) async {
      await atList(tester);
      final l10n = l10nOf(tester);
      await knowLanguage(tester, 'bn', 'Bengali');
      await tapKey(tester, 'language-bn');
      expect(markOfPill(tester, 'skill-spoken'), SkillMark.knowBoth);
      expect(markOfPill(tester, 'skill-script:bengali'), SkillMark.know);
      // Hear and Speak to Leave; Read to Read and Write to Leave.
      await tapKey(tester, 'skill-spoken');
      await tapKey(tester, 'skill-script:bengali');
      await tapKey(tester, 'skill-script:bengali');
      await tester.tap(find.text(l10n.languagesDone));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('language-bn')), findsNothing);
      expect(find.text(l10n.onboardingSpokenNeedOne), findsOneWidget);
    });

    testWidgets('the shared list finds a language by its English name, its '
        'own name or an alias, and leaves English out', (tester) async {
      await atList(tester);
      await tapKey(tester, 'onboarding-add-language');
      final search = find.byKey(const ValueKey<String>('languages-add-search'));
      await tester.enterText(search, 'Urdu');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('add-hi')), findsOneWidget);
      await tester.enterText(search, 'বাং');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('add-bn')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('add-hi')), findsNothing);
      await tester.enterText(search, 'English');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('add-en')), findsNothing);
    });

    test('a language asks which script is read only where that is a question: '
        'not Latin letters alone, a sign language or a script-only course', () {
      expect(asksWhichScripts(language('es')), isFalse);
      expect(asksWhichScripts(language('hi')), isTrue);
      expect(asksWhichScripts(language('bn')), isTrue);
      expect(asksWhichScripts(language('ase')), isFalse);
    });

    test('the Know sheet\'s reply becomes skills: hearing and speaking, and '
        'Read for each script read', () {
      final hi = language('hi');
      final reads = skillsFromKnownReply(
        hi,
        const KnownReply.reads(<String>['devanagari']),
      );
      expect(reads.spokenLevel, SpokenLevel.hearSpeak);
      expect(reads.scriptLevelOf('devanagari'), ScriptLevel.read);
      expect(reads.scriptLevelOf('perso_arabic'), ScriptLevel.leave);
      final speaks = skillsFromKnownReply(hi, const KnownReply.speaksOnly());
      expect(speaks.spokenLevel, SpokenLevel.hearSpeak);
      expect(speaks.scriptLevelOf('devanagari'), ScriptLevel.leave);
      expect(speaks.anyLearn, isFalse);
    });

    test('an answer is marked and drawn by its own script: Perso-Arabic is '
        'Urdu and right to left where it is a second script', () {
      expect(SpokenLanguage.isRtlText(urduAnswer), isTrue);
      expect(SpokenLanguage.isRtlText(devanagariAnswer), isFalse);
      expect(language('hi').localeCodeFor(urduAnswer), 'ur');
      expect(language('hi').localeCodeFor(devanagariAnswer), 'hi');
      // Punjabi's Shahmukhi answer is written in Gurmukhi: left to right.
      final shahmukhi = language('pa').canReadIn('shahmukhi')!;
      expect(SpokenLanguage.isRtlText(shahmukhi), isFalse);
      expect(language('pa').localeCodeFor(shahmukhi), 'pa');
      // Where Perso-Arabic is the language's own script, its own code.
      expect(language('sd').localeCodeFor(urduAnswer), 'sd');
    });
  });

  group('the older lists and skills agree', () {
    final choices = parseSpokenLanguages(
      File(spokenLanguagesAsset).readAsStringSync(),
    );
    SpokenLanguage language(String code) =>
        choices.firstWhere((l) => l.code == code);

    test('skills saved by the first launch read back the same, and the older '
        'lists the other screens read are kept right', () async {
      final bn = language('bn');
      final es = language('es');
      final known = skillsFromKnownReply(
        bn,
        const KnownReply.reads(<String>['bengali']),
      );
      final learn = LanguageSkills().withScriptLevel(
        'latin',
        ScriptLevel.learn,
      );
      final state = AppState.test(settings: SettingsNotifier());
      addTearDown(state.dispose);
      await state.load();
      OnboardingAnswers()
        ..setSkills(bn, known)
        ..setSkills(es, learn)
        ..saveTo(state);

      expect(state.skillsOf(bn), known);
      expect(state.skillsOf(es), learn);
      expect(state.skillsOf(language('en')), englishKnownByDefault());
      // What the review-languages, fact-languages and script-offers screens
      // read: who speaks what, which scripts are read, what is learned.
      expect(state.settings.spokenLanguages, ['bn', 'en']);
      expect(state.settings.scriptsRead, <String, bool>{
        'bn': true,
        'en': true,
      });
      expect(state.learningCodes, {'es'});
      expect(scriptReaders(choices, state.settings.scriptsRead), {
        'bengali': ['bn'],
        'latin': ['en'],
      });
    });

    test('a language set to Leave, or English, is not saved as chosen', () {
      final answers = OnboardingAnswers()
        ..setSkills(language('bn'), LanguageSkills())
        ..setSkills(language('en'), englishKnownByDefault());
      expect(answers.chosen, isEmpty);
    });

    test(
      'saves from before skills read as skills until they are edited',
      () async {
        final settings = SettingsNotifier(
          spokenLanguages: const <String>['bn', 'en'],
          learningLanguages: const <String>['es'],
          learningChosen: true,
        )..restore(const {'scripts_read': '{"bn":true,"en":true}'});
        final state = AppState.test(settings: settings);
        addTearDown(state.dispose);
        await state.load();

        final bn = state.skillsOf(language('bn'));
        expect(bn.spokenLevel, SpokenLevel.hearSpeak);
        expect(bn.scriptLevelOf('bengali'), ScriptLevel.read);
        expect(state.skillsOf(language('es')).anyLearn, isTrue);
        expect(state.skillsOf(language('hi')).isAllLeave, isTrue);
        // Nothing was written by reading.
        expect(settings.languageSkillsOf('bn'), isNull);
      },
    );
  });
}
