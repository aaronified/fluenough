// The daily questions (#519): written from card data, the weakest first, the
// same for every reviewer; answered Yes, No or flagged; counted per day with
// what is left waiting for tomorrow; sent by mail like a review, one file per
// language, marked sent only once a mail app takes them.
//
// The words are made up (AGENTS.md: tests check behaviour).

import 'dart:convert';

import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/app/reviewing.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/review/question_generator.dart';
import 'package:fluenough/core/review/question_log.dart';
import 'package:fluenough/core/review/questions_file.dart';
import 'package:fluenough/core/review/rater_code.dart';
import 'package:fluenough/core/review/review_question.dart';
import 'package:fluenough/features/review/daily_questions_page.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/review_fixture.dart';

const LanguageInfo _xx = LanguageInfo(
  code: 'xx',
  iso639_3: 'xxx',
  name: 'Xish',
);
const LanguageInfo _yy = LanguageInfo(
  code: 'yy',
  iso639_3: 'yyy',
  name: 'Yish',
);
const LanguageInfo _en = LanguageInfo(
  code: 'en',
  iso639_3: 'eng',
  name: 'English',
);

Deck _deck(
  String id,
  List<Card> cards, {
  LanguageInfo language = _xx,
  List<String> tags = const <String>[],
  Map<String, List<String>> checkedBy = const <String, List<String>>{},
}) => Deck(
  id: id,
  name: id,
  kind: DeckKind.vocab,
  language: language,
  native: _en,
  license: 'CC0-1.0',
  cards: cards,
  tags: tags,
  checkedBy: checkedBy,
);

Card _card(
  String id,
  String target, {
  String native = 'a thing',
  String? reading,
  List<CardExample> examples = const <CardExample>[],
  List<CardItem> confusables = const <CardItem>[],
  String? audio,
  MediaCredit? audioCredit,
  bool practiceOnly = false,
}) => Card(
  id: id,
  deckId: 'xx-en-deck',
  target: target,
  native: native,
  reading: reading,
  examples: examples,
  confusables: confusables,
  audio: audio,
  audioCredit: audioCredit,
  practiceOnly: practiceOnly,
);

List<String> _ids(List<ReviewQuestion> questions) => <String>[
  for (final q in questions) q.id,
];

void main() {
  group('the questions are written from card data, weakest first', () {
    test(
      'unverified data comes before Wiktionary data, then in deck order',
      () {
        final questions = generateQuestions(<Deck>[
          _deck('xx-en-deck', <Card>[
            _card(
              'xx-0001',
              'blorp',
              examples: const <CardExample>[
                CardExample(
                  target: 'blorp zan',
                  native: 'a zan of blorp',
                  source: 'https://en.wiktionary.org/wiki/blorp',
                ),
                CardExample(target: 'zan blorp', native: 'blorp of zan'),
              ],
            ),
            _card('xx-0002', 'quint'),
          ]),
        ]);
        expect(_ids(questions), <String>[
          'xx-0001|meaning',
          'xx-0001|example:${pointHash('zan blorp')}',
          'xx-0002|meaning',
          'xx-0001|example:${pointHash('blorp zan')}',
        ]);
        expect(questions.map((q) => q.weakness), <int>[0, 0, 0, 1]);
      },
    );

    test('a Tatoeba example is semi-verified too', () {
      final questions = generateQuestions(<Deck>[
        _deck('xx-en-deck', <Card>[
          _card(
            'xx-0001',
            'blorp',
            examples: const <CardExample>[
              CardExample(
                target: 'blorp zan',
                native: 'a zan of blorp',
                source: 'https://tatoeba.org/en/sentences/show/1',
              ),
            ],
          ),
        ]),
      ]);
      expect(questions.last.kind, QuestionKind.example);
      expect(questions.last.weakness, 1);
    });

    test('a card asks about two examples at most, and names each by its text '
        'so that reordering does not change the question', () {
      const a = CardExample(target: 'aa aa', native: 'one');
      const b = CardExample(target: 'bb bb', native: 'two');
      const c = CardExample(target: 'cc cc', native: 'three');
      List<String> examplePoints(List<CardExample> examples) => <String>[
        for (final q in generateQuestions(<Deck>[
          _deck('xx-en-deck', <Card>[
            _card('xx-0001', 'blorp', examples: examples),
          ]),
        ]))
          if (q.kind == QuestionKind.example) q.point,
      ];
      final first = examplePoints(<CardExample>[a, b, c]);
      expect(first, hasLength(maxExamplesAsked));
      expect(examplePoints(<CardExample>[b, a, c]).toSet(), first.toSet());
    });

    test('a card two reviewers signed off is not asked about; one sign-off '
        'makes its data semi-verified', () {
      final questions = generateQuestions(<Deck>[
        _deck(
          'xx-en-deck',
          <Card>[
            _card('xx-0001', 'blorp'),
            _card('xx-0002', 'quint'),
            _card('xx-0003', 'wend'),
          ],
          checkedBy: const <String, List<String>>{
            'xx-0001': <String>['FL-7K3M-Q9TD-6', 'FL-0000-0000-0'],
            'xx-0002': <String>['FL-7K3M-Q9TD-6'],
          },
        ),
      ]);
      expect(_ids(questions), <String>['xx-0003|meaning', 'xx-0002|meaning']);
    });

    test(
      'offensive decks, generated cards and repeated cards are left out',
      () {
        final questions = generateQuestions(<Deck>[
          _deck(
            'xx-en-rude',
            <Card>[_card('xx-0090', 'snarf')],
            tags: const <String>['offensive'],
          ),
          _deck('xx-en-deck', <Card>[
            _card('xx-0001', 'blorp'),
            _card('xx-0002', 'quint', practiceOnly: true),
          ]),
          _deck('xx-en-again', <Card>[_card('xx-0001', 'blorp')]),
        ]);
        expect(_ids(questions), <String>['xx-0001|meaning']);
      },
    );

    test('a confusable that names a card is asked about by that card\'s '
        'word, and each is a question of its own', () {
      final questions = generateQuestions(<Deck>[
        _deck('xx-en-deck', <Card>[
          _card(
            'xx-0001',
            'blorp',
            confusables: const <CardItem>[
              CardItem(id: 'c1', ref: 'xx-0002'),
              CardItem(id: 'c2', word: 'blorb', reading: 'blorb', text: 'x'),
            ],
          ),
          _card('xx-0002', 'quint', reading: 'kwint', native: 'a quint'),
        ]),
      ]);
      final confusables = questions
          .where((q) => q.kind == QuestionKind.confusable)
          .toList();
      expect(_ids(confusables), <String>[
        'xx-0001|confusable:c1',
        'xx-0001|confusable:c2',
      ]);
      expect(confusables.first.shown, 'quint');
      expect(confusables.first.shownReading, 'kwint');
      expect(confusables.first.shownMeaning, 'a quint');
    });

    test('a recording can only be confirmed or flagged: there is no No, and '
        'only a card with a recording is asked', () {
      final questions = generateQuestions(<Deck>[
        _deck('xx-en-deck', <Card>[
          _card('xx-0001', 'blorp', audio: 'audio/xx-0001.opus'),
          _card('xx-0002', 'quint'),
        ]),
      ]);
      final sounds = questions.where((q) => q.kind == QuestionKind.sound);
      expect(_ids(sounds.toList()), <String>['xx-0001|sound']);
      expect(QuestionKind.sound.answers, <QuestionAnswer>[
        QuestionAnswer.yes,
        QuestionAnswer.flag,
      ]);
      expect(QuestionKind.meaning.answers, <QuestionAnswer>[
        QuestionAnswer.yes,
        QuestionAnswer.no,
      ]);
    });

    test('what was answered or put off is not asked again', () {
      final decks = <Deck>[
        _deck('xx-en-deck', <Card>[
          _card('xx-0001', 'blorp'),
          _card('xx-0002', 'quint'),
        ]),
      ];
      expect(
        _ids(generateQuestions(decks, skip: <String>{'xx-0001|meaning'})),
        <String>['xx-0002|meaning'],
      );
    });

    test('a picture proposal is a question that pins its file', () {
      final questions = generateQuestions(
        <Deck>[
          _deck('xx-en-deck', <Card>[_card('xx-0001', 'blorp')]),
        ],
        images: const <ImageProposal>[
          ImageProposal(
            language: 'xx',
            card: 'xx-0001',
            file: 'Blorp.jpg',
            credit: 'A. Maker',
            license: 'CC-BY-SA-4.0',
          ),
          ImageProposal(language: 'xx', card: 'xx-0404', file: 'Lost.jpg'),
        ],
      );
      final image = questions.singleWhere((q) => q.kind == QuestionKind.image);
      expect(image.id, 'xx-0001|image:Blorp.jpg');
      expect(image.shownMeaning, 'A. Maker · CC-BY-SA-4.0');
    });

    test('every reviewer is asked the same questions in the same order', () {
      List<String> ask() => _ids(
        generateQuestions(<Deck>[
          _deck('xx-en-deck', <Card>[
            _card('xx-0001', 'blorp'),
            _card('xx-0002', 'quint'),
          ]),
          _deck('yy-en-deck', <Card>[_card('yy-0001', 'zorb')], language: _yy),
        ]),
      );
      expect(ask(), ask());
    });

    test('an example is named by a hash that is the standard FNV-1a', () {
      expect(pointHash('a'), 'e40c292c');
      expect(pointHash('foobar'), 'bf9cf968');
      expect(pointHash('  a '), pointHash('a'));
    });
  });

  group('the answers kept on the phone', () {
    const question = ReviewQuestion(
      language: 'xx',
      card: 'xx-0001',
      kind: QuestionKind.meaning,
      point: 'meaning',
      word: 'blorp',
      weakness: 0,
    );
    const example = ReviewQuestion(
      language: 'xx',
      card: 'xx-0001',
      kind: QuestionKind.example,
      point: 'example:0000abcd',
      word: 'blorp',
      weakness: 0,
    );

    test('answering twice keeps the last answer, and a reason must be one '
        'the question knows', () {
      final log = const QuestionLog()
          .answer(question, QuestionAnswer.no, '2026-10-30', reason: 'bogus')
          .answer(
            question,
            QuestionAnswer.no,
            '2026-10-30',
            reason: 'awkward',
            why: ' sounds stiff ',
          );
      final given = log.answers[question.id]!;
      expect(log.answers, hasLength(1));
      expect(given.reason, 'awkward');
      expect(given.why, 'sounds stiff');
    });

    test('a Yes carries no reason and no text', () {
      final log = const QuestionLog().answer(
        question,
        QuestionAnswer.yes,
        '2026-10-30',
        reason: 'wrong',
        why: 'x',
      );
      expect(log.answers[question.id]!.reason, isNull);
      expect(log.answers[question.id]!.why, '');
    });

    test('the day\'s count is what was answered that day, and what is left '
        'never adds up', () {
      var log = const QuestionLog()
          .answer(question, QuestionAnswer.yes, '2026-10-29')
          .answer(example, QuestionAnswer.yes, '2026-10-30');
      expect(log.answeredOn('2026-10-30'), 1);
      expect(log.leftOn('2026-10-30', 10), 9);
      expect(log.leftOn('2026-10-31', 10), 10);
      log = log.answer(question, QuestionAnswer.yes, '2026-10-30');
      expect(log.leftOn('2026-10-30', 2), 0);
      expect(log.leftOn('2026-10-30', 1), 0);
    });

    test('a skip hides a question for that day only', () {
      final log = const QuestionLog().skip(question, '2026-10-30');
      expect(log.hiddenOn('2026-10-30'), contains(question.id));
      expect(log.hiddenOn('2026-10-31'), isNot(contains(question.id)));
      expect(log.since('2026-10-31').skipped, isEmpty);
    });

    test('an answer is taken back before it is sent, never after', () {
      var log = const QuestionLog().answer(
        question,
        QuestionAnswer.yes,
        '2026-10-30',
      );
      expect(log.undo(question).answers, isEmpty);
      log = log.sentAt(<String>[question.id], DateTime.utc(2026, 10, 30));
      expect(log.unsent, isEmpty);
      expect(log.undo(question).answers, hasLength(1));
    });

    test('it survives being written and read, and unreadable text is an '
        'empty log', () {
      final log = const QuestionLog()
          .answer(
            question,
            QuestionAnswer.no,
            '2026-10-30',
            reason: 'wrong',
            why: 'it is a different thing',
          )
          .skip(example, '2026-10-30');
      final again = QuestionLog.fromJson(log.toJson());
      expect(again.answers[question.id]!.reason, 'wrong');
      expect(again.answers[question.id]!.why, 'it is a different thing');
      expect(again.skipped, log.skipped);
      expect(QuestionLog.fromJson('not json').isEmpty, isTrue);
      expect(QuestionLog.fromJson('[1]').isEmpty, isTrue);
    });
  });

  group('the questions file', () {
    final code = RaterCode.tryParse('FL-7K3M-Q9TD-6')!;
    LoggedAnswer answer(String language, String card, QuestionAnswer a) =>
        LoggedAnswer(
          language: language,
          card: card,
          point: 'meaning',
          kind: QuestionKind.meaning,
          answer: a,
          on: '2026-10-30',
          reason: a == QuestionAnswer.no ? 'wrong' : null,
          why: a == QuestionAnswer.no ? 'for the owner' : '',
        );

    test('carries the code, language, version and answers, and stands on its '
        'own', () {
      final text = QuestionsFile.encode(
        <LoggedAnswer>[
          answer('xx', 'xx-0001', QuestionAnswer.yes),
          answer('yy', 'yy-0001', QuestionAnswer.yes),
          answer('xx', 'xx-0002', QuestionAnswer.no),
        ],
        language: 'xx',
        code: code,
        appVersion: '9.9.9',
        made: DateTime.utc(2026, 10, 30, 8),
      );
      final file = jsonDecode(text) as Map<String, Object?>;
      expect(file['format'], 'fluenough-questions');
      expect(file['rater_code'], 'FL-7K3M-Q9TD-6');
      expect(file['language'], 'xx');
      expect(file['app_version'], '9.9.9');
      expect(file['made'], '2026-10-30T08:00:00.000Z');
      final answers = (file['answers']! as List).cast<Map<String, Object?>>();
      expect(answers.map((a) => a['card']), <String>['xx-0001', 'xx-0002']);
      expect(answers.last, <String, Object?>{
        'card': 'xx-0002',
        'point': 'meaning',
        'kind': 'meaning',
        'answer': 'no',
        'reason': 'wrong',
        'why': 'for the owner',
      });
      expect(answers.first.containsKey('reason'), isFalse);
    });

    test('the subject carries the code and the languages, in English', () {
      expect(
        QuestionsMail.subject(code, <String>['xx', 'yy']),
        '[Fluenough questions] FL-7K3M-Q9TD-6 (xx, yy)',
      );
      expect(QuestionsFile.name('xx'), 'fluenough-questions-xx.json');
    });
  });

  group('the reviewer\'s day', () {
    Future<SettingsNotifier> reviewerSettings() async =>
        SettingsNotifier(
            spokenLanguages: const <String>['en', 'te'],
            learningLanguages: const <String>['te'],
            learningChosen: true,
          )
          ..reviewLanguages = const <String>{'te'}
          ..scriptsRead = const <String, bool>{'en': true, 'te': true};

    test(
      'ten a day until the reviewer chooses, and the choice is kept',
      () async {
        final settings = await reviewerSettings();
        expect(settings.reviewQuestionsPerDay, 10);
        settings.reviewQuestionsPerDay = 5;
        final stored = settings.toStored();
        expect(stored['review_questions_per_day'], '5');
        final again = SettingsNotifier()..restore(stored);
        expect(again.reviewQuestionsPerDay, 5);
      },
    );

    test('answers go in one mail, a file a language, and are marked sent '
        'only when a mail app takes them', () async {
      final share = FixedMailShare(shares: false);
      final state = await reviewState(
        share: share,
        reviewing: true,
        settings: await reviewerSettings(),
      );
      addTearDown(state.dispose);
      final reviewing = state.reviewing;
      final questions = generateQuestions(<Deck>[
        for (final entry in state.decks) entry.deck,
      ]);
      expect(questions, isNotEmpty);
      reviewing.answerQuestion(questions.first, QuestionAnswer.yes);
      reviewing.answerQuestion(
        questions[1],
        QuestionAnswer.no,
        reason: questions[1].kind.reasons.first,
        why: 'a note',
      );
      expect(reviewing.unsentAnswers, hasLength(2));

      expect(
        await reviewing.sendQuestions(body: 'For you'),
        ReviewSendOutcome.noMailApp,
      );
      expect(reviewing.unsentAnswers, hasLength(2));

      share.shares = true;
      expect(
        await reviewing.sendQuestions(body: 'For you'),
        ReviewSendOutcome.inMailApp,
      );
      final mail = share.shared.last;
      expect(mail.to, <String>[AppLinks.feedbackEmail]);
      expect(mail.subject, '[Fluenough questions] ${reviewing.code} (te)');
      expect(mail.files.map((f) => f.name), <String>[
        'fluenough-questions-te.json',
      ]);
      final file = jsonDecode(mail.files.single.text) as Map<String, Object?>;
      expect(file['rater_code'], '${reviewing.code}');
      expect(file['app_version'], AppInfo.version);
      expect((file['answers']! as List), hasLength(2));
      expect(reviewing.unsentAnswers, isEmpty);
      expect(
        await reviewing.sendQuestions(body: ''),
        ReviewSendOutcome.nothingToSend,
      );
    });

    test(
      'what is not answered today waits, and the count is the day\'s',
      () async {
        final state = await reviewState(
          reviewing: true,
          settings: await reviewerSettings(),
        );
        addTearDown(state.dispose);
        final reviewing = state.reviewing;
        reviewing.questionsPerDay = 1;
        expect(reviewing.questionsLeftToday, 1);
        final questions = generateQuestions(<Deck>[
          for (final entry in state.decks) entry.deck,
        ]);
        reviewing.answerQuestion(questions.first, QuestionAnswer.yes);
        expect(reviewing.questionsLeftToday, 0);
        reviewing.questionsPerDay = 3;
        expect(reviewing.questionsLeftToday, 2);
      },
    );
  });

  group('the questions screen', () {
    Future<AppState> open(WidgetTester tester, {FixedMailShare? share}) async {
      usePhone(tester);
      final state = await reviewState(
        reviewing: true,
        share: share ?? FixedMailShare(),
        settings:
            SettingsNotifier(
                spokenLanguages: const <String>['en', 'te'],
                learningLanguages: const <String>['te'],
                learningChosen: true,
              )
              ..reviewLanguages = const <String>{'te'}
              ..scriptsRead = const <String, bool>{'en': true, 'te': true},
      );
      await pumpScreen(tester, const DailyQuestionsPage(), state: state);
      return state;
    }

    testWidgets('asks one question at a time and moves on after a Yes', (
      tester,
    ) async {
      final state = await open(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewQuestionsProgress(1, 2)), findsOneWidget);
      expect(
        find.text(l10n.reviewQuestionMeaning('విధవ (vidhava)')),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.reviewQuestionYes));
      await tester.pumpAndSettle();
      expect(
        state.reviewing.questions.answers['$alikeCard|meaning']!.answer,
        QuestionAnswer.yes,
      );
      expect(find.text(l10n.reviewQuestionsProgress(2, 2)), findsOneWidget);
      expect(
        find.text(l10n.reviewQuestionMeaning('అమ్మ (amma)')),
        findsOneWidget,
      );
    });

    testWidgets('a No asks why, and the reason and the line are kept, then '
        'the day ends with Send answers', (tester) async {
      final share = FixedMailShare();
      final state = await open(tester, share: share);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.reviewQuestionYes));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reviewQuestionNo));
      await tester.pumpAndSettle();
      expect(find.text(l10n.reviewQuestionWhyNo), findsOneWidget);
      await tester.tap(find.text(l10n.reviewReasonAwkward));
      await tester.enterText(find.byType(TextField), 'too stiff');
      await tester.tap(find.text(l10n.reviewQuestionSave));
      await tester.pumpAndSettle();
      final given = state.reviewing.questions.answers['$plainCard|meaning']!;
      expect(given.answer, QuestionAnswer.no);
      expect(given.reason, 'awkward');
      expect(given.why, 'too stiff');

      expect(find.text(l10n.reviewQuestionsDoneTitle), findsOneWidget);
      await tester.tap(find.text(l10n.reviewQuestionsSend(2)));
      await tester.pumpAndSettle();
      expect(share.shared, hasLength(1));
      expect(state.reviewing.unsentAnswers, isEmpty);
    });

    testWidgets('Skip puts a question off to tomorrow, without counting it', (
      tester,
    ) async {
      final state = await open(tester);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.reviewQuestionSkip));
      await tester.pumpAndSettle();
      expect(state.reviewing.questions.answers, isEmpty);
      expect(
        state.reviewing.questions.hiddenOn(state.reviewing.today),
        contains('$alikeCard|meaning'),
      );
      expect(
        find.text(l10n.reviewQuestionMeaning('అమ్మ (amma)')),
        findsOneWidget,
      );
    });
  });
}
