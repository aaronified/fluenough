import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/ui/widgets/deck_tile.dart';

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
  - { id: hi-$native-$name-0001, target: "क", native: "k", reading: "k", modes: [production] }
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('A lesson takes new words only from the first two units of the '
      'path, one from each in turn', () async {
    final state = learning(<String>['hi']);
    addTearDown(state.dispose);
    await state.load();
    // Hindi starts with words and basic sentences, not its script.
    expect(unitIds(state), <List<String>>[
      <String>[
        'hi-en-phrasebook',
        'hi-en-first-words',
        'hi-en-grammar-sentences',
      ],
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

  test('a placed unit is skipped, and its decks read Done', () async {
    final state = learning(
      <String>['hi'],
      placed: <String>{
        'hi-en-phrasebook',
        'hi-en-first-words',
        'hi-en-grammar-sentences',
      },
    );
    addTearDown(state.dispose);
    await state.load();
    expect(unitIds(state).first, <String>['hi-en-sound-differences']);
    expect(unitIds(state).last.first, 'hi-en-grammar-differences');
    expect(badgeOf(state, 'hi-en-first-words'), DeckBadgeKind.done);
    expect(badgeOf(state, 'hi-en-sound-differences'), DeckBadgeKind.pending);
    expect(badgeOf(state, 'hi-en-grammar-differences'), DeckBadgeKind.pending);
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
  });

  test('a deck finished inside a pending unit reads Done, its unit-mate '
      'Pending', () async {
    final state = learning(<String>['hi']);
    addTearDown(state.dispose);
    await state.load();
    final sentences = state.deckById('hi-en-grammar-sentences')!;
    while (state.notStudiedIn(sentences) > 0) {
      for (final item
          in state.buildSession(DrillRequest.untaught(sentences.id)).items) {
        state.record(item, 5);
      }
    }
    expect(unitIds(state).first, contains(sentences.id));
    expect(badgeOf(state, sentences.id), DeckBadgeKind.done);
    expect(badgeOf(state, 'hi-en-first-words'), DeckBadgeKind.pending);
  });

  test('a finished unit is passed, and the next two are taught', () async {
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

  test('the profile learns only the languages chosen; with none chosen it '
      'learns them all, each with its own window', () async {
    final bengali = learning(<String>['bn']);
    addTearDown(bengali.dispose);
    await bengali.load();
    expect(bengali.currentProfile.learns('bn'), isTrue);
    expect(bengali.currentProfile.learns('hi'), isFalse);
    expect(badgeOf(bengali, 'hi-en-first-words'), DeckBadgeKind.start);
    expect(
      bengali.pendingUnits.expand((u) => u).map((e) => e.language.code),
      everyElement('bn'),
    );

    final everything = learning(const <String>[]);
    addTearDown(everything.dispose);
    await everything.load();
    final pending = <List<String>>[
      for (final unit in everything.pendingUnits) [for (final e in unit) e.id],
    ];
    final starts = [for (final unit in pending) unit.first];
    // Two units for each of the eight courses. Bengali starts with its
    // phrasebook and first words (ADR-0036: the phrasebook is taught in
    // the first unit), then the sounds English lacks.
    final bengaliUnits = [
      for (final unit in pending)
        if (unit.first.startsWith('bn-')) unit,
    ];
    expect(bengaliUnits, hasLength(2));
    expect(bengaliUnits.first.take(2), <String>[
      'bn-en-phrasebook',
      'bn-en-first-words',
    ]);
    expect(bengaliUnits.last.first, 'bn-en-sound-differences');
    expect(starts, contains('es-en-core-100'));
    expect(starts, hasLength(16));
  });

  test('a language is taught from the best-known language the learner speaks '
      'that has a course', () async {
    final state = learning(
      <String>['hi'],
      spoken: <String>['bn', 'en'],
      decks: MemoryDeckSource(<String, String>{
        ...tinyCourse(first: 'c'),
        ...tinyCourse(native: 'bn', path: false),
      }),
    );
    addTearDown(state.dispose);
    await state.load();
    expect(unitIds(state), <List<String>>[
      <String>['hi-bn-c'],
      <String>['hi-bn-a'],
    ]);
    // With the Bengali course nearly done, its last unit is all that is
    // pending: the English course's decks are never pulled in.
    state.settings.placedDecks = const <String>{'hi-bn-c', 'hi-bn-a'};
    expect(unitIds(state), <List<String>>[
      <String>['hi-bn-b'],
    ]);
  });

  test('a profile made with its own languages keeps them', () async {
    final state = AppState.test(
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['hi'],
      ),
      profiles: const <Profile>[
        Profile.defaultProfile,
        Profile(id: 'mira', languages: <String>{'bn'}),
      ],
      currentProfileId: 'mira',
    );
    addTearDown(state.dispose);
    await state.load();
    expect(state.currentProfile.learns('bn'), isTrue);
    expect(state.currentProfile.learns('hi'), isFalse);
    state.selectProfile(Profile.defaultProfile.id);
    expect(state.currentProfile.learns('hi'), isTrue);
    expect(state.currentProfile.learns('bn'), isFalse);
  });

  test('each language has a lesson of its own, from its own units', () async {
    final state = learning(<String>['hi', 'bn']);
    addTearDown(state.dispose);
    await state.load();
    for (final code in <String>['hi', 'bn']) {
      final lesson = state.lessonFor(DrillRequest.lesson(language: code));
      expect(lesson, isNotEmpty, reason: code);
      expect(
        lesson.map((i) => state.deckById(i.card.deckId)!.language.code),
        everyElement(code),
      );
    }
  });

  test('a deck whose words are all taught is finished, its other skills '
      'coming with its reviews (ADR-0024)', () async {
    final base = learning(<String>['hi']);
    await base.load();
    final market = base.deckById('hi-en-market')!;
    // Every card written three days ago, so due again today, and none yet
    // heard or said.
    final progress = MemoryProgress();
    for (final card in market.cards) {
      progress.record(
        deckId: market.id,
        cardId: card.id,
        mode: DrillMode.production,
        grade: 4,
        now: base.now().subtract(const Duration(days: 3)),
      );
    }
    base.dispose();
    final state = learning(<String>['hi'], progress: progress);
    addTearDown(state.dispose);
    await state.load();
    final entry = state.deckById(market.id)!;
    expect(state.notStudiedIn(entry), 0);
    expect(state.isFinished(entry), isTrue);
    expect(state.buildSession(DrillRequest.deck(market.id)).due, isNotEmpty);
  });
}
