// The question builder of "Find my level" (wiki/Plan-Placement-V2.md, "Step
// 2: question generators"): a request of the run controller becomes a
// concrete question from the learner's decks; a topic the data cannot
// support says so, and the run controller uses the plan's fallback.
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/sound_contrasts.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/generated_question.dart';
import 'package:fluenough/core/placement/item_picker.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/placement_run.dart';
import 'package:fluenough/core/placement/question_builder.dart';
import 'package:fluenough/core/placement/question_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

const String _a = 'abcdefghij';

Card _card(
  String id,
  String target,
  String native, {
  int deck = 0,
  String pos = 'noun',
  List<CardBase> bases = const <CardBase>[],
  List<String> altNative = const <String>[],
  List<CardItem> synonyms = const <CardItem>[],
  List<CardItem> confusables = const <CardItem>[],
  List<String> tags = const <String>[],
}) => Card(
  id: id,
  deckId: 'deck-$deck',
  target: target,
  native: native,
  pos: pos,
  bases: bases,
  altNative: altNative,
  synonyms: synonyms,
  confusables: confusables,
  tags: tags,
);

/// Six decks in path order. Every deck holds ten words with their own
/// meanings; decks 3 to 5 teach grammar families (plural 3 and 4, case 4 and
/// 5, tense 5); decks 4 and 5 hold six long sentences each, decks 3 and 4 a
/// few short ones; deck 1 holds eight words spelled in Devanagari. Four
/// word pairs differ by one swap (k and g, t and d).
PlacementLanguageData _fixture({
  int sentenceWords = 9,
  bool sentences = true,
  bool sounds = true,
  bool pairsFromDecks = true,
  bool grammar = true,
  bool script = true,
  bool trusted = false,
}) {
  final decks = <PlacementDeck>[];
  final scriptCards = <Card>[];
  const devanagari = <String>[
    'कमल',
    'नमक',
    'पत्र',
    'चक्र',
    'सूर्य',
    'धर्म',
    'शब्द',
    'जल',
  ];
  const families = <int, List<String>>{
    3: <String>['plural'],
    4: <String>['plural', 'case'],
    5: <String>['case', 'tense'],
  };
  for (var i = 0; i < 6; i++) {
    final cards = <Card>[
      for (var j = 0; j < 10; j++)
        _card(
          'w-$i-$j',
          'x${_a[i]}${_a[j]}o',
          'thing $i-$j',
          deck: i,
          tags: <String>['t$i'],
          // Two inflected forms of one stem in the last deck.
          bases: i == 5 && j < 2
              ? <CardBase>[CardBase(word: 'x${_a[i]}${_a[j]}o', base: 'stem')]
              : const <CardBase>[],
        ),
    ];
    if (i == 1) {
      for (var j = 0; j < devanagari.length; j++) {
        final c = _card('s-$j', devanagari[j], 'sign $j', deck: 1);
        scriptCards.add(c);
        cards.add(c);
      }
    }
    if (i == 3) {
      cards.add(_card('p-tola', 'tola', 'bridge', deck: 3));
    }
    if (i == 4) {
      cards.add(_card('p-kala', 'kala', 'cup', deck: 4));
    }
    if (i == 5) {
      cards
        ..add(_card('p-gala', 'gala', 'feast', deck: 5))
        ..add(_card('p-dola', 'dola', 'swing', deck: 5));
    }
    if (sentences && i >= 3) {
      for (var j = 0; j < (i >= 4 ? 6 : 0); j++) {
        final words = <String>[
          for (var k = 0; k < sentenceWords; k++) 'w$i$j$k',
        ];
        cards.add(
          _card(
            's$i-$j',
            words.join(' '),
            'Long sentence $i-$j',
            deck: i,
            pos: 'phrase',
            bases: <CardBase>[CardBase(word: words[2], base: 'root$i$j')],
            confusables: <CardItem>[
              for (var n = 0; n < 3; n++)
                CardItem(id: 'c$n', word: 'w$i${j}z$n'),
            ],
          ),
        );
      }
      for (var j = 0; j < 3; j++) {
        final words = <String>['q$i${j}a', 'q$i${j}b', 'q$i${j}c'];
        cards.add(
          _card(
            'short$i-$j',
            words.join(' '),
            'Short sentence $i-$j',
            deck: i,
            pos: 'phrase',
            bases: <CardBase>[CardBase(word: words[1], base: 'short$i$j')],
            confusables: <CardItem>[
              for (var n = 0; n < 3; n++)
                CardItem(id: 'c$n', word: 'q$i${j}z$n'),
            ],
          ),
        );
      }
    }
    decks.add(
      PlacementDeck(
        id: 'deck-$i',
        cards: cards,
        grammarFamilies: grammar
            ? (families[i] ?? const <String>[])
            : const <String>[],
      ),
    );
  }
  return PlacementLanguageData(
    language: 'xx',
    decks: decks,
    scripts: script
        ? <PlacementScriptData>[
            PlacementScriptData(
              script: 'devanagari',
              words: <PlacementScriptWord>[
                for (final c in scriptCards)
                  PlacementScriptWord(card: c, spelling: c.target),
              ],
            ),
          ]
        : const <PlacementScriptData>[],
    sounds: sounds
        ? const SoundContrasts(
            language: 'xx',
            contrasts: <SoundContrast>[
              SoundContrast(
                id: 'velar',
                name: 'k or g',
                pairs: <(String, String)>[('k', 'g')],
              ),
              SoundContrast(
                id: 'dental',
                name: 't or d',
                pairs: <(String, String)>[('t', 'd')],
              ),
            ],
          )
        : null,
    levelMarkDecks: const <int>[1, 3, 5],
    pairsFromDecks: pairsFromDecks,
    pairAudioTrusted: trusted,
  );
}

PlacementQuestionRequest _request(
  PlacementVariant variant, {
  PlacementQuestionRole role = PlacementQuestionRole.base,
  PlacementTopic topic = PlacementTopic.longRecognition,
  PlacementQuestionKind kind = PlacementQuestionKind.pickOne,
  List<PlacementSkill> skills = const <PlacementSkill>[PlacementSkill.read],
  int deck = 5,
  int pick = 0,
  int number = 1,
  PlacementPart? part,
  PlacementVariant? origin,
}) => PlacementQuestionRequest(
  number: number,
  role: role,
  topic: topic,
  variant: variant,
  kind: kind,
  skills: skills,
  deck: deck,
  percentile: deck * 20,
  shortlistPick: pick,
  part: part,
  origin: origin,
);

GeneratedQuestion _built(QuestionOutcome outcome) {
  expect(outcome, isA<QuestionBuilt>(), reason: outcome.toString());
  return (outcome as QuestionBuilt).question;
}

PlacementUnavailableReason _why(QuestionOutcome outcome) {
  expect(outcome, isA<QuestionUnavailable>());
  return (outcome as QuestionUnavailable).reason;
}

void main() {
  group('one generator per topic builds a question from the decks', () {
    test('topic 1, K1: a long sentence written only in the script', () {
      final data = _fixture();
      final q = _built(
        QuestionBuilder(data).build(
          _request(
            PlacementVariant.k1,
            kind: PlacementQuestionKind.english,
            skills: const [PlacementSkill.read, PlacementSkill.script],
          ),
        ),
      );
      final card = data.cardById(q.cardId!)!;
      expect(q.prompt, PlacementPromptKind.writtenSentence);
      expect(q.promptText, card.target);
      expect(q.promptReading, isNull, reason: 'no reading aid');
      expect(q.audio, isNull, reason: 'no audio');
      expect(card.wordCount, greaterThanOrEqualTo(8));
      expect(q.mode, PlacementAnswerMode.sayEnglish);
      expect(q.accepted, contains(card.native));
      // The no-microphone pick is there too, four options, one right.
      expect(q.options, hasLength(4));
      expect(q.options[q.correctIndex!], card.native);
      expect(q.difficulty.shortOfLong, isFalse);
      // A miss would be split in two (section 3.1).
      expect(q.splits.map((s) => s.variant), <PlacementVariant>[
        PlacementVariant.s1,
        PlacementVariant.s2,
      ]);
    });

    test('topic 1, K2: the English meaning of a heard sentence', () {
      final data = _fixture();
      final q = _built(
        QuestionBuilder(data).build(
          _request(
            PlacementVariant.k2,
            kind: PlacementQuestionKind.english,
            skills: const [PlacementSkill.hear],
          ),
        ),
      );
      final card = data.cardById(q.cardId!)!;
      expect(q.prompt, PlacementPromptKind.heardSentence);
      expect(q.promptText, isNull, reason: 'the text is withheld');
      expect(q.audio!.text, card.target);
      expect(q.accepted, contains(card.native));
    });

    test('K2 without Hear shows the reading instead of audio', () {
      final data = _fixture();
      final q = _built(
        QuestionBuilder(data, tested: const {PlacementSkill.read}).build(
          _request(PlacementVariant.k2, skills: const [PlacementSkill.read]),
        ),
      );
      expect(q.audio, isNull);
      expect(q.promptText, isNotNull);
    });

    test('with no microphone the English answer is a pick', () {
      final q = _built(
        QuestionBuilder(_fixture(), microphone: false).build(
          _request(PlacementVariant.k1, kind: PlacementQuestionKind.pickMany),
        ),
      );
      expect(q.mode, PlacementAnswerMode.pick);
      expect(q.options, hasLength(4));
    });

    test('topic 5, W1 and W2: the hardest word, written and heard', () {
      final data = _fixture();
      final builder = QuestionBuilder(data);
      final w1 = _built(
        builder.build(
          _request(PlacementVariant.w1, topic: PlacementTopic.complexWords),
        ),
      );
      final card = data.cardById(w1.cardId!)!;
      expect(w1.prompt, PlacementPromptKind.writtenWord);
      expect(w1.promptText, card.target);
      expect(w1.options[w1.correctIndex!], card.native);
      // The two inflected forms of the last deck are the hardest items.
      expect(isInflected(card, data), isTrue);
      final w2 = _built(
        builder.build(
          _request(
            PlacementVariant.w2,
            topic: PlacementTopic.complexWords,
            skills: const [PlacementSkill.hear],
          ),
          asked: w1.itemIds,
        ),
      );
      expect(w2.prompt, PlacementPromptKind.heardWord);
      expect(w2.audio!.text, data.cardById(w2.cardId!)!.target);
      expect(w2.cardId, isNot(w1.cardId));
    });

    test('topic 3, G1 and G2: one family each, the last unit first', () {
      final data = _fixture();
      final builder = QuestionBuilder(data);
      final g1 = _built(
        builder.build(
          _request(PlacementVariant.g1, topic: PlacementTopic.lateGrammar),
        ),
      );
      expect(
        g1.concept,
        'grammar:case',
        reason: "the last unit's first family",
      );
      expect(g1.prompt, PlacementPromptKind.blankSentence);
      expect(g1.promptText, contains('____'));
      expect(g1.options, hasLength(4));
      final form = g1.options[g1.correctIndex!];
      final card = data.cardById(g1.cardId!)!;
      expect(card.target.replaceFirst(form, '____'), g1.promptText);
      expect(g1.meaningHint, card.native);

      final g2 = _built(
        builder.build(
          _request(
            PlacementVariant.g2,
            topic: PlacementTopic.lateGrammar,
            kind: PlacementQuestionKind.tilesSentence,
            skills: const [PlacementSkill.write, PlacementSkill.read],
          ),
          asked: g1.itemIds,
        ),
      );
      expect(
        g2.concept,
        'grammar:plural',
        reason: 'the family with most units',
      );
      expect(g2.mode, PlacementAnswerMode.tiles);
      final tiles = data
          .cardById(g2.cardId!)!
          .tilesOfSpelling(data.cardById(g2.cardId!)!.target);
      expect(g2.accepted, contains(tiles.join(' ')));
      expect(g2.tiles, isNot(orderedEquals(tiles)), reason: 'shuffled');
      expect(g2.tiles.toSet().containsAll(tiles), isTrue);
      expect(g2.tiles.length, greaterThan(tiles.length), reason: 'wrong tiles');
    });

    test('topic 2, R1 and R2: a long sentence built from tiles', () {
      final data = _fixture();
      final builder = QuestionBuilder(data);
      final r1 = _built(
        builder.build(
          _request(
            PlacementVariant.r1,
            topic: PlacementTopic.longReproduction,
            kind: PlacementQuestionKind.tilesSentence,
            skills: const [PlacementSkill.hear, PlacementSkill.write],
          ),
        ),
      );
      expect(r1.prompt, PlacementPromptKind.heardSentence);
      expect(r1.audio, isNotNull);
      expect(r1.mode, PlacementAnswerMode.tiles);
      final r2 = _built(
        builder.build(
          _request(
            PlacementVariant.r2,
            topic: PlacementTopic.longReproduction,
            kind: PlacementQuestionKind.tilesSentence,
            skills: const [PlacementSkill.write],
          ),
          asked: r1.itemIds,
        ),
      );
      final card = data.cardById(r2.cardId!)!;
      expect(r2.prompt, PlacementPromptKind.meaning);
      expect(r2.promptText, card.native);
      expect(
        r2.accepted,
        contains(card.tilesOfSpelling(card.target).join(' ')),
      );
    });

    test('topic 4, P1: two words that differ by one letter of a contrast', () {
      final data = _fixture();
      final q = _built(
        QuestionBuilder(data).build(
          _request(
            PlacementVariant.p1,
            topic: PlacementTopic.minimalPairs,
            kind: PlacementQuestionKind.pair,
            skills: const [PlacementSkill.hear],
          ),
        ),
      );
      expect(q.options, hasLength(2));
      expect(
        data.sounds!.between(q.options[0], q.options[1]),
        isNotNull,
        reason: 'one swap of a sounds-file contrast',
      );
      expect(q.options[q.correctIndex!], data.cardById(q.cardId!)!.target);
      expect(q.audio!.text, q.options[q.correctIndex!]);
      expect(q.concept, startsWith('sound:'));
      // Nothing checks the system voice yet: the pair audio is untrusted, and
      // the written version is ready for a device that fails the check.
      expect(q.audioUntrusted, isTrue);
      expect(q.tilesFallback, isNotNull);
      expect(q.tilesFallback!.accepted, contains(q.options[q.correctIndex!]));
    });

    test('two pair questions use two different contrasts', () {
      final data = _fixture();
      final builder = QuestionBuilder(data);
      final req = _request(
        PlacementVariant.p1,
        topic: PlacementTopic.minimalPairs,
        kind: PlacementQuestionKind.pair,
        skills: const [PlacementSkill.hear],
      );
      final p1 = _built(builder.build(req));
      final p2 = _built(builder.build(req, asked: p1.itemIds));
      expect(p2.concept, isNot(p1.concept));
    });

    test('with no sounds file the pairs come from the decks', () {
      final data = _fixture(sounds: false);
      final q = _built(
        QuestionBuilder(data).build(
          _request(
            PlacementVariant.p1,
            topic: PlacementTopic.minimalPairs,
            kind: PlacementQuestionKind.pair,
            skills: const [PlacementSkill.hear],
          ),
        ),
      );
      expect(editDistance(q.options[0], q.options[1]), 1);
      expect(q.options[0].length, q.options[1].length);
    });

    test(
      'topic 6, Say: the accepted answers are the taught form and synonyms',
      () {
        final data = _fixture();
        final builder = QuestionBuilder(data);
        final q = _built(
          builder.build(
            _request(
              PlacementVariant.y1,
              topic: PlacementTopic.sayByMeaning,
              kind: PlacementQuestionKind.say,
              skills: const [PlacementSkill.say],
            ),
          ),
        );
        final card = data.cardById(q.cardId!)!;
        expect(q.mode, PlacementAnswerMode.say);
        expect(q.promptText, card.native);
        expect(q.accepted.first, card.target);
        expect(q.dialectRisk, isTrue);

        // Listed synonyms, by card or in full, and a card that means the same.
        final other = data.cardById('w-2-2')!;
        final withSynonyms = _card(
          'syn',
          'xyzo',
          other.native,
          synonyms: <CardItem>[
            const CardItem(id: 's1', ref: 'w-0-0'),
            const CardItem(id: 's2', word: 'listed'),
          ],
          // The card's own alternatives are accepted too.
        );
        final accepted = builder.acceptedWordsFor(withSynonyms);
        expect(accepted, containsAll(<String>['xyzo', 'xaao', 'listed']));
        expect(accepted, contains(other.target), reason: 'same meaning');
      },
    );

    test('topic 7: read a script word and build one from tiles', () {
      final data = _fixture();
      final builder = QuestionBuilder(data);
      final read = _built(
        builder.build(
          _request(
            PlacementVariant.sr,
            topic: PlacementTopic.scriptReadWrite,
            kind: PlacementQuestionKind.pickMany,
            skills: const [PlacementSkill.script, PlacementSkill.read],
          ),
        ),
      );
      expect(read.prompt, PlacementPromptKind.writtenWord);
      expect(read.promptReading, isNull);
      expect(
        read.options[read.correctIndex!],
        data.cardById(read.cardId!)!.native,
      );
      expect(read.promptText, data.cardById(read.cardId!)!.target);
      final write = _built(
        builder.build(
          _request(
            PlacementVariant.sw,
            topic: PlacementTopic.scriptReadWrite,
            kind: PlacementQuestionKind.tilesWord,
            skills: const [PlacementSkill.script, PlacementSkill.write],
          ),
          asked: read.itemIds,
        ),
      );
      expect(write.mode, PlacementAnswerMode.tiles);
      expect(write.accepted, <String>[data.cardById(write.cardId!)!.target]);
      expect(write.tiles.join(), isNot(write.accepted.first));
      expect(write.cardId, isNot(read.cardId));
    });

    test('a probe asks one vocabulary question of its skill', () {
      final data = _fixture();
      final q = _built(
        QuestionBuilder(data).build(
          _request(
            PlacementVariant.probe,
            role: PlacementQuestionRole.probe,
            topic: PlacementTopic.positioning,
            deck: 2,
          ),
        ),
      );
      expect(data.deckIndexOf(q.cardId!), 2, reason: 'asked at its own deck');
      expect(q.options, hasLength(4));
    });

    test('the split of a K1 miss is a different, simpler question', () {
      final data = _fixture();
      final builder = QuestionBuilder(data);
      final k1 = _built(
        builder.build(
          _request(
            PlacementVariant.k1,
            kind: PlacementQuestionKind.english,
            skills: const [PlacementSkill.read, PlacementSkill.script],
          ),
        ),
      );
      final s1 = _built(
        builder.build(
          _request(
            PlacementVariant.s1,
            role: PlacementQuestionRole.split,
            kind: PlacementQuestionKind.pickOne,
            part: PlacementPart.meaning,
            origin: PlacementVariant.k1,
          ),
          asked: k1.itemIds,
          origin: k1,
        ),
      );
      expect(s1.mode, PlacementAnswerMode.pick);
      expect(s1.audio, isNotNull, reason: 'by audio only');
      expect(s1.cardId, isNot(k1.cardId));
    });
  });

  group('items and options', () {
    test('wrong options never share the answer\'s meaning', () {
      // Cards that mean the same as one another in every deck: j and j + 5
      // of a deck share a native, every j shares an alternative with the same
      // j of the other decks, and one card lists another as a synonym.
      final base = _fixture();
      final decks = <PlacementDeck>[
        for (final d in base.decks)
          PlacementDeck(
            id: d.id,
            cards: <Card>[
              for (final c in d.cards)
                if (c.id.startsWith('w-'))
                  _card(
                    c.id,
                    c.target,
                    'thing ${c.id.split('-')[1]}-${int.parse(c.id.split('-')[2]) % 5}',
                    deck: int.parse(c.id.split('-')[1]),
                    altNative: <String>['alt ${c.id.split('-')[2]}'],
                    synonyms: c.id == 'w-5-3'
                        ? const <CardItem>[CardItem(id: 's', ref: 'w-5-4')]
                        : const <CardItem>[],
                  )
                else
                  c,
            ],
            grammarFamilies: d.grammarFamilies,
          ),
      ];
      final data = PlacementLanguageData(
        language: 'xx',
        decks: decks,
        sounds: base.sounds,
      );
      final builder = QuestionBuilder(data, seed: 3);
      final seen = <String>{};
      for (var pick = 0; pick < 5; pick++) {
        for (final variant in <PlacementVariant>[
          PlacementVariant.w1,
          PlacementVariant.w2,
        ]) {
          final q = _built(
            builder.build(
              _request(variant, pick: pick, topic: PlacementTopic.complexWords),
            ),
          );
          seen.add(q.cardId!);
          final answer = data.cardById(q.cardId!)!;
          // Every meaning the answer has, or that a synonym of it has.
          final same = <String>{
            for (final m in answer.meanings) foldMeaning(m),
            for (final s in answer.synonyms)
              for (final m in data.cardById(s.ref!)!.meanings) foldMeaning(m),
          };
          expect(q.options.toSet(), hasLength(q.options.length));
          for (final (i, option) in q.options.indexed) {
            if (i == q.correctIndex) continue;
            expect(same, isNot(contains(foldMeaning(option))), reason: option);
          }
        }
      }
      expect(seen.length, greaterThan(1));
    });

    test('distractors come from the same deck first, then its neighbours', () {
      Card c(String id, int deck) => _card(id, 't$id', 'm$id', deck: deck);
      final data = PlacementLanguageData(
        language: 'xx',
        decks: <PlacementDeck>[
          for (var i = 0; i < 5; i++)
            PlacementDeck(
              id: 'd$i',
              cards: <Card>[
                for (var j = 0; j < (i == 2 ? 2 : 3); j++) c('c$i$j', i),
              ],
            ),
        ],
      );
      final picker = PlacementItemPicker(data);
      final wrong = picker.distractorsFor(
        data.decks[2].cards.first,
        2,
        sameKind: isWordCard,
        show: (c) => c.native,
      );
      expect(wrong, hasLength(3));
      expect(wrong.first.id, 'c21', reason: 'the same deck first');
      expect(
        wrong.skip(1).map((c) => data.deckIndexOf(c.id)),
        everyElement(anyOf(1, 3)),
        reason: 'then the nearest neighbours, not decks 0 and 4',
      );
    });

    test('a sentence is never offered as the wrong option of a word', () {
      final data = _fixture();
      final picker = PlacementItemPicker(data);
      final wrong = picker.distractorsFor(
        data.cardById('w-5-3')!,
        5,
        sameKind: isWordCard,
        show: (c) => c.native,
        count: 20,
      );
      expect(wrong.every(isWordCard), isTrue);
    });

    test('harder items rank first: deeper, more inflected, closer', () {
      final data = _fixture();
      final picker = PlacementItemPicker(data);
      final candidates = <({Card card, int deck})>[
        for (var i = 0; i < 6; i++)
          for (final c in data.decks[i].cards)
            if (isWordCard(c) && c.id.startsWith('w-')) (card: c, deck: i),
      ];
      final ranked = picker.rank(
        candidates,
        wrongFor: (c, d) => picker.distractorsFor(
          c,
          d,
          sameKind: isWordCard,
          show: (x) => x.native,
        ),
      );
      for (var i = 1; i < ranked.length; i++) {
        expect(ranked[i - 1].score, greaterThanOrEqualTo(ranked[i].score));
      }
      // Deep and inflected beats shallow and plain.
      expect(ranked.first.deck, 5);
      expect(isInflected(ranked.first.card, data), isTrue);
      expect(
        ranked.first.score,
        closeTo(
          0.35 * ranked.first.depth +
              0.30 * ranked.first.form +
              0.35 * ranked.first.closeness,
          1e-9,
        ),
      );
      expect(
        ranked.indexWhere((r) => r.deck == 0),
        greaterThan(ranked.indexWhere((r) => r.deck == 5)),
      );
      // The shortlist is the top five; the request's pick chooses within it.
      final shortlist = <String>{
        for (var pick = 0; pick < 5; pick++)
          PlacementItemPicker.pickFromShortlist(ranked, pick)!.card.id,
      };
      expect(shortlist, ranked.take(5).map((r) => r.card.id).toSet());
    });

    test('a sounds-file swap is the closest wrong option there is', () {
      final data = _fixture();
      final picker = PlacementItemPicker(data);
      expect(
        picker.closenessOf(data.cardById('p-kala')!, data.cardById('p-gala')!),
        1,
      );
      expect(
        picker.closenessOf(data.cardById('w-5-3')!, data.cardById('w-0-7')!),
        lessThan(1),
      );
    });
  });

  group('no repeats and the seed', () {
    test('a run never asks a card, or a word family, twice', () {
      final data = _fixture();
      final builder = QuestionBuilder(data);
      final asked = <String>{};
      final cards = <String>[];
      for (var n = 1; n <= 12; n++) {
        final outcome = builder.build(
          _request(
            PlacementVariant.w1,
            topic: PlacementTopic.complexWords,
            number: n,
            pick: n % 5,
          ),
          asked: asked,
        );
        if (outcome is! QuestionBuilt) break;
        final q = outcome.question;
        expect(asked, isNot(contains(q.cardId)));
        cards.add(q.cardId!);
        asked.addAll(q.itemIds);
      }
      expect(cards.length, greaterThan(6));
      expect(cards.toSet(), hasLength(cards.length));
      // w-5-0 and w-5-1 are two forms of one stem.
      expect(cards.contains('w-5-0') && cards.contains('w-5-1'), isFalse);
    });

    test('the same input gives the same question, another seed another', () {
      final data = _fixture();
      GeneratedQuestion build(int seed, int pick) => _built(
        QuestionBuilder(
          data,
          seed: seed,
        ).build(_request(PlacementVariant.k1, pick: pick)),
      );
      for (var pick = 0; pick < 5; pick++) {
        final one = build(7, pick);
        final two = build(7, pick);
        expect(two.cardId, one.cardId);
        expect(two.options, one.options);
        expect(two.correctIndex, one.correctIndex);
      }
      final ids = <String?>{
        for (var pick = 0; pick < 5; pick++) build(7, pick).cardId,
      };
      expect(ids.length, greaterThan(1), reason: 'the pick moves in the five');
      final shuffles = <String>{
        for (var seed = 0; seed < 8; seed++) build(seed, 0).options.join('|'),
      };
      expect(shuffles.length, greaterThan(1), reason: 'the seed shuffles');
    });

    test('a card the learner reviews with high stability is never asked', () {
      final data = _fixture();
      final stable = PlacementLanguageData(
        language: 'xx',
        decks: data.decks,
        sounds: data.sounds,
        stableCardIds: <String>{for (final c in data.decks[5].cards) c.id},
      );
      final q = _built(
        QuestionBuilder(stable).build(
          _request(PlacementVariant.w1, topic: PlacementTopic.complexWords),
        ),
      );
      expect(stable.deckIndexOf(q.cardId!), isNot(5));
    });
  });

  group('a data gap is unavailable, not a guess', () {
    PlacementQuestionRequest pair() => _request(
      PlacementVariant.p1,
      topic: PlacementTopic.minimalPairs,
      kind: PlacementQuestionKind.pair,
      skills: const [PlacementSkill.hear],
    );

    test('no sounds file and no pairs from the decks', () {
      final data = _fixture(sounds: false, pairsFromDecks: false);
      expect(
        _why(QuestionBuilder(data).build(pair())),
        PlacementUnavailableReason.noSoundsFile,
      );
    });

    test('a sounds file with no two words that differ by one swap', () {
      final data = _fixture();
      final bare = PlacementLanguageData(
        language: 'xx',
        decks: <PlacementDeck>[
          for (final d in data.decks)
            PlacementDeck(
              id: d.id,
              cards: <Card>[
                for (final c in d.cards)
                  if (!c.id.startsWith('p-')) c,
              ],
            ),
        ],
        sounds: data.sounds,
      );
      expect(
        _why(QuestionBuilder(bare).build(pair())),
        PlacementUnavailableReason.noPairFound,
      );
    });

    test('untrusted pair audio, when only trusted audio is wanted', () {
      expect(
        _why(
          QuestionBuilder(
            _fixture(),
            requireTrustedPairAudio: true,
          ).build(pair()),
        ),
        PlacementUnavailableReason.pairAudioUntrusted,
      );
      expect(
        QuestionBuilder(
          _fixture(trusted: true),
          requireTrustedPairAudio: true,
        ).build(pair()),
        isA<QuestionBuilt>(),
      );
    });

    test('no grammar unit, no sentence, no script', () {
      final builder = QuestionBuilder(_fixture(grammar: false));
      expect(
        _why(
          builder.build(
            _request(PlacementVariant.g1, topic: PlacementTopic.lateGrammar),
          ),
        ),
        PlacementUnavailableReason.noGrammarFamily,
      );
      expect(
        _why(
          QuestionBuilder(_fixture(sentences: false))
              .build(_request(PlacementVariant.k1)),
        ),
        PlacementUnavailableReason.noSentences,
      );
      expect(
        _why(
          QuestionBuilder(_fixture(script: false)).build(
            _request(
              PlacementVariant.sr,
              topic: PlacementTopic.scriptReadWrite,
              skills: const [PlacementSkill.script],
            ),
          ),
        ),
        PlacementUnavailableReason.noScript,
      );
    });

    test('short sentences are asked as the longest there are, and flagged', () {
      final q = _built(
        QuestionBuilder(_fixture(sentenceWords: 5))
            .build(_request(PlacementVariant.k1)),
      );
      expect(q.difficulty.shortOfLong, isTrue);
      expect(shortFixtureCard(q).wordCount, 5);
    });
  });

  group('the run controller takes the plan\'s fallback', () {
    PlacementRunConfig config() => PlacementRunConfig(
      deckCount: 6,
      skills: const {
        PlacementSkill.read,
        PlacementSkill.hear,
        PlacementSkill.say,
        PlacementSkill.write,
      },
      declaration: PlacementDeclaration.expert,
      pathCompleteToB1: true,
      allDecksDownloaded: true,
    );

    PlacementRun upTo(PlacementVariant variant) {
      var run = PlacementRun(config());
      var guard = 0;
      while (run.next!.variant != variant && guard++ < 40) {
        run = run.answer(true);
      }
      expect(run.next!.variant, variant);
      return run;
    }

    test('pair audio that cannot be trusted becomes Write tiles', () {
      final run = upTo(PlacementVariant.p1);
      final before = run.asked;
      final next = run.markUnavailable(
        PlacementUnavailableReason.pairAudioUntrusted,
      );
      expect(next.asked, before, reason: 'nothing was answered');
      expect(next.next!.variant, PlacementVariant.p1);
      expect(next.next!.kind, PlacementQuestionKind.tilesWord);
      expect(next.next!.skills, const [PlacementSkill.write]);
      // The second pair question is still its own.
      expect(next.answer(true).next!.variant, PlacementVariant.p2);
    });

    test('a language with no pair list gets a heard complex word', () {
      final run = upTo(PlacementVariant.p1)
          .markUnavailable(PlacementUnavailableReason.noSoundsFile);
      expect(run.next!.variant, PlacementVariant.w2b);
      expect(run.next!.skills, const [PlacementSkill.hear]);
    });

    test(
      'a topic with no fallback is left out, and its skill not Verified',
      () {
        var run = upTo(PlacementVariant.y1);
        var guard = 0;
        while (!run.isDone && guard++ < 80) {
          final next = run.next!;
          final isSay = next.skills.contains(PlacementSkill.say);
          run = isSay
              ? run.markUnavailable(PlacementUnavailableReason.noWords)
              : run.answer(true);
        }
        expect(run.isDone, isTrue);
        expect(run.skippedQuestions, contains(PlacementVariant.y1));
        expect(run.readout[PlacementSkill.say]!.isVerified, isFalse);
        expect(run.readout[PlacementSkill.read]!.isVerified, isTrue);
      },
    );

    test('the same answers and notes give the same run', () {
      final one = upTo(PlacementVariant.p1)
          .markUnavailable(PlacementUnavailableReason.pairAudioUntrusted);
      final two = PlacementRun(
        one.config,
        results: one.results,
        unavailable: one.unavailableLog,
      );
      expect(two.next.toString(), one.next.toString());
    });

    test('built questions and the run together never repeat a card', () {
      final data = _fixture();
      final builder = QuestionBuilder(data, seed: 5);
      var run = PlacementRun(config());
      final asked = <String>{};
      final cards = <String>[];
      var guard = 0;
      while (!run.isDone && guard++ < 70) {
        final outcome = builder.build(run.next!, asked: asked);
        if (outcome is QuestionUnavailable) {
          run = run.markUnavailable(outcome.reason);
          continue;
        }
        final q = (outcome as QuestionBuilt).question;
        expect(asked, isNot(contains(q.cardId)), reason: q.request.toString());
        cards.add(q.cardId!);
        asked.addAll(q.itemIds);
        run = run.answer(true);
      }
      expect(cards.toSet(), hasLength(cards.length));
      expect(cards.length, greaterThan(10));
    });
  });
}

Card shortFixtureCard(GeneratedQuestion q) =>
    _fixture(sentenceWords: 5).cardById(q.cardId!)!;
