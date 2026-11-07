import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/sound_contrasts.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/placement_run.dart';

/// A small course for the Find my level run (the same shape as the question
/// builder's own fixture): six word decks in path order, decks 3 to 5
/// teaching grammar families, long sentences in decks 4 and 5, a few short
/// ones in decks 3 and 4, eight words spelled in Devanagari in deck 1 and
/// four pairs of words that differ by one swap.
PlacementLanguageData findLevelData({
  Set<String> stable = const <String>{},
  int decks = 6,
  int words = 10,
}) {
  const letters = 'abcdefghij';
  final big = decks != 6 || words != 10;
  String wordOf(int i, int j) => big
      ? 'x${i.toRadixString(36)}${j.toRadixString(36)}o'
      : 'x${letters[i]}${letters[j]}o';
  const devanagari = <String>[
    'कमल',
    'नमक',
    'पत्र',
    'चक्र',
    'सूर्य',
    'धर्म',
    'शब्द',
    'जल',
  ];
  const families = <int, List<String>>{
    3: <String>['plural'],
    4: <String>['plural', 'case'],
    5: <String>['case', 'tense'],
  };
  Card card(
    String id,
    String target,
    String native,
    int deck, {
    String pos = 'noun',
    List<CardBase> bases = const <CardBase>[],
    List<CardItem> confusables = const <CardItem>[],
  }) => Card(
    id: id,
    deckId: 'deck-$deck',
    target: target,
    native: native,
    pos: pos,
    bases: bases,
    confusables: confusables,
    tags: <String>['t$deck'],
  );

  final deckList = <PlacementDeck>[];
  final scriptCards = <Card>[];
  for (var i = 0; i < decks; i++) {
    final cards = <Card>[
      for (var j = 0; j < words; j++)
        card(
          'w-$i-$j',
          wordOf(i, j),
          'thing $i-$j',
          i,
          bases: i == decks - 1 && j < 2
              ? <CardBase>[CardBase(word: wordOf(i, j), base: 'stem')]
              : const <CardBase>[],
        ),
    ];
    if (i == 1) {
      for (var j = 0; j < devanagari.length; j++) {
        final c = card('s-$j', devanagari[j], 'sign $j', 1);
        scriptCards.add(c);
        cards.add(c);
      }
    }
    if (i == 3) cards.add(card('p-tola', 'tola', 'bridge', 3));
    if (i == 4) cards.add(card('p-kala', 'kala', 'cup', 4));
    if (i == 5) {
      cards
        ..add(card('p-gala', 'gala', 'feast', 5))
        ..add(card('p-dola', 'dola', 'swing', 5));
    }
    if (i >= 3) {
      for (var j = 0; j < (i >= 4 ? 6 : 0); j++) {
        final words = <String>[for (var k = 0; k < 9; k++) 'w$i$j$k'];
        cards.add(
          card(
            's$i-$j',
            words.join(' '),
            'Long sentence $i-$j',
            i,
            pos: 'phrase',
            bases: <CardBase>[CardBase(word: words[2], base: 'root$i$j')],
            confusables: <CardItem>[
              for (var n = 0; n < 3; n++)
                CardItem(id: 'c$n', word: 'w$i${j}z$n'),
            ],
          ),
        );
      }
      for (var j = 0; j < 3; j++) {
        final words = <String>['q$i${j}a', 'q$i${j}b', 'q$i${j}c'];
        cards.add(
          card(
            'short$i-$j',
            words.join(' '),
            'Short sentence $i-$j',
            i,
            pos: 'phrase',
            bases: <CardBase>[CardBase(word: words[1], base: 'short$i$j')],
            confusables: <CardItem>[
              for (var n = 0; n < 3; n++)
                CardItem(id: 'c$n', word: 'q$i${j}z$n'),
            ],
          ),
        );
      }
    }
    deckList.add(
      PlacementDeck(
        id: 'deck-$i',
        cards: cards,
        grammarFamilies: families[i] ?? const <String>[],
      ),
    );
  }
  return PlacementLanguageData(
    language: 'xx',
    decks: deckList,
    scripts: <PlacementScriptData>[
      PlacementScriptData(
        script: 'devanagari',
        words: <PlacementScriptWord>[
          for (final c in scriptCards)
            PlacementScriptWord(card: c, spelling: c.target),
        ],
      ),
    ],
    sounds: const SoundContrasts(
      language: 'xx',
      contrasts: <SoundContrast>[
        SoundContrast(
          id: 'velar',
          name: 'k or g',
          pairs: <(String, String)>[('k', 'g')],
        ),
        SoundContrast(
          id: 'dental',
          name: 't or d',
          pairs: <(String, String)>[('t', 'd')],
        ),
      ],
    ),
    levelMarkDecks: <int>[1, big ? 5 : 3, decks - 1],
    stableCardIds: stable,
  );
}

/// The run settings for [findLevelData]'s six decks.
PlacementRunConfig findLevelConfig({
  int decks = 6,
  Set<PlacementSkill> skills = const <PlacementSkill>{
    PlacementSkill.read,
    PlacementSkill.hear,
    PlacementSkill.write,
  },
  PlacementDeclaration declaration = PlacementDeclaration.expert,
  bool microphone = false,
  bool verifiable = true,
  bool floorFirst = true,
}) => PlacementRunConfig(
  deckCount: decks,
  skills: skills,
  declaration: declaration,
  microphone: microphone,
  floorFirst: floorFirst,
  pathCompleteToB1: verifiable,
  allDecksDownloaded: verifiable,
  grammarUnitDecks: const <int>[3, 4, 5],
);
