import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/rater_code.dart';
import 'package:fluenough/core/review/review_file.dart';
import 'package:fluenough/features/review/review_sheets.dart';
import 'package:fluenough/features/review/suggest_bases.dart';

import '../../support/harness.dart';
import '../../support/review_fixture.dart';

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
Future<AppState> openSheet(
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

List<Suggestion> savedOn(AppState state) {
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

void main() {
  testWidgets('delete strikes a base through until the tick, Undo brings it '
      'back, and saved it is a removal with its why', (tester) async {
    final state = await openSheet(tester);
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
    expect(savedOn(state), isEmpty);
    await tap(tester, find.text(l10n.commonUndo));
    expect(find.text(l10n.reviewBaseRemoved), findsNothing);
    expect(delete, findsOneWidget);

    await tap(tester, delete);
    await type(tester, SuggestSheet.baseKey('అమ్మ', 'why'), 'Its own root');
    await save(tester);
    final removal = savedOn(state).single;
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
    final again = await openSheet(tester, saved: savedOn(state));
    expect(find.text(l10n.reviewBaseRemoved), findsOneWidget);
    await tap(tester, find.text(l10n.commonUndo));
    await save(tester);
    expect(savedOn(again), isEmpty);
  });

  testWidgets('Add a base offers the words of the card that have none, and a '
      'form that is another card\'s word links it, unless unticked', (
    tester,
  ) async {
    final state = await openSheet(tester, bases: null);
    final l10n = l10nOf(tester);
    await tap(tester, find.byKey(SuggestSheet.addBaseKey));
    expect(find.text(l10n.reviewBaseNew.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.reviewBaseWhich), findsOneWidget);
    // The card's one word, chosen, and the form started from it.
    final chip = tester.widget<FilterChip>(
      find.byKey(SuggestSheet.chipKey(0, 'అమ్మ')),
    );
    expect(chip.selected, isTrue);
    String text(String f) => tester
        .widget<TextField>(find.byKey(SuggestSheet.newBaseKey(0, f)))
        .controller!
        .text;
    expect(text('form'), 'అమ్మ');
    // Its one word taken, Add a base is gone.
    expect(find.byKey(SuggestSheet.addBaseKey), findsNothing);
    // Not another card's word: no link.
    expect(find.byKey(SuggestSheet.newBaseKey(0, 'link')), findsNothing);

    await type(tester, SuggestSheet.newBaseKey(0, 'form'), 'విధవ');
    final link = SuggestSheet.newBaseKey(0, 'link');
    expect(ticked(tester, link), isTrue);
    expect(
      find.text(l10n.reviewBaseLink('విధవ', 'vidhava', 'widow', alikeCard)),
      findsOneWidget,
    );
    await type(tester, SuggestSheet.newBaseKey(0, 'why'), 'It had none');
    await save(tester);
    var added = savedOn(state).single;
    expect(added.action, BaseAction.add);
    expect(added.word, 'అమ్మ');
    expect(added.base, const BaseForm(ref: alikeCard));
    expect(added.why, 'It had none');

    // Opened again, the new base is there to change: unticked, it is
    // written in full, and says it was not linked.
    final again = await openSheet(tester, bases: null, saved: savedOn(state));
    expect(text('form'), 'విధవ');
    expect(ticked(tester, link), isTrue);
    await tap(tester, find.byKey(link));
    await save(tester);
    added = savedOn(again).single;
    expect(
      added.base,
      const BaseForm(
        base: 'విధవ',
        reading: 'vidhava',
        meaning: 'widow',
        link: false,
      ),
    );
  });

  testWidgets('a new word shows what hung on the old one, Replace the bases '
      'removes them and opens a base for the new word, and the old word is '
      'kept as also heard, all saved as one review', (tester) async {
    final state = await openSheet(tester);
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

    final saved = savedOn(state);
    expect(
      <CardPart>[for (final s in saved) s.part],
      <CardPart>[CardPart.word, CardPart.alt, CardPart.base, CardPart.base],
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
    final again = await openSheet(tester, saved: saved);
    expect(find.byType(IdentityPanel), findsNothing);
    expect(find.text(l10n.reviewPartAlt.toUpperCase()), findsOneWidget);
    expect(ticked(tester, SuggestSheet.keepAltKey), isTrue);
    await tap(tester, find.byKey(SuggestSheet.keepAltKey));
    await save(tester);
    expect(savedOn(again).map((s) => s.part), isNot(contains(CardPart.alt)));
    expect(savedOn(again), hasLength(3));
  });

  testWidgets('unticked in the panel, the old word is not kept', (
    tester,
  ) async {
    final state = await openSheet(tester);
    await newWord(tester);
    await tap(tester, find.byKey(IdentityPanel.keepAltKey));
    expect(ticked(tester, IdentityPanel.keepAltKey), isFalse);
    await save(tester);
    expect(
      <CardPart>[for (final s in savedOn(state)) s.part],
      <CardPart>[CardPart.word],
    );
  });

  group('accessibility', () {
    for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      for (final scale in <double>[1.0, 1.4]) {
        testWidgets('the base boxes, a new base and the new word\'s panel lay '
            'out at ${scale}x in ${themeMode.name}, with labelled 48 dp '
            'targets and readable text', (tester) async {
          await openSheet(tester, textScale: scale, themeMode: themeMode);
          final context = tester.element(find.byType(SuggestSheet));
          expect(
            Theme.of(context).brightness,
            themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
          );
          final handle = tester.ensureSemantics();
          final l10n = l10nOf(tester);
          await tap(
            tester,
            find.byTooltip(
              l10n.reviewSuggestEditPart(l10n.reviewPartBaseOf('అమ్మ')),
            ),
          );
          expect(tester.takeException(), isNull);
          await newWord(tester);
          await tap(tester, find.byKey(IdentityPanel.replaceKey));
          expect(tester.takeException(), isNull);
          // The panel is announced by its title.
          expect(
            find.bySemanticsLabel(RegExp('^${l10n.reviewIdentityTitle}')),
            findsWidgets,
          );
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    }
  });
}
