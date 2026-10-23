// Grading: whether what a learner typed, chose or said is right, near or
// wrong. The answer grader, Indic spellings, the meaning rules, readings
// typed in Latin letters, spoken answers, the contrast a mis-heard sound
// names, and self-grades.

import 'dart:io';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/romanisation_parser.dart';
import 'package:fluenough/core/data/sounds_parser.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/grading/meaning_rules.dart';
import 'package:fluenough/core/grading/romanised.dart';
import 'package:fluenough/core/grading/self_grade.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/romanisation.dart';
import 'package:fluenough/core/models/sound_contrasts.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/answer_feedback.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

// From answer_grader_folds_test.dart.
/// The flags that tell the interface *why* an answer was a close miss.
///
/// The outcome itself is unchanged by them — an article miss is still
/// `closeDiacritics`, graded 4 — so these tests pin only which message the
/// drill can pick: "mind the accent", "keep the article", or both.

// From iso_readings_test.dart.
/// Readings in ISO 15919 letters (ADR-0025) are graded as leniently as the
/// plain readings they replaced: an answer typed as the old reading was is
/// still exact.

Romanisation bundled(String code) => parseRomanisation(
  File('decks/$code/$code-romanisation.yaml').readAsStringSync(),
  source: '$code-romanisation.yaml',
);

// From romanised_test.dart.
const Romanisation hindi = Romanisation(
  language: 'hi',
  scheme: 'Popular',
  equivalents: <List<String>>[
    ['a', 'aa'],
    ['i', 'ee', 'ii'],
    ['u', 'oo', 'uu'],
    ['v', 'w'],
    ['chh', 'ch'],
  ],
);

// From translit_test.dart.
/// Answers typed in Latin letters (#47, ADR-0022), graded against the
/// card's reading in its language's scheme.

// From speaking_test.dart.
/// Speaking (#89, ADR-0014): when the microphone is asked for, which
/// languages can be heard, and how what was heard is graded.

const String spanish = 'es-en-core-100';

AppState speaking(FixedSpeechEngine speech, {bool on = false}) => AppState.test(
  speech: speech,
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningChosen: true,
    enabledSkills: <Skill>{
      ...Skill.values.where((s) => s.onByDefault),
      if (on) Skill.speaking,
    },
  ),
);

// From sound_contrasts_test.dart.
/// Sound contrasts (#89, ADR-0015): which sound a wrong word heard differs
/// from the answer by, read from a language's sounds file.

const String bengali = '''
schema: 1
kind: sounds
id: bn-sounds
language: bn
contrasts:
  - id: aspiration
    name: "a breath after the consonant"
    pairs: [["ক", "খ"], ["ব", "ভ"]]
  - id: dental-retroflex
    name: "the tongue on the teeth or curled back"
    pairs: [["দ", "ড"]]
  - id: inherent-vowel
    name: "the open o against a"
    within_word: true
    pairs: [["", "া"]]
  - id: nasal
    name: "a vowel said through the nose"
    pairs: [["", "ঁ"]]
''';

// From contrast_feedback_test.dart.
/// The speaking drill names the sound a wrong word differs by, when the
/// word heard is the answer with one sound changed (#89, ADR-0015).

// From near_miss_test.dart.
/// A near miss waits for the learner to judge it, unless it is word for word
/// another card's answer: then it is that other word, and wrong.

const String future = 'te-en-grammar-future';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the answer grader', () {
    const spanish = AnswerGrader(articles: ['el', 'la', 'los', 'las']);
    const plain = AnswerGrader();

    group('exact matching', () {
      test('exact, ignoring case, spacing and terminal punctuation', () {
        expect(plain.grade('la casa', 'la casa').outcome, AnswerOutcome.exact);

        for (final given in [
          'La Casa',
          '  la casa  ',
          'la casa.',
          '¿la casa?',
        ]) {
          expect(
            plain.grade(given, 'la casa').outcome,
            AnswerOutcome.exact,
            reason: 'for input "$given"',
          );
        }

        expect(
          plain.grade('la    casa', 'la casa').outcome,
          AnswerOutcome.exact,
        );
      });

      test('accepts a declared alternate', () {
        final result = plain.grade(
          'the home',
          'the house',
          alternates: const ['the home'],
        );
        expect(result.outcome, AnswerOutcome.exact);
        expect(result.matched, 'the home');
      });
    });

    group('diacritics', () {
      test('a missing accent is correct but flagged', () {
        expect(
          plain.grade('pais', 'país').outcome,
          AnswerOutcome.closeDiacritics,
        );
        expect(
          plain.grade('habláis', 'hablais').outcome,
          AnswerOutcome.closeDiacritics,
        );
      });
    });

    group('articles', () {
      test('a dropped article is accepted only when the language declares '
          'them, and never strips the whole answer', () {
        expect(spanish.grade('casa', 'la casa').outcome.isCorrect, isTrue);

        expect(plain.grade('casa', 'la casa').outcome, AnswerOutcome.wrong);

        expect(spanish.grade('la', 'la').outcome, AnswerOutcome.exact);
      });
    });

    group('typos', () {
      test('one wrong letter is a near miss, with more allowance for a long '
          'answer than a short one', () {
        expect(
          plain.grade('gracia', 'gracias').outcome,
          AnswerOutcome.closeTypo,
        );

        expect(
          plain.grade('trabajamso', 'trabajamos').outcome,
          AnswerOutcome.closeTypo,
        );

        // Distance 2 on a three character answer is rejected, where the same
        // distance on the ten character answer above was accepted.
        expect(plain.grade('sre', 'ser').outcome, AnswerOutcome.wrong);
        expect(plain.grade('xyz', 'ser').outcome, AnswerOutcome.wrong);
      });

      test('a different word is wrong, not a typo', () {
        expect(plain.grade('perro', 'casa').outcome, AnswerOutcome.wrong);
      });
    });

    group('empty input', () {
      test('is always wrong', () {
        expect(plain.grade('', 'casa').outcome, AnswerOutcome.wrong);
        expect(plain.grade('   ', 'casa').outcome, AnswerOutcome.wrong);
      });
    });
  });

  group('what a close miss is flagged as', () {
    const spanish = AnswerGrader(articles: ['el', 'la', 'los', 'las', 'un']);

    GradedAnswer grade(String given, String expected) =>
        spanish.grade(given, expected);

    test('a missing accent and a missing article are told apart', () {
      final result = grade('el nino', 'el niño');
      expect(result.outcome, AnswerOutcome.closeDiacritics);
      expect(result.foldedDiacritics, isTrue);
      expect(result.droppedArticle, isFalse);

      final article = grade('niño', 'el niño');
      expect(article.outcome, AnswerOutcome.closeDiacritics);
      expect(article.droppedArticle, isTrue);
      expect(article.foldedDiacritics, isFalse);
    });
  });

  group('Indic spellings', () {
    const grader = AnswerGrader();

    void same(String typed, String expected, {required String because}) {
      expect(
        typed == expected,
        isFalse,
        reason: 'the test needs two spellings',
      );
      expect(
        grader.grade(typed, expected).outcome,
        AnswerOutcome.exact,
        reason: because,
      );
      expect(
        grader.grade(expected, typed).outcome,
        AnswerOutcome.exact,
        reason: '$because, either way round',
      );
    }

    group('a sentence-final mark is not part of the answer (#130)', () {
      test('the danda and double danda', () {
        same('আমি ছাত্র', 'আমি ছাত্র।', because: 'Bengali full stop');
        same('मैं छात्र हूँ', 'मैं छात्र हूँ।', because: 'Hindi full stop');
        same('नमस्ते', 'नमस्ते॥', because: 'double danda');
      });
    });

    group('one letter, two spellings, compare equal', () {
      test('nukta letters and two-part vowel signs, precomposed or not, '
          'compare equal', () {
        same('\u095B\u0930\u093E', '\u091C\u093C\u0930\u093E', because: 'ज़रा');

        // য় in সময় (time), both ways.
        same('সময়', 'সময়', because: 'সময়');
        same('ড়', 'ড়', because: 'ড়');
        same('ঢ়', 'ঢ়', because: 'ঢ়');
        // ো in বোন (sister): one code point, or ে then া.
        same('বোন', 'বোন', because: 'বোন');
        same('ৌ', 'ৌ', because: 'ৌ');
      });

      test('Indic digits read as 0 to 9', () {
        same('२०२०', '2020', because: 'Devanagari २०२०');
        same('১৯৫০', '1950', because: 'Bengali ১৯৫০');
        same('౪౦౦౭', '4007', because: 'Telugu ౪౦౦౭');
        same('૧૯૬૦', '1960', because: 'Gujarati ૧૯૬૦');
        same('೨೦೨೬', '2026', because: 'Kannada ೨೦೨೬');
      });
    });

    group('what stays different', () {
      test('a missing nukta is right but flagged, not exact', () {
        final graded = grader.grade('जरा', 'ज़रा');
        expect(graded.outcome, AnswerOutcome.closeDiacritics);
        expect(graded.foldedDiacritics, isTrue);
      });
    });
  });

  group('the meaning rules', () {
    bool eq(String given, String expected) => meaningsEqual(given, expected);

    test('owner examples', () {
      expect(eq('there is no time', "There's no time."), isTrue);
      expect(eq('how are you', 'How are you? (respectful)'), isTrue);
      expect(eq('can you repeat that', 'Please say that again.'), isFalse);
    });

    test('rules 1, 3, 4 and 5: case and punctuation, a bracketed qualifier, '
        'each ; meaning on its own, a leading to', () {
      expect(eq('  HELLO,   there! ', 'hello there'), isTrue);
      expect(eq('"hello"', 'Hello.'), isTrue);

      expect(eq('how are you', 'How are you? (respectful)'), isTrue);
      expect(
        eq('how are you respectful', 'How are you? (respectful)'),
        isFalse,
      );
      expect(eq('how are you (respectful)', 'How are you?'), isTrue);

      expect(eq('one book', 'a book; one book'), isTrue);
      expect(eq('a book', 'a book; one book'), isTrue);
      expect(eq('two books', 'a book; one book'), isFalse);

      expect(eq('say', 'to say'), isTrue);
      expect(eq('to say', 'say'), isTrue);
      expect(eq('to', 'to say'), isFalse);
    });

    test('rule 2: contractions, straight and curly', () {
      for (final (c, e) in [
        ("it's cold", 'it is cold'),
        ("I'm here", 'I am here'),
        ("you're late", 'you are late'),
        ("we're in", 'we are in'),
        ("they're in", 'they are in'),
        ("he's in", 'he is in'),
        ("she's in", 'she is in'),
        ("that's it", 'that is it'),
        ("what's this", 'what is this'),
        ("who's there", 'who is there'),
        ("where's it", 'where is it'),
        ("let's go", 'let us go'),
        ("don't go", 'do not go'),
        ("doesn't go", 'does not go'),
        ("didn't go", 'did not go'),
        ("isn't", 'is not'),
        ("aren't", 'are not'),
        ("wasn't", 'was not'),
        ("weren't", 'were not'),
        ("haven't", 'have not'),
        ("hasn't", 'has not'),
        ("hadn't", 'had not'),
        ("can't", 'cannot'),
        ("can't", 'can not'),
        ("couldn't", 'could not'),
        ("won't", 'will not'),
        ("wouldn't", 'would not'),
        ("shouldn't", 'should not'),
        ("I'll go", 'I will go'),
        ("you'll go", 'you will go'),
        ("we'll go", 'we will go'),
        ("they'll go", 'they will go'),
        ("I've gone", 'I have gone'),
        ("you've gone", 'you have gone'),
        ("we've gone", 'we have gone'),
        ("they've gone", 'they have gone'),
        ("I'd go", 'I would go'),
      ]) {
        expect(eq(c, e), isTrue, reason: '$c / $e');
        expect(eq(e, c), isTrue, reason: '$e / $c');
      }
      expect(eq('there’s no time', 'there is no time'), isTrue);
      expect(eq("there's no time", 'There’s no time'), isTrue);
    });

    group('AnswerGrader(meaning: true)', () {
      const grader = AnswerGrader(meaning: true);

      test('paraphrase stays wrong', () {
        expect(
          grader.grade('can you repeat that', 'Please say that again.').outcome,
          AnswerOutcome.wrong,
        );
      });

      test('a typo after the rules is still a near miss', () {
        expect(
          grader.grade('there is no tiem', "There's no time.").outcome,
          AnswerOutcome.closeTypo,
        );
      });
    });
  });

  group('self-grades', () {
    final now = DateTime(2026, 9, 28, 19);

    group('SelfGrade', () {
      test('Again, Hard, Good, Easy grade 1, 3, 4, 5; Again on a new card is '
          'due tomorrow', () {
        expect(SelfGrade.values.map((g) => g.toGrade()), [1, 3, 4, 5]);

        final state = Fsrs.next(
          null,
          SelfGrade.again.toGrade(),
          now: now,
          rated: true,
        );
        expect(state.intervalDays, 1);
        expect(state.dueAt, DateTime(2026, 9, 29, 19));
      });
    });
  });

  group('readings based on ISO 15919', () {
    test('pālu and palu are both right; a reading is typed as people type '
        'it: c as ch, ś as sh, m̐ as n', () {
      final telugu = RomanisedSpelling(bundled('te'));
      for (final typed in <String>['palu', 'paalu', 'pālu']) {
        expect(
          telugu.grade(typed, <String>['pālu']).outcome,
          AnswerOutcome.exact,
          reason: typed,
        );
      }

      final hindi = RomanisedSpelling(bundled('hi'));
      expect(hindi.typedForm('cāy'), 'chāy');
      expect(hindi.typedForm('acchā'), 'achhā');
      expect(hindi.typedForm('śādī'), 'shādī');
      expect(hindi.typedForm('haim̐'), 'hain');
      expect(hindi.grade('chai', <String>['cāy']).outcome, AnswerOutcome.exact);
      expect(
        hindi.grade('shadi', <String>['śādī']).outcome,
        AnswerOutcome.exact,
      );
    });
  });

  group('transliteration letters', () {
    final plain = RomanisedSpelling(null);
    AnswerOutcome grade(String typed, String reading) =>
        plain.grade(typed, <String>[reading]).outcome;

    test('pinyin with caron tones is typed without them', () {
      expect(grade('lu', 'lǔ'), AnswerOutcome.exact);
      expect(grade('nihao', 'nǐ hǎo'), AnswerOutcome.exact);
      expect(grade('nu', 'nǚ'), AnswerOutcome.exact);
    });

    test('Egyptian letters are typed as plain ones, and none empties a '
        'word', () {
      expect(grade('ankh', 'ꜥnḫ'), isNot(AnswerOutcome.wrong));
      expect(grade('anh', 'ꜥnḫ'), AnswerOutcome.exact);
      expect(grade('dd', 'ḏd'), AnswerOutcome.exact);
      expect(grade('tz', 'ṯz'), AnswerOutcome.exact);
      expect(plain.key('ꜥꜣ'), isNotEmpty);
    });

    test('sign indices and laryngeal subscripts are typed as digits', () {
      expect(grade('du3', 'du₃'), AnswerOutcome.exact);
      expect(grade('h2owis', 'h₂ówis'), AnswerOutcome.exact);
      expect(grade('kwetwores', 'kʷetwóres'), AnswerOutcome.exact);
      expect(grade('bhreh2ter', 'bʰréh₂ter'), AnswerOutcome.exact);
    });

    test('a mark typed apart from its letter folds away like a composed '
        'one', () {
      expect(grade('ksatriya', 'k\u1E63atriya'), AnswerOutcome.exact);
      expect(grade('ma', 'ma\u0304'), AnswerOutcome.exact);
      expect(grade('lu', 'lu\u030C'), AnswerOutcome.exact);
    });

    test('the half-ring letters and the apostrophe are not typed', () {
      expect(grade('ayn', 'ʿayn'), AnswerOutcome.exact);
      expect(grade('quran', 'qurʾān'), AnswerOutcome.exact);
      expect(grade('mana', 'maʻnā'), AnswerOutcome.exact);
    });
  });

  group('romanised answers', () {
    final spelling = RomanisedSpelling(hindi);

    test('each spelling a learner may type is written the decks\' way', () {
      expect(spelling.key('kitnaa'), spelling.key('kitna'));
      expect(spelling.key('paanee'), spelling.key('pani'));
      expect(spelling.key('doodh'), spelling.key('dudh'));
      expect(spelling.key('wahan'), spelling.key('vahan'));
    });

    test('a romanised answer is exact, a near miss to judge, or wrong, and '
        'names the reading it matched', () {
      expect(
        spelling.grade('jaatee hoon', <String>['jati hun']),
        isA<GradedAnswer>()
            .having((g) => g.outcome, 'outcome', AnswerOutcome.exact)
            .having((g) => g.matched, 'matched', 'jati hun'),
      );
      expect(
        spelling.grade('jata hun', <String>['jati hun', 'jata hun']).matched,
        'jata hun',
      );
      expect(
        spelling.grade('jatu hun', <String>['jati hun']).outcome,
        AnswerOutcome.closeTypo,
      );
      expect(
        spelling.grade('khana', <String>['jati hun']).outcome,
        AnswerOutcome.wrong,
      );
      expect(
        spelling.grade('', <String>['jati hun']).outcome,
        AnswerOutcome.wrong,
      );
      expect(
        spelling.grade('x', const <String>[]).outcome,
        AnswerOutcome.wrong,
      );
    });
  });

  group('transliteration and the script units', () {
    late AppState state;

    setUp(() async {
      state = AppState.test(tts: FixedTtsEngine(<String>{'hi'}));
      await state.load();
    });

    tearDown(() => state.dispose());

    /// A session in Latin letters on [deckId]'s cards in [skill], starting
    /// on the first card [where] picks.
    DrillSession latin(
      String deckId,
      Skill skill, {
      bool Function(Card card)? where,
    }) {
      final cards = state.deckById(deckId)!.cards;
      final first = cards.firstWhere(
        (c) => c.reading != null && (where?.call(c) ?? true),
      );
      final mode = skill.mode!;
      final session = DrillSession(
        state: state,
        items: <SessionItem>[
          for (final card in <Card>[first, ...cards.where((c) => c != first)])
            SessionItem(card: card, mode: mode, state: null),
        ],
        inputMode: InputMode.translit,
      );
      addTearDown(session.dispose);
      expect(session.transliterating, isTrue);
      return session;
    }

    test('before the script units the reading counts in full, after them '
        'as a hard recall', () {
      final session = latin('hi-en-market', Skill.production);
      expect(session.expectsScript, isFalse);
      session.check(session.item.card.reading!);
      expect(session.answer!.graded!.outcome, AnswerOutcome.exact);
      expect(session.answer!.grade, 5);

      {
        // Placed past Hindi's script units: the script is expected now.
        state.settings.placedDecks = <String>{
          for (final unit in state.courseUnits('hi'))
            for (final entry in unit)
              if (entry.id.contains('-script-')) entry.id,
        };
        final session = latin('hi-en-market', Skill.production);
        expect(session.expectsScript, isTrue);
        expect(
          DrillSession(state: state, items: session.items).inputMode,
          InputMode.script,
        );
        session.check(session.item.card.reading!);
        expect(session.answer!.graded!.outcome, AnswerOutcome.exact);
        expect(session.answer!.grade, DrillSession.romanisedGrade);
      }
    });

    test('the script is still accepted, in full', () {
      final session = latin('hi-en-market', Skill.production);
      session.check(session.item.card.target);
      expect(session.answer!.graded!.outcome, AnswerOutcome.exact);
      expect(session.answer!.grade, 5);
    });
  });

  group('spoken answers', () {
    group('grading what was heard', () {
      late AppState state;
      late FixedSpeechEngine speech;

      Future<DrillSession> session() async {
        speech = FixedSpeechEngine(onDevice: <String>{'es'});
        state = speaking(speech, on: true);
        await state.load();
        await state.startSpeech();
        final queue = state.buildSession(
          DrillRequest.untaught(spanish, skill: Skill.speaking),
        );
        return DrillSession(state: state, items: queue.items);
      }

      tearDown(() => state.dispose());

      test(
        'the best reading, right, is correct and recorded with what was '
        'heard; a near miss is wrong, being another word in speech',
        () async {
          final s = await session();
          addTearDown(s.dispose);
          final target = s.item.card.target;
          speech.next = <SpeechAlternative>[SpeechAlternative(target)];
          await s.listen();
          expect(s.answer!.graded!.outcome.isCorrect, isTrue);
          expect(s.answer!.grade, 5);
          expect(state.progress.log.single.answerGiven, target);
          expect(state.progress.log.single.mode, DrillMode.speaking);

          s.next();
          final next = s.item.card.target;
          final miss = '${next.substring(0, next.length - 1)}x';
          s.checkSpoken(<SpeechAlternative>[SpeechAlternative(miss)]);
          expect(s.answer!.graded!.outcome.isCorrect, isFalse);
          expect(s.answer!.awaitsJudgement, isFalse);
        },
      );

      test('another reading counts if the recogniser said it was fairly sure '
          'of it, and not otherwise', () async {
        final s = await session();
        addTearDown(s.dispose);
        final target = s.item.card.target;
        s.checkSpoken(<SpeechAlternative>[
          const SpeechAlternative('xyz', confidence: 0.9),
          SpeechAlternative(target, confidence: 0.6),
        ]);
        expect(s.answer!.graded!.outcome.isCorrect, isTrue);
        expect(s.answer!.typed, target);

        // Low, 0 as Android gives every reading after the best, or none
        // given: not taken as what was said.
        for (final confidence in <double?>[0.2, 0.0, null]) {
          s.next();
          final other = s.item.card.target;
          s.checkSpoken(<SpeechAlternative>[
            const SpeechAlternative('xyz', confidence: 0.9),
            SpeechAlternative(other, confidence: confidence),
          ]);
          expect(
            s.answer!.graded!.outcome.isCorrect,
            isFalse,
            reason: '$confidence',
          );
          expect(s.answer!.typed, 'xyz');
          expect(s.answer!.grade, 1);
        }
      });

      test('nothing heard records nothing, and the card can be said again or '
          'skipped', () async {
        final s = await session();
        addTearDown(s.dispose);
        final first = s.item.card.id;
        await s.listen();
        expect(s.unheard, SpeechFailure.noMatch);
        expect(s.answer, isNull);
        expect(state.progress.log, isEmpty);
        s.skipUnheard();
        expect(s.item.card.id, isNot(first));
        expect(state.progress.log, isEmpty);
      });
    });
  });

  group('sound contrasts', () {
    final sounds = parseSounds(bengali, source: 'bn-sounds.yaml');
    String? between(String heard, String expected) =>
        sounds.between(heard, expected)?.id;

    group('a word heard instead of the answer', () {
      test('a word heard with one sound changed names the contrast; nothing '
          'for the same word, two changes, or another word', () {
        expect(between('খাল', 'কাল'), 'aspiration');
        expect(between('কাল', 'খাল'), 'aspiration');
        expect(between('বাত', 'ভাত'), 'aspiration');
        expect(between('ডান', 'দান'), 'dental-retroflex');

        expect(between('কাল', 'কাল।'), isNull);
        expect(between('খাড', 'কাল'), isNull, reason: 'two changes');
        expect(between('খাল', 'খালি'), isNull, reason: 'an added i');
        expect(between('মাছ', 'কাল'), isNull);
        expect(between('', 'কাল'), isNull);
      });
    });
  });

  group('contrast feedback', () {
    group('the feedback', () {
      const kal = Card(id: 'k', deckId: 'd', target: 'কাল', native: 'time');
      const khal = Card(id: 'h', deckId: 'd', target: 'খাল', native: 'canal');
      const breath = SoundContrast(
        id: 'aspiration',
        name: 'a breath after the consonant',
        pairs: <(String, String)>[('ক', 'খ')],
      );

      Future<void> pump(WidgetTester tester, TypedAnswer answer) async {
        usePhone(tester);
        await pumpScreen(
          tester,
          Scaffold(
            body: AnswerFeedback(
              answer: answer,
              card: kal,
              expected: kal.target,
              transliterating: false,
              spoken: true,
            ),
          ),
        );
      }

      const wrong = GradedAnswer(AnswerOutcome.wrong, matched: null);

      testWidgets('names the sound, and what the word heard means', (
        tester,
      ) async {
        await pump(
          tester,
          const TypedAnswer(
            typed: 'খাল',
            graded: wrong,
            grade: 1,
            contrast: breath,
            heardCard: khal,
          ),
        );
        final l10n = l10nOf(tester);
        expect(
          find.text(
            l10n.feedbackSaidContrastMeaning(
              'খাল',
              'canal',
              'a breath after the consonant',
              'কাল',
            ),
          ),
          findsOneWidget,
        );
      });
    });
  });

  group('near misses', () {
    late AppState state;
    late DrillSession session;

    setUp(() async {
      state = AppState.test();
      await state.load();
      final queue = state.buildSession(
        DrillRequest.untaught(future, skill: Skill.grammar),
      );
      session = DrillSession(state: state, items: queue.items);
    });

    tearDown(() {
      session.dispose();
      state.dispose();
    });

    test("another cell's form, one letter off, is wrong", () {
      final card = session.item.card;
      // చేస్తాను against చేస్తావు or చేస్తాడు: the wrong person, not a slip.
      final other = state
          .deckById(future)!
          .cards
          .firstWhere(
            (c) =>
                c.target != card.target &&
                !card.altTarget.contains(c.target) &&
                levenshtein(c.target, card.target) == 1,
          );
      session.check(other.target);
      expect(session.answer!.graded!.outcome, AnswerOutcome.wrong);
      expect(session.answer!.awaitsJudgement, isFalse);
    });
  });
}
