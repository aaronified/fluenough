import 'dart:ui' show LocaleStringAttribute;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/numbers/number_practice.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/import_page.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/recognition_drill.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/features/profiles/new_profile_page.dart';
import 'package:fluenough/features/profiles/profiles_page.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/voices_page.dart';
import 'package:fluenough/features/stats/leeches_page.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:fluenough/ui/widgets/target_text.dart';

import 'support/harness.dart';

/// Flutter's accessibility guidelines on every drill state (#26): tap targets
/// big enough for a drill used fast, every tap target labelled, and text at
/// WCAG AA contrast, in both themes.
Future<void> meetsEveryGuideline(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

/// The parts of [finder]'s screen-reader label marked as another language,
/// by locale.
Map<String, String> quotedIn(WidgetTester tester, Finder finder) {
  final label = tester.getSemantics(finder).attributedLabel;
  return <String, String>{
    for (final a in label.attributes.whereType<LocaleStringAttribute>())
      label.string.substring(a.range.start, a.range.end): a.locale
          .toLanguageTag(),
  };
}

/// The nodes on the screen reader's tree whose label or value has [text].
FinderBase<SemanticsNode> readsOut(String text) => find.semantics.byPredicate(
  (node) => node.label.contains(text) || node.value.contains(text),
);

void main() {
  group('deck content in an interface string is read in its language', () {
    const spanish = LanguageInfo(
      code: 'es',
      iso639_3: 'spa',
      name: 'Spanish',
      script: 'latin',
    );

    test('the longest quote wins, and the rest stays unmarked', () {
      final span = quotingTarget('You typed “nino”. Written: el niño', <String>[
        'niño',
        'el niño',
        'nino',
      ], spanish);
      expect(
        [
          for (final child in span.children!.cast<TextSpan>())
            (child.text, child.locale?.languageCode),
        ],
        <(String?, String?)>[
          ('You typed “', null),
          ('nino', 'es'),
          ('”. Written: ', null),
          ('el niño', 'es'),
        ],
      );
    });

    testWidgets('a wrong answer\'s feedback', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.deck('es-en-core-100', skill: Skill.production),
          preset: const DrillPreset(
            target: 'el niño',
            typed: 'la mesa',
            check: true,
          ),
        ),
      );
      final l10n = l10nOf(tester);
      expect(
        quotedIn(tester, find.text(l10n.feedbackAnswer('el niño'))),
        <String, String>{'el niño': 'es'},
      );
      semantics.dispose();
    });

    testWidgets('but not a heard number\'s digits', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final settings = SettingsNotifier()
        ..setSkillEnabled(Skill.recognition, false)
        ..setSkillEnabled(Skill.production, false);
      await pumpScreen(
        tester,
        DrillPage(request: DrillRequest.numbers('hi-en-numbers-big')),
        state: AppState.test(
          tts: FixedTtsEngine(<String>{'hi'}),
          settings: settings,
        ),
      );
      final card =
          tester.widget<TypedDrill>(find.byType(TypedDrill)).session.item.card
              as NumberCard;
      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      await tester.tap(find.text(l10nOf(tester).drillCheck));
      await tester.pumpAndSettle();
      expect(
        quotedIn(tester, find.text(l10nOf(tester).feedbackAnswer(card.native))),
        isEmpty,
      );
      semantics.dispose();
    });
  });

  group('the screen reader never reads out the answer asked for', () {
    void expectHidden(String answer) => expect(readsOut(answer), findsNothing);

    testWidgets('recognition: the meaning, until shown', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.deck(
            'es-en-core-100',
            skill: Skill.recognition,
          ),
          preset: const DrillPreset(target: 'la casa'),
        ),
      );
      final card = tester
          .widget<RecognitionDrill>(find.byType(RecognitionDrill))
          .session
          .item
          .card;
      expect(readsOut(card.target), findsAny);
      expectHidden(card.native);
      await tester.tap(find.text(l10nOf(tester).drillShowAnswer));
      await tester.pumpAndSettle();
      expect(readsOut(card.native), findsAny);
      semantics.dispose();
    });

    testWidgets('production: the word', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.deck('es-en-core-100', skill: Skill.production),
          preset: const DrillPreset(target: 'el niño'),
        ),
      );
      expect(readsOut('the boy'), findsAny);
      expectHidden('niño');
      semantics.dispose();
    });

    testWidgets('listening: the word, and its meaning', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.deck('es-en-core-100', skill: Skill.listening),
          preset: const DrillPreset(target: 'el niño'),
        ),
        state: AppState.test(tts: FixedTtsEngine(<String>{'es'})),
      );
      expectHidden('niño');
      expectHidden('the boy');
      semantics.dispose();
    });

    testWidgets('number practice: the words for the digits', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final settings = SettingsNotifier()
        ..setSkillEnabled(Skill.recognition, false)
        ..setSkillEnabled(Skill.listening, false);
      await pumpScreen(
        tester,
        DrillPage(request: DrillRequest.numbers('hi-en-numbers-big')),
        state: AppState.test(settings: settings),
      );
      final card = tester
          .widget<TypedDrill>(find.byType(TypedDrill))
          .session
          .item
          .card;
      expect(readsOut(card.native), findsAny);
      expectHidden(card.target);
      semantics.dispose();
    });
  });

  final drills = <(String, DrillRequest, DrillPreset)>[
    (
      'recognition',
      DrillRequest.deck('es-en-core-100', skill: Skill.recognition),
      const DrillPreset(target: 'la casa'),
    ),
    (
      'recognition, revealed',
      DrillRequest.deck('es-en-core-100', skill: Skill.recognition),
      const DrillPreset(target: 'la casa', reveal: true),
    ),
    (
      'production',
      DrillRequest.deck('es-en-core-100', skill: Skill.production),
      const DrillPreset(target: 'el niño'),
    ),
    (
      'production, correct',
      DrillRequest.deck('es-en-core-100', skill: Skill.production),
      const DrillPreset(target: 'el niño', typed: 'el niño', check: true),
    ),
    (
      'production, accent',
      DrillRequest.deck('es-en-core-100', skill: Skill.production),
      const DrillPreset(target: 'el niño', typed: 'el nino', check: true),
    ),
    (
      'production, near miss',
      DrillRequest.deck('es-en-core-100', skill: Skill.production),
      const DrillPreset(target: 'la ventana', typed: 'la ventna', check: true),
    ),
    (
      'production, wrong',
      DrillRequest.deck('es-en-core-100', skill: Skill.production),
      const DrillPreset(target: 'la ventana', typed: 'el perro', check: true),
    ),
    (
      'production in a script, with the keyboard hint',
      DrillRequest.deck('ja-en-hiragana', skill: Skill.production),
      const DrillPreset(target: 'か'),
    ),
    (
      'listening',
      DrillRequest.deck('es-en-core-100', skill: Skill.listening),
      const DrillPreset(),
    ),
    (
      'number practice',
      DrillRequest.numbers('hi-en-numbers-big'),
      const DrillPreset(),
    ),
  ];

  final pages = <(String, Widget)>[
    ('a deck', const DeckDetailPage(deckId: 'hi-en-market')),
    ('a deck marked unreviewed', const DeckDetailPage(deckId: 'te-en-market')),
    ('add a deck', const ImportPage()),
    ('leeches', const LeechesPage()),
    ('appearance', const AppearancePage()),
    ('voices', const VoicesPage()),
    ('profiles', const ProfilesPage()),
    ('a new profile', const NewProfilePage()),
    (
      'the summary',
      SummaryPage(
        result: SessionResult(
          answers: const <SessionAnswer>[
            SessionAnswer(skill: Skill.recognition, grade: 4),
            SessionAnswer(skill: Skill.production, grade: 1),
          ],
          startedAt: DateTime(2026, 9, 28, 18, 50),
          endedAt: DateTime(2026, 9, 28, 19),
        ),
      ),
    ),
  ];

  group('at the largest font size, 2.0 on Android', () {
    for (final (name, request, preset) in drills) {
      testWidgets('$name: nothing clipped, targets still big enough', (
        tester,
      ) async {
        usePhone(tester, textScale: 2.0);
        final semantics = tester.ensureSemantics();
        await pumpScreen(
          tester,
          DrillPage(request: request, preset: preset),
          state: AppState.test(tts: FixedTtsEngine(<String>{'es', 'hi'})),
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  });

  for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    group('${themeMode.name} theme', () {
      for (final (name, request, preset) in drills) {
        testWidgets(name, (tester) async {
          usePhone(tester);
          final semantics = tester.ensureSemantics();
          await pumpScreen(
            tester,
            DrillPage(request: request, preset: preset),
            state: AppState.test(tts: FixedTtsEngine(<String>{'es'})),
            themeMode: themeMode,
          );
          await meetsEveryGuideline(tester);
          semantics.dispose();
        });
      }

      for (final (name, page) in pages) {
        testWidgets(name, (tester) async {
          usePhone(tester);
          final semantics = tester.ensureSemantics();
          await pumpScreen(tester, page, themeMode: themeMode);
          await meetsEveryGuideline(tester);
          semantics.dispose();
        });
      }

      for (final tab in ShellTab.values) {
        testWidgets('the ${tab.name} tab', (tester) async {
          usePhone(tester);
          final semantics = tester.ensureSemantics();
          final state = AppState.test();
          state.settings.themeMode = themeMode;
          await pumpApp(tester, state: state);
          state.shellTab.value = tab;
          await tester.pumpAndSettle();
          await meetsEveryGuideline(tester);
          semantics.dispose();
        });
      }
    });
  }
}
