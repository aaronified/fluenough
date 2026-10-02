import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/features/onboarding/onboarding_flow.dart';
import 'package:fluenough/features/onboarding/onboarding_step.dart';
import 'package:fluenough/features/onboarding/tour_step.dart';
import 'package:fluenough/features/profiles/spoken_languages_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';

import '../../support/harness.dart';

void main() {
  // A cached asset's future belongs to the test that first read it.
  setUp(rootBundle.clear);

  final choices = parseSpokenLanguages(
    File(SpokenLanguagesPage.asset).readAsStringSync(),
  );

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

  testWidgets('Next walks the welcome, every slide and the question', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final settings = await firstLaunch(tester);
    final l10n = l10nOf(tester);

    expect(find.text(l10n.appTitle), findsOneWidget);
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

    expect(find.text(l10n.onboardingSpokenTitle), findsOneWidget);
    expect(find.text(l10n.onboardingSpokenNeedOne), findsOneWidget);
    final go = find.widgetWithText(FilledButton, l10n.onboardingFinish);
    expect(tester.widget<FilledButton>(go).onPressed, isNull);
    await tester.tap(find.text(l10n.spokenOption('Hindi', 'हिन्दी')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.onboardingSpokenNeedOne), findsNothing);
    expect(settings.spokenLanguages, isEmpty, reason: 'nothing saved yet');

    await tester.tap(go);
    await tester.pumpAndSettle();
    expect(settings.spokenLanguages, ['hi']);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
    semantics.dispose();
  });

  testWidgets('a swipe turns the slide; Skip; back returns where it left', (
    tester,
  ) async {
    final settings = await firstLaunch(tester);
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.onboardingStart));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text(title(l10n, 1)), findsOneWidget);

    await tester.tap(find.text(l10n.onboardingSkip));
    await tester.pumpAndSettle();
    expect(find.text(l10n.onboardingSpokenTitle), findsOneWidget);

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
  });

  testWidgets('the on-screen Back does what Android back does', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, const OnboardingFlow(startAt: 'tour', page: 2));
    final l10n = l10nOf(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(title(l10n, 1)), findsOneWidget);
  });

  testWidgets('ticks survive going back to the tour', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      OnboardingFlow(startAt: 'spoken', choices: choices),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.spokenOption('Bengali', 'বাংলা')));
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(title(l10n, tourSlides.length - 1)), findsOneWidget);
    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pumpAndSettle();
    expect(find.text(l10n.spokenRank(1)), findsOneWidget);
    expect(state.settings.spokenLanguages, ['en'], reason: 'not saved');
  });

  testWidgets('a double tap cannot skip a step', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, const OnboardingFlow());
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.onboardingStart));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(title(l10n, 0)), findsOneWidget);
  });

  testWidgets('with animations off, nothing moves', (tester) async {
    usePhone(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: OnboardingFlow(),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse, reason: 'no entrance');

    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.onboardingStart));
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.appTitle), findsNothing);
    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pump();
    final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(pages.page, 1.0);
  });

  testWidgets('a screen reader hears where it is', (tester) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester, const OnboardingFlow(startAt: 'tour'));
    final l10n = l10nOf(tester);
    expect(
      tester.getSemantics(find.byType(TourDots)),
      isSemantics(
        label: l10n.onboardingTourPosition(1, 4, title(l10n, 0)),
        isLiveRegion: true,
      ),
    );
    expect(
      tester.getSemantics(find.text(title(l10n, 0))),
      isSemantics(isHeader: true, namesRoute: true),
    );
    expect(
      tester.getSemantics(
        find.descendant(
          of: find.byType(OnboardingFlow),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.scopesRoute ?? false),
          ),
        ),
      ),
      isSemantics(scopesRoute: true),
    );
    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byType(TourDots)),
      isSemantics(label: l10n.onboardingTourPosition(2, 4, title(l10n, 1))),
    );
    semantics.dispose();
  });

  testWidgets('a second question gets a progress bar, and Next', (
    tester,
  ) async {
    usePhone(tester);
    final settings = SettingsNotifier();
    await pumpScreen(
      tester,
      OnboardingFlow(
        steps: <OnboardingStep>[
          ...onboardingSteps,
          OnboardingStep(
            id: 'probe',
            asks: true,
            content: (_, _) => const SizedBox(),
          ),
        ],
        startAt: 'spoken',
        spoken: const <String>['bn'],
        choices: choices,
      ),
      state: AppState.test(settings: settings),
    );
    final l10n = l10nOf(tester);
    expect(
      find.bySemanticsLabel(l10n.onboardingQuestionPosition(1, 2)),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(l10n.onboardingQuestionPosition(2, 2)),
      findsOneWidget,
    );
    expect(settings.spokenLanguages, isEmpty);
    await tester.tap(find.text(l10n.onboardingFinish));
    await tester.pumpAndSettle();
    expect(settings.spokenLanguages, ['bn']);
  });

  testWidgets('right to left, the frame and the pages mirror', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const Directionality(
        textDirection: TextDirection.rtl,
        child: OnboardingFlow(startAt: 'tour'),
      ),
    );
    final l10n = l10nOf(tester);
    expect(tester.getTopRight(find.text(title(l10n, 0))).dx, 390 - 24);
    expect(tester.getCenter(find.byType(BackButton)).dx, greaterThan(195));
    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text(title(l10n, 1)), findsOneWidget);
  });

  test('the gallery shows every screen of the first launch', () {
    expect(
      allGalleryEntries.map((e) => e.id),
      containsAll(<String>[
        'onboarding-welcome',
        for (final slide in tourSlides) 'onboarding-tour-${slide.id}',
        'onboarding-spoken',
        'onboarding-spoken-ranked',
      ]),
    );
  });
}
