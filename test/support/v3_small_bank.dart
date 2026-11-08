import 'package:fluenough/core/placement/item_registry.dart';

/// A small bank over the fixture's six decks: per deck two picks of each
/// direction, a typed word, a word built from tiles, a gap, a yes/no.
List<RegItem> smallV3Bank({Set<String>? formats}) {
  final out = <RegItem>[];
  for (var d = 0; d < 6; d++) {
    for (var j = 0; j < 4; j++) {
      final id = 'w-$d-$j';
      final word = 'x${'abcdef'[d]}${'abcdefghij'[j]}o';
      final options = <String>[
        'thing $d-$j',
        'other ${d}0$j',
        'else ${d}1$j',
        'more ${d}2$j',
      ];
      out.add(
        RegItem(
          id: '$id:F2',
          format: 'F2',
          cardId: id,
          deck: d,
          prompt: word,
          options: options,
          correct: 0,
          lemmas: <String>{'l$id'},
        ),
      );
      out.add(
        RegItem(
          id: '$id:F3',
          format: 'F3',
          cardId: 'p-$id',
          deck: d,
          prompt: 'thing $d-$j',
          options: <String>[word, 'yabo', 'yaco', 'yado'],
          correct: 0,
          lemmas: <String>{'lp$id'},
        ),
      );
      out.add(
        RegItem(
          id: '$id:F7',
          format: 'F7',
          cardId: 't-$id',
          deck: d,
          prompt: 'thing $d-$j',
          accepted: <String>[word],
          lemmas: <String>{'lt$id'},
        ),
      );
      out.add(
        RegItem(
          id: '$id:F4',
          format: 'F4',
          cardId: 'b-$id',
          deck: d,
          prompt: 'thing $d-$j',
          tiles: <String>['o', 'x', 'q', word.substring(1, 3)],
          answerTiles: <String>['x', word.substring(1, 3), 'o'],
          accepted: <String>[word],
          lemmas: <String>{'lb$id'},
        ),
      );
      out.add(
        RegItem(
          id: '$id:F21',
          format: 'F21',
          cardId: 'g-$id',
          deck: d,
          prompt: 'thing $d-$j',
          answerTiles: <String>['x', 'a', 'b', 'o'],
          accepted: <String>['a'],
          gapIndex: 1,
          lemmas: <String>{'lg$id'},
        ),
      );
      out.add(
        RegItem(
          id: '$id:F8',
          format: 'F8',
          cardId: 's-$id',
          deck: d,
          prompt: 'a sentence $d-$j',
          tiles: <String>['mo', 'ba', 'ku', 'zi', 'le'],
          answerTiles: <String>['ba', 'mo', 'ku'],
          lemmas: <String>{'ls$id'},
        ),
      );
      out.add(
        RegItem(
          id: '$id:F1',
          format: 'F1',
          cardId: 'y-$id',
          deck: d,
          prompt: word,
          lemmas: <String>{'ly$id'},
        ),
      );
    }
  }
  return <RegItem>[
    for (final i in out)
      if (formats == null || formats.contains(i.format)) i,
  ];
}
