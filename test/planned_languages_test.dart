import 'dart:convert';
import 'dart:io';

import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:flutter_test/flutter_test.dart';

/// The planned languages of assets/languages.yaml (#959): entries with no
/// decks yet, whose families and scripts the app can name.
void main() {
  final all = parseSpokenLanguages(
    File('assets/languages.yaml').readAsStringSync(),
  );
  final arb =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
  Set<String> selectIds(String key) {
    final text = arb[key] as String;
    return RegExp(r'(\w+)\{').allMatches(text).map((m) => m.group(1)!).toSet();
  }

  final planned =
      'pt it ca sv nb yi ru pl hbs el he fi hu tr eu ga ar yue th vi fil ms '
              'sw ha so qu gmy sux egy ine vsn la ang enm ins ase tlh sjn qya '
              'qdo qhv'
          .split(' ');

  test('every planned language is listed once', () {
    final codes = all.map((l) => l.code).toList();
    expect(codes.toSet().length, codes.length, reason: 'codes are unique');
    expect(codes, containsAll(planned));
  });

  test('a language with no ISO code takes a private-use one', () {
    for (final code in ['qdo', 'qhv']) {
      final l = all.singleWhere((l) => l.code == code);
      expect(l.iso639_3, code);
      expect(
        code.compareTo('qaa') >= 0 && code.compareTo('qtz') <= 0,
        isTrue,
        reason: '$code is in qaa to qtz',
      );
    }
  });

  test('a sign language has no script to ask about', () {
    for (final code in ['ins', 'ase']) {
      final l = all.singleWhere((l) => l.code == code);
      expect(l.family, 'sign');
      expect(l.scripts, isEmpty);
    }
  });

  test('every family and script of the list is named in the app', () {
    final families = selectIds('knownFamily');
    final scripts = selectIds('scriptName');
    for (final l in all) {
      if (l.family != null) {
        expect(families, contains(l.family), reason: '${l.code} family');
      }
      for (final s in l.scripts) {
        expect(scripts, contains(s), reason: '${l.code} script $s');
      }
    }
  });
}
