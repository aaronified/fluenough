import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('rude words are hidden without adult content, and count as '
      'left to check', (tester) async {
    useTallPhone(tester);
    await pumpScreen(
      tester,
      const ReviewPage(deckId: rudeDeck),
      state: await reviewState(reviewing: true),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reviewRudeHidden(1)), findsOneWidget);
    expect(find.text('idiot, good-for-nothing'), findsNothing);
    expect(find.text(l10n.reviewSignOff(1)), findsOneWidget);
  });

  testWidgets('a rude word shows its level, type, friendliness and region, '
      'and is rated 1 to 9 with the language\'s regions', (tester) async {
    useTallPhone(tester);
    final state = await pumpScreen(
      tester,
      const ReviewPage(deckId: rudeDeck, adult: true),
      state: await reviewState(reviewing: true),
    );
    final l10n = l10nOf(tester);
    // Rated, not marked right.
    expect(rowButton(l10n.reviewRateShort), findsOneWidget);
    expect(rowButton(l10n.reviewCheck), findsNothing);
    await tester.tap(find.text('idiot, good-for-nothing'));
    await tester.pumpAndSettle();
    for (final row in <String>[
      l10n.reviewRudeLevel,
      l10n.reviewRudeType,
      l10n.reviewRudeFriends,
      l10n.reviewRudeRegion,
    ]) {
      expect(find.text(row), findsOneWidget);
    }
    expect(find.text(l10n.reviewRudeNotSet), findsNWidgets(4));
    expect(find.text(l10n.reviewLooksRight), findsNothing);
    await tester.tap(find.text(l10n.reviewRate));
    await tester.pumpAndSettle();
    expect(find.byType(RateSheet), findsOneWidget);
    expect(find.text(l10n.reviewRateQuestion), findsOneWidget);
    expect(find.text(l10n.reviewRateWhere('Telugu')), findsOneWidget);
    for (final region in <String>[
      'Telangana',
      'Coastal Andhra',
      'Rayalaseema',
      l10n.reviewRateElsewhere,
    ]) {
      expect(find.text(region), findsOneWidget);
    }
    final save = find.widgetWithText(FilledButton, l10n.reviewSave);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    // Nine numbers, none chosen until the rater picks one: no score is
    // given before then, 5 no more than any other.
    expect(find.byType(Slider), findsNothing);
    final handle = tester.ensureSemantics();
    for (var n = 1; n <= 9; n++) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(l10n.reviewRateScore(n))),
        isSemantics(
          label: l10n.reviewRateScore(n),
          isButton: true,
          hasCheckedState: true,
          isChecked: false,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
        reason: '$n',
      );
    }
    expect(find.text(l10n.reviewRateLow), findsOneWidget);
    expect(find.text(l10n.reviewRateHigh), findsOneWidget);
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel(l10n.reviewRateScore(4))),
      isSemantics(
        label: l10n.reviewRateScore(4),
        isButton: true,
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
    await tester.tap(find.text('Coastal Andhra'));
    await tester.tap(find.text(l10n.reviewFriendlySometimes));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final rude = state.deckById(rudeDeck)!;
    final rating = state.reviewing.reviewOf(rude, rude.cards.single)!.rating!;
    expect(rating.score, 4);
    expect(rating.region, 'coastal-andhra');
    expect(rating.friendly, Friendly.sometimes);
    expect(find.text(l10n.reviewRated(4)), findsOneWidget);
    expect(rowButton(l10n.reviewRatedShort), findsOneWidget);
    expect(find.text(l10n.reviewSignOffReady), findsOneWidget);
  });

  Future<void> openRating(WidgetTester tester, String regions) async {
    await pumpScreen(
      tester,
      const ReviewPage(deckId: rudeDeck, adult: true),
      state: await reviewState(reviewing: true, regions: regions),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text('idiot, good-for-nothing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.reviewRate));
    await tester.pumpAndSettle();
  }

  testWidgets('the rating sheet offers the regions the language\'s path '
      'lists, in its order, then Elsewhere', (tester) async {
    useTallPhone(tester);
    await openRating(tester, '''
  - { id: "north", name: { "en": "The north", "te": "ఉత్తరం" } }
  - { id: "coastal-andhra", name: { "en": "The coast" } }''');
    final l10n = l10nOf(tester);
    final chips = <String>['The north', 'The coast', l10n.reviewRateElsewhere];
    for (final chip in chips) {
      expect(find.text(chip), findsOneWidget);
    }
    for (var i = 1; i < chips.length; i++) {
      expect(
        tester.getTopLeft(find.text(chips[i - 1])).dy,
        lessThan(tester.getTopLeft(find.text(chips[i])).dy),
      );
    }
    // Nothing of the fixed list there was before the paths had regions.
    expect(find.text('Telangana'), findsNothing);
    expect(find.text('Rayalaseema'), findsNothing);
  });

  testWidgets('a language whose path lists no regions asks no region '
      'question', (tester) async {
    useTallPhone(tester);
    await openRating(tester, '');
    final l10n = l10nOf(tester);
    expect(find.byType(RateSheet), findsOneWidget);
    expect(find.text(l10n.reviewRateWhere('Telugu')), findsNothing);
    expect(find.text(l10n.reviewRateElsewhere), findsNothing);
  });

  testWidgets('a rude word\'s Region row is its region note, its regions '
      'named as the path names them', (tester) async {
    useTallPhone(tester);
    await pumpScreen(
      tester,
      const ReviewPage(deckId: rudeDeck, adult: true),
      state: await reviewState(
        reviewing: true,
        rudeNotes:
            '[{ kind: "usage", text: "A plain note." }, '
            '{ kind: "usage", region: ["telangana", "rayalaseema"], '
            'text: "Milder among friends here." }]',
      ),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text('idiot, good-for-nothing'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        l10n.reviewRudeRegionNote(
          l10n.pathMetaJoin('Telangana', 'Rayalaseema'),
          'Milder among friends here.',
        ),
      ),
      findsOneWidget,
    );
    // Level, type and friendliness are still not set; the region is.
    expect(find.text(l10n.reviewRudeNotSet), findsNWidgets(3));
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
