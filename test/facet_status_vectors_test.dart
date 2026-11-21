// The facet status cases shared with the tools: tools/test_review_facets.py
// reads the same file, so `facetStatus` here and `facet_status` in
// tools/review_facets.py stay equal (ADR-0058, W9).

import 'dart:convert';
import 'dart:io';

import 'package:fluenough/core/review/facets.dart';
import 'package:fluenough/core/review/review_quorum.dart';
import 'package:flutter_test/flutter_test.dart';

ReviewCheck _check(Map<String, Object?> json) {
  final answer = json['answer'];
  final tier = json['tier'] == 'verified'
      ? ReviewerTier.verified
      : ReviewerTier.provisional;
  if (answer == 'right') {
    return ReviewCheck(rater: json['rater']! as String, tier: tier);
  }
  final map = answer! as Map<String, Object?>;
  return ReviewCheck(
    rater: json['rater']! as String,
    tier: tier,
    answer: FacetAnswer.flagged(<PointerTag>{
      for (final wire in map['tags']! as List<Object?>)
        PointerTag.fromWire(wire)!,
    }, replacement: map['fix'] as String?),
  );
}

void main() {
  final file = File('test/support/facet_status_cases.json');
  final cases =
      (jsonDecode(file.readAsStringSync()) as Map<String, Object?>)['cases']!
          as List<Object?>;

  test('there are cases', () => expect(cases.length, greaterThan(10)));

  for (final raw in cases) {
    final json = raw! as Map<String, Object?>;
    test(json['name']! as String, () {
      final checks = <ReviewCheck>[
        for (final c in json['checks']! as List<Object?>)
          _check(c! as Map<String, Object?>),
      ];
      final needsVerified = json['needs_verified'] == true;
      expect(
        facetStatus(
          checks,
          needsVerified: needsVerified,
          language: json['language'] as String?,
        ).name,
        (json['status']! as String).replaceAll('_f', 'F'),
      );
      expect(
        facetReachedQuorum(checks, needsVerified: needsVerified),
        json['settled'],
      );
    });
  }
}
