import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/notes/note_rotation.dart';

CardNote note(String id) =>
    CardNote(id: id, kind: NoteKind.usage, text: 'About $id');

void main() {
  test('every note of a card shows once before any repeats', () {
    final rotation = NoteRotation(Random(7));
    final notes = <CardNote>[note('a'), note('b'), note('c'), note('d')];
    for (var round = 0; round < 5; round++) {
      final shown = <String>[
        for (var i = 0; i < notes.length; i++)
          rotation.next('zz-0001', notes)!.id,
      ];
      expect(shown.toSet(), <String>{
        'a',
        'b',
        'c',
        'd',
      }, reason: 'round $round');
    }
  });

  test('a round never starts with the note that ended the last', () {
    final rotation = NoteRotation(Random(3));
    final notes = <CardNote>[note('a'), note('b'), note('c')];
    String? previous;
    for (var round = 0; round < 40; round++) {
      final ids = <String>[
        for (var i = 0; i < notes.length; i++)
          rotation.next('zz-0001', notes)!.id,
      ];
      if (previous != null) expect(ids.first, isNot(previous));
      previous = ids.last;
    }
  });

  test('a card with two notes alternates; with one, it repeats it', () {
    final rotation = NoteRotation(Random(1));
    final two = <CardNote>[note('a'), note('b')];
    final ids = <String>[
      for (var i = 0; i < 6; i++) rotation.next('zz-0001', two)!.id,
    ];
    for (var i = 1; i < ids.length; i++) {
      expect(ids[i], isNot(ids[i - 1]));
    }
    final one = <CardNote>[note('only')];
    expect(rotation.next('zz-0002', one)!.id, 'only');
    expect(rotation.next('zz-0002', one)!.id, 'only');
  });

  test('cards keep their own rounds', () {
    final rotation = NoteRotation(Random(5));
    final notes = <CardNote>[note('a'), note('b')];
    final first = rotation.next('zz-0001', notes)!.id;
    final other = rotation.next('zz-0002', notes)!.id;
    final second = rotation.next('zz-0001', notes)!.id;
    expect(<String>{first, second}, <String>{'a', 'b'});
    expect(rotation.next('zz-0002', notes)!.id, isNot(other));
  });

  test('a note added to a card is due, and a dropped one is forgotten', () {
    final rotation = NoteRotation(Random(2));
    final two = <CardNote>[note('a'), note('b')];
    rotation.next('zz-0001', two);
    rotation.next('zz-0001', two);
    final three = <CardNote>[...two, note('c')];
    expect(rotation.next('zz-0001', three)!.id, 'c');
    final dropped = <CardNote>[note('b'), note('c')];
    final next = <String>{
      rotation.next('zz-0001', dropped)!.id,
      rotation.next('zz-0001', dropped)!.id,
    };
    expect(next, <String>{'b', 'c'});
  });

  test('no notes, no note', () {
    expect(NoteRotation(Random(0)).next('zz-0001', const <CardNote>[]), isNull);
  });
}
