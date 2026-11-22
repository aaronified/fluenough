// Reviews to send (owner, 2026-11-22): the one home for sending reviews. A
// tickable group per deck, opening to every item that will be sent, and one
// per language of daily-question answers; one Send button counting what is
// ticked; a card can be dropped from the mail; Sent lists the mails with
// Send again while the deck does not show their changes. Bengali and
// Hindustani examples, light and dark, at the app's 1.4x text.

import 'dart:convert';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/facets.dart';
import 'package:fluenough/core/review/review_file.dart';
import 'package:fluenough/core/review/review_question.dart';
import 'package:fluenough/features/review/reviews_to_send_page.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/review_fixture.dart' show reviewerCode;

const String _bnDeck = 'bn-en-phrasebook';
const String _hiDeck = 'hi-en-slang';

/// A Bengali phrasebook and a Hindustani deck of slang, taught from English.
/// [proposed] is a card's `proposed:` list, on the phrasebook's second card.
Map<String, String> _course({String proposed = ''}) => <String, String>{
  'decks/bn/$_bnDeck.yaml':
      '''
schema: 1
id: $_bnDeck
name: "Bengali phrasebook"
language: { code: bn, iso639_3: ben, name: Bengali, script: bengali }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [unreviewed]
cards:
  - { id: bn-9001, target: "ধন্যবাদ", native: "thank you", reading: "dhonnobad" }
  - { id: bn-9002, target: "আপনি কেমন আছেন?", native: "How are you?", reading: "āpni kemon āchen?"$proposed }
''',
  'decks/hi/$_hiDeck.yaml':
      '''
schema: 1
id: $_hiDeck
name: "Slang"
language: { code: hi, iso639_3: hin, name: Hindustani, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [unreviewed]
cards:
  - { id: hi-9001, target: "यार", native: "friend", reading: "yaar" }
  - { id: hi-9002, target: "बकवास", native: "nonsense", reading: "bakvās" }
''',
  'decks/bn/bn-path.yaml': '''
schema: 1
kind: path
id: bn-path
language: bn
units:
  - [bn-phrasebook]
''',
  'decks/hi/hi-path.yaml': '''
schema: 1
kind: path
id: hi-path
language: hi
units:
  - [hi-slang]
''',
};

/// A proposal on the phrasebook's second card that matches the suggestion
/// [_review] makes there: the deck shows it to other reviewers.
const String _proposal =
    ', proposed: [{ id: "aaaaaaaaaa", field: "native", now: "How are you?", '
    'text: "How are you doing?", by: "$reviewerCode", date: "2026-10-09" }]';

Future<AppState> _state({FixedMailShare? share, String proposed = ''}) async {
  final state = AppState.test(
    decks: MemoryDeckSource(_course(proposed: proposed)),
    mailShare: share ?? FixedMailShare(),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['bn', 'hi'],
      learningChosen: true,
    )..raterCode = reviewerCode,
  );
  await state.load();
  state.reviewing.turnOn();
  addTearDown(state.dispose);
  return state;
}

ReviewQuestion _question(String language, String card, String word) =>
    ReviewQuestion(
      language: language,
      card: card,
      kind: QuestionKind.meaning,
      point: 'meaning',
      word: word,
      weakness: 0,
    );

/// What the reviewer did: facet answers and a suggestion in the Bengali
/// deck, a mark and a rating in the Hindustani one, and three answers to
/// the daily questions, two Bengali and one Hindustani.
void _review(AppState state) {
  final r = state.reviewing;
  final bn = state.reviewDeckById(_bnDeck)!;
  final hi = state.reviewDeckById(_hiDeck)!;
  r.answerFacet(bn, bn.cards[0], Facet.reading, const FacetAnswer.right());
  r.answerFacet(
    bn,
    bn.cards[0],
    Facet.ipa,
    FacetAnswer.flagged(<PointerTag>{
      PointerTag.ipaWrong,
    }, replacement: 'final d is released'),
  );
  r.suggest(bn, bn.cards[1], const <Suggestion>[
    Suggestion(
      part: CardPart.meaning,
      now: 'How are you?',
      text: 'How are you doing?',
      why: 'It asks about state.',
    ),
  ]);
  r.markRight(hi, hi.cards[0]);
  r.rate(hi, hi.cards[1], const WordRating(score: 4));
  r.answerQuestion(
    _question('bn', 'bn-9001', 'ধন্যবাদ'),
    QuestionAnswer.no,
    reason: 'awkward',
    why: 'The everyday word.',
  );
  r.answerQuestion(
    _question('bn', 'bn-9002', 'আপনি কেমন আছেন?'),
    QuestionAnswer.yes,
  );
  r.answerQuestion(
    _question('hi', 'hi-9001', 'यार'),
    QuestionAnswer.yes,
  );
}

/// A phone tall enough for every group to be built, at the app's 1.4x text.
void _phone(WidgetTester tester) {
  usePhone(tester, textScale: 1.4);
  tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
}

/// The Send button: a [FilledButton.icon] is a subclass, which byType misses.
Finder _send() => find.byWidgetPredicate((w) => w is FilledButton);

Finder _tick(String key) => find.descendant(
  of: find.byKey(ValueKey<String>(key)),
  matching: find.byType(Checkbox),
);

void main() {
  group('Reviews to send', () {
    testWidgets('nothing to send and no mail opened: one short message', (
      tester,
    ) async {
      _phone(tester);
      final state = await _state();
      await pumpScreen(tester, const ReviewsToSendPage(), state: state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewToSendNothing), findsOneWidget);
      expect(_send(), findsNothing);
      expect(find.text(l10n.reviewToSendSent), findsNothing);
    });

    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('a group per deck and per language of answers, one Send '
          'counting what is ticked, and a deck opens to every item '
          '(${mode.name}, 1.4x)', (tester) async {
        _phone(tester);
        final state = await _state();
        _review(state);
        await pumpScreen(
          tester,
          const ReviewsToSendPage(),
          state: state,
          themeMode: mode,
        );
        final l10n = l10nOf(tester);
        expect(find.text('Bengali phrasebook'), findsOneWidget);
        expect(find.text('Slang'), findsOneWidget);
        expect(find.text(l10n.reviewQuestionsTitle), findsNWidgets(2));
        expect(find.text(l10n.reviewToSendBoth(2, 3)), findsOneWidget);
        // Unticking a deck, then a language of answers, changes the count.
        await tester.tap(_tick('deck-$_hiDeck'));
        await tester.pumpAndSettle();
        expect(find.text(l10n.reviewToSendBoth(1, 3)), findsOneWidget);
        await tester.tap(_tick('answers-hi'));
        await tester.pumpAndSettle();
        expect(find.text(l10n.reviewToSendBoth(1, 2)), findsOneWidget);
        await tester.tap(_tick('answers-bn'));
        await tester.pumpAndSettle();
        expect(find.text(l10n.reviewSendButton(1)), findsOneWidget);
        await tester.tap(_tick('deck-$_bnDeck'));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(_send()).onPressed, isNull);
        await tester.tap(_tick('deck-$_bnDeck'));
        await tester.pumpAndSettle();

        // The Bengali deck opens to every item it will send.
        await tester.tap(find.text('Bengali phrasebook'));
        await tester.pumpAndSettle();
        expect(find.text('ধন্যবাদ'), findsOneWidget);
        expect(find.text('আপনি কেমন আছেন?'), findsOneWidget);
        expect(find.textContaining(l10n.reviewTagIpaWrong), findsOneWidget);
        expect(find.textContaining('final d is released'), findsOneWidget);
        expect(find.textContaining('How are you doing?'), findsOneWidget);
        expect(find.textContaining('It asks about state.'), findsOneWidget);
        // The Hindustani deck: a mark and a rating.
        await tester.tap(find.text('Slang'));
        await tester.pumpAndSettle();
        expect(find.text('यार'), findsOneWidget);
        expect(find.text('बकवास'), findsOneWidget);
        expect(find.textContaining(l10n.reviewRated(4)), findsOneWidget);
        // The daily answers of Bengali: Answer, Reason and Why.
        await tester.tap(find.text(l10n.reviewQuestionsTitle).first);
        await tester.pumpAndSettle();
        expect(find.textContaining('The everyday word.'), findsOneWidget);
        expect(
          find.textContaining(l10n.reviewReasonAwkward),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Send sends only what is ticked in one mail, and the mail is '
        'listed under Sent; Send again puts it back and sends nothing', (
      tester,
    ) async {
      _phone(tester);
      final share = FixedMailShare();
      final state = await _state(share: share);
      _review(state);
      await pumpScreen(tester, const ReviewsToSendPage(), state: state);
      final l10n = l10nOf(tester);
      await tester.tap(_tick('deck-$_hiDeck'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reviewToSendBoth(1, 3)));
      await tester.pumpAndSettle();

      expect(share.shared, hasLength(1));
      expect(
        share.shared.single.files.map((f) => f.name),
        unorderedEquals(<String>[
          ReviewFile.name(_bnDeck),
          'fluenough-questions-bn.json',
          'fluenough-questions-hi.json',
        ]),
      );
      expect(state.reviewing.unsent.map((d) => d.deckId), <String>[_hiDeck]);
      expect(state.reviewing.unsentAnswers, isEmpty);
      expect(find.text(l10n.reviewSendOpened), findsOneWidget);
      // The mail is under Sent, by date, with its decks and answers.
      expect(find.text(l10n.reviewToSendSent), findsOneWidget);
      expect(
        find.text('Bengali phrasebook, ${l10n.reviewToSendAnswers(3)}'),
        findsOneWidget,
      );
      // The Hindustani deck, left unticked, still waits.
      expect(find.text('Slang'), findsOneWidget);
      // The deck does not show the changes yet: Send again is offered.
      await tester.tap(find.text(l10n.reviewToSendAgain));
      await tester.pumpAndSettle();
      expect(share.shared, hasLength(1));
      expect(state.reviewing.unsent.map((d) => d.deckId), <String>[
        _bnDeck,
        _hiDeck,
      ]);
      expect(state.reviewing.unsentAnswers, hasLength(3));
      expect(state.reviewing.sentMails, isEmpty);
      expect(find.text(l10n.reviewToSendSent), findsNothing);
      expect(find.text(l10n.reviewToSendBoth(1, 3)), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('no Send again once the deck shows the change of a mail as a '
        'proposal other reviewers see', (tester) async {
      _phone(tester);
      final share = FixedMailShare();
      final state = await _state(share: share, proposed: _proposal);
      _review(state);
      await pumpScreen(tester, const ReviewsToSendPage(), state: state);
      final l10n = l10nOf(tester);
      await tester.tap(_tick('deck-$_hiDeck'));
      await tester.pumpAndSettle();
      await tester.tap(_tick('answers-hi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reviewToSendBoth(1, 2)));
      await tester.pumpAndSettle();
      expect(share.shared, hasLength(1));
      expect(find.text(l10n.reviewToSendSent), findsOneWidget);
      expect(find.text(l10n.reviewToSendAgain), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a card dropped from the mail is not sent and stays waiting', (
      tester,
    ) async {
      _phone(tester);
      final share = FixedMailShare();
      final state = await _state(share: share);
      _review(state);
      await pumpScreen(tester, const ReviewsToSendPage(), state: state);
      final l10n = l10nOf(tester);
      await tester.tap(find.text('Bengali phrasebook'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('আপনি কেমন আছেন?'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.reviewToSendChange), findsOneWidget);
      await tester.tap(find.text(l10n.reviewToSendDrop));
      await tester.pumpAndSettle();
      expect(find.text('আপনি কেমন আছেন?'), findsNothing);
      expect(find.text(l10n.reviewToSendDropped), findsOneWidget);
      await tester.tap(find.text(l10n.reviewToSendBoth(2, 3)));
      await tester.pumpAndSettle();

      final file = share.shared.single.files.firstWhere(
        (f) => f.name == ReviewFile.name(_bnDeck),
      );
      final cards = (jsonDecode(file.text) as Map<String, Object?>)['cards']!;
      expect((cards as List).map((c) => (c as Map)['card']), <Object?>[
        'bn-9001',
      ]);
      expect(state.reviewing.reviews.of(_bnDeck)!.unsentCards.keys, <String>[
        'bn-9002',
      ]);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });
}
