// Reviewing: a reviewer's code; Looks right and Suggest a change, never
// both; sign off and Send review in one mail, marked sent only when it goes,
// and taken back once; base changes; proposals accepted, rejected, edited;
// what waits per language; offensive words asked for every time, never in a
// unit, regions from the path; the look-alike warning only after the
// answer; the app's agreement count matches the review bot's.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/app/reviewing.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/proposal.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/rater_code.dart';
import 'package:fluenough/core/review/review_file.dart';
import 'package:fluenough/core/review/review_pairs.dart';
import 'package:fluenough/core/review/sent_state.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/review/alike_warning.dart';
import 'package:fluenough/features/review/offensive_review_page.dart';
import 'package:fluenough/features/review/proposal_card.dart';
import 'package:fluenough/features/review/review_page.dart';
import 'package:fluenough/features/review/review_sheets.dart';
import 'package:fluenough/features/review/review_waiting.dart';
import 'package:fluenough/features/review/reviewed_not_sent_page.dart';
import 'package:fluenough/features/review/send_reviews_sheet.dart';
import 'package:fluenough/features/review/suggest_bases.dart';
import 'package:fluenough/features/settings/reviewing_page.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/review_fixture.dart';

// From rater_code_test.dart.
/// A code whose symbols include a match of [pattern].
RaterCode _codeWith(RegExp pattern) {
  final random = Random(9);
  while (true) {
    final code = RaterCode.generate(random);
    if (pattern.hasMatch(code.symbols)) return code;
  }
}

// From review_page_test.dart.
/// A phone tall enough for every card and sheet to be built.
void useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
}

Finder rowButton(String label) => find.widgetWithText(FilledButton, label);

// From suggest_sheet_test.dart.
/// "Suggest a change" (#468): a card a part, each edited in its own field
/// with its own why; the tick saves every part edited, the cross none.

/// A phone tall enough for every part of the sheet to be built.
void useTallPhoneSuggestSheet(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
}

/// Opens Suggest a change on the plain word, అమ్మ (amma), mother.
Future<AppState> openSheet(
  WidgetTester tester, {
  List<Suggestion> saved = const <Suggestion>[],
}) async {
  useTallPhoneSuggestSheet(tester);
  final state = await reviewState(reviewing: true);
  final words = state.deckById(wordsDeck)!;
  if (saved.isNotEmpty) {
    state.reviewing.suggest(words, words.cards.last, saved);
  }
  await pumpScreen(tester, const ReviewPage(deckId: wordsDeck), state: state);
  final l10n = l10nOf(tester);
  await tester.tap(find.text('mother'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, l10n.reviewSuggest));
  await tester.pumpAndSettle();
  expect(find.byType(SuggestSheet), findsOneWidget);
  return state;
}

Future<void> pencil(WidgetTester tester, String part) async {
  final l10n = l10nOf(tester);
  await tester.tap(find.byTooltip(l10n.reviewSuggestEditPart(part)));
  await tester.pumpAndSettle();
}

List<Suggestion> savedOn(AppState state) {
  final words = state.deckById(wordsDeck)!;
  return state.reviewing.reviewOf(words, words.cards.last)?.suggestions ??
      const <Suggestion>[];
}

// From base_change_test.dart.
/// Suggest a change on base words and a new word for the card (#476,
/// docs/mockups/reviewer-mode.html, section 2): a base removed with Undo
/// before the tick, a base added for a word of the card and linked to the
/// card its form is, and a new word with the panel of what hung on the old
/// one. At 1x and the app's 1.4x cap, light and dark.

/// The plain word అమ్మ (amma), mother, with its own base written in full.
const String bases =
    '[{ word: "అమ్మ", base: "అమ్మ", reading: "amma", meaning: "mum" }]';

/// Opens Suggest a change on the plain word, with [bases], [saved] kept
/// on it, at [textScale] in [themeMode].
Future<AppState> openSheetBaseChange(
  WidgetTester tester, {
  String? bases = bases,
  List<Suggestion> saved = const <Suggestion>[],
  double textScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  usePhone(tester, textScale: textScale);
  tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
  final state = await reviewState(reviewing: true, bases: bases);
  final words = state.deckById(wordsDeck)!;
  final mother = words.cards.firstWhere((c) => c.id == plainCard);
  if (saved.isNotEmpty) state.reviewing.suggest(words, mother, saved);
  await pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSuggestSheet(context, deck: words, card: mother),
          child: const Text('open'),
        ),
      ),
    ),
    state: state,
    themeMode: themeMode,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return state;
}

List<Suggestion> savedOnBaseChange(AppState state) {
  final words = state.deckById(wordsDeck)!;
  final mother = words.cards.firstWhere((c) => c.id == plainCard);
  return state.reviewing.reviewOf(words, mother)?.suggestions ??
      const <Suggestion>[];
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, Key key, String text) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.enterText(find.byKey(key), text);
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) =>
    tap(tester, find.byTooltip(l10nOf(tester).reviewSuggestSaveAll));

bool ticked(WidgetTester tester, Key row) => tester
    .widget<Checkbox>(
      find.descendant(of: find.byKey(row), matching: find.byType(Checkbox)),
    )
    .value!;

/// Suggests the new word మా అమ్మ (mā amma), "our mother", on the card.
Future<void> newWord(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  await tap(
    tester,
    find.byTooltip(l10n.reviewSuggestEditPart(l10n.reviewPartWord)),
  );
  await type(tester, SuggestSheet.textKey(CardPart.word), 'మా అమ్మ');
  await type(tester, SuggestSheet.whyKey(CardPart.word), 'As said');
}

// From proposal_card_test.dart.
/// Two proposals on the plain word's meaning, "mother": one by another
/// reviewer, one by this one; and one whose field has changed since.
const proposed =
    '[{ id: "aaaaaaaaaa", field: "native", now: "mother", text: "mum", '
    'by: "$otherCode", date: "2026-10-09", why: "Less formal." }, '
    '{ id: "bbbbbbbbbb", field: "native", now: "mother", text: "mom", '
    'by: "$reviewerCode", date: "2026-10-09", accepted: ["$otherCode"] }, '
    '{ id: "cccccccccc", field: "native", now: "mum", text: "mama", '
    'by: "$otherCode", date: "2026-10-09" }]';

Future<dynamic> open(WidgetTester tester) async {
  useTallPhone(tester);
  final state = await pumpScreen(
    tester,
    const ReviewPage(deckId: wordsDeck),
    state: await reviewState(
      proposed: proposed,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['te'],
        learningChosen: true,
      )..raterCode = reviewerCode,
      reviewing: true,
    ),
  );
  return state;
}

// From review_settings_test.dart.
/// A phone tall enough for Settings' lazy list to build every group.
void useTallPhoneReviewSettings(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
}

// From review_pairs_test.dart.
/// Who can review a course, a language taught from another (#462): one who
/// knows both languages and reads both scripts.

// From waiting_test.dart.
/// What is waiting for review, in the reviewer's languages
/// (docs/plans/deck-browser.md): the languages they review, what waits in
/// each, the page in Settings and the path's "To review" marks.

/// A reviewer who knows [spoken] and reads each one's script, with
/// reviewing on: by default, Telugu from English is theirs to review.
Future<AppState> reviewer({
  List<String> spoken = const <String>['en', 'te'],
  Set<String>? languages,
  bool more = false,
}) async {
  final state = await reviewState(
    reviewing: true,
    more: more,
    share: FixedMailShare(),
    settings:
        SettingsNotifier(
            spokenLanguages: spoken,
            learningLanguages: const <String>['te'],
            learningChosen: true,
          )
          ..reviewLanguages = languages
          ..scriptsRead = <String, bool>{for (final code in spoken) code: true},
  );
  return state;
}

// From waiting_reviews_test.dart.
/// Waiting for review's three parts (#471, docs/mockups/reviewer-mode.html,
/// section 1): "Your reviews" with Reviewed, not sent and Reviewed and sent,
/// then the languages, folded.

/// The plain word's meaning, "mother", proposed as "mum" by this reviewer,
/// with no acceptance yet.
const String proposedWaitingReviews =
    '[{ id: "aaaaaaaaaa", field: "native", now: "mother", text: "mum", '
    'by: "$reviewerCode", date: "2026-10-09" }]';

Future<AppState> reviewerState() => reviewState(
  proposed: proposedWaitingReviews,
  reviewing: true,
  share: FixedMailShare(),
  settings:
      SettingsNotifier(
          spokenLanguages: const <String>['en', 'te'],
          learningLanguages: const <String>['te'],
          learningChosen: true,
        )
        ..raterCode = reviewerCode
        ..reviewLanguages = const <String>{'te'}
        ..scriptsRead = const <String, bool>{'en': true, 'te': true},
);

/// Suggestions on the plain word, one in each state, and a picture, and
/// "Looks right" on the word like a rude one.
Future<void> reviewAndSend(AppState state, {bool send = true}) async {
  final words = state.deckById(wordsDeck)!;
  final plain = words.cards.last;
  state.reviewing.suggest(words, plain, const <Suggestion>[
    // Still a proposal in the deck, with nothing accepted: waiting.
    Suggestion(
      part: CardPart.meaning,
      now: 'mother',
      text: 'mum',
      why: 'Less formal.',
    ),
    // The field says it now, and no proposal: accepted.
    Suggestion(part: CardPart.reading, now: 'ammaa', text: 'amma'),
    // The field says something else, and no proposal: rejected.
    Suggestion(part: CardPart.ipa, now: 'old', text: 'new'),
    // The field is as it was: the deck has not got it yet.
    Suggestion(
      part: CardPart.notes,
      now: 'Also అమ్మా (ammā) when calling her.',
      text: 'Said to elders.',
    ),
    // A part the bot does not turn into proposals.
    Suggestion(part: CardPart.picture, now: '', text: 'A mother.'),
  ]);
  state.reviewing.markRight(words, words.cards.first);
  if (send) {
    await state.reviewing.send(state.reviewing.unsent, body: '');
  }
}

// From offensive_review_test.dart.
/// A language's Offensive words review (docs/plans/deck-browser.md,
/// "Offensive words are reviewed apart, and only on purpose"; #428): why
/// the words are there, then the 18+ question, then the words, each rated
/// 1 to 9 with the region the rater speaks in.

/// A phone tall enough for every row and sheet to be built.
void useTallPhoneOffensiveReview(
  WidgetTester tester, {
  double textScale = 1.0,
}) {
  usePhone(tester, textScale: textScale);
  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
}

/// The words of the Telugu fixture that must not show before the reviewer
/// has read why and said they are 18 or over.
const List<String> rudeWords = <String>[
  'వెధవ',
  'vedhava',
  'idiot, good-for-nothing',
];

void expectNoWord() {
  for (final word in rudeWords) {
    expect(find.textContaining(word), findsNothing, reason: word);
  }
}

/// Pumps Telugu's Offensive words review on [state].
Future<AppState> pumpOffensive(
  WidgetTester tester, {
  AppState? state,
  ThemeMode themeMode = ThemeMode.light,
}) async => pumpScreen(
  tester,
  const OffensiveReviewPage(language: 'te'),
  state: state ?? await reviewState(reviewing: true),
  themeMode: themeMode,
);

/// Goes past why the words are there and the age question, to the words.
Future<void> passGate(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  await tester.ensureVisible(find.text(l10n.commonContinue));
  await tester.tap(find.text(l10n.commonContinue));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(l10n.settingsAdultConfirm));
  await tester.tap(find.text(l10n.settingsAdultConfirm));
  await tester.pumpAndSettle();
}

// From alike_warning_test.dart.
/// The sound-alike warning on the drill card (docs/plans/offensive-words.md):
/// only once the word is shown or answered, never before, and never naming
/// the rude word without adult content.

// From how_reviewing_works_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the reviewer\'s code', () {
    test('a code reads loosely, and its check catches a wrong symbol or two '
        'neighbours swapped', () {
      final code = RaterCode.tryParse('${RaterCode.generate(Random(3))}')!;
      final plain = code.symbols;
      expect(RaterCode.tryParse(plain), code);
      expect(RaterCode.tryParse('fl-${plain.toLowerCase()}'), code);
      expect(
        RaterCode.tryParse(
          ' FL ${plain.substring(0, 4)} '
          '${plain.substring(4)} ',
        ),
        code,
      );
      // A code with a 1 and a 0 in it, typed with I and O.
      final withDigits = _codeWith(RegExp('[10]'));
      final typed = withDigits.symbols
          .replaceAll('1', 'I')
          .replaceAll('0', 'O');
      expect(RaterCode.tryParse(typed), withDigits);

      {
        final code = RaterCode.generate(Random(11));
        final plain = code.symbols;
        for (var at = 0; at < plain.length; at++) {
          for (final symbol in RaterCode.alphabet.split('')) {
            if (symbol == plain[at]) continue;
            final typo = plain.replaceRange(at, at + 1, symbol);
            expect(RaterCode.tryParse(typo), isNull, reason: typo);
          }
        }
      }

      {
        final random = Random(5);
        for (var i = 0; i < 300; i++) {
          final plain = RaterCode.generate(random).symbols;
          for (var at = 0; at < plain.length - 1; at++) {
            if (plain[at] == plain[at + 1]) continue;
            final swapped =
                '${plain.substring(0, at)}${plain[at + 1]}${plain[at]}'
                '${plain.substring(at + 2)}';
            expect(RaterCode.tryParse(swapped), isNull, reason: swapped);
          }
        }
      }
    });
  });

  group('reviewing', () {
    test(
      'turning on makes a code once, and reviews outlive a restart',
      () async {
        final state = await reviewState();
        addTearDown(state.dispose);
        final reviewing = state.reviewing;
        expect(reviewing.on, isFalse);
        expect(reviewing.code, isNull);

        expect(reviewing.turnOn(), isTrue);
        final code = reviewing.code!;
        expect(RaterCode.tryParse('$code'), code);
        expect(reviewing.on, isTrue);

        reviewing.turnOff();
        expect(reviewing.on, isFalse);
        expect(reviewing.code, code, reason: 'turning off keeps the code');

        expect(reviewing.turnOn(), isFalse);
        expect(reviewing.code, code);

        {
          final state = await reviewState(reviewing: true);
          addTearDown(state.dispose);
          final words = state.deckById(wordsDeck)!;
          final card = words.cards.first;
          state.reviewing.markRight(words, card);
          state.reviewing.suggest(words, words.cards.last, const <Suggestion>[
            Suggestion(part: CardPart.meaning, now: 'mother', text: 'mum'),
          ]);

          final restored = SettingsNotifier()
            ..restore(state.settings.toStored());
          expect(restored.reviewDecks, isTrue);
          expect(restored.raterCode, '${state.reviewing.code}');
          expect(restored.reviewIntroShown, isTrue);
          expect(restored.reviews.toJson(), state.settings.reviews.toJson());
          expect(restored.reviews.card(wordsDeck, card.id)!.right, isTrue);
        }
      },
    );

    test('several decks go in one mail, and are marked sent only when a mail '
        'app takes it', () async {
      final share = FixedMailShare();
      final state = await reviewState(share: share, reviewing: true);
      addTearDown(state.dispose);
      final reviewing = state.reviewing;
      final words = state.deckById(wordsDeck)!;
      final rude = state.deckById(rudeDeck)!;
      for (final card in words.cards) {
        reviewing.markRight(words, card);
      }
      reviewing.rate(
        rude,
        rude.cards.single,
        const WordRating(score: 4, region: 'coastal-andhra'),
      );
      reviewing.signOff(words);
      expect(reviewing.unsent.map((d) => d.deckId), <String>[
        wordsDeck,
        rudeDeck,
      ]);

      final outcome = await reviewing.send(reviewing.unsent, body: 'For you');
      expect(outcome, ReviewSendOutcome.inMailApp);
      final mail = share.shared.single;
      expect(mail.to, <String>[AppLinks.feedbackEmail]);
      expect(mail.subject, '[Fluenough review] ${reviewing.code} (te)');
      expect(mail.body, 'For you');
      expect(mail.files.map((f) => f.name), <String>[
        'fluenough-review-$wordsDeck.json',
        'fluenough-review-$rudeDeck.json',
      ]);
      final file = jsonDecode(mail.files.first.text) as Map<String, Object?>;
      expect(file['rater_code'], '${reviewing.code}');
      expect(file['language'], 'te');
      expect(file['deck'], wordsDeck);
      expect(file['app_version'], AppInfo.version);
      expect(file['made'], state.now().toUtc().toIso8601String());
      expect(file['signed_off'], isTrue);
      expect((file['cards']! as List).length, 2);

      expect(reviewing.unsent, isEmpty);
      // What was done still shows.
      expect(reviewing.reviews.of(wordsDeck)!.markedCount, 2);

      {
        final share = FixedMailShare(shares: false);
        final state = await reviewState(share: share, reviewing: true);
        addTearDown(state.dispose);
        final reviewing = state.reviewing;
        final words = state.deckById(wordsDeck)!;
        reviewing.markRight(words, words.cards.first);
        expect(
          await reviewing.send(reviewing.unsent, body: ''),
          ReviewSendOutcome.noMailApp,
        );
        expect(reviewing.unsent, hasLength(1));
        share.error = Exception('no channel');
        expect(
          await reviewing.send(reviewing.unsent, body: ''),
          ReviewSendOutcome.failed,
        );
        expect(reviewing.unsent, hasLength(1));
        expect(
          await reviewing.send(const <DeckReview>[], body: ''),
          ReviewSendOutcome.nothingToSend,
        );
      }
    });
  });

  group('a deck\'s review', () {
    final monday = DateTime.utc(2026, 10, 12, 9);

    Reviews marked() => const Reviews()
        .withCard(
          'te-family',
          'te',
          'te-0001',
          monday,
          (_) => CardReview(at: monday, right: true),
        )
        .withCard(
          'te-family',
          'te',
          'te-0384',
          monday,
          (_) => CardReview(
            at: monday,
            suggestions: const <Suggestion>[
              Suggestion(
                part: CardPart.notes,
                now: 'Formally కుమార్తె (kumārte).',
                text: 'In speech also అమ్మాయి (ammāyi).',
                why: 'As common',
              ),
            ],
          ),
        );

    test('a card is marked right or suggested, never both, and a change after '
        'a sign-off takes the sign-off back', () {
      final reviews = marked();
      expect(reviews.card('te-family', 'te-0001')!.marked, isTrue);
      expect(reviews.card('te-family', 'te-0384')!.suggestions, isNotEmpty);
      expect(reviews.of('te-family')!.markedCount, 2);
      // Read back, a stored card with both keeps the suggestion.
      final both = CardReview.fromJson(<String, Object?>{
        'at': monday.toIso8601String(),
        'looks_right': true,
        'suggestion': <String, Object?>{
          'part': 'word',
          'now': 'a',
          'text': 'b',
        },
      })!;
      expect(both.right, isFalse);
      expect(both.suggestions.single.text, 'b');

      {
        var reviews = marked().signOff('te-family', 'te', monday);
        expect(reviews.of('te-family')!.signedOff, monday);
        reviews = reviews.withCard(
          'te-family',
          'te',
          'te-0001',
          monday,
          (old) => CardReview(at: monday, right: true),
        );
        expect(reviews.of('te-family')!.signedOff, isNull);
      }
    });

    test('the last send can be taken back once, for a mail that never went: '
        'its decks wait again, as they did before it', () {
      final later = monday.add(const Duration(hours: 1));
      final latest = monday.add(const Duration(hours: 2));
      expect(marked().lastSend, isEmpty);
      // A first mail, then a second with the family deck again and another.
      var reviews = marked().sentAt(<String>['te-family'], monday);
      reviews = reviews
          .withCard(
            'te-family',
            'te',
            'te-0002',
            later,
            (_) => CardReview(at: later, right: true),
          )
          .withCard(
            'te-rude',
            'te',
            'te-0900',
            later,
            (_) => CardReview(at: later, rating: const WordRating(score: 3)),
          )
          .sentAt(<String>['te-family', 'te-rude'], latest);
      expect(reviews.unsent, isEmpty);
      expect(reviews.lastSend.map((d) => d.deckId), <String>[
        'te-family',
        'te-rude',
      ]);
      // Stored and read back, it can still be taken back.
      reviews = Reviews.fromJson(reviews.toJson())!;
      expect(reviews.lastSend, hasLength(2));

      reviews = reviews.unsend(reviews.lastSend.map((d) => d.deckId));
      // What the second mail carried waits again; the first mail's stays sent.
      expect(reviews.of('te-family')!.sent, monday);
      expect(reviews.of('te-rude')!.sent, isNull);
      expect(reviews.unsent.map((d) => d.deckId), <String>[
        'te-family',
        'te-rude',
      ]);
      expect(reviews.of('te-family')!.unsentCards.keys, <String>['te-0002']);
      // Once only: nothing more can be taken back, and taking the second
      // mail back again changes nothing.
      expect(reviews.lastSend, isEmpty);
      final again = reviews.unsend(<String>['te-family', 'te-rude']);
      expect(again.toJson(), reviews.toJson());
    });
  });

  group('the review page', () {
    testWidgets(
      'Check marks a card; a card opens whole, and Suggest a change keeps '
      'a suggestion',
      (tester) async {
        useTallPhone(tester);
        final state = await pumpScreen(
          tester,
          const ReviewPage(deckId: wordsDeck),
          state: await reviewState(reviewing: true),
        );
        final l10n = l10nOf(tester);
        expect(find.text(l10n.reviewPageTitle('Family words')), findsOneWidget);
        expect(find.text('${state.reviewing.code}'), findsOneWidget);
        expect(find.text(l10n.reviewPageProgress(0, 2)), findsOneWidget);
        expect(find.text(l10n.reviewPageInfo), findsOneWidget);
        expect(rowButton(l10n.reviewCheck), findsNWidgets(2));

        await tester.tap(rowButton(l10n.reviewCheck).last);
        await tester.pumpAndSettle();
        expect(find.text(l10n.reviewPageProgress(1, 2)), findsOneWidget);
        expect(rowButton(l10n.reviewRight), findsOneWidget);
        expect(find.text(l10n.reviewSectionTally(1, 0)), findsOneWidget);
        // Waiting to send, said at the foot.
        expect(find.text(l10n.reviewDecksWaiting(1)), findsOneWidget);

        await tester.tap(rowButton(l10n.reviewRight));
        await tester.pumpAndSettle();
        expect(find.text(l10n.reviewPageProgress(0, 2)), findsOneWidget);

        {
          useTallPhone(tester);
          final state = await pumpScreen(
            tester,
            const ReviewPage(deckId: wordsDeck),
            state: await reviewState(reviewing: true),
          );
          final l10n = l10nOf(tester);
          await tester.tap(find.text('mother'));
          await tester.pumpAndSettle();
          expect(find.byType(ReviewCardSheet), findsOneWidget);
          expect(
            find.text(l10n.reviewCardLine(plainCard, l10n.reviewStateNot)),
            findsOneWidget,
          );
          expect(
            find.text('Also అమ్మా (ammā) when calling her.'),
            findsOneWidget,
          );
          await tester.tap(find.text(l10n.reviewLooksRight));
          await tester.pumpAndSettle();
          final words = state.deckById(wordsDeck)!;
          final mother = words.cards.last;
          expect(state.reviewing.reviewOf(words, mother)!.right, isTrue);

          await tester.tap(find.text('mother'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.widgetWithText(OutlinedButton, l10n.reviewSuggest),
          );
          await tester.pumpAndSettle();
          expect(find.byType(SuggestSheet), findsOneWidget);
          for (final part in CardPart.values) {
            // A base word has a card a base; this card has none. Also heard
            // shows once a new word is suggested (#476).
            expect(
              find.byTooltip(l10n.reviewSuggestEditPart(partName(l10n, part))),
              part == CardPart.base || part == CardPart.alt
                  ? findsNothing
                  : findsOneWidget,
            );
          }
          // No field until a pencil is tapped, and Save waits for a change.
          expect(find.byType(TextField), findsNothing);
          final save = find.byTooltip(l10n.reviewSuggestSaveAll);
          IconButton saveButton() => tester.widget<IconButton>(
            find.ancestor(of: save, matching: find.byType(IconButton)),
          );
          expect(saveButton().onPressed, isNull);
          await tester.tap(
            find.byTooltip(l10n.reviewSuggestEditPart(l10n.reviewPartNotes)),
          );
          await tester.pumpAndSettle();
          expect(find.text(l10n.reviewSuggestNow), findsOneWidget);
          expect(find.byType(TextField), findsNWidgets(2));
          await tester.enterText(
            find.byKey(SuggestSheet.textKey(CardPart.notes)),
            'Also అమ్మా (ammā), and మా అమ్మ (mā amma), our mother.',
          );
          await tester.enterText(
            find.byKey(SuggestSheet.whyKey(CardPart.notes)),
            'Common in speech',
          );
          await tester.pumpAndSettle();
          await tester.tap(save);
          await tester.pumpAndSettle();
          final suggestion = state.reviewing
              .reviewOf(words, mother)!
              .suggestions
              .single;
          expect(suggestion.part, CardPart.notes);
          expect(suggestion.now, 'Also అమ్మా (ammā) when calling her.');
          expect(suggestion.why, 'Common in speech');
          expect(state.reviewing.reviewOf(words, mother)!.right, isFalse);
          expect(rowButton(l10n.reviewSuggested), findsOneWidget);
        }
      },
    );

    testWidgets('offensive words never appear in a unit\'s review, adult '
        'content on or off, nor count as left to check', (tester) async {
      useTallPhone(tester);
      for (final adult in <bool>[false, true]) {
        await pumpScreen(
          tester,
          const ReviewPage(deckId: rudeDeck),
          state: await reviewState(reviewing: true)
            ..settings.adultContent = adult,
        );
        final l10n = l10nOf(tester);
        expect(find.text(l10n.reviewOffensiveApart(1)), findsOneWidget);
        expect(find.text('idiot, good-for-nothing'), findsNothing);
        expect(find.text('వెధవ'), findsNothing);
        expect(rowButton(l10n.reviewRateShort), findsNothing);
        expect(find.text(l10n.reviewPageProgress(0, 0)), findsOneWidget);
        // A deck of offensive words only is signed off in their own review.
        expect(find.textContaining(l10n.reviewSignOffReady), findsNothing);
        expect(find.text(l10n.reviewSignedOff), findsNothing);
        expect(find.text(l10n.reviewSend), findsOneWidget);
      }
    });

    testWidgets('Sign off once every card is checked; Send review sends every '
        'deck waiting in one mail, a file each, all ticked', (tester) async {
      useTallPhone(tester);
      final share = FixedMailShare();
      final state = await reviewState(share: share, reviewing: true);
      final rude = state.deckById(rudeDeck)!;
      state.reviewing.rate(rude, rude.cards.single, const WordRating(score: 7));
      await pumpScreen(
        tester,
        const ReviewPage(deckId: wordsDeck),
        state: state,
      );
      final l10n = l10nOf(tester);
      final signOff = find.widgetWithText(
        OutlinedButton,
        l10n.reviewSignOff(2),
      );
      expect(tester.widget<OutlinedButton>(signOff).onPressed, isNull);
      for (var i = 0; i < 2; i++) {
        await tester.tap(rowButton(l10n.reviewCheck).first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(l10n.reviewSignOffReady));
      await tester.pumpAndSettle();
      expect(find.text(l10n.reviewSignedOff), findsOneWidget);
      expect(find.text(l10n.reviewDecksWaiting(2)), findsOneWidget);

      await tester.tap(find.text(l10n.reviewSend));
      await tester.pumpAndSettle();
      expect(find.byType(SendReviewsSheet), findsOneWidget);
      expect(find.text(l10n.reviewSendBody), findsOneWidget);
      expect(
        find.text(l10n.reviewSendDeck('Family words', 'Telugu')),
        findsOneWidget,
      );
      expect(find.text(l10n.reviewSendDeckSigned(2)), findsOneWidget);
      expect(
        find.text(l10n.reviewSendDeck('Rude words', 'Telugu')),
        findsOneWidget,
      );
      expect(find.text(l10n.reviewSendButton(2)), findsOneWidget);
      // Unticking one leaves it for later.
      await tester.tap(find.text(l10n.reviewSendDeck('Rude words', 'Telugu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reviewSendButton(1)));
      await tester.pumpAndSettle();

      final mail = share.shared.single;
      expect(mail.subject, '[Fluenough review] ${state.reviewing.code} (te)');
      expect(mail.files, hasLength(1));
      expect((jsonDecode(mail.files.single.text) as Map)['deck'], wordsDeck);
      expect(mail.body, contains('${state.reviewing.code}'));
      expect(
        mail.body,
        contains(l10n.reviewMailDeckSigned('Family words', wordsDeck, 2)),
      );
      expect(find.text(l10n.reviewSendOpened), findsOneWidget);
      expect(state.reviewing.unsent.map((d) => d.deckId), <String>[rudeDeck]);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  group('Suggest a change', () {
    testWidgets('editing two parts saves both; the cross discards every edit', (
      tester,
    ) async {
      final state = await openSheet(tester);
      final l10n = l10nOf(tester);
      await pencil(tester, l10n.reviewPartMeaning);
      await pencil(tester, l10n.reviewPartIpa);
      expect(find.byType(TextField), findsNWidgets(4));
      await tester.enterText(
        find.byKey(SuggestSheet.textKey(CardPart.meaning)),
        'mother, mum',
      );
      await tester.enterText(
        find.byKey(SuggestSheet.whyKey(CardPart.meaning)),
        'Mum is common',
      );
      await tester.enterText(
        find.byKey(SuggestSheet.textKey(CardPart.ipa)),
        'amma',
      );
      await tester.enterText(
        find.byKey(SuggestSheet.whyKey(CardPart.ipa)),
        'It had none',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.reviewSuggestSaveAll));
      await tester.pumpAndSettle();
      expect(find.byType(SuggestSheet), findsNothing);

      final saved = savedOn(state);
      expect(
        <(CardPart, String, String, String)>[
          for (final s in saved) (s.part, s.now, s.text, s.why),
        ],
        <(CardPart, String, String, String)>[
          (CardPart.ipa, '', 'amma', 'It had none'),
          (CardPart.meaning, 'mother', 'mother, mum', 'Mum is common'),
        ],
      );

      {
        const meaning = Suggestion(
          part: CardPart.meaning,
          now: 'mother',
          text: 'mum',
        );
        final state = await openSheet(
          tester,
          saved: const <Suggestion>[meaning],
        );
        final l10n = l10nOf(tester);
        await tester.tap(
          find.byTooltip(l10n.reviewSuggestRemove(l10n.reviewPartMeaning)),
        );
        await pencil(tester, l10n.reviewPartWord);
        await tester.enterText(
          find.byKey(SuggestSheet.textKey(CardPart.word)),
          'అమ్మా',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(l10n.reviewSuggestDiscard));
        await tester.pumpAndSettle();
        expect(find.byType(SuggestSheet), findsNothing);
        final saved = savedOn(state);
        expect(saved.single.part, CardPart.meaning);
        expect(saved.single.text, 'mum');
      }
    });
  });

  group('bases', () {
    testWidgets(
      'a base deleted, or replaced by a new word, is saved as a suggestion',
      (tester) async {
        final state = await openSheetBaseChange(tester);
        final l10n = l10nOf(tester);
        final delete = find.byTooltip(l10n.reviewBaseRemove('అమ్మ'));
        await tap(tester, delete);
        expect(find.text(l10n.reviewBaseRemoved), findsOneWidget);
        final struck = tester.widget<RichText>(
          find
              .descendant(
                of: find.byType(SuggestSheet),
                matching: find.byWidgetPredicate(
                  (w) => w is RichText && w.text.toPlainText() == 'అమ్మ (amma)',
                ),
              )
              .first,
        );
        expect(struck.text.style!.decoration, TextDecoration.lineThrough);
        // Nothing is kept before the tick.
        expect(savedOnBaseChange(state), isEmpty);
        await tap(tester, find.text(l10n.commonUndo));
        expect(find.text(l10n.reviewBaseRemoved), findsNothing);
        expect(delete, findsOneWidget);

        await tap(tester, delete);
        await type(tester, SuggestSheet.baseKey('అమ్మ', 'why'), 'Its own root');
        await save(tester);
        final removal = savedOnBaseChange(state).single;
        expect(removal.part, CardPart.base);
        expect(removal.action, BaseAction.remove);
        expect(removal.word, 'అమ్మ');
        expect(
          removal.was,
          const BaseForm(base: 'అమ్మ', reading: 'amma', meaning: 'mum'),
        );
        expect(removal.base, isNull);
        expect(removal.why, 'Its own root');

        // Opened again, it is still marked, and Undo then the tick drops it.
        final again = await openSheetBaseChange(
          tester,
          saved: savedOnBaseChange(state),
        );
        expect(find.text(l10n.reviewBaseRemoved), findsOneWidget);
        await tap(tester, find.text(l10n.commonUndo));
        await save(tester);
        expect(savedOnBaseChange(again), isEmpty);

        {
          final state = await openSheetBaseChange(tester);
          final l10n = l10nOf(tester);
          expect(find.byType(IdentityPanel), findsNothing);
          expect(find.byType(CheckTag), findsNothing);
          await newWord(tester);

          expect(find.byType(IdentityPanel), findsOneWidget);
          expect(find.text(l10n.reviewIdentityTitle), findsOneWidget);
          expect(
            find.text(l10n.reviewIdentityKeeps(plainCard, 'mother')),
            findsOneWidget,
          );
          expect(
            find.text(
              l10n.reviewIdentityBases(
                1,
                l10n.cardBaseReadingMeaning('అమ్మ', 'amma', 'mum'),
              ),
            ),
            findsOneWidget,
          );
          expect(find.text(l10n.reviewIdentityCheckThem), findsOneWidget);
          expect(find.text(l10n.reviewIdentityNone), findsOneWidget);
          expect(find.text(l10n.reviewIdentityFollow), findsOneWidget);
          // Kept as an accepted answer, ticked at first.
          expect(ticked(tester, IdentityPanel.keepAltKey), isTrue);
          // The base and the notes are tagged Check.
          expect(find.byType(CheckTag), findsNWidgets(2));

          await tap(tester, find.byKey(IdentityPanel.replaceKey));
          expect(find.text(l10n.reviewBaseRemoved), findsOneWidget);
          expect(find.byKey(IdentityPanel.replaceKey), findsNothing);
          expect(
            tester
                .widget<FilterChip>(find.byKey(SuggestSheet.chipKey(0, 'మా')))
                .selected,
            isTrue,
          );
          await type(tester, SuggestSheet.newBaseKey(0, 'reading'), 'mā');
          await type(tester, SuggestSheet.newBaseKey(0, 'meaning'), 'our');
          await save(tester);

          final saved = savedOnBaseChange(state);
          expect(
            <CardPart>[for (final s in saved) s.part],
            <CardPart>[
              CardPart.word,
              CardPart.alt,
              CardPart.base,
              CardPart.base,
            ],
          );
          expect(saved[0].text, 'మా అమ్మ');
          expect(saved[1].now, '');
          expect(saved[1].text, 'అమ్మ');
          expect(saved[2].action, BaseAction.remove);
          expect(saved[3].action, BaseAction.add);
          expect(saved[3].word, 'మా');
          expect(
            saved[3].base,
            const BaseForm(base: 'మా', reading: 'mā', meaning: 'our'),
          );

          // One file carries all of it.
          final file = jsonDecode(
            ReviewFile.encode(
              state.reviewing.reviews.of(wordsDeck)!,
              code: RaterCode.tryParse(reviewerCode)!,
              appVersion: '0.5.0',
              made: DateTime.utc(2026, 10, 17),
            ),
          ) as Map<String, Object?>;
          final card = (file['cards']! as List<Object?>).single as Map;
          expect(
            <Object?>[
              for (final s in card['suggestions'] as List<Object?>)
                (s as Map)['part'],
            ],
            <String>['word', 'alt', 'base', 'base'],
          );

          // Opened again: Also heard shows the old word ticked, tagged Check;
          // unticked, it is no longer suggested.
          final again = await openSheetBaseChange(tester, saved: saved);
          expect(find.byType(IdentityPanel), findsNothing);
          expect(find.text(l10n.reviewPartAlt.toUpperCase()), findsOneWidget);
          expect(ticked(tester, SuggestSheet.keepAltKey), isTrue);
          await tap(tester, find.byKey(SuggestSheet.keepAltKey));
          await save(tester);
          expect(
            savedOnBaseChange(again).map((s) => s.part),
            isNot(contains(CardPart.alt)),
          );
          expect(savedOnBaseChange(again), hasLength(3));
        }
      },
    );
  });

  group('proposals', () {
    testWidgets(
      'Accept and Reject answer a proposal; Edit opens Suggest a change '
      'with it',
      (tester) async {
        final state = await open(tester);
        final l10n = l10nOf(tester);
        // The row says how many wait: not the outdated one.
        expect(find.text(l10n.reviewProposalsWaiting(2)), findsOneWidget);

        await tester.tap(find.text('mother'));
        await tester.pumpAndSettle();
        expect(find.byType(ProposalCard), findsNWidgets(2));
        expect(
          find.text(l10n.reviewProposalTitle(l10n.reviewPartMeaning)),
          findsNWidgets(2),
        );
        expect(find.text('mum'), findsOneWidget);
        expect(find.text('mama'), findsNothing);
        expect(
          find.text(l10n.reviewProposalWhy('Less formal.')),
          findsOneWidget,
        );
        expect(find.text(l10n.reviewProposalBy(otherCode, 0)), findsOneWidget);
        // This reviewer's own: no buttons, and who accepted it.
        expect(find.text(l10n.reviewProposalYours(1)), findsOneWidget);
        expect(find.text(l10n.reviewProposalAccept), findsOneWidget);

        await tester.tap(find.text(l10n.reviewProposalAccept));
        await tester.pumpAndSettle();
        final words = state.deckById(wordsDeck)!;
        final mother = words.cards.last;
        final answer = state.reviewing.reviewOf(words, mother)!.answers.values;
        expect(answer.single.id, 'aaaaaaaaaa');
        expect(answer.single.verdict, ProposalVerdict.accept);
        expect(answer.single.field, 'native');
        expect(answer.single.text, 'mum');
        expect(find.text(l10n.reviewProposalAccepted), findsOneWidget);
        expect(state.reviewing.unsent.single.deckId, wordsDeck);

        await tester.tap(find.text(l10n.reviewProposalReject));
        await tester.pumpAndSettle();
        expect(
          state.reviewing
              .reviewOf(words, mother)!
              .answers['aaaaaaaaaa']!
              .verdict,
          ProposalVerdict.reject,
        );
        expect(find.text(l10n.reviewProposalRejected), findsOneWidget);

        await tester.tap(find.text(l10n.reviewProposalReject));
        await tester.pumpAndSettle();
        expect(state.reviewing.reviewOf(words, mother), isNull);

        {
          final state = await open(tester);
          final l10n = l10nOf(tester);
          await tester.tap(find.text('mother'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.reviewProposalEdit));
          await tester.pumpAndSettle();
          expect(find.byType(SuggestSheet), findsOneWidget);
          // Only the proposal's part is open, started from its text.
          expect(find.byType(TextField), findsNWidgets(2));
          final yours = find.byKey(SuggestSheet.textKey(CardPart.meaning));
          expect(tester.widget<TextField>(yours).controller!.text, 'mum');
          await tester.enterText(yours, 'mum, mother');
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(l10n.reviewSuggestSaveAll));
          await tester.pumpAndSettle();

          final words = state.deckById(wordsDeck)!;
          final review = state.reviewing.reviewOf(words, words.cards.last)!;
          final suggestion = review.suggestions.single;
          expect(suggestion.part, CardPart.meaning);
          expect(suggestion.now, 'mother');
          expect(suggestion.text, 'mum, mother');
          expect(review.answers['aaaaaaaaaa']!.verdict, ProposalVerdict.edit);
          expect(find.text(l10n.reviewProposalEdited), findsOneWidget);
        }
      },
    );
  });

  group('review settings', () {
    testWidgets('once a mail is sent, Send the last mail again puts its decks '
        'back and opens the send sheet', (tester) async {
      useTallPhoneReviewSettings(tester);
      final state = await reviewState(share: FixedMailShare(), reviewing: true);
      final words = state.deckById(wordsDeck)!;
      state.reviewing.markRight(words, words.cards.first);
      await state.reviewing.send(state.reviewing.unsent, body: '');
      await pumpScreen(tester, const ReviewingPage(), state: state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewSettingsToSend), findsNothing);
      expect(find.text(l10n.reviewSettingsSendAgainDesc(1)), findsOneWidget);
      await tester.tap(find.text(l10n.reviewSettingsSendAgain));
      await tester.pumpAndSettle();
      expect(find.byType(SendReviewsSheet), findsOneWidget);
      expect(state.reviewing.unsent.map((d) => d.deckId), <String>[wordsDeck]);
      expect(find.text(l10n.reviewSendButton(1)), findsOneWidget);
    });
  });

  group('what can be reviewed', () {
    const bnEn = ReviewPair('bn', 'en');
    const teEn = ReviewPair('te', 'en');
    const hiBn = ReviewPair('hi', 'bn');

    ReviewerLanguages reviewer(
      Map<String, bool> scripts, [
      Set<String>? known,
    ]) => ReviewerLanguages(
      known: known ?? scripts.keys.toSet(),
      readsScript: scripts,
    );

    group('eligibility', () {
      test('a pair can be reviewed only when both languages are known and both '
          'scripts read', () {
        final r = reviewer(const <String, bool>{'bn': true, 'en': true});
        expect(r.canReview(bnEn), isTrue);
        expect(r.blockOf(bnEn), isNull);

        {
          final r = reviewer(const <String, bool>{'en': true});
          expect(r.blockOf(teEn), PairBlock.unknownTarget);
          final s = reviewer(const <String, bool>{'bn': true});
          expect(s.blockOf(bnEn), PairBlock.unknownNative);
        }

        {
          final r = reviewer(const <String, bool>{'bn': false, 'en': true});
          expect(r.blockOf(bnEn), PairBlock.targetScript);
          final s = reviewer(const <String, bool>{
            'hi': true,
            'bn': false,
            'en': true,
          });
          expect(s.blockOf(hiBn), PairBlock.nativeScript);
          expect(s.canReview(hiBn), isFalse);
        }
      });
    });
  });

  group('what waits', () {
    group('what waits in a language', () {
      test('what waits per language, fewer as the reviewer checks', () async {
        final state = await reviewer();
        final te = state.deckById(wordsDeck)!.language;
        final waiting = waitingIn(state, te);
        // The unit of rude words only is not among them: its words are
        // reviewed apart, on purpose, in the Offensive words review.
        expect(waiting.units.map((u) => (u.number, u.title)), [
          (1, 'Family words'),
        ]);
        expect(waiting.units.first.decks.single.left, 2);
        expect(waiting.units.first.decks.single.total, 2);
        expect(waiting.decks, isEmpty);
        expect(waiting.unrated.map((c) => c.card.id), [rudeCard]);
        expect(waiting.offensive, 1);
        expect(waiting.unconfirmed.map((c) => c.card.id), [alikeCard]);
        expect(state.reviewing.unsent, isEmpty);
        expect(waiting.isEmpty, isFalse);

        {
          final state = await reviewer();
          final words = state.deckById(wordsDeck)!;
          final rude = state.deckById(rudeDeck)!;
          final reviewing = state.reviewing;
          reviewing.markRight(words, words.cards.last);
          reviewing.rate(rude, rude.cards.single, const WordRating(score: 6));
          reviewing.checkAlike(
            words,
            words.cards.first,
            const AlikeCheck(
              partner: rudeCard,
              kind: AlikeKind.sound,
              real: true,
            ),
          );
          final waiting = waitingIn(state, words.language);
          expect(waiting.units.single.decks.single.left, 1);
          expect(waiting.unrated, isEmpty);
          expect(waiting.offensive, 1);
          expect(waiting.unconfirmed, isEmpty);
          expect(state.reviewing.unsent.map((d) => d.deckId).toSet(), {
            wordsDeck,
            rudeDeck,
          });
        }
      });

      test('offensive words are never among a unit\'s cards left, adult '
          'content on or off: they wait to be rated, apart', () async {
        final state = await reviewer();
        final rude = state.deckById(rudeDeck)!;
        for (final adult in <bool>[false, true]) {
          state.settings.adultContent = adult;
          final waiting = waitingIn(state, rude.language);
          expect(
            waiting.allDecks.map((d) => d.deck.id),
            isNot(contains(rudeDeck)),
          );
          expect(waiting.unrated.map((c) => c.card.id), [rudeCard]);
        }
        state.reviewing.rate(
          rude,
          rude.cards.single,
          const WordRating(score: 6),
        );
        expect(waitingIn(state, rude.language).unrated, isEmpty);
      });
    });
  });

  group('waiting for review', () {
    group('what became of a sent suggestion, from the deck files', () {
      const own = Proposal(
        id: 'aaaaaaaaaa',
        card: plainCard,
        field: ProposalField.native,
        now: 'mother',
        text: 'mum',
        by: reviewerCode,
        date: '2026-10-09',
      );
      const mum = Suggestion(
        part: CardPart.meaning,
        now: 'mother',
        text: 'mum',
      );
      SentState of(
        Suggestion s,
        String? current, [
        List<Proposal> proposals = const <Proposal>[],
      ]) => sentStateOf(
        suggestion: s,
        current: current,
        proposals: proposals,
        code: reviewerCode,
        agreementsNeeded: 2,
      );

      test(
        'a sent suggestion reads waiting, accepted or rejected from the deck '
        'files',
        () {
          expect(
            of(mum, 'mother', <Proposal>[own]),
            const SentState(SentOutcome.waiting, moreNeeded: 2),
          );
          final once = Proposal(
            id: own.id,
            card: own.card,
            field: own.field,
            now: own.now,
            text: own.text,
            by: own.by,
            date: own.date,
            accepted: const <String>[otherCode],
          );
          expect(
            of(mum, 'mother', <Proposal>[once]),
            const SentState(SentOutcome.waiting, moreNeeded: 1),
          );
          final other = Proposal(
            id: 'bbbbbbbbbb',
            card: own.card,
            field: own.field,
            now: own.now,
            text: own.text,
            by: otherCode,
            date: own.date,
          );
          expect(
            of(mum, 'mother', <Proposal>[other]).outcome,
            SentOutcome.unknown,
          );

          expect(of(mum, 'mum').outcome, SentOutcome.accepted);
          expect(of(mum, 'mom').outcome, SentOutcome.rejected);
          expect(
            of(mum, 'mother'),
            const SentState(
              SentOutcome.unknown,
              unknown: SentUnknown.notInDeckYet,
            ),
          );
          expect(of(mum, null).unknown, SentUnknown.notInDeckYet);
        },
      );
    });

    group('Reviewed, not sent', () {
      testWidgets('once sent, nothing is left here', (tester) async {
        usePhone(tester);
        final state = await reviewerState();
        await reviewAndSend(state);
        await pumpScreen(tester, const ReviewedNotSentPage(), state: state);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.reviewUnsentNone), findsOneWidget);
        expect(find.text(l10n.reviewSend), findsNothing);
      });
    });
  });

  group('offensive words', () {
    testWidgets('it asks every time it is opened, and shows no word before', (
      tester,
    ) async {
      useTallPhoneOffensiveReview(tester);
      await pumpOffensive(tester);
      final l10n = l10nOf(tester);
      expect(
        find.text(l10n.reviewOffensivePageTitle('Telugu')),
        findsOneWidget,
      );
      // Why: the range, understanding abuse, culture, what to do, and that
      // they are kept apart.
      for (final line in <String>[
        l10n.reviewOffensiveWhyTitle,
        l10n.reviewOffensiveWhyRange,
        l10n.reviewOffensiveWhyUnderstand,
        l10n.reviewOffensiveWhyCulture,
        l10n.reviewOffensiveWhyRate,
        l10n.reviewOffensiveWhyApart,
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
      expect(find.text(l10n.settingsAdultConfirm), findsNothing);
      expectNoWord();

      await tester.tap(find.text(l10n.commonContinue));
      await tester.pumpAndSettle();
      // Then the age, still with no word.
      expect(find.text(l10n.reviewOffensiveWhyRange), findsNothing);
      expect(find.text(l10n.settingsAdultConfirmTitle), findsOneWidget);
      expect(find.text(l10n.reviewOffensiveAgeBody('Telugu')), findsOneWidget);
      expectNoWord();

      await tester.tap(find.text(l10n.settingsAdultConfirm));
      await tester.pumpAndSettle();
      expect(find.text('వెధవ'), findsOneWidget);
      expect(find.text('vedhava'), findsOneWidget);
      expect(find.text('idiot, good-for-nothing'), findsOneWidget);
      expect(find.text(l10n.reviewOffensiveWordsInfo), findsOneWidget);
      expect(find.text(l10n.reviewOffensiveProgress(0, 1)), findsNWidgets(2));
      expect(rowButton(l10n.reviewRateShort), findsOneWidget);

      {
        useTallPhoneOffensiveReview(tester);
        final state = await reviewState(reviewing: true);
        state.settings.adultContent = true;
        await pumpOffensive(tester, state: state);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.reviewOffensiveWhyTitle), findsOneWidget);
        await tester.tap(find.text(l10n.commonContinue));
        await tester.pumpAndSettle();
        expect(find.text(l10n.settingsAdultConfirmTitle), findsOneWidget);
        expectNoWord();
      }
    });

    testWidgets(
      'the rating sheet offers the regions the path lists, and a deck of '
      'offensive words only is signed off here',
      (tester) async {
        useTallPhoneOffensiveReview(tester);
        await pumpOffensive(
          tester,
          state: await reviewState(
            reviewing: true,
            regions: '''
  - { id: "north", name: { "en": "The north", "te": "ఉత్తరం" } }
  - { id: "coastal-andhra", name: { "en": "The coast" } }''',
          ),
        );
        await passGate(tester);
        final l10n = l10nOf(tester);
        await tester.tap(rowButton(l10n.reviewRateShort));
        await tester.pumpAndSettle();
        final chips = <String>[
          'The north',
          'The coast',
          l10n.reviewRateElsewhere,
        ];
        for (var i = 1; i < chips.length; i++) {
          expect(
            tester.getTopLeft(find.text(chips[i - 1])).dy,
            lessThan(tester.getTopLeft(find.text(chips[i])).dy),
          );
        }
        expect(find.text('Telangana'), findsNothing);

        {
          useTallPhoneOffensiveReview(tester);
          final share = FixedMailShare();
          final state = await pumpOffensive(
            tester,
            state: await reviewState(reviewing: true, share: share),
          );
          await passGate(tester);
          final l10n = l10nOf(tester);
          final signOff = find.widgetWithText(
            OutlinedButton,
            l10n.reviewSignOff(1),
          );
          expect(tester.widget<OutlinedButton>(signOff).onPressed, isNull);

          final rude = state.deckById(rudeDeck)!;
          state.reviewing.rate(
            rude,
            rude.cards.single,
            const WordRating(
              score: 7,
              region: 'telangana',
              friendly: Friendly.no,
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.reviewSignOffReady));
          await tester.pumpAndSettle();
          expect(find.text(l10n.reviewSignedOff), findsOneWidget);
          expect(state.reviewing.reviews.of(rudeDeck)!.signedOff, isNotNull);

          await tester.tap(find.text(l10n.reviewSend));
          await tester.pumpAndSettle();
          expect(find.byType(SendReviewsSheet), findsOneWidget);
          await tester.tap(find.text(l10n.reviewSendButton(1)));
          await tester.pumpAndSettle();
          final file = jsonDecode(
            share.shared.single.files.single.text,
          ) as Map<String, Object?>;
          expect(file['deck'], rudeDeck);
          expect(file['signed_off'], isNotNull);
          final card = (file['cards']! as List).single as Map;
          expect(card['card'], rudeCard);
          expect(card['rating'], <String, Object?>{
            'score': 7,
            'region': 'telangana',
            'friendly': 'no',
          });
          await tester.pumpAndSettle(const Duration(seconds: 5));
        }
      },
    );
  });

  group('the look-alike warning', () {
    testWidgets(
      'the look-alike warning comes after the answer, never before, and '
      'names the rude word only with adult content on',
      (tester) async {
        usePhone(tester);
        final request = DrillRequest.deck(wordsDeck, skill: Skill.recognition);
        await pumpScreen(
          tester,
          DrillPage(
            request: request,
            preset: const DrillPreset(target: 'విధవ'),
          ),
          state: await reviewState(),
        );
        expect(find.byType(AlikeWarning), findsNothing);

        await pumpScreen(
          tester,
          DrillPage(
            key: UniqueKey(),
            request: request,
            preset: const DrillPreset(target: 'విధవ', reveal: true),
          ),
          state: await reviewState(),
        );
        final l10n = l10nOf(tester);
        expect(find.byType(AlikeWarning), findsOneWidget);
        expect(find.text(l10n.alikeCarefulSpeaking), findsOneWidget);
        expect(find.text(l10n.alikeSpeakingRude), findsOneWidget);
        expect(find.text(l10n.alikeHidden), findsOneWidget);
        expect(find.textContaining('వెధవ'), findsNothing);

        {
          usePhone(tester);
          final state = await reviewState();
          await pumpScreen(
            tester,
            Scaffold(
              body: AlikeWarning.forCard(
                state,
                state.deckById(wordsDeck)!.cards.first,
                state.deckById(wordsDeck)!.language,
              ).single,
            ),
            state: state,
          );
          final l10n = l10nOf(tester);
          expect(find.text(l10n.alikeHidden), findsOneWidget);

          await pumpScreen(
            tester,
            Scaffold(
              body: AlikeWarning(
                kind: AlikeKind.sound,
                named: state.deckById(rudeDeck)!.cards.single,
                language: state.deckById(rudeDeck)!.language,
                care: 'Keep the short i.',
              ),
            ),
            state: state,
          );
          expect(find.text(l10n.alikeHidden), findsNothing);
          expect(
            find.text(l10n.reviewAlikeSounds('వెధవ', 'vedhava')),
            findsOneWidget,
          );
          expect(find.text('Keep the short i.'), findsOneWidget);
        }
      },
    );
  });

  group('How reviewing works', () {
    group('docs/REVIEWING.md and the app say the same', () {
      test(
        'the guide\'s agreement count, and the app\'s, are the review bot\'s',
        () {
          final guide = File('docs/REVIEWING.md').readAsStringSync();
          expect(guide, contains('`REVIEW_AGREEMENTS_NEEDED`'));
          expect(
            guide.replaceAll(RegExp(r'\s+'), ' '),
            contains('is ${Reviewing.agreementsNeeded} by default'),
          );
          expect(guide, contains(AppLinks.feedbackEmail));

          final bot = File('tools/review_bot.py').readAsStringSync();
          expect(
            bot.replaceAll(RegExp(r'\s+'), ' '),
            contains('${Reviewing.agreementsNeeded} when unset'),
          );
        },
      );
    });
  });
}
