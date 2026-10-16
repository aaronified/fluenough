import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/inspect_page.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/ui/widgets/drill_frame.dart';
import 'package:fluenough/ui/widgets/ipa_line.dart';

import '../../support/harness.dart';

/// The IPA line (ADR-0025, #533), as the owner placed it: under a word the
/// question shows, from the start; with the answer once it is in where the
/// word is the answer or is heard; under passages and in Inspect. Show IPA
/// in Settings hides it everywhere.

const String spanish = 'es-en-core-100';
const String hindi = 'hi-en-first-words';
const String bengaliReading = 'bn-en-reading-sahaj-path-1';
const String grammar = 'es-en-grammar-present-ar';

/// `la ventana`, as the deck says it.
const String ventana = '/la benˈtana/';

AppState ipaApp({bool showIpa = true, double cardTextScale = 1.0}) =>
    AppState.test(
      tts: FixedTtsEngine(<String>{'es', 'hi', 'bn'}),
      settings: SettingsNotifier(cardTextScale: cardTextScale)
        ..showIpa = showIpa,
    );

Future<AppState> pumpDrill(
  WidgetTester tester,
  DrillRequest request, {
  DrillPreset? preset,
  AppState? state,
}) => pumpScreen(
  tester,
  DrillPage(request: request, preset: preset),
  state: state ?? ipaApp(),
);

Finder ipaLine(String shown) =>
    find.descendant(of: find.byType(IpaLine), matching: find.text(shown));

void main() {
  testWidgets('recognition shows the IPA under the word from the start', (
    tester,
  ) async {
    usePhone(tester);
    await pumpDrill(
      tester,
      DrillRequest.untaught(spanish, skill: Skill.recognition),
      preset: const DrillPreset(target: 'la ventana'),
    );
    expect(ipaLine(ventana), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(IpaLine)).label,
      l10nOf(tester).ipaSemantics('la benˈtana'),
    );
  });

  testWidgets('Hindi: the IPA shows with the reading and the script', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpDrill(
      tester,
      DrillRequest.untaught(hindi, skill: Skill.recognition),
      preset: const DrillPreset(target: 'आप'),
    );
    final card = state
        .deckById(hindi)!
        .cards
        .firstWhere((c) => c.target == 'आप');
    expect(ipaLine('/${card.ipa}/'), findsOneWidget);
  });

  testWidgets('production: the IPA only once the answer is in', (tester) async {
    usePhone(tester);
    await pumpDrill(
      tester,
      DrillRequest.untaught(spanish, skill: Skill.production),
      preset: const DrillPreset(target: 'la ventana'),
    );
    expect(find.byType(IpaLine), findsNothing, reason: 'it is the answer');

    await tester.enterText(find.byType(TextField), 'la ventana');
    await tester.pump();
    await tester.tap(find.text(l10nOf(tester).drillCheck));
    await tester.pumpAndSettle();
    await scrollToFind(tester, ipaLine(ventana));
    expect(ipaLine(ventana), findsOneWidget);
  });

  testWidgets('listening: not before the answer, which it would give away', (
    tester,
  ) async {
    usePhone(tester);
    await pumpDrill(
      tester,
      DrillRequest.untaught(spanish, skill: Skill.listening),
      preset: const DrillPreset(target: 'la ventana'),
    );
    expect(find.byType(IpaLine), findsNothing);
  });

  testWidgets('grammar: the form\'s IPA once answered', (tester) async {
    usePhone(tester);
    await pumpDrill(
      tester,
      DrillRequest.untaught(grammar, skill: Skill.grammar),
      preset: const DrillPreset(target: 'hablo'),
    );
    expect(find.byType(IpaLine), findsNothing);
    await tester.enterText(find.byType(TextField), 'hablo');
    await tester.pump();
    await tester.tap(find.text(l10nOf(tester).drillCheck));
    await tester.pumpAndSettle();
    await scrollToFind(tester, ipaLine('/ˈablo/'));
    expect(ipaLine('/ˈablo/'), findsOneWidget);
  });

  testWidgets('Bengali: a passage shows each sentence\'s IPA', (tester) async {
    usePhone(tester);
    await pumpDrill(
      tester,
      DrillRequest.untaught(bengaliReading, skill: Skill.reading),
    );
    expect(ipaLine('/bɔne t̪ʰake baɡʱ/'), findsOneWidget);
  });

  testWidgets('Inspect shows a card\'s IPA beside its word', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const InspectPage(deckId: hindi),
      state: ipaApp(),
    );
    final first = state.deckById(hindi)!.cards.first;
    expect(ipaLine('/${first.ipa}/'), findsOneWidget);

    state.settings.showIpa = false;
    await tester.pumpAndSettle();
    expect(find.byType(IpaLine), findsNothing, reason: 'live');
  });

  testWidgets('Show IPA off: no line on a card', (tester) async {
    usePhone(tester);
    await pumpDrill(
      tester,
      DrillRequest.untaught(spanish, skill: Skill.recognition),
      preset: const DrillPreset(target: 'la ventana', reveal: true),
      state: ipaApp(showIpa: false),
    );
    expect(find.byType(IpaLine), findsNothing);
  });

  test('Show IPA is on by default', () {
    expect(SettingsNotifier().showIpa, isTrue);
  });

  // The 2026-10-04 draft overflowed here, with the IPA in the feedback; it
  // is on the card now, which scrolls. 1.4x is the app's cap (#505).
  group('at 1.4x text nothing overflows', () {
    final states = <(String, DrillRequest, DrillPreset)>[
      (
        'production, near miss',
        DrillRequest.untaught(spanish, skill: Skill.production),
        const DrillPreset(
          target: 'la ventana',
          typed: 'la ventna',
          check: true,
        ),
      ),
      (
        'production, answered',
        DrillRequest.untaught(spanish, skill: Skill.production),
        const DrillPreset(
          target: 'la ventana',
          typed: 'la ventana',
          check: true,
        ),
      ),
      (
        'recognition, revealed',
        DrillRequest.untaught(spanish, skill: Skill.recognition),
        const DrillPreset(target: 'la ventana', reveal: true),
      ),
      (
        'Hindi recognition, revealed',
        DrillRequest.untaught(hindi, skill: Skill.recognition),
        const DrillPreset(target: 'आप', reveal: true),
      ),
      (
        'grammar, near miss',
        DrillRequest.untaught(grammar, skill: Skill.grammar),
        const DrillPreset(target: 'hablamos', typed: 'hablamo', check: true),
      ),
      (
        'Bengali passage',
        DrillRequest.untaught(bengaliReading, skill: Skill.reading),
        const DrillPreset(),
      ),
    ];
    for (final (name, request, preset) in states) {
      for (final phone in <double>[1.4, 2.0]) {
        testWidgets('$name, phone at $phone', (tester) async {
          usePhone(tester, textScale: phone);
          await pumpDrill(
            tester,
            request,
            preset: preset,
            state: ipaApp(cardTextScale: SettingsNotifier.maxCardTextScale),
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(DrillFrame), findsOneWidget);
          expect(find.byType(IpaLine), findsWidgets);
        });
      }
    }
  });
}
