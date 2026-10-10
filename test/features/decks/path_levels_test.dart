import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/path_fixture.dart';
import 'package:fluenough/features/decks/path_parts.dart';

import '../../support/harness.dart';

/// Folding a level on the Decks path (#465).

Future<AppState> _pump(WidgetTester tester, {AppState? state}) async {
  usePhone(tester);
  final app = state ?? await _learner();
  await pumpScreen(
    tester,
    const DecksPage(planOf: PathFixtures.planOf),
    state: app,
  );
  return app;
}

Future<AppState> _learner() async {
  final app = AppState.test();
  await app.load();
  return PathFixtures.state(app, upTo: PathFixtures.familyDeck);
}

final Finder _units = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_UnitNode',
  skipOffstage: false,
);

Finder _header(String level) =>
    find.ancestor(of: find.text(level), matching: find.byType(LevelHeader));

final Finder _downward = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

void main() {
  testWidgets('tapping a level header folds its units and tapping again '
      'unfolds them, with an arrow and the state for a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final state = await _pump(tester);
    final all = _units.evaluate().length;
    expect(all, greaterThan(0));
    final header = _header('A2');
    await tester.scrollUntilVisible(header, 300, scrollable: _downward.first);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(header),
      isSemantics(hasExpandedState: true, isExpanded: true),
    );
    expect(
      find.descendant(of: header, matching: find.byIcon(Icons.expand_less)),
      findsOneWidget,
    );

    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(_units.evaluate().length, lessThan(all));
    expect(state.settings.isLevelCollapsed('te', 'A2'), isTrue);
    expect(
      tester.getSemantics(header),
      isSemantics(hasExpandedState: true, isExpanded: false),
    );
    expect(
      find.descendant(of: header, matching: find.byIcon(Icons.expand_more)),
      findsOneWidget,
    );
    // Its achievement stays: the level is still on the path.
    expect(find.byType(AchievementMark, skipOffstage: false), findsNWidgets(3));

    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(_units.evaluate().length, all);
    expect(state.settings.isLevelCollapsed('te', 'A2'), isFalse);
    handle.dispose();
  });

  testWidgets('the level up next starts unfolded, and "Where I am" unfolds '
      'it', (tester) async {
    final app = await _learner();
    app.settings.setLevelCollapsed('te', 'A1', true);
    app.settings.setLevelCollapsed('te', 'B1', true);
    await _pump(tester, state: app);
    final l10n = l10nOf(tester);
    // A1 holds Family, up next: unfolded on opening. B1 stays folded.
    expect(app.settings.isLevelCollapsed('te', 'A1'), isFalse);
    expect(app.settings.isLevelCollapsed('te', 'B1'), isTrue);
    expect(find.text(l10n.pathUpNext), findsOneWidget);

    // Folded again, "Where I am" unfolds it and finds the unit.
    await tester.ensureVisible(_header('A1'));
    await tester.pumpAndSettle();
    await tester.tap(_header('A1'));
    await tester.pumpAndSettle();
    expect(app.settings.isLevelCollapsed('te', 'A1'), isTrue);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is FloatingActionButton && w.heroTag == 'where-i-am',
      ),
    );
    await tester.pumpAndSettle();
    expect(app.settings.isLevelCollapsed('te', 'A1'), isFalse);
    expect(find.text(l10n.pathUpNext), findsOneWidget);
  });

  test('what is folded is remembered per language', () {
    final settings = SettingsNotifier()
      ..setLevelCollapsed('te', 'A2', true)
      ..setLevelCollapsed('es', 'B1', true);
    final again = SettingsNotifier()..restore(settings.toStored());
    expect(again.isLevelCollapsed('te', 'A2'), isTrue);
    expect(again.isLevelCollapsed('te', 'B1'), isFalse);
    expect(again.isLevelCollapsed('es', 'B1'), isTrue);
    expect(again.isLevelCollapsed('es', 'A2'), isFalse);
  });
}
