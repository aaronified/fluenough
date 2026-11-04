// Helpers and fixtures that more than one of the files split out of
// lesson_and_review_test.dart use, moved here unchanged.

import 'dart:io';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/fact.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/features/drill/pair_fixture.dart';
import 'package:fluenough/features/drill/reading_fixture.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'harness.dart';

// From session_queue_test.dart.
final now = DateTime(2026, 9, 28, 19);

Card card(String id, {Set<DrillMode> modes = const {}}) => Card(
  id: id,
  deckId: 'test',
  target: 'target $id',
  native: 'native $id',
  modes: modes,
);

SessionQueue build(
  List<Card> cards, {
  Map<(String, DrillMode), FsrsState> states = const {},
  bool voice = true,
  int newCardLimit = 20,
  Set<DrillMode>? modes,
}) {
  FsrsState? lookup(Card c, DrillMode m) => states[(c.id, m)];
  bool hasVoice(Card _) => voice;
  return modes == null
      ? SessionQueue.build(
          cards: cards,
          stateOf: lookup,
          hasVoice: hasVoice,
          now: now,
          newCardLimit: newCardLimit,
        )
      : SessionQueue.build(
          cards: cards,
          stateOf: lookup,
          hasVoice: hasVoice,
          now: now,
          newCardLimit: newCardLimit,
          modes: modes,
        );
}

Card word(String id) =>
    Card(id: id, deckId: 'words', target: 'target $id', native: 'native $id');

// From lesson_flow_test.dart.
/// A day's lesson (ADR-0024), from Today to the summary and back.

AppState spanishLearner() => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['es'],
  ),
);

// From ask_test.dart.
Card cardAsk(String id, {String? target, String? native, String? pos}) => Card(
  id: id,
  deckId: 'test',
  target: target ?? 'target $id',
  native: native ?? 'native $id',
  pos: pos,
);

SessionItem item(Card cardAsk, DrillMode mode) =>
    SessionItem(card: cardAsk, mode: mode, state: null);

String shape(SessionItem item) => item.ask == Ask.matchPairs
    ? 'match(${item.group.map((g) => g.card.id).join(',')})'
    : '${item.card.id}:${item.ask.name}';

List<String> asked(
  List<SessionItem> items, {
  bool Function(SessionItem item)? canChoose,
}) =>
    reviewAsks(items, canChoose: canChoose ?? (_) => true).map(shape).toList();

// From drill_page_test.dart.
const String spanish = 'es-en-core-100';
const String consonants = 'hi-en-script-consonants';

Future<void> typeAndCheck(WidgetTester tester, String typed) async {
  await tester.enterText(find.byType(TextField), typed);
  await tester.pump();
  await tester.tap(find.text(l10nOf(tester).drillCheck));
  await tester.pumpAndSettle();
}

// From asked_drill_test.dart.
/// Multiple choice, match pairs and rearrange (ADR-0024).

const String hindi = 'hi-en-phrasebook';
const String script = 'hi-en-script-reading';

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// From curated_options_test.dart.
/// A choice question's wrong options are the card's hand-picked confusables
/// that name cards of the course first, then the pool's.

const String core = '''
schema: 1
id: "zz-curated"
part: "core"
kind: "vocab"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu", tts: "te-IN", icon: "తె" }
license: "CC-BY-SA-4.0"
cards:
  - id: "zz-8001"
    target: "ఇల్లు"
    reading: "illu"
    pos: "noun"
    confusables:
      - { id: "a", ref: "zz-8002" }
      - { id: "b", ref: "zz-8003" }
      - { id: "c", ref: "zz-8004" }
      - { id: "d", word: "ఇంటి", reading: "iṇṭi" }
  - id: "zz-8002"
    target: "అమ్మ"
    reading: "amma"
    pos: "noun"
  - id: "zz-8003"
    target: "నేను"
    reading: "nēnu"
    pos: "pronoun"
  - id: "zz-8004"
    target: "వెళ్ళు"
    reading: "veḷḷu"
    pos: "verb"
  - id: "zz-8005"
    target: "పిల్లి"
    reading: "pilli"
    pos: "noun"
  - id: "zz-8006"
    target: "కుక్క"
    reading: "kukka"
    pos: "noun"
''';

const String layer = '''
schema: 1
id: "zz-en-curated"
kind: "layer"
core: "zz-curated"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Curated"
license: "CC-BY-SA-4.0"
cards:
  "zz-8001":
    native: "house"
    confusables:
      "a": { why: "Not the mother." }
      "b": { why: "Not the I." }
      "c": { why: "Not the verb." }
      "d": { why: "The stem." }
  "zz-8002":
    native: "mother"
  "zz-8003":
    native: "I"
  "zz-8004":
    native: "to go"
  "zz-8005":
    native: "cat"
  "zz-8006":
    native: "dog"
''';

// From ipa_line_test.dart.
/// The IPA line (ADR-0025, #533), as the owner placed it: under a word the
/// question shows, from the start; with the answer once it is in where the
/// word is the answer or is heard; under passages and in Inspect. IPA pronunciations
/// in Settings hides it everywhere.

const String grammar = 'es-en-grammar-present-ar';

// From grammar_questions_test.dart.
const appendix = 'test/fixtures/b1/appendix-a/zz';
const features = 'test/fixtures/b1/features/zz';

String read(String path) => File(path).readAsStringSync();

final homeCore = read('$appendix/zz-home.yaml');
final homeLayer = read('$appendix/en/zz-en-home.yaml');

Card cell(List<Card> cells, String suffix) =>
    cells.firstWhere((c) => c.id == 'zz-grammar-case-endings-$suffix');

// From pair_drill_test.dart.
final MinimalPair first = pairFixtureRounds.first.pair;

Future<void> choose(WidgetTester tester, PairSound sound) async {
  await tester.tap(find.text(sound.target));
  await tester.pumpAndSettle();
}

// From reading_drill_test.dart.
/// The reading drill (#98, ADR-0019): a passage, then its questions, read or
/// heard, each choice recorded at once.

final DateTime noon = DateTime(2026, 9, 28, 12);
final DrillRequest heard = DrillRequest.untaught(
  readingFixtureDeckId,
  skill: Skill.listening,
);
const String home = 'সে কাজ ক’রে বাড়ি যায়।';

/// Goes on from an answered question, a set or a teach card with the
/// end-edge chevron, as a swipe does: there is no Continue button (#509).
Future<void> nextCard(WidgetTester tester) async {
  await tester.tap(find.byTooltip(l10nOf(tester).drillNextCard));
  await tester.pumpAndSettle();
}

// From taught_details_test.dart.
/// What a word's lesson showed of it (its note and its example) comes back
/// once a review question about it is answered, never before.

const String spanishTaughtDetails = 'es-fixture-details';
const String hindiTaughtDetails = 'hi-fixture-details';

/// A drill on screen, with its engines.
class Rig {
  Rig(this.state, this.speech);

  final AppState state;
  final FixedSpeechEngine speech;

  Card card(String deck, String target) =>
      state.deckById(deck)!.cards.firstWhere((c) => c.target == target);
}

enum Outcome { right, wrong }

typedef Answer = Future<void> Function(
  WidgetTester tester,
  Rig rig,
  Card card,
  Outcome outcome,
);

Future<void> typed(WidgetTester tester, Rig rig, Card card, Outcome o) async {
  // Hear types the meaning of what was heard (ADR-0034); the rest, the word.
  final session = tester.widget<TypedDrill>(find.byType(TypedDrill)).session;
  await tester.enterText(
    find.byType(TextField),
    o == Outcome.wrong
        ? 'zzzz'
        : session.hearsMeaning
        ? card.native
        : card.target,
  );
  await tester.pump();
  await tester.tap(find.text(l10nOf(tester).drillCheck));
  await tester.pumpAndSettle();
}

Future<void> revealed(
  WidgetTester tester,
  Rig rig,
  Card card,
  Outcome o,
) async {
  await tapText(tester, l10nOf(tester).drillShowAnswer);
}

/// One way of asking a question about one word, and what it shows before
/// the answer.
class Question {
  const Question(
    this.name,
    this.skill,
    this.ask,
    this.answer, {
    required this.showsWord,
    required this.showsMeaning,
    this.phrase = false,
  });

  final String name;
  final Skill skill;
  final Ask ask;
  final Answer answer;

  /// Whether the word is on the card before the answer.
  final bool showsWord;

  /// Whether the meaning is on the card before the answer.
  final bool showsMeaning;

  /// Whether it asks a phrase, which is rearranged.
  final bool phrase;

  /// The target of the card with a note and an example, and of the one
  /// with neither, in [deck].
  String rich(String deck) => switch ((deck, phrase)) {
    (spanishTaughtDetails, false) => 'la casa',
    (spanishTaughtDetails, true) => 'buenos días a todos',
    (hindiTaughtDetails, false) => 'किताब',
    (hindiTaughtDetails, true) => 'यह मेरी किताब है',
    _ => 'کتاب',
  };

  String plain(String deck) => switch ((deck, phrase)) {
    (spanishTaughtDetails, false) => 'el perro',
    (spanishTaughtDetails, true) => 'buenas noches a todos',
    (hindiTaughtDetails, _) => 'घर',
    _ => 'گھر',
  };

  @override
  String toString() => name;
}

const Question recognition = Question(
  'recognition',
  Skill.recognition,
  Ask.own,
  revealed,
  showsWord: true,
  showsMeaning: false,
);

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

Fact fact(String id, Map<String, String> text, {String? contrast}) =>
    Fact(id: id, text: text, contrast: contrast);
