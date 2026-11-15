import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/situations_parser.dart';
import 'package:fluenough/core/models/situation.dart';
import 'package:fluenough/features/situations/situation_visuals.dart';

void main() {
  test('every icon key has its own icon, and an unknown key a plain one', () {
    final icons = <IconData>{
      for (final key in situationIcons) key.situationIcon,
    };
    expect(icons.length, situationIcons.length);
    expect('boat'.situationIcon, Icons.chat_bubble_outline);
    expect(icons, isNot(contains(Icons.chat_bubble_outline)));
  });

  test('a situations file parses with each new key once', () {
    const keys = <String>[
      'hotel',
      'post',
      'bank',
      'greeting',
      'emergency',
      'school',
      'work',
      'travel',
    ];
    final text = StringBuffer('''
schema: 1
id: zz-situations
name: "Testlang situations"
kind: situations
language: { code: zz, iso639_3: zzz, name: Testlang, script: latin, tts: es-ES }
license: "CC-BY-SA-4.0"
situations:
''');
    for (final key in keys) {
      text.writeln('  - id: $key');
      text.writeln('    icon: $key');
      text.writeln('    title: { en: "$key" }');
      text.writeln('    phrases: ["zz-0001"]');
    }
    final file = parseSituations(text.toString(), source: 'zz-situations.yaml');
    expect(file.situations.map((s) => s.icon), keys);
    for (final key in keys) {
      expect(situationIcons, contains(key));
      expect(file.withIcon(key)?.id, key);
    }
  });

  test('a course with no sheets shows the first six buttons only', () {
    expect(firstSituationIcons.length, 6);
    expect(situationIcons.take(6), firstSituationIcons);
    expect(situationIcons.toSet().length, situationIcons.length);
  });
}
