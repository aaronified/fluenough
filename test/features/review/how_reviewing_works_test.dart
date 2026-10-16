import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/reviewing.dart';
import 'package:fluenough/features/review/how_reviewing_works.dart';
import 'package:fluenough/l10n/app_localizations.dart';

import '../../support/harness.dart';

/// A screen with one button that opens the walkthrough, as Settings does.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => showHowReviewingWorks(context),
        child: const Text('open'),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  usePhone(tester);
  await pumpScreen(tester, const _Host());
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.byType(HowReviewingWorks), findsOneWidget);
}

AppLocalizations _l10n(WidgetTester tester) =>
    l10nOf(tester, find.byType(HowReviewingWorks));

/// The `## ` headings of docs/REVIEWING.md, in order.
List<String> guideHeadings() => <String>[
  for (final line in File('docs/REVIEWING.md').readAsLinesSync())
    if (line.startsWith('## ')) line.substring(3).trim(),
];

void main() {
  testWidgets('Next walks through every step of the guide, the dots saying '
      'which, and Got it on the last closes it', (tester) async {
    final semantics = tester.ensureSemantics();
    await _open(tester);
    final l10n = _l10n(tester);
    final total = reviewGuideSteps.length;
    for (final (i, step) in reviewGuideSteps.indexed) {
      expect(find.text(step.title(l10n)), findsOneWidget, reason: step.id);
      for (final paragraph in step.paragraphs(l10n)) {
        expect(find.text(paragraph), findsOneWidget, reason: step.id);
      }
      expect(
        find.bySemanticsLabel(
          l10n.reviewGuidePosition(i + 1, total, step.title(l10n)),
        ),
        findsOneWidget,
      );
      // Back from the second step on; Skip until the last.
      expect(find.text(l10n.commonBack), i == 0 ? findsNothing : findsOne);
      expect(
        find.text(l10n.onboardingSkip),
        i == total - 1 ? findsNothing : findsOneWidget,
      );
      if (i < total - 1) {
        expect(find.text(l10n.reviewHowGotIt), findsNothing);
        await tester.tap(find.text(l10n.onboardingNext));
        await tester.pumpAndSettle();
      }
    }
    await tester.tap(find.text(l10n.reviewHowGotIt));
    await tester.pumpAndSettle();
    expect(find.byType(HowReviewingWorks), findsNothing);
    semantics.dispose();
  });

  testWidgets('Back goes back a step, and a swipe moves one too', (
    tester,
  ) async {
    await _open(tester);
    final l10n = _l10n(tester);
    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pumpAndSettle();
    expect(find.text(l10n.reviewGuideToReviewTitle), findsOneWidget);
    await tester.tap(find.text(l10n.commonBack));
    await tester.pumpAndSettle();
    expect(find.text(l10n.reviewGuideCodeTitle), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(l10n.reviewGuideToReviewTitle), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        l10n.reviewGuidePosition(
          3,
          reviewGuideSteps.length,
          l10n.reviewGuideToReviewTitle,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Skip closes it from any step but the last', (tester) async {
    await _open(tester);
    final l10n = _l10n(tester);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text(l10n.onboardingNext));
      await tester.pumpAndSettle();
    }
    expect(find.text(l10n.reviewGuideSendTitle), findsNothing);
    expect(find.text(l10n.reviewGuideAdultTitle), findsNothing);
    await tester.tap(find.text(l10n.onboardingSkip));
    await tester.pumpAndSettle();
    expect(find.byType(HowReviewingWorks), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('Android back goes back a step, and closes it from the first', (
    tester,
  ) async {
    await _open(tester);
    final l10n = _l10n(tester);
    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(l10n.reviewGuideWhatTitle), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HowReviewingWorks), findsNothing);
  });

  testWidgets('the agreement step states the review bot\'s default, and the '
      'thanks step where to write', (tester) async {
    await pumpScreen(
      tester,
      HowReviewingWorks(initialStep: reviewGuideSteps.length - 2),
    );
    final l10n = _l10n(tester);
    expect(
      find.text(l10n.reviewGuideAgreeCount(Reviewing.agreementsNeeded)),
      findsOneWidget,
    );
    expect(Reviewing.agreementsNeeded, 1);
    await tester.tap(find.text(l10n.onboardingNext));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.reviewGuideThanksHelp(AppLinks.feedbackEmail)),
      findsOneWidget,
    );
  });

  group('docs/REVIEWING.md and the app say the same', () {
    test('every step is a section of the guide, in its order, and every '
        'section but Help is a step', () {
      expect(guideHeadings(), <String>[
        for (final step in reviewGuideSteps) step.guideHeading,
        'Help',
      ]);
    });

    test('the guide gives the same number of agreements, and the same '
        'address', () {
      final guide = File('docs/REVIEWING.md').readAsStringSync();
      expect(guide, contains('`REVIEW_AGREEMENTS_NEEDED`'));
      expect(
        guide.replaceAll(RegExp(r'\s+'), ' '),
        contains('is ${Reviewing.agreementsNeeded} by default'),
      );
      expect(guide, contains(AppLinks.feedbackEmail));
    });

    test('the review bot\'s default is the app\'s', () {
      final bot = File('tools/review_bot.py').readAsStringSync();
      expect(
        bot.replaceAll(RegExp(r'\s+'), ' '),
        contains('${Reviewing.agreementsNeeded} when unset'),
      );
    });
  });
}
