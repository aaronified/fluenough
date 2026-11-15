// The culture part of a language's course line (Add a language) is filled by
// the cards of the language's culture decks in the deck index, up to
// `cultureCardTarget`; a language with none shows it empty.

import 'dart:convert';

import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

final String _hash = 'a' * 64;

Map<String, Object?> _shelf(
  String code,
  String deck,
  int cards, {
  String genre = 'culture',
  bool core = true,
}) => <String, Object?>{
  'cards': cards,
  'content_sha256': _hash,
  'deck': deck,
  'genre': genre,
  'kind': 'vocab',
  if (core) 'part': 'core',
  'path': 'decks/$code/$deck.yaml',
  'schema': 1,
  'sha256': _hash,
  'size': 10,
};

CatalogLanguage _language(String code, List<Map<String, Object?>> shelves) {
  final text = jsonEncode(<String, Object?>{
    'version': 1,
    'languages': <Object?>[
      <String, Object?>{
        'code': code,
        'name': code,
        'natives': <Object?>[
          <String, Object?>{'code': 'en', 'name': 'English'},
        ],
        'path': <String>[],
        'units': <Object?>[],
        'files': <Object?>[],
        'shelves': shelves,
      },
    ],
  });
  return CatalogLanguage.fromIndex(DeckIndex.parse(text).language(code)!);
}

void main() {
  group('the culture bar of the course line', () {
    test('is filled by the cards of the culture decks', () {
      final language = _language('zz', <Map<String, Object?>>[
        _shelf('zz', 'zz-culture-1', 18),
        _shelf('zz', 'zz-culture-2', 18),
      ]);
      expect(language.progressFor(<String>['en'])!.culture, 36 / 72);
    });

    test('counts a core once, not its layer, and only the culture genre', () {
      final language = _language('zz', <Map<String, Object?>>[
        _shelf('zz', 'zz-culture-1', 18),
        _shelf('zz', 'zz-en-culture-1', 18, core: false),
        _shelf('zz', 'zz-proverbs-1', 20, genre: 'proverbs'),
      ]);
      expect(language.progressFor(<String>['en'])!.culture, 18 / 72);
    });

    test('is empty for a language without culture decks', () {
      final language = _language('zz', <Map<String, Object?>>[]);
      expect(language.progressFor(<String>['en'])!.culture, 0);
    });

    test('never passes full', () {
      final language = _language('zz', <Map<String, Object?>>[
        _shelf('zz', 'zz-culture-1', 500),
      ]);
      expect(language.progressFor(<String>['en'])!.culture, 1);
    });
  });
}
