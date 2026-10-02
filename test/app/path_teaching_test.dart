import 'dart:io';

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

/// A tiny course: three single-card decks of Hindi from [native], in a path
/// of three units, [first] first.
Map<String, String> tinyCourse({String native = 'en', String first = 'a'}) {
  String deck(String name) =>
      '''
schema: 1
id: hi-$native-$name
name: "$name"
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: $native, iso639_3: ${native == 'en' ? 'eng' : 'ben'}, name: ${native == 'en' ? 'English' : 'Bengali'} }
license: CC0-1.0
cards:
  - { id: hi-$native-$name-0001, target: "क", native: "k", reading: "k", modes: [recognition] }
''';
  final order = <String>[
    first,
    ...<String>['a', 'b', 'c']..remove(first),
  ];
  return <String, String>{
    for (final name in <String>['a', 'b', 'c'])
      'decks/hi/hi-$native-$name.yaml': deck(name),
    'decks/hi/hi-$native-path.yaml':
        '''
schema: 1
kind: path
id: hi-$native-path
language: hi
native: $native
units:
${[for (final name in order) '  - [hi-$native-$name]'].join('\n')}
''',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Today takes new cards only from the first two units of the path, '
      'one from each in turn', () async {
    final state = learning(<String>['hi']);
    addTearDown(state.dispose);
    await state.load();
    // Hindi starts with its script.
    expect(unitIds(state), <List<String>>[
      <String>['hi-en-script-vowels', 'hi-en-script-consonants'],
      <String>['hi-en-script-vowel-signs', 'hi-en-script-conjuncts'],
    ]);
    final fresh = state.buildSession(const DrillRequest.today()).fresh;
    expect(fresh, hasLength(20));
    final unitOf = <String, int>{
      for (final (i, unit) in unitIds(state).indexed)
        for (final id in unit) id: i,
    };
    expect(fresh.map((i) => unitOf[i.card.deckId]), everyElement(isNotNull));
    expect(fresh.take(4).map((i) => unitOf[i.card.deckId]), [0, 1, 0, 1]);
    // "Learn 5 new" draws on the same units.
    expect(
      state
          .buildSession(const DrillRequest.learnNew(5))
          .fresh
          .map((i) => i.card.deckId),
      everyElement(isIn(unitOf.keys)),
    );
  });

  test('a placed unit is skipped, and its decks read Done', () async {
    final state = learning(
      <String>['hi'],
      placed: <String>{'hi-en-script-vowels', 'hi-en-script-consonants'},
    );
    addTearDown(state.dispose);
    await state.load();
    expect(unitIds(state).first, <String>[
      'hi-en-script-vowel-signs',
      'hi-en-script-conjuncts',
    ]);
    expect(unitIds(state).last.first, 'hi-en-sound-differences');
    expect(badgeOf(state, 'hi-en-script-vowels'), DeckBadgeKind.done);
    expect(badgeOf(state, 'hi-en-script-vowel-signs'), DeckBadgeKind.pending);
    expect(badgeOf(state, 'hi-en-sound-differences'), DeckBadgeKind.pending);
    expect(badgeOf(state, 'hi-en-market'), DeckBadgeKind.notDone);
    // A placed deck can still be studied.
    expect(
      state.buildSession(DrillRequest.deck('hi-en-script-vowels')).fresh,
      isNotEmpty,
    );

    // Placement is a setting: changing it moves the window at once.
    state.settings.placedDecks = const <String>{};
    expect(unitIds(state).first.first, 'hi-en-script-vowels');
  });

  test('a deck finished inside a pending unit reads Done, its unit-mate '
      'Pending', () async {
    final state = learning(<String>['hi']);
    addTearDown(state.dispose);
    await state.load();
    final consonants = state.deckById('hi-en-script-consonants')!;
    while (state.notStudiedIn(consonants) > 0) {
      for (final item
          in state
              .buildSession(DrillRequest.learnAnyway(consonants.id))
              .items) {
        state.record(item, 5);
      }
    }
    expect(unitIds(state).first, contains(consonants.id));
    expect(badgeOf(state, consonants.id), DeckBadgeKind.done);
    expect(badgeOf(state, 'hi-en-script-vowels'), DeckBadgeKind.pending);
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
    // The day's cap would allow more, but nothing past the pending units.
    expect(
      state
          .buildSession(const DrillRequest.today())
          .fresh
          .map((i) => i.card.deckId),
      <String>['hi-en-a', 'hi-en-b'],
    );
    final first = state.buildSession(DrillRequest.deck('hi-en-a')).items.single;
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
        mode: DrillMode.recognition,
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
    final starts = <String>[
      for (final unit in everything.pendingUnits) unit.first.id,
    ];
    // Two units for each course, and Japanese's only one, hiragana.
    // Bengali starts with its script.
    expect(
      starts,
      containsAll(<String>['bn-en-script-vowels', 'bn-en-script-vowel-signs']),
    );
    expect(starts, containsAll(<String>['es-en-core-100', 'ja-en-hiragana']));
    expect(starts, hasLength(9));
  });

  test('a language is taught from the best-known language the learner speaks '
      'that has a course', () async {
    final state = learning(
      <String>['hi'],
      spoken: <String>['bn', 'en'],
      decks: MemoryDeckSource(<String, String>{
        ...tinyCourse(),
        ...tinyCourse(native: 'bn', first: 'c'),
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
        Profile(id: 'mira', languages: <String>{'ja'}),
      ],
      currentProfileId: 'mira',
    );
    addTearDown(state.dispose);
    await state.load();
    expect(state.currentProfile.learns('ja'), isTrue);
    expect(state.currentProfile.learns('hi'), isFalse);
    state.selectProfile(Profile.defaultProfile.id);
    expect(state.currentProfile.learns('hi'), isTrue);
    expect(state.currentProfile.learns('ja'), isFalse);
  });

  test(
    'two languages share the day equally, each in a block of its own',
    () async {
      final state = learning(<String>['hi', 'bn']);
      addTearDown(state.dispose);
      await state.load();
      final fresh = state.buildSession(const DrillRequest.today()).fresh;
      expect(fresh, hasLength(20));
      final languages = fresh.map(
        (i) => state.deckById(i.card.deckId)!.language.code,
      );
      // Bengali comes first in the catalog, so its block does too.
      expect(languages.take(10), everyElement('bn'));
      expect(languages.skip(10), everyElement('hi'));

      // A language with fewer new cards than its share passes the rest on.
      final small = learning(
        <String>['hi', 'ja'],
        decks: MemoryDeckSource(<String, String>{
          ...tinyCourse(),
          'decks/ja/ja-en-hiragana.yaml': File('decks/ja/ja-en-hiragana.yaml')
              .readAsStringSync(),
          'decks/ja/ja-en-path.yaml': File('decks/ja/ja-en-path.yaml')
              .readAsStringSync(),
        }),
      );
      addTearDown(small.dispose);
      await small.load();
      final mixed = small.buildSession(const DrillRequest.today()).fresh;
      expect(mixed, hasLength(20));
      expect(
        mixed
            .where((i) => i.card.deckId.startsWith('hi-'))
            .map((i) => i.card.deckId),
        <String>['hi-en-a', 'hi-en-b'],
      );
    },
  );
}
