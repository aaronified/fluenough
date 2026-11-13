import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/ipa_chart.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/ui/widgets/ipa_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// The IPA keyboard (#836): a read-only answer field with the app's own
/// keyboard of IPA symbols, as braille has.

const String _typedIpa =
    '{ code: ipa, iso639_3: zxx, name: IPA, script: ipa, icon: "ə" }';

final Map<String, String> _files = <String, String>{
  'decks/ipa/ipa-en-basics.yaml':
      '''
schema: 1
id: ipa-en-basics
name: "IPA: basics"
language: $_typedIpa
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: ipa-0001, target: "ɒ", native: "open back rounded vowel", modes: [listening, speaking] }
  - { id: ipa-0002, target: "pʰ", native: "aspirated p", modes: [listening, speaking] }
  - { id: ipa-0003, target: "ʈ", native: "voiceless retroflex plosive", modes: [listening, speaking] }
  - { id: ipa-0004, target: "voicing", native: "the vibration of the vocal folds", modes: [listening, speaking] }
''',
  'decks/ipa/ipa-path.yaml': '''
schema: 1
kind: path
id: ipa-path
language: ipa
units:
  - [ipa-basics]
  - ["*"]
''',
  'decks/es/es-en-words.yaml': '''
schema: 1
id: es-en-words
name: "Words"
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: es-0001, target: "hola", native: "hello" }
  - { id: es-0002, target: "casa", native: "house" }
''',
};

AppState _app(List<String> languages) => AppState.test(
  decks: MemoryDeckSource(_files),
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: languages,
    learningChosen: true,
  ),
  tts: const NullTtsEngine(),
);

Finder _key(String symbol) => find.byKey(ValueKey<String>('ipa-key-$symbol'));
Finder _tab(IpaKind kind) =>
    find.byKey(ValueKey<String>('ipa-tab-${kind.name}'));

/// A field with the keyboard under it, on a screen of its own.
class _Host extends StatefulWidget {
  const _Host({required this.controller, this.symbols, this.enabled = true});

  final TextEditingController controller;
  final List<IpaSymbol>? symbols;
  final bool enabled;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          children: <Widget>[
            TextField(controller: widget.controller, readOnly: true),
            IpaKeyboard(
              controller: widget.controller,
              symbols: widget.symbols,
              enabled: widget.enabled,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('the IPA chart', () {
    test('keys are the chart symbols the answers use, in chart order', () {
      final keys = ipaKeysFor(<String>['ʈ', 'ɒ', 'pʰ']);
      expect(keys.map((k) => k.symbol), <String>['ɒ', 'ʈ', 'p', 'ʰ']);
      expect(keys.map((k) => k.kind), <IpaKind>[
        IpaKind.vowels,
        IpaKind.consonants,
        IpaKind.consonants,
        IpaKind.marks,
      ]);
      expect(keys.every((k) => k.name != null), isTrue);
    });

    test('a card of words adds no keys, and a symbol the chart lacks does', () {
      final keys = ipaKeysFor(<String>['voicing', 'ɒ', 'ã', '/ /']);
      expect(keys.map((k) => k.symbol), <String>['ɒ', '/', 'ã']);
      final extra = keys.last;
      expect(extra.name, isNull);
      expect(extra.kind, IpaKind.other);
    });

    test('with no answers it is the whole chart', () {
      expect(ipaKeysFor(const <String>[]), same(ipaChart));
      expect(ipaKeysFor(<String>['voicing']), same(ipaChart));
    });

    test('a combining mark is drawn on a circle, a modifier letter is not', () {
      expect(ipaKeysFor(<String>['̃']).single.combining, isTrue);
      expect(ipaKeysFor(<String>['ʰ']).single.combining, isFalse);
    });

    test('every symbol is named and appears once', () {
      final seen = <String>{};
      for (final s in ipaChart) {
        expect(s.name, isNotEmpty, reason: s.symbol);
        expect(seen.add(s.symbol), isTrue, reason: 'twice: ${s.symbol}');
      }
    });

    test('the IPA names its own keyboard, other languages the phone\'s', () {
      const ipa = LanguageInfo(
        code: 'ipa',
        iso639_3: 'zxx',
        name: 'IPA',
        script: 'ipa',
      );
      const es = LanguageInfo(code: 'es', iso639_3: 'spa', name: 'Spanish');
      expect(ipa.keyboard, ScriptKeyboard.ipa);
      expect(es.keyboard, isNull);
    });
  });

  for (final dark in <bool>[false, true]) {
    final look = dark ? 'dark' : 'light';
    group('the keyboard at 1.4x text, $look', () {
      late TextEditingController controller;
      setUp(() => controller = TextEditingController());
      tearDown(() => controller.dispose());

      testWidgets('typing symbols builds the answer; backspace and space', (
        tester,
      ) async {
        usePhone(tester, textScale: 1.4);
        await pumpScreen(
          tester,
          _Host(
            controller: controller,
            symbols: ipaKeysFor(<String>['pʰɒ', 'ʈ', 'ã']),
          ),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        final l10n = l10nOf(tester);
        // The first tab with keys is the vowels'.
        await tester.tap(_key('ɒ'));
        await tester.pump();
        expect(controller.text, 'ɒ');
        await tester.tap(_tab(IpaKind.consonants));
        await tester.pump();
        await tester.tap(_key('p'));
        await tester.tap(find.byTooltip(l10n.ipaSpace));
        await tester.tap(_key('ʈ'));
        await tester.pump();
        expect(controller.text, 'ɒp ʈ');
        await tester.tap(_tab(IpaKind.marks));
        await tester.pump();
        await tester.tap(_key('ʰ'));
        await tester.pump();
        expect(controller.text, 'ɒp ʈʰ');
        await tester.tap(find.byTooltip(l10n.ipaBackspace));
        await tester.tap(find.byTooltip(l10n.ipaBackspace));
        await tester.pump();
        expect(controller.text, 'ɒp ');
        for (var i = 0; i < 5; i++) {
          await tester.tap(find.byTooltip(l10n.ipaBackspace));
        }
        await tester.pump();
        expect(
          controller.text,
          isEmpty,
          reason: 'backspace stops at the start',
        );
        expect(tester.takeException(), isNull, reason: 'nothing overflows');
      });

      testWidgets('keys are at least 44 dp and tabs show only the kinds '
          'present', (tester) async {
        usePhone(tester, textScale: 1.4);
        await pumpScreen(
          tester,
          _Host(controller: controller, symbols: ipaChart),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        for (final kind in IpaKind.values) {
          expect(_tab(kind), findsOneWidget);
          await tester.tap(_tab(kind));
          await tester.pump();
          final size = tester.getSize(
            find.byKey(
              ValueKey<String>(
                'ipa-key-${ipaChart.firstWhere((s) => s.kind == kind).symbol}',
              ),
            ),
          );
          expect(size.width, greaterThanOrEqualTo(44), reason: kind.name);
          expect(size.height, greaterThanOrEqualTo(44), reason: kind.name);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('a tab with no symbol is not offered', (tester) async {
        usePhone(tester, textScale: 1.4);
        await pumpScreen(
          tester,
          _Host(controller: controller, symbols: ipaKeysFor(<String>['ɒ'])),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        expect(_tab(IpaKind.vowels), findsOneWidget);
        expect(_tab(IpaKind.consonants), findsNothing);
        expect(_tab(IpaKind.marks), findsNothing);
      });

      testWidgets('a long press shows the symbol\'s name', (tester) async {
        usePhone(tester, textScale: 1.4);
        await pumpScreen(
          tester,
          _Host(controller: controller, symbols: ipaKeysFor(<String>['ɒ'])),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        await tester.longPress(_key('ɒ'));
        await tester.pumpAndSettle();
        expect(find.text('open back rounded vowel'), findsWidgets);
        expect(controller.text, isEmpty, reason: 'a long press types nothing');
      });

      testWidgets('keys do nothing once the answer is in', (tester) async {
        usePhone(tester, textScale: 1.4);
        await pumpScreen(
          tester,
          _Host(
            controller: controller,
            symbols: ipaKeysFor(<String>['ɒ']),
            enabled: false,
          ),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        await tester.tap(_key('ɒ'));
        await tester.pump();
        expect(controller.text, isEmpty);
      });
    });
  }

  group('the keyboard in the drill', () {
    testWidgets('the keys come from the IPA course\'s own cards', (
      tester,
    ) async {
      usePhone(tester, textScale: 1.4);
      final state = _app(<String>['ipa']);
      addTearDown(state.dispose);
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(
            'ipa-en-basics',
            skill: Skill.production,
          ),
          preset: const DrillPreset(target: 'pʰ'),
        ),
        state: state,
      );
      expect(find.byType(IpaKeyboard), findsOneWidget);
      // The vowels' tab: the one vowel the cards use, and no other.
      expect(_key('ɒ'), findsOneWidget);
      expect(_key('i'), findsNothing);
      expect(
        state.ipaAnswerTargets(),
        unorderedEquals(<String>['ɒ', 'pʰ', 'ʈ', 'voicing']),
      );
    });

    testWidgets('typed IPA is graded as typed, on the keyboard and not the '
        'phone\'s', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = _app(<String>['ipa']);
      addTearDown(state.dispose);
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(
            'ipa-en-basics',
            skill: Skill.production,
          ),
          preset: const DrillPreset(target: 'pʰ'),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.byType(TypedDrill), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.readOnly,
        isTrue,
        reason: 'the phone\'s keyboard stays shut',
      );
      expect(field.keyboardType, TextInputType.none);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.testTextInput.hasAnyClients, isFalse);

      await tester.tap(_tab(IpaKind.consonants));
      await tester.pump();
      await tester.tap(_key('p'));
      await tester.tap(_tab(IpaKind.marks));
      await tester.pump();
      await tester.tap(_key('ʰ'));
      await tester.pump();
      expect(field.controller!.text, 'pʰ');
      await tester.tap(find.text(l10n.drillCheck));
      await tester.pumpAndSettle();
      final session = tester
          .widget<TypedDrill>(find.byType(TypedDrill))
          .session;
      expect(session.answer!.graded!.outcome, AnswerOutcome.exact);
      expect(find.byType(IpaKeyboard), findsNothing);
    });

    testWidgets('another language keeps the phone\'s keyboard', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = _app(<String>['es']);
      addTearDown(state.dispose);
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(
            'es-en-words',
            skill: Skill.production,
          ),
          preset: const DrillPreset(target: 'hola'),
        ),
        state: state,
      );
      expect(find.byType(TypedDrill), findsOneWidget);
      expect(find.byType(IpaKeyboard), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.readOnly, isFalse);
      expect(field.keyboardType, isNot(TextInputType.none));
    });
  });
}
