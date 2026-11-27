// The achievements screens (#323, #324; the approved mockup
// `achievements`): the four tabs of the badges page, the badge sheets and the
// levels sheet, the latest-badge line on Progress and the announcement on the
// session summary, in light and dark, with Hindustani, Bengali and Urdu
// words, at 1.4x text.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/achievements/achievement.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/achievements/achievement_announcement.dart';
import 'package:fluenough/features/achievements/achievement_texts.dart';
import 'package:fluenough/features/achievements/achievements_view.dart';
import 'package:fluenough/features/achievements/badge_glyph.dart';
import 'package:fluenough/features/achievements/badge_sheet.dart';
import 'package:fluenough/features/achievements/badge_tile.dart';
import 'package:fluenough/features/achievements/badge_view.dart';
import 'package:fluenough/features/achievements/recent_badge_line.dart';
import 'package:fluenough/ui/script_name.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/achievement_fixture.dart';
import 'support/achievement_screens_fixture.dart';
import 'support/harness.dart';

/// A tall phone at 1.4x text, so that a whole tab is built.
void _tallPhone(WidgetTester tester) {
  usePhone(tester, textScale: 1.4);
  tester.view.physicalSize = const Size(390 * 3, 3000 * 3);
  addTearDown(tester.view.reset);
}

/// The badges of the page's tab that is showing, in order.
List<BadgeView> _tiles(WidgetTester tester) => <BadgeView>[
  for (final tile in tester.widgetList<BadgeTile>(find.byType(BadgeTile)))
    tile.view,
];

BadgeShown _shown(List<BadgeView> views, String id) =>
    views.firstWhere((v) => v.def.id == id).shown;

/// Draws the badges page over [report] and returns what the taps did.
Future<({List<BadgeView> badges, List<List<BadgeView>> levels})> _pumpView(
  WidgetTester tester,
  AchievementReport report, {
  LanguageInfo language = hindustani,
  AchievementTab tab = AchievementTab.levels,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  _tallPhone(tester);
  final badges = <BadgeView>[];
  final levels = <List<BadgeView>>[];
  await pumpScreen(
    tester,
    Scaffold(
      body: AchievementsView(
        report: report,
        language: language,
        initialTab: tab,
        onBadge: badges.add,
        onLevels: levels.add,
      ),
    ),
    themeMode: themeMode,
  );
  return (badges: badges, levels: levels);
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _pumpSheet(
  WidgetTester tester,
  Widget sheet, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  _tallPhone(tester);
  await pumpScreen(tester, Scaffold(body: sheet), themeMode: themeMode);
}

void main() {
  final report = learnedToA1();

  group('the tabs of the badges page', () {
    for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
      testWidgets('Levels shows the levels and the word counts, ${mode.name}', (
        tester,
      ) async {
        final taps = await _pumpView(tester, report, themeMode: mode);
        final l10n = l10nOf(tester);
        expect(tester.takeException(), isNull, reason: 'no overflow at 1.4x');
        // Levels is the tab and the heading of its first group.
        expect(find.text(l10n.achvGroupLevels), findsNWidgets(2));
        expect(find.text(l10n.achvGroupWords), findsOneWidget);

        final views = _tiles(tester);
        expect(views.map((v) => v.def.id), <String>[
          'level-a1',
          'level-a2',
          'level-b1',
          'words-100',
          'words-500',
          'words-1000',
          'words-2500',
        ]);
        expect(_shown(views, 'level-a1'), BadgeShown.earned);
        expect(_shown(views, 'level-a2'), BadgeShown.progress);
        expect(_shown(views, 'level-b1'), BadgeShown.locked);
        expect(_shown(views, 'words-100'), BadgeShown.progress);
        expect(_shown(views, 'words-500'), BadgeShown.locked);

        // The status under a badge: its date, its count, or Locked.
        final a1 = report['level-a1']!;
        expect(
          find.text(achievementDate(l10n, a1.earnedAt!)),
          findsAtLeastNWidgets(1),
        );
        final words = report['words-100']!;
        expect(
          find.text(
            l10n.achvProgressOf(
              achievementCount(l10n, words.have),
              achievementCount(l10n, words.need),
            ),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.achvLocked), findsNWidgets(4));

        // A level opens the levels sheet with all three, a word count its own
        // sheet.
        await tester.tap(find.byType(BadgeTile).first);
        expect(taps.levels, hasLength(1));
        expect(taps.levels.single.map((v) => v.def.id), <String>[
          'level-a1',
          'level-a2',
          'level-b1',
        ]);
        expect(taps.badges, isEmpty);
        await tester.tap(find.byType(BadgeTile).at(3));
        expect(taps.badges.single.def.id, 'words-100');
      });
    }

    testWidgets('Skills has a Start and a Master for each skill', (
      tester,
    ) async {
      await _pumpView(tester, report);
      final l10n = l10nOf(tester);
      await _openTab(tester, l10n.achvTabSkills);
      expect(tester.takeException(), isNull);

      final views = _tiles(tester);
      expect(views.map((v) => v.def.id).toSet(), <String>{
        'skill-hear-start',
        'skill-hear-master',
        'skill-speak-start',
        'skill-speak-master',
        'skill-read-devanagari-start',
        'skill-read-devanagari-master',
        'skill-write-devanagari-start',
        'skill-write-devanagari-master',
      });
      // The first letters were learned: Read's Start is earned. Nothing was
      // heard or written.
      expect(_shown(views, 'skill-read-devanagari-start'), BadgeShown.earned);
      expect(_shown(views, 'skill-hear-start'), BadgeShown.locked);
      expect(_shown(views, 'skill-hear-master'), BadgeShown.locked);
      expect(_shown(views, 'skill-write-devanagari-start'), BadgeShown.locked);

      // Read and Write are for the script; the intro says which.
      final script = l10n.scriptNameOr('devanagari', 'x');
      expect(find.text(l10n.achvSkillsIntroScript(script)), findsOneWidget);
      expect(
        find.text(l10n.achvSkillHeading(l10n.languagesSkillRead, script)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.achvSkillHeading(l10n.languagesSkillWrite, script)),
        findsOneWidget,
      );
      expect(find.text(l10n.languagesSkillHear), findsOneWidget);
      expect(find.text(l10n.languagesSkillSpeak), findsOneWidget);
    });

    testWidgets('a skill marked Leave is shown dimmed, not part of the plan', (
      tester,
    ) async {
      final left = untouched(
        facts: courseFacts(
          leave: <SkillKey>{const SkillKey(SkillKind.write, 'devanagari')},
        ),
      );
      await _pumpView(tester, left, tab: AchievementTab.skills);
      final l10n = l10nOf(tester);
      final views = _tiles(tester);
      expect(_shown(views, 'skill-write-devanagari-start'), BadgeShown.left);
      expect(_shown(views, 'skill-write-devanagari-master'), BadgeShown.left);
      expect(find.text(l10n.achvNotInPlan), findsNWidgets(2));
    });

    testWidgets('Sets has the word sets and the grammar tables', (
      tester,
    ) async {
      await _pumpView(tester, report, tab: AchievementTab.sets);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.achvSetsIntro), findsOneWidget);
      expect(find.text(l10n.achvGroupWordSets), findsOneWidget);
      expect(find.text(l10n.achvGroupGrammarTables), findsOneWidget);
      expect(find.text(l10n.achvSetsEmpty), findsNothing);

      final views = _tiles(tester);
      expect(views.map((v) => v.def.id).toSet(), <String>{
        'set-family',
        'set-past',
      });
      // The sets are named by the app's strings.
      expect(find.text(l10n.achvSetFamily), findsOneWidget);
      expect(find.text(l10n.achvSetPast), findsOneWidget);
    });

    testWidgets('Sets says so when the course has none chosen', (tester) async {
      final none = untouched(facts: courseFacts(sets: const []));
      await _pumpView(tester, none, tab: AchievementTab.sets);
      final l10n = l10nOf(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.achvSetsEmpty), findsOneWidget);
      expect(find.byType(BadgeTile), findsNothing);
      expect(find.text(l10n.achvGroupWordSets), findsNothing);
      expect(find.text(l10n.achvGroupGrammarTables), findsNothing);
    });

    testWidgets(
      'Other has the first lesson, the days in a row and the answers',
      (tester) async {
        await _pumpView(tester, report, tab: AchievementTab.other);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.achvGroupFirsts), findsOneWidget);
        expect(find.text(l10n.achvGroupEveryLanguage), findsOneWidget);
        expect(find.text(l10n.achvGroupInARow), findsOneWidget);
        expect(find.text(l10n.achvGroupAnswers), findsOneWidget);

        final views = _tiles(tester);
        expect(views.map((v) => v.def.id), <String>[
          'other-first-lesson',
          'other-streak-3',
          'other-streak-7',
          'other-streak-30',
          'other-streak-100',
          'other-streak-365',
          'other-answers-1000',
          'other-answers-10000',
        ]);
        expect(_shown(views, 'other-first-lesson'), BadgeShown.earned);
        expect(_shown(views, 'other-streak-30'), BadgeShown.earned);
        // Only the next badge of a chain shows progress.
        expect(_shown(views, 'other-streak-100'), BadgeShown.progress);
        expect(_shown(views, 'other-streak-365'), BadgeShown.locked);
        expect(_shown(views, 'other-answers-1000'), BadgeShown.progress);
        expect(_shown(views, 'other-answers-10000'), BadgeShown.locked);
      },
    );

    testWidgets('a course with no decks has only the badges of the app', (
      tester,
    ) async {
      await _pumpView(tester, appOnly(), language: bengali);
      final l10n = l10nOf(tester);
      // Levels says there is nothing yet, rather than an empty page.
      expect(find.text(l10n.achvNone), findsOneWidget);
      expect(find.byType(BadgeTile), findsNothing);
      await _openTab(tester, l10n.achvTabSets);
      expect(find.text(l10n.achvNone), findsOneWidget);
      await _openTab(tester, l10n.achvTabOther);
      expect(find.text(l10n.achvNone), findsNothing);
      expect(_tiles(tester).map((v) => v.def.id), <String>[
        'other-streak-3',
        'other-streak-7',
        'other-streak-30',
        'other-streak-100',
        'other-streak-365',
        'other-answers-1000',
        'other-answers-10000',
      ]);
    });

    testWidgets('a tile tells a screen reader its state and, locked, how', (
      tester,
    ) async {
      await _pumpView(tester, report);
      final l10n = l10nOf(tester);
      final handle = tester.ensureSemantics();
      await tester.pump();
      final a1 = report['level-a1']!;
      expect(
        find.bySemanticsLabel(
          l10n.achvSemEarned('A1', achievementDate(l10n, a1.earnedAt!)),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          l10n.achvSemLocked('B1', l10n.achvHowLevel('B1')),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('the badge glyph', () {
    testWidgets('the progress ring follows the badge outline', (tester) async {
      _tallPhone(tester);
      final result = inProgress(AchievementDef.words(500), 100, 500);
      await pumpScreen(
        tester,
        Scaffold(
          body: BadgeGlyph(view: BadgeView(result, BadgeShown.progress)),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      const size = BadgeSize.regular;
      final box = Size.square(size.side + 2 * size.ringGap);
      final outline = badgeRingPath(box, size.radius + size.ringGap - 2);
      // The ring is a rounded square, not a circle, with the glyph's centre.
      final bounds = outline.getBounds();
      expect(bounds.width, closeTo(box.width - 4, 1e-6));
      expect(bounds.height, closeTo(box.height - 4, 1e-6));
      expect(bounds.center, Offset(box.width / 2, box.height / 2));
      // It starts at the top centre and the corner is cut, as the glyph's is.
      final metric = outline.computeMetrics().single;
      final start = metric.getTangentForOffset(0)!.position;
      expect(start.dx, closeTo(box.width / 2, 1e-6));
      expect(start.dy, closeTo(2, 1e-6));
      expect(outline.contains(Offset(box.width - 3, 3)), isFalse);
      expect(outline.contains(Offset(box.width / 2, box.height / 2)), isTrue);
    });

    testWidgets('draws the three states and the metals of the levels', (
      tester,
    ) async {
      _tallPhone(tester);
      final a1 = earned(AchievementDef.forLevel(Milestone.a1), screensStart);
      final a2 = inProgress(AchievementDef.forLevel(Milestone.a2), 4, 10);
      final b1 = locked(AchievementDef.forLevel(Milestone.b1));
      await pumpScreen(
        tester,
        Scaffold(
          body: Wrap(
            children: <Widget>[
              for (final size in BadgeSize.values)
                BadgeGlyph(view: BadgeView(a1, BadgeShown.earned), size: size),
              BadgeGlyph(view: BadgeView(a2, BadgeShown.progress)),
              BadgeGlyph(view: BadgeView(b1, BadgeShown.locked)),
              BadgeGlyph(
                view: BadgeView(
                  locked(AchievementDef.words(100)),
                  BadgeShown.left,
                ),
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BadgeGlyph), findsNWidgets(6));
      // The level's name is drawn on its badge; a locked one has a lock only
      // when it is not a level.
      expect(find.text('A1'), findsNWidgets(3));
      expect(find.text('A2'), findsOneWidget);
      expect(find.text('B1'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });
  });

  group('the badge sheet', () {
    final day = DateTime.utc(2026, 10, 14, 12);

    for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
      testWidgets('an earned word count shows its date and some of the '
          'learner\'s words, ${mode.name}', (tester) async {
        final result = earned(AchievementDef.words(100), day, need: 100);
        await _pumpSheet(
          tester,
          BadgeSheet(
            view: BadgeView(result, BadgeShown.earned),
            language: hindustani,
            cards: <BadgeCardRow>[
              const BadgeCardRow(card: hindiCard, language: hindustani),
              const BadgeCardRow(card: hindiCardTwo, language: hindustani),
            ],
          ),
          themeMode: mode,
        );
        final l10n = l10nOf(tester);
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.achvWords('100')), findsOneWidget);
        expect(find.text('Hindustani'), findsOneWidget);
        expect(
          find.text(l10n.achvEarnedOn(achievementDate(l10n, day))),
          findsOneWidget,
        );
        expect(find.text(l10n.achvHowWords('100')), findsOneWidget);
        expect(find.text(l10n.achvFewWords), findsOneWidget);
        // The words are the course's own, in their script.
        expect(find.text('मैं'), findsOneWidget);
        expect(find.text('तुम'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      });
    }

    testWidgets('a word count in progress shows a bar and waits for a break', (
      tester,
    ) async {
      final result = inProgress(AchievementDef.words(500), 312, 500);
      await _pumpSheet(
        tester,
        BadgeSheet(
          view: BadgeView(result, BadgeShown.progress),
          language: hindustani,
        ),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.achvWordsKnown('312', '500')), findsOneWidget);
      expect(find.text(l10n.achvWordsWait), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(312 / 500, 1e-9));
      expect(find.text(l10n.achvFewWords), findsNothing);
    });

    testWidgets('a set in progress lists the cards still to know, in Bengali', (
      tester,
    ) async {
      final result = inProgress(
        AchievementDef.deckSet('family', grammar: false),
        13,
        16,
        cards: <String>['bn-9001', 'bn-9002', 'bn-9003'],
      );
      await _pumpSheet(
        tester,
        BadgeSheet(
          view: BadgeView(result, BadgeShown.progress),
          language: bengali,
          cards: <BadgeCardRow>[
            const BadgeCardRow(card: bengaliCard, language: bengali),
            const BadgeCardRow(
              card: bengaliCardTwo,
              language: bengali,
              started: true,
            ),
            const BadgeCardRow(card: bengaliCardThree, language: bengali),
          ],
        ),
      );
      final l10n = l10nOf(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.achvSetFamilyFull), findsOneWidget);
      expect(
        find.text(l10n.achvSubline('Bengali', l10n.achvSheetWordSet)),
        findsOneWidget,
      );
      expect(find.text(l10n.achvCardsKnown('13', '16')), findsOneWidget);
      expect(find.text(l10n.achvSetRule), findsOneWidget);
      expect(find.text(l10n.achvStillToKnow(3)), findsOneWidget);
      for (final word in ['আমি', 'তুমি', 'আপনি']) {
        expect(find.text(word), findsOneWidget, reason: word);
      }
      // One was started, two are new.
      expect(find.text(l10n.achvLearning), findsOneWidget);
      expect(find.text(l10n.unitNew), findsNWidgets(2));
    });

    testWidgets('a grammar table says so', (tester) async {
      final result = inProgress(
        AchievementDef.deckSet('past', grammar: true),
        10,
        40,
      );
      await _pumpSheet(
        tester,
        BadgeSheet(
          view: BadgeView(result, BadgeShown.progress),
          language: hindustani,
        ),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.achvSetPastFull), findsOneWidget);
      expect(
        find.text(l10n.achvSubline('Hindustani', l10n.achvSheetGrammarTable)),
        findsOneWidget,
      );
      // Without the cards to name, only the count is shown.
      expect(find.text(l10n.achvStillToKnow(30)), findsNothing);
    });

    testWidgets('a locked level says how to earn it and what comes first', (
      tester,
    ) async {
      final result = locked(AchievementDef.forLevel(Milestone.b1));
      await _pumpSheet(
        tester,
        BadgeSheet(
          view: BadgeView(result, BadgeShown.locked),
          language: hindustani,
        ),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.achvLocked), findsOneWidget);
      expect(find.text(l10n.achvHowLevel('B1')), findsOneWidget);
      expect(find.text(l10n.achvLevelFirst('A2')), findsOneWidget);
    });

    testWidgets('a skill not part of the plan is dimmed and says so', (
      tester,
    ) async {
      final result = AchievementResult(
        def: AchievementDef.skillStart(const SkillKey(SkillKind.speak)),
        status: AchievementStatus.locked,
        have: 0,
        need: 0,
        earnable: false,
      );
      await _pumpSheet(
        tester,
        BadgeSheet(
          view: BadgeView(result, BadgeShown.left),
          language: hindustani,
        ),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.achvNotInPlan), findsOneWidget);
      expect(find.text(l10n.achvHowSpeakStart), findsOneWidget);
      expect(
        find.text(l10n.achvSkillFull(l10n.languagesSkillSpeak, l10n.achvStart)),
        findsOneWidget,
      );
    });

    testWidgets('a script skill names its script; Urdu words run right to '
        'left', (tester) async {
      final result = AchievementResult(
        def: AchievementDef.skillMaster(
          const SkillKey(SkillKind.read, 'perso_arabic'),
        ),
        status: AchievementStatus.inProgress,
        have: 1,
        need: 3,
        cards: <String>['ur-9001'],
      );
      await _pumpSheet(
        tester,
        BadgeSheet(
          view: BadgeView(result, BadgeShown.progress),
          language: urdu,
          cards: <BadgeCardRow>[
            const BadgeCardRow(card: urduCard, language: urdu),
          ],
        ),
      );
      final l10n = l10nOf(tester);
      expect(tester.takeException(), isNull);
      final script = l10n.scriptNameOr('perso_arabic', 'x');
      expect(find.text(l10n.achvSubline('Urdu', script)), findsOneWidget);
      expect(find.text(l10n.achvMasterWait), findsOneWidget);
      final word = tester.widget<Text>(find.text('میں'));
      expect(word.textDirection, TextDirection.rtl);
    });
  });

  group('the levels sheet', () {
    for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
      testWidgets(
        'shows the three metals and the bar of the next, ${mode.name}',
        (tester) async {
          final day = DateTime.utc(2026, 10, 14);
          final levels = <BadgeView>[
            BadgeView(
              earned(AchievementDef.forLevel(Milestone.a1), day, need: 62),
              BadgeShown.earned,
            ),
            BadgeView(
              inProgress(AchievementDef.forLevel(Milestone.a2), 41, 62),
              BadgeShown.progress,
            ),
            BadgeView(
              locked(AchievementDef.forLevel(Milestone.b1)),
              BadgeShown.locked,
            ),
          ];
          await _pumpSheet(
            tester,
            LevelsSheet(levels: levels, language: hindustani),
            themeMode: mode,
          );
          final l10n = l10nOf(tester);
          expect(tester.takeException(), isNull);
          expect(find.text(l10n.achvLevelsTitle('Hindustani')), findsOneWidget);
          expect(find.text(l10n.achvLevelsFollow), findsOneWidget);
          expect(find.byType(BadgeGlyph), findsNWidgets(3));
          expect(find.text(achievementDate(l10n, day)), findsOneWidget);
          expect(find.text(l10n.achvNextLevel('A2')), findsOneWidget);
          expect(
            find.text(l10n.achvLevelCards('41', '62', 'A2')),
            findsOneWidget,
          );
          expect(find.text(l10n.achvLevelRule), findsOneWidget);
          final bar = tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
          expect(bar.value, closeTo(41 / 62, 1e-9));
        },
      );
    }

    testWidgets('with every level earned there is no next bar', (tester) async {
      final day = DateTime.utc(2026, 10, 14);
      await _pumpSheet(
        tester,
        LevelsSheet(
          levels: <BadgeView>[
            for (final level in Milestone.values)
              BadgeView(
                earned(AchievementDef.forLevel(level), day),
                BadgeShown.earned,
              ),
          ],
          language: bengali,
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(BadgeGlyph), findsNWidgets(3));
    });
  });

  group('the latest-badge line on Progress', () {
    testWidgets('shows the latest badge and its date, and opens the page', (
      tester,
    ) async {
      _tallPhone(tester);
      var opened = 0;
      await pumpScreen(
        tester,
        Scaffold(
          body: RecentBadgeLine(
            report: report,
            languageName: 'Hindustani',
            onTap: () => opened++,
          ),
        ),
      );
      final l10n = l10nOf(tester);
      final latest = report.earned.last;
      expect(find.text(latest.def.fullName(l10n)), findsOneWidget);
      final date = achievementDate(l10n, latest.earnedAt!);
      final sub = latest.def.isAppWide
          ? date
          : l10n.achvSubline('Hindustani', date);
      expect(find.text(sub), findsOneWidget);
      expect(find.byType(BadgeGlyph), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      expect(opened, 1);
    });

    testWidgets('is not there before the first badge', (tester) async {
      _tallPhone(tester);
      await pumpScreen(
        tester,
        Scaffold(
          body: RecentBadgeLine(
            report: untouched(),
            languageName: 'Hindustani',
            onTap: () {},
          ),
        ),
      );
      expect(find.byType(BadgeGlyph), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('the announcement on the session summary', () {
    final since = DateTime.utc(2026, 5, 1);

    /// The announcement as the summary draws it, in a scrolling page.
    Widget announcement(DateTime since) => Scaffold(
      body: SingleChildScrollView(
        child: AchievementAnnouncement(language: 'zz', since: since),
      ),
    );

    /// A state that answered one card on each of [days] days from 1 May.
    /// Its language, `zz`, has no decks, so only the badges of the app are
    /// there.
    Future<AppState> answered(int days) async {
      final state = AppState.test();
      await state.load();
      for (var i = 0; i < days; i++) {
        state.progress.record(
          deckId: 'zz-core',
          cardId: 'zz-1',
          mode: DrillMode.recognition,
          grade: 4,
          now: DateTime.utc(2026, 5, 1 + i, 8),
          elapsed: const Duration(seconds: 3),
          answerGiven: 'x',
        );
      }
      return state;
    }

    /// Looks at the badges of the language and the app, so that what is earned
    /// next is new.
    void looked(AppState state) => state.settings
      ..markAchievementsSeen('zz', const <String>[])
      ..markAchievementsSeen('*', const <String>[]);

    testWidgets('a new badge is announced once, quietly, and marked seen', (
      tester,
    ) async {
      _tallPhone(tester);
      final state = await answered(3);
      looked(state);
      await pumpScreen(
        tester,
        announcement(since),
        state: state,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 300));
      final l10n = l10nOf(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.achvNewBadge.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.achvDays('3')), findsOneWidget);
      expect(find.text(l10n.achvDoneDays('3')), findsOneWidget);
      expect(find.text(l10n.achvSeeOnProgress), findsOneWidget);
      // No pressure: nothing about a streak at risk, lost or kept.
      expect(find.textContaining('lost'), findsNothing);
      expect(find.textContaining('risk'), findsNothing);
      // It stays on screen once marked, and is marked.
      expect(
        state.settings.achievementsSeenOf('*'),
        contains('other-streak-3'),
      );
      expect(find.text(l10n.achvNewBadge.toUpperCase()), findsOneWidget);

      // The next summary does not show it again.
      await pumpScreen(
        tester,
        announcement(since),
        state: state,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.achvNewBadge.toUpperCase()), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('two cards at most, then "and N more"', (tester) async {
      _tallPhone(tester);
      final state = await answered(30);
      looked(state);
      await pumpScreen(
        tester,
        announcement(since),
        state: state,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 300));
      final l10n = l10nOf(tester);
      // 3, 7 and 30 days in a row: two in full, one counted.
      expect(find.text(l10n.achvNewBadge.toUpperCase()), findsNWidgets(2));
      expect(find.text(l10n.achvDays('3')), findsOneWidget);
      expect(find.text(l10n.achvDays('7')), findsOneWidget);
      expect(find.text(l10n.achvDays('30')), findsNothing);
      expect(find.text(l10n.achvMore('1')), findsOneWidget);
    });

    testWidgets('badges from past reviews are celebrated once, in one quiet '
        'card', (tester) async {
      _tallPhone(tester);
      final state = await answered(3);
      // A session that began long after: what was earned is the past's.
      await pumpScreen(
        tester,
        announcement(DateTime.utc(2026, 6)),
        state: state,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 300));
      final l10n = l10nOf(tester);
      expect(find.text(l10n.achvPastFound(1)), findsOneWidget);
      expect(find.text(l10n.achvSeeThem), findsOneWidget);
      expect(find.text(l10n.achvNewBadge.toUpperCase()), findsNothing);
      expect(find.byType(BadgeGlyph), findsOneWidget);

      // Marked seen: the next summary has nothing to say.
      await pumpScreen(
        tester,
        announcement(DateTime.utc(2026, 6)),
        state: state,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.achvPastFound(1)), findsNothing);
      expect(find.byType(BadgeGlyph), findsNothing);
    });

    testWidgets('says nothing when no badge was earned', (tester) async {
      _tallPhone(tester);
      final state = await answered(1);
      looked(state);
      await pumpScreen(
        tester,
        announcement(since),
        state: state,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BadgeGlyph), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });
  });
}
