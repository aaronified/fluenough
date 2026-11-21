// The comparison folds (ADR-0058, W5): per-script rules for deciding whether
// two typed fixes are the same. tools/test_review_facets.py reads the same
// vectors, so lib/core/review/script_folds.dart and tools/review_facets.py
// stay equal.

import 'dart:convert';
import 'dart:io';

import 'package:fluenough/core/review/fix_text.dart';
import 'package:fluenough/core/review/script_folds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final data = jsonDecode(
    File('test/support/comparison_fold_cases.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final pairs = (data['pairs']! as List<Object?>).cast<Map<String, Object?>>();
  final keys = (data['keys']! as List<Object?>).cast<Map<String, Object?>>();
  final folds = (data['folds']! as List<Object?>).cast<Map<String, Object?>>();

  test('there are vectors', () => expect(pairs.length, greaterThan(40)));

  for (final c in pairs) {
    test('pair: ${c['name']}', () {
      expect(
        sameFixIn(
          c['a']! as String,
          c['b']! as String,
          language: c['language'] as String?,
          caseInsensitive: c['case_insensitive'] == true,
        ),
        c['same'],
      );
    });
  }

  for (final c in keys) {
    test('key: ${c['name']}', () {
      expect(
        comparisonKey(
          c['text']! as String,
          language: c['language'] as String?,
          caseInsensitive: c['case_insensitive'] == true,
        ),
        c['key'],
      );
    });
  }

  test('the registry is the one the tools have', () {
    final mine = <Map<String, Object?>>[
      for (final f in comparisonFolds)
        <String, Object?>{
          'id': f.id,
          'languages': f.languages.toList()..sort(),
          'map': <String, Object?>{
            for (final e in f.map.entries)
              e.key.toRadixString(16).toUpperCase().padLeft(4, '0'): e.value
                  ?.toRadixString(16)
                  .toUpperCase()
                  .padLeft(4, '0'),
          },
        },
    ];
    expect(mine, folds);
  });

  test('a fold only maps to a variant form of the same letter or digit', () {
    final allowed = <int?>{
      0x06CC,
      0x06A9,
      null,
      for (var i = 0; i < 10; i++) 0x06F0 + i,
    };
    for (final f in comparisonFolds) {
      expect(f.map.values.toSet().difference(allowed), isEmpty, reason: f.id);
    }
  });

  test('the typed text is never changed', () {
    const typed = 'كـي ١';
    comparisonKey(typed, language: 'ur');
    expect(typed, 'كـي ١');
    expect(normalizeFixText(typed), typed);
  });

  test('a language with a region or other case still gets its folds', () {
    expect(primaryLanguage('ur-PK'), 'ur');
    expect(primaryLanguage('FA_ir'), 'fa');
    expect(primaryLanguage(''), isNull);
    expect(primaryLanguage(null), isNull);
  });
}
