import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/review/review_page.dart';
import 'package:fluenough/features/review/review_waiting.dart';
import 'package:fluenough/features/review/send_reviews_sheet.dart';
import 'package:fluenough/features/review/waiting_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';

import '../../support/harness.dart';
import '../../support/review_fixture.dart';

/// What is waiting for review, in the reviewer's languages
/// (docs/plans/deck-browser.md): the languages they review, what waits in
/// each, the page in Settings and the path's "To review" marks.

/// A reviewer who speaks [spoken], with reviewing on.
Future<AppState> reviewer({
  List<String> spoken = const <String>['en'],
  Set<String>? languages,
  bool more = false,
}) async {
  final state = await reviewState(
    reviewing: true,
    more: more,
    share: FixedMailShare(),
    settings: SettingsNotifier(
      spokenLanguages: spoken,
      learningLanguages: const <String>['te'],
      learningChosen: true,
    )..reviewLanguages = languages,
  );
  return state;
}

/// A phone tall enough for Settings' lazy list to build every group.
void useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
}

void main() {
  group('the languages a reviewer reviews', () {
    test('before they choose, the languages they speak that the app '
        'teaches; then what they chose, even none', () async {
      expect(reviewLanguagesOf(await reviewer()), isEmpty);
      final state = await reviewer(spoken: const <String>['en', 'te', 'fr']);
      expect(reviewLanguagesOf(state).map((l) => l.code), <String>['te']);
      state.settings.reviewLanguages = const <String>{};
      expect(reviewLanguagesOf(state), isEmpty);
      state.settings.reviewLanguages = const <String>{'te', 'xx'};
      expect(reviewLanguagesOf(state).map((l) => l.code), <String>['te']);
    });

    test('kept with the settings: not chosen, chosen, and chosen none', () {
      for (final chosen in <Set<String>?>[
        null,
        const <String>{'te', 'bn'},
        const <String>{},
      ]) {
        final stored = (SettingsNotifier()..reviewLanguages = chosen)
            .toStored();
        final back = SettingsNotifier(spokenLanguages: const <String>['en'])
          ..reviewLanguages = const <String>{'hi'};
        back.restore(stored);
        expect(back.reviewLanguages, chosen, reason: '$chosen');
      }
    });
  });

  group('what waits in a language', () {
    test('at first: each unit and deck not signed off with every card '
        'left, the rude word unrated, the pair unconfirmed, nothing '
        'unsent', () async {
      final state = await reviewer();
      final te = state.deckById(wordsDeck)!.language;
      final waiting = waitingIn(state, te, adult: true);
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
      expect(waiting.unsent, isEmpty);
      expect(waiting.isEmpty, isFalse);
    });

    test('as the reviewer checks: fewer cards left, the word rated, the '
        'pair confirmed, and what they did waits to send', () async {
      final state = await reviewer();
      final words = state.deckById(wordsDeck)!;
      final rude = state.deckById(rudeDeck)!;
      final reviewing = state.reviewing;
      reviewing.markRight(words, words.cards.last);
      reviewing.rate(rude, rude.cards.single, const WordRating(score: 6));
      reviewing.checkAlike(
        words,
        words.cards.first,
        const AlikeCheck(partner: rudeCard, kind: AlikeKind.sound, real: true),
      );
      final waiting = waitingIn(state, words.language, adult: true);
      expect(waiting.units.single.decks.single.left, 1);
      expect(waiting.unrated, isEmpty);
      expect(waiting.offensive, 1);
      expect(waiting.unconfirmed, isEmpty);
      expect(waiting.unsent.map((d) => d.deckId).toSet(), {
        wordsDeck,
        rudeDeck,
      });
    });

    test('without adult content, a pair the reviewer cannot confirm does '
        'not wait, as its deck\'s cards left say', () async {
      final state = await reviewer();
      final words = state.deckById(wordsDeck)!;
      for (final card in words.cards) {
        state.reviewing.markRight(words, card);
      }
      final hidden = waitingIn(state, words.language, adult: false);
      expect(hidden.units.first.decks.single.left, 0);
      expect(hidden.unconfirmed, isEmpty);
      final shown = waitingIn(state, words.language, adult: true);
      expect(shown.units.first.decks.single.left, 1);
      expect(shown.unconfirmed.map((c) => c.card.id), [alikeCard]);
    });

    test('offensive words are never among a unit\'s cards left, adult '
        'content on or off: they wait to be rated, apart', () async {
      final state = await reviewer();
      final rude = state.deckById(rudeDeck)!;
      for (final adult in <bool>[false, true]) {
        final waiting = waitingIn(state, rude.language, adult: adult);
        expect(
          waiting.allDecks.map((d) => d.deck.id),
          isNot(contains(rudeDeck)),
        );
        expect(waiting.unrated.map((c) => c.card.id), [rudeCard]);
      }
      state.reviewing.rate(rude, rude.cards.single, const WordRating(score: 6));
      expect(waitingIn(state, rude.language, adult: false).unrated, isEmpty);
    });

    test('a deck with offensive and ordinary words counts only the '
        'ordinary ones as its cards left', () async {
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
      final waiting = waitingIn(
        state,
        state.deckById(wordsDeck)!.language,
        adult: true,
      );
      // A deck the path leaves out comes after its units.
      final mixed = waiting.units.last.decks.single;
      expect(mixed.deck.id, 'te-en-review-mixed');
      expect((mixed.left, mixed.total), (1, 1));
      expect(waiting.unrated.map((c) => c.card.id), <String>[
        rudeCard,
        'te-9952',
      ]);
      expect(waiting.offensive, 2);
    });

    test('a deck signed off on the phone, or whose file no longer says '
        'unreviewed, waits no more; once sent, nothing does', () async {
      final state = await reviewer();
      final words = state.deckById(wordsDeck)!;
      final rude = state.deckById(rudeDeck)!;
      final reviewing = state.reviewing;
      for (final card in words.cards) {
        reviewing.markRight(words, card);
      }
      reviewing.signOff(words);
      var waiting = waitingIn(state, words.language, adult: false);
      expect(waiting.units, isEmpty);
      expect(waiting.unrated.map((c) => c.card.id), [rudeCard]);
      expect(awaitsReview(state, words), isFalse);
      expect(awaitsReview(state, rude), isTrue);

      reviewing.signOff(rude);
      await reviewing.send(reviewing.unsent, body: '');
      waiting = waitingIn(state, words.language, adult: false);
      expect(waiting.isEmpty, isTrue);

      // A deck a native speaker has checked carries no unreviewed tag.
      final checked = AppState.test(
        decks: MemoryDeckSource(<String, String>{
          for (final MapEntry(:key, :value) in reviewCourse().entries)
            key: value.replaceAll('tags: [unreviewed]', 'tags: []'),
        }),
      );
      await checked.load();
      expect(awaitsReview(checked, checked.deckById(wordsDeck)!), isFalse);
    });

    test(
      'a deck outside the reviewer\'s course is listed on its own',
      () async {
        final state = AppState.test(
          decks: MemoryDeckSource(<String, String>{
            ...reviewCourse(),
            'decks/te/te-bn-review-words.yaml': '''
schema: 1
id: te-bn-review-words
name: "পরিবারের শব্দ"
language: { code: te, iso639_3: tel, name: Telugu, script: telugu }
native: { code: bn, iso639_3: ben, name: Bengali }
license: CC0-1.0
tags: [unreviewed]
cards:
  - { id: te-9904, target: "అక్క", native: "দিদি", reading: "akka" }
''',
          }),
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningLanguages: const <String>['te'],
            learningChosen: true,
          ),
        );
        await state.load();
        final waiting = waitingIn(
          state,
          state.deckById(wordsDeck)!.language,
          adult: false,
        );
        expect(waiting.decks.map((d) => (d.deck.id, d.left)), [
          ('te-bn-review-words', 1),
        ]);
      },
    );
  });

  group('the Waiting for review page', () {
    testWidgets('per language: each unit and its cards left, the words to '
        'rate and the pairs to confirm, counted, never named', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const WaitingForReviewPage(adult: true),
        state: await reviewer(languages: const <String>{'te'}, more: true),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewSettingsWaiting), findsOneWidget);
      expect(find.text('Telugu'), findsOneWidget);
      expect(
        find.text(l10n.reviewWaitingUnit(1, 'Family words')),
        findsOneWidget,
      );
      // Two decks in the unit: each with its own cards left.
      expect(
        find.text(
          '${l10n.reviewWaitingDeckCards('Family words', 2)}\n'
          '${l10n.reviewWaitingDeckCards('More family words', 1)}',
        ),
        findsOneWidget,
      );
      // The offensive words: never a unit to review, but a row of their
      // own, opened on purpose.
      expect(find.text(l10n.reviewWaitingUnit(2, 'Rude words')), findsNothing);
      expect(find.text(l10n.reviewOffensiveTitle), findsOneWidget);
      expect(find.text(l10n.reviewWaitingUnrated(1)), findsOneWidget);
      expect(find.text(l10n.reviewWaitingUnconfirmed(1)), findsOneWidget);
      expect(find.textContaining('వెధవ'), findsNothing);
      expect(find.textContaining('idiot'), findsNothing);
      expect(find.text(l10n.reviewWaitingUnsent(1)), findsNothing);
    });

    testWidgets('a unit opens its review; what waits to send opens the send '
        'sheet', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        const WaitingForReviewPage(),
        state: await reviewer(languages: const <String>{'te'}),
      );
      final l10n = l10nOf(tester);
      final words = state.deckById(wordsDeck)!;
      state.reviewing.markRight(words, words.cards.last);
      await tester.pumpAndSettle();
      expect(find.text(l10n.reviewWaitingUnsent(1)), findsOneWidget);
      await tester.tap(find.text(l10n.reviewWaitingUnsent(1)));
      await tester.pumpAndSettle();
      expect(find.byType(SendReviewsSheet), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.reviewWaitingUnit(1, 'Family words')));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewPage), findsOneWidget);
      expect(find.text(l10n.reviewPageTitle('Family words')), findsOneWidget);
    });

    testWidgets('with everything signed off and sent: nothing waits', (
      tester,
    ) async {
      usePhone(tester);
      final state = await reviewer(languages: const <String>{'te'});
      for (final id in <String>[wordsDeck, rudeDeck]) {
        state.reviewing.signOff(state.deckById(id)!);
      }
      await state.reviewing.send(state.reviewing.unsent, body: '');
      await pumpScreen(tester, const WaitingForReviewPage(), state: state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewWaitingNothing('Telugu')), findsOneWidget);
      expect(find.text(l10n.reviewWaitingUnrated(1)), findsNothing);
      // The language's offensive words can still be opened, on purpose.
      expect(find.text(l10n.reviewOffensiveTitle), findsOneWidget);
      expect(find.text(l10n.reviewOffensiveNoneWaiting), findsOneWidget);
    });

    testWidgets('with no language reviewed, it asks for them, and shows '
        'what waits once chosen', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        const WaitingForReviewPage(),
        state: await reviewer(),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewWaitingNoLanguages), findsOneWidget);
      await tester.tap(find.text(l10n.reviewWaitingChoose));
      await tester.pumpAndSettle();
      expect(find.text(l10n.reviewLanguagesBody), findsOneWidget);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Telugu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reviewSave));
      await tester.pumpAndSettle();
      expect(state.settings.reviewLanguages, <String>{'te'});
      expect(
        find.text(l10n.reviewWaitingUnit(1, 'Family words')),
        findsOneWidget,
      );
    });
  });

  group('Settings, under Review decks', () {
    testWidgets('with reviewing on: the languages reviewed, and how many '
        'decks wait, which opens the page', (tester) async {
      useTallPhone(tester);
      await pumpScreen(
        tester,
        const SettingsPage(),
        state: await reviewer(spoken: const <String>['te', 'en']),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewSettingsLanguages), findsOneWidget);
      expect(find.text('Telugu'), findsWidgets);
      // The deck of offensive words only is not counted: it is reviewed
      // apart, on purpose.
      expect(find.text(l10n.reviewSettingsWaitingDesc(1)), findsOneWidget);
      await tester.tap(find.text(l10n.reviewSettingsWaiting));
      await tester.pumpAndSettle();
      expect(find.byType(WaitingForReviewPage), findsOneWidget);
    });

    testWidgets('choosing no language says so', (tester) async {
      useTallPhone(tester);
      final state = await pumpScreen(
        tester,
        const SettingsPage(),
        state: await reviewer(spoken: const <String>['te', 'en']),
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.reviewSettingsLanguages));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Telugu'));
      await tester.tap(find.text(l10n.reviewSave));
      await tester.pumpAndSettle();
      expect(state.settings.reviewLanguages, isEmpty);
      expect(find.text(l10n.reviewSettingsLanguagesNone), findsOneWidget);
      expect(find.text(l10n.reviewSettingsWaitingDesc(0)), findsOneWidget);
    });

    testWidgets('with reviewing off, neither row shows', (tester) async {
      useTallPhone(tester);
      await pumpScreen(
        tester,
        const SettingsPage(),
        state: await reviewState(),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewSettingsLanguages), findsNothing);
      expect(find.text(l10n.reviewSettingsWaiting), findsNothing);
    });
  });

  group('the path\'s "To review" marks', () {
    Finder marked(WidgetTester tester, String title) => find.bySemanticsLabel(
      RegExp('^$title, .*${l10nOf(tester).pathToReview}\$'),
    );

    testWidgets('each unit with a deck waiting is marked, in a language '
        'reviewed, with reviewing on', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        const DecksPage(),
        state: await reviewer(languages: const <String>{'te'}),
      );
      final l10n = l10nOf(tester);
      final handle = tester.ensureSemantics();
      expect(find.text(l10n.pathToReview), findsOneWidget);
      expect(marked(tester, 'Family words'), findsOneWidget);
      // A unit of offensive words only is never marked: they are reviewed
      // only on purpose.
      expect(marked(tester, 'Rude words'), findsNothing);

      // Signed off, the unit's mark goes.
      final words = state.deckById(wordsDeck)!;
      state.reviewing.signOff(words);
      await tester.pumpAndSettle();
      expect(find.text(l10n.pathToReview), findsNothing);
      expect(marked(tester, 'Family words'), findsNothing);

      // Off, or a language not reviewed: no mark.
      state.settings.reviews = const Reviews();
      await tester.pumpAndSettle();
      expect(find.text(l10n.pathToReview), findsOneWidget);
      state.settings.reviewLanguages = const <String>{};
      await tester.pumpAndSettle();
      expect(find.text(l10n.pathToReview), findsNothing);
      state.settings.reviewLanguages = const <String>{'te'};
      state.reviewing.turnOff();
      await tester.pumpAndSettle();
      expect(find.text(l10n.pathToReview), findsNothing);
      handle.dispose();
    });
  });
}
