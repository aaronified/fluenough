// Cloze from sentence cards and examples (#321, slice 1 of the sentence
// building plan): the gap is always a known word, the options are other known
// words of its kind with nothing to tell the right one by, it is graded by the
// exact word, it is asked on its turn only, and placement never asks it.
import 'dart:io';
import 'dart:math';

import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/placement/v3_picker.dart' show kScreenFormats;
import 'package:fluenough/core/progress/cloze.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/question_type.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:flutter_test/flutter_test.dart';

Card _word(String id, String target, String pos, {String? reading}) => Card(
  id: id,
  deckId: 'es-words',
  target: target,
  native: 'native $id',
  pos: pos,
  reading: reading,
);

final Map<String, Card> _cards = <String, Card>{
  for (final card in <Card>[
    _word('es-yo', 'yo', 'pronoun'),
    _word('es-tengo', 'tengo', 'verb'),
    _word('es-quiero', 'quiero', 'verb'),
    _word('es-como', 'como', 'verb'),
    _word('es-un', 'un', 'adj'),
    _word('es-grande', 'grande', 'adj'),
    _word('es-perro', 'perro', 'noun'),
    _word('es-gato', 'gato', 'noun'),
    _word('es-casa', 'casa', 'noun'),
    _word('es-libro', 'libro', 'noun'),
    _word('es-universidad', 'universidad', 'noun'),
    _word('es-mesa', 'mesa', 'noun'),
    _word('es-pez', 'pez', 'noun'),
  ])
    card.id: card,
};

/// What the learner knows: not mesa, pez or grande.
const Set<String> _known = <String>{
  'es-yo',
  'es-tengo',
  'es-quiero',
  'es-como',
  'es-un',
  'es-perro',
  'es-gato',
  'es-casa',
  'es-libro',
  'es-universidad',
};

Card _sentence(
  String id,
  String target, {
  List<CardBase> bases = const <CardBase>[],
  List<CardExample> examples = const <CardExample>[],
  String? reading,
  Map<String, String> scripts = const <String, String>{},
}) => Card(
  id: id,
  deckId: 'es-sentences',
  target: target,
  native: 'native $id',
  pos: 'phrase',
  bases: bases,
  examples: examples,
  reading: reading,
  targetScripts: scripts,
);

final Card _dog = _sentence(
  'es-s1',
  'Yo tengo un perro grande.',
  bases: const <CardBase>[
    CardBase(word: 'tengo', ref: 'es-tengo'),
    CardBase(word: 'perro', ref: 'es-perro'),
  ],
);

ClozeBank _bank({int minKnown = kClozeMinKnown, Set<String> known = _known}) =>
    ClozeBank(
      cards: _cards.values,
      isKnown: known.contains,
      minKnown: minKnown,
    );

void main() {
  group('the gap', () {
    test('is always a known word, and never one the learner has not '
        'learnt', () {
      final bank = _bank();
      for (var seed = 0; seed < 60; seed++) {
        final cloze = bank.make(_dog, random: Random(seed));
        expect(cloze, isNotNull, reason: 'seed $seed');
        expect(_known, contains(cloze!.gap.word.id), reason: 'seed $seed');
        final view = cloze.view(firstScript: 'latin', random: Random(seed))!;
        final unknown = <String>{'mesa', 'pez', 'grande'};
        expect(view.options.where(unknown.contains), isEmpty);
      }
    });

    test('is only a word that has other known words of its kind to stand '
        'beside', () {
      // yo and un have no known pronoun or adjective beside them.
      final bank = _bank();
      final gaps = <String>{
        for (var seed = 0; seed < 60; seed++)
          bank.make(_dog, random: Random(seed))!.gap.word.id,
      };
      expect(gaps, <String>{'es-tengo', 'es-perro'});
    });

    test('is a word of the sentence, shown with the sentence around it', () {
      final bank = _bank();
      for (var seed = 0; seed < 20; seed++) {
        final view = bank
            .make(_dog, random: Random(seed))!
            .view(firstScript: 'latin', random: Random(seed))!;
        final whole = view.filled(view.answer);
        expect(whole.toLowerCase(), _dog.target.toLowerCase());
        expect(view.before + view.after, isNot(contains(view.answer)));
      }
    });

    test('needs at least three known words in the sentence', () {
      final bank = _bank();
      // tengo and un are known; pez is not.
      final two = _sentence('es-s2', 'Tengo un pez.');
      expect(bank.canAsk(two), isFalse);
      expect(bank.make(two, random: Random(1)), isNull);
      // yo, tengo and un are known; pez is not, but three are enough.
      final three = _sentence('es-s3', 'Yo tengo un pez.');
      expect(bank.canAsk(three), isTrue);
      expect(_bank(minKnown: 2).canAsk(two), isTrue);
    });

    test('is never made of a sentence whose words are not known', () {
      final bank = _bank(known: <String>{'es-gato', 'es-casa', 'es-libro'});
      expect(bank.canAsk(_dog), isFalse);
      expect(bank.make(_dog, random: Random(1)), isNull);
    });

    test('prefers a word as its card teaches it to an inflected one', () {
      final bank = _bank();
      final plural = _sentence(
        'es-s4',
        'Yo tengo perros.',
        bases: const <CardBase>[
          CardBase(word: 'tengo', ref: 'es-tengo'),
          CardBase(word: 'perros', ref: 'es-perro'),
        ],
      );
      for (var seed = 0; seed < 20; seed++) {
        expect(
          bank.make(plural, random: Random(seed))!.gap.word.id,
          'es-tengo',
          reason: 'perros stands among nouns as perro; tengo is as taught',
        );
      }
    });

    test('is an inflected word when nothing else can be', () {
      final bank = _bank(minKnown: 1);
      final plural = _sentence(
        'es-s5',
        'Los perros',
        bases: const <CardBase>[CardBase(word: 'perros', ref: 'es-perro')],
      );
      final view = bank
          .make(plural, random: Random(3))!
          .view(firstScript: 'latin', random: Random(3))!;
      expect(view.answer, 'perros');
      expect(view.before, 'Los ');
    });

    test('is drawn the same way from the same seed', () {
      final bank = _bank();
      List<String> run(int seed) {
        final random = Random(seed);
        final view = bank
            .make(_dog, random: random)!
            .view(firstScript: 'latin', random: random)!;
        return <String>[view.answer, ...view.options];
      }

      for (var seed = 0; seed < 10; seed++) {
        expect(run(seed), run(seed));
      }
    });
  });

  group('the options', () {
    test('are other known words of the gap\'s kind, the nearest in length '
        'first, so that nothing tells the right one apart', () {
      final bank = _bank();
      for (var seed = 0; seed < 60; seed++) {
        final random = Random(seed);
        final cloze = bank.make(_dog, random: random)!;
        final view = cloze.view(firstScript: 'latin', random: random)!;
        final options = view.options.toSet();
        if (cloze.gap.word.id == 'es-perro') {
          // universidad is far longer than perro: never offered.
          expect(options, <String>{'perro', 'libro', 'gato', 'casa'});
        } else {
          expect(options, <String>{'tengo', 'quiero', 'como'});
        }
        expect(view.options.length, options.length, reason: 'none twice');
      }
    });

    test('offer the right word and two or three others', () {
      final bank = _bank();
      final view = bank
          .make(_dog, random: Random(5))!
          .view(firstScript: 'latin', random: Random(5))!;
      expect(view.options, contains(view.answer));
      expect(view.options.length, inInclusiveRange(3, kClozeOptions));
      expect(kClozeMinOptions, 3);
    });

    test('are not words that mean what the answer means', () {
      final cards = <Card>[
        ..._cards.values,
        const Card(
          id: 'es-chucho',
          deckId: 'es-words',
          target: 'chucho',
          native: 'native es-perro',
          pos: 'noun',
        ),
      ];
      final bank = ClozeBank(
        cards: cards,
        isKnown: (id) => _known.contains(id) || id == 'es-chucho',
      );
      for (var seed = 0; seed < 30; seed++) {
        final random = Random(seed);
        final view = bank
            .make(_dog, random: random)!
            .view(firstScript: 'latin', random: random)!;
        expect(view.options, isNot(contains('chucho')));
      }
    });
  });

  group('graded', () {
    test('by the exact word: the missing word is right and no other is', () {
      final bank = _bank();
      final view = bank
          .make(_dog, random: Random(2))!
          .view(firstScript: 'latin', random: Random(2))!;
      expect(view.isRight(view.answer), isTrue);
      for (final option in view.options) {
        expect(view.isRight(option), option == view.answer);
      }
      expect(view.isRight('${view.answer}s'), isFalse);
      expect(view.isRight(''), isFalse);
    });
  });

  group('the Script and Latin letters switch', () {
    final hindi = <Card>[
      _hindi('hi-1', 'कुत्ता', 'kuttā', 'noun'),
      _hindi('hi-2', 'बिल्ली', 'billī', 'noun'),
      _hindi('hi-3', 'घर', 'ghar', 'noun'),
      _hindi('hi-4', 'किताब', 'kitāb', 'noun'),
      _hindi('hi-5', 'मेरे', 'mere', 'pronoun'),
      _hindi('hi-6', 'पास', 'pās', 'adv'),
      _hindi('hi-7', 'एक', 'ek', 'adj'),
      _hindi('hi-8', 'है', 'hai', 'verb'),
    ];
    const sentence = Card(
      id: 'hi-s1',
      deckId: 'hi-sentences',
      target: 'मेरे पास एक कुत्ता है।',
      native: 'I have a dog.',
      reading: 'mere pās ek kuttā hai.',
      pos: 'phrase',
    );
    final bank = ClozeBank(cards: hindi, isKnown: (_) => true);

    test('shows the sentence and the words in the script', () {
      final cloze = bank.make(sentence, random: Random(1))!;
      final view = cloze.view(firstScript: 'devanagari', random: Random(1))!;
      expect(view.reading, isFalse);
      expect(view.before, 'मेरे पास एक ');
      expect(view.after, ' है।');
      expect(view.answer, 'कुत्ता');
      final words = <String>{'कुत्ता', 'बिल्ली', 'घर', 'किताब'};
      expect(view.options.toSet(), words);
    });

    test('or in Latin letters, the reading, graded as that word', () {
      final cloze = bank.make(sentence, random: Random(1))!;
      final view = cloze.view(
        firstScript: 'devanagari',
        random: Random(1),
        reading: true,
      )!;
      expect(view.reading, isTrue);
      expect(view.before, 'mere pās ek ');
      expect(view.after, ' hai.');
      expect(view.answer, 'kuttā');
      final words = <String>{'kuttā', 'billī', 'ghar', 'kitāb'};
      expect(view.options.toSet(), words);
      expect(view.isRight('kuttā'), isTrue);
      expect(view.isRight('कुत्ता'), isFalse);
    });

    test('is not offered what the sentence cannot show', () {
      final cloze = bank.make(sentence, random: Random(1))!;
      // No spelling in another script.
      expect(
        cloze.view(
          firstScript: 'devanagari',
          random: Random(1),
          script: 'perso_arabic',
        ),
        isNull,
      );
      // A reading of another number of words cannot be matched to the gap.
      final short = Card(
        id: 'hi-s2',
        deckId: 'hi-sentences',
        target: sentence.target,
        native: sentence.native,
        reading: 'mere pas',
        pos: 'phrase',
      );
      final made = bank.make(short, random: Random(1))!;
      final view = made.view(
        firstScript: 'devanagari',
        random: Random(1),
        reading: true,
      );
      expect(view, isNull);
    });
  });

  group('examples of a card', () {
    const example = CardExample(
      target: 'Yo tengo un perro.',
      native: 'I have a dog.',
    );
    const perro = Card(
      id: 'es-perro',
      deckId: 'es-words',
      target: 'perro',
      native: 'native es-perro',
      pos: 'noun',
      examples: <CardExample>[example],
    );

    test('a word is asked as a cloze on its own word in its example', () {
      final bank = _bank();
      expect(bank.canAsk(perro), isTrue);
      for (var seed = 0; seed < 10; seed++) {
        final random = Random(seed);
        final cloze = bank.make(perro, random: random)!;
        expect(cloze.gap.word.id, 'es-perro');
        final view = cloze.view(firstScript: 'latin', random: random)!;
        expect(view.answer, 'perro');
        expect(view.before, 'Yo tengo un ');
        expect(view.after, '.');
        expect(cloze.source.native, 'I have a dog.');
      }
    });

    test('but not on an example that does not hold the card\'s word, or '
        'holds too few known words', () {
      final bank = _bank();
      const gato = Card(
        id: 'es-gato',
        deckId: 'es-words',
        target: 'gato',
        native: 'native es-gato',
        pos: 'noun',
        examples: <CardExample>[example],
      );
      expect(bank.canAsk(gato), isFalse);
      const casa = Card(
        id: 'es-casa',
        deckId: 'es-words',
        target: 'casa',
        native: 'native es-casa',
        pos: 'noun',
        examples: <CardExample>[
          CardExample(target: 'Una casa.', native: 'A house.'),
        ],
      );
      expect(bank.canAsk(casa), isFalse);
    });

    test('an example in another language is no sentence of this one', () {
      final bank = _bank();
      const sound = Card(
        id: 'es-perro',
        deckId: 'es-words',
        target: 'perro',
        native: 'native es-perro',
        pos: 'noun',
        examples: <CardExample>[
          CardExample(
            target: 'Yo tengo un perro.',
            native: 'I have a dog.',
            language: 'en',
          ),
        ],
      );
      expect(bank.canAsk(sound), isFalse);
    });
  });

  group('when it is asked', () {
    FsrsState stateAfter(int repetitions) => FsrsState(
      stability: 5,
      difficulty: 5,
      intervalDays: 5,
      dueAt: DateTime(2026, 1, 1),
      lastReviewAt: DateTime(2025, 12, 27),
      repetitions: repetitions,
    );

    SessionItem production(Card card, FsrsState? state) =>
        SessionItem(card: card, mode: DrillMode.production, state: state);

    final context = QuestionContext(
      canChoose: (_) => true,
      canCloze: (_) => true,
    );
    final sentence = _sentence('es-s6', 'yo tengo un perro');
    final word = _word('es-perro', 'perro', 'noun');

    test('a sentence on every second review, rearranged between', () {
      expect(
        questionTypeFor(production(sentence, stateAfter(1)), context)?.ask,
        Ask.cloze,
      );
      expect(
        questionTypeFor(production(sentence, stateAfter(2)), context)?.ask,
        Ask.rearrange,
      );
      expect(
        questionTypeFor(production(sentence, stateAfter(3)), context)?.ask,
        Ask.cloze,
      );
    });

    test('never a new pair, nor one just missed', () {
      expect(
        questionTypeFor(production(sentence, null), context)?.ask,
        Ask.rearrange,
      );
      expect(
        questionTypeFor(production(sentence, stateAfter(0)), context)?.ask,
        Ask.rearrange,
      );
      expect(clozeTurn(production(sentence, null)), isFalse);
    });

    test('never where no word can be left out', () {
      final none = QuestionContext(canChoose: (_) => true);
      expect(
        questionTypeFor(production(sentence, stateAfter(1)), none)?.ask,
        Ask.rearrange,
      );
      final no = QuestionContext(
        canChoose: (_) => true,
        canCloze: (_) => false,
      );
      expect(
        questionTypeFor(production(sentence, stateAfter(1)), no)?.ask,
        Ask.rearrange,
      );
    });

    test('a word on its example now and then, so that most reviews stay '
        'recall', () {
      Ask? ask(int repetitions) => questionTypeFor(
        production(word, stateAfter(repetitions)),
        context,
      )?.ask;
      expect(ask(1), isNull);
      expect(ask(2), isNull);
      expect(ask(3), Ask.cloze);
      expect(ask(4), isNull);
      expect(ask(7), Ask.cloze);
    });

    test('only production is asked as a cloze', () {
      for (final mode in <DrillMode>[
        DrillMode.recognition,
        DrillMode.listening,
        DrillMode.speaking,
      ]) {
        final item = SessionItem(
          card: sentence,
          mode: mode,
          state: stateAfter(1),
        );
        expect(questionTypeFor(item, context)?.ask, isNot(Ask.cloze));
      }
      expect(clozeType.skill, DrillMode.production);
    });

    test('a lesson never asks it', () {
      expect(lessonTypeFor(sentence, DrillMode.production)?.ask, Ask.rearrange);
      expect(lessonTypeFor(word, DrillMode.production)?.ask, isNot(Ask.cloze));
    });

    test('a review asks it where the app says it can', () {
      final items = <SessionItem>[production(sentence, stateAfter(1))];
      final asked = reviewAsks(
        items,
        canChoose: (_) => true,
        canCloze: (_) => true,
      );
      expect(asked.single.ask, Ask.cloze);
      final without = reviewAsks(items, canChoose: (_) => true);
      expect(without.single.ask, Ask.rearrange);
    });
  });

  group('placement', () {
    test('never asks a cloze: its screens have no format for one', () {
      // F6 is the placement bank's cloze, made by no screen.
      expect(kScreenFormats, isNot(contains('F6')));
    });

    test('does not use the review\'s cloze', () {
      const dirs = <String>['lib/core/placement', 'lib/features/placement'];
      final files = <File>[
        for (final dir in dirs)
          ...Directory(dir).listSync(recursive: true).whereType<File>(),
        for (final file in Directory('lib/app').listSync().whereType<File>())
          if (file.uri.pathSegments.last.startsWith('placement')) file,
      ];
      expect(files, isNotEmpty);
      for (final file in files) {
        if (!file.path.endsWith('.dart')) continue;
        final text = file.readAsStringSync();
        expect(text, isNot(contains('Ask.cloze')), reason: file.path);
        expect(text, isNot(contains('clozeType')), reason: file.path);
        expect(text, isNot(contains('ClozeBank')), reason: file.path);
      }
    });
  });
}

Card _hindi(String id, String target, String reading, String pos) => Card(
  id: id,
  deckId: 'hi-words',
  target: target,
  native: 'native $id',
  reading: reading,
  pos: pos,
);
