// The answer grader counts user-perceived characters with the `characters`
// package, not Flutter's re-export of it. They are the same implementation,
// so the count the typo allowance sees is unchanged.

import 'package:characters/characters.dart' as pkg;
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Counts fixed by the Unicode rules, whatever the version of the tables.
  const known = <String, int>{
    'gracias': 7, // plain ASCII
    '[ɛ̃ˈbɑ̃]': 6, // IPA: [ ɛ̃ ˈ b ɑ̃ ], the tildes are combining marks
    '👨‍👩‍👧': 1, // emoji ZWJ sequence
  };

  // Indic text: the count follows the package's tables, so only parity with
  // Flutter's extension is asserted.
  const indic = ['বাংলা', 'ক্ষমা', 'తెలుగు', 'స్త్రీ', 'हिन्दी', 'क्षत्रिय'];

  group('grapheme counting', () {
    known.forEach((text, expected) {
      test('"$text" is $expected user-perceived characters', () {
        expect(pkg.StringCharacters(text).characters.length, expected);
      });
    });

    for (final text in [...known.keys, ...indic]) {
      test('"$text" counts the same as Flutter\'s extension', () {
        expect(
          pkg.StringCharacters(text).characters.length,
          widgets.StringCharacters(text).characters.length,
        );
      });
    }
  });
}
