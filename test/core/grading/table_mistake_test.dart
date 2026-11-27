import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/grading/table_mistake.dart';
import 'package:fluenough/core/models/grammar_pattern.dart';

const List<String> _slots = <String>['yo', 'tú', 'él', 'nosotros'];

const PatternEntry _hablar = PatternEntry(
  lemma: 'hablar',
  gloss: 'to speak',
  forms: <String, String?>{
    'yo': 'hablo',
    'tú': 'hablas',
    'él': 'habla',
    'nosotros': 'hablamos',
  },
  alternatives: <String, List<String>>{
    'nosotros': <String>['hablemos'],
  },
);

/// A row that spells two cells alike, and has one without a form.
const PatternEntry _alike = PatternEntry(
  lemma: 'ser',
  gloss: 'to be',
  forms: <String, String?>{
    'yo': 'era',
    'tú': 'eras',
    'él': 'era',
    'nosotros': null,
  },
);

TableMistake? _read(String given, String asked, [PatternEntry? entry]) {
  return readTableMistake(
    given: given,
    entry: entry ?? _hablar,
    slots: _slots,
    asked: asked,
  );
}

void main() {
  group('readTableMistake', () {
    test('the form of another cell names that cell', () {
      final mistake = _read('hablamos', 'yo');
      expect(mistake?.kind, TableMistakeKind.otherCell);
      expect(mistake?.slots, <String>['nosotros']);
    });

    test('compares as the grader does: case, spacing, not accents', () {
      expect(_read('  Hablamos ', 'yo')?.slots, <String>['nosotros']);
      expect(_read('hablámos', 'yo'), isNull);
    });

    test('a cell spelled alike is named with all its slots', () {
      final mistake = _read('era', 'tú', _alike);
      expect(mistake?.kind, TableMistakeKind.otherCell);
      expect(mistake?.slots, <String>['yo', 'él']);
    });

    test('the asked cell is not named when it spells the same', () {
      // era is right for yo, so nothing to explain; for nosotros, which has
      // no form, it names yo and él.
      expect(_read('era', 'yo', _alike), isNull);
      expect(_read('era', 'nosotros', _alike)?.slots, <String>['yo', 'él']);
    });

    test('a form of the asked cell, or its alternative, is no mistake', () {
      expect(_read('hablo', 'yo'), isNull);
      expect(_read('hablemos', 'nosotros'), isNull);
    });

    test('only the listed form of another cell is read', () {
      // hablemos is an alternative of nosotros, not its form.
      expect(_read('hablemos', 'yo'), isNull);
    });

    test('the lemma is the uninflected word', () {
      final mistake = _read('hablar', 'tú');
      expect(mistake?.kind, TableMistakeKind.uninflected);
      expect(mistake?.slots, isEmpty);
    });

    test('another cell wins when the lemma is also its form', () {
      const same = PatternEntry(
        lemma: 'run',
        gloss: 'to run',
        forms: <String, String?>{'yo': 'run', 'él': 'runs'},
      );
      final mistake = readTableMistake(
        given: 'run',
        entry: same,
        slots: const <String>['yo', 'él'],
        asked: 'él',
      );
      expect(mistake?.kind, TableMistakeKind.otherCell);
      expect(mistake?.slots, <String>['yo']);
    });

    test('an answer found nowhere in the table is no match', () {
      expect(_read('hablan', 'yo'), isNull);
      expect(_read('', 'yo'), isNull);
      expect(_read('   ', 'yo'), isNull);
    });
  });
}
