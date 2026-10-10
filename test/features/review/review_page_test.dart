import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/thanks_notice.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/decks/unreviewed_notice.dart';
import 'package:fluenough/features/review/review_page.dart';
import 'package:fluenough/features/review/review_sheets.dart';
import 'package:fluenough/features/review/send_reviews_sheet.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/ui/widgets/speaker.dart';

import '../../support/harness.dart';
import '../../support/review_fixture.dart';

/// A phone tall enough for every card and sheet to be built.
void useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
}

Finder rowButton(String label) => find.widgetWithText(FilledButton, label);

void main() {
  testWidgets('the review shows the code and how far it has got; Check marks '
      'a card right, Right takes it back', (tester) async {
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
  });

  testWidgets('a card opens whole; Looks right marks it, Suggest a change '
      'picks a part, shows it now, and saves the change and why', (
    tester,
  ) async {
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
    expect(find.text('Also అమ్మా (ammā) when calling her.'), findsOneWidget);
    await tester.tap(find.text(l10n.reviewLooksRight));
    await tester.pumpAndSettle();
    final words = state.deckById(wordsDeck)!;
    final mother = words.cards.last;
    expect(state.reviewing.reviewOf(words, mother)!.right, isTrue);

    await tester.tap(find.text('mother'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, l10n.reviewSuggest));
    await tester.pumpAndSettle();
    expect(find.byType(SuggestSheet), findsOneWidget);
    expect(find.text(l10n.reviewSuggestWhich), findsOneWidget);
    for (final part in CardPart.values) {
      expect(find.text(partName(l10n, part)), findsOneWidget);
    }
    // Save waits for a change.
    final save = find.widgetWithText(FilledButton, l10n.reviewSave);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.tap(find.text(l10n.reviewPartNotes));
    await tester.pumpAndSettle();
    expect(find.text(l10n.reviewSuggestNow), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, l10n.reviewSuggestYours),
      'Also అమ్మా (ammā), and మా అమ్మ (mā amma), our mother.',
    );
    await tester.enterText(
      find.widgetWithText(TextField, l10n.reviewSuggestWhy),
      'Common in speech',
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final suggestion = state.reviewing.reviewOf(words, mother)!.suggestion!;
    expect(suggestion.part, CardPart.notes);
    expect(suggestion.now, 'Also అమ్మా (ammā) when calling her.');
    expect(suggestion.why, 'Common in speech');
    expect(state.reviewing.reviewOf(words, mother)!.right, isFalse);
    expect(rowButton(l10n.reviewSuggested), findsOneWidget);
  });

  testWidgets('offensive words never appear in a unit\'s review, adult '
      'content on or off, nor count as left to check', (tester) async {
    useTallPhone(tester);
    for (final adult in <bool>[false, true]) {
      await pumpScreen(
        tester,
        ReviewPage(deckId: rudeDeck, adult: adult),
        state: await reviewState(reviewing: true),
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

  testWidgets('a deck with offensive and ordinary words shows only the '
      'ordinary ones, and is signed off with them', (tester) async {
    useTallPhone(tester);
    final state = AppState.test(
      decks: MemoryDeckSource(<String, String>{
        ...reviewCourse(),
        'decks/te/te-en-review-mixed.yaml': '''
schema: 1
id: te-en-review-mixed
name: "Mixed words"
language: { code: te, iso639_3: tel, name: Telugu, script: telugu }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [unreviewed]
cards:
  - { id: te-9905, target: "అక్క", native: "elder sister", reading: "akka" }
  - { id: te-9952, target: "దొంగ", native: "thief", reading: "doṅga", tags: [offensive], modes: [recognition] }
''',
      }),
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['te'],
        learningChosen: true,
      ),
    );
    await state.load();
    state.reviewing.turnOn();
    await pumpScreen(
      tester,
      const ReviewPage(deckId: 'te-en-review-mixed', adult: true),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(find.text('elder sister'), findsOneWidget);
    expect(find.text('thief'), findsNothing);
    expect(find.text('దొంగ'), findsNothing);
    expect(find.text(l10n.reviewOffensiveApart(1)), findsOneWidget);
    expect(find.text(l10n.reviewPageProgress(0, 1)), findsOneWidget);
    await tester.tap(rowButton(l10n.reviewCheck));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.reviewSignOffReady));
    await tester.pumpAndSettle();
    expect(
      state.reviewing.reviews.of('te-en-review-mixed')!.signedOff,
      isNotNull,
    );
  });

  testWidgets('a unit with no offensive words says nothing of them', (
    tester,
  ) async {
    useTallPhone(tester);
    await pumpScreen(
      tester,
      const ReviewPage(deckId: wordsDeck, adult: true),
      state: await reviewState(reviewing: true),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reviewOffensiveApart(1)), findsNothing);
    expect(find.text(l10n.reviewPageProgress(0, 2)), findsOneWidget);
  });

  testWidgets('a sound-alike pair is confirmed with a care note of at most '
      '40 letters, its budget shown as it is typed', (tester) async {
    useTallPhone(tester);
    final state = await pumpScreen(
      tester,
      const ReviewPage(deckId: wordsDeck, adult: true),
      state: await reviewState(reviewing: true),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text('widow'));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.reviewAlikeSounds('వెధవ', 'vedhava')),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.reviewAlikeCheck));
    await tester.pumpAndSettle();
    expect(find.byType(AlikeSheet), findsOneWidget);
    expect(find.text(l10n.reviewAlikeReal), findsOneWidget);
    await tester.tap(find.text(l10n.reviewAlikeConfirm));
    await tester.pumpAndSettle();
    expect(find.text(l10n.reviewAlikeCareCount(0, 40)), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'Keep the short i at the start.',
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.reviewAlikeCareCount(30, 40)), findsOneWidget);
    // Never more than 40.
    await tester.enterText(find.byType(TextField), 'x' * 50);
    await tester.pumpAndSettle();
    expect(find.text(l10n.reviewAlikeCareCount(40, 40)), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'Keep the short i at the start.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, l10n.reviewSave));
    await tester.pumpAndSettle();
    final words = state.deckById(wordsDeck)!;
    final alike = state.reviewing.reviewOf(words, words.cards.first)!.alike!;
    expect(alike.real, isTrue);
    expect(alike.partner, rudeCard);
    expect(alike.kind, AlikeKind.sound);
    expect(alike.care, 'Keep the short i at the start.');
    expect(find.text(l10n.reviewAlikeConfirmed), findsOneWidget);
  });

  testWidgets('without adult content the pair\'s rude word stays hidden', (
    tester,
  ) async {
    useTallPhone(tester);
    await pumpScreen(
      tester,
      const ReviewPage(deckId: wordsDeck),
      state: await reviewState(reviewing: true),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text('widow'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.alikeCarefulSpeaking), findsOneWidget);
    expect(find.text(l10n.alikeHidden), findsOneWidget);
    expect(find.textContaining('వెధవ'), findsNothing);
    expect(find.text(l10n.reviewAlikeCheck), findsNothing);
  });

  testWidgets('Sign off once every card is checked; Send review sends every '
      'deck waiting in one mail, a file each, all ticked', (tester) async {
    useTallPhone(tester);
    final share = FixedMailShare();
    final state = await reviewState(share: share, reviewing: true);
    final rude = state.deckById(rudeDeck)!;
    state.reviewing.rate(rude, rude.cards.single, const WordRating(score: 7));
    await pumpScreen(tester, const ReviewPage(deckId: wordsDeck), state: state);
    final l10n = l10nOf(tester);
    final signOff = find.widgetWithText(OutlinedButton, l10n.reviewSignOff(2));
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

  testWidgets('a unit whose deck lists the reviewer\'s code thanks them in '
      'place of the not-yet-checked notice', (tester) async {
    useTallPhone(tester);
    Future<void> show(List<String> authors) async => pumpScreen(
      tester,
      const UnitPage(deckId: wordsDeck),
      state: await reviewState(
        authors: authors,
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['te'],
          learningChosen: true,
        )..raterCode = reviewerCode,
      ),
    );
    await show(const <String>[otherCode]);
    expect(find.byType(UnreviewedNotice), findsOneWidget);
    expect(find.byType(ThanksNotice), findsNothing);

    await show(const <String>[reviewerCode, otherCode]);
    final l10n = l10nOf(tester);
    expect(find.byType(ThanksNotice), findsOneWidget);
    expect(find.byType(UnreviewedNotice), findsNothing);
    expect(find.text(l10n.reviewThanksTitle), findsOneWidget);
    expect(find.text(l10n.reviewThanksBy(1, reviewerCode)), findsOneWidget);
  });

  testWidgets('beside the thanks, another deck of the unit still unchecked '
      'keeps its notice', (tester) async {
    useTallPhone(tester);
    await pumpScreen(
      tester,
      const UnitPage(deckId: wordsDeck),
      state: await reviewState(
        authors: const <String>[reviewerCode],
        more: true,
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['te'],
          learningChosen: true,
        )..raterCode = reviewerCode,
      ),
    );
    expect(find.byType(ThanksNotice), findsOneWidget);
    expect(
      tester.widget<UnreviewedNotice>(find.byType(UnreviewedNotice)).entry.id,
      moreDeck,
    );
  });

  testWidgets('each row\'s button keeps its own tap for screen readers, '
      'starts with its word and names its card', (tester) async {
    useTallPhone(tester);
    final handle = tester.ensureSemantics();
    final state = await pumpScreen(
      tester,
      const ReviewPage(deckId: wordsDeck),
      state: await reviewState(reviewing: true),
    );
    final l10n = l10nOf(tester);
    Finder node(String label) => find.bySemanticsLabel(label);
    expect(
      tester.getSemantics(node(l10n.reviewCheckFor('mother'))),
      isSemantics(isButton: true, hasTapAction: true),
    );
    expect(node(l10n.reviewCheckFor('widow')), findsOneWidget);
    // A screen reader's tap marks it right.
    tester.semantics.tap(find.semantics.byLabel(l10n.reviewCheckFor('mother')));
    await tester.pumpAndSettle();
    final words = state.deckById(wordsDeck)!;
    expect(state.reviewing.reviewOf(words, words.cards.last)!.right, isTrue);
    expect(
      tester.getSemantics(node(l10n.reviewRightFor('mother'))),
      isSemantics(isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('a card in review says the word from its top line', (
    tester,
  ) async {
    useTallPhone(tester);
    final tts = FixedTtsEngine(<String>{'te'});
    await pumpScreen(
      tester,
      const ReviewPage(deckId: wordsDeck),
      state: await reviewState(reviewing: true, tts: tts),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text('mother'));
    await tester.pumpAndSettle();
    final sheet = find.byType(ReviewCardSheet);
    await tester.tap(
      find.descendant(of: sheet, matching: find.byType(SpeakerIcon)),
    );
    await tester.pumpAndSettle();
    expect(tts.spoken.single.text, 'అమ్మ');
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(
          l10n.reviewCardLine(plainCard, l10n.reviewStateNot),
        ),
      ),
      findsOneWidget,
    );
  });
}
