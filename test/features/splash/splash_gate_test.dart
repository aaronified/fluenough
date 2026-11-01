import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/features/splash/splash_gate.dart';
import 'package:fluenough/features/splash/splash_progress.dart';
import 'package:fluenough/l10n/app_localizations.dart';

/// The splash screen on a cold start: how long it stays, what it waits for,
/// what the bar shows and how it leaves.
void main() {
  Future<void> pumpGate(
    WidgetTester tester,
    SplashProgress progress, {
    bool reduceMotion = false,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: SplashGate(progress: progress, child: child!),
        ),
        home: Scaffold(
          body: Center(
            child: TextButton(
              onPressed: onTap ?? () {},
              child: const Text('Underneath'),
            ),
          ),
        ),
      ),
    );
  }

  /// Moves the frames' clock on by [by], in 50 ms steps, and returns the
  /// bar's value at each step (null once the splash is gone).
  Future<List<double?>> advance(WidgetTester tester, Duration by) async {
    final values = <double?>[];
    for (
      var left = by;
      left > Duration.zero;
      left -= const Duration(milliseconds: 50)
    ) {
      await tester.pump(const Duration(milliseconds: 50));
      values.add(barValue(tester));
    }
    return values;
  }

  void finishAll(SplashProgress progress) {
    for (final stage in SplashStage.values) {
      progress.complete(stage);
    }
  }

  testWidgets('stays two seconds even when everything is ready at once', (
    tester,
  ) async {
    final progress = SplashProgress();
    finishAll(progress);
    await pumpGate(tester, progress);

    await advance(tester, const Duration(milliseconds: 1900));
    expect(find.byType(SplashBar), findsOneWidget);
    expect(find.text('Fluenough'), findsOneWidget);

    await advance(tester, const Duration(milliseconds: 800));
    expect(find.byType(SplashBar), findsNothing);
    expect(find.text('Underneath'), findsOneWidget);
  });

  testWidgets('waits for a stage that is not ready, then leaves', (
    tester,
  ) async {
    final progress = SplashProgress()
      ..complete(SplashStage.history)
      ..complete(SplashStage.catalog);
    await pumpGate(tester, progress);

    await advance(tester, const Duration(seconds: 6));
    expect(find.byType(SplashBar), findsOneWidget);
    expect(barValue(tester), lessThan(0.95));

    progress.complete(SplashStage.today);
    await advance(tester, const Duration(milliseconds: 800));
    expect(find.byType(SplashBar), findsNothing);
  });

  testWidgets('the bar never goes back and is full only as it leaves', (
    tester,
  ) async {
    final progress = SplashProgress();
    await pumpGate(tester, progress);

    final values = <double?>[];
    values.addAll(await advance(tester, const Duration(milliseconds: 600)));
    progress.complete(SplashStage.history);
    values.addAll(await advance(tester, const Duration(milliseconds: 800)));
    progress.complete(SplashStage.catalog);
    values.addAll(await advance(tester, const Duration(milliseconds: 1500)));
    // Everything but Today, and the minimum is over: held short of full.
    expect(values.last, lessThan(0.95));
    progress.complete(SplashStage.today);
    values.addAll(await advance(tester, const Duration(milliseconds: 300)));

    final shown = values.whereType<double>().toList();
    for (var i = 1; i < shown.length; i++) {
      expect(shown[i], greaterThanOrEqualTo(shown[i - 1]));
    }
    final full = shown.indexWhere((v) => v >= 1);
    expect(full, isNot(-1), reason: 'the bar fills before it fades');
    expect(
      shown.sublist(0, full).every((v) => v < 1),
      isTrue,
      reason: 'and not before everything is ready',
    );
  });

  testWidgets('the status line names the stage under way', (tester) async {
    final progress = SplashProgress();
    await pumpGate(tester, progress);
    expect(find.text('Opening your history'), findsOneWidget);

    progress.complete(SplashStage.history);
    await tester.pump();
    expect(find.text('Loading courses'), findsOneWidget);

    progress.complete(SplashStage.catalog);
    await tester.pump();
    expect(find.text('Getting Today ready'), findsOneWidget);

    progress.complete(SplashStage.today);
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('with animations off it leaves at once, with no fade', (
    tester,
  ) async {
    final progress = SplashProgress();
    finishAll(progress);
    await pumpGate(tester, progress, reduceMotion: true);

    await advance(tester, const Duration(milliseconds: 1900));
    expect(find.byType(SplashBar), findsOneWidget);

    await advance(tester, const Duration(milliseconds: 100));
    expect(find.byType(SplashBar), findsNothing);
  });

  testWidgets('taps reach the app only once the splash is going', (
    tester,
  ) async {
    var taps = 0;
    final progress = SplashProgress();
    finishAll(progress);
    await pumpGate(tester, progress, onTap: () => taps++);

    await tester.tap(find.text('Underneath'), warnIfMissed: false);
    expect(taps, 0, reason: 'the splash covers the app');

    await advance(tester, const Duration(seconds: 3));
    expect(find.byType(SplashBar), findsNothing);
    await tester.tap(find.text('Underneath'));
    expect(taps, 1);
  });

  testWidgets('the app starts under the splash and shows once it is gone', (
    tester,
  ) async {
    await tester.pumpWidget(FluenoughApp(state: AppState.test(), splash: true));
    await tester.pump();
    expect(find.byType(SplashBar), findsOneWidget);

    for (
      var i = 0;
      i < 100 && find.byType(SplashBar).evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SplashBar), findsNothing);
  });
}

double? barValue(WidgetTester tester) {
  final bars = find.byType(SplashBar);
  return bars.evaluate().isEmpty ? null : tester.widget<SplashBar>(bars).value;
}
