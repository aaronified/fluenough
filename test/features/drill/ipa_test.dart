import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/deck_facts.dart';
import 'package:fluenough/features/decks/inspect_page.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/match_drill.dart';
import 'package:fluenough/features/drill/pair_drill.dart';
import 'package:fluenough/features/drill/pair_fixture.dart';
import 'package:fluenough/ui/widgets/feedback_banner.dart';
import 'package:fluenough/ui/widgets/ipa_text.dart';

import '../../support/harness.dart';

/// The IPA line (ADR-0025), as the owner placed it: on the teach card, under
/// a word the question shows, with the answer once it is in where the word
/// is the answer or the question is about how it sounds, under a passage's
/// sentences and glossary words, and in Inspect and the deck's preview.
/// Never on an option or a match tile; and Show IPA switches it off.

const String vocab = 'es-en-ipa-probe';
const String grammar = 'es-en-ipa-grammar';
const String reading = 'bn-en-ipa-reading';

const String casa = 'la ˈkasa';
const String example = 'mi ˈkasa es tu ˈkasa';

const String vocabYaml = '''
schema: 1
id: es-en-ipa-probe
name: "IPA probe"
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-ipa-0001
    target: "la casa"
    native: "the house"
    ipa: "la ˈkasa"
    examples:
      - target: "Mi casa es tu casa."
        native: "My house is your house."
        ipa: "mi ˈkasa es tu ˈkasa"
  - { id: es-ipa-0002, target: "el perro", native: "the dog", ipa: "el ˈpero" }
  - { id: es-ipa-0003, target: "el gato", native: "the cat", ipa: "el ˈɡato" }
  - { id: es-ipa-0004, target: "la mesa", native: "the table", ipa: "la ˈmesa" }
  - { id: es-ipa-0005, target: "el libro", native: "the book", ipa: "el ˈliβɾo" }
''';

const String grammarYaml = '''
schema: 1
id: es-en-ipa-grammar
name: "IPA grammar probe"
kind: grammar
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
pattern:
  name: Present tense
  slot_name: person
  slots: [yo, tú]
  prompt: "{lemma} ({gloss}) — {slot}"
  entries:
    - lemma: hablar
      gloss: to speak
      ipa: "aˈβlaɾ"
      forms: { yo: hablo, tú: hablas }
      ipas: { yo: "ˈaβlo", tú: "ˈaβlas" }
''';

const String readingYaml = '''
schema: 1
id: bn-en-ipa-reading
name: "IPA reading probe"
kind: reading
language: { code: bn, iso639_3: ben, name: Bengali, script: bengali, tts: bn-IN }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
passages:
  - id: bn-en-ipa-reading-shop
    title: "At the shop"
    sentences:
      - text: "কত দাম?"
        reading: "koto dam?"
        ipa: "kɔt̪o d̪am"
      - text: "পঞ্চাশ টাকা।"
        reading: "ponchash taka."
        ipa: "pɔntʃaʃ ʈaka"
    glossary:
      - word: "দাম"
        modern: "দাম"
        reading: "dam"
        ipa: "d̪am"
        meaning: { en: "price" }
    questions:
      - id: bn-en-ipa-reading-shop-q1
        prompt: { en: "The buyer asks the price." }
        answer: true
''';

AppState ipaApp({void Function(SettingsNotifier s)? change}) {
  final settings = SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningChosen: true,
    enabledSkills: Skill.values.toSet(),
  );
  change?.call(settings);
  return AppState.test(
    decks: MemoryDeckSource(const <String, String>{
      'decks/es/es-en-ipa-probe.yaml': vocabYaml,
      'decks/es/es-en-ipa-grammar.yaml': grammarYaml,
      'decks/bn/bn-en-ipa-reading.yaml': readingYaml,
    }),
    tts: FixedTtsEngine(const <String>{'es', 'bn'}),
    speech: FixedSpeechEngine(onDevice: <String>{'es'}),
    settings: settings,
  );
}

Finder ipaLine(String ipa) => find.text('/$ipa/');

Finder inFeedback(String ipa) =>
    find.descendant(of: find.byType(FeedbackBanner), matching: ipaLine(ipa));

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<AppState> pumpAsked(
  WidgetTester tester, {
  required Skill skill,
  Ask ask = Ask.own,
  AppState? state,
}) async {
  final app = state ?? ipaApp();
  await app.load();
  // Speaking enters a session only once the recogniser is ready.
  await app.startSpeech();
  return pumpScreen(
    tester,
    DrillPage(
      request: DrillRequest.untaught(vocab, skill: skill),
      preset: DrillPreset(target: 'la casa', ask: ask),
    ),
    state: app,
  );
}

void main() {
  testWidgets('the IPA line reads as the IPA to a screen reader', (
    tester,
  ) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    await pumpAsked(tester, skill: Skill.recognition);
    expect(find.byType(IpaText), findsOneWidget);
    expect(
      find.bySemanticsLabel(l10nOf(tester).ipaSemantics(casa)),
      findsOneWidget,
    );
    semantics.dispose();
  });

  group('shown with the word from the start', () {
    testWidgets('the teach card: under the word', (tester) async {
      usePhone(tester);
      final state = ipaApp();
      await pumpScreen(
        tester,
        DrillPage(request: DrillRequest.lesson(language: 'es')),
        state: state,
      );
      final first = state.lessonFor(DrillRequest.lesson(language: 'es')).first;
      expect(first.ask, Ask.teach);
      expect(ipaLine(first.card.ipa!), findsOneWidget);
    });

    testWidgets('recognition: under the word, before the answer', (
      tester,
    ) async {
      usePhone(tester);
      await pumpAsked(tester, skill: Skill.recognition);
      expect(ipaLine(casa), findsOneWidget);
      await tapVisible(tester, find.text(l10nOf(tester).drillShowAnswer));
      expect(ipaLine(casa), findsOneWidget);
    });

    testWidgets('choosing the meaning: under the word, never on an option', (
      tester,
    ) async {
      usePhone(tester);
      await pumpAsked(tester, skill: Skill.recognition, ask: Ask.chooseMeaning);
      // Once, under the word: the options are meanings, without IPA.
      expect(find.byType(IpaText), findsOneWidget);
      expect(ipaLine(casa), findsOneWidget);
      await tapVisible(tester, find.text('the house'));
      expect(find.byType(IpaText), findsOneWidget);
      expect(inFeedback(casa), findsNothing);
    });
  });

  group('shown only with the answer', () {
    Future<void> expectAfter(
      WidgetTester tester,
      Future<void> Function() answer,
    ) async {
      expect(find.byType(IpaText), findsNothing, reason: 'before answering');
      await answer();
      expect(find.byType(FeedbackBanner), findsOneWidget);
      expect(inFeedback(casa), findsOneWidget);
    }

    testWidgets('typed production', (tester) async {
      usePhone(tester);
      await pumpAsked(tester, skill: Skill.production);
      await expectAfter(tester, () async {
        await tester.enterText(find.byType(TextField), 'la casa');
        await tester.pump();
        await tapVisible(tester, find.text(l10nOf(tester).drillCheck));
      });
    });

    testWidgets('choosing the word: never on an option', (tester) async {
      usePhone(tester);
      await pumpAsked(tester, skill: Skill.production, ask: Ask.chooseWord);
      await expectAfter(tester, () => tapVisible(tester, find.text('la casa')));
    });

    testWidgets('rearrange', (tester) async {
      usePhone(tester);
      await pumpAsked(tester, skill: Skill.production, ask: Ask.rearrange);
      await expectAfter(tester, () async {
        await tapVisible(tester, find.text('la'));
        await tapVisible(tester, find.text('casa'));
        await tapVisible(tester, find.text(l10nOf(tester).drillCheck));
      });
    });

    testWidgets('typed listening', (tester) async {
      usePhone(tester);
      await pumpAsked(tester, skill: Skill.listening);
      await expectAfter(
        tester,
        () => tapVisible(tester, find.text(l10nOf(tester).drillDontKnow)),
      );
    });

    testWidgets('hearing and choosing', (tester) async {
      usePhone(tester);
      await pumpAsked(tester, skill: Skill.listening, ask: Ask.hearAndChoose);
      await expectAfter(tester, () => tapVisible(tester, find.text('la casa')));
    });

    testWidgets('speaking', (tester) async {
      usePhone(tester);
      await pumpAsked(tester, skill: Skill.speaking);
      await expectAfter(
        tester,
        () => tapVisible(tester, find.text(l10nOf(tester).drillDontKnow)),
      );
    });

    testWidgets('grammar: the form\'s own IPA', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(grammar, skill: Skill.grammar),
        ),
        state: ipaApp(),
      );
      expect(find.byType(IpaText), findsNothing);
      await tapVisible(tester, find.text(l10nOf(tester).drillDontKnow));
      final shown = tester.widget<IpaText>(
        find.descendant(
          of: find.byType(FeedbackBanner),
          matching: find.byType(IpaText),
        ),
      );
      expect(<String>['ˈaβlo', 'ˈaβlas'], contains(shown.ipa));
    });

    testWidgets('minimal pairs: the sound heard', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const PairDrill(),
        state: AppState.test(
          tts: FixedTtsEngine(const <String>{'hi'}),
          features: const FeatureRegistry.only(<Feature>{
            ...Feature.available,
            Feature.drillPair,
          }),
        ),
      );
      final heard = pairFixtureRounds.first.heard;
      expect(find.byType(IpaText), findsNothing);
      await tapVisible(
        tester,
        find.text(pairFixtureRounds.first.pair.a.target),
      );
      expect(inFeedback(heard.ipa!), findsOneWidget);
    });
  });

  testWidgets('match pairs shows none on its tiles', (tester) async {
    usePhone(tester);
    await pumpAsked(tester, skill: Skill.recognition, ask: Ask.matchPairs);
    expect(find.byType(MatchDrill), findsOneWidget);
    expect(find.byType(IpaText), findsNothing);
  });

  testWidgets('a passage: under each sentence and in its glossary', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      DrillPage(request: DrillRequest.untaught(reading, skill: Skill.reading)),
      state: ipaApp(),
    );
    expect(ipaLine('kɔt̪o d̪am'), findsOneWidget);
    expect(ipaLine('pɔntʃaʃ ʈaka'), findsOneWidget);
    await tapVisible(tester, find.text(l10nOf(tester).readingWords));
    expect(ipaLine('d̪am'), findsOneWidget);
  });

  testWidgets('a heard passage: only once the question is answered', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.untaught(reading, skill: Skill.listening),
      ),
      state: ipaApp(),
    );
    final l10n = l10nOf(tester);
    expect(find.byType(IpaText), findsNothing);
    await tapVisible(tester, find.text(l10n.readingToQuestions));
    expect(find.byType(IpaText), findsNothing);
    await tapVisible(tester, find.text(l10n.readingTrue));
    expect(ipaLine('kɔt̪o d̪am'), findsOneWidget);
  });

  testWidgets('Inspect: beside the card\'s word, its example\'s when opened, '
      'and a grammar row\'s lemma and forms', (tester) async {
    usePhone(tester);
    final state = ipaApp();
    await pumpScreen(tester, const InspectPage(deckId: vocab), state: state);
    expect(ipaLine(casa), findsOneWidget);
    expect(ipaLine('el ˈpero'), findsOneWidget);
    expect(ipaLine(example), findsNothing);
    await tapVisible(tester, find.text('la casa'));
    expect(ipaLine(example), findsOneWidget);

    state.settings.showIpa = false;
    await tester.pumpAndSettle();
    expect(find.byType(IpaText), findsNothing);

    state.settings.showIpa = true;
    await pumpScreen(tester, const InspectPage(deckId: grammar), state: state);
    expect(ipaLine('aˈβlaɾ'), findsOneWidget);
    expect(ipaLine('ˈaβlo'), findsOneWidget);
    expect(ipaLine('ˈaβlas'), findsOneWidget);
  });

  testWidgets('a deck\'s card preview', (tester) async {
    usePhone(tester);
    final state = ipaApp();
    await state.load();
    await pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: CardPreview(entry: state.deckById(vocab)!),
        ),
      ),
      state: state,
    );
    expect(ipaLine(casa), findsOneWidget);
    state.settings.showIpa = false;
    await tester.pumpAndSettle();
    expect(find.byType(IpaText), findsNothing);
  });

  group('Show IPA off', () {
    AppState off() => ipaApp(change: (s) => s.showIpa = false);

    testWidgets('none under the word, on recognition or the teach card', (
      tester,
    ) async {
      usePhone(tester);
      await pumpAsked(tester, skill: Skill.recognition, state: off());
      expect(find.byType(IpaText), findsNothing);
      await pumpScreen(
        tester,
        DrillPage(
          key: UniqueKey(),
          request: DrillRequest.lesson(language: 'es'),
        ),
        state: off(),
      );
      expect(find.byType(IpaText), findsNothing);
    });

    testWidgets('none with the answer', (tester) async {
      usePhone(tester);
      await pumpAsked(tester, skill: Skill.production, state: off());
      await tester.enterText(find.byType(TextField), 'la casa');
      await tester.pump();
      await tapVisible(tester, find.text(l10nOf(tester).drillCheck));
      expect(find.byType(FeedbackBanner), findsOneWidget);
      expect(find.byType(IpaText), findsNothing);
    });

    testWidgets('none in a passage', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(reading, skill: Skill.reading),
        ),
        state: off(),
      );
      expect(find.byType(IpaText), findsNothing);
    });
  });

  testWidgets('ipaToShow: none for no IPA, for a word written in the IPA '
      'already, or with Show IPA off', (tester) async {
    final state = ipaApp();
    late BuildContext context;
    await pumpScreen(
      tester,
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
      state: state,
    );
    expect(ipaToShow(context, casa, target: 'la casa'), casa);
    expect(ipaToShow(context, null), isNull);
    expect(ipaToShow(context, ' '), isNull);
    // A card of the IPA course, whose word is already the IPA.
    expect(ipaToShow(context, 'pʰ', target: 'pʰ'), isNull);
    state.settings.showIpa = false;
    expect(ipaToShow(context, casa, target: 'la casa'), isNull);
  });
}
