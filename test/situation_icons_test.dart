import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('the keys are unique and start with the first six', () {
    expect(situationIcons.toSet().length, situationIcons.length);
    expect(situationIcons.take(6), firstSituationIcons);
    expect(
      situationIcons.skip(6),
      <String>[
        'hotel',
        'post',
        'bank',
        'greeting',
        'emergency',
        'school',
        'work',
        'travel',
      ],
    );
  });
}
