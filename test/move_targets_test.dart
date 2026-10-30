import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/move_targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const path = CoursePath(
    id: 'xx-path',
    language: 'xx',
    native: 'en',
    units: <List<String>>[
      <String>['xx-en-about'],
      <String>['xx-en-family', 'xx-en-grammar'],
    ],
    alphabet: <String>{'xx-en-script'},
    plan: <PlanUnit>[
      PlanUnit(decks: <String>['xx-en-script']),
      PlanUnit(decks: <String>['xx-en-about']),
      PlanUnit(
        planned: PlannedDeck(id: 'xx-health', theme: 'health'),
      ),
      PlanUnit(decks: <String>['xx-en-family', 'xx-en-grammar']),
    ],
  );

  String? nameOf(String id) => const <String, String>{
    'xx-en-script': 'Script',
    'xx-en-about': 'About me',
    'xx-en-family': 'Family',
    'xx-en-grammar': 'Grammar',
  }[id];

  List<MoveTarget> targets(String from) => moveTargets(
    path,
    from: from,
    nameOf: nameOf,
    isVocab: (id) => id != 'xx-en-grammar',
  );

  test('offers only the plan\'s vocabulary decks, never the deck it is in', () {
    final offered = targets('xx-en-about').where((t) => !t.planned);
    expect(offered.map((t) => t.deckId), <String>['xx-en-family']);
    expect(offered.single.unit, 4);
    expect(offered.single.name, 'Family');
  });

  test('shows a planned unit, marked, and never a script or grammar deck', () {
    final all = targets('xx-en-family');
    expect(all.map((t) => t.deckId), <String>['xx-en-about', 'xx-health']);
    expect(all.last.planned, isTrue);
    expect(all.last.unit, 3);
  });

  test('finds the unit a deck is in', () {
    expect(unitNumberOf(path, 'xx-en-family'), 4);
    expect(unitNumberOf(path, 'xx-en-none'), isNull);
  });

  test('a move round trips through the review file with its label', () {
    const s = Suggestion(
      part: CardPart.place,
      now: 'xx-en-about',
      text: 'xx-en-family',
      label: 'Unit 4 · Family',
      why: 'It is a family word.',
    );
    final back = Suggestion.fromJson(s.toJson())!;
    expect(back.part, CardPart.place);
    expect(back.now, 'xx-en-about');
    expect(back.text, 'xx-en-family');
    expect(back.label, 'Unit 4 · Family');
    expect(back.why, 'It is a family word.');
  });
}
