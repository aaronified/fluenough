// The stored admission verdict holds one entry per deck source (#1270): a
// language audited on its frozen decks and on its live decks gets the verdict
// of whichever the phone has, and a change of what the audit reads in one
// source leaves the other's verdict in place. The key holds only what the audit
// reads: cards and decks it skips do not change it. Pure logic, no decks read.
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/placement/admission.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:flutter_test/flutter_test.dart';

PlacementDeck _deck(String id, List<(String, String, String)> cards) =>
    PlacementDeck(
      id: id,
      cards: <Card>[
        for (final c in cards)
          Card(id: c.$1, deckId: id, target: c.$2, native: c.$3),
      ],
    );

PlacementLanguageData _data(String language, String word) =>
    PlacementLanguageData(
      language: language,
      decks: <PlacementDeck>[
        _deck('$language-001', <(String, String, String)>[
          ('$language-1', word, 'house'),
        ]),
      ],
    );

void main() {
  test('a language with a frozen key and a live key gets the verdict of '
      'the decks it has', () {
    final frozen = _data('xx', 'casa');
    final live = _data('xx', 'casita');
    final map = <String, List<AdmissionProfile>>{
      'xx': <AdmissionProfile>[
        AdmissionProfile(
          deckKey: admissionKey(frozen),
          excluded: const <String>['F5:clean'],
          decoys: 2,
        ),
        AdmissionProfile(
          source: kLiveDecks,
          deckKey: admissionKey(live),
          excluded: const <String>['F17:clean'],
          decoys: 3,
        ),
      ],
    };
    expect(admissionKey(frozen), isNot(admissionKey(live)));
    final onFrozen = AdmissionProfile.of(frozen, map)!;
    expect(onFrozen.source, kFrozenDecks);
    expect(onFrozen.admits('F5:clean'), isFalse);
    final onLive = AdmissionProfile.of(live, map)!;
    expect(onLive.source, kLiveDecks);
    expect(onLive.admits('F17:clean'), isFalse);
    expect(onLive.admits('F5:clean'), isTrue);
    expect(onLive.decoys, 3);
  });

  test('decks matching no entry, or a language with none, get no verdict', () {
    final frozen = _data('xx', 'casa');
    final map = <String, List<AdmissionProfile>>{
      'xx': <AdmissionProfile>[
        AdmissionProfile(
          deckKey: admissionKey(frozen),
          excluded: const <String>[],
          decoys: 0,
        ),
      ],
    };
    expect(AdmissionProfile.of(frozen, map), isNotNull);
    expect(AdmissionProfile.of(_data('xx', 'otra'), map), isNull);
    expect(AdmissionProfile.of(_data('yy', 'casa'), map), isNull);
    expect(AdmissionProfile.of(frozen, const {}), isNull);
  });

  test('the shipped entries of one key (frozen and live decks the audit '
      'reads alike) hold the same verdict', () {
    for (final e in kAdmissionProfiles.entries) {
      final byKey = <String, AdmissionProfile>{};
      for (final p in e.value) {
        final seen = byKey.putIfAbsent(p.deckKey, () => p);
        expect(p.excluded, seen.excluded, reason: '${e.key} ${p.deckKey}');
        expect(p.decoys, seen.decoys, reason: '${e.key} ${p.deckKey}');
      }
    }
  });

  test('two entries of one key are found, the first answering', () {
    final data = _data('xx', 'casa');
    final map = <String, List<AdmissionProfile>>{
      'xx': <AdmissionProfile>[
        AdmissionProfile(
          deckKey: admissionKey(data),
          excluded: const <String>['F5:clean'],
          decoys: 2,
        ),
        AdmissionProfile(
          source: kLiveDecks,
          deckKey: admissionKey(data),
          excluded: const <String>['F5:clean'],
          decoys: 2,
        ),
      ],
    };
    expect(AdmissionProfile.of(data, map)?.source, kFrozenDecks);
  });

  group('the key holds only what the audit reads', () {
    Card word({
      String id = 'xx-1',
      String target = 'casa',
      String native = 'house',
      String? reading,
      String? pos = 'noun',
      String? gender,
      bool practiceOnly = false,
      List<String> altTarget = const <String>[],
      List<String>? words,
      List<CardBase> bases = const <CardBase>[],
    }) {
      return Card(
        id: id,
        deckId: 'xx-001',
        target: target,
        native: native,
        reading: reading,
        pos: pos,
        gender: gender,
        practiceOnly: practiceOnly,
        altTarget: altTarget,
        words: words,
        bases: bases,
      );
    }

    PlacementLanguageData course(List<List<Card>> decks, String language) {
      final built = <PlacementDeck>[];
      for (final (i, cards) in decks.indexed) {
        built.add(PlacementDeck(id: 'xx-00$i', cards: cards));
      }
      return PlacementLanguageData(language: language, decks: built);
    }

    String keyOf(List<List<Card>> decks) {
      return admissionKey(course(decks, 'xx'));
    }

    String keyOne(List<Card> cards) {
      return keyOf(<List<Card>>[cards]);
    }

    const skipped = <Card>[
      Card(
        id: 'xx-l',
        deckId: 'xx-001',
        target: 'a',
        native: 'a',
        pos: 'letter',
      ),
      Card(
        id: 'xx-d',
        deckId: 'xx-001',
        target: '1',
        native: 'one',
        pos: 'digit',
      ),
      Card(
        id: 'xx-g',
        deckId: 'xx-001',
        target: 'casas',
        native: 'houses',
        modes: DrillMode.vocabulary,
      ),
    ];

    test('cards and decks the audit skips change nothing', () {
      final plain = keyOne(<Card>[word()]);
      expect(keyOne(<Card>[word(), ...skipped]), plain);
      final after = keyOf(<List<Card>>[
        <Card>[word()],
        skipped,
      ]);
      expect(after, plain);
      final before = keyOf(<List<Card>>[
        skipped,
        <Card>[word()],
      ]);
      expect(before, plain, reason: 'a deck first only offsets the others');
      expect(plain, startsWith('1-'));
    });

    test('fields the audit never reads change nothing', () {
      final plain = keyOne(<Card>[word()]);
      final decorated = PlacementLanguageData(
        language: 'xx',
        decks: <PlacementDeck>[
          const PlacementDeck(
            id: 'xx-renamed',
            grammarFamilies: <String>['plural'],
            cards: <Card>[
              Card(
                id: 'xx-1',
                deckId: 'xx-renamed',
                target: 'casa',
                native: 'house',
                pos: 'noun',
                ipa: '/ka.sa/',
                phonetic: '[ka.sa]',
                tags: <String>['home'],
                audio: 'a.mp3',
              ),
            ],
          ),
        ],
        stableCardIds: const <String>{'xx-1'},
      );
      expect(admissionKey(decorated), plain);
    });

    test('a change to any field the audit reads changes the key', () {
      final plain = keyOne(<Card>[word()]);
      const baseWord = CardBase(word: 'casa');
      const baseOf = CardBase(word: 'casa', base: 'cas');
      final changed = <String, Card>{
        'id': word(id: 'xx-9'),
        'target': word(target: 'casita'),
        'native': word(native: 'home'),
        'reading': word(reading: 'kasa'),
        'empty reading': word(reading: ''),
        'pos': word(pos: 'verb'),
        'no pos': word(pos: null),
        'gender': word(gender: 'f'),
        'practiceOnly': word(practiceOnly: true),
        'altTarget': word(altTarget: const <String>['casa grande']),
        'words': word(words: const <String>['casa']),
        'empty words': word(words: const <String>[]),
        'base word': word(bases: <CardBase>[baseWord]),
        'base': word(bases: <CardBase>[baseOf]),
      };
      for (final e in changed.entries) {
        expect(keyOne(<Card>[e.value]), isNot(plain), reason: e.key);
      }
      final other = word(id: 'xx-2', target: 'perro', native: 'dog');
      expect(keyOne(<Card>[word(), other]), isNot(plain));
      expect(
        keyOne(<Card>[word(), other]),
        isNot(keyOne(<Card>[other, word()])),
        reason: 'order within a deck',
      );
      expect(keyOne(<Card>[word()]), isNot(keyOne(<Card>[word(), other])));
      final yyDecks = <List<Card>>[
        <Card>[word()],
      ];
      final yy = admissionKey(course(yyDecks, 'yy'));
      expect(yy, isNot(plain), reason: 'another language, another audit');
    });

    test('a deck between read cards, or a swap of decks, changes it', () {
      final a = word();
      final b = word(id: 'xx-2', target: 'perro', native: 'dog');
      final together = keyOf(<List<Card>>[
        <Card>[a],
        <Card>[b],
      ]);
      final apart = keyOf(<List<Card>>[
        <Card>[a],
        skipped,
        <Card>[b],
      ]);
      final swapped = keyOf(<List<Card>>[
        <Card>[b],
        <Card>[a],
      ]);
      expect(apart, isNot(together));
      expect(swapped, isNot(together));
    });

    test('a non-Latin course, or a wider near-span, changes the key', () {
      final latin = keyOne(<Card>[word()]);
      // More letters of other scripts than Latin ones among all the cards,
      // the cards the audit skips included.
      const nonLatin = Card(
        id: 'xx-n',
        deckId: 'xx-001',
        target: 'कककककककक',
        native: 'many',
        pos: 'letter',
      );
      expect(keyOne(<Card>[word(), nonLatin]), isNot(latin));
      // 72 decks have the span 6, 84 decks the span 7.
      String keyOfDecks(int n) {
        final decks = <List<Card>>[
          <Card>[word()],
        ];
        for (var i = 1; i < n; i++) {
          decks.add(<Card>[]);
        }
        return keyOf(decks);
      }

      expect(keyOfDecks(72), keyOfDecks(73));
      expect(keyOfDecks(72), isNot(keyOfDecks(84)));
    });

    test('a stored verdict is found for decks that differ in unread input', () {
      final map = <String, List<AdmissionProfile>>{
        'xx': <AdmissionProfile>[
          AdmissionProfile(
            source: kLiveDecks,
            deckKey: keyOne(<Card>[word()]),
            excluded: const <String>['F5:clean'],
            decoys: 2,
          ),
        ],
      };
      final mergedDecks = <List<Card>>[
        <Card>[word()],
        skipped,
      ];
      final merged = course(mergedDecks, 'xx');
      final found = AdmissionProfile.of(merged, map);
      expect(found?.excluded, <String>['F5:clean']);
      final editedDecks = <List<Card>>[
        <Card>[word(native: 'home')],
      ];
      final edited = course(editedDecks, 'xx');
      expect(AdmissionProfile.of(edited, map), isNull);
    });
  });
}
