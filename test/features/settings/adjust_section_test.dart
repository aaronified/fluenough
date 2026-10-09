import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/fsrs_tuner.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/skill_fit.dart';
import 'package:fluenough/features/settings/adjust_section.dart';
import 'package:fluenough/features/settings/settings_page.dart';

import '../../support/fit_learner.dart';
import '../../support/harness.dart';
import 'support.dart';

/// [reviews] recorded into a fresh [MemoryProgress], in order.
MemoryProgress progressOf(Iterable<LoggedReview> reviews) {
  final p = MemoryProgress();
  for (final r in reviews) {
    p.record(
      deckId: r.deckId,
      cardId: r.key.cardId,
      mode: r.key.mode,
      grade: r.grade,
      now: r.at,
      answerGiven: r.answerGiven,
    );
  }
  return p;
}

/// The Adjust button.
Finder adjustButton(String label) => find.widgetWithText(FilledButton, label);

void main() {
  final now = DateTime(2026, 10, 9, 18);
  final start = DateTime(2026, 1, 1, 9);

  /// A Hindi learner with enough Write answers to fit, and a few Hear
  /// answers, too few.
  AppState learner({FitRunner runner = fitInPlace}) => AppState.test(
    progress: progressOf(
      inTimeOrder([
        ...simulate(language: 'hi', start: start, until: now),
        ...simulate(
          language: 'hi',
          start: start,
          until: now,
          cards: 3,
          mode: DrillMode.listening,
        ),
      ]),
    ),
    now: now,
    fitRunner: runner,
  );

  testWidgets('with too few answers the button waits, saying why', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, const SettingsPage());
    final l10n = l10nOf(tester);
    await scrollTo(tester, find.text(l10n.settingsAdjustHelp));

    expect(find.text(l10n.settingsAdjust), findsOneWidget);
    expect(find.text(l10n.settingsAdjustNeedsMore), findsOneWidget);
    final button = tester.widget<FilledButton>(
      adjustButton(l10n.settingsAdjustButton),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Adjust shows its progress, then what changed, per skill', (
    tester,
  ) async {
    usePhone(tester);
    final gate = Completer<void>();
    final state = learner(
      runner: (job) async {
        await gate.future;
        return SkillFit.run(job);
      },
    );
    await pumpScreen(tester, const SettingsPage(), state: state);
    final l10n = l10nOf(tester);
    await scrollTo(tester, find.text(l10n.settingsAdjustHelp));

    expect(find.text(l10n.settingsAdjustNotYet), findsOneWidget);
    await tester.ensureVisible(adjustButton(l10n.settingsAdjustButton));
    await tester.pumpAndSettle();
    await tester.tap(adjustButton(l10n.settingsAdjustButton));
    await tester.pump();

    // Adjusting: a progress bar, the skill named, the button waiting.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      find.text(
        l10n.settingsAdjusting(
          state.languages.firstWhere((l) => l.code == 'hi').name,
          'production',
          1,
          1,
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(adjustButton(l10n.settingsAdjustButton))
          .onPressed,
      isNull,
    );

    gate.complete();
    await tester.pumpAndSettle();

    // The sheet: every skill, fitted or not, and that nothing left the
    // phone.
    expect(find.text(l10n.adjustedTitle), findsOneWidget);
    expect(find.text(l10n.adjustedNotYet('listening')), findsOneWidget);
    expect(
      find.textContaining(
        RegExp(
          '^(${RegExp.escape(l10n.adjustedFewer('production'))}|'
          '${RegExp.escape(l10n.adjustedMore('production'))}|'
          '${RegExp.escape(l10n.adjustedSame('production'))})\$',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.adjustedPrivacy), findsOneWidget);
    expect(
      state.progress.parameters.fitted[(
        language: 'hi',
        mode: DrillMode.production,
      )],
      isNotNull,
    );

    await tester.tap(find.text(l10n.commonDone));
    await tester.pumpAndSettle();
    expect(find.text(l10n.adjustedTitle), findsNothing);
    expect(find.text(l10n.settingsAdjustLastToday), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester
          .widget<FilledButton>(adjustButton(l10n.settingsAdjustButton))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('the automatic switch is on by default, and kept as set', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(tester, const SettingsPage());
    final l10n = l10nOf(tester);
    await scrollTo(tester, find.text(l10n.settingsAdjustAutoDesc));

    expect(state.settings.autoAdjust, isTrue);
    await tester.ensureVisible(find.text(l10n.settingsAdjustAuto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsAdjustAuto));
    await tester.pumpAndSettle();
    expect(state.settings.autoAdjust, isFalse);
  });

  testWidgets('the sheet shows a heading per language when there are several', (
    tester,
  ) async {
    usePhone(tester);
    final state = learner();
    await pumpScreen(
      tester,
      Scaffold(body: ListView(children: const <Widget>[AdjustSection()])),
      state: state,
    );
    String name(String code) =>
        state.languages.firstWhere((l) => l.code == code).name;
    final l10n = l10nOf(tester);
    final context = tester.element(find.byType(AdjustSection));
    const none = (days: 0, reviews: 0);
    unawaited(
      showAdjustedSheet(context, state, [
        (
          key: (language: 'hi', mode: DrillMode.production),
          fitted: null,
          before: none,
          after: none,
        ),
        (
          key: (language: 'bn', mode: DrillMode.production),
          fitted: null,
          before: none,
          after: none,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text(name('hi')), findsOneWidget);
    expect(find.text(name('bn')), findsOneWidget);
    expect(find.text(l10n.adjustedNotYet('production')), findsNWidgets(2));
  });
}
