// Accessibility at 1.4x text, the app's cap (#505; owner, 2026-10-17: "We
// are now only building for 1.4x text"). One test per screen, drawing it in
// light and in dark on a phone with Android's three-button bar: nothing
// overflows or is clipped, nothing sits under the bar, tap targets are big
// enough, every control is labelled, and text meets contrast. Beside them:
// the screen reader never reads out the answer asked for; deck text in an
// interface string is read in its own language; the first launch in high
// contrast and every colour; a phone at 2x text is drawn at 1.4x; a toast is
// a live region.
import 'dart:io';
import 'dart:ui' show LocaleStringAttribute;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/feedback/report.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/numbers/number_practice.dart';
import 'package:fluenough/core/scheduling/session_queue.dart' show Ask;
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/path_fixture.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/recognition_drill.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/features/onboarding/onboarding_flow.dart';
import 'package:fluenough/features/onboarding/tour_step.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/placement/script_test_page.dart';
import 'package:fluenough/features/profiles/spoken_languages_page.dart';
import 'package:fluenough/features/report/report_page.dart';
import 'package:fluenough/features/review/offensive_review_page.dart';
import 'package:fluenough/features/review/review_page.dart';
import 'package:fluenough/features/review/waiting_page.dart';
import 'package:fluenough/features/settings/activities_page.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/your_data_page.dart';
import 'package:fluenough/features/stats/how_you_learn_page.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:fluenough/ui/theme.dart';
import 'package:fluenough/ui/widgets/braille_keyboard.dart';
import 'package:fluenough/ui/widgets/snack.dart';
import 'package:fluenough/ui/widgets/target_text.dart';

import 'support/backup_fixture.dart';
import 'support/braille_course.dart';
import 'support/harness.dart';
import 'support/nav_bar_walk.dart';
import 'support/paced_learner.dart';
import 'support/picker.dart';
import 'support/review_fixture.dart';

/// Flutter's accessibility guidelines (#26): tap targets big enough for a
/// drill used fast, every tap target labelled, and text at WCAG AA contrast.
Future<void> meetsEveryGuideline(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

/// The parts of [finder]'s screen-reader label marked as another language,
/// by locale.
Map<String, String> quotedIn(WidgetTester tester, Finder finder) {
  final label = tester.getSemantics(finder).attributedLabel;
  return <String, String>{
    for (final a in label.attributes.whereType<LocaleStringAttribute>())
      label.string.substring(a.range.start, a.range.end): a.locale
          .toLanguageTag(),
  };
}

/// The nodes on the screen reader's tree whose label or value has [text].
FinderBase<SemanticsNode> readsOut(String text) => find.semantics.byPredicate(
  (node) => node.label.contains(text) || node.value.contains(text),
);

/// Taps [finder], scrolling the screen's list to it first.
Future<void> tapShown(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// Scrolls the screen's list, where a tap target is cut by the list's top
/// edge, until that target is whole at the top. A screen that opens part
/// way down a list, as the path opens at the unit up next, cuts the row
/// above wherever it stops; the tap-target guidelines skip a node cut by
/// the screen's edge for that reason, but not one cut by a list's edge
/// below the app bar. Every target on the screen is still checked.
Future<void> noTargetCutAtTop(WidgetTester tester) async {
  final list = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );
  if (list.evaluate().isEmpty) return;
  final top = tester.getTopLeft(list.first).dy;
  final targets = find.descendant(
    of: list.first,
    matching: find.byWidgetPredicate(
      (w) => w is InkWell || (w is Semantics && w.properties.button == true),
    ),
  );
  for (final element in targets.evaluate()) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.top < top - 0.5 && rect.bottom > top + 0.5) {
      await Scrollable.ensureVisible(element);
      await tester.pumpAndSettle();
      return;
    }
  }
}

/// Draws a screen in [mode]; returns nothing, leaving it on screen.
typedef DrawScreen = Future<void> Function(WidgetTester tester, ThemeMode mode);

/// One screen at 1.4x text on a phone with the three-button bar, in light
/// and in dark: nothing overflows, the guidelines hold, and once scrolled
/// to its end nothing is left under the bar (#489, #501).
void screen(String name, DrawScreen draw) {
  testWidgets('$name, at 1.4x text, light and dark', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      usePhone(tester, textScale: 1.4, navBar: true);
      await draw(tester, mode);
      expect(tester.takeException(), isNull, reason: mode.name);
      await noTargetCutAtTop(tester);
      await meetsEveryGuideline(tester);
      expect(
        await underBarAtEnd(tester, within: find.byType(MaterialApp)),
        isEmpty,
        reason: '${mode.name}: under the three-button bar',
      );
    }
    semantics.dispose();
  });
}

/// The gallery's screen [id], on the state it is drawn on there.
DrawScreen gallery(String id) => (tester, mode) async {
  final app = AppState.test();
  await app.load();
  final entry = allGalleryEntries.firstWhere((e) => e.id == id);
  final state = entry.state?.call(app) ?? GalleryFixtures.state(app);
  await pumpScreen(
    tester,
    Builder(builder: entry.builder),
    state: state,
    themeMode: mode,
  );
};

/// [page] on a fresh app, or on the state [state] makes.
DrawScreen page(Widget page, {Future<AppState> Function()? state}) =>
    (tester, mode) async {
      await pumpScreen(
        tester,
        page,
        state: state == null ? null : await state(),
        themeMode: mode,
      );
    };

/// A drill of [request] from [preset].
DrawScreen drill(
  DrillRequest request, [
  DrillPreset preset = const DrillPreset(),
]) => page(
  DrillPage(request: request, preset: preset),
  state: () async => AppState.test(tts: FixedTtsEngine(<String>{'es', 'hi'})),
);

/// The whole app on [tab], for a learner whose pace has been fitted.
DrawScreen tab(ShellTab tab) => (tester, mode) async {
  final state = await pacedLearner(
    Paced.fewer,
    also: <Paced>{Paced.more, Paced.same},
  );
  state.settings.themeMode = mode;
  await pumpApp(tester, state: state);
  state.shellTab.value = tab;
  await tester.pumpAndSettle();
};

/// The design's Telugu learner, on the path (PathFixtures).
Future<AppState> teluguLearner() async {
  final app = AppState.test();
  await app.load();
  return PathFixtures.state(app);
}

/// [page] in reviewer mode, then [open] done on it.
DrawScreen review(
  Widget page, [
  Future<void> Function(WidgetTester tester, AppState state)? open,
]) => (tester, mode) async {
  final state = await pumpScreen(
    tester,
    page,
    state: await reviewState(reviewing: true),
    themeMode: mode,
  );
  if (open != null) {
    await open(tester, state);
    await tester.pumpAndSettle();
  }
};

final List<SpokenLanguage> choices = parseSpokenLanguages(
  File(SpokenLanguagesPage.asset).readAsStringSync(),
);

/// A learner who speaks English and Bengali, reading both, learning
/// Assamese: the script test is offered (#554).
AppState bengaliReader() => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en', 'bn'],
    learningLanguages: const <String>['as'],
    learningChosen: true,
  )..scriptsRead = <String, bool>{'en': true, 'bn': true},
);

/// The example set's files with a set card of five words, split over two
/// cards, added to its home deck (#515).
Map<String, String> setFiles() {
  const appendix = 'test/fixtures/b1/appendix-a/zz';
  final out = <String, String>{
    for (final file in Directory(appendix).listSync(recursive: true))
      if (file is File && file.path.endsWith('.yaml'))
        'decks/zz/${file.path.substring(appendix.length + 1)}': file
            .readAsStringSync(),
  };
  const members = <String>[
    'zz-9001',
    'zz-9004',
    'zz-9006',
    'zz-9003',
    'zz-9002',
  ];
  out['decks/zz/zz-home.yaml'] =
      '${out['decks/zz/zz-home.yaml']}'
      '  - id: "zz-9201"\n'
      '    kind: "set"\n'
      '    members: [${members.map((m) => '{ ref: "$m" }').join(', ')}]\n';
  out['decks/zz/en/zz-en-home.yaml'] = out['decks/zz/en/zz-en-home.yaml']!
      .replaceFirst(
        'cards:\n',
        'cards:\n'
            '  "zz-9201":\n'
            '    native: "First words"\n'
            '    explanation: "Words you meet first, together."\n',
      );
  return out;
}

const Key _say = Key('say');

/// A screen with an app bar and a button that toasts.
class _Toasting extends StatelessWidget {
  const _Toasting();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Screen')),
    body: Center(
      child: Builder(
        builder: (context) => TextButton(
          key: _say,
          onPressed: () => showAppSnackBar(context, 'Saved'),
          child: const Text('Say'),
        ),
      ),
    ),
  );
}

void main() {
  group('Learn', () {
    screen('Today', tab(ShellTab.today));
    screen(
      'the Decks path',
      page(const DecksPage(planOf: PathFixtures.planOf), state: teluguLearner),
    );
    screen(
      'a unit',
      page(
        const UnitPage(
          deckId: PathFixtures.familyDeck,
          plan: PathFixtures.telugu,
        ),
        state: teluguLearner,
      ),
    );
    screen('a deck', page(const DeckDetailPage(deckId: 'hi-en-market')));
    screen('Languages on the phone', gallery('learning-deck-updates'));
    screen(
      'the summary',
      page(
        SummaryPage(
          result: SessionResult(
            answers: const <SessionAnswer>[
              SessionAnswer(skill: Skill.recognition, grade: 4),
              SessionAnswer(skill: Skill.production, grade: 1),
            ],
            startedAt: DateTime(2026, 9, 28, 18, 50),
            endedAt: DateTime(2026, 9, 28, 19),
          ),
        ),
      ),
    );
  });

  group('Drills', () {
    screen('the teach card', gallery('drill-lesson'));
    screen(
      'recognition, revealed',
      drill(
        DrillRequest.deck('es-en-core-100', skill: Skill.recognition),
        const DrillPreset(target: 'la casa', reveal: true),
      ),
    );
    screen('choosing the meaning', gallery('drill-choose-meaning'));
    screen(
      'match pairs, with its tap-to-hear button',
      drill(
        DrillRequest.untaught('es-en-core-100', skill: Skill.recognition),
        const DrillPreset(target: 'la casa', ask: Ask.matchPairs),
      ),
    );
    screen('rearranging', gallery('drill-rearrange'));
    // A typed answer with the keyboard open: the prompt, the field and
    // Check stay in view above it; then its feedback.
    screen('typed production, the keyboard open, then its feedback', (
      tester,
      mode,
    ) async {
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(
            'te-en-first-words',
            skill: Skill.production,
          ),
          preset: const DrillPreset(target: 'నమస్కారం'),
        ),
        themeMode: mode,
      );
      await tester.enterText(find.byType(TextField), 'nama');
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      for (final shown in <Finder>[
        find.byType(TextField),
        find.text(l10n.drillCheck),
      ]) {
        expect(shown.hitTestable(), findsOneWidget);
        expect(tester.getRect(shown).bottom, lessThanOrEqualTo(844 - 336));
      }
      expect(tester.takeException(), isNull);
      await meetsEveryGuideline(tester);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.drillCheck));
      await tester.pumpAndSettle();
    });
    screen(
      'listening',
      drill(DrillRequest.deck('es-en-core-100', skill: Skill.listening)),
    );
    screen('speaking', gallery('drill-speaking'));
    screen('grammar, answered', gallery('drill-grammar-right'));
    screen('minimal pairs, a wrong pick', gallery('drill-pair-wrong'));
    screen(
      'a reading passage, its glossary open',
      gallery('drill-reading-glossary'),
    );
    screen(
      'a split set card',
      page(
        DrillPage(
          request: DrillRequest.lesson(language: 'zz', deckId: 'zz-en-home'),
        ),
        state: () async => AppState.test(
          decks: MemoryDeckSource(setFiles()),
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningLanguages: const <String>['zz'],
          ),
        ),
      ),
    );
    screen('the script guide', gallery('script-guide'));
    screen('braille typed on its keyboard', (tester, mode) async {
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(
            'qbe-en-letters',
            skill: Skill.production,
          ),
          preset: const DrillPreset(target: '⠃'),
        ),
        state: brailleApp(<String>['qbe']),
        themeMode: mode,
      );
      expect(find.byType(BrailleKeyboard), findsOneWidget);
    });
  });

  group('First launch', () {
    screen('the tour', page(const OnboardingFlow(startAt: 'tour', page: 1)));
    screen('the sound check', gallery('onboarding-sound'));
    screen('Languages you know, a language\'s sheet open', (
      tester,
      mode,
    ) async {
      await pumpScreen(
        tester,
        OnboardingFlow(
          startAt: 'spoken',
          spoken: const <String>['bn', 'en'],
          choices: choices,
        ),
        themeMode: mode,
      );
      await tester.tap(find.byKey(const ValueKey<String>('pick-en')));
      await tester.pumpAndSettle();
    });
    screen(
      'the language picker, a language\'s sheet open',
      gallery('picker-taught-from'),
    );
    screen('a placement question', gallery('placement-check'));
    screen('the script test', (tester, mode) async {
      await pumpScreen(
        tester,
        LanguagePickerPage(spokenList: choices),
        state: bengaliReader(),
        themeMode: mode,
      );
      await openSheet(tester, 'as');
      await tapShown(tester, find.text(l10nOf(tester).scriptTestTake));
      await tester.pumpAndSettle();
      expect(find.byType(ScriptTestPage), findsOneWidget);
    });
  });

  group('Progress and settings', () {
    screen('Progress', tab(ShellTab.progress));
    screen(
      'How you learn',
      page(
        const HowYouLearnPage(),
        state: () =>
            pacedLearner(Paced.fewer, also: <Paced>{Paced.more, Paced.same}),
      ),
    );
    screen('leeches', gallery('leeches'));
    screen('Settings', gallery('settings'));
    screen('Activities and memory', page(const ActivitiesPage()));
    screen('Appearance', page(const AppearancePage()));
    screen('Voices', gallery('voices-speaking'));
    screen('backup, the restore sheet open', (tester, mode) async {
      tester.view.physicalSize = const Size(390 * 3, 5000 * 3);
      final app = await stateWithBackups(
        features: const FeatureRegistry.shipped(),
      );
      await pumpScreen(
        tester,
        const YourDataPage(),
        state: app.state,
        themeMode: mode,
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.byTooltip(l10n.settingsBackupRestore).first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsRestoreTitle), findsOneWidget);
    });
    screen('the app log', gallery('settings-app-log'));
    screen('release notes', gallery('release-notes'));
    screen(
      'Report a problem',
      page(
        const ReportPage(
          request: ReportRequest(screen: '/deck', detail: 'hi-en-market'),
        ),
        state: () async => AppState.test(
          features: const FeatureRegistry.only(Feature.available),
        ),
      ),
    );
  });

  group('Reviewing', () {
    screen(
      'the review page, a card open',
      review(
        const ReviewPage(deckId: wordsDeck),
        (tester, state) async => tapShown(tester, find.text('mother')),
      ),
    );
    screen(
      'Suggest a change',
      review(const ReviewPage(deckId: wordsDeck), (tester, state) async {
        await tapShown(tester, find.text('mother'));
        await tester.pumpAndSettle();
        await tapShown(
          tester,
          find.widgetWithText(OutlinedButton, l10nOf(tester).reviewSuggest),
        );
      }),
    );
    screen(
      'Waiting for review, a language unfolded',
      review(const WaitingForReviewPage(), (tester, state) async {
        state.settings
          ..spokenLanguages = const <String>['en', 'te']
          ..scriptsRead = const <String, bool>{'en': true, 'te': true}
          ..reviewLanguages = const <String>{'te'};
        await tester.pumpAndSettle();
        await tapShown(tester, find.text('Telugu'));
      }),
    );
    screen(
      'the offensive-words gate',
      review(const OffensiveReviewPage(language: 'te')),
    );
  });

  group('Profiles', () {
    screen('the PIN', gallery('pin'));
  });

  group('the screen reader never reads out the answer asked for', () {
    void expectHidden(String answer) => expect(readsOut(answer), findsNothing);

    testWidgets('recognition: the meaning, until shown', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.deck(
            'es-en-core-100',
            skill: Skill.recognition,
          ),
          preset: const DrillPreset(target: 'la casa'),
        ),
      );
      final card = tester
          .widget<RecognitionDrill>(find.byType(RecognitionDrill))
          .session
          .item
          .card;
      expect(readsOut(card.target), findsAny);
      expectHidden(card.native);
      await tester.tap(find.text(l10nOf(tester).drillShowAnswer));
      await tester.pumpAndSettle();
      expect(readsOut(card.native), findsAny);
      semantics.dispose();
    });

    testWidgets('production: the word', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.deck('es-en-core-100', skill: Skill.production),
          preset: const DrillPreset(target: 'el niño'),
        ),
      );
      expect(readsOut('the boy'), findsAny);
      expectHidden('niño');
      semantics.dispose();
    });

    testWidgets('listening: the word, and its meaning', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.deck('es-en-core-100', skill: Skill.listening),
          preset: const DrillPreset(target: 'el niño'),
        ),
        state: AppState.test(tts: FixedTtsEngine(<String>{'es'})),
      );
      expectHidden('niño');
      expectHidden('the boy');
      semantics.dispose();
    });

    testWidgets('number practice: the words for the digits', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final settings = SettingsNotifier()
        ..setSkillEnabled(Skill.recognition, false)
        ..setSkillEnabled(Skill.listening, false);
      await pumpScreen(
        tester,
        DrillPage(request: DrillRequest.numbers('hi-en-numbers-big')),
        state: AppState.test(settings: settings),
      );
      final card = tester
          .widget<TypedDrill>(find.byType(TypedDrill))
          .session
          .item
          .card;
      expect(readsOut(card.native), findsAny);
      expectHidden(card.target);
      semantics.dispose();
    });
  });

  testWidgets('deck text in an interface string is read in its language: '
      'a wrong answer\'s feedback, a language\'s own name, but not a heard '
      'number\'s digits', (tester) async {
    const spanish = LanguageInfo(
      code: 'es',
      iso639_3: 'spa',
      name: 'Spanish',
      script: 'latin',
    );
    final span = quotingTarget('You typed “nino”. Written: el niño', <String>[
      'niño',
      'el niño',
      'nino',
    ], spanish);
    expect(
      [
        for (final child in span.children!.cast<TextSpan>())
          (child.text, child.locale?.languageCode),
      ],
      <(String?, String?)>[
        ('You typed “', null),
        ('nino', 'es'),
        ('”. Written: ', null),
        ('el niño', 'es'),
      ],
      reason: 'the longest quote wins, and the rest stays unmarked',
    );

    usePhone(tester);
    final semantics = tester.ensureSemantics();
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.deck('es-en-core-100', skill: Skill.production),
        preset: const DrillPreset(
          target: 'el niño',
          typed: 'la mesa',
          check: true,
        ),
      ),
    );
    final l10n = l10nOf(tester);
    expect(
      quotedIn(tester, find.text(l10n.feedbackAnswer('el niño'))),
      <String, String>{'el niño': 'es'},
    );

    await pumpScreen(
      tester,
      OnboardingFlow(
        startAt: 'spoken',
        spoken: const <String>['bn', 'en'],
        choices: choices,
      ),
    );
    final bengali = find.text(l10n.spokenOption('Bengali', 'বাংলা'));
    expect(quotedIn(tester, bengali), <String, String>{'বাংলা': 'bn'});

    final settings = SettingsNotifier()
      ..setSkillEnabled(Skill.recognition, false)
      ..setSkillEnabled(Skill.production, false);
    await pumpScreen(
      tester,
      DrillPage(request: DrillRequest.numbers('hi-en-numbers-big')),
      state: AppState.test(
        tts: FixedTtsEngine(<String>{'hi'}),
        settings: settings,
      ),
    );
    final card =
        tester.widget<TypedDrill>(find.byType(TypedDrill)).session.item.card
            as NumberCard;
    await tester.enterText(find.byType(TextField), '1');
    await tester.pump();
    await tester.tap(find.text(l10n.drillCheck));
    await tester.pumpAndSettle();
    expect(
      quotedIn(tester, find.text(l10n.feedbackAnswer(card.native))),
      isEmpty,
    );
    semantics.dispose();
  });

  testWidgets('the first launch meets contrast in every colour, standard and '
      'high contrast, light and dark', (tester) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    for (final seed in ThemeSeed.values) {
      for (final high in <bool>[false, true]) {
        for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
          rootBundle.clear();
          final settings = SettingsNotifier(
            seed: seed,
            highContrast: high,
            themeMode: mode,
          );
          final state = AppState.test(settings: settings);
          addTearDown(state.dispose);
          addTearDown(settings.dispose);
          await tester.pumpWidget(FluenoughApp(key: UniqueKey(), state: state));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          for (var i = 0; i < tourSlides.length; i++) {
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            await tester.tap(find.byType(FilledButton));
            await tester.pumpAndSettle();
          }
          // The microphone and sound check (#89), then on.
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          await knowLanguage(tester, 'Bengali');
          await tester.enterText(
            find.byKey(const ValueKey<String>('known-search')),
            '',
          );
          await tester.pumpAndSettle();
          // The sheet, open (#490), then the list with answers.
          await tester.tap(find.byKey(const ValueKey<String>('pick-en')));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.tap(find.byKey(const ValueKey<String>('know-read')));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
      }
    }
    semantics.dispose();
  });

  testWidgets('a phone at 2x text draws the app at 1.4x (#505), and below '
      'the cap keeps its own size', (tester) async {
    usePhone(tester, textScale: 2.0);
    await pumpApp(tester);
    TextScaler scaler() =>
        MediaQuery.textScalerOf(tester.element(find.byType(Scaffold).first));
    expect(AppSizes.maxTextScale, 1.4);
    expect(scaler().scale(10), closeTo(14, 0.001));

    usePhone(tester, textScale: 1.2);
    await tester.pumpAndSettle();
    expect(scaler().scale(10), closeTo(12, 0.001));
  });

  testWidgets('a toast is a live region a screen reader hears', (tester) async {
    addTearDown(hideAppSnackBar);
    usePhone(tester);
    final handle = tester.ensureSemantics();
    await pumpScreen(tester, const _Toasting());
    await tester.tap(find.byKey(_say));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Saved')),
      matchesSemantics(label: 'Saved', isLiveRegion: true),
    );
    handle.dispose();
  });
}
