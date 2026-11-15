// The stored admission verdict holds one entry per deck source (#1270): a
// language audited on its frozen decks and on its live decks gets the verdict
// of whichever the phone has, and a deck change of one source leaves the
// other's verdict in place. Pure logic, no decks read.
import 'package:fluenough/core/models/card.dart';
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
}
