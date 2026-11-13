// The one shared self-rating row: four labels, Again, Hard, Okay, Easy, in
// light and dark at the app's 1.4x text cap, each reporting its own grade.

import 'package:fluenough/core/grading/self_grade.dart';
import 'package:fluenough/features/drill/rating_buttons.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<SelfGrade>> _pump(
  WidgetTester tester,
  Brightness brightness, {
  int Function(SelfGrade grade)? intervalFor,
}) async {
  final rated = <SelfGrade>[];
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: brightness,
        ),
      ),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(1.4),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RatingButtons(intervalFor: intervalFor, onRate: rated.add),
          ),
        ),
      ),
    ),
  );
  return rated;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('shows Again, Hard, Okay, Easy in one row at 1.4x, '
        '${brightness.name}', (tester) async {
      await _pump(tester, brightness);
      for (final label in <String>['Again', 'Hard', 'Okay', 'Easy']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Good'), findsNothing);
      final tops = <double>{
        for (final label in <String>['Again', 'Hard', 'Okay', 'Easy'])
          tester.getTopLeft(find.text(label)).dy,
      };
      expect(tops, hasLength(1), reason: 'one row');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('each button reports its grade, and Okay is the old Good (4)', (
    tester,
  ) async {
    final rated = await _pump(tester, Brightness.light);
    for (final label in <String>['Again', 'Hard', 'Okay', 'Easy']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(rated, SelfGrade.values);
    expect(rated.map((g) => g.toGrade()), <int>[1, 3, 4, 5]);
  });

  testWidgets('an interval is read out with the label Okay', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, Brightness.dark, intervalFor: (_) => 3);
    expect(
      find.bySemanticsLabel('Okay, next review in 3 days'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
