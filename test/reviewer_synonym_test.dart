// A reviewer adds one accepted answer ("Another accepted answer",
// `alt_native`) or one refused word ("Not a synonym", `not_synonyms`) to a
// card (ADR-0050): each a proposal to add, never a change, in the review
// file under the names the review bot reads.

import 'dart:convert';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/proposal.dart';
import 'package:fluenough/core/review/added_item.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/rater_code.dart';
import 'package:fluenough/core/review/review_file.dart';
import 'package:fluenough/core/review/sent_state.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/features/review/proposal_card.dart';
import 'package:fluenough/features/review/review_page.dart';
import 'package:fluenough/features/review/review_sheets.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/labelled.dart';
import 'support/review_fixture.dart';

/// "mother", also accepted as "mum", and refusing "woman".
const Card _mother = Card(
  id: plainCard,
  deckId: wordsDeck,
  target: 'అమ్మ',
  native: 'mother (female parent); the mother',
  altNative: <String>['mum'],
  notSynonyms: <String>['woman'],
  reading: 'amma',
  pos: 'noun',
);

AddedItemProblem? _check(
  CardPart part,
  String typed, {
  String nativeCode = 'en',
  Iterable<String> alsoAdded = const <String>[],
}) => checkAddedItem(
  part: part,
  typed: typed,
  card: _mother,
  nativeCode: nativeCode,
  alsoAdded: alsoAdded,
);

Future<AppState> _open(WidgetTester tester, {double textScale = 1.0}) async {
  usePhone(tester, textScale: textScale);
  tester.view.physicalSize = const Size(390 * 3, 4800 * 3);
  final state = await reviewState(reviewing: true);
  final words = state.deckById(wordsDeck)!;
  await pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showSuggestSheet(context, deck: words, card: _mother),
          child: const Text('open'),
        ),
      ),
    ),
    state: state,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return state;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, Key key, String text) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.enterText(find.byKey(key), text);
  await tester.pumpAndSettle();
}

/// Whether the sheet's Save (the check in its top row) is on.
bool _canSave(WidgetTester tester) {
  final save = find.ancestor(
    of: find.byTooltip(l10nOf(tester).reviewSuggestSaveAll).first,
    matching: find.byType(IconButton),
  );
  return tester.widget<IconButton>(save.first).onPressed != null;
}

List<Suggestion> _kept(AppState state) {
  final words = state.deckById(wordsDeck)!;
  return state.reviewing.reviewOf(words, _mother)?.suggestions ??
      const <Suggestion>[];
}

void main() {
  group('the proposal as the review file carries it', () {
    test('an added item is `alt_native` or `not_synonyms` with action add and '
        'the item in text', () {
      final review = CardReview(
        at: DateTime.utc(2026, 10, 31),
        suggestions: const <Suggestion>[
          Suggestion(
            part: CardPart.altNative,
            word: 'new-1',
            action: BaseAction.add,
            now: '',
            text: 'mommy',
            why: 'Said in Texas',
          ),
          Suggestion(
            part: CardPart.notSynonyms,
            word: 'new-1',
            action: BaseAction.add,
            now: '',
            text: 'lady',
          ),
        ],
      );
      final json = jsonDecode(jsonEncode(review.toJson())) as Map;
      final parts = (json['suggestions'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(
        parts.map((p) => (p['part'], p['action'], p['now'], p['text'])),
        <Object>[
          ('alt_native', 'add', '', 'mommy'),
          ('not_synonyms', 'add', '', 'lady'),
        ],
      );
      final back = CardReview.fromJson(json)!;
      expect(back.suggestions.map((s) => (s.part, s.text, s.why)), <Object>[
        (CardPart.altNative, 'mommy', 'Said in Texas'),
        (CardPart.notSynonyms, 'lady', ''),
      ]);
    });

    test('an item that changes or removes, or names no item, is dropped', () {
      Map<String, Object?> json(Map<String, Object?> more) => <String, Object?>{
        'part': 'alt_native',
        'now': '',
        'text': 'mommy',
        ...more,
      };
      expect(Suggestion.fromJson(json(<String, Object?>{})), isNull);
      for (final action in <String>['edit', 'remove']) {
        expect(
          Suggestion.fromJson(
            json(<String, Object?>{'word': 'new-1', 'action': action}),
          ),
          isNull,
          reason: action,
        );
      }
      expect(
        Suggestion.fromJson(
          json(<String, Object?>{'word': 'new-1', 'action': 'add'}),
        ),
        isNotNull,
      );
    });

    test('a deck names the fields alt_native_add and not_synonyms_add', () {
      expect(
        ProposalField.fromWire('alt_native_add'),
        ProposalField.altNativeAdd,
      );
      expect(
        ProposalField.fromWire('not_synonyms_add'),
        ProposalField.notSynonymsAdd,
      );
      expect(ProposalField.fromWire('register'), ProposalField.register);
      expect(ProposalField.fromWire('altNativeAdd'), isNull);
      expect(proposalFieldOf(CardPart.altNative), ProposalField.altNativeAdd);
      expect(
        proposalFieldOf(CardPart.notSynonyms),
        ProposalField.notSynonymsAdd,
      );
    });
  });

  group('what is accepted as an item to add', () {
    test('a new, single answer is, trimmed and with its spaces made one', () {
      expect(_check(CardPart.altNative, '  mommy  '), isNull);
      expect(addedItemText('  my   mommy \n'), 'my mommy');
      expect(_check(CardPart.notSynonyms, 'lady'), isNull);
    });

    test('nothing, or only spaces, is empty', () {
      for (final part in <CardPart>[CardPart.altNative, CardPart.notSynonyms]) {
        expect(_check(part, ''), AddedItemProblem.empty);
        expect(_check(part, '   '), AddedItemProblem.empty);
      }
    });

    test('an answer the card has, however it is written, is refused', () {
      // The card's own answer, with its article, brackets and case.
      expect(_check(CardPart.altNative, 'Mother'), AddedItemProblem.ownAnswer);
      expect(
        _check(CardPart.altNative, 'the mother'),
        AddedItemProblem.ownAnswer,
      );
      expect(
        _check(CardPart.notSynonyms, ' MOTHER '),
        AddedItemProblem.ownAnswer,
      );
      // Already in the list that is added to.
      expect(_check(CardPart.altNative, 'Mum.'), AddedItemProblem.alreadyThere);
      expect(
        _check(CardPart.notSynonyms, 'a woman'),
        isNull,
        reason: 'only the same words are the same item',
      );
      expect(
        _check(CardPart.notSynonyms, 'Woman'),
        AddedItemProblem.alreadyThere,
      );
      // An accepted answer is not refused, and a refused word not accepted.
      expect(_check(CardPart.notSynonyms, 'mum'), AddedItemProblem.ownAnswer);
      expect(
        _check(CardPart.altNative, 'woman'),
        AddedItemProblem.refusedByCard,
      );
    });

    test('several answers split by a semicolon are not one answer', () {
      expect(
        _check(CardPart.altNative, 'mommy; mama'),
        AddedItemProblem.severalAnswers,
      );
    });

    test('an item typed twice in one sheet is refused the second time', () {
      expect(
        _check(CardPart.altNative, 'Mommy', alsoAdded: <String>['mommy']),
        AddedItemProblem.alreadyThere,
      );
    });

    test('a word to refuse is for English meanings only', () {
      expect(offersNotSynonyms('en'), isTrue);
      expect(offersNotSynonyms('hi'), isFalse);
      expect(
        _check(CardPart.notSynonyms, 'lady', nativeCode: 'hi'),
        AddedItemProblem.notEnglish,
      );
      expect(_check(CardPart.altNative, 'mommy', nativeCode: 'hi'), isNull);
    });
  });

  group('the Suggest a change sheet', () {
    testWidgets('offers both lists, and what the card has now', (tester) async {
      await _open(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewPartAltNative.toUpperCase()), findsOneWidget);
      expect(
        find.text(l10n.reviewPartNotSynonyms.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text('mum'), findsOneWidget);
      expect(find.text('woman'), findsOneWidget);
      expect(
        find.byKey(SuggestSheet.addItemKey(CardPart.altNative)),
        findsOneWidget,
      );
      expect(
        find.byKey(SuggestSheet.addItemKey(CardPart.notSynonyms)),
        findsOneWidget,
      );
    });

    testWidgets('an item of each is kept as an add, trimmed, with its why', (
      tester,
    ) async {
      final state = await _open(tester);
      await _tap(
        tester,
        find.byKey(SuggestSheet.addItemKey(CardPart.altNative)),
      );
      await _type(
        tester,
        SuggestSheet.newItemKey(CardPart.altNative, 0, 'text'),
        '  mommy ',
      );
      await _type(
        tester,
        SuggestSheet.newItemKey(CardPart.altNative, 0, 'why'),
        'Said by children',
      );
      await _tap(
        tester,
        find.byKey(SuggestSheet.addItemKey(CardPart.notSynonyms)),
      );
      await _type(
        tester,
        SuggestSheet.newItemKey(CardPart.notSynonyms, 0, 'text'),
        'lady',
      );
      expect(_canSave(tester), isTrue);
      await _tap(tester, find.byTooltip(l10nOf(tester).reviewSuggestSaveAll));

      final kept = _kept(state);
      expect(
        kept.map((s) => (s.part, s.action, s.now, s.text, s.why)),
        <Object>[
          (CardPart.altNative, BaseAction.add, '', 'mommy', 'Said by children'),
          (CardPart.notSynonyms, BaseAction.add, '', 'lady', ''),
        ],
      );
      // It goes in the mail under the names the bot reads.
      final file = jsonDecode(
        ReviewFile.encode(
          state.reviewing.reviews.of(wordsDeck)!,
          code: RaterCode.tryParse(reviewerCode)!,
          appVersion: '0.7.0',
          made: DateTime.utc(2026, 10, 31),
        ),
      ) as Map<String, Object?>;
      final card = (file['cards']! as List<Object?>).single as Map;
      expect(
        <Object?>[
          for (final s in card['suggestions'] as List<Object?>)
            ((s as Map)['part'], s['action'], s['text']),
        ],
        <Object>[
          ('alt_native', 'add', 'mommy'),
          ('not_synonyms', 'add', 'lady'),
        ],
      );
    });

    testWidgets('a bad item says why and cannot be saved until it is fixed', (
      tester,
    ) async {
      await _open(tester);
      final l10n = l10nOf(tester);
      await _tap(
        tester,
        find.byKey(SuggestSheet.addItemKey(CardPart.altNative)),
      );
      final field = SuggestSheet.newItemKey(CardPart.altNative, 0, 'text');
      // Nothing typed is not an error, and nothing to save.
      expect(_canSave(tester), isFalse);
      expect(find.text(l10n.reviewAddedEmpty), findsNothing);

      await _type(tester, field, 'Mother');
      expect(find.text(l10n.reviewAddedOwnAnswer), findsOneWidget);
      expect(_canSave(tester), isFalse);

      await _type(tester, field, 'mum');
      expect(find.text(l10n.reviewAddedAlreadyThere), findsOneWidget);
      expect(_canSave(tester), isFalse);

      await _type(tester, field, 'a; b');
      expect(find.text(l10n.reviewAddedSeveral), findsOneWidget);
      expect(_canSave(tester), isFalse);

      await _type(tester, field, 'woman');
      expect(find.text(l10n.reviewAddedRefused), findsOneWidget);
      expect(_canSave(tester), isFalse);

      await _type(tester, field, 'mommy');
      expect(find.text(l10n.reviewAddedRefused), findsNothing);
      expect(_canSave(tester), isTrue);
    });

    testWidgets('at 1.4x text a typed refusal shows its error without an '
        'overflow', (tester) async {
      await _open(tester, textScale: 1.4);
      final l10n = l10nOf(tester);
      await _tap(
        tester,
        find.byKey(SuggestSheet.addItemKey(CardPart.altNative)),
      );
      await _type(
        tester,
        SuggestSheet.newItemKey(CardPart.altNative, 0, 'text'),
        'woman',
      );
      expect(find.text(l10n.reviewAddedRefused), findsOneWidget);
      expect(_canSave(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an item dropped before saving is not kept', (tester) async {
      final state = await _open(tester);
      final l10n = l10nOf(tester);
      await _tap(
        tester,
        find.byKey(SuggestSheet.addItemKey(CardPart.notSynonyms)),
      );
      await _type(
        tester,
        SuggestSheet.newItemKey(CardPart.notSynonyms, 0, 'text'),
        'lady',
      );
      await _tap(tester, byButtonLabel(l10n.reviewAddRemove));
      expect(_canSave(tester), isFalse);
      expect(_kept(state), isEmpty);
    });

    testWidgets('a kept item opens again in the sheet', (tester) async {
      final state = await _open(tester);
      await _tap(
        tester,
        find.byKey(SuggestSheet.addItemKey(CardPart.altNative)),
      );
      await _type(
        tester,
        SuggestSheet.newItemKey(CardPart.altNative, 0, 'text'),
        'mommy',
      );
      await _tap(tester, find.byTooltip(l10nOf(tester).reviewSuggestSaveAll));
      expect(_kept(state), hasLength(1));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final box = tester.widget<TextField>(
        find.byKey(SuggestSheet.newItemKey(CardPart.altNative, 0, 'text')),
      );
      expect(box.controller!.text, 'mommy');
    });
  });

  group('only reviewers meet them', () {
    testWidgets('a learner\'s word sheet shows neither list\'s title or '
        'button', (tester) async {
      usePhone(tester);
      final state = await reviewState(reviewing: true);
      await pumpScreen(
        tester,
        Scaffold(
          body: WordSheet(
            card: _mother,
            language: state.deckById(wordsDeck)!.language,
          ),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      for (final text in <String>[
        l10n.reviewPartAltNative,
        l10n.reviewPartNotSynonyms,
        l10n.reviewAddAltNative,
        l10n.reviewAddNotSynonym,
      ]) {
        expect(find.textContaining(text), findsNothing, reason: text);
      }
    });
  });

  group('a sent item', () {
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

    const refuse = Suggestion(
      part: CardPart.notSynonyms,
      word: 'new-1',
      action: BaseAction.add,
      now: '',
      text: 'Lady',
    );

    test('waits as a proposal, in the comparison form the bot writes', () {
      final own = const Proposal(
        id: 'aaaaaaaaaa',
        card: plainCard,
        field: ProposalField.notSynonymsAdd,
        now: '',
        text: 'lady',
        by: reviewerCode,
        date: '2026-10-31',
      );
      expect(
        of(refuse, '', <Proposal>[own]),
        const SentState(SentOutcome.waiting, moreNeeded: 2),
      );
    });

    test('is accepted once the card has the item, and otherwise unknown', () {
      expect(of(refuse, 'Lady').outcome, SentOutcome.accepted);
      expect(
        of(refuse, '').unknown,
        SentUnknown.notInDeckYet,
        reason: 'an item is never rejected: nothing is replaced',
      );
    });
  });

  group('another reviewer\'s proposal to add an item', () {
    const proposed =
        '[{ id: "aaaaaaaaaa", field: "alt_native_add", now: "", '
        'text: "mama", by: "$otherCode", date: "2026-10-31" }, '
        '{ id: "bbbbbbbbbb", field: "not_synonyms_add", now: "", '
        'text: "lady", by: "$otherCode", date: "2026-10-31" }]';

    testWidgets('shows with Accept, Edit and Reject, and Edit opens it as an '
        'item to add', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
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
      await tester.tap(find.text('mother'));
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      // Both show: "mama" is not on the card yet, and "lady" is not one of its
      // answers or refused words. (A refusal of "mother", the card's own
      // answer, would be dropped as already settled.)
      expect(find.byType(ProposalCard), findsNWidgets(2));
      expect(
        find.text(l10n.reviewProposalTitle(l10n.reviewPartAltNative)),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.reviewProposalEdit).first);
      await tester.pumpAndSettle();
      final box = tester.widget<TextField>(
        find.byKey(SuggestSheet.newItemKey(CardPart.altNative, 0, 'text')),
      );
      expect(box.controller!.text, 'mama');
      await tester.tap(find.byTooltip(l10n.reviewSuggestSaveAll));
      await tester.pumpAndSettle();
      final words = state.deckById(wordsDeck)!;
      final review = state.reviewing.reviewOf(words, words.cards.last)!;
      expect(review.suggestions.single.part, CardPart.altNative);
      expect(review.suggestions.single.text, 'mama');
      expect(review.answers['aaaaaaaaaa']!.verdict, ProposalVerdict.edit);
      expect(review.answers['aaaaaaaaaa']!.field, 'alt_native_add');
    });
  });
}
