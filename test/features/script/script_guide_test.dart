import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/script_guide_parser.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/recognition_drill.dart';
import 'package:fluenough/features/script/script_guide_page.dart';

import '../../support/harness.dart';

/// A script's guide (#30, ADR-0016): shown once before a language's first
/// script card, and from a script deck's Tips.

const String guide = '''
schema: 1
kind: script
id: bn-script
language: bn
name: "How Bengali script works"
intro: "A few ideas come back again and again."
features:
  - id: headline
    name: "The headline"
    term: "মাত্রা (matra)"
    example: "ক"
    text: "Most letters hang from a line along the top."
    letters: ["ক", "খ"]
''';

String deck(String id, {bool script = true}) =>
    '''
schema: 1
id: $id
name: "Probe"
language: { code: bn, iso639_3: ben, name: Bengali, script: bengali, tts: bn-IN }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [${script ? 'script' : 'beginner'}]
cards:
  - { id: $id-0001, target: "ক", native: "k (ko)", reading: "ko" }
  - { id: $id-0002, target: "খ", native: "kh (kho)", reading: "kho" }
''';

AppState guided({bool withGuide = true, SettingsNotifier? settings}) =>
    AppState.test(
      decks: MemoryDeckSource(<String, String>{
        'decks/bn/bn-en-letters.yaml': deck('bn-en-letters'),
        'decks/bn/bn-en-words.yaml': deck('bn-en-words', script: false),
        if (withGuide) 'decks/bn/bn-script.yaml': guide,
      }),
      settings:
          settings ??
          SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningChosen: true,
          ),
    );

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  group('a script guide file', () {
    test('reads its features in order', () {
      final parsed = parseScriptGuide(guide, source: 'bn-script.yaml');
      expect(parsed.language, 'bn');
      expect(parsed.name, 'How Bengali script works');
      final feature = parsed.features.single;
      expect(feature.id, 'headline');
      expect(feature.term, 'মাত্রা (matra)');
      expect(feature.example, 'ক');
      expect(feature.letters, <String>['ক', 'খ']);
    });

    test('a malformed one is refused, and the catalog keeps it as broken', () {
      for (final bad in <String>[
        guide.replaceFirst('id: bn-script', 'id: bengali'),
        guide.replaceFirst('schema: 1', 'schema: 2'),
        guide.replaceFirst('    example: "ক"\n', ''),
        guide.replaceFirst('letters: ["ক", "খ"]', 'letters: "ক"'),
        '$guide\nextra: 1\n',
      ]) {
        expect(
          () => parseScriptGuide(bad, source: 'bn-script.yaml'),
          throwsA(isA<DeckParseException>()),
        );
      }
      final catalog = DeckCatalog.parseAll(<String, String>{
        'decks/bn/bn-script.yaml': guide,
        'decks/hi/hi-script.yaml': 'schema: 1\nkind: script\nid: x\n',
      });
      expect(catalog.scriptGuides.keys, <String>['bn']);
      expect(catalog.broken.single.path, 'decks/hi/hi-script.yaml');
    });
  });

  testWidgets('shown once, before the first script card, and Start goes on '
      'to the letters', (tester) async {
    usePhone(tester);
    final state = guided();
    await pumpScreen(
      tester,
      DrillPage(request: DrillRequest.deck('bn-en-letters')),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(find.text('How Bengali script works'), findsOneWidget);
    expect(find.text('The headline'), findsOneWidget);
    expect(find.text('মাত্রা (matra)'), findsOneWidget);
    expect(find.byType(RecognitionDrill), findsNothing);
    await tapText(tester, l10n.scriptGuideStart);
    expect(state.settings.hasSeenScriptGuide('bn'), isTrue);
    expect(find.byType(RecognitionDrill), findsOneWidget);

    // Seen: the next session starts on the letters.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpScreen(
      tester,
      DrillPage(request: DrillRequest.deck('bn-en-letters')),
      state: state,
    );
    expect(find.text('How Bengali script works'), findsNothing);
    expect(find.byType(RecognitionDrill), findsOneWidget);
  });

  testWidgets('not shown for a deck that is not a script, nor for a language '
      'with no guide', (tester) async {
    usePhone(tester);
    final words = guided();
    await pumpScreen(
      tester,
      DrillPage(request: DrillRequest.deck('bn-en-words')),
      state: words,
    );
    expect(find.text('How Bengali script works'), findsNothing);
    expect(words.settings.hasSeenScriptGuide('bn'), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpScreen(
      tester,
      DrillPage(request: DrillRequest.deck('bn-en-letters')),
      state: guided(withGuide: false),
    );
    expect(find.byType(RecognitionDrill), findsOneWidget);
  });

  testWidgets('Tips on a script deck opens the guide, and Done closes it', (
    tester,
  ) async {
    usePhone(tester);
    final state = guided();
    await pumpScreen(
      tester,
      const DeckDetailPage(deckId: 'bn-en-letters'),
      state: state,
    );
    final l10n = l10nOf(tester);
    await tapText(tester, l10n.deckScriptTips('Bengali'));
    expect(find.byType(ScriptGuidePage), findsOneWidget);
    expect(find.text('The headline'), findsOneWidget);
    await tapText(tester, l10n.commonDone);
    expect(find.byType(ScriptGuidePage), findsNothing);
    // Opening it from Tips doesn't count as seeing it before the letters.
    expect(state.settings.hasSeenScriptGuide('bn'), isFalse);
  });

  testWidgets('no Tips on a deck that is not a script', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const DeckDetailPage(deckId: 'bn-en-words'),
      state: guided(),
    );
    expect(find.text(l10nOf(tester).deckScriptTips('Bengali')), findsNothing);
  });

  test('which guides were seen survives a restart', () {
    final settings = SettingsNotifier()..markScriptGuideSeen('bn');
    final restored = SettingsNotifier()..restore(settings.toStored());
    expect(restored.hasSeenScriptGuide('bn'), isTrue);
    expect(restored.hasSeenScriptGuide('hi'), isFalse);
  });

  testWidgets('fits at twice the text size, and meets the tap-target, label '
      'and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    for (final scale in <double>[1.0, 2.0]) {
      usePhone(tester, textScale: scale);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpScreen(
        tester,
        DrillPage(request: DrillRequest.deck('bn-en-letters')),
        state: guided(),
      );
      expect(tester.takeException(), isNull, reason: '$scale');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
    handle.dispose();
  });
}
