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

  test('the shipped entries are keyed by distinct decks per language', () {
    for (final e in kAdmissionProfiles.entries) {
      final keys = e.value.map((p) => p.deckKey).toList();
      expect(keys.toSet().length, keys.length, reason: e.key);
    }
  });

  group('the key holds only what the audit reads', () {
    PlacementLanguageData base({
      List<PlacementDeck> extraDecks = const <PlacementDeck>[],
      List<Card> extraCards = const <Card>[],
      String native = 'house',
      String? reading,
    }) => PlacementLanguageData(
      language: 'xx',
      decks: <PlacementDeck>[
        PlacementDeck(
          id: 'xx-001',
          cards: <Card>[
            Card(
              id: 'xx-1',
              deckId: 'xx-001',
              target: 'casa',
              native: native,
              reading: reading,
              pos: 'noun',
            ),
            ...extraCards,
          ],
        ),
        ...extraDecks,
      ],
    );

    test(
      'a card the audit skips, or a deck of such cards, changes nothing',
      () {
      final plain = admissionKey(base());
      // A letter, a digit and a grammar cell are never read; a deck made only
      // of them is not either (it is appended, so no read card moves).
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
      expect(admissionKey(base(extraCards: skipped)), plain);
      expect(
        admissionKey(
          base(
            extraDecks: <PlacementDeck>[
              PlacementDeck(id: 'xx-002', cards: skipped),
            ],
          ),
        ),
        plain,
      );
      expect(plain, startsWith('1-'));
      },
    );

    test('fields the audit never reads change nothing', () {
      final plain = admissionKey(base());
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

    test('a card, field or order the audit reads changes the key', () {
      final plain = admissionKey(base());
      final read = Card(
        id: 'xx-2',
        deckId: 'xx-001',
        target: 'perro',
        native: 'dog',
      );
      expect(admissionKey(base(extraCards: <Card>[read])), isNot(plain));
      expect(admissionKey(base(native: 'home')), isNot(plain));
      expect(admissionKey(base(reading: 'kasa')), isNot(plain));
      // The same card in a later deck: its distance to its neighbours changed.
      final moved = PlacementLanguageData(
        language: 'xx',
        decks: <PlacementDeck>[
          const PlacementDeck(id: 'xx-000', cards: <Card>[]),
          base().decks.first,
        ],
      );
      expect(admissionKey(moved), isNot(plain));
      // Another language is another audit.
      expect(
        admissionKey(
          PlacementLanguageData(language: 'yy', decks: base().decks),
        ),
        isNot(plain),
      );
    });

    test('a verdict stored for the key is found for decks that differ only '
        'in what the audit does not read', () {
      final stored = base();
      final map = <String, List<AdmissionProfile>>{
        'xx': <AdmissionProfile>[
          AdmissionProfile(
            source: kLiveDecks,
            deckKey: admissionKey(stored),
            excluded: const <String>['F5:clean'],
            decoys: 2,
          ),
        ],
      };
      final merged = base(
        extraDecks: <PlacementDeck>[
          PlacementDeck(
            id: 'xx-culture',
            cards: <Card>[
              Card(
                id: 'xx-c',
                deckId: 'xx-culture',
                target: 'x',
                native: 'y',
                modes: DrillMode.vocabulary,
              ),
            ],
          ),
        ],
      );
      expect(AdmissionProfile.of(merged, map)?.excluded, <String>['F5:clean']);
      expect(AdmissionProfile.of(base(native: 'home'), map), isNull);
    });
  });
}
