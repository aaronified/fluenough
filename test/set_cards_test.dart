// Set cards (DECK-FORMAT.md, Set cards; #506, #515): a closed group shown
// together in a lesson before its new members are drilled. Read from a
// vocab core and its layer, never into a deck's cards; its members by ref,
// or a rule and one value of its table ("Rule + axis", owner, 2026-10-16).
//
// The fixtures are the valid example set, test/fixtures/b1/appendix-a/zz,
// with set cards added, and cards made here for the lesson's order.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/card_sets.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/models/aksharas.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/card_set.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/rule.dart';
import 'package:fluenough/core/scheduling/lesson.dart';
import 'package:fluenough/core/scheduling/lesson_sets.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';

const appendix = 'test/fixtures/b1/appendix-a/zz';

String read(String path) => File(path).readAsStringSync();

final homeCore = read('$appendix/zz-home.yaml');
final homeLayer = read('$appendix/en/zz-en-home.yaml');

/// Three of the home deck's words, as one set.
const refSet = '''
  - id: "zz-9201"
    kind: "set"
    members: [{ ref: "zz-9001" }, { ref: "zz-9004" }, { ref: "zz-9006" }]
''';

/// One noun of the case table across its slots, and one slot across its
/// nouns.
const ruleSets = '''
  - id: "zz-9202"
    kind: "set"
    members: { rule: "zz-grammar-case-endings", noun: "అమ్మ" }
  - id: "zz-9203"
    kind: "set"
    members: { rule: "zz-rule-lo", case: "lo" }
''';

String coreWith(String sets) => '$homeCore$sets';

String layerWith(Map<String, (String, String)> texts) => homeLayer.replaceFirst(
  'cards:\n',
  <String>[
    'cards:',
    for (final MapEntry(key: id, value: (name, explanation))
        in texts.entries) ...<String>[
      '  "$id":',
      '    native: "$name"',
      '    explanation: "$explanation"',
    ],
    '',
  ].join('\n'),
);

const texts = <String, (String, String)>{
  'zz-9201': ('Three first words', 'Three words you meet first.'),
  'zz-9202': ('Mother: every case', 'One noun, అమ్మ (amma), in every case.'),
  'zz-9203': ('In: every noun', 'One ending, -లో (-lō), on every noun.'),
};

Matcher fails(String why) => throwsA(
  isA<DeckParseException>().having((e) => e.message, 'message', contains(why)),
);

Card word(String id, String target, {String? reading}) => Card(
  id: id,
  deckId: 'xx-en-a',
  target: target,
  native: 'meaning of $target',
  reading: reading,
);

/// A rules cell of row [row], slot [slot], as the expander makes it.
Card cell(String row, String slot, String target) => Card(
  id: 'te-grammar-verb-present-$row-$slot',
  deckId: 'te-en-grammar-verb-present',
  target: target,
  native: '$row $slot',
  modes: const <DrillMode>{DrillMode.grammar},
  rule: RuleCell(
    ruleId: 'te-rule-present',
    word: 'te-$row',
    wordTarget: row,
    slot: slot,
  ),
);

CardSet ruleSet(
  String id,
  String axis,
  String value, {
  String rule = 'te-grammar-verb-present',
}) => CardSet(
  id: id,
  deckId: 'te-en-verbs',
  name: id,
  explanation: '',
  rule: SetRule(rule: rule, axis: axis, value: value),
);

/// The rules of the core te-grammar-verb-present: one, here.
Set<String> rulesOf(String core) => <String>{'te-rule-present'};

void main() {
  group('the deck format', () {
    test('a set card is read into the deck\'s sets, not its cards', () {
      final deck = mergeLayer(
        DeckParser.parseCore(coreWith(refSet + ruleSets), source: 'c.yaml'),
        DeckParser.parseLayer(layerWith(texts), source: 'l.yaml'),
        source: 'l.yaml',
      );
      expect(deck.cards.map((c) => c.id), isNot(contains('zz-9201')));
      expect(deck.sets.map((s) => s.id), ['zz-9201', 'zz-9202', 'zz-9203']);
      final words = deck.sets.first;
      expect(words.name, 'Three first words');
      expect(words.explanation, 'Three words you meet first.');
      expect(words.members, ['zz-9001', 'zz-9004', 'zz-9006']);
      expect(words.rule, isNull);
      final noun = deck.sets[1].rule!;
      expect(
        (noun.rule, noun.axis, noun.value, noun.fixesRow),
        ('zz-grammar-case-endings', 'noun', 'అమ్మ', true),
      );
      expect(deck.sets[2].rule!.fixesRow, isFalse);
      // A deck's set survives its cards being replaced, as refs resolve.
      expect(deck.withCards(const <Card>[]).sets, hasLength(3));
    });

    test('a layer that does not name a set does not teach it', () {
      final deck = mergeLayer(
        DeckParser.parseCore(coreWith(refSet), source: 'c.yaml'),
        DeckParser.parseLayer(homeLayer, source: 'l.yaml'),
        source: 'l.yaml',
      );
      expect(deck.sets, isEmpty);
    });

    test('its layer gives its name and its explanation', () {
      final core = DeckParser.parseCore(coreWith(refSet), source: 'c.yaml');
      expect(
        () => mergeLayer(
          core,
          DeckParser.parseLayer(
            homeLayer.replaceFirst(
              'cards:\n',
              'cards:\n  "zz-9201":\n    native: "Words"\n',
            ),
            source: 'l.yaml',
          ),
          source: 'l.yaml',
        ),
        fails('explanation is required'),
      );
      expect(
        () => mergeLayer(
          DeckParser.parseCore(homeCore, source: 'c.yaml'),
          DeckParser.parseLayer(
            homeLayer.replaceFirst(
              '    native: "mother"\n',
              '    native: "mother"\n    explanation: "x"\n',
            ),
            source: 'l.yaml',
          ),
          source: 'l.yaml',
        ),
        fails('explanation is only for a set card'),
      );
    });

    test('a set card has only id, kind and members, two or more', () {
      expect(
        () => DeckParser.parseCore(
          coreWith('$refSet    target: "x"\n'),
          source: 'c.yaml',
        ),
        fails('a set card has only id, kind and members'),
      );
      expect(
        () => DeckParser.parseCore(
          coreWith('''
  - id: "zz-9201"
    kind: "set"
    members: [{ ref: "zz-9001" }]
'''),
          source: 'c.yaml',
        ),
        fails('a set has at least 2 members'),
      );
      expect(
        () => DeckParser.parseCore(
          coreWith('''
  - id: "zz-9201"
    kind: "set"
    members: { rule: "zz-rule-lo", case: "lo", noun: "అమ్మ" }
'''),
          source: 'c.yaml',
        ),
        fails("a rule's set fixes one value of its table"),
      );
    });

    test('a single-file deck has no set card', () {
      expect(
        () => DeckParser.parse('''
schema: 1
id: zz-en-extra
name: Extra
language: { code: zz, iso639_3: zzz, name: Testlang, script: telugu }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: zz-9201, kind: set, members: [{ ref: zz-9001 }, { ref: zz-9004 }] }
''', source: 'x.yaml'),
        fails('a set card is written in a vocab core'),
      );
    });
  });

  group('parts of at most four', () {
    test('the fewest even parts, in order', () {
      List<int> sizes(int n) => <int>[
        for (final part in setParts(List<int>.generate(n, (i) => i)))
          part.length,
      ];
      expect(sizes(3), [3]);
      expect(sizes(4), [4]);
      expect(sizes(5), [3, 2]);
      expect(sizes(6), [3, 3]);
      expect(sizes(8), [4, 4]);
      expect(sizes(9), [3, 3, 3]);
      expect(sizes(12), [4, 4, 4]);
      expect(
        setParts(List<int>.generate(9, (i) => i)).expand((p) => p),
        List<int>.generate(9, (i) => i),
      );
    });
  });

  group('members', () {
    final cells = <Card>[
      for (final row in ['tagu', 'cudu'])
        for (final slot in ['nenu', 'atanu', 'please'])
          cell(row, slot, '$row-$slot'),
    ];

    test('a row across its slots, in slot order; a slot across its rows', () {
      List<String> of(CardSet set) => <String>[
        for (final c in setMembers(set, cells, ruleOf: rulesOf)) c.target,
      ];
      expect(of(ruleSet('v', 'verb', 'tagu')), [
        'tagu-nenu',
        'tagu-atanu',
        'tagu-please',
      ]);
      expect(of(ruleSet('v', 'verb', 'te-cudu')), [
        'cudu-nenu',
        'cudu-atanu',
        'cudu-please',
      ]);
      expect(of(ruleSet('p', 'person', 'atanu')), ['tagu-atanu', 'cudu-atanu']);
      // A rule id names its own cells; a core id those of its rules.
      expect(
        setMembers(
          ruleSet('p', 'person', 'atanu', rule: 'te-rule-present'),
          cells,
        ),
        hasLength(2),
      );
      expect(setMembers(ruleSet('p', 'person', 'atanu'), cells), isEmpty);
    });

    test('refs in the set\'s order; a ref no card is left out', () {
      final cards = [word('a-1', 'a'), word('a-2', 'b'), word('a-3', 'c')];
      const set = CardSet(
        id: 's',
        deckId: 'd',
        name: 'n',
        explanation: 'e',
        members: ['a-3', 'a-9', 'a-1'],
      );
      expect(setMembers(set, cards).map((c) => c.id), ['a-3', 'a-1']);
    });
  });

  group('a lesson with sets', () {
    // Hindi: आप (āp), तुम (tum) known, तू (tū).
    final ap = word('hi-1', 'आप', reading: 'āp');
    final tum = word('hi-2', 'तुम', reading: 'tum');
    final tu = word('hi-3', 'तू', reading: 'tū');
    final other = word('hi-4', 'घर', reading: 'ghar');
    final you = ResolvedSet(
      set: const CardSet(
        id: 'hi-9001',
        deckId: 'hi-en-a',
        name: 'You',
        explanation: 'Three words for you.',
      ),
      members: [ap, tum, tu],
    );

    test('the set first, whole, with its known member marked; only the new '
        'members drilled', () {
      final lesson = lessonSets(
        [ap, other],
        sets: [you],
        isNew: (c) => c != tum,
        isKnown: (c) => c == tum,
      );
      expect(lesson.parts, hasLength(1));
      final part = lesson.parts.single;
      expect(part.members, [ap, tum, tu]);
      expect(part.isKnown(tum), isTrue);
      expect(part.isKnown(ap), isFalse);
      expect(part.isSplit, isFalse);
      // तू (tū) comes with आप (āp), though the lesson did not pick it.
      expect(lesson.cards, [ap, tu, other]);
      expect(lesson.members, {'hi-1', 'hi-3'});
    });

    test('a set with no new member, or none picked, is not shown', () {
      expect(
        lessonSets(
          [other],
          sets: [you],
          isNew: (c) => true,
          isKnown: (c) => false,
        ).parts,
        isEmpty,
      );
      expect(
        lessonSets(
          [tum],
          sets: [you],
          isNew: (c) => false,
          isKnown: (c) => true,
        ).parts,
        isEmpty,
      );
    });

    // Telugu: one verb across nine forms, the request last, then one
    // person across six verbs: both sets, then drills.
    const slots = [
      'nenu',
      'memu',
      'manam',
      'nuvvu',
      'miru',
      'atanu',
      'ame-adi',
      'vallu',
      'please',
    ];
    const verbs = ['ceyu', 'vellu', 'ra', 'tinu', 'tagu', 'cudu'];
    final table = <Card>[
      for (final verb in verbs)
        for (final slot in slots) cell(verb, slot, '$verb-$slot'),
    ];
    Card form(String verb, String slot) =>
        table.firstWhere((c) => c.target == '$verb-$slot');
    final fresh = <Card>{
      form('tagu', 'atanu'),
      form('tagu', 'ame-adi'),
      form('tagu', 'please'),
      form('cudu', 'atanu'),
    };
    // Listed person first: the order comes from the lesson, not the deck.
    final person = ResolvedSet(
      set: ruleSet('person', 'person', 'atanu'),
      members: setMembers(
        ruleSet('person', 'person', 'atanu'),
        table,
        ruleOf: rulesOf,
      ),
    );
    final verb = ResolvedSet(
      set: ruleSet('verb', 'verb', 'tagu'),
      members: setMembers(
        ruleSet('verb', 'verb', 'tagu'),
        table,
        ruleOf: rulesOf,
      ),
    );

    LessonSets telugu(List<Card> picked) => lessonSets(
      picked,
      sets: [person, verb],
      isNew: fresh.contains,
      isKnown: (c) => !fresh.contains(c),
    );

    test('the verb set, then the person set, every part, all-known parts '
        'too', () {
      final lesson = telugu([form('tagu', 'atanu')]);
      expect(
        lesson.parts.map(
          (p) => (p.set.set.id, p.index, p.count, p.members.length),
        ),
        [
          ('verb', 0, 3, 3),
          ('verb', 1, 3, 3),
          ('verb', 2, 3, 3),
          ('person', 0, 2, 3),
          ('person', 1, 2, 3),
        ],
      );
      // The first part holds only known forms, and is still shown.
      expect(
        lesson.parts.first.members.every(lesson.parts.first.isKnown),
        isTrue,
      );
      // The request is last in the verb set.
      expect(lesson.parts[2].members.last, form('tagu', 'please'));
      // The verb set's last part names the next set; the last the forms.
      expect(lesson.parts[2].next?.set.id, 'person');
      expect(lesson.parts.last.next, isNull);
      expect(lesson.parts.last.lessonNew, [
        form('tagu', 'atanu'),
        form('tagu', 'ame-adi'),
        form('tagu', 'please'),
        form('cudu', 'atanu'),
      ]);
    });

    test('the verb set first, even when a form only the person set has '
        'was picked first', () {
      final lesson = telugu([form('cudu', 'atanu'), form('tagu', 'atanu')]);
      expect(lesson.parts.map((p) => p.set.set.id).toSet().toList(), [
        'verb',
        'person',
      ]);
      expect(lesson.parts.first.set.set.id, 'verb');
      expect(lesson.parts.last.set.set.id, 'person');
    });

    test('every new form is taught, past the cap, each once', () {
      final lesson = telugu([form('tagu', 'atanu')]);
      expect(lesson.cards, [
        form('tagu', 'atanu'),
        form('tagu', 'ame-adi'),
        form('tagu', 'please'),
        form('cudu', 'atanu'),
      ]);
      expect(lesson.members, hasLength(4));
    });

    test('a form a set taught goes straight to its question', () {
      final lesson = telugu([form('tagu', 'atanu')]);
      final items = lessonPlan(
        lesson.cards,
        modesOf: (_) => const {DrillMode.grammar},
        canChoose: (_, _) => false,
        straightToQuestion: (c) => lesson.members.contains(c.id),
      );
      expect(items.where((i) => i.ask == Ask.teach), isEmpty);
      expect(items.map((i) => i.card).toSet(), lesson.cards.toSet());
      // A word keeps its New card.
      final words = lessonPlan(
        [ap],
        modesOf: (_) => const {DrillMode.recognition},
        canChoose: (_, _) => false,
      );
      expect(words.first.ask, Ask.teach);
    });

    test('a set part records nothing and counts what the set teaches', () {
      final lesson = telugu([form('tagu', 'atanu')]);
      final items = <SessionItem>[
        for (final part in lesson.parts)
          SessionItem.set(part, DrillMode.recognition),
        ...lessonPlan(
          lesson.cards,
          modesOf: (_) => const {DrillMode.grammar},
          canChoose: (_, _) => false,
          straightToQuestion: (c) => lesson.members.contains(c.id),
        ),
      ];
      expect(items.first.ask, Ask.showSet);
      expect(items.first.ask.onlyShows, isTrue);
      expect(items.first.card, lesson.parts.first.members.first);
      expect(lessonCardCount(items), 4);
    });
  });

  group('the app', () {
    Future<AppState> loaded() async {
      final files = <String, String>{
        for (final file in Directory(appendix).listSync(recursive: true))
          if (file is File && file.path.endsWith('.yaml'))
            'decks/zz/${file.path.substring(appendix.length + 1)}': file
                .readAsStringSync(),
      };
      files['decks/zz/zz-home.yaml'] = coreWith(refSet + ruleSets);
      files['decks/zz/en/zz-en-home.yaml'] = layerWith(texts);
      final state = AppState.test(
        decks: MemoryDeckSource(files),
        progress: MemoryProgress(),
      );
      await state.load();
      return state;
    }

    test('a course\'s sets are resolved against its cards and cells', () async {
      final state = await loaded();
      final sets = state.courseSets('zz', 'en');
      expect(sets.map((s) => s.set.id), ['zz-9201', 'zz-9202', 'zz-9203']);
      expect(sets[0].members.map((c) => c.target), ['ఇల్లు', 'అమ్మ', 'నేను']);
      expect(sets[1].members.map((c) => c.target), [
        'అమ్మలో',
        'అమ్మకి',
        'అమ్మతో',
        'అమ్మ నుంచి',
      ]);
      expect(sets[2].members.map((c) => c.target), ['ఇంట్లో', 'అమ్మలో']);
    });

    test(
      'a lesson shows the set first and teaches all its new members',
      () async {
        final state = await loaded();
        final items = state.lessonFor(
          DrillRequest.lesson(language: 'zz', deckId: 'zz-en-home'),
        );
        expect(items.first.ask, Ask.showSet);
        expect(items.first.setPart!.set.set.id, 'zz-9201');
        final taught = <String>{for (final i in items) i.card.id};
        expect(taught, containsAll(<String>['zz-9001', 'zz-9004', 'zz-9006']));
        expect(state.progress.log, isEmpty);
      },
    );

    test('a slot across the words holds only the words taught', () async {
      final state = await loaded();
      final byLo = state.courseSets('zz', 'en')[2];
      expect(state.forLearner(byLo), isNull);
      final home = state.deckById('zz-en-home')!;
      state.record(
        SessionItem(
          card: home.cards.firstWhere((c) => c.id == 'zz-9001'),
          mode: DrillMode.recognition,
          state: null,
        ),
        4,
      );
      state.record(
        SessionItem(
          card: home.cards.firstWhere((c) => c.id == 'zz-9004'),
          mode: DrillMode.recognition,
          state: null,
        ),
        4,
      );
      expect(state.forLearner(byLo)!.members, hasLength(2));
      // Neither set is split, so no question shows a Full list.
      expect(state.splitSetsOf(byLo.members.first), isEmpty);
    });
  });

  group('aksharas', () {
    test('a line breaks only between aksharas, never inside one', () {
      expect(aksharasOf('తాగుతుంది'), ['తా', 'గు', 'తుం', 'ది']);
      expect(aksharasOf('చూస్తాడు'), ['చూ', 'స్తా', 'డు']);
      expect(aksharasOf('क्षत्रिय'), ['क्ष', 'त्रि', 'य']);
      expect(aksharasOf('আপনি'), ['আ', 'প', 'নি']);
      expect(aksharasOf('తాగుతుంది').join(), 'తాగుతుంది');
      expect(breakableWord('తాగుతుంది'), 'తా​గు​తుం​ది');
      // Short words, and text with spaces, are left as they are.
      expect(breakableWord('తాగు'), 'తాగు');
      expect(breakableWord('ఇంటి నుంచి'), 'ఇంటి నుంచి');
    });
  });
}
