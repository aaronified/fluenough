// A lesson and a review: the session queue (due first, most overdue first,
// the new-card cap, one mode per card, no voiceless or switched-off mode);
// the lesson (easy first, teach then check then ask again, no voice falls
// back to choosing); every kind of question records its grade: recognition,
// choice, match, rearrange, typed production with a near-miss judgement,
// Hear, speaking with its try again and Hear yourself, grammar cells,
// minimal pairs, reading passages and their glossary, sets, number
// practice, and braille typed on the app's own keyboard; the path teaches
// the first two units and skips placed ones; Today's due count, Start
// review, Quick revision and the skill tiles; Can't now; the script guide;
// the daily fact; the summary.

import 'dart:io';
import 'dart:math';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/data/number_rules_parser.dart';
import 'package:fluenough/core/data/rule_expander.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/grading/self_grade.dart';
import 'package:fluenough/core/models/aksharas.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/card_set.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/fact.dart';
import 'package:fluenough/core/models/grammar_pattern.dart';
import 'package:fluenough/core/models/number_rules.dart';
import 'package:fluenough/core/models/reading.dart';
import 'package:fluenough/core/models/rule.dart';
import 'package:fluenough/core/numbers/number_practice.dart';
import 'package:fluenough/core/numbers/number_speller.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/lesson.dart';
import 'package:fluenough/core/scheduling/lesson_sets.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';
import 'package:fluenough/core/sound/sound_check.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/grammar_cells.dart';
import 'package:fluenough/features/drill/grammar_drill.dart';
import 'package:fluenough/features/drill/match_drill.dart';
import 'package:fluenough/features/drill/pair_drill.dart';
import 'package:fluenough/features/drill/pair_fixture.dart';
import 'package:fluenough/features/drill/reading_drill.dart';
import 'package:fluenough/features/drill/reading_fixture.dart';
import 'package:fluenough/features/drill/rearrange_drill.dart';
import 'package:fluenough/features/drill/recognition_drill.dart';
import 'package:fluenough/features/drill/rtl_fixture.dart';
import 'package:fluenough/features/drill/set_drill.dart';
import 'package:fluenough/features/drill/speaking_drill.dart';
import 'package:fluenough/features/drill/taught_details.dart';
import 'package:fluenough/features/drill/teach_drill.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/script/script_guide_page.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:fluenough/features/today/due_card.dart';
import 'package:fluenough/features/today/lesson_card.dart';
import 'package:fluenough/features/today/quick_revision.dart';
import 'package:fluenough/features/today/today_fixtures.dart';
import 'package:fluenough/features/today/today_numbers.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/widgets/bar_row.dart';
import 'package:fluenough/ui/widgets/braille_keyboard.dart';
import 'package:fluenough/ui/widgets/deck_tile.dart';
import 'package:fluenough/ui/widgets/drill_frame.dart';
import 'package:fluenough/ui/widgets/feedback_banner.dart';
import 'package:fluenough/ui/widgets/incoming.dart';
import 'package:fluenough/ui/widgets/ipa_line.dart';
import 'package:fluenough/ui/widgets/play_button.dart';
import 'package:fluenough/ui/widgets/stat_tile.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/braille_course.dart';
import 'support/fit_learner.dart';
import 'support/harness.dart';

// From session_queue_test.dart.
final now = DateTime(2026, 9, 28, 19);

Card card(String id, {Set<DrillMode> modes = const {}}) => Card(
  id: id,
  deckId: 'test',
  target: 'target $id',
  native: 'native $id',
  modes: modes,
);

/// A state due [daysAgo] days before [now]; negative means in the future.
FsrsState dueDaysAgo(int daysAgo) => FsrsState(
  stability: 6,
  difficulty: 5,
  repetitions: 2,
  intervalDays: 6,
  dueAt: now.subtract(Duration(days: daysAgo)),
  lastReviewAt: now.subtract(Duration(days: daysAgo + 6)),
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

List<String> ids(List<SessionItem> items) => [
  for (final i in items) '${i.card.id}:${i.mode.name}',
];

// From session_queue_reading_test.dart.
/// Reading questions in a session (#98, ADR-0019): each scheduled like a
/// card, and a passage's questions kept together.

/// [questions] questions about passage [id], as the parser makes them.
List<QuestionCard> passage(String id, int questions) {
  final p = Passage(
    id: id,
    title: 'Passage $id',
    sentences: const <PassageSentence>[PassageSentence(text: 'বাক্য।')],
    questions: <ReadingQuestion>[
      for (var i = 1; i <= questions; i++)
        ReadingQuestion(id: '$id-q$i', prompt: {'en': 'Q$i'}, answer: 0),
    ],
  );
  return <QuestionCard>[
    for (final q in p.questions)
      QuestionCard(deckId: 'reading', passage: p, question: q),
  ];
}

Card word(String id) =>
    Card(id: id, deckId: 'words', target: 'target $id', native: 'native $id');

SessionQueue buildSessionQueueReading(
  List<Card> cards, {
  Map<(String, DrillMode), FsrsState> states = const {},
  bool voice = true,
  int newCardLimit = 20,
}) => SessionQueue.build(
  cards: cards,
  stateOf: (c, m) => states[(c.id, m)],
  hasVoice: (_) => voice,
  now: now,
  newCardLimit: newCardLimit,
);

// From app_state_test.dart.

// From path_teaching_test.dart.
/// Today teaching along a course's path (#117, ADR-0013): new cards only from
/// the pending units, the current one and the next, mixed.

AppState learning(
  List<String> languages, {
  Set<String> placed = const <String>{},
  List<String> spoken = const <String>['en'],
  DeckSource? decks,
  MemoryProgress? progress,
}) => AppState.test(
  decks: decks,
  progress: progress,
  settings: SettingsNotifier(
    spokenLanguages: spoken,
    learningLanguages: languages,
    placedDecks: placed,
  ),
);

List<List<String>> unitIds(AppState state) => <List<String>>[
  for (final unit in state.pendingUnits) <String>[for (final e in unit) e.id],
];

DeckBadgeKind badgeOf(AppState state, String deckId) =>
    DeckBadge.forEntry(state, state.deckById(deckId)!).kind;

/// A tiny course: three single-card decks of Hindi from [native], and, with
/// [path], Hindi's path of three units, [first] first. The path is the
/// language's, every course's (ADR-0036), so a second course of Hindi
/// leaves it out.
Map<String, String> tinyCourse({
  String native = 'en',
  String first = 'a',
  bool path = true,
}) {
  String deck(String name) =>
      '''
schema: 1
id: hi-$native-$name
name: "$name"
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: $native, iso639_3: ${native == 'en' ? 'eng' : 'ben'}, name: ${native == 'en' ? 'English' : 'Bengali'} }
license: CC0-1.0
cards:
  - { id: hi-$native-$name-0001, target: "क", native: "k", reading: "k", modes: [recognition, listening, speaking] }
''';
  final order = <String>[
    first,
    ...<String>['a', 'b', 'c']..remove(first),
  ];
  return <String, String>{
    for (final name in <String>['a', 'b', 'c'])
      'decks/hi/hi-$native-$name.yaml': deck(name),
    if (path)
      'decks/hi/hi-path.yaml':
          '''
schema: 1
kind: path
id: hi-path
language: hi
units:
${[for (final name in order) '  - [hi-$name]'].join('\n')}
''',
  };
}

// From lesson_test.dart.
Card cardLesson(
  String id,
  String target, {
  String? reading,
  String? pos,
  Set<DrillMode> modes = const {},
}) => Card(
  id: id,
  deckId: 'test',
  target: target,
  native: 'native $id',
  reading: reading,
  pos: pos,
  modes: modes,
);

List<String> idsLesson(List<Card> cards) => <String>[
  for (final c in cards) c.id,
];

// From lesson_flow_test.dart.
/// A day's lesson (ADR-0024), from Today to the summary and back.

AppState spanishLearner() => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['es'],
  ),
);

/// The session the drill page is running.
DrillSession sessionOf(WidgetTester tester) {
  for (final widget in <Widget>[
    ...tester.widgetList(find.byType(GrammarDrill)),
    ...tester.widgetList(find.byType(TeachDrill)),
    ...tester.widgetList(find.byType(ChoiceDrill)),
    ...tester.widgetList(find.byType(MatchDrill)),
    ...tester.widgetList(find.byType(RearrangeDrill)),
  ]) {
    return switch (widget) {
      GrammarDrill(:final session?) => session,
      TeachDrill(:final session) => session,
      ChoiceDrill(:final session) => session,
      MatchDrill(:final session) => session,
      RearrangeDrill(:final session) => session,
      _ => throw StateError('$widget'),
    };
  }
  throw StateError('no lesson screen');
}

/// Answers every question of the lesson right, through the session.
Future<void> finishLesson(WidgetTester tester) async {
  while (find.byType(DrillPage).evaluate().isNotEmpty) {
    final session = sessionOf(tester);
    final card = session.item.card;
    switch (session.ask) {
      case Ask.teach || Ask.showSet:
        session.learnt();
      case Ask.chooseMeaning ||
          Ask.chooseWord ||
          Ask.hearAndChoose ||
          Ask.hearMeaning ||
          Ask.chooseFormMeaning ||
          Ask.chooseForm:
        session.pick(session.options.firstWhere((o) => o.id == card.id));
        session.next();
      case Ask.matchPairs:
        for (final entry in session.item.group) {
          session.match(entry, entry);
        }
        session.next();
      case Ask.rearrange:
        final words = tilesOf(
          session.rearrangesReading ? card.reading! : card.target,
        );
        final tiles = session.tiles;
        final used = <int>{};
        for (final word in words) {
          final i = List<int>.generate(
            tiles.length,
            (i) => i,
          ).firstWhere((i) => tiles[i] == word && !used.contains(i));
          used.add(i);
          session.place(i);
        }
        session.checkOrder();
        session.next();
      case Ask.own:
        // A grammar cell, typed, or a word heard and its meaning typed.
        session.check(session.acceptedAnswers.first);
        session.next();
    }
    await tester.pumpAndSettle();
  }
}

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

List<SessionItem> recognising(int count) => <SessionItem>[
  for (var i = 0; i < count; i++) item(cardAsk('r$i'), DrillMode.recognition),
];

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

Future<AppState> pumpDrill(
  WidgetTester tester,
  DrillRequest request, {
  DrillPreset? preset,
  AppState? state,
  ThemeMode themeMode = ThemeMode.light,
}) => pumpScreen(
  tester,
  DrillPage(request: request, preset: preset),
  state: state,
  themeMode: themeMode,
);

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

Future<AppState> pumpAsked(
  WidgetTester tester, {
  required String deck,
  required Skill skill,
  required String target,
  required Ask ask,
  AppState? state,
}) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.untaught(deck, skill: skill),
    preset: DrillPreset(target: target, ask: ask),
  ),
  state: state,
);

Card cardOf(AppState state, String deck, String target) =>
    state.deckById(deck)!.cards.firstWhere((c) => c.target == target);

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// A match pairs question of [target] and the next words of [deck] with
/// other meanings, in recognition, as a lesson asks it (ADR-0034). The
/// match shows until it is answered and continued.
Future<(AppState, DrillSession)> pumpMatch(
  WidgetTester tester, {
  required String deck,
  required String target,
}) async {
  final state = AppState.test();
  await state.load();
  final cards = state.deckById(deck)!.cards;
  final first = cards.firstWhere((c) => c.target == target);
  final group = <SessionItem>[
    SessionItem(card: first, mode: DrillMode.recognition, state: null),
  ];
  for (final card in cards) {
    if (group.length == matchSize) break;
    if (group.every(
      (g) => g.card.native != card.native && g.card.target != card.target,
    )) {
      group.add(
        SessionItem(card: card, mode: DrillMode.recognition, state: null),
      );
    }
  }
  final session = DrillSession(
    state: state,
    items: <SessionItem>[group.first.askedAs(Ask.matchPairs, group: group)],
  );
  addTearDown(session.dispose);
  await pumpScreen(
    tester,
    ListenableBuilder(
      listenable: session,
      builder: (context, _) => session.finished
          ? const SizedBox.shrink()
          : MatchDrill(session: session, onClose: () {}),
    ),
    state: state,
  );
  return (state, session);
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

// From hear_test.dart.
/// Hear (ADR-0034): the word is played, and its meaning chosen while the
/// pair is new or was last missed, typed once it was last remembered. In
/// script practice what was heard is typed instead.

const String spanishHear = 'es-fixture-hear';

/// A small Spanish deck, in memory, with a meaning in parts.
MemoryDeckSource fixtureDecks() => MemoryDeckSource(const <String, String>{
  'decks/es/$spanishHear.yaml': '''
schema: 1
id: es-fixture-hear
name: "Spanish (Hear fixture)"
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-fixture-hear-0001
    target: "ir"
    native: "to go, to leave"
  - id: es-fixture-hear-0002
    target: "la casa"
    native: "the house"
    alt_native: ["the home"]
  - id: es-fixture-hear-0003
    target: "el perro"
    native: "the dog"
  - id: es-fixture-hear-0004
    target: "el gato"
    native: "the cat"
  - id: es-fixture-hear-0005
    target: "la mesa"
    native: "the table"
''',
});

AppState spanishState({MemoryProgress? progress, DateTime? now}) =>
    AppState.test(
      decks: fixtureDecks(),
      tts: FixedTtsEngine(const <String>{'es'}),
      progress: progress,
      now: now,
    );

/// [target] of the fixture deck heard, typed, as a remembered word is.
Future<AppState> pumpTyped(WidgetTester tester, String target) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.untaught(spanishHear, skill: Skill.listening),
    preset: DrillPreset(target: target),
  ),
  state: spanishState(),
);

Future<void> typeAndCheckHear(WidgetTester tester, String typed) async {
  await tester.enterText(find.byType(TextField), typed);
  await tester.pump();
  await tapText(tester, l10nOf(tester).drillCheck);
}

// From ipa_line_test.dart.
/// The IPA line (ADR-0025, #533), as the owner placed it: under a word the
/// question shows, from the start; with the answer once it is in where the
/// word is the answer or is heard; under passages and in Inspect. IPA pronunciations
/// in Settings hides it everywhere.

const String grammar = 'es-en-grammar-present-ar';

/// `la ventana`, as the deck says it.
const String ventana = '/la benˈtana/';

AppState ipaApp({bool showIpa = true, double cardTextScale = 1.0}) =>
    AppState.test(
      tts: FixedTtsEngine(<String>{'es', 'hi', 'bn'}),
      settings: SettingsNotifier(cardTextScale: cardTextScale)
        ..showIpa = showIpa,
    );

Future<AppState> pumpDrillIpaLine(
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

// From speaking_drill_test.dart.
/// The speaking drill, the switch that turns speaking on, and the Voices
/// page's speech section (#89, ADR-0014).

AppState speakingState(FixedSpeechEngine speech, {bool on = true}) =>
    AppState.test(
      speech: speech,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
        enabledSkills: <Skill>{
          ...Skill.values.where((s) => s.onByDefault),
          if (on) Skill.speaking,
        },
      ),
    );

Future<AppState> pumpSpeaking(
  WidgetTester tester,
  FixedSpeechEngine speech,
) async {
  final state = speakingState(speech);
  await state.load();
  await state.startSpeech();
  await pumpScreen(
    tester,
    DrillPage(request: DrillRequest.untaught(spanish, skill: Skill.speaking)),
    state: state,
  );
  return state;
}

Future<void> speak(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  final mic = find.bySemanticsLabel(l10n.drillSpeak);
  await tester.ensureVisible(mic);
  await tester.pumpAndSettle();
  await tester.tap(mic);
  await tester.pumpAndSettle();
}

// From speaking_retry_test.dart.
/// Trying a pronunciation again, and hearing yourself then the voice
/// (#231, ADR-0014): the first answer is the one
/// recorded; a try again is graded and shown, never recorded.

/// What was played, in order: the learner's recording, then the voice.
final List<String> _played = <String>[];

/// A sound check that also notes, in [_played], when it plays.
class _OrderedSoundCheck extends FixedSoundCheck {
  _OrderedSoundCheck();

  @override
  Future<bool> play(Recording recording) async {
    _played.add('self');
    return super.play(recording);
  }
}

/// A voice that also notes, in [_played], what it says.
class _OrderedTts extends FixedTtsEngine {
  _OrderedTts() : super(<String>{'es'});

  @override
  Future<void> speak(
    String text, {
    required String bcp47,
    double rate = 0.5,
    String? voice,
  }) async {
    _played.add('voice $text');
    return super.speak(text, bcp47: bcp47, rate: rate, voice: voice);
  }
}

AppState _state(
  FixedSpeechEngine speech, {
  SoundCheckEngine? soundCheck,
  TtsEngine? tts,
}) => AppState.test(
  speech: speech,
  soundCheck: soundCheck ?? _OrderedSoundCheck(),
  tts: tts ?? _OrderedTts(),
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningChosen: true,
    enabledSkills: <Skill>{
      ...Skill.values.where((s) => s.onByDefault),
      Skill.speaking,
    },
  ),
);

String _unaccented(String text) => text
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');

// From grammar_questions_test.dart.
const appendix = 'test/fixtures/b1/appendix-a/zz';
const features = 'test/fixtures/b1/features/zz';
const rulesDeck = 'zz-en-grammar-case-endings';

String read(String path) => File(path).readAsStringSync();

final homeCore = read('$appendix/zz-home.yaml');
final homeLayer = read('$appendix/en/zz-en-home.yaml');
final rulesCore = read('$appendix/zz-grammar-case-endings.yaml');
final rulesLayer = read('$appendix/en/zz-en-grammar-case-endings.yaml');

Deck merge(String core, String layer) => mergeLayer(
  DeckParser.parseCore(core, source: 'core.yaml'),
  DeckParser.parseLayer(layer, source: 'layer.yaml'),
  source: 'layer.yaml',
);

/// The rules deck's cells, from [core] and [layer] as edited.
List<Card> cellsOf({String? core, String? layer}) {
  final home = merge(homeCore, homeLayer);
  return expandRules(
    merge(core ?? rulesCore, layer ?? rulesLayer),
    wordOf: (id) => home.cards.where((c) => c.id == id).firstOrNull,
  );
}

Card cell(List<Card> cells, String suffix) =>
    cells.firstWhere((c) => c.id == 'zz-grammar-case-endings-$suffix');

/// Every file of the example set, keyed as the catalog keys bundled decks.
Map<String, String> appendixFiles() => <String, String>{
  for (final file in Directory(appendix).parent.listSync(recursive: true))
    if (file is File && file.path.endsWith('.yaml'))
      'decks/${file.path.substring(Directory(appendix).parent.path.length + 1)}':
          file.readAsStringSync(),
};

FsrsState remembered(DateTime at) => FsrsState(
  stability: 5,
  difficulty: 5,
  intervalDays: 5,
  dueAt: at,
  lastReviewAt: at.subtract(const Duration(days: 5)),
  repetitions: 2,
);

FsrsState missed(DateTime at) => FsrsState(
  stability: 1,
  difficulty: 7,
  intervalDays: 1,
  dueAt: at,
  lastReviewAt: at.subtract(const Duration(days: 1)),
  lapses: 1,
);

// From grammar_drill_test.dart.
/// The real bundled pattern, as the drill reads it.
Future<GrammarPattern> realPattern() async {
  final state = AppState.test();
  await state.load();
  return state.deckById(grammarFixtureDeckId)!.deck.pattern!;
}

AppState grammarOn() => AppState.test(features: FeatureRegistry.all());

FeedbackBanner banner(WidgetTester tester) =>
    tester.widget<FeedbackBanner>(find.byType(FeedbackBanner));

// From pair_drill_test.dart.
final MinimalPair first = pairFixtureRounds.first.pair;

AppState pairOn([FixedTtsEngine? tts]) => AppState.test(
  features: FeatureRegistry.all(),
  tts: tts ?? FixedTtsEngine(const <String>{'hi'}),
);

Future<void> choose(WidgetTester tester, PairSound sound) async {
  await tester.tap(find.text(sound.target));
  await tester.pumpAndSettle();
}

// From reading_drill_test.dart.
/// The reading drill (#98, ADR-0019): a passage, then its questions, read or
/// heard, each choice recorded at once.

final DateTime noon = DateTime(2026, 9, 28, 12);

final DrillRequest readReadingDrill = DrillRequest.untaught(
  readingFixtureDeckId,
  skill: Skill.reading,
);
final DrillRequest heard = DrillRequest.untaught(
  readingFixtureDeckId,
  skill: Skill.listening,
);

const List<String> shop = <String>[
  'নমস্কার। কত দাম?',
  'পঞ্চাশ টাকা।',
  'একটু কম করুন।',
  'আচ্ছা। ধন্যবাদ।',
];
const String home = 'সে কাজ ক’রে বাড়ি যায়।';

AppState readingApp({
  FixedTtsEngine? tts,
  SettingsNotifier? settings,
  MemoryProgress? progress,
}) => AppState.test(
  decks: readingFixtureDecks(),
  tts: tts ?? FixedTtsEngine(<String>{'bn'}),
  settings: settings,
  progress: progress,
  now: noon,
);

Future<void> tapTextReadingDrill(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

/// Whether [finder] is drawn inside the phone's screen, not scrolled off it.
void expectOnScreen(WidgetTester tester, Finder finder) {
  expect(finder, findsWidgets);
  final rect = tester.getRect(finder.first);
  expect(
    rect.top >= 0 && rect.bottom <= 844 && rect.left >= 0 && rect.right <= 390,
    isTrue,
    reason: '$finder is at $rect, off the screen',
  );
}

// From set_cards_test.dart.
/// Three of the home deck's words, as one set.
const refSet = '''
  - id: "zz-9201"
    kind: "set"
    members: [{ ref: "zz-9001" }, { ref: "zz-9004" }, { ref: "zz-9006" }]
''';

/// One noun of the case table across its slots, and one slot across its
/// nouns, its card showing the rows the deck chose.
const ruleSets = '''
  - id: "zz-9202"
    kind: "set"
    members: { rule: "zz-grammar-case-endings", noun: "అమ్మ" }
  - id: "zz-9203"
    kind: "set"
    members: { rule: "zz-rule-lo", case: "lo" }
    shown: [{ ref: "zz-9004" }, { ref: "zz-9001" }]
''';

String coreWith(String sets) => '$homeCore$sets';

String layerWith(Map<String, (String, String)> texts) => homeLayer.replaceFirst(
  'cards:\n',
  <String>[
    'cards:',
    for (final MapEntry(key: id, value: (name, explanation))
        in texts.entries) ...<String>[
      '  "$id":',
      '    native: "$name"',
      '    explanation: "$explanation"',
    ],
    '',
  ].join('\n'),
);

const texts = <String, (String, String)>{
  'zz-9201': ('Three first words', 'Three words you meet first.'),
  'zz-9202': ('Mother: every case', 'One noun, అమ్మ (amma), in every case.'),
  'zz-9203': ('In: every noun', 'One ending, -లో (-lō), on every noun.'),
};

Matcher fails(String why) => throwsA(
  isA<DeckParseException>().having((e) => e.message, 'message', contains(why)),
);

Card wordSetCards(String id, String target, {String? reading}) => Card(
  id: id,
  deckId: 'xx-en-a',
  target: target,
  native: 'meaning of $target',
  reading: reading,
);

/// A rules cell of row [row], slot [slot], as the expander makes it.
Card cellSetCards(String row, String slot, String target) => Card(
  id: 'te-grammar-verb-present-$row-$slot',
  deckId: 'te-en-grammar-verb-present',
  target: target,
  native: '$row $slot',
  modes: DrillMode.vocabulary,
  rule: RuleCell(
    ruleId: 'te-rule-present',
    word: 'te-$row',
    wordTarget: row,
    slot: slot,
  ),
);

CardSet ruleSet(
  String id,
  String axis,
  String value, {
  String rule = 'te-grammar-verb-present',
  List<String> shown = const <String>[],
}) => CardSet(
  id: id,
  deckId: 'te-en-verbs',
  name: id,
  explanation: '',
  rule: SetRule(rule: rule, axis: axis, value: value),
  shown: shown,
);

/// The rules of the core te-grammar-verb-present: one, here.
Set<String> rulesOf(String core) => <String>{'te-rule-present'};

// From set_drill_test.dart.
/// Set cards in a lesson (#515), as the approved mockup
/// `docs/mockups/set-cards.html` draws them: the set first, its members
/// marked New or Known, a split set in parts with a Full list, and the Full
/// list on an answered question.

const homeSetDrill = 'zz-en-home';

/// The example set's files, with set cards added to its home deck: three
/// words, or five, split over two cards.
Map<String, String> files({bool split = false}) {
  final out = <String, String>{
    for (final file in Directory(appendix).listSync(recursive: true))
      if (file is File && file.path.endsWith('.yaml'))
        'decks/zz/${file.path.substring(appendix.length + 1)}': file
            .readAsStringSync(),
  };
  final members = split
      ? <String>['zz-9001', 'zz-9004', 'zz-9006', 'zz-9003', 'zz-9002']
      : <String>['zz-9001', 'zz-9004', 'zz-9006'];
  out['decks/zz/zz-home.yaml'] =
      '${out['decks/zz/zz-home.yaml']}'
      '  - id: "zz-9201"\n'
      '    kind: "set"\n'
      '    members: [${members.map((m) => '{ ref: "$m" }').join(', ')}]\n';
  out['decks/zz/en/zz-en-home.yaml'] = out['decks/zz/en/zz-en-home.yaml']!
      .replaceFirst(
        'cards:\n',
        'cards:\n'
            '  "zz-9201":\n'
            '    native: "First words"\n'
            '    explanation: "Words you meet first, together."\n',
      );
  return out;
}

AppState learner({bool split = false}) => AppState.test(
  decks: MemoryDeckSource(files(split: split)),
  progress: MemoryProgress(),
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['zz'],
  ),
);

DrillSession sessionOfSetDrill(WidgetTester tester) {
  for (final widget in <Widget>[
    ...tester.widgetList(find.byType(SetDrill)),
    ...tester.widgetList(find.byType(TeachDrill)),
    ...tester.widgetList(find.byType(ChoiceDrill)),
    ...tester.widgetList(find.byType(MatchDrill)),
  ]) {
    return switch (widget) {
      SetDrill(:final session) => session,
      TeachDrill(:final session) => session,
      ChoiceDrill(:final session) => session,
      MatchDrill(:final session) => session,
      _ => throw StateError('$widget'),
    };
  }
  throw StateError('no drill');
}

Future<void> openLesson(WidgetTester tester, AppState state) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.lesson(language: 'zz', deckId: homeSetDrill),
  ),
  state: state,
);

// From number_practice_test.dart.
NumberRules bundled(String code) => parseNumberRules(
  File('decks/$code/$code-numbers.yaml').readAsStringSync(),
  source: '$code-numbers.yaml',
);

// From number_speller_test.dart.
Matcher refusedWith(String message) => throwsA(
  isA<DeckParseException>().having(
    (e) => e.message,
    'message',
    contains(message),
  ),
);

// From braille_keyboard_test.dart.
Finder dot(int n) => find.byKey(ValueKey<String>('braille-dot-$n'));

// From taught_details_test.dart.
/// What a word's lesson showed of it (its note and its example) comes back
/// once a review question about it is answered, never before.

const String spanishTaughtDetails = 'es-fixture-details';
const String hindiTaughtDetails = 'hi-fixture-details';
const String urdu = 'ur-fixture-details';

/// Three small decks, in memory, so that each card has the note and the
/// example a test needs, or none.
MemoryDeckSource fixtureDecksTaughtDetails() =>
    MemoryDeckSource(const <String, String>{
      'decks/es/$spanishTaughtDetails.yaml': _spanish,
      'decks/hi/$hindiTaughtDetails.yaml': _hindi,
      'decks/ur/$urdu.yaml': _urdu,
    });

const String _spanish = '''
schema: 1
id: es-fixture-details
name: "Spanish (details fixture)"
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-fixture-0001
    target: "la casa"
    native: "the house"
    notes: "A feminine noun: la casa, las casas."
    examples:
      - target: "La casa es grande."
        native: "The house is big."
  - id: es-fixture-0002
    target: "el perro"
    native: "the dog"
  - id: es-fixture-0003
    target: "el gato"
    native: "the cat"
    notes: "A note and no example."
  - id: es-fixture-0004
    target: "la mesa"
    native: "the table"
    examples:
      - target: "La mesa es de madera."
        native: "The table is wooden."
  - id: es-fixture-0005
    target: "el libro"
    native: "the book"
  - id: es-fixture-0006
    target: "la silla"
    native: "the chair"
  - id: es-fixture-0007
    target: "buenos días a todos"
    native: "good morning, everyone"
    pos: phrase
    notes: "Said to a group, as a class begins."
    examples:
      - target: "Buenos días a todos, empecemos."
        native: "Good morning, everyone, let us begin."
  - id: es-fixture-0008
    target: "buenas noches a todos"
    native: "good night, everyone"
    pos: phrase
  - id: es-fixture-0009
    target: "la ventana"
    native: "the window"
    notes: "Spanish has two words for a window of a house and a window of a vehicle or a bank: ventana is the first, ventanilla the second. A small ventana can be a ventanita, and the diminutive is common in speech."
    examples:
      - target: "La ventana de mi habitación da al jardín y por la mañana entra mucha luz."
        native: "My bedroom window looks out on the garden, and a lot of light comes in through it in the morning."
  - id: es-fixture-0010
    target: "la ventana de mi cuarto da al jardín"
    native: "the window of my room looks out on the garden"
    pos: phrase
    notes: "Spanish has two words for a window of a house and a window of a vehicle or a bank: ventana is the first, ventanilla the second. A small ventana can be a ventanita, and the diminutive is common in speech."
    examples:
      - target: "La ventana de mi habitación da al jardín y por la mañana entra mucha luz."
        native: "My bedroom window looks out on the garden, and a lot of light comes in through it in the morning."
''';

const String _hindi = '''
schema: 1
id: hi-fixture-details
name: "Hindi (details fixture)"
kind: vocab
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: hi-fixture-0001
    target: "किताब"
    native: "book"
    reading: "kitāb"
    notes: "Borrowed from Arabic through Persian."
    examples:
      - target: "यह मेरी किताब है।"
        native: "This is my book."
  - id: hi-fixture-0002
    target: "घर"
    native: "house"
    reading: "ghar"
  - id: hi-fixture-0003
    target: "पानी"
    native: "water"
    reading: "pānī"
  - id: hi-fixture-0004
    target: "दूध"
    native: "milk"
    reading: "dūdh"
  - id: hi-fixture-0005
    target: "रोटी"
    native: "bread"
    reading: "rōṭī"
  - id: hi-fixture-0006
    target: "चाय"
    native: "tea"
    reading: "cāy"
  - id: hi-fixture-0007
    target: "यह मेरी किताब है"
    native: "this is my book"
    reading: "yah mērī kitāb hai"
    pos: phrase
    notes: "Said as you hold it up."
    examples:
      - target: "यह मेरी किताब है, वह तुम्हारी।"
        native: "This is my book, that one is yours."
''';

const String _urdu = '''
schema: 1
id: ur-fixture-details
name: "Urdu (details fixture)"
kind: vocab
language: { code: ur, iso639_3: urd, name: Urdu, script: arabic, rtl: true, tts: ur-PK }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: ur-fixture-0001
    target: "کتاب"
    native: "book"
    reading: "kitaab"
    notes: "Borrowed from Arabic."
    examples:
      - target: "یہ میری کتاب ہے۔"
        native: "This is my book."
  - id: ur-fixture-0002
    target: "گھر"
    native: "house"
    reading: "ghar"
  - id: ur-fixture-0003
    target: "پانی"
    native: "water"
    reading: "paani"
  - id: ur-fixture-0004
    target: "دودھ"
    native: "milk"
    reading: "doodh"
  - id: ur-fixture-0005
    target: "روٹی"
    native: "bread"
    reading: "roti"
  - id: ur-fixture-0006
    target: "چائے"
    native: "tea"
    reading: "chai"
''';

/// A drill on screen, with its engines.
class Rig {
  Rig(this.state, this.speech);

  final AppState state;
  final FixedSpeechEngine speech;

  Card card(String deck, String target) =>
      state.deckById(deck)!.cards.firstWhere((c) => c.target == target);
}

/// [target] of [deck], asked [ask] as [skill], on a phone with a voice and a
/// recogniser for each fixture language.
Future<Rig> pumpRig(
  WidgetTester tester, {
  required String deck,
  required Skill skill,
  required String target,
  Ask ask = Ask.own,
  Set<String> noAlphabet = const <String>{},
  bool romanisation = true,
  double cardTextScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final speech = FixedSpeechEngine(onDevice: <String>{'es', 'hi', 'ur'});
  final state = AppState.test(
    decks: fixtureDecksTaughtDetails(),
    tts: FixedTtsEngine(<String>{'es', 'hi', 'ur'}),
    speech: speech,
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
      enabledSkills: Skill.values.toSet(),
      noAlphabet: noAlphabet,
      showRomanisation: romanisation,
      cardTextScale: cardTextScale,
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  await state.startSpeech();
  await pumpScreen(
    tester,
    DrillPage(
      request: DrillRequest.untaught(deck, skill: skill),
      preset: DrillPreset(target: target, ask: ask),
    ),
    state: state,
    themeMode: themeMode,
  );
  return Rig(state, speech);
}

/// The example, named for a screen reader: its label, then the sentence and
/// its translation it holds.
Finder exampleNamed(WidgetTester tester) => find.bySemanticsLabel(
  RegExp('^${RegExp.escape(l10nOf(tester).drillExample)}'),
);

/// [finder] on the drill's card.
Finder inCard(Finder finder) =>
    find.descendant(of: find.byType(DrillCard), matching: finder);

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

Future<void> chosen(WidgetTester tester, Rig rig, Card card, Outcome o) async {
  final session = tester.widget<ChoiceDrill>(find.byType(ChoiceDrill)).session;
  final option = o == Outcome.right
      ? card
      : session.options.firstWhere((c) => c.id != card.id);
  await tapText(
    tester,
    session.ask.choosesMeaning ? option.native : option.target,
  );
}

Future<void> said(WidgetTester tester, Rig rig, Card card, Outcome o) async {
  rig.speech.next = <SpeechAlternative>[
    SpeechAlternative(o == Outcome.right ? card.target : 'zzzz'),
  ];
  final mic = find.bySemanticsLabel(l10nOf(tester).drillSpeak);
  await tester.ensureVisible(mic);
  await tester.pumpAndSettle();
  await tester.tap(mic);
  await tester.pumpAndSettle();
}

Future<void> arranged(
  WidgetTester tester,
  Rig rig,
  Card card,
  Outcome o,
) async {
  final words = tilesOf(card.target);
  for (final word in o == Outcome.right ? words : words.reversed) {
    await tapText(tester, word);
  }
  await tapText(tester, l10nOf(tester).drillCheck);
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

const List<Question> answered = <Question>[
  Question(
    'production',
    Skill.production,
    Ask.own,
    typed,
    showsWord: false,
    showsMeaning: true,
  ),
  Question(
    'listening',
    Skill.listening,
    Ask.own,
    typed,
    showsWord: false,
    showsMeaning: false,
  ),
  Question(
    'multiple choice of the meaning',
    Skill.recognition,
    Ask.chooseMeaning,
    chosen,
    showsWord: true,
    showsMeaning: false,
  ),
  Question(
    'multiple choice of the word',
    Skill.production,
    Ask.chooseWord,
    chosen,
    showsWord: false,
    showsMeaning: true,
  ),
  Question(
    'hearing and choosing',
    Skill.listening,
    Ask.hearAndChoose,
    chosen,
    showsWord: false,
    showsMeaning: false,
  ),
  Question(
    'speaking',
    Skill.speaking,
    Ask.own,
    said,
    showsWord: false,
    showsMeaning: true,
  ),
  Question(
    'rearranging',
    Skill.production,
    Ask.rearrange,
    arranged,
    showsWord: false,
    showsMeaning: true,
    phrase: true,
  ),
  Question(
    'hearing and choosing the meaning',
    Skill.listening,
    Ask.hearMeaning,
    chosen,
    showsWord: false,
    showsMeaning: false,
  ),
];

const Question recognition = Question(
  'recognition',
  Skill.recognition,
  Ask.own,
  revealed,
  showsWord: true,
  showsMeaning: false,
);

/// Where the details are on screen: the note, the example's sentence and
/// its translation, and the example itself, named for a screen reader.
void expectDetails(WidgetTester tester, Card card, {required bool shown}) {
  final example = card.examples.first;
  final matcher = shown ? findsOneWidget : findsNothing;
  expect(find.text(card.notes.first.text), matcher, reason: 'the note');
  expect(find.text(example.target), matcher, reason: 'the example');
  expect(find.text(example.native), matcher, reason: 'its translation');
  expect(exampleNamed(tester), matcher, reason: 'the example, named');
}

// From quick_revision_test.dart.
/// Quick revision (ADR-0029): words already taught, picked at random.
/// Every answer is recorded (ADR-0033).

Future<AppState> knowing(int count) async {
  final state = await withDeckTaught(
    (progress) => AppState.test(
      progress: progress,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['hi'],
      ),
    ),
    'hi-en-phrasebook',
    count: count,
    // Known in Write, one of the schedules (ADR-0034).
    mode: DrillMode.production,
  );
  await state.load();
  return state;
}

/// Every word [items] asks, a match's words each.
List<SessionItem> askedQuickRevision(List<SessionItem> items) => <SessionItem>[
  for (final item in items)
    ...item.group.isEmpty ? <SessionItem>[item] : item.group,
];

// From today_page_test.dart.
Future<AppState> pumpToday(WidgetTester tester, {AppState? state}) =>
    pumpScreen(tester, const TodayPage(), state: state);

/// Aro's fixture state: twelve days of reviews ending yesterday.
Future<AppState> fixtureState({String profile = 'aro'}) async {
  final app = AppState.test();
  await app.load();
  return GalleryFixtures.state(app, currentProfileId: profile);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Eight Hindi words, each reviewed in every mode of [ago] that long ago:
/// due again after a day. With [speaking], speaking is on and the phone
/// recognises Hindi.
Future<AppState> hindiReviewed(
  Map<DrillMode, Duration> ago, {
  bool speaking = false,
}) async {
  AppState build(MemoryProgress progress) => AppState.test(
    progress: progress,
    speech: FixedSpeechEngine(onDevice: const <String>{'hi'}),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      enabledSkills: <Skill>{
        ...Skill.values.where((s) => s.onByDefault),
        if (speaking) Skill.speaking,
      },
    ),
  );
  final base = build(MemoryProgress());
  await base.load();
  final progress = MemoryProgress();
  for (final card in base.deckById('hi-en-phrasebook')!.cards.take(8)) {
    for (final MapEntry(key: mode, value: back) in ago.entries) {
      progress.record(
        deckId: card.deckId,
        cardId: card.id,
        mode: mode,
        grade: 4,
        now: base.now().subtract(back),
      );
    }
  }
  final state = build(progress);
  await state.load();
  if (speaking) await state.startSpeech();
  return state;
}

/// [skill]'s tile on the due card.
Finder tileOf(WidgetTester tester, Skill skill) => find.descendant(
  of: find.byType(DueCard),
  matching: find.text(skill.label(l10nOf(tester))),
);

// From cant_now_test.dart.
/// "Can't speak now" and "Can't listen now" (#89): a pause for an hour, or
/// off for one language or everywhere, from a drill and from Settings.

AppState soundState({
  SettingsNotifier? settings,
  DateTime? now,
  MemoryProgress? progress,
  FixedSpeechEngine? speech,
}) => AppState.test(
  tts: FixedTtsEngine(<String>{'es', 'hi'}),
  speech: speech ?? FixedSpeechEngine(onDevice: <String>{'es'}, granted: true),
  settings:
      settings ??
      SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
        enabledSkills: Skill.values.toSet(),
      ),
  now: now ?? noon,
  progress: progress,
);

Future<void> tapTextCantNow(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

// From script_guide_test.dart.
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
    term: "মাত্রা"
    reading: "matra"
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

Future<void> tapTextScriptGuide(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

// From daily_fact_test.dart.
const facts = '''
schema: 1
id: hi-facts
name: Hindi facts
kind: facts
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
license: CC0-1.0
facts:
  - id: hi-fact-001
    text:
      en: "No Hindi word begins with ड़."
      bn: "কোনো হিন্দি শব্দ ড় দিয়ে শুরু হয় না।"
  - id: hi-fact-002
    text: { en: "Hindi writes conjuncts." }
  - id: hi-fact-101
    contrast: bn
    text: { bn: "হিন্দিতে স সবসময় 's'।" }
''';

const deckDailyFact = '''
schema: 1
id: hi-en-core
name: Hindi core
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: hi-en-core-0001, target: "घर", native: "house", reading: "ghar" }
''';

Fact fact(String id, Map<String, String> text, {String? contrast}) =>
    Fact(id: id, text: text, contrast: contrast);

// From summary_page_test.dart.
final DateTime nowSummaryPage = DateTime(2026, 9, 28, 19);

/// Five answers over three minutes, four of them correct.
final SessionResult fiveAnswers = SessionResult(
  answers: const <SessionAnswer>[
    SessionAnswer(skill: Skill.recognition, grade: 4),
    SessionAnswer(skill: Skill.recognition, grade: 5),
    SessionAnswer(skill: Skill.production, grade: 4),
    SessionAnswer(skill: Skill.production, grade: 1),
    SessionAnswer(skill: Skill.listening, grade: 3),
  ],
  startedAt: nowSummaryPage.subtract(const Duration(minutes: 3)),
  endedAt: nowSummaryPage,
);

/// Scrolls [finder] into view, building it first if the list is lazy (the
/// buttons sit in the last sliver), then taps it.
Future<void> tapVisibleSummaryPage(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The value a [StatTile] with [label] shows.
String statFor(WidgetTester tester, String label) => tester
    .widget<StatTile>(
      find.byWidgetPredicate((w) => w is StatTile && w.label == label),
    )
    .value;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the session queue', () {
    group('new cards', () {
      test(
        'the new-card cap limits new pairs, and never holds back reviews',
        () {
          final queue = build([
            for (final id in ['a', 'b', 'c', 'd']) card(id),
          ], newCardLimit: 2);
          expect(ids(queue.fresh), ['a:recognition', 'b:recognition']);

          {
            final queue = build(
              [card('a'), card('b')],
              states: {
                ('a', DrillMode.production): dueDaysAgo(1),
                ('b', DrillMode.production): dueDaysAgo(1),
              },
              newCardLimit: 0,
            );
            expect(queue.due, hasLength(2));
          }
        },
      );
    });

    group('due cards', () {
      test('due reviews come first, most overdue first', () {
        final queue = build(
          [card('a'), card('b'), card('c'), card('new')],
          states: {
            ('a', DrillMode.production): dueDaysAgo(1),
            ('b', DrillMode.production): dueDaysAgo(5),
            ('c', DrillMode.production): dueDaysAgo(3),
          },
        );
        expect(ids(queue.items), [
          'b:production',
          'c:production',
          'a:production',
          'new:recognition',
        ]);
        expect(queue.due.every((i) => !i.isNew), isTrue);
      });
    });

    group('one mode per card per session', () {
      test(
        'a card due in two modes is drilled once, in the more overdue one',
        () {
          final queue = build(
            [card('a')],
            states: {
              ('a', DrillMode.listening): dueDaysAgo(1),
              ('a', DrillMode.production): dueDaysAgo(4),
            },
          );
          expect(ids(queue.items), ['a:production']);

          {
            final queue = build(
              [card('a')],
              states: {('a', DrillMode.production): dueDaysAgo(1)},
            );
            expect(ids(queue.items), ['a:production']);
          }
        },
      );
    });

    group('modes', () {
      test(
        'a voiceless or switched-off mode is never offered; reviseAll drills '
        'every reviewed card',
        () {
          final queue = build(
            [
              card(
                'a',
                modes: {
                  DrillMode.recognition,
                  DrillMode.production,
                  DrillMode.speaking,
                },
              ),
              card('b'),
            ],
            states: {
              ('b', DrillMode.recognition): dueDaysAgo(-2),
              ('b', DrillMode.production): dueDaysAgo(-2),
              ('b', DrillMode.listening): dueDaysAgo(1),
            },
            voice: false,
          );
          expect(queue.isEmpty, isTrue);

          {
            final queue = build(
              [card('a')],
              states: {('a', DrillMode.listening): dueDaysAgo(1)},
              modes: {DrillMode.production},
            );
            expect(ids(queue.items), ['a:production']);
          }

          {
            final early = card('early');
            final later = card('later');
            final unseen = card('unseen');
            final queue = SessionQueue.build(
              cards: [early, later, unseen],
              stateOf: (c, m) => switch ((c.id, m)) {
                ('early', DrillMode.listening) => dueDaysAgo(-5),
                ('early', DrillMode.production) => dueDaysAgo(-2),
                ('later', DrillMode.listening) => dueDaysAgo(-9),
                _ => null,
              },
              hasVoice: (_) => true,
              now: now,
              newCardLimit: 0,
              reviseAll: true,
            );
            expect(queue.fresh, isEmpty);
            // One mode per card, the one due soonest; soonest card first.
            expect(queue.due.map((i) => (i.card.id, i.mode)), [
              ('early', DrillMode.production),
              ('later', DrillMode.listening),
            ]);
            // Without it, nothing is due yet.
            expect(
              SessionQueue.build(
                cards: [early, later, unseen],
                stateOf: (c, m) => c.id == 'unseen' ? null : dueDaysAgo(-5),
                hasVoice: (_) => true,
                now: now,
                newCardLimit: 0,
              ).isEmpty,
              isTrue,
            );
          }
        },
      );
    });
  });

  group('passages in the queue', () {
    test('a new question is read before it is heard', () {
      final queue = buildSessionQueueReading(passage('p', 2));
      expect(ids(queue.items), ['p-q1:reading', 'p-q2:reading']);
    });
  });

  group('a day\'s session', () {
    Future<AppState> loaded({
      FixedTtsEngine? tts,
      FeatureRegistry features = const FeatureRegistry.shipped(),
      SettingsNotifier? settings,
      List<Profile> profiles = const [Profile.defaultProfile],
    }) async {
      final state = AppState.test(
        tts: tts ?? FixedTtsEngine(const {}),
        features: features,
        settings: settings,
        profiles: profiles,
      );
      await state.load();
      return state;
    }

    group('sessions', () {
      // Grammar cards enter in their own mode. These tests are about
      // vocabulary, so the grammar drill is off in them.
      final vocabOnly = FeatureRegistry.only(
        Feature.available.difference({Feature.drillGrammar}),
      );

      test('a fresh day teaches a lesson, and taught words join the reviews in '
          'their other skills', () async {
        final state = await loaded(features: vocabOnly);
        expect(state.buildSession(const DrillRequest.today()).isEmpty, isTrue);
        final lesson = state.lessonFor(DrillRequest.lesson(language: 'es'));
        expect(lesson.where((i) => i.ask == Ask.teach), hasLength(9));

        {
          final state = await loaded(features: vocabOnly)
            ..showLanguage('es');
          final lesson = DrillRequest.lesson(language: 'es');
          final check = state.lessonFor(lesson)[1];
          state.record(check, 4);
          expect(state.isTaught(check.card), isTrue);
          final today = state.buildSession(const DrillRequest.today());
          expect(today.fresh.map((i) => i.card.id), <String>[check.card.id]);
          expect(today.fresh.single.mode, isNot(check.mode));
          expect(
            state.lessonFor(lesson).map((i) => i.card.id),
            isNot(contains(check.card.id)),
          );
        }
      });

      test(
        'listening joins only with a voice, and a switched-off skill is left '
        'out',
        () async {
          final state = await loaded(tts: FixedTtsEngine({'es'}));
          final spanish = state.buildSession(
            DrillRequest.untaught('es-en-core-100', skill: Skill.listening),
          );
          final hindi = state.buildSession(
            DrillRequest.untaught(
              'hi-en-script-vowels',
              skill: Skill.listening,
            ),
          );
          expect(spanish.isNotEmpty, isTrue);
          expect(hindi.isEmpty, isTrue);

          {
            final settings = SettingsNotifier();
            final state = await loaded(
              tts: FixedTtsEngine({'es'}),
              settings: settings,
              features: vocabOnly,
            );
            state.showLanguage('es');
            // A taught word's other skills join the reviews, Write first; with
            // Write switched off, Hear comes in its place.
            state.record(
              state.lessonFor(DrillRequest.lesson(language: 'es'))[1],
              4,
            );
            settings.setSkillEnabled(Skill.production, false);
            final queue = state.buildSession(const DrillRequest.today());
            expect(queue.isNotEmpty, isTrue);
            expect(
              queue.items.every((i) => i.mode != DrillMode.production),
              isTrue,
            );
          }
        },
      );

      test('a profile sees only its own languages', () async {
        final state = await loaded(
          profiles: const [
            Profile(id: 'mira', name: 'Mira', languages: {'hi'}),
          ],
        );
        final hindi = <String>{
          for (final d in state.decks)
            if (d.language.code == 'hi') d.id,
        };
        expect(state.profileDecks.map((d) => d.id).toSet(), hindi);
        final lesson = state.lessonFor(DrillRequest.lesson(language: 'hi'));
        expect(lesson, isNotEmpty);
        expect(lesson.every((i) => hindi.contains(i.card.deckId)), isTrue);
        expect(state.lessonFor(DrillRequest.lesson(language: 'es')), isEmpty);
      });
    });
  });

  group('the path teaches', () {
    test('A lesson takes new words only from the first two units of the '
        'path, one from each in turn', () async {
      final state = learning(<String>['hi']);
      addTearDown(state.dispose);
      await state.load();
      // Hindi starts with words and basic sentences, not its script.
      expect(unitIds(state), <List<String>>[
        <String>['hi-en-phrasebook', 'hi-en-first-words'],
        <String>['hi-en-sound-differences'],
      ]);
      final untaught = state.untaughtCards('hi');
      final unitOf = <String, int>{
        for (final (i, unit) in unitIds(state).indexed)
          for (final id in unit) id: i,
      };
      expect(untaught.map((c) => unitOf[c.deckId]), everyElement(isNotNull));
      expect(untaught.take(4).map((c) => unitOf[c.deckId]), [0, 1, 0, 1]);
      // The lesson draws on the same units.
      expect(
        state
            .lessonFor(DrillRequest.lesson(language: 'hi'))
            .map((i) => i.card.deckId),
        everyElement(isIn(unitOf.keys)),
      );
      // And Start review has no new words.
      expect(state.buildSession(const DrillRequest.today()).isEmpty, isTrue);
    });

    test('a placed unit is skipped, and a finished one passed', () async {
      final state = learning(
        <String>['hi'],
        placed: <String>{'hi-en-phrasebook', 'hi-en-first-words'},
      );
      addTearDown(state.dispose);
      await state.load();
      expect(unitIds(state).first, <String>['hi-en-sound-differences']);
      expect(unitIds(state).last.first, 'hi-en-questions');
      expect(badgeOf(state, 'hi-en-first-words'), DeckBadgeKind.done);
      expect(badgeOf(state, 'hi-en-sound-differences'), DeckBadgeKind.pending);
      expect(badgeOf(state, 'hi-en-questions'), DeckBadgeKind.pending);
      expect(badgeOf(state, 'hi-en-market'), DeckBadgeKind.notDone);
      // A placed deck can still be studied, in a lesson of its own.
      expect(
        state.lessonFor(
          DrillRequest.lesson(language: 'hi', deckId: 'hi-en-first-words'),
        ),
        isNotEmpty,
      );

      // Placement is a setting: changing it moves the window at once.
      state.settings.placedDecks = const <String>{};
      expect(unitIds(state).first.first, 'hi-en-phrasebook');

      {
        final state = learning(<String>[
          'hi',
        ], decks: MemoryDeckSource(tinyCourse()));
        addTearDown(state.dispose);
        await state.load();
        expect(unitIds(state), <List<String>>[
          <String>['hi-en-a'],
          <String>['hi-en-b'],
        ]);
        // Nothing past the pending units.
        expect(state.untaughtCards('hi').map((c) => c.deckId), <String>[
          'hi-en-a',
          'hi-en-b',
        ]);
        final first = state
            .buildSession(DrillRequest.untaught('hi-en-a'))
            .items
            .single;
        state.record(first, 5);
        expect(unitIds(state), <List<String>>[
          <String>['hi-en-b'],
          <String>['hi-en-c'],
        ]);
        expect(badgeOf(state, 'hi-en-a'), DeckBadgeKind.done);
      }
    });

    test('reviews come from every deck, pending or not', () async {
      final base = learning(<String>['hi']);
      await base.load();
      final market = base.deckById('hi-en-market')!;
      final progress = MemoryProgress()
        ..record(
          deckId: market.id,
          cardId: market.cards.first.id,
          mode: DrillMode.production,
          grade: 4,
          now: base.now().subtract(const Duration(days: 3)),
        );
      base.dispose();
      final state = learning(<String>['hi'], progress: progress);
      addTearDown(state.dispose);
      await state.load();
      final today = state.buildSession(const DrillRequest.today());
      expect(today.due.map((i) => i.card.deckId), <String>['hi-en-market']);
      expect(
        today.fresh.map((i) => i.card.deckId),
        isNot(contains('hi-en-market')),
      );
    });
  });

  group('the lesson', () {
    group('lessonItems', () {
      final easy = [for (var i = 0; i < 5; i++) cardLesson('e$i', 'sí')];
      final medium = [for (var i = 0; i < 5; i++) cardLesson('m$i', 'gracias')];
      final hard = [
        for (var i = 0; i < 5; i++) cardLesson('h$i', 'hola', pos: 'phrase'),
      ];

      test('takes the first three of each difficulty, easy first', () {
        final mixed = <Card>[
          hard[0],
          medium[0],
          easy[0],
          hard[1],
          easy[1],
          medium[1],
          easy[2],
          easy[3],
          hard[2],
          medium[2],
          hard[3],
          medium[3],
        ];
        expect(idsLesson(lessonItems(mixed)), <String>[
          'e0',
          'e1',
          'e2',
          'm0',
          'm1',
          'm2',
          'h0',
          'h1',
          'h2',
        ]);
      });
    });

    group('lessonPlan', () {
      final easy = [for (var i = 0; i < 3; i++) cardLesson('e$i', 'sí$i')];
      final medium = [
        for (var i = 0; i < 3; i++) cardLesson('m$i', 'gracias$i'),
      ];
      final hard = [
        for (var i = 0; i < 3; i++) cardLesson('h$i', 'me llamo Ana$i'),
      ];
      final nine = <Card>[...easy, ...medium, ...hard];

      String shape(SessionItem item) => item.ask == Ask.matchPairs
          ? 'match(${item.group.map((g) => g.card.id).join(',')})'
          : '${item.card.id}:${item.mode.name}:${item.ask.name}';

      List<String> plan(
        List<Card> cards, {
        bool voice = true,
        bool speech = true,
        bool choose = true,
      }) => lessonPlan(
        cards,
        modesOf: (c) => c.modesIn(ttsAvailable: voice, speechAvailable: speech),
        canChoose: (_, _) => choose,
      ).map(shape).toList();

      test(
        'teaches and checks each card, then asks it once more; a grammar cell '
        'is taught and typed',
        () {
          expect(plan(nine), <String>[
            'e0:recognition:teach',
            'e0:recognition:chooseMeaning',
            'e1:recognition:teach',
            'e1:recognition:chooseMeaning',
            'e2:recognition:teach',
            'e2:recognition:chooseMeaning',
            'm0:listening:teach',
            'm0:listening:hearMeaning',
            'm1:listening:teach',
            'm1:listening:hearMeaning',
            'm2:listening:teach',
            'm2:listening:hearMeaning',
            'h0:production:teach',
            'h0:production:rearrange',
            'h1:production:teach',
            'h1:production:rearrange',
            'h2:production:teach',
            'h2:production:rearrange',
            // The exercise.
            'e0:speaking:own',
            'match(m0,m1,m2)',
            'h0:speaking:own',
            'e1:speaking:own',
            'h1:speaking:own',
            'e2:speaking:own',
            'h2:speaking:own',
          ]);

          final cell = cardLesson('g', 'voy', modes: DrillMode.vocabulary);
          expect(plan(<Card>[cell]), <String>[
            'g:grammar:teach',
            'g:grammar:own',
          ]);
        },
      );

      test(
        'without a voice, a medium card is checked by choosing the word',
        () {
          final items = plan(medium, voice: false, speech: false);
          expect(items, <String>[
            'm0:production:teach',
            'm0:production:chooseWord',
            'm1:production:teach',
            'm1:production:chooseWord',
            'm2:production:teach',
            'm2:production:chooseWord',
            'match(m0,m1,m2)',
          ]);
        },
      );
    });
  });

  group('a lesson on screen', () {
    testWidgets('Today offers the lesson; it teaches each word, then asks it, '
        'and once done offers another', (tester) async {
      usePhone(tester);
      final state = spanishLearner();
      await pumpScreen(tester, const TodayPage(), state: state);
      final l10n = l10nOf(tester);
      expect(find.byType(LessonCard), findsOneWidget);
      expect(find.text(l10n.todayLessonTitle), findsOneWidget);
      expect(find.text(l10n.todayLessonWords(9)), findsOneWidget);
      // Nothing to review yet: new words come in lessons.
      expect(find.text(l10n.todayAllDoneTitle), findsOneWidget);

      final planned = <SessionItem>[
        for (final item in state.lessonFor(DrillRequest.lesson(language: 'es')))
          if (item.ask != Ask.teach)
            ...item.group.isEmpty ? <SessionItem>[item] : item.group,
      ].length;
      await tester.tap(find.text(l10n.todayLessonStart));
      await tester.pumpAndSettle();
      // The first word is taught before it is asked, and nothing is recorded.
      expect(find.byType(TeachDrill), findsOneWidget);
      expect(find.text(l10n.drillTeachTitle), findsOneWidget);
      final first = sessionOf(tester).item.card;
      expect(find.text(first.native), findsOneWidget);
      await tester.tap(find.text(l10n.commonContinue));
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceDrill), findsOneWidget);
      expect(sessionOf(tester).item.card.id, first.id);
      expect(state.progress.log, isEmpty);

      await finishLesson(tester);
      expect(find.byType(SummaryPage), findsOneWidget);
      // Nine words, each recorded in two skills but a grammar cell, which has
      // one, all right.
      final log = state.progress.log;
      expect(log.map((e) => e.cardId).toSet(), hasLength(9));
      expect(log, hasLength(planned));
      // A right choice in Hear or Write records 3, a right choice or match
      // of a meaning seen 4 (ADR-0034): every answer is right.
      expect(log.every((e) => e.grade >= 3), isTrue);
      expect(
        log
            .where((e) => e.mode == DrillMode.recognition)
            .every((e) => e.grade >= 4),
        isTrue,
      );
      expect(state.lessonDoneToday('es'), isTrue);

      // The summary offers another; back on Today, so does its card.
      expect(find.text(l10n.summaryAnotherLesson), findsOneWidget);
      Navigator.of(tester.element(find.byType(SummaryPage)))
          .popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      expect(find.text(l10n.todayLessonDoneTitle), findsOneWidget);
      expect(find.text(l10n.todayAnotherLesson), findsOneWidget);
      expect(find.text(l10n.todayNewWords(9)), findsOneWidget);
    });

    testWidgets('Start review asks the words taught in their other skills', (
      tester,
    ) async {
      usePhone(tester);
      final state = AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['es'],
        ),
        tts: FixedTtsEngine(<String>{'es'}),
      );
      await state.load();
      final lesson = state.lessonFor(DrillRequest.lesson(language: 'es'));
      final recorded = <(String, DrillMode)>{};
      for (final item in lesson) {
        if (item.ask == Ask.teach) continue;
        for (final entry
            in item.group.isEmpty ? <SessionItem>[item] : item.group) {
          state.record(entry, 5);
          recorded.add((entry.card.id, entry.mode));
        }
      }
      final review = state.buildSession(const DrillRequest.today());
      expect(review.due, isEmpty);
      expect(review.fresh, isNotEmpty);
      for (final item in review.fresh) {
        expect(state.isTaught(item.card), isTrue);
        expect(recorded, isNot(contains((item.card.id, item.mode))));
      }
    });
  });

  group('how a card is asked', () {
    group('reviewAsks', () {
      test('recognition is asked by match pairs, then choice; a sentence or a '
          'phrase is rearranged', () {
        expect(asked(recognising(10)), <String>[
          'match(r0,r1,r2,r3)',
          'r4:chooseMeaning',
          'r5:chooseMeaning',
          'r6:chooseMeaning',
          'r7:chooseMeaning',
          'r8:chooseMeaning',
          'r9:chooseMeaning',
        ]);

        final items = <SessionItem>[
          item(cardAsk('s', target: 'yo soy Ana'), DrillMode.production),
          item(
            cardAsk('p', target: 'muy bien', pos: 'phrase'),
            DrillMode.production,
          ),
          item(cardAsk('w', target: 'buenos días'), DrillMode.production),
          item(cardAsk('l', target: 'yo soy Ana'), DrillMode.listening),
        ];
        expect(asked(items), <String>[
          's:rearrange',
          'p:rearrange',
          'w:own',
          // Hearing a sentence is never rearranged: it asks the meaning.
          'l:hearMeaning',
        ]);
      });
    });

    group('Hear (ADR-0034)', () {
      final now = DateTime(2026, 10, 8, 9);
      SessionItem heard(String id, {FsrsState? state}) => SessionItem(
        card: cardAsk(id),
        mode: DrillMode.listening,
        state: state,
      );
      final remembered = Fsrs.next(null, 4, now: now);
      final missed = Fsrs.next(
        remembered,
        1,
        now: now.add(const Duration(days: 3)),
      );

      test('chooses the meaning while new or last missed, types it once '
          'remembered', () {
        expect(
          asked(<SessionItem>[
            heard('a'),
            heard('b', state: missed),
            heard('c', state: remembered),
          ]),
          <String>['a:hearMeaning', 'b:hearMeaning', 'c:own'],
        );
      });
    });
  });

  group('the drill', () {
    testWidgets('recognition: reveal, rate with the previewed interval, '
        'recorded', (tester) async {
      usePhone(tester);
      // Two good reviews, the second a week ago: due now, with an interval
      // each rating moves differently.
      final base = AppState.test();
      await base.load();
      final card = base.deckById(spanish)!.cards.first;
      final now = base.now();
      final progress = MemoryProgress();
      for (final daysAgo in <int>[8, 7]) {
        progress.record(
          deckId: spanish,
          cardId: card.id,
          mode: DrillMode.recognition,
          grade: 4,
          now: now.subtract(Duration(days: daysAgo)),
        );
      }
      // Rated, as recognition is where it cannot be chosen (ADR-0024): a
      // preset keeps each card asked its own way. Recognition is scheduled
      // (ADR-0034): the card is due, and the new words follow it.
      final state = await pumpDrill(
        tester,
        DrillRequest.untaught(spanish, skill: Skill.recognition),
        state: AppState.test(progress: progress),
        preset: DrillPreset(target: card.target),
      );
      final l10n = l10nOf(tester);
      final total = state
          .buildSession(
            DrillRequest.untaught(spanish, skill: Skill.recognition),
          )
          .length;
      expect(total, greaterThan(1));

      expect(find.text(card.target), findsOneWidget);
      expect(find.text(card.native), findsNothing);
      await tester.tap(find.text(l10n.drillShowAnswer));
      await tester.pumpAndSettle();
      expect(find.text(card.native), findsOneWidget);
      expect(find.text(l10n.drillRatePrompt), findsOneWidget);

      for (final grade in SelfGrade.values) {
        final days = progress
            .preview(card.id, DrillMode.recognition, grade.toGrade(), now: now)
            .intervalDays;
        expect(find.text(l10n.rateInterval(days)), findsWidgets);
      }
      final goodDays = progress
          .preview(card.id, DrillMode.recognition, 4, now: now)
          .intervalDays;
      expect(
        find.bySemanticsLabel(
          l10n.rateButtonSemantics(l10n.rateGood, l10n.rateInterval(goodDays)),
        ),
        findsOneWidget,
      );

      final before = progress.log.length;
      await tester.tap(find.text(l10n.rateGood));
      await tester.pumpAndSettle();
      expect(progress.log, hasLength(before + 1));
      expect(progress.log.last.cardId, card.id);
      expect(progress.log.last.grade, 4);
      expect(progress.log.last.answerGiven, isNull);
      // The next card of the review, rated in its turn.
      expect(progress.log.last.mode, DrillMode.recognition);
      expect(find.text(l10n.drillShowAnswer), findsOneWidget);
      expect(find.text(l10n.drillPositionShort(2, total)), findsOneWidget);
    });

    group('production records the right grade', () {
      final cases =
          <
            ({
              String name,
              String typed,
              String Function(AppLocalizations l10n) title,
              int grade,
            })
          >[
            (
              name: 'exact',
              typed: 'el niño',
              title: (l) => l.feedbackCorrect,
              grade: 5,
            ),
            (
              name: 'accent',
              typed: 'el nino',
              title: (l) => l.feedbackAccent,
              grade: 4,
            ),
            (
              name: 'article',
              typed: 'niño',
              title: (l) => l.feedbackArticle,
              grade: 4,
            ),
            (
              name: 'accent and article',
              typed: 'nino',
              title: (l) => l.feedbackAccentAndArticle,
              grade: 4,
            ),
            (
              name: 'wrong',
              typed: 'la mesa',
              title: (l) => l.feedbackWrong,
              grade: 1,
            ),
          ];

      testWidgets(
        'production records its grade on Check; a near miss waits for the '
        'learner to judge it',
        (tester) async {
          for (final c in cases) {
            usePhone(tester);
            final state = await pumpDrill(
              tester,
              DrillRequest.untaught(spanish, skill: Skill.production),
              preset: const DrillPreset(target: 'el niño'),
            );
            final l10n = l10nOf(tester);
            await typeAndCheck(tester, c.typed);

            expect(find.text(c.title(l10n)), findsOneWidget);
            final log = state.progress.log;
            expect(log, hasLength(1), reason: 'recorded before Continue');
            expect(log.single.grade, c.grade);
            expect(log.single.mode, DrillMode.production);
            expect(log.single.answerGiven, c.typed);

            await tester.tap(find.text(l10n.commonContinue));
            await tester.pumpAndSettle();
            expect(find.text(l10n.drillCheck), findsOneWidget);
            expect(state.progress.log, hasLength(1));
          }

          {
            for (final judgement in TypoJudgement.values) {
              usePhone(tester);
              final state = await pumpDrill(
                tester,
                DrillRequest.untaught(spanish, skill: Skill.production),
                preset: const DrillPreset(target: 'la ventana'),
              );
              final l10n = l10nOf(tester);
              await typeAndCheck(tester, 'la ventna');

              expect(
                find.text(l10n.feedbackTypo('la ventana')),
                findsOneWidget,
              );
              expect(find.text(l10n.commonContinue), findsNothing);
              expect(
                state.progress.log,
                isEmpty,
                reason: 'the learner judges it',
              );

              await tester.tap(
                find.text(
                  judgement == TypoJudgement.knewIt
                      ? l10n.drillKnewIt
                      : l10n.drillCountWrong,
                ),
              );
              await tester.pumpAndSettle();
              expect(state.progress.log.single.grade, judgement.toGrade());
              expect(
                find.text(l10n.drillCheck),
                findsOneWidget,
                reason: 'next',
              );
            }
          }
        },
      );
    });

    testWidgets('listening speaks at the speech rate, and slower, and its '
        'meaning is typed once remembered (ADR-0034)', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(<String>{'es'});
      // Heard and remembered: due, so Hear asks for the meaning to be typed.
      final base = AppState.test();
      await base.load();
      final card = base.deckById(spanish)!.cards.first;
      final progress = MemoryProgress()
        ..record(
          deckId: spanish,
          cardId: card.id,
          mode: DrillMode.listening,
          grade: 4,
          now: base.now().subtract(const Duration(days: 8)),
        );
      final state = await pumpDrill(
        tester,
        DrillRequest.deck(spanish, skill: Skill.listening),
        state: AppState.test(tts: tts, progress: progress),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.drillTypeMeaning), findsOneWidget);
      expect(find.text(l10n.drillTypeHeard), findsNothing);
      expect(find.text(card.target), findsNothing, reason: 'heard, not read');

      await tester.tap(find.byType(PlayButton));
      await tester.pumpAndSettle();
      expect(tts.spoken.single.text, card.target);
      expect(tts.spoken.single.bcp47, 'es-ES');
      expect(tts.spoken.single.rate, state.settings.ttsRate());

      await tester.tap(find.text(l10n.drillSlower(0.7)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PlayButton));
      await tester.pumpAndSettle();
      expect(tts.spoken, hasLength(2));
      expect(tts.spoken.last.rate, state.settings.ttsRate(slower: true));
      expect(tts.spoken.last.rate, lessThan(tts.spoken.first.rate));

      // The word typed as heard is not its meaning.
      final before = state.progress.log.length;
      await typeAndCheck(tester, card.native);
      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
      expect(state.progress.log, hasLength(before + 1));
      expect(state.progress.log.last.mode, DrillMode.listening);
      expect(state.progress.log.last.answerGiven, card.native);
      expect(state.progress.log.last.grade, 5);
    });

    testWidgets(
      'closing part-way asks first; a right-to-left deck types and shows '
      'right to left',
      (tester) async {
        usePhone(tester);
        final state = AppState.test();
        await pumpScreen(tester, const SizedBox.shrink(), state: state);
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => DrillPage(
              request: DrillRequest.untaught(spanish, skill: Skill.production),
              preset: const DrillPreset(target: 'el niño'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = l10nOf(tester);
        await typeAndCheck(tester, 'el nino');
        await tester.tap(find.text(l10n.commonContinue));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip(l10n.drillEndSession));
        await tester.pumpAndSettle();
        expect(find.text(l10n.drillEndTitle), findsOneWidget);
        await tester.tap(find.text(l10n.drillEndKeepGoing));
        await tester.pumpAndSettle();
        expect(find.byType(DrillPage), findsOneWidget);

        await tester.tap(find.byTooltip(l10n.drillEndSession));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, l10n.drillEndSession));
        await tester.pumpAndSettle();
        expect(find.byType(DrillPage), findsNothing);
        expect(state.progress.log.single.grade, 4, reason: 'kept');

        {
          usePhone(tester);
          final state = await pumpDrill(
            tester,
            DrillRequest.untaught(rtlFixtureDeckId, skill: Skill.production),
            state: AppState.test(decks: rtlFixtureDecks()),
            preset: const DrillPreset(target: 'کتاب'),
          );
          final field = tester.widget<TextField>(find.byType(TextField));
          expect(field.textDirection, TextDirection.rtl);

          await typeAndCheck(tester, 'کتاب');
          expect(state.progress.log.single.grade, 5);
          final shown = find.descendant(
            of: find.byType(TargetText),
            matching: find.text('کتاب'),
          );
          expect(tester.widget<Text>(shown).textDirection, TextDirection.rtl);
          expect(find.text(l10nOf(tester).feedbackCorrect), findsOneWidget);
        }
      },
    );

    group('number practice (#54)', () {
      const numbersBig = 'hi-en-numbers-big';

      /// The generated number on screen now.
      NumberCard current(WidgetTester tester) {
        final drill = tester.widget(
          find.byWidgetPredicate(
            (w) => w is RecognitionDrill || w is TypedDrill,
          ),
        );
        final session = drill is RecognitionDrill
            ? drill.session
            : (drill as TypedDrill).session;
        return session.item.card as NumberCard;
      }

      testWidgets(
        'recognition, production and listening, none of it recorded',
        (tester) async {
          usePhone(tester);
          final tts = FixedTtsEngine(<String>{'hi'});
          final state = await pumpDrill(
            tester,
            DrillRequest.numbers(numbersBig),
            state: AppState.test(tts: tts),
          );
          final l10n = l10nOf(tester);
          expect(find.text(l10n.numbersPracticeTitle), findsOneWidget);
          expect(find.text(l10n.drillPositionShort(1, 10)), findsOneWidget);

          // The words, then the digits, rated with no interval: nothing is
          // scheduled.
          var card = current(tester);
          expect(find.text(card.target), findsOneWidget);
          await tester.tap(find.text(l10n.drillShowAnswer));
          await tester.pumpAndSettle();
          expect(find.text(card.native), findsOneWidget);
          expect(find.bySemanticsLabel(l10n.rateGood), findsOneWidget);
          for (final days in <int>[0, 1, 4]) {
            expect(find.text(l10n.rateInterval(days)), findsNothing);
          }
          await tester.tap(find.text(l10n.rateGood));
          await tester.pumpAndSettle();

          // The digits; the words typed, in their other accepted spelling.
          card = current(tester);
          expect(find.text(card.native), findsOneWidget);
          await typeAndCheck(tester, card.altTarget.firstOrNull ?? card.target);
          expect(find.text(l10n.feedbackCorrect), findsOneWidget);
          await tester.tap(find.text(l10n.commonContinue));
          await tester.pumpAndSettle();

          // Heard as words; typed as digits, a comma allowed.
          card = current(tester);
          expect(find.text(l10n.numbersTypeDigits), findsOneWidget);
          await tester.tap(find.byType(PlayButton));
          await tester.pumpAndSettle();
          expect(tts.spoken.single.text, card.target);
          final n = card.number;
          await typeAndCheck(
            tester,
            '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}',
          );
          expect(find.text(l10n.feedbackCorrect), findsOneWidget);

          expect(state.progress.log, isEmpty);
        },
      );
    });
  });

  group('choice, match and rearrange', () {
    group('multiple choice', () {
      testWidgets(
        'the right meaning records 4; a wrong one records 1 and shows the '
        'answer',
        (tester) async {
          usePhone(tester);
          final state = await pumpAsked(
            tester,
            deck: spanish,
            skill: Skill.recognition,
            target: 'la casa',
            ask: Ask.chooseMeaning,
          );
          final l10n = l10nOf(tester);
          final card = cardOf(state, spanish, 'la casa');
          expect(find.byType(ChoiceDrill), findsOneWidget);
          expect(find.text(l10n.drillChooseMeaning), findsOneWidget);
          // Four options, each a different meaning, the card's among them.
          final options = find.descendant(
            of: find.bySemanticsLabel(l10n.drillOptionsGroup),
            matching: find.byType(InkWell),
          );
          expect(options, findsNWidgets(4));

          await tapText(tester, card.native);
          final event = state.progress.log.single;
          expect(event.cardId, card.id);
          expect(event.mode, DrillMode.recognition);
          expect(event.grade, 4);
          expect(find.text(l10n.feedbackCorrect), findsOneWidget);
          await tapText(tester, l10n.commonContinue);
          expect(find.byType(ChoiceDrill), findsNothing);

          {
            usePhone(tester);
            final state = await pumpAsked(
              tester,
              deck: spanish,
              skill: Skill.recognition,
              target: 'la casa',
              ask: Ask.chooseMeaning,
            );
            final l10n = l10nOf(tester);
            final card = cardOf(state, spanish, 'la casa');
            final session = tester.widget<ChoiceDrill>(
              find.byType(ChoiceDrill),
            );
            final wrong = session.session.options.firstWhere(
              (o) => o.id != card.id,
            );
            await tapText(tester, wrong.native);
            expect(state.progress.log.single.grade, 1);
            expect(find.text(l10n.feedbackWrong), findsOneWidget);
            expect(find.text(l10n.feedbackAnswer(card.native)), findsOneWidget);
          }
        },
      );
    });

    group('match pairs', () {
      testWidgets('a word is matched to its meaning by a tap, or by dragging', (
        tester,
      ) async {
        usePhone(tester);
        final (state, _) = await pumpMatch(
          tester,
          deck: spanish,
          target: 'la casa',
        );
        final l10n = l10nOf(tester);
        final drill = tester.widget<MatchDrill>(find.byType(MatchDrill));
        final group = drill.session.item.group;
        expect(group, hasLength(matchSize));
        expect(find.text(l10n.drillMatchPrompt), findsOneWidget);

        // A wrong pair first: nothing recorded, the word marked missed.
        await tapText(tester, group[0].card.target);
        await tapText(tester, group[1].card.native);
        expect(state.progress.log, isEmpty);
        expect(drill.session.wasMissed(group[0]), isTrue);

        // Meaning first, then word, works too.
        for (final entry in group) {
          await tapText(tester, entry.card.native);
          await tapText(tester, entry.card.target);
        }
        final grades = <String, int>{
          for (final e in state.progress.log) e.cardId: e.grade,
        };
        expect(state.progress.log, hasLength(matchSize));
        expect(state.progress.log.map((e) => e.mode).toSet(), <DrillMode>{
          DrillMode.recognition,
        });
        expect(grades[group[0].card.id], 1);
        for (final entry in group.skip(1)) {
          expect(grades[entry.card.id], 4);
        }
        expect(find.text(l10n.drillMatchAgain(1)), findsOneWidget);
        await tapText(tester, l10n.commonContinue);
        expect(find.byType(MatchDrill), findsNothing);

        {
          usePhone(tester);
          final (state, _) = await pumpMatch(
            tester,
            deck: spanish,
            target: 'la casa',
          );
          final card = cardOf(state, spanish, 'la casa');
          final word = find.text(card.target);
          final meaning = find.text(card.native);
          await tester.ensureVisible(word);
          await tester.pumpAndSettle();
          final gesture = await tester.startGesture(tester.getCenter(word));
          await tester.pump();
          await gesture.moveTo(tester.getCenter(meaning));
          await tester.pump();
          await gesture.up();
          await tester.pumpAndSettle();
          final event = state.progress.log.single;
          expect(event.cardId, card.id);
          expect(event.grade, 4);
        }
      });
    });

    group('rearrange', () {
      testWidgets('the words put in order record 5; the wrong order records 1', (
        tester,
      ) async {
        usePhone(tester);
        final state = await pumpAsked(
          tester,
          deck: hindi,
          skill: Skill.production,
          target: 'आप कैसे हैं?',
          ask: Ask.rearrange,
        );
        final l10n = l10nOf(tester);
        final card = cardOf(state, hindi, 'आप कैसे हैं?');
        expect(find.byType(RearrangeDrill), findsOneWidget);
        expect(find.text(card.native), findsOneWidget);
        // Before the script units, the words come in Latin letters.
        final words = tilesOf(card.reading!);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, l10n.drillCheck),
              )
              .onPressed,
          isNull,
        );
        for (final word in words) {
          await tapText(tester, word);
        }
        await tapText(tester, l10n.drillCheck);
        final event = state.progress.log.single;
        expect(event.mode, DrillMode.production);
        expect(event.grade, 5);
        expect(find.text(l10n.feedbackCorrect), findsOneWidget);

        {
          usePhone(tester);
          final state = await pumpAsked(
            tester,
            deck: spanish,
            skill: Skill.production,
            target: 'la casa',
            ask: Ask.rearrange,
          );
          final l10n = l10nOf(tester);
          Finder placed(String word) => find.descendant(
            of: find.byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  w.properties.label == l10n.drillRearrangeAnswer,
            ),
            matching: find.text(word),
          );
          await tapText(tester, 'la');
          expect(placed('la'), findsOneWidget);
          // Its place among the words to place is kept, so the others stay put.
          expect(find.text('la'), findsNWidgets(2));
          await tester.tap(placed('la'));
          await tester.pumpAndSettle();
          expect(placed('la'), findsNothing);
          await tapText(tester, 'casa');
          await tapText(tester, 'la');
          await tapText(tester, l10n.drillCheck);
          expect(state.progress.log.single.grade, 1);
          expect(find.text(l10n.feedbackAnswer('la casa')), findsOneWidget);
        }
      });
    });
  });

  group('confusables', () {
    test('a card whose confusables name three cards is offered exactly those '
        'as wrong options', () async {
      final state = AppState.test(
        decks: MemoryDeckSource(const <String, String>{
          'decks/zz/zz-curated.yaml': core,
          'decks/zz/en/zz-en-curated.yaml': layer,
        }),
      );
      addTearDown(state.dispose);
      await state.load();
      final card = state
          .deckById('zz-en-curated')!
          .cards
          .firstWhere((c) => c.id == 'zz-8001');
      // The pool alone would also offer the cat and the dog.
      expect(state.choicePool(card, Ask.chooseMeaning), hasLength(5));
      for (var seed = 0; seed < 8; seed++) {
        final session = DrillSession(
          state: state,
          items: <SessionItem>[
            SessionItem(
              card: card,
              mode: DrillMode.recognition,
              state: null,
              ask: Ask.chooseMeaning,
            ),
          ],
          random: Random(seed),
        );
        addTearDown(session.dispose);
        expect(session.options, hasLength(DrillSession.optionCount));
        expect(
          session.options.map((c) => c.id),
          unorderedEquals(<String>['zz-8001', 'zz-8002', 'zz-8003', 'zz-8004']),
        );
      }
    });
  });

  group('Hear', () {
    group('a Hear choice', () {
      testWidgets(
        'a new word heard has its meaning chosen; typed, a part of the meaning '
        'is accepted',
        (tester) async {
          usePhone(tester);
          final tts = FixedTtsEngine(const <String>{'es'});
          final state = await pumpScreen(
            tester,
            DrillPage(
              request: DrillRequest.untaught(
                spanishHear,
                skill: Skill.listening,
              ),
            ),
            state: AppState.test(decks: fixtureDecks(), tts: tts),
          );
          final l10n = l10nOf(tester);
          expect(find.byType(ChoiceDrill), findsOneWidget);
          final session = tester
              .widget<ChoiceDrill>(find.byType(ChoiceDrill))
              .session;
          final card = session.item.card;
          expect(session.ask, Ask.hearMeaning);
          expect(session.item.mode, DrillMode.listening);
          expect(find.text(l10n.drillChooseHeardMeaning), findsOneWidget);
          // The options are meanings; the word is not given away.
          expect(session.options, hasLength(DrillSession.optionCount));
          for (final option in session.options) {
            expect(find.text(option.native), findsOneWidget);
            expect(find.text(option.target), findsNothing);
          }
          await tester.tap(find.byType(PlayButton));
          await tester.pumpAndSettle();
          expect(tts.spoken.last.text, card.target);

          await tapText(tester, card.native);
          final event = state.progress.log.single;
          expect(event.cardId, card.id);
          expect(event.mode, DrillMode.listening);
          expect(event.grade, DrillSession.scheduledChoiceGrade);
          expect(event.grade, 3);
          expect(event.answerGiven, card.native);
          expect(find.text(l10n.feedbackCorrect), findsOneWidget);
          // Now the word is shown with its meaning.
          expect(find.text(card.target), findsOneWidget);

          {
            usePhone(tester);
            final state = await pumpTyped(tester, 'ir');
            final l10n = l10nOf(tester);
            final session = tester
                .widget<TypedDrill>(find.byType(TypedDrill))
                .session;
            expect(session.hearsMeaning, isTrue);
            expect(find.text(l10n.drillTypeMeaning), findsOneWidget);
            // Each part of "to go, to leave" is the meaning.
            expect(
              session.acceptedAnswers,
              containsAll(<String>['to go', 'to leave']),
            );

            await typeAndCheckHear(tester, 'to leave');
            expect(find.text(l10n.feedbackCorrect), findsOneWidget);
            final event = state.progress.log.single;
            expect(event.mode, DrillMode.listening);
            expect(event.grade, greaterThanOrEqualTo(4));
          }
        },
      );
    });

    group('script practice', () {
      testWidgets('a card is typed as heard, in the script', (tester) async {
        usePhone(tester);
        final card = (await () async {
          final s = AppState.test();
          await s.load();
          return s.deckById(script)!.cards.firstWhere((c) => c.reading != null);
        }());
        final state = await pumpScreen(
          tester,
          DrillPage(
            request: DrillRequest.untaught(script, skill: Skill.listening),
            preset: DrillPreset(target: card.target),
          ),
          state: AppState.test(tts: FixedTtsEngine(const <String>{'hi'})),
        );
        final l10n = l10nOf(tester);
        final session = tester
            .widget<TypedDrill>(find.byType(TypedDrill))
            .session;
        expect(session.hearsMeaning, isFalse);
        expect(session.acceptedAnswers.first, card.target);
        expect(find.text(l10n.drillTypeHeard), findsOneWidget);
        expect(find.text(l10n.drillTypeMeaning), findsNothing);

        await typeAndCheckHear(tester, card.target);
        expect(find.text(l10n.feedbackCorrect), findsOneWidget);
        expect(state.progress.log.single.mode, DrillMode.listening);
        expect(state.progress.log.single.grade, 5);
      });
    });
  });

  group('the IPA line', () {
    testWidgets(
      'the IPA shows on recognition from the start, and never before the '
      'answer when listening',
      (tester) async {
        usePhone(tester);
        await pumpDrillIpaLine(
          tester,
          DrillRequest.untaught(spanish, skill: Skill.recognition),
          preset: const DrillPreset(target: 'la ventana'),
        );
        expect(ipaLine(ventana), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(IpaLine)).label,
          l10nOf(tester).ipaSemantics('la benˈtana'),
        );

        usePhone(tester);
        await pumpDrillIpaLine(
          tester,
          DrillRequest.untaught(spanish, skill: Skill.listening),
          preset: const DrillPreset(target: 'la ventana'),
        );
        expect(find.byType(IpaLine), findsNothing);
      },
    );
  });

  group('speaking', () {
    testWidgets(
      'a word heard right says so; a wrong one says what was heard and the '
      'answer',
      (tester) async {
        usePhone(tester);
        final handle = tester.ensureSemantics();
        final speech = FixedSpeechEngine(onDevice: <String>{'es'});
        final state = await pumpSpeaking(tester, speech);
        final l10n = l10nOf(tester);
        expect(find.byType(SpeakingDrill), findsOneWidget);
        final card = state
            .buildSession(DrillRequest.untaught(spanish, skill: Skill.speaking))
            .items
            .first
            .card;
        expect(find.text(l10n.drillSayIn('Spanish')), findsOneWidget);
        expect(find.text(card.native), findsOneWidget);

        speech.next = <SpeechAlternative>[SpeechAlternative(card.target)];
        await speak(tester);
        expect(find.text(l10n.feedbackCorrect), findsOneWidget);
        expect(state.progress.log.single.mode, DrillMode.speaking);
        expect(speech.listens.single.onDevice, isTrue);
        handle.dispose();

        {
          usePhone(tester);
          final handle = tester.ensureSemantics();
          final speech = FixedSpeechEngine(onDevice: <String>{'es'});
          final state = await pumpSpeaking(tester, speech);
          final l10n = l10nOf(tester);
          final card = state
              .buildSession(
                DrillRequest.untaught(spanish, skill: Skill.speaking),
              )
              .items
              .first
              .card;
          speech.next = const <SpeechAlternative>[
            SpeechAlternative('el perro'),
          ];
          await speak(tester);
          expect(find.text(l10n.feedbackWrong), findsOneWidget);
          expect(
            find.text(l10n.feedbackSaidAnswer('el perro', card.target)),
            findsOneWidget,
          );
          expect(state.progress.log.single.grade, 1);
          handle.dispose();
        }
      },
    );

    testWidgets('nothing heard asks again and records nothing', (tester) async {
      usePhone(tester);
      final handle = tester.ensureSemantics();
      final speech = FixedSpeechEngine(onDevice: <String>{'es'});
      final state = await pumpSpeaking(tester, speech);
      final l10n = l10nOf(tester);
      await speak(tester);
      expect(find.text(l10n.drillUnheardNoMatch), findsOneWidget);
      expect(state.progress.log, isEmpty);
      handle.dispose();
    });
  });

  group('try again and Hear yourself', () {
    setUp(_played.clear);

    group('the session', () {
      late AppState state;
      late FixedSpeechEngine speech;

      Future<DrillSession> session({
        SoundCheckEngine? soundCheck,
        TtsEngine? tts,
        FixedSpeechEngine? recogniser,
        bool Function(SessionItem item)? where,
      }) async {
        speech = recogniser ?? FixedSpeechEngine(onDevice: <String>{'es'});
        state = _state(speech, soundCheck: soundCheck, tts: tts);
        await state.load();
        await state.startSpeech();
        final items = state
            .buildSession(DrillRequest.untaught(spanish, skill: Skill.speaking))
            .items
            .where(where ?? (_) => true)
            .toList();
        final s = DrillSession(state: state, items: items);
        addTearDown(s.dispose);
        addTearDown(state.dispose);
        return s;
      }

      test('a wrong answer offers a try again, and only a failed first answer '
          'brings the word back', () async {
        final s = await session();
        final target = s.item.card.target;
        speech.next = const <SpeechAlternative>[SpeechAlternative('el perro')];
        await s.listen();
        expect(s.answer!.grade, 1);
        expect(s.canRetry, isTrue);
        expect(s.retried, isNull);

        speech.next = <SpeechAlternative>[SpeechAlternative(target)];
        await s.retry();
        expect(s.retried!.graded!.outcome, AnswerOutcome.exact);
        expect(s.retries, 1);
        // The first answer counts: one review, failed, so the word comes
        // back sooner.
        expect(state.progress.log.single.grade, 1);
        expect(state.progress.log.single.answerGiven, 'el perro');
        expect(s.answer!.typed, 'el perro');
        // As often as the learner likes.
        expect(s.canRetry, isTrue);
        speech.next = const <SpeechAlternative>[SpeechAlternative('el gato')];
        await s.retry();
        expect(s.retried!.graded!.outcome, AnswerOutcome.wrong);
        expect(s.retries, 2);
        expect(state.progress.log, hasLength(1));
        expect(speech.listens, hasLength(3));

        {
          var s = await session();
          speech.next = const <SpeechAlternative>[
            SpeechAlternative('el perro'),
          ];
          await s.listen();
          expect(s.firstTryFailed, isTrue);

          s = await session();
          s.dontKnow();
          expect(s.firstTryFailed, isTrue);

          s = await session(
            where: (item) => _unaccented(item.card.target) != item.card.target,
          );
          speech.next = <SpeechAlternative>[
            SpeechAlternative(_unaccented(s.item.card.target)),
          ];
          await s.listen();
          expect(s.answer!.grade, 4);
          // Recorded as a pass: a try again changes nothing, sooner or later.
          expect(s.firstTryFailed, isFalse);
          speech.next = <SpeechAlternative>[
            SpeechAlternative(s.item.card.target),
          ];
          await s.retry();
          expect(s.retried!.graded!.outcome, AnswerOutcome.exact);
          expect(s.firstTryFailed, isFalse);
          expect(state.progress.log.single.grade, 4);
        }
      });

      test('Hear yourself records, plays the recording, then the voice, and '
          'records nothing in the log', () async {
        final sound = _OrderedSoundCheck();
        final s = await session(soundCheck: sound);
        final target = s.item.card.target;
        expect(s.canHearSelf, isFalse);
        speech.next = <SpeechAlternative>[SpeechAlternative(target)];
        await s.listen();
        expect(s.canHearSelf, isTrue);
        _played.clear();
        await s.hearSelf();
        expect(sound.recordings, 1);
        expect(sound.playbacks, 1);
        expect(_played, <String>['self', 'voice $target']);
        expect(s.hearingSelf, SelfTake.idle);
        expect(s.selfFailure, isNull);
        expect(state.progress.log, hasLength(1));
      });
    });
  });

  group('grammar questions', () {
    final now = DateTime(2026, 10, 9, 18);
    final cells = cellsOf();
    // అమ్మతో (ammatō), "with mother", among అమ్మలో, అమ్మకి, అమ్మ నుంచి.
    final withMother = cell(cells, '9004-2');

    group('the meaning question, Ask.chooseFormMeaning (4.8, 1)', () {
      test('the meaning question shows the form and asks its meaning; the form '
          'question shows the meaning and offers the row\'s forms', () {
        expect(
          withMother.promptFor(DrillMode.grammarUnderstood),
          'అమ్మతో (ammatō)',
        );
        expect(withMother.acceptedAnswers(DrillMode.grammarUnderstood), [
          'with mother',
        ]);
        expect(Ask.chooseFormMeaning.chooses, isTrue);
        expect(Ask.chooseFormMeaning.choosesMeaning, isTrue);
        expect(Ask.chooseFormMeaning.optionOf(withMother), 'with mother');

        expect(
          withMother.promptFor(DrillMode.grammar),
          'అమ్మ (amma): with mother',
        );
        expect(Ask.chooseForm.chooses, isTrue);
        expect(Ask.chooseForm.choosesMeaning, isFalse);
        final options = formChoices(withMother, Ask.chooseForm, cells);
        expect(options.map((c) => c.target), [
          'అమ్మలో',
          'అమ్మకి',
          'అమ్మ నుంచి',
        ]);
        expect(options.map((c) => c.reading), [
          'ammalō',
          'ammaki',
          'amma nuñci',
        ]);
      });
    });

    group('lessons (4.8, 5)', () {
      test('a cell is understood, then produced, and the Grammar switch covers '
          'both', () async {
        expect(lessonQuestions(withMother), [
          (mode: DrillMode.grammarUnderstood, ask: Ask.chooseFormMeaning),
          (mode: DrillMode.grammar, ask: Ask.chooseForm),
        ]);
        final plan = lessonPlan(
          [withMother],
          modesOf: (c) => c.modesIn(ttsAvailable: false),
          canChoose: (card, ask) =>
              formChoices(card, ask, cells).isNotEmpty ||
              !ask.choosesAmongForms,
        );
        expect(plan.map((i) => (i.mode, i.ask)), [
          (DrillMode.grammarUnderstood, Ask.teach),
          (DrillMode.grammarUnderstood, Ask.chooseFormMeaning),
          (DrillMode.grammar, Ask.chooseForm),
        ]);

        {
          Future<AppState> loaded({SettingsNotifier? settings}) async {
            final state = AppState.test(
              decks: MemoryDeckSource(appendixFiles()),
              progress: MemoryProgress(),
              settings: settings,
              now: now,
            );
            await state.load();
            return state;
          }

          final settings = SettingsNotifier();
          final state = await loaded(settings: settings);
          expect(
            state.sessionModes,
            containsAll(<DrillMode>[
              DrillMode.grammarUnderstood,
              DrillMode.grammar,
            ]),
          );
          settings.setSkillEnabled(Skill.grammar, false);
          expect(
            state.sessionModes,
            isNot(contains(DrillMode.grammarUnderstood)),
          );
          expect(state.sessionModes, isNot(contains(DrillMode.grammar)));
          expect(
            state.sessionItems(
              const DrillRequest(deckIds: {rulesDeck}, untaught: true),
            ),
            isEmpty,
          );
        }
      });
    });

    group('the log replays as it is', () {
      test('an old grammar answer stays grammar', () {
        final id = 'te-grammar-case-endings-0042-1';
        final old = [
          review(id, DrillMode.grammar, now, 4),
          review(id, DrillMode.grammar, now.add(const Duration(days: 3)), 3),
        ];
        final text = LogJsonl.encode([
          for (final r in old)
            (
              deckId: 'te-en-grammar',
              at: r.at,
              grade: r.grade,
              elapsed: r.elapsed,
              answerGiven: r.answerGiven,
              script: null,
              asked: null,
              key: r.key,
            ),
        ], const []);
        expect(text, contains('"grammar"'));
        expect(text, isNot(contains('grammarUnderstood')));
        final decoded = LogJsonl.decode(text).reviews;
        expect(decoded.map((r) => r.key.mode), everyElement(DrillMode.grammar));
        final replayed = replayReviews(decoded, skills: const SkillMap());
        expect(replayed.states.keys, [(cardId: id, mode: DrillMode.grammar)]);
        expect(
          replayed.events.map((e) => e.mode),
          everyElement(DrillMode.grammar),
        );
      });
    });
  });

  group('the grammar drill', () {
    group('grammar drill', () {
      testWidgets(
        'asks a cell; a wrong answer shows the table with the cell marked',
        (tester) async {
          usePhone(tester);
          await pumpScreen(tester, const GrammarDrill(), state: grammarOn());
          final l10n = l10nOf(tester);
          expect(find.text('hablar (to speak) — vosotros'), findsOneWidget);
          expect(find.text(l10n.drillTypeSlot('vosotros')), findsOneWidget);
          expect(find.text(l10n.drillPositionShort(1, 3)), findsOneWidget);
          expect(find.text('hablo'), findsNothing, reason: 'no table yet');
          expect(find.byType(IncomingFeature), findsNothing);

          {
            usePhone(tester);
            final semantics = tester.ensureSemantics();
            final pattern = await realPattern();
            await pumpScreen(tester, const GrammarDrill(), state: grammarOn());
            await typeAndCheck(tester, 'hablamos');
            final l10n = l10nOf(tester);

            expect(banner(tester).kind, FeedbackKind.wrong);
            expect(banner(tester).title, l10n.feedbackWrong);
            expect(banner(tester).detail, l10n.feedbackAnswer('habláis'));

            final row = findGrammarCell(
              pattern,
              lemma: 'hablar',
              slot: 'yo',
            )!.table;
            for (final cell in row) {
              // The asked slot is in the chip too.
              expect(find.text(cell.slot), findsWidgets);
              expect(find.text(cell.form!), findsOneWidget);
              final node = tester.getSemantics(find.text(cell.form!));
              if (cell.slot == 'vosotros') {
                expect(node, isSemantics(isSelected: true));
              } else {
                expect(node, isNot(isSemantics(isSelected: true)));
              }
            }
            expect(find.text(pattern.notes!), findsOneWidget);
            semantics.dispose();
          }
        },
      );
    });

    testWidgets('live: a session card is graded, recorded, and shows its table '
        'and notes', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(
            grammarFixtureDeckId,
            skill: Skill.grammar,
          ),
        ),
        state: AppState.test(),
      );
      final l10n = l10nOf(tester);
      final pattern = state.deckById(grammarFixtureDeckId)!.deck.pattern!;
      expect(find.byType(GrammarDrill), findsOneWidget);
      // The first new cell in deck order: hablar, yo.
      expect(find.text('hablar (to speak) — yo'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hablo');
      await tester.pump();
      await tester.tap(find.text(l10n.drillCheck));
      await tester.pumpAndSettle();

      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
      expect(find.text('hablas'), findsOneWidget, reason: 'the whole table');
      expect(find.text(pattern.notes!), findsOneWidget);
      final review = state.progress.log.single;
      expect(review.mode, DrillMode.grammar);
      expect(review.cardId, 'es-grammar-present-ar-hablar-0');
      expect(review.answerGiven, 'hablo');
      expect(review.grade, greaterThanOrEqualTo(4));
    });
  });

  group('minimal pairs', () {
    testWidgets(
      'Play speaks the sound asked; choosing it says so, with the contrast',
      (tester) async {
        usePhone(tester);
        final tts = FixedTtsEngine(const <String>{'hi'});
        final state = await pumpScreen(
          tester,
          const PairDrill(),
          state: pairOn(tts),
        );
        expect(pairFixtureRounds.first.heard, first.b);

        await tester.tap(find.byType(PlayButton));
        await tester.pumpAndSettle();
        expect(tts.spoken, hasLength(1));
        expect(tts.spoken.single.text, first.b.target);
        expect(tts.spoken.single.bcp47, pairFixtureLanguage.ttsTag);
        expect(tts.spoken.single.rate, state.settings.ttsRate());

        usePhone(tester);
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester, const PairDrill(), state: pairOn());
        final l10n = l10nOf(tester);
        expect(find.text(l10n.drillPairQuestion), findsOneWidget);
        for (final sound in <PairSound>[first.a, first.b]) {
          expect(find.text(sound.reading), findsOneWidget);
          expect(
            find.bySemanticsLabel(
              l10n.drillPairOption(sound.target, sound.reading),
            ),
            findsOneWidget,
          );
        }
        expect(find.text(first.contrast), findsNothing);

        await choose(tester, first.b);
        expect(banner(tester).kind, FeedbackKind.correct);
        expect(banner(tester).title, l10n.feedbackPairCorrect(first.b.reading));
        expect(banner(tester).detail, l10n.feedbackPairHeard(first.b.target));
        expect(find.text(first.contrast), findsOneWidget);
        final options = tester.widgetList<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        expect(options, hasLength(2));
        expect(options.every((b) => b.onPressed == null), isTrue);

        await tester.tap(find.text(l10n.commonContinue));
        await tester.pumpAndSettle();
        expect(find.text(l10n.drillPositionShort(2, 2)), findsOneWidget);
        expect(find.text(pairFixtureRounds[1].pair.a.target), findsOneWidget);
        expect(find.byType(FeedbackBanner), findsNothing);
        semantics.dispose();
      },
    );
  });

  group('reading', () {
    group('read', () {
      testWidgets(
        'a passage shows on its own, then its questions; a choice is recorded '
        'at once',
        (tester) async {
          usePhone(tester);
          final tts = FixedTtsEngine(<String>{'bn'});
          final state = readingApp(tts: tts);
          await pumpScreen(
            tester,
            DrillPage(request: readReadingDrill),
            state: state,
          );
          final l10n = l10nOf(tester);
          expect(find.byType(ReadingDrill), findsOneWidget);
          expect(find.text('At the shop'), findsOneWidget);
          expect(find.text(l10n.readingIntro(3)), findsOneWidget);
          for (final sentence in shop) {
            expect(find.text(sentence), findsOneWidget);
          }
          expect(find.text('nomoshkar. koto dam?'), findsOneWidget);
          expectOnScreen(
            tester,
            find.text(l10n.readingSource(readingFixtureSource)),
          );
          expect(find.byTooltip(l10n.readingPlaySentence), findsNWidgets(4));
          // No question yet.
          expect(find.text('What does the buyer ask first?'), findsNothing);

          await tester.tap(find.byTooltip(l10n.readingPlaySentence).at(1));
          await tester.pumpAndSettle();
          expect(tts.spoken.single.text, shop[1]);
          expect(tts.spoken.single.bcp47, 'bn-IN');

          state.settings.showRomanisation = false;
          await tester.pumpAndSettle();
          expect(find.text('nomoshkar. koto dam?'), findsNothing);

          await tapTextReadingDrill(tester, l10n.readingToQuestions);
          expect(find.text('What does the buyer ask first?'), findsOneWidget);
          for (final choice in ['The price', 'The way', 'The time']) {
            expect(find.text(choice), findsOneWidget);
          }
          // The passage is under the choices, to look back at.
          expect(find.text(l10n.readingPassage), findsOneWidget);
          expect(find.text(shop.first), findsOneWidget);
          expect(state.progress.log, isEmpty);

          {
            usePhone(tester);
            final state = readingApp();
            await pumpScreen(
              tester,
              DrillPage(request: readReadingDrill),
              state: state,
            );
            final l10n = l10nOf(tester);
            await tapTextReadingDrill(tester, l10n.readingToQuestions);

            await tapTextReadingDrill(tester, 'The price');
            final right = state.progress.log.single;
            expect(right.deckId, readingFixtureDeckId);
            expect(right.cardId, 'bn-en-fixture-reading-shop-q1');
            expect(right.mode, DrillMode.reading);
            expect(right.grade, ReadingQuestion.rightGrade);
            expect(right.answerGiven, '1');
            expect(find.text(l10n.feedbackCorrect), findsOneWidget);
            expect(find.text(l10n.feedbackAnswer('The price')), findsOneWidget);
            // Choosing again changes nothing.
            await tester.tap(find.text('The way'));
            await tester.pumpAndSettle();
            expect(state.progress.log, hasLength(1));

            // The next question about the same passage follows at once.
            await tapTextReadingDrill(tester, l10n.commonContinue);
            expect(find.text(l10n.readingToQuestions), findsNothing);
            expect(find.text(l10n.readingTrueOrFalse), findsOneWidget);
            expect(
              find.text('The buyer asks for a lower price.'),
              findsOneWidget,
            );
            await tapTextReadingDrill(tester, l10n.readingFalse);
            final wrong = state.progress.log.last;
            expect(wrong.cardId, 'bn-en-fixture-reading-shop-q2');
            expect(wrong.grade, ReadingQuestion.wrongGrade);
            expect(wrong.answerGiven, 'false');
            expect(find.text(l10n.feedbackWrong), findsOneWidget);
            expect(
              find.text(l10n.feedbackAnswer(l10n.readingTrue)),
              findsOneWidget,
            );

            await tapTextReadingDrill(tester, l10n.commonContinue);
            await tapTextReadingDrill(tester, 'Fifty taka');
            await tapTextReadingDrill(tester, l10n.commonContinue);
            // The next passage shows on its own first.
            expect(find.text('Going home'), findsOneWidget);
            expect(find.text(l10n.readingToQuestions), findsOneWidget);
            expect(find.text(home), findsOneWidget);
          }
        },
      );

      testWidgets('Words opens the glossary: the word as written, today\'s '
          'form, its reading with romanisation on, and its meaning', (
        tester,
      ) async {
        usePhone(tester);
        final state = readingApp();
        await pumpScreen(
          tester,
          DrillPage(
            request: readReadingDrill,
            preset: const DrillPreset(target: home),
          ),
          state: state,
        );
        final l10n = l10nOf(tester);
        expect(find.text(home), findsOneWidget);
        await tapTextReadingDrill(tester, l10n.readingWords);
        expect(find.text(l10n.readingWordsTitle), findsOneWidget);
        final glossary = find.byType(Glossary);
        for (final text in <String>['ক’রে', 'করে']) {
          final shown = find.descendant(
            of: glossary,
            matching: find.text(text),
          );
          expect(shown, findsOneWidget);
          expect(
            find.ancestor(of: shown, matching: find.byType(TargetText)),
            findsOneWidget,
          );
        }
        expect(find.text('kore'), findsOneWidget);
        expect(find.text('having done'), findsOneWidget);
        // A word written the same today shows once, with no arrow to itself.
        expect(
          find.descendant(of: glossary, matching: find.text('বাড়িতে')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: glossary,
            matching: find.byIcon(Icons.arrow_forward),
          ),
          findsOneWidget,
        );
        expect(
          find.text('older spelling; the apostrophe marks a dropped ই'),
          findsOneWidget,
        );
        state.settings.showRomanisation = false;
        await tester.pumpAndSettle();
        expect(find.text('kore'), findsNothing);
        // Behind the sheet, Words stays by the passage, to open it again.
        expect(
          find.descendant(
            of: find.byType(ReadingDrill),
            matching: find.text(l10n.readingWords),
          ),
          findsOneWidget,
        );
      });
    });

    group('heard', () {
      testWidgets('the passage is read aloud, its text hidden until the '
          'question is answered', (tester) async {
        usePhone(tester);
        final tts = FixedTtsEngine(<String>{'bn'});
        final state = readingApp(tts: tts);
        await pumpScreen(tester, DrillPage(request: heard), state: state);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.readingListenIntro(3)), findsOneWidget);
        expect(find.text(l10n.readingTextHidden), findsOneWidget);
        for (final sentence in shop) {
          expect(find.text(sentence), findsNothing);
        }
        expect(find.text('nomoshkar. koto dam?'), findsNothing);
        expect(find.text(l10n.drillCantListen), findsOneWidget);

        await tester.tap(find.byType(PlayButton));
        await tester.pumpAndSettle();
        expect(tts.spoken.map((s) => s.text), shop);

        await tapTextReadingDrill(tester, l10n.readingToQuestions);
        expect(find.byType(PlayButton), findsOneWidget);
        for (final sentence in shop) {
          expect(find.text(sentence), findsNothing);
        }
        await tapTextReadingDrill(tester, 'The price');
        expect(state.progress.log.single.mode, DrillMode.listening);
        for (final sentence in shop) {
          expect(find.text(sentence), findsOneWidget);
        }
        expect(find.text(l10n.readingTextHidden), findsNothing);

        // Hidden again for the next question.
        await tapTextReadingDrill(tester, l10n.commonContinue);
        for (final sentence in shop) {
          expect(find.text(sentence), findsNothing);
        }
      });
    });
  });

  group('sets', () {
    group('the deck format', () {
      test(
        'a set card is read into the deck\'s sets, its layer giving its name '
        'and explanation',
        () {
          final deck = mergeLayer(
            DeckParser.parseCore(coreWith(refSet + ruleSets), source: 'c.yaml'),
            DeckParser.parseLayer(layerWith(texts), source: 'l.yaml'),
            source: 'l.yaml',
          );
          expect(deck.cards.map((c) => c.id), isNot(contains('zz-9201')));
          expect(deck.sets.map((s) => s.id), ['zz-9201', 'zz-9202', 'zz-9203']);
          final words = deck.sets.first;
          expect(words.name, 'Three first words');
          expect(words.explanation, 'Three words you meet first.');
          expect(words.members, ['zz-9001', 'zz-9004', 'zz-9006']);
          expect(words.rule, isNull);
          final noun = deck.sets[1].rule!;
          expect(
            (noun.rule, noun.axis, noun.value, noun.fixesRow),
            ('zz-grammar-case-endings', 'noun', 'అమ్మ', true),
          );
          expect(deck.sets[2].rule!.fixesRow, isFalse);
          expect(deck.sets[2].shown, ['zz-9004', 'zz-9001']);
          expect(deck.sets[1].shown, isEmpty);
          // A deck's set survives its cards being replaced, as refs resolve.
          expect(deck.withCards(const <Card>[]).sets, hasLength(3));

          final core = DeckParser.parseCore(coreWith(refSet), source: 'c.yaml');
          expect(
            () => mergeLayer(
              core,
              DeckParser.parseLayer(
                homeLayer.replaceFirst(
                  'cards:\n',
                  'cards:\n  "zz-9201":\n    native: "Words"\n',
                ),
                source: 'l.yaml',
              ),
              source: 'l.yaml',
            ),
            fails('explanation is required'),
          );
          expect(
            () => mergeLayer(
              DeckParser.parseCore(homeCore, source: 'c.yaml'),
              DeckParser.parseLayer(
                homeLayer.replaceFirst(
                  '    native: "mother"\n',
                  '    native: "mother"\n    explanation: "x"\n',
                ),
                source: 'l.yaml',
              ),
              source: 'l.yaml',
            ),
            fails('explanation is only for a set card'),
          );
        },
      );
    });

    group('a lesson with sets', () {
      // Telugu: one verb across nine forms, the request last, then one
      // person across six verbs: both sets, then drills.
      const slots = [
        'nenu',
        'memu',
        'manam',
        'nuvvu',
        'miru',
        'atanu',
        'ame-adi',
        'vallu',
        'please',
      ];
      const verbs = ['ceyu', 'vellu', 'ra', 'tinu', 'tagu', 'cudu'];
      final table = <Card>[
        for (final verb in verbs)
          for (final slot in slots) cellSetCards(verb, slot, '$verb-$slot'),
      ];
      Card form(String verb, String slot) =>
          table.firstWhere((c) => c.target == '$verb-$slot');
      final fresh = <Card>{
        form('tagu', 'atanu'),
        form('tagu', 'ame-adi'),
        form('tagu', 'please'),
        form('cudu', 'atanu'),
      };
      // Listed person first: the order comes from the lesson, not the deck.
      final person = ResolvedSet(
        set: ruleSet('person', 'person', 'atanu'),
        members: setMembers(
          ruleSet('person', 'person', 'atanu'),
          table,
          ruleOf: rulesOf,
        ),
      );
      final verb = ResolvedSet(
        set: ruleSet('verb', 'verb', 'tagu'),
        members: setMembers(
          ruleSet('verb', 'verb', 'tagu'),
          table,
          ruleOf: rulesOf,
        ),
      );

      LessonSets telugu(List<Card> picked) => lessonSets(
        picked,
        sets: [person, verb],
        isNew: fresh.contains,
        isKnown: (c) => !fresh.contains(c),
      );

      // Hindi: आप (āp), तुम (tum) known, तू (tū).
      final ap = wordSetCards('hi-1', 'आप', reading: 'āp');
      final tum = wordSetCards('hi-2', 'तुम', reading: 'tum');
      final tu = wordSetCards('hi-3', 'तू', reading: 'tū');
      final other = wordSetCards('hi-4', 'घर', reading: 'ghar');
      final you = ResolvedSet(
        set: const CardSet(
          id: 'hi-9001',
          deckId: 'hi-en-a',
          name: 'You',
          explanation: 'Three words for you.',
        ),
        members: [ap, tum, tu],
      );

      test(
        'the set comes first, its known member marked, and every new form is '
        'taught once',
        () {
          final lesson = lessonSets(
            [ap, other],
            sets: [you],
            isNew: (c) => c != tum,
            isKnown: (c) => c == tum,
          );
          expect(lesson.parts, hasLength(1));
          final part = lesson.parts.single;
          expect(part.members, [ap, tum, tu]);
          expect(part.isKnown(tum), isTrue);
          expect(part.isKnown(ap), isFalse);
          expect(part.isSplit, isFalse);
          // तू (tū) comes with आप (āp), though the lesson did not pick it.
          expect(lesson.cards, [ap, tu, other]);
          expect(lesson.members, {'hi-1', 'hi-3'});

          {
            final lesson = telugu([form('tagu', 'atanu')]);
            expect(lesson.cards, [
              form('tagu', 'atanu'),
              form('tagu', 'ame-adi'),
              form('tagu', 'please'),
              form('cudu', 'atanu'),
            ]);
            expect(lesson.members, hasLength(4));
          }
        },
      );
    });

    group('aksharas', () {
      test('a line breaks only between aksharas, never inside one', () {
        expect(aksharasOf('తాగుతుంది'), ['తా', 'గు', 'తుం', 'ది']);
        expect(aksharasOf('చూస్తాడు'), ['చూ', 'స్తా', 'డు']);
        expect(aksharasOf('क्षत्रिय'), ['क्ष', 'त्रि', 'य']);
        expect(aksharasOf('আপনি'), ['আ', 'প', 'নি']);
        expect(aksharasOf('తాగుతుంది').join(), 'తాగుతుంది');
        expect(breakableWord('తాగుతుంది'), 'తా​గు​తుం​ది');
        // Short words, and text with spaces, are left as they are.
        expect(breakableWord('తాగు'), 'తాగు');
        expect(breakableWord('ఇంటి నుంచి'), 'ఇంటి నుంచి');
      });
    });
  });

  group('sets on screen', () {
    testWidgets('the set comes first; a split set shows its parts', (
      tester,
    ) async {
      usePhone(tester);
      final state = learner();
      await openLesson(tester, state);
      final l10n = l10nOf(tester);
      expect(find.byType(SetDrill), findsOneWidget);
      expect(find.text(l10n.setTitle), findsOneWidget);
      expect(find.text('Words you meet first, together.'), findsOneWidget);
      expect(find.byType(SetMemberRow), findsNWidgets(3));
      expect(find.text(l10n.setNew), findsNWidgets(3));
      expect(find.text(l10n.setKnown), findsNothing);
      // It fits on one card: no Full list.
      expect(find.text(l10n.setFullList), findsNothing);
      expect(
        find.text(
          l10n.setNextWords(3, 'ఇల్లు (illu), అమ్మ (amma) and నేను (nēnu)'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(l10n.drillPositionShort(1, sessionOfSetDrill(tester).total)),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.commonContinue));
      await tester.pumpAndSettle();
      expect(find.byType(TeachDrill), findsOneWidget);
      expect(state.progress.log, isEmpty);

      {
        usePhone(tester);
        final state = learner(split: true);
        await openLesson(tester, state);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.setPartTitle(1, 2)), findsOneWidget);
        expect(find.byType(SetMemberRow), findsNWidgets(3));
        // Only the last part says what comes next.
        expect(find.textContaining('Next:'), findsNothing);
        expect(find.text(l10n.setFullList), findsOneWidget);

        await tester.tap(find.text(l10n.setFullList));
        await tester.pumpAndSettle();
        expect(find.text('First words'), findsOneWidget);
        expect(find.text(l10n.setSheetWords(5, 5)), findsOneWidget);
        expect(find.byType(SetMemberRow), findsNWidgets(3 + 5));
        await tester.tap(find.byTooltip(l10n.commonClose).last);
        await tester.pumpAndSettle();
        expect(find.byType(SetMemberRow), findsNWidgets(3));

        await tester.tap(find.text(l10n.commonContinue));
        await tester.pumpAndSettle();
        expect(find.text(l10n.setPartTitle(2, 2)), findsOneWidget);
        expect(find.textContaining('Next:'), findsOneWidget);
      }
    });
  });

  group('number practice', () {
    final hi = bundled('hi');

    test('heard, a number is answered in digits, shown, in words; only the '
        'skills asked for', () {
      final typed = numberPractice(
        hi,
        deckId: 'hi-en-numbers-big',
        modes: const <DrillMode>{DrillMode.production, DrillMode.grammar},
        random: Random(1),
      );
      expect(typed.map((i) => i.mode).toSet(), {DrillMode.production});
      expect(
        numberPractice(
          hi,
          deckId: 'hi-en-numbers-big',
          modes: const <DrillMode>{DrillMode.grammar},
          random: Random(1),
        ),
        isEmpty,
      );

      final card = NumberCard(
        number: 2020,
        spellings: spellNumber(hi, 2020),
        rulesId: hi.id,
        deckId: 'hi-en-numbers-big',
      );
      expect(card.acceptedAnswers(DrillMode.listening), <String>['2020']);
      expect(card.acceptedAnswers(DrillMode.production), <String>[
        'दो हज़ार बीस',
        'दो हजार बीस',
      ]);
      expect(card.acceptedAnswers(DrillMode.recognition), <String>['2020']);
      expect(card.promptFor(DrillMode.production), '2020');
      expect(card.promptFor(DrillMode.recognition), 'दो हज़ार बीस');
    });
  });

  group('spelling numbers', () {
    group('Hindi: every number to 99 is a word of its own', () {
      final hi = bundled('hi');

      test('the spelling follows each rules file: 2020 joined, and a hundred '
          'changes its form when more follows', () {
        expect(spellNumber(hi, 2020).first, 'दो हज़ार बीस');
        expect(spellNumber(hi, 2020), contains('दो हजार बीस'));
        expect(spellNumber(hi, 1950).first, 'एक हज़ार नौ सौ पचास');
        expect(spellNumber(hi, 4007).first, 'चार हज़ार सात');
        expect(spellNumber(hi, 1000).first, 'एक हज़ार');

        {
          final te = bundled('te');

          expect(spellNumber(te, 2000).first, 'రెండు వేలు');
          expect(spellNumber(te, 1200).first, 'వెయ్యి రెండు వందలు');
          expect(spellNumber(te, 1150).first, 'వెయ్యి నూట యాభై');
          expect(spellNumber(te, 250).first, 'రెండు వందల యాభై');
        }
      });
    });

    group('a file that is not number rules is refused', () {
      final good = File('decks/hi/hi-numbers.yaml').readAsStringSync();

      test(
        'a malformed rules file is refused: the wrong kind, a hundred missing',
        () {
          expect(
            () => parseNumberRules(
              good.replaceFirst('kind: numbers', 'kind: vocab'),
              source: 'x',
            ),
            refusedWith('"kind: numbers"'),
          );

          expect(
            () => parseNumberRules(
              good.replaceFirst(RegExp(r'\n  9: .*सौ.*'), ''),
              source: 'x',
            ),
            refusedWith('hundreds needs an entry for 9'),
          );
        },
      );
    });
  });

  group('the braille keyboard', () {
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
      expect(
        field.readOnly,
        isTrue,
        reason: 'the phone\'s keyboard stays shut',
      );
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
      await tester.pump();
      await tester.tap(find.text(l10n.brailleEnterCell));
      await tester.pumpAndSettle();
      expect(field.controller!.text, '⠃');
      await tester.tap(find.text(l10n.drillCheck));
      await tester.pumpAndSettle();
      final session = tester
          .widget<TypedDrill>(find.byType(TypedDrill))
          .session;
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
          request: DrillRequest.untaught(
            'es-en-words',
            skill: Skill.production,
          ),
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
  });

  group('taught details', () {
    testWidgets('after the answer, a reviewed word shows its note and '
        'example, which nothing gives away before it', (tester) async {
      final handle = tester.ensureSemantics();
      for (final question in <Question>[...answered, recognition]) {
        const outcome = Outcome.right;

        usePhone(tester);
        final rig = await pumpRig(
          tester,
          deck: spanishTaughtDetails,
          skill: question.skill,
          target: question.rich(spanishTaughtDetails),
          ask: question.ask,
        );
        final card = rig.card(
          spanishTaughtDetails,
          question.rich(spanishTaughtDetails),
        );
        final l10n = l10nOf(tester);
        expect(find.byType(DrillCard), findsOneWidget);

        // Nothing is given away beforehand.
        expectDetails(tester, card, shown: false);
        expect(
          inCard(findTarget(card.target)),
          question.showsWord ? findsOneWidget : findsNothing,
          reason: 'the word, before the answer',
        );
        expect(
          inCard(find.text(card.native)),
          question.showsMeaning ? findsOneWidget : findsNothing,
          reason: 'the meaning, before the answer',
        );

        await question.answer(tester, rig, card, outcome);
        expect(tester.takeException(), isNull);
        if (question != recognition) {
          expect(
            find.text(
              outcome == Outcome.right
                  ? l10n.feedbackCorrect
                  : l10n.feedbackWrong,
            ),
            findsOneWidget,
            reason: 'the answer was taken as ${outcome.name}',
          );
        }

        // Now: the word, the meaning, the note and the example.
        expectDetails(tester, card, shown: true);
        expect(inCard(findTarget(card.target)), findsOneWidget);
        expect(inCard(find.text(card.native)), findsOneWidget);
        // On the card, which scrolls, not in the frame's fixed foot.
        expect(inCard(find.text(card.notes.first.text)), findsOneWidget);
        expect(find.byType(TaughtDetails), findsOneWidget);
      }
      handle.dispose();
    });
  });

  group('quick revision', () {
    test('a tag\'s practice is a capped set of taught words carrying the tag, '
        'and records every answer', () async {
      final state = await knowing(8);
      final tag = state.deckById('hi-en-phrasebook')!.cards.first.tags.first;
      final request = DrillRequest.tag(tag, count: 3, language: 'hi');
      expect(request.recordsRevision, isTrue);
      final items = state.sessionItems(request);
      final words = <String>{for (final item in items) item.card.id};
      expect(words, isNotEmpty);
      expect(words.length, lessThanOrEqualTo(3));
      for (final item in items) {
        expect(item.card.tags, contains(tag));
        expect(state.isTaught(item.card), isTrue);
      }
    });

    test('quick revision revises that many known words once each, and records '
        'every answer', () async {
      final state = await knowing(8);
      expect(state.revisableCount, 8);
      final items = askedQuickRevision(
        state.sessionItems(const DrillRequest.revision(5)),
      );
      expect(<String>{for (final item in items) item.card.id}, hasLength(5));
      for (final item in items) {
        expect(state.isTaught(item.card), isTrue);
      }

      {
        final state = await knowing(8);
        final items = <SessionItem>[
          for (final item
              in state
                  .buildSession(const DrillRequest.revision(5))
                  .items
                  .take(2))
            item.askedAs(Ask.chooseWord),
        ];
        final session = DrillSession(
          state: state,
          items: items,
          recorded: false,
          revising: true,
          recordsRevision: true,
        );
        final first = items[0];
        final before = state.progress.log.length;
        final due = state.progress.stateOf(first.card.id, first.mode)!.dueAt;
        session.pick(
          session.options.firstWhere((option) => option.id == first.card.id),
        );
        expect(state.progress.log, hasLength(before + 1));
        // A right choice in Write records Hard (ADR-0034).
        expect(
          state.progress.log.last.grade,
          DrillSession.scheduledChoiceGrade,
        );
        expect(
          state.progress.stateOf(first.card.id, first.mode)!.dueAt.isAfter(due),
          isTrue,
        );

        session.next();
        final second = items[1];
        session.pick(
          session.options.firstWhere((option) => option.id != second.card.id),
        );
        expect(state.progress.log, hasLength(before + 2));
        final miss = state.progress.log.last;
        expect(miss.cardId, second.card.id);
        expect(miss.grade, lessThan(Fsrs.passingGrade));
      }
    });
  });

  group('Today', () {
    testWidgets(
      'the due count comes from the session, and Start review opens it',
      (tester) async {
        usePhone(tester);
        final state = await pumpToday(tester, state: await fixtureState());
        final l10n = l10nOf(tester);

        final queue = state.buildSession(const DrillRequest.today());
        expect(queue.length, greaterThan(0));
        final numbers = TodayNumbers.of(state);
        expect(numbers.due, queue.length);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.data == '${queue.length}' &&
                w.style?.fontSize == 72,
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.todayWordsDue(queue.length)), findsOneWidget);
        expect(find.text(l10n.todayMinutes(numbers.minutes)), findsOneWidget);

        final byMode = queue.countByMode();
        // Recognition is scheduled, so it has a tile (ADR-0034).
        expect(
          find.descendant(
            of: find.byType(DueCard),
            matching: find.text(l10n.skillRecognition),
          ),
          findsOneWidget,
        );
        for (final (skill, label) in <(Skill, String)>[
          (Skill.recognition, l10n.skillRecognition),
          (Skill.production, l10n.skillProduction),
          // The grammar drill ships (#14).
          (Skill.grammar, l10n.skillGrammar),
        ]) {
          expect(
            find.bySemanticsLabel(
              l10n.todaySkillSemantics(label, byMode[skill.mode] ?? 0),
            ),
            findsOneWidget,
            reason: skill.name,
          );
        }

        usePhone(tester);
        final settings = SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['hi'],
        );
        await pumpToday(
          tester,
          state: await withReviewsDue(
            (progress) => AppState.test(settings: settings, progress: progress),
            const <String>['hi'],
          ),
        );
        await tapVisible(tester, find.text(l10nOf(tester).todayStartReview));
        final drill = tester.widget<DrillPage>(find.byType(DrillPage));
        expect(drill.request.deckIds, isNull);
        expect(drill.request.newOnly, isFalse);
        expect(drill.request.language, isNull, reason: 'one language');
      },
    );

    testWidgets(
      'Quick revision offers its sizes, and a tile with cards due reviews '
      'that skill',
      (tester) async {
        usePhone(tester);
        await pumpToday(tester);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.todayRevisionTitle), findsOneWidget);
        expect(find.byType(DeckTile), findsNothing);
        for (final size in QuickRevision.sizes) {
          expect(find.text('$size'), findsOneWidget);
        }
        // Nothing taught yet: the buttons are off, and the line says why.
        expect(find.text(l10n.todayRevisionNone), findsOneWidget);
        final five = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('5'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(five.onPressed, isNull);
        // The fact of the day comes after it.
        final fact = find.textContaining(l10n.todayFactTitle);
        await tester.scrollUntilVisible(
          fact.first,
          200,
          scrollable: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          ),
        );
        expect(
          tester.getTopLeft(fact.first).dy,
          greaterThan(tester.getTopLeft(find.text(l10n.todayRevisionTitle)).dy),
        );

        usePhone(tester);
        final state = await hindiReviewed(<DrillMode, Duration>{
          DrillMode.production: const Duration(days: 3),
        });
        await pumpToday(tester, state: state);
        expect(TodayNumbers.of(state).bySkill[Skill.production], 8);
        await tapVisible(tester, tileOf(tester, Skill.production));
        final drill = tester.widget<DrillPage>(find.byType(DrillPage));
        expect(drill.request.skill, Skill.production);
        expect(drill.request.revise, isFalse);
        expect(drill.request.language, isNull);
        final items = state.sessionItems(drill.request);
        expect(items, isNotEmpty);
        expect(
          <DrillMode>{
            for (final item in items)
              for (final asked in item.group.isEmpty ? [item] : item.group)
                asked.mode,
          },
          <DrillMode>{DrillMode.production},
        );
      },
    );

    testWidgets('with everything answered, Today is all done', (tester) async {
      usePhone(tester);
      final state = await fixtureState();
      await state.load();
      finishToday(state);
      await pumpToday(tester, state: state);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.todayAllDoneTitle), findsOneWidget);
      expect(find.text(l10n.todayAllDoneBody), findsOneWidget);
      expect(find.text(l10n.todayStartReview), findsNothing);
      // Today now counts towards the streak.
      expect(find.text(l10n.todayStreak(13)), findsOneWidget);
    });
  });

  group('Can\'t now', () {
    testWidgets(
      'Pause for an hour skips every listening card, and the pause survives '
      'a restart',
      (tester) async {
        final settings = SettingsNotifier()
          ..pause(Skill.listening, until: noon.add(const Duration(hours: 1)))
          ..setOffFor(Skill.speaking, 'hi', true)
          ..setOffFor(Skill.speaking, 'bn', true);
        final restored = SettingsNotifier()..restore(settings.toStored());
        expect(
          restored.pausedUntil(Skill.listening),
          noon.add(const Duration(hours: 1)),
        );
        expect(restored.offFor(Skill.speaking), <String>{'hi', 'bn'});
        final junk = SettingsNotifier()
          ..restore(const <String, String>{
            'paused_until': '{"listening": "soon", "nope": 1}',
            'off_for': '{"speaking": ["hi", "Hindi", 3], "nope": ["bn"]}',
          });
        expect(junk.pausedUntil(Skill.listening), isNull);
        expect(junk.offFor(Skill.speaking), <String>{'hi'});

        usePhone(tester);
        final state = soundState();
        await pumpScreen(
          tester,
          DrillPage(
            request: DrillRequest.untaught(spanish, skill: Skill.listening),
          ),
          state: state,
        );
        final l10n = l10nOf(tester);
        await tapTextCantNow(tester, l10n.drillCantListen);
        await tapTextCantNow(tester, l10n.cantNowPause);
        expect(
          state.settings.pausedUntil(Skill.listening),
          noon.add(const Duration(hours: 1)),
        );
        expect(state.progress.log, isEmpty);
        // Every card was listening, so the session is over.
        expect(find.text(l10n.drillCantListen), findsNothing);
      },
    );

    group('on a drill', () {
      testWidgets(
        'Turn off for Spanish switches speaking off for Spanish only',
        (tester) async {
          usePhone(tester);
          final state = soundState();
          await state.load();
          // The launch check of the recogniser is not awaited by load.
          await tester.pump();
          await state.startSpeech();
          await pumpScreen(
            tester,
            DrillPage(
              request: DrillRequest.untaught(spanish, skill: Skill.speaking),
            ),
            state: state,
          );
          final l10n = l10nOf(tester);
          await tapTextCantNow(tester, l10n.drillCantSpeak);
          await tapTextCantNow(tester, l10n.cantNowOffFor('Spanish'));
          expect(state.settings.offFor(Skill.speaking), <String>{'es'});
          expect(state.settings.isEnabled(Skill.speaking), isTrue);
          expect(state.progress.log, isEmpty);
          // Every card was Spanish speaking, so none is left to drill.
          expect(find.text(l10n.drillCantSpeak), findsNothing);
        },
      );
    });
  });

  group('the script guide', () {
    testWidgets(
      'a guide shows once, before the first script card, and Tips opens it',
      (tester) async {
        usePhone(tester);
        final state = guided();
        await pumpScreen(
          tester,
          DrillPage(request: DrillRequest.untaught('bn-en-letters')),
          state: state,
        );
        final l10n = l10nOf(tester);
        expect(find.text('How Bengali script works'), findsOneWidget);
        expect(find.text('The headline'), findsOneWidget);
        expect(find.text('মাত্রা'), findsOneWidget);
        expect(find.byType(DrillFrame), findsNothing);
        await tapTextScriptGuide(tester, l10n.scriptGuideStart);
        expect(state.settings.hasSeenScriptGuide('bn'), isTrue);
        expect(find.byType(DrillFrame), findsOneWidget);

        // Seen: the next session starts on the letters.
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpScreen(
          tester,
          DrillPage(request: DrillRequest.untaught('bn-en-letters')),
          state: state,
        );
        expect(find.text('How Bengali script works'), findsNothing);
        expect(find.byType(DrillFrame), findsOneWidget);

        {
          usePhone(tester);
          final state = guided();
          await pumpScreen(
            tester,
            const DeckDetailPage(deckId: 'bn-en-letters'),
            state: state,
          );
          final l10n = l10nOf(tester);
          await tapTextScriptGuide(
            tester,
            l10n.deckScriptTips('How Bengali script works'),
          );
          expect(find.byType(ScriptGuidePage), findsOneWidget);
          expect(find.text('The headline'), findsOneWidget);
          await tapTextScriptGuide(tester, l10n.commonDone);
          expect(find.byType(ScriptGuidePage), findsNothing);
          // Opening it from Tips doesn't count as seeing it before the letters.
          expect(state.settings.hasSeenScriptGuide('bn'), isFalse);
        }
      },
    );
  });

  group('the daily fact', () {
    testWidgets(
      'Today shows the fact in Bengali then English, and records it',
      (tester) async {
        usePhone(tester);
        final settings = SettingsNotifier(spokenLanguages: const ['bn', 'en']);
        final state = AppState.test(
          decks: MemoryDeckSource(const <String, String>{
            'decks/hi/hi-en-core.yaml': deckDailyFact,
            'decks/hi/hi-facts.yaml': facts,
          }),
          settings: settings,
        );
        await pumpScreen(tester, const TodayPage(), state: state);
        final l10n = l10nOf(tester);
        expect(state.brokenDecks, isEmpty);
        expect(find.text(l10n.todayFactFor('Hindi')), findsOneWidget);
        final bengali = find.text('কোনো হিন্দি শব্দ ড় দিয়ে শুরু হয় না।');
        final english = find.text('No Hindi word begins with ड़.');
        expect(bengali, findsOneWidget);
        expect(english, findsOneWidget);
        expect(
          tester.getTopLeft(bengali).dy,
          lessThan(tester.getTopLeft(english).dy),
        );
        expect(tester.widget<Text>(bengali).locale, const Locale('bn'));
        await tester.pump();
        expect(settings.factShownAt('hi', 'hi-fact-001'), isNotNull);
        settings.dispose();
      },
    );
  });

  group('the summary', () {
    testWidgets(
      'the summary\'s totals and scores come from the session, and Done '
      'returns to Today',
      (tester) async {
        usePhone(tester);
        await pumpScreen(tester, SummaryPage(result: fiveAnswers));
        final l10n = l10nOf(tester);

        expect(find.text(l10n.summaryTitle), findsOneWidget);
        expect(find.text(l10n.summaryLine(5, 4)), findsOneWidget);
        expect(statFor(tester, l10n.summaryCorrect), l10n.commonPercent(0.8));
        expect(statFor(tester, l10n.summaryMinutes(3)), '3');
        // No history before this session in AppState.test.
        expect(statFor(tester, l10n.summaryStreak(0)), '0');

        for (final (label, correct, total) in <(String, int, int)>[
          (l10n.skillRecognition, 2, 2),
          (l10n.skillProduction, 1, 2),
          (l10n.skillListening, 1, 1),
        ]) {
          expect(
            find.bySemanticsLabel(
              l10n.summaryScoreSemantics(label, correct, total),
            ),
            findsOneWidget,
            reason: label,
          );
        }
        expect(find.byType(BarRow), findsNWidgets(3));
        expect(find.text(l10n.summaryNextDue(0)), findsOneWidget);

        usePhone(tester);
        final state = await pumpApp(tester);
        state.shellTab.value = ShellTab.decks;
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(AppShell)))
            .pushNamed(AppRoutes.summary, arguments: fiveAnswers);
        await tester.pumpAndSettle();
        expect(find.byType(SummaryPage), findsOneWidget);

        await tapVisibleSummaryPage(
          tester,
          find.text(l10nOf(tester).commonDone),
        );
        expect(find.byType(SummaryPage), findsNothing);
        expect(state.shellTab.value, ShellTab.today);
      },
    );
  });
  group('a deck\'s known cards come up a few at a time', () {
    final cards = <Card>[
      for (var i = 0; i < 12; i++)
        Card(
          id: 'k$i',
          deckId: 'known',
          target: 't$i',
          native: 'n$i',
          modes: const {DrillMode.recognition},
        ),
    ];

    /// A known card due a day before [at], last reviewed [daysAgo] days
    /// before it.
    FsrsState known(DateTime at, {int daysAgo = 30}) => FsrsState(
      stability: 20,
      difficulty: 5,
      repetitions: 3,
      intervalDays: 20,
      dueAt: at.subtract(const Duration(days: 1)),
      lastReviewAt: at.subtract(Duration(days: daysAgo)),
    );

    /// A known card reviewed right at [at], so not due for weeks.
    FsrsState passed(DateTime at) => FsrsState(
      stability: 25,
      difficulty: 5,
      repetitions: 4,
      intervalDays: 25,
      dueAt: at.add(const Duration(days: 25)),
      lastReviewAt: at,
    );

    FsrsState missed(DateTime at) => FsrsState(
      stability: 1,
      difficulty: 6,
      repetitions: 0,
      intervalDays: 1,
      dueAt: at.add(const Duration(days: 1)),
      lastReviewAt: at,
      lapses: 1,
    );

    List<String> due(
      Map<String, FsrsState> states, {
      DateTime? at,
      int take = 12,
    }) => SessionQueue.build(
      cards: cards.take(take),
      stateOf: (c, m) => states[c.id],
      hasVoice: (_) => false,
      now: at ?? now,
      newCardLimit: 0,
      sampleKnown: true,
    ).due.map((i) => i.card.id).toList();

    // k0 was reviewed longest ago, then k1, and so on.
    Map<String, FsrsState> pending() => {
      for (var i = 0; i < 12; i++) 'k$i': known(now, daysAgo: 60 - i),
    };

    test('a pending deck shows two, the ones reviewed longest ago', () {
      expect(due(pending()), <String>['k0', 'k1']);
    });

    test('a passed sample holds the rest, and the cards not sampled have '
        'their turn before any is sampled again', () {
      final states = pending();
      for (final id in <String>['k0', 'k1']) {
        states[id] = passed(now);
      }
      expect(due(states), isEmpty);
      // Weeks on, the samples are due again, with the others still due.
      final later = now.add(const Duration(days: 40));
      expect(due(states, at: later), <String>['k2', 'k3']);
    });

    test('a failed sample asks more, and a second failure brings every due '
        'known card of the deck', () {
      final states = pending();
      states['k0'] = missed(now);
      states['k1'] = passed(now);
      final more = due(states);
      expect(more.length, inInclusiveRange(3, 5));
      expect(more.first, 'k2');
      states['k2'] = missed(now);
      expect(due(states), <String>[for (var i = 3; i < 12; i++) 'k$i']);
    });

    test('cards still being learned are not sampled', () {
      final states = <String, FsrsState>{
        for (var i = 0; i < 5; i++) 'k$i': dueDaysAgo(1),
      };
      expect(due(states, take: 5), hasLength(5));
    });
  });
}
