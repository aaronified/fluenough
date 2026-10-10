import 'dart:io';
import 'dart:ui' show LocaleStringAttribute;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/numbers/number_practice.dart';
import 'package:fluenough/core/scheduling/session_queue.dart' show Ask;
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/import_page.dart';
import 'package:fluenough/features/decks/path_fixture.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/recognition_drill.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/features/onboarding/onboarding_flow.dart';
import 'package:fluenough/features/onboarding/tour_step.dart';
import 'package:fluenough/features/profiles/new_profile_page.dart';
import 'package:fluenough/features/profiles/profiles_page.dart';
import 'package:fluenough/features/profiles/spoken_languages_page.dart';
import 'package:fluenough/features/review/how_reviewing_works.dart';
import 'package:fluenough/features/review/review_page.dart';
import 'package:fluenough/features/review/waiting_page.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/sources_page.dart';
import 'package:fluenough/features/settings/voices_page.dart';
import 'package:fluenough/features/stats/how_you_learn_page.dart';
import 'package:fluenough/features/stats/leeches_page.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:fluenough/features/today/due_card.dart';
import 'package:fluenough/ui/widgets/pace_parts.dart';
import 'package:fluenough/ui/widgets/target_text.dart';

import 'support/harness.dart';
import 'support/paced_learner.dart';
import 'support/review_fixture.dart';

/// Flutter's accessibility guidelines on every drill state (#26): tap targets
/// big enough for a drill used fast, every tap target labelled, and text at
/// WCAG AA contrast, in both themes.
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

void main() {
  group('deck content in an interface string is read in its language', () {
    const spanish = LanguageInfo(
      code: 'es',
      iso639_3: 'spa',
      name: 'Spanish',
      script: 'latin',
    );

    test('the longest quote wins, and the rest stays unmarked', () {
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
      );
    });

    testWidgets('a wrong answer\'s feedback', (tester) async {
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
      semantics.dispose();
    });

    testWidgets('a language\'s own name, in the list of spoken ones', (
      tester,
    ) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        OnboardingFlow(
          startAt: 'spoken',
          spoken: const <String>['bn', 'en'],
          choices: parseSpokenLanguages(
            File(SpokenLanguagesPage.asset).readAsStringSync(),
          ),
        ),
      );
      final l10n = l10nOf(tester);
      final bengali = find.text(l10n.spokenOption('Bengali', 'বাংলা'));
      expect(quotedIn(tester, bengali), <String, String>{'বাংলা': 'bn'});
      final node = tester.getSemantics(bengali);
      expect(node, isSemantics(isChecked: true));
      expect(node.label, contains(l10n.spokenRankSemantics(1, 2)));
      semantics.dispose();
    });

    testWidgets('but not a heard number\'s digits', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
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
      await tester.tap(find.text(l10nOf(tester).drillCheck));
      await tester.pumpAndSettle();
      expect(
        quotedIn(tester, find.text(l10nOf(tester).feedbackAnswer(card.native))),
        isEmpty,
      );
      semantics.dispose();
    });
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

  final drills = <(String, DrillRequest, DrillPreset)>[
    (
      'recognition',
      DrillRequest.deck('es-en-core-100', skill: Skill.recognition),
      const DrillPreset(target: 'la casa'),
    ),
    (
      'recognition, revealed',
      DrillRequest.deck('es-en-core-100', skill: Skill.recognition),
      const DrillPreset(target: 'la casa', reveal: true),
    ),
    (
      'production',
      DrillRequest.deck('es-en-core-100', skill: Skill.production),
      const DrillPreset(target: 'el niño'),
    ),
    (
      'production, correct',
      DrillRequest.deck('es-en-core-100', skill: Skill.production),
      const DrillPreset(target: 'el niño', typed: 'el niño', check: true),
    ),
    (
      'production, accent',
      DrillRequest.deck('es-en-core-100', skill: Skill.production),
      const DrillPreset(target: 'el niño', typed: 'el nino', check: true),
    ),
    (
      'production, near miss',
      DrillRequest.deck('es-en-core-100', skill: Skill.production),
      const DrillPreset(target: 'la ventana', typed: 'la ventna', check: true),
    ),
    (
      'production, wrong',
      DrillRequest.deck('es-en-core-100', skill: Skill.production),
      const DrillPreset(target: 'la ventana', typed: 'el perro', check: true),
    ),
    (
      'production in a script, with the keyboard hint',
      DrillRequest.deck('hi-en-script-consonants', skill: Skill.production),
      const DrillPreset(target: 'क'),
    ),
    (
      'listening',
      DrillRequest.deck('es-en-core-100', skill: Skill.listening),
      const DrillPreset(),
    ),
    (
      'match pairs, with its tap-to-hear button',
      DrillRequest.untaught('es-en-core-100', skill: Skill.recognition),
      const DrillPreset(target: 'la casa', ask: Ask.matchPairs),
    ),
    (
      'number practice',
      DrillRequest.numbers('hi-en-numbers-big'),
      const DrillPreset(),
    ),
  ];

  final pages = <(String, Widget)>[
    ('a deck', const DeckDetailPage(deckId: 'hi-en-market')),
    ('a deck marked unreviewed', const DeckDetailPage(deckId: 'te-en-market')),
    ('add a deck', const ImportPage()),
    ('leeches', const LeechesPage()),
    ('appearance', const AppearancePage()),
    ('voices', const VoicesPage()),
    ('sources', const SourcesPage()),
    ('profiles', const ProfilesPage()),
    ('a new profile', const NewProfilePage()),
    (
      'the summary',
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
  ];

  final choices = parseSpokenLanguages(
    File(SpokenLanguagesPage.asset).readAsStringSync(),
  );
  final firstLaunch = <(String, Widget)>[
    ('first launch: welcome', const OnboardingFlow()),
    for (final (i, slide) in tourSlides.indexed)
      (
        'first launch: tour, ${slide.id}',
        OnboardingFlow(startAt: 'tour', page: i),
      ),
    (
      'first launch: languages, none ticked',
      OnboardingFlow(startAt: 'spoken', choices: choices),
    ),
    (
      'first launch: languages, two ranked',
      OnboardingFlow(
        startAt: 'spoken',
        spoken: const <String>['bn', 'en'],
        choices: choices,
      ),
    ),
    ('languages, from Settings', SpokenLanguagesPage(choices: choices)),
  ];
  pages.addAll(firstLaunch);

  // The Decks tab's path and a unit's screen (the owner's design), on the
  // design's Telugu learner: levels, milestones and coming units, a search
  // across courses, a unit part learned, and a word's card.
  final pathScreens = <(String, Widget)>[
    ('the path, toward B1', const DecksPage(planOf: PathFixtures.planOf)),
    (
      'the path, searched',
      const DecksPage(planOf: PathFixtures.planOf, initialQuery: 'family'),
    ),
    (
      'a unit',
      const UnitPage(
        deckId: PathFixtures.familyDeck,
        plan: PathFixtures.telugu,
      ),
    ),
    (
      'a unit, a word\'s card open',
      const UnitPage(
        deckId: 'te-en-sound-differences',
        plan: PathFixtures.telugu,
        openWord: PathFixtures.soundAlikeCard,
      ),
    ),
  ];
  Future<AppState> teluguLearner() async {
    final app = AppState.test();
    await app.load();
    return PathFixtures.state(app);
  }

  for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    group('the path and a unit, ${themeMode.name} theme', () {
      for (final (name, page) in pathScreens) {
        testWidgets(name, (tester) async {
          usePhone(tester);
          final semantics = tester.ensureSemantics();
          await pumpScreen(
            tester,
            page,
            state: await teluguLearner(),
            themeMode: themeMode,
          );
          await noTargetCutAtTop(tester);
          await meetsEveryGuideline(tester);
          semantics.dispose();
        });
      }
    });
  }

  // In reviewer mode, each unit with a deck no native speaker has signed
  // off carries "To review": every bundled Telugu deck is unreviewed.
  for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('the path in reviewer mode, its units marked To review, '
        '${themeMode.name} theme', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final state = await teluguLearner();
      state.reviewing.turnOn();
      state.settings.reviewLanguages = const <String>{'te'};
      await pumpScreen(
        tester,
        const DecksPage(planOf: PathFixtures.planOf),
        state: state,
        themeMode: themeMode,
      );
      expect(find.text(l10nOf(tester).pathToReview), findsWidgets);
      await meetsEveryGuideline(tester);
      semantics.dispose();
    });
  }

  group('the path and a unit at the largest font size, 2.0 on Android', () {
    for (final (name, page) in pathScreens) {
      testWidgets('$name: nothing clipped, targets still big enough', (
        tester,
      ) async {
        usePhone(tester, textScale: 2.0);
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester, page, state: await teluguLearner());
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  });

  group('at the largest font size, 2.0 on Android', () {
    for (final (name, page) in firstLaunch) {
      testWidgets('$name: nothing clipped, targets still big enough', (
        tester,
      ) async {
        usePhone(tester, textScale: 2.0);
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester, page);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }

    for (final (name, request, preset) in drills) {
      testWidgets('$name: nothing clipped, targets still big enough', (
        tester,
      ) async {
        usePhone(tester, textScale: 2.0);
        final semantics = tester.ensureSemantics();
        await pumpScreen(
          tester,
          DrillPage(request: request, preset: preset),
          state: AppState.test(tts: FixedTtsEngine(<String>{'es', 'hi'})),
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  });

  for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    group('${themeMode.name} theme', () {
      for (final (name, request, preset) in drills) {
        testWidgets(name, (tester) async {
          usePhone(tester);
          final semantics = tester.ensureSemantics();
          await pumpScreen(
            tester,
            DrillPage(request: request, preset: preset),
            state: AppState.test(tts: FixedTtsEngine(<String>{'es'})),
            themeMode: themeMode,
          );
          await meetsEveryGuideline(tester);
          semantics.dispose();
        });
      }

      for (final (name, page) in pages) {
        testWidgets(name, (tester) async {
          usePhone(tester);
          final semantics = tester.ensureSemantics();
          await pumpScreen(tester, page, themeMode: themeMode);
          await meetsEveryGuideline(tester);
          semantics.dispose();
        });
      }

      for (final tab in ShellTab.values) {
        testWidgets('the ${tab.name} tab', (tester) async {
          usePhone(tester);
          final semantics = tester.ensureSemantics();
          final state = AppState.test();
          state.settings.themeMode = themeMode;
          await pumpApp(tester, state: state);
          state.shellTab.value = tab;
          await tester.pumpAndSettle();
          await meetsEveryGuideline(tester);
          semantics.dispose();
        });
      }
    });
  }

  // Reviewer mode (docs/plans/deck-browser.md): Settings' Reviewing group
  // and How reviewing works, a unit's review and each of its sheets, the
  // rude-word rating and the pair check with adult content on, the send
  // sheet, and the drill card's sound-alike warning.
  final reviewScreens =
      <
        (
          String,
          Widget,
          Future<void> Function(WidgetTester tester, AppState state)?,
        )
      >[
        ('settings, reviewing on', const SettingsPage(), null),
        (
          'how reviewing works',
          const SettingsPage(),
          (tester, state) async {
            await tapShown(tester, find.text(l10nOf(tester).reviewSettingsHow));
          },
        ),
        ('review a unit', const ReviewPage(deckId: wordsDeck), null),
        (
          'review a unit, a card open',
          const ReviewPage(deckId: wordsDeck),
          (tester, state) async => tapShown(tester, find.text('mother')),
        ),
        (
          'review a unit, suggest a change',
          const ReviewPage(deckId: wordsDeck),
          (tester, state) async {
            await tapShown(tester, find.text('mother'));
            await tester.pumpAndSettle();
            await tapShown(
              tester,
              find.widgetWithText(OutlinedButton, l10nOf(tester).reviewSuggest),
            );
          },
        ),
        (
          'review a unit, the pair with adult content on',
          const ReviewPage(deckId: wordsDeck, adult: true),
          (tester, state) async => tapShown(tester, find.text('widow')),
        ),
        (
          'review rude words, rating one',
          const ReviewPage(deckId: rudeDeck, adult: true),
          (tester, state) async {
            await tapShown(tester, find.text('idiot, good-for-nothing'));
            await tester.pumpAndSettle();
            await tapShown(tester, find.text(l10nOf(tester).reviewRate));
          },
        ),
        (
          'review a unit, the send sheet',
          const ReviewPage(deckId: wordsDeck),
          (tester, state) async {
            final words = state.deckById(wordsDeck)!;
            state.reviewing.markRight(words, words.cards.first);
            await tester.pumpAndSettle();
            await tapShown(tester, find.text(l10nOf(tester).reviewSend));
          },
        ),
        (
          'waiting for review, no language chosen',
          const WaitingForReviewPage(),
          null,
        ),
        (
          'waiting for review, choosing the languages',
          const WaitingForReviewPage(),
          (tester, state) async =>
              tapShown(tester, find.text(l10nOf(tester).reviewWaitingChoose)),
        ),
        (
          'waiting for review in Telugu',
          const WaitingForReviewPage(),
          (tester, state) async {
            state.settings.reviewLanguages = const <String>{'te'};
          },
        ),
        // The reviewer guide as the walkthrough (#409): its first step, one
        // with three paragraphs, and the last, which closes with Got it.
        ('how reviewing works, first step', const HowReviewingWorks(), null),
        (
          'how reviewing works, sending in one mail',
          HowReviewingWorks(
            initialStep: reviewGuideSteps.indexWhere((s) => s.id == 'send'),
          ),
          null,
        ),
        (
          'how reviewing works, last step',
          HowReviewingWorks(initialStep: reviewGuideSteps.length - 1),
          null,
        ),
        (
          'a seen word like a rude one, answer shown',
          DrillPage(
            request: DrillRequest.deck(wordsDeck, skill: Skill.recognition),
            preset: const DrillPreset(target: 'విధవ', reveal: true),
          ),
          null,
        ),
      ];

  Future<void> pumpReview(
    WidgetTester tester,
    Widget page,
    Future<void> Function(WidgetTester, AppState)? open, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    final state = await pumpScreen(
      tester,
      page,
      state: await reviewState(reviewing: true),
      themeMode: themeMode,
    );
    if (open != null) {
      await open(tester, state);
      await tester.pumpAndSettle();
    }
  }

  for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    group('reviewer mode, ${themeMode.name} theme', () {
      for (final (name, page, open) in reviewScreens) {
        testWidgets(name, (tester) async {
          usePhone(tester);
          final semantics = tester.ensureSemantics();
          await pumpReview(tester, page, open, themeMode: themeMode);
          await meetsEveryGuideline(tester);
          semantics.dispose();
        });
      }
    });
  }

  group('reviewer mode at the largest font size, 2.0 on Android', () {
    for (final (name, page, open) in reviewScreens) {
      testWidgets('$name: nothing clipped, targets still big enough', (
        tester,
      ) async {
        usePhone(tester, textScale: 2.0);
        final semantics = tester.ensureSemantics();
        await pumpReview(tester, page, open);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  });

  // Adjusted to you (ADR-0035): How you learn, and the
  // Today and Progress tabs, before any fit and after each kind of fit.
  group('adjusted to you', () {
    for (final paced in Paced.values) {
      for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        testWidgets('How you learn, ${paced.name}, ${themeMode.name}', (
          tester,
        ) async {
          usePhone(tester);
          final semantics = tester.ensureSemantics();
          await pumpScreen(
            tester,
            const HowYouLearnPage(),
            state: await pacedLearner(paced),
            themeMode: themeMode,
          );
          await meetsEveryGuideline(tester);
          semantics.dispose();
        });

        for (final tab in <ShellTab>[ShellTab.today, ShellTab.progress]) {
          testWidgets('the ${tab.name} tab, ${paced.name}, ${themeMode.name}', (
            tester,
          ) async {
            usePhone(tester);
            final semantics = tester.ensureSemantics();
            final state = await pacedLearner(paced);
            state.settings.themeMode = themeMode;
            await pumpApp(tester, state: state);
            state.shellTab.value = tab;
            await tester.pumpAndSettle();
            if (tab == ShellTab.today) {
              // The state checked is the one asked for.
              expect(
                find.descendant(
                  of: find.byType(DueCard),
                  matching: find.byType(PaceStrip),
                ),
                paced.adjusts ? findsOneWidget : findsNothing,
              );
              // The tiles and their marks on screen, to be measured.
              final marks = find.byType(PaceMark);
              if (paced.adjusts) {
                await tester.ensureVisible(marks.first);
                await tester.pumpAndSettle();
              }
            }
            await meetsEveryGuideline(tester);
            semantics.dispose();
          });
        }
      }

      testWidgets('How you learn, ${paced.name}, at text scale 2.0: nothing '
          'clipped, targets still big enough', (tester) async {
        usePhone(tester, textScale: 2.0);
        final semantics = tester.ensureSemantics();
        await pumpScreen(
          tester,
          const HowYouLearnPage(),
          state: await pacedLearner(
            paced,
            also: <Paced>{Paced.fewer, Paced.more, Paced.same},
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }

    for (final tab in <ShellTab>[ShellTab.today, ShellTab.progress]) {
      testWidgets('the ${tab.name} tab, every kind of fit, at text scale '
          '2.0: nothing clipped, targets still big enough', (tester) async {
        usePhone(tester, textScale: 2.0);
        final semantics = tester.ensureSemantics();
        final state = await pacedLearner(
          Paced.fewer,
          also: <Paced>{Paced.more, Paced.same},
        );
        await pumpApp(tester, state: state);
        state.shellTab.value = tab;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  });

  group('the first launch in every colour', () {
    setUp(rootBundle.clear);
    for (final seed in ThemeSeed.values) {
      for (final high in <bool>[false, true]) {
        for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
          testWidgets('${seed.name}, ${high ? 'high' : 'standard'} contrast, '
              '${mode.name}', (tester) async {
            usePhone(tester);
            final semantics = tester.ensureSemantics();
            final settings = SettingsNotifier(
              seed: seed,
              highContrast: high,
              themeMode: mode,
            );
            final state = AppState.test(settings: settings);
            addTearDown(state.dispose);
            addTearDown(settings.dispose);
            await tester.pumpWidget(FluenoughApp(state: state));
            await tester.pumpAndSettle();
            final l10n = l10nOf(tester);
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
            await tester.tap(find.text(l10n.spokenOption('Bengali', 'বাংলা')));
            await tester.tap(
              find.text(l10n.spokenOption('English', 'English')),
            );
            await tester.pumpAndSettle();
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            semantics.dispose();
          });
        }
      }
    }
  });
}
