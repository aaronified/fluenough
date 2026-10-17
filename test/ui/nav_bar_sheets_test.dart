import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/card_set.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/updates/release_check.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/features/downloads/update_escape.dart';
import 'package:fluenough/features/drill/cant_now.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/reading_fixture.dart';
import 'package:fluenough/features/drill/set_drill.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/features/placement/gallery_entries.dart';
import 'package:fluenough/features/profiles/spoken_languages_picker.dart';
import 'package:fluenough/features/review/review_sheets.dart';
import 'package:fluenough/features/review/review_words.dart';
import 'package:fluenough/features/review/send_reviews_sheet.dart';
import 'package:fluenough/features/settings/adjust_section.dart';
import 'package:fluenough/features/settings/speech_test_sheet.dart';
import 'package:fluenough/ui/theme.dart';
import 'package:fluenough/ui/widgets/report_button.dart';

import '../support/harness.dart';
import '../support/nav_bar_walk.dart';
import '../support/picker.dart';
import '../support/review_fixture.dart';

/// Every bottom sheet the app opens, on a phone with the three-button bar
/// (#501): at 1x, and with the phone at 2x, which the app draws at its
/// 1.4x cap (#505). Scrolled to its end, no sheet leaves text or a control
/// under the bar (owner, 2026-10-13, on #504: "Add the tests in this PR").
///
/// One test a sheet and a scale. A new `showModalBottomSheet` in lib/
/// belongs here too.

/// Pumps a bare screen on [state] and opens a sheet from it with [open].
Future<void> openOn(
  WidgetTester tester,
  AppState state,
  Future<void> Function(BuildContext context) open,
) async {
  await pumpScreen(
    tester,
    const Scaffold(body: SizedBox.expand()),
    state: state,
  );
  unawaited(open(tester.element(find.byType(SizedBox).last)));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

Card cardOf(AppState state, String deck, String id) =>
    state.deckById(deck)!.cards.firstWhere((c) => c.id == id);

/// Each sheet, and how to open it.
final Map<String, Future<void> Function(WidgetTester tester)>
sheets = <String, Future<void> Function(WidgetTester tester)>{
  'report_button: report on GitHub': (tester) => openOn(
    tester,
    AppState.test(
      features: FeatureRegistry.only(
        Feature.available.difference(<Feature>{Feature.feedbackMail}),
      ),
    ),
    (context) => ReportButton.open(context),
  ),
  'update_escape: check for updates': (tester) => openOn(
    tester,
    AppState.test(releases: FixedReleaseCheck(const LatestRelease('99.0.0'))),
    showUpdateSheet,
  ),
  'review_sheets: a card under review': (tester) async {
    final state = await reviewState(reviewing: true);
    await openOn(
      tester,
      state,
      (context) => showReviewCard(
        context,
        deck: state.deckById(wordsDeck)!,
        card: cardOf(state, wordsDeck, plainCard),
      ),
    );
  },
  'review_sheets: a rude word under review': (tester) async {
    final state = await reviewState(reviewing: true);
    await openOn(
      tester,
      state,
      (context) => showReviewCard(
        context,
        deck: state.deckById(rudeDeck)!,
        card: cardOf(state, rudeDeck, rudeCard),
      ),
    );
  },
  'review_sheets: a word like a rude one, offensive review': (tester) async {
    final state = await reviewState(reviewing: true);
    await openOn(
      tester,
      state,
      (context) => showReviewCard(
        context,
        deck: state.deckById(wordsDeck)!,
        card: cardOf(state, wordsDeck, alikeCard),
        offensive: true,
      ),
    );
  },
  'review_sheets: Suggest a change': (tester) async {
    final state = await reviewState(reviewing: true);
    await openOn(
      tester,
      state,
      (context) => showSuggestSheet(
        context,
        deck: state.deckById(wordsDeck)!,
        card: cardOf(state, wordsDeck, plainCard),
      ),
    );
  },
  'review_sheets: Rate this word': (tester) async {
    final state = await reviewState(reviewing: true);
    await openOn(
      tester,
      state,
      (context) => showRateSheet(
        context,
        deck: state.deckById(rudeDeck)!,
        card: cardOf(state, rudeDeck, rudeCard),
      ),
    );
  },
  'review_sheets: the pair check': (tester) async {
    final state = await reviewState(reviewing: true);
    final card = cardOf(state, wordsDeck, alikeCard);
    await openOn(
      tester,
      state,
      (context) => showAlikeSheet(
        context,
        deck: state.deckById(wordsDeck)!,
        card: card,
        pair: rudeAlikesOf(state, card).first,
      ),
    );
  },
  'send_reviews_sheet': (tester) async {
    final state = await reviewState(reviewing: true);
    final words = state.deckById(wordsDeck)!;
    final rude = state.deckById(rudeDeck)!;
    state.reviewing.markRight(words, words.cards.first);
    state.reviewing.markRight(rude, rude.cards.first);
    await openOn(tester, state, showSendReviews);
  },
  'reading_drill: Words': (tester) async {
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.untaught(
          readingFixtureDeckId,
          skill: Skill.reading,
        ),
        preset: const DrillPreset(target: 'সে কাজ ক’রে বাড়ি যায়।'),
      ),
      state: AppState.test(
        decks: readingFixtureDecks(),
        tts: FixedTtsEngine(<String>{'bn'}),
        now: DateTime(2026, 9, 28, 12),
      ),
    );
    await tapText(tester, l10nOf(tester).readingWords);
  },
  'cant_now: Can\'t listen now': (tester) async {
    final state = AppState.test(
      tts: FixedTtsEngine(<String>{'hi'}),
      speech: FixedSpeechEngine(onDevice: <String>{'hi'}, granted: true),
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
        enabledSkills: Skill.values.toSet(),
      ),
      now: DateTime(2026, 9, 28, 12),
    );
    await state.load();
    final session = DrillSession(
      state: state,
      items: state
          .buildSession(
            DrillRequest.untaught(
              'hi-en-script-vowels',
              skill: Skill.listening,
            ),
          )
          .items
          .take(2)
          .toList(),
    );
    addTearDown(session.dispose);
    await pumpScreen(
      tester,
      Scaffold(
        body: Center(child: CantNowButton(session: session)),
      ),
      state: state,
    );
    await tapText(tester, l10nOf(tester).drillCantListen);
  },
  'word_sheet': (tester) async {
    final state = await reviewState();
    await openOn(
      tester,
      state,
      (context) => showWordSheet(
        context,
        card: cardOf(state, wordsDeck, plainCard),
        language: state.deckById(wordsDeck)!.language,
      ),
    );
  },
  'speech_test_sheet': (tester) async {
    final state = AppState.test();
    await state.load();
    await openOn(
      tester,
      state,
      (context) => showSpeechTest(
        context,
        state.languages.firstWhere((l) => l.code == 'hi'),
      ),
    );
  },
  'adjust_section: Adjusted to you': (tester) async {
    final state = AppState.test();
    await state.load();
    const none = (days: 0, reviews: 0);
    await openOn(
      tester,
      state,
      (context) => showAdjustedSheet(context, state, [
        for (final language in <String>['hi', 'bn'])
          for (final mode in DrillMode.values)
            (
              key: (language: language, mode: mode),
              fitted: null,
              before: none,
              after: none,
            ),
      ]),
    );
  },
  'set_drill: the Full list': (tester) async {
    final state = AppState.test();
    await state.load();
    const telugu = LanguageInfo(
      code: 'te',
      iso639_3: 'tel',
      name: 'Telugu',
      script: 'telugu',
    );
    final forms = <Card>[
      for (var i = 0; i < 9; i++)
        Card(
          id: 'te-$i',
          deckId: 'te-en-x',
          target: 'తాగుతాను$i',
          reading: 'tāgutānu$i',
          native: 'form $i',
        ),
    ];
    await openOn(
      tester,
      state,
      (context) => showSetList(
        context,
        sets: <ResolvedSet>[
          ResolvedSet(
            set: const CardSet(
              id: 'te-9',
              deckId: 'te-en-x',
              name: 'తాగు (tāgu), drink: every person',
              explanation: '',
            ),
            members: forms,
          ),
        ],
        language: telugu,
        isKnown: (card) => card.id == 'te-0',
      ),
    );
  },
  'language_card: taught from four': (tester) async {
    final app = AppState.test();
    await app.load();
    final entry = placementGalleryEntries.firstWhere(
      (e) => e.id == 'picker-taught-from-list',
    );
    await pumpScreen(
      tester,
      GalleryPreview(key: UniqueKey(), entry: entry),
      state: app,
    );
    final change = find.descendant(
      of: languageCard('te'),
      matching: find.text(l10nOf(tester).pickerChangeNative),
    );
    await scrollToInPicker(tester, change);
    await tester.tap(change);
    await tester.pumpAndSettle();
  },
  'spoken_languages_picker: a language I know': (tester) async {
    final state = AppState.test();
    await state.load();
    const bengali = SpokenLanguage(
      code: 'bn',
      iso639_3: 'ben',
      name: 'Bengali',
      ownName: 'বাংলা',
      scripts: <String>['bengali'],
      family: 'indo_aryan',
      scriptQuestion: 'আপনি কি বাংলা লিপি পড়তে পারেন?',
      scriptCanRead: 'আমি বাংলা লিপি পড়তে পারি',
    );
    // As the picker opens it.
    await openOn(
      tester,
      state,
      (context) => showModalBottomSheet<KnownReply>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const KnownLanguageSheet(
          language: bengali,
          current: <String>['bengali'],
          chosen: true,
        ),
      ),
    );
  },
  'spoken_languages_picker: a language in several scripts (#551)':
      (tester) async {
        final state = AppState.test();
        await state.load();
        const punjabi = SpokenLanguage(
          code: 'pa',
          iso639_3: 'pan',
          name: 'Punjabi',
          ownName: 'ਪੰਜਾਬੀ',
          scripts: <String>['gurmukhi', 'shahmukhi'],
          family: 'indo_aryan',
        );
        await openOn(
          tester,
          state,
          (context) => showModalBottomSheet<KnownReply>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => const KnownLanguageSheet(
              language: punjabi,
              current: <String>['gurmukhi'],
              chosen: true,
            ),
          ),
        );
      },
};

void main() {
  test('every sheet the app opens is covered here', () {
    // Where lib/ calls showModalBottomSheet, by file, as [sheets] covers it.
    final sites = <String, int>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final count = 'showModalBottomSheet<'
          .allMatches(file.readAsStringSync())
          .length;
      if (count > 0) {
        sites[file.uri.pathSegments.last.replaceAll('.dart', '')] = count;
      }
    }
    expect(sites, <String, int>{
      'report_button': 1,
      'update_escape': 1,
      'review_sheets': 4,
      'send_reviews_sheet': 1,
      'reading_drill': 1,
      'cant_now': 1,
      'word_sheet': 1,
      'speech_test_sheet': 1,
      'adjust_section': 1,
      'language_card': 1,
      'set_drill': 1,
      'spoken_languages_picker': 1,
    }, reason: 'a new sheet belongs in [sheets]');
  });

  for (final scale in <double>[1.0, 2.0]) {
    for (final MapEntry(key: name, value: open) in sheets.entries) {
      testWidgets('$name, phone text at ${scale}x: nothing under the bar', (
        tester,
      ) async {
        usePhone(tester, navBar: true, textScale: scale);
        await open(tester);
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget, reason: 'the sheet opened');
        expect(
          MediaQuery.textScalerOf(tester.element(sheet)).scale(1),
          closeTo(math.min(scale, AppSizes.maxTextScale), 0.001),
        );
        // Overflows at large text are the accessibility tests' to catch.
        tester.takeException();
        expect(await underBarAtEnd(tester, within: sheet), isEmpty);
      });
    }
  }
}
