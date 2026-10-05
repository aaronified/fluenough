import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/cant_now.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/grammar_cells.dart';
import 'package:fluenough/features/drill/grammar_drill.dart';
import 'package:fluenough/features/drill/input_mode_choice.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/ui/widgets/play_button.dart';

import '../../support/harness.dart';

/// A typed answer with the keyboard open: the card stays in view above the
/// field. The owner, typing a Telugu production card: "When I am typing,
/// the card is completely out of view."

/// A phone's status bar, and its keyboard with the suggestion strip, in
/// logical pixels.
const double statusBar = 47;
const double keyboard = 336;

/// The phone of [usePhone], with its status bar and gesture bar.
void usePhoneWithBars(WidgetTester tester) {
  usePhone(tester);
  tester.view.padding = const FakeViewPadding(top: statusBar * 3, bottom: 102);
  tester.view.viewPadding = const FakeViewPadding(
    top: statusBar * 3,
    bottom: 102,
  );
}

/// Opens the keyboard over the bottom of the screen, or closes it.
Future<void> setKeyboard(WidgetTester tester, {required bool open}) async {
  tester.view.viewInsets = open
      ? const FakeViewPadding(bottom: keyboard * 3)
      : FakeViewPadding.zero;
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpAndSettle();
}

/// [finder] is on screen, between the status bar and the keyboard, and
/// nothing covers it.
void expectInView(WidgetTester tester, Finder finder) {
  expect(finder.hitTestable(), findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(statusBar), reason: '$finder');
  expect(rect.bottom, lessThanOrEqualTo(844 - keyboard), reason: '$finder');
}

DrillSession sessionOf(WidgetTester tester) =>
    tester.widget<TypedDrill>(find.byType(TypedDrill)).session;

void main() {
  testWidgets('production: with the keyboard open the script or Latin '
      'letters choice goes, and the prompt, the field and Check are all in '
      'view; it comes back, the mode and what was typed kept, as the '
      'keyboard closes', (tester) async {
    usePhoneWithBars(tester);
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.untaught(
          'te-en-first-words',
          skill: Skill.production,
        ),
        preset: const DrillPreset(target: 'నమస్కారం'),
      ),
    );
    final l10n = l10nOf(tester);
    final session = sessionOf(tester);
    final prompt = find.text(session.item.card.native);
    expect(find.byType(InputModeChoice), findsOneWidget);
    final transliterating = session.transliterating;

    await tester.enterText(find.byType(TextField), 'nama');
    await setKeyboard(tester, open: true);
    expect(find.byType(InputModeChoice), findsNothing);
    expectInView(tester, prompt);
    expectInView(tester, find.byType(TextField));
    expectInView(tester, find.text(l10n.drillCheck));
    expect(find.text('nama'), findsOneWidget);

    await setKeyboard(tester, open: false);
    expect(find.byType(InputModeChoice), findsOneWidget);
    expect(session.transliterating, transliterating);
    expect(find.text('nama'), findsOneWidget);
  });

  testWidgets('listening: with the keyboard open the play button, the field '
      'and Check are in view, and Can\'t listen now waits', (tester) async {
    usePhoneWithBars(tester);
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.untaught(
          'es-en-core-100',
          skill: Skill.listening,
        ),
      ),
      state: AppState.test(tts: FixedTtsEngine(const <String>{'es'})),
    );
    final l10n = l10nOf(tester);
    expect(find.byType(CantNowButton), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'el');
    await setKeyboard(tester, open: true);
    expect(find.byType(CantNowButton), findsNothing);
    expectInView(tester, find.byType(PlayButton));
    expectInView(tester, find.text(l10n.drillSlower(0.7)));
    expectInView(tester, find.byType(TextField));
    expectInView(tester, find.text(l10n.drillCheck));

    await setKeyboard(tester, open: false);
    expect(find.byType(CantNowButton), findsOneWidget);
    expect(find.text('el'), findsOneWidget);
  });

  testWidgets('grammar: with the keyboard open the prompt, the slot, the '
      'field and Check are in view', (tester) async {
    usePhoneWithBars(tester);
    final state = await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.untaught(
          grammarFixtureDeckId,
          skill: Skill.grammar,
        ),
      ),
    );
    final l10n = l10nOf(tester);
    final drill = tester.widget<GrammarDrill>(find.byType(GrammarDrill));
    final cell = grammarCellOf(
      drill.session!.item.card,
      state.deckById(grammarFixtureDeckId)!.deck,
    )!;

    await tester.enterText(find.byType(TextField), 'habl');
    await setKeyboard(tester, open: true);
    expectInView(tester, find.text(cell.prompt));
    expectInView(tester, find.text(cell.slot));
    expectInView(tester, find.byType(TextField));
    expectInView(tester, find.text(l10n.drillCheck));
  });
}
