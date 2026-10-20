// The app's own braille keyboard (owner, 2026-10-20: "Braille will need a
// keyboard too"; ADR-0043): six dots in the Perkins layout, Enter cell,
// Space and Backspace, under the answer field of a braille course.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/ui/widgets/braille_keyboard.dart';

import '../../support/braille_course.dart';
import '../../support/harness.dart';

Finder dot(int n) => find.byKey(ValueKey<String>('braille-dot-$n'));

/// The keyboard alone, typing into [controller].
Future<List<String>> pumpKeyboard(
  WidgetTester tester,
  TextEditingController controller, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final changes = <String>[];
  await pumpScreen(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: BrailleKeyboard(controller: controller, onChanged: changes.add),
      ),
    ),
    themeMode: themeMode,
  );
  return changes;
}

void main() {
  testWidgets('dots 1 and 2, then Enter cell, type ⠃ and lower the dots', (
    tester,
  ) async {
    usePhone(tester);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final changes = await pumpKeyboard(tester, controller);
    final l10n = l10nOf(tester);

    await tester.tap(dot(1));
    await tester.tap(dot(2));
    await tester.pump();
    expect(controller.text, isEmpty, reason: 'not entered yet');
    expect(find.text('⠃'), findsOneWidget, reason: 'the cell shown');
    await tester.tap(find.text(l10n.brailleEnterCell));
    await tester.pump();
    expect(controller.text, '⠃');
    expect(changes, <String>['⠃']);

    // The dots are lowered: a second cell starts empty.
    await tester.tap(dot(1));
    await tester.tap(find.text(l10n.brailleEnterCell));
    await tester.pump();
    expect(controller.text, '⠃⠁');
  });

  testWidgets('a dot tapped twice is lowered again, and Enter cell waits '
      'for a dot', (tester) async {
    usePhone(tester);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpKeyboard(tester, controller);
    final l10n = l10nOf(tester);
    final enter = find.widgetWithText(FilledButton, l10n.brailleEnterCell);
    expect(tester.widget<FilledButton>(enter).onPressed, isNull);
    await tester.tap(dot(4));
    await tester.pump();
    expect(tester.widget<FilledButton>(enter).onPressed, isNotNull);
    await tester.tap(dot(4));
    await tester.pump();
    expect(tester.widget<FilledButton>(enter).onPressed, isNull);
  });

  testWidgets('Space adds a space, and Backspace deletes before the cursor', (
    tester,
  ) async {
    usePhone(tester);
    final controller = TextEditingController(text: '⠁');
    addTearDown(controller.dispose);
    final changes = await pumpKeyboard(tester, controller);
    final l10n = l10nOf(tester);

    await tester.tap(find.byTooltip(l10n.brailleSpace));
    await tester.pump();
    expect(controller.text, '⠁ ');
    await tester.tap(dot(1));
    await tester.tap(dot(2));
    await tester.tap(find.text(l10n.brailleEnterCell));
    await tester.pump();
    expect(controller.text, '⠁ ⠃');

    await tester.tap(find.byTooltip(l10n.brailleBackspace));
    await tester.pump();
    expect(controller.text, '⠁ ');
    await tester.tap(find.byTooltip(l10n.brailleBackspace));
    await tester.tap(find.byTooltip(l10n.brailleBackspace));
    await tester.pump();
    expect(controller.text, isEmpty);
    // Nothing left to delete: no change.
    await tester.tap(find.byTooltip(l10n.brailleBackspace));
    await tester.pump();
    expect(changes, <String>['⠁ ', '⠁ ⠃', '⠁ ', '⠁', '']);
  });

  testWidgets('a screen reader hears each dot by its number and whether it '
      'is raised', (tester) async {
    usePhone(tester);
    final handle = tester.ensureSemantics();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpKeyboard(tester, controller);
    final l10n = l10nOf(tester);
    expect(
      tester.getSemantics(dot(1)),
      isSemantics(
        label: l10n.brailleDot(1),
        isButton: true,
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );
    await tester.tap(dot(1));
    await tester.pump();
    expect(
      tester.getSemantics(dot(1)),
      isSemantics(label: l10n.brailleDot(1), isToggled: true),
    );
    expect(find.bySemanticsLabel(l10n.brailleCellDots('1')), findsOneWidget);
    handle.dispose();
  });

  for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
    testWidgets('fits the phone at 1.4x text, ${mode.name}', (tester) async {
      usePhone(tester, textScale: 1.4);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller, themeMode: mode);
      expect(tester.takeException(), isNull);
      for (var n = 1; n <= 6; n++) {
        final size = tester.getSize(dot(n));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      final l10n = l10nOf(tester);
      expect(
        tester.getSize(find.byTooltip(l10n.brailleBackspace)).height,
        greaterThanOrEqualTo(48),
      );
      // Dots 1 to 3 down the left, 4 to 6 down the right.
      expect(
        tester.getCenter(dot(1)).dx,
        lessThan(tester.getCenter(dot(4)).dx),
      );
      expect(
        tester.getCenter(dot(1)).dy,
        lessThan(tester.getCenter(dot(3)).dy),
      );
    });
  }

  testWidgets('the braille course\'s production is typed on it, in place of '
      'the phone\'s keyboard, and graded as typed', (tester) async {
    usePhone(tester);
    final state = brailleApp(<String>['qbe']);
    addTearDown(state.dispose);
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.untaught(
          'qbe-en-letters',
          skill: Skill.production,
        ),
        preset: const DrillPreset(target: '⠃'),
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(find.byType(TypedDrill), findsOneWidget);
    expect(find.byType(BrailleKeyboard), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.readOnly, isTrue, reason: 'the phone\'s keyboard stays shut');
    expect(field.keyboardType, TextInputType.none);
    // Owner, 2026-10-20: "Make sure that the fields which need the keyboard
    // will not trigger the normal keyboard": not as it appears, nor on a tap.
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);

    await tester.tap(dot(1));
    await tester.tap(dot(2));
    await tester.tap(find.text(l10n.brailleEnterCell));
    await tester.pumpAndSettle();
    expect(field.controller!.text, '⠃');
    await tester.tap(find.text(l10n.drillCheck));
    await tester.pumpAndSettle();
    final session = tester.widget<TypedDrill>(find.byType(TypedDrill)).session;
    expect(session.answer!.graded!.outcome, AnswerOutcome.exact);
    // With the answer in, the keyboard goes with the field.
    expect(find.byType(BrailleKeyboard), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);

    // The next card's field does not ask for the phone's keyboard either.
    await tester.tap(find.text(l10n.commonContinue));
    await tester.pumpAndSettle();
    if (find.byType(BrailleKeyboard).evaluate().isNotEmpty) {
      await tester.tap(find.byType(TextField));
      await tester.pump();
    }
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
  });

  testWidgets('another language keeps the phone\'s keyboard', (tester) async {
    usePhone(tester);
    final state = brailleApp(<String>['es']);
    addTearDown(state.dispose);
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.untaught('es-en-words', skill: Skill.production),
        preset: const DrillPreset(target: 'hola'),
      ),
      state: state,
    );
    expect(find.byType(TypedDrill), findsOneWidget);
    expect(find.byType(BrailleKeyboard), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.readOnly, isFalse);
    expect(field.keyboardType, isNot(TextInputType.none));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
  });
}
