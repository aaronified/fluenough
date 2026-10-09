import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/pacing.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/features/stats/how_you_learn_page.dart';
import 'package:fluenough/features/today/due_card.dart';
import 'package:fluenough/features/today/today_fixtures.dart';
import 'package:fluenough/features/today/today_numbers.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/widgets/pace_parts.dart';

import '../../support/harness.dart';
import '../../support/paced_learner.dart';

/// [skill]'s name on its tile.
Finder nameOf(WidgetTester tester, Skill skill) => find.descendant(
  of: find.byType(DueCard),
  matching: find.text(skill.label(l10nOf(tester))),
);

/// The mark on [skill]'s tile, if any.
Finder markOn(WidgetTester tester, Skill skill) => find.descendant(
  of: find
      .ancestor(of: nameOf(tester, skill), matching: find.byType(Material))
      .first,
  matching: find.byType(PaceMark),
);

Future<AppState> onToday(
  WidgetTester tester,
  Paced paced, {
  Set<Paced> also = const <Paced>{},
  double textScale = 1.0,
  PaceRunner paceRunner = paceInPlace,
}) async {
  usePhone(tester, textScale: textScale);
  final state = await pacedLearner(paced, also: also, paceRunner: paceRunner);
  await pumpScreen(tester, const TodayPage(), state: state);
  await tester.ensureVisible(find.byType(DueCard));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('before any fit: no strip, no marks, and nothing worked out', (
    tester,
  ) async {
    var runs = 0;
    await onToday(
      tester,
      Paced.none,
      paceRunner: (job) {
        runs++;
        return paceInPlace(job);
      },
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.adjustedTitle), findsNothing);
    expect(find.byType(PaceStrip), findsNothing);
    expect(find.byType(PaceMark), findsNothing);
    expect(runs, 0, reason: 'only stored fits are read before a fit');
  });

  testWidgets('fitted slower: the settled strip, and Hear marked "Fewer '
      'reviews"', (tester) async {
    final state = await onToday(tester, Paced.fewer);
    final l10n = l10nOf(tester);
    final pace = TodayNumbers.of(state).pace!;
    final totals = pace.totals!;

    expect(find.text(l10n.adjustedTitle), findsOneWidget);
    expect(
      find.text(
        totals.reviews == totals.was
            ? l10n.paceReviewsSteady(totals.reviews)
            : l10n.paceReviews(totals.reviews, totals.was),
      ),
      findsOneWidget,
    );
    expect(pace.marks, {Skill.listening: PaceDirection.fewer});
    expect(
      find.descendant(
        of: markOn(tester, Skill.listening),
        matching: find.text(l10n.paceFewer),
      ),
      findsOneWidget,
    );
    expect(markOn(tester, Skill.recognition), findsNothing);
    expect(markOn(tester, Skill.production), findsNothing);
    // The screen reader hears it too.
    expect(
      find.bySemanticsLabel(
        l10n.todaySkillAdjustedSemantics(
          Skill.listening.label(l10n),
          TodayNumbers.of(state).bySkill[Skill.listening]!,
          'fewer',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.adjustedTitle));
    await tester.pumpAndSettle();
    expect(find.byType(HowYouLearnPage), findsOneWidget);
  });

  testWidgets('fitted faster: Write marked "More reviews", in the quiet '
      'colour, and the strip counts the extra reviews', (tester) async {
    final state = await onToday(tester, Paced.more);
    final l10n = l10nOf(tester);
    final totals = TodayNumbers.of(state).pace!.totals!;
    expect(totals.reviews, greaterThan(totals.was));
    expect(
      find.text(l10n.paceReviews(totals.reviews, totals.was)),
      findsOneWidget,
    );
    final mark = find.descendant(
      of: markOn(tester, Skill.production),
      matching: find.text(l10n.paceMore),
    );
    expect(mark, findsOneWidget);
    final scheme = Theme.of(tester.element(mark)).colorScheme;
    expect(tester.widget<Text>(mark).style!.color, scheme.onSurfaceVariant);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: markOn(tester, Skill.production),
              matching: find.byType(Icon),
            ),
          )
          .icon,
      Icons.north,
    );
  });

  testWidgets('about the same: Recognition marked so', (tester) async {
    await onToday(tester, Paced.same);
    final l10n = l10nOf(tester);
    expect(
      find.descendant(
        of: markOn(tester, Skill.recognition),
        matching: find.text(l10n.paceSame),
      ),
      findsOneWidget,
    );
    expect(find.byType(PaceMark), findsOneWidget);
  });

  testWidgets('with nothing due the strip stays', (tester) async {
    usePhone(tester);
    final state = await pacedLearner(Paced.fewer);
    finishToday(state);
    await pumpScreen(tester, const TodayPage(), state: state);
    final l10n = l10nOf(tester);
    expect(TodayNumbers.of(state).allDone, isTrue);
    expect(find.text(l10n.todayAllDoneTitle), findsOneWidget);
    expect(find.text(l10n.adjustedTitle), findsOneWidget);
  });

  for (final scale in <double>[1.0, 1.3]) {
    testWidgets('at text scale $scale, the two tiles of a row are level: '
        'heights, names and marks', (tester) async {
      final state = await onToday(
        tester,
        Paced.fewer,
        also: <Paced>{Paced.more, Paced.same},
        textScale: scale,
      );
      final skills = TodayNumbers.of(state).bySkill.keys.toList();
      expect(skills.length, greaterThanOrEqualTo(4));
      final tiles = <Rect>[
        for (final skill in skills)
          tester.getRect(
            find
                .ancestor(
                  of: nameOf(tester, skill),
                  matching: find.byType(Material),
                )
                .first,
          ),
      ];
      for (var i = 0; i + 1 < skills.length; i += 2) {
        final a = tiles[i];
        final b = tiles[i + 1];
        expect(a.top, b.top, reason: 'row ${i ~/ 2} tops');
        expect(a.height, b.height, reason: 'row ${i ~/ 2} heights');
        expect(a.width, b.width, reason: 'row ${i ~/ 2} widths');
        expect(
          tester.getTopLeft(nameOf(tester, skills[i])).dy,
          tester.getTopLeft(nameOf(tester, skills[i + 1])).dy,
          reason: 'row ${i ~/ 2} names',
        );
        // A name starts at its tile's text edge, as the mark does.
        for (final j in <int>[i, i + 1]) {
          final mark = markOn(tester, skills[j]);
          if (mark.evaluate().isEmpty) continue;
          expect(
            tester.getTopLeft(mark).dx,
            tester.getTopLeft(nameOf(tester, skills[j])).dx,
            reason: '${skills[j].name}: mark and name share an edge',
          );
        }
      }
      // Marks on both tiles of a row sit at the same height.
      final hear = markOn(tester, Skill.listening);
      final seen = markOn(tester, Skill.recognition);
      expect(tester.getTopLeft(hear).dy, tester.getTopLeft(seen).dy);
      final l10n = l10nOf(tester);
      // From 1.3, the mark is one word; the strip keeps the full words.
      expect(
        find.text(l10n.paceFewerShort),
        scale >= 1.3 ? findsOneWidget : findsNothing,
      );
      expect(
        find.text(l10n.paceFewer),
        scale >= 1.3 ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in <bool>[false, true]) {
    testWidgets('at text scale 2.0${dark ? ', dark' : ''}: one column, full '
        'marks, nothing clipped', (tester) async {
      usePhone(tester, textScale: 2.0);
      final state = await pacedLearner(
        Paced.fewer,
        also: <Paced>{Paced.more, Paced.same},
      );
      await pumpScreen(
        tester,
        const TodayPage(),
        state: state,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      );
      final l10n = l10nOf(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(l10n.paceMore));
      await tester.pumpAndSettle();
      expect(find.text(l10n.paceMore), findsOneWidget);
      expect(find.text(l10n.paceMoreShort), findsNothing);
    });
  }
}
