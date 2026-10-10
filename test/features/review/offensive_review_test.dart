import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/features/review/offensive_review_page.dart';
import 'package:fluenough/features/review/review_sheets.dart';
import 'package:fluenough/features/review/review_words.dart';
import 'package:fluenough/features/review/send_reviews_sheet.dart';
import 'package:fluenough/features/review/waiting_page.dart';

import '../../support/harness.dart';
import '../../support/review_fixture.dart';

/// A language's Offensive words review (docs/plans/deck-browser.md,
/// "Offensive words are reviewed apart, and only on purpose"; #428): why
/// the words are there, then the 18+ question, then the words, each rated
/// 1 to 9 with the region the rater speaks in.

/// A phone tall enough for every row and sheet to be built.
void useTallPhone(WidgetTester tester, {double textScale = 1.0}) {
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

Finder rowButton(String label) => find.widgetWithText(FilledButton, label);

void main() {
  test('a language\'s offensive words are its decks\' rude words, by deck; '
      'none for a language with none', () async {
    final state = await reviewState();
    final te = offensiveDecksIn(state, 'te');
    expect(te.map((d) => d.deck.id), <String>[rudeDeck]);
    expect(te.single.words.map((c) => c.id), <String>[rudeCard]);
    expect(offensiveDecksIn(state, 'bn'), isEmpty);
    expect(hasOrdinaryCards(state.deckById(rudeDeck)!), isFalse);
    expect(hasOrdinaryCards(state.deckById(wordsDeck)!), isTrue);
  });

  testWidgets('it opens on why offensive words are here, and shows no word '
      'until the reviewer has read it and said they are 18 or over', (
    tester,
  ) async {
    useTallPhone(tester);
    await pumpOffensive(tester);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reviewOffensivePageTitle('Telugu')), findsOneWidget);
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
  });

  testWidgets('it asks every time it is opened, whatever the adult content '
      'setting', (tester) async {
    useTallPhone(tester);
    final state = await reviewState(reviewing: true);
    state.settings.adultContent = true;
    await pumpOffensive(tester, state: state);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reviewOffensiveWhyTitle), findsOneWidget);
    await tester.tap(find.text(l10n.commonContinue));
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsAdultConfirmTitle), findsOneWidget);
    expectNoWord();
  });

  for (final atAge in <bool>[false, true]) {
    testWidgets('Not now ${atAge ? 'at the age question' : 'before it'} '
        'leaves without showing a word', (tester) async {
      useTallPhone(tester);
      await pumpScreen(
        tester,
        const WaitingForReviewPage(),
        state: await reviewState(
          reviewing: true,
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningLanguages: const <String>['te'],
            learningChosen: true,
          )..reviewLanguages = const <String>{'te'},
        ),
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.reviewOffensiveTitle));
      await tester.pumpAndSettle();
      expect(find.byType(OffensiveReviewPage), findsOneWidget);
      if (atAge) {
        await tester.tap(find.text(l10n.commonContinue));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(l10n.reviewOffensiveNotNow));
      await tester.pumpAndSettle();
      expect(find.byType(OffensiveReviewPage), findsNothing);
      expect(find.byType(WaitingForReviewPage), findsOneWidget);
      expectNoWord();
    });
  }

  testWidgets('a word opens whole, with its level, type, friendliness and '
      'region, and is rated 1 to 9 with the language\'s regions; the rating '
      'is kept and shown with its region', (tester) async {
    useTallPhone(tester);
    final state = await pumpOffensive(tester);
    await passGate(tester);
    final l10n = l10nOf(tester);
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
    // Nine numbers, none chosen until the rater picks one.
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
    handle.dispose();
    await tester.tap(find.text('4'));
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
    expect(
      find.text(l10n.reviewOffensiveRegion('Coastal Andhra')),
      findsOneWidget,
    );
    expect(rowButton(l10n.reviewRatedShort), findsOneWidget);
    expect(find.text(l10n.reviewOffensiveProgress(1, 1)), findsNWidgets(2));
  });

  testWidgets('Rate on a row opens the rating sheet; Elsewhere is shown as '
      'such', (tester) async {
    useTallPhone(tester);
    final state = await pumpOffensive(tester);
    await passGate(tester);
    final l10n = l10nOf(tester);
    await tester.tap(rowButton(l10n.reviewRateShort));
    await tester.pumpAndSettle();
    expect(find.byType(RateSheet), findsOneWidget);
    await tester.tap(find.text('9'));
    await tester.tap(find.text(l10n.reviewRateElsewhere));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, l10n.reviewSave));
    await tester.pumpAndSettle();
    final rude = state.deckById(rudeDeck)!;
    expect(
      state.reviewing.reviewOf(rude, rude.cards.single)!.rating!.region,
      WordRating.elsewhere,
    );
    expect(
      find.text(l10n.reviewOffensiveRegion(l10n.reviewRateElsewhere)),
      findsOneWidget,
    );
  });

  testWidgets('a language whose path lists no regions asks no region '
      'question', (tester) async {
    useTallPhone(tester);
    await pumpOffensive(
      tester,
      state: await reviewState(reviewing: true, regions: ''),
    );
    await passGate(tester);
    final l10n = l10nOf(tester);
    await tester.tap(rowButton(l10n.reviewRateShort));
    await tester.pumpAndSettle();
    expect(find.byType(RateSheet), findsOneWidget);
    expect(find.text(l10n.reviewRateWhere('Telugu')), findsNothing);
    expect(find.text(l10n.reviewRateElsewhere), findsNothing);
  });

  testWidgets('the rating sheet offers the regions the path lists, in its '
      'order, then Elsewhere', (tester) async {
    useTallPhone(tester);
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
    final chips = <String>['The north', 'The coast', l10n.reviewRateElsewhere];
    for (var i = 1; i < chips.length; i++) {
      expect(
        tester.getTopLeft(find.text(chips[i - 1])).dy,
        lessThan(tester.getTopLeft(find.text(chips[i])).dy),
      );
    }
    expect(find.text('Telangana'), findsNothing);
  });

  testWidgets('a word\'s Region row is its region note, its regions named '
      'as the path names them', (tester) async {
    useTallPhone(tester);
    await pumpOffensive(
      tester,
      state: await reviewState(
        reviewing: true,
        rudeNotes:
            '[{ kind: "usage", text: "A plain note." }, '
            '{ kind: "usage", region: ["telangana", "rayalaseema"], '
            'text: "Milder among friends here." }]',
      ),
    );
    await passGate(tester);
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
    expect(find.text(l10n.reviewRudeNotSet), findsNWidgets(3));
  });

  testWidgets('a deck of offensive words only is signed off here once every '
      'word is rated, and its ratings go in its review file, by mail', (
    tester,
  ) async {
    useTallPhone(tester);
    final share = FixedMailShare();
    final state = await pumpOffensive(
      tester,
      state: await reviewState(reviewing: true, share: share),
    );
    await passGate(tester);
    final l10n = l10nOf(tester);
    final signOff = find.widgetWithText(OutlinedButton, l10n.reviewSignOff(1));
    expect(tester.widget<OutlinedButton>(signOff).onPressed, isNull);

    final rude = state.deckById(rudeDeck)!;
    state.reviewing.rate(
      rude,
      rude.cards.single,
      const WordRating(score: 7, region: 'telangana', friendly: Friendly.no),
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
  });

  testWidgets('a language with no offensive words says so', (tester) async {
    useTallPhone(tester);
    final state = AppState.test(
      decks: MemoryDeckSource(<String, String>{
        for (final MapEntry(:key, :value) in reviewCourse().entries)
          if (!key.contains(rudeDeck)) key: value,
      }),
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['te'],
        learningChosen: true,
      ),
    );
    await pumpOffensive(tester, state: state);
    await passGate(tester);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reviewOffensiveNone('Telugu')), findsOneWidget);
  });

  group('accessibility', () {
    for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('every step lays out at twice the text size, in '
          '${themeMode.name}, with labelled buttons', (tester) async {
        useTallPhone(tester, textScale: 2);
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        await pumpOffensive(tester, themeMode: themeMode);
        final l10n = l10nOf(tester);
        final context = tester.element(find.byType(OffensiveReviewPage));
        expect(
          Theme.of(context).brightness,
          themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(tester.takeException(), isNull);
        final handle = tester.ensureSemantics();
        // The heading is announced as one.
        expect(
          tester.getSemantics(find.text(l10n.reviewOffensiveWhyTitle)),
          isSemantics(label: l10n.reviewOffensiveWhyTitle, isHeader: true),
        );
        await passGate(tester);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('idiot, good-for-nothing'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        // The Rate button names its word, and keeps its own tap.
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(
              l10n.reviewRateFor('idiot, good-for-nothing'),
            ),
          ),
          isSemantics(
            label: l10n.reviewRateFor('idiot, good-for-nothing'),
            isButton: true,
            hasTapAction: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });
}
