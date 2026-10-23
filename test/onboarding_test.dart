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

    testWidgets('a swipe that starts on the Decks search bar changes tab too, '
        'and the bar still takes a tap (#773)', (tester) async {
      final state = await pumpPager(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.style_outlined),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shellTab.value, ShellTab.decks);

      final search = find.byType(SearchBar);
      // The path opens scrolled to the unit up next, the bar above the screen.
      await tester.ensureVisible(search);
      await tester.pumpAndSettle();
      await tester.tap(search);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Left: Progress. Right: back to Decks.
      await tester.dragFrom(tester.getCenter(search), const Offset(-250, 0));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shellTab.value, ShellTab.progress);
      await tester.dragFrom(
        tester.getCenter(find.byType(StatsPage).hitTestable()),
        const Offset(250, 0),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shellTab.value, ShellTab.decks);
      await tester.dragFrom(tester.getCenter(search), const Offset(250, 0));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shellTab.value, ShellTab.today);
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
