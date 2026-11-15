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
    }) => Card(
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

    PlacementLanguageData course(
      List<List<Card>> decks, {
      String language = 'xx',
    }) => PlacementLanguageData(
      language: language,
      decks: <PlacementDeck>[
        for (final (i, cards) in decks.indexed)
          PlacementDeck(id: 'xx-00$i', cards: cards),
      ],
    );

    PlacementLanguageData one(Card card, [List<Card> more = const <Card>[]]) =>
        course(<List<Card>>[
          <Card>[card, ...more],
        ]);

    final skipped = <Card>[
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
      final plain = admissionKey(one(word()));
      expect(admissionKey(one(word(), skipped)), plain);
      expect(
        admissionKey(
          course(<List<Card>>[
            <Card>[word()],
            skipped,
          ]),
        ),
        plain,
      );
      expect(
        admissionKey(
          course(<List<Card>>[
            skipped,
            <Card>[word()],
          ]),
        ),
        plain,
        reason: 'a deck before every read card only offsets the others',
      );
      expect(plain, startsWith('1-'));
    });

    test('fields the audit never reads change nothing', () {
      final plain = admissionKey(one(word()));
      final decorated = PlacementLanguageData(
        language: 'xx',
        decks: <PlacementDeck>[
          PlacementDeck(
            id: 'xx-renamed',
            grammarFamilies: const <String>['plural'],
            cards: <Card>[
              Card(
                id: 'xx-1',
                deckId: 'xx-renamed',
                target: 'casa',
                native: 'house',
                pos: 'noun',
                ipa: '/ka.sa/',
                phonetic: '[ka.sa]',
                tags: const <String>['home'],
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
      final plain = admissionKey(one(word()));
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
        'base word': word(bases: const <CardBase>[CardBase(word: 'casa')]),
        'base': word(
          bases: const <CardBase>[CardBase(word: 'casa', base: 'cas')],
        ),
      };
      for (final e in changed.entries) {
        expect(admissionKey(one(e.value)), isNot(plain), reason: e.key);
      }
      final other = word(id: 'xx-2', target: 'perro', native: 'dog');
      expect(admissionKey(one(word(), <Card>[other])), isNot(plain));
      expect(
        admissionKey(one(word(), <Card>[other])),
        isNot(admissionKey(one(other, <Card>[word()]))),
        reason: 'order within a deck',
      );
      expect(
        admissionKey(one(word(), const <Card>[])),
        isNot(admissionKey(one(word(), <Card>[other]))),
      );
      expect(
        admissionKey(course(<List<Card>>[<Card>[word()]], language: 'yy')),
        isNot(plain),
        reason: 'another language is another audit',
      );
    });

    test('a deck between read cards, or a swap of decks, changes it', () {
      final a = word();
      final b = word(id: 'xx-2', target: 'perro', native: 'dog');
      final together = admissionKey(
        course(<List<Card>>[
          <Card>[a],
          <Card>[b],
        ]),
      );
      final apart = admissionKey(
        course(<List<Card>>[
          <Card>[a],
          skipped,
          <Card>[b],
        ]),
      );
      final swapped = admissionKey(
        course(<List<Card>>[
          <Card>[b],
          <Card>[a],
        ]),
      );
      expect(apart, isNot(together));
      expect(swapped, isNot(together));
    });

    test('the course turning non-Latin, or the near-span growing, changes the '
        'key', () {
      final latin = admissionKey(one(word()));
      // More letters of other scripts than Latin ones among all the cards,
      // the cards the audit skips included.
      final nonLatin = Card(
        id: 'xx-n',
        deckId: 'xx-001',
        target: 'कककककककक',
        native: 'many',
        pos: 'letter',
      );
      expect(admissionKey(one(word(), <Card>[nonLatin])), isNot(latin));
      // 72 decks have the span 6, 84 decks the span 7.
      PlacementLanguageData decks(int n) => course(<List<Card>>[
        <Card>[word()],
        for (var i = 1; i < n; i++) <Card>[],
      ]);
      expect(admissionKey(decks(72)), admissionKey(decks(73)));
      expect(admissionKey(decks(72)), isNot(admissionKey(decks(84))));
    });

    test('a verdict stored for the key is found for decks that differ only '
        'in what the audit does not read', () {
      final map = <String, List<AdmissionProfile>>{
        'xx': <AdmissionProfile>[
          AdmissionProfile(
            source: kLiveDecks,
            deckKey: admissionKey(one(word())),
            excluded: const <String>['F5:clean'],
            decoys: 2,
          ),
        ],
      };
      final merged = course(<List<Card>>[
        <Card>[word()],
        skipped,
      ]);
      expect(AdmissionProfile.of(merged, map)?.excluded, <String>['F5:clean']);
      expect(AdmissionProfile.of(one(word(native: 'home')), map), isNull);
    });
  });
}
