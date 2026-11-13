// Culture in the course (wiki/Plan-Deck-Kinds-And-Topics.md, T20, the approved
// mockup docs/mockups/culture-in-course.html, default variants): a culture item
// woven into a path unit and offered on Today at the learner's level; its page
// with the text, meaning, gloss, source line, creator chip and legacy line; the
// creator card with the picture's credit or its placeholder, the bio at the
// learner's level, "Still alive today" and the timeline strip; the full
// timeline to today; the full culture deck with its people; the culture
// settings; and an item above the level, not shown or shown with support.

import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/culture/creator_sheet.dart';
import 'package:fluenough/features/culture/culture_cards.dart';
import 'package:fluenough/features/culture/culture_deck_page.dart';
import 'package:fluenough/features/culture/culture_item_page.dart';
import 'package:fluenough/features/culture/culture_settings_page.dart';
import 'package:fluenough/features/culture/culture_timeline.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/accessibility_shared.dart';
import 'support/culture_world.dart';
import 'support/harness.dart';

final AppLocalizationsEn _l10n = AppLocalizationsEn();

const String _proverb = 'Más vale tarde que nunca.';
const String _stanza = 'Caminante, no hay camino, se hace camino al andar.';

CultureItemPage _item(String id) => CultureItemPage(
  request: CultureItemRequest(language: 'zz', itemId: id),
);

Future<void> _tapShown(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// The chip is a column: the card button, then the legacy line. A tap at the
// column's centre can land on the line, so tap the button itself.
final Finder _chipButton = find.descendant(
  of: find.byType(CreatorChip),
  matching: find.byType(InkWell),
);

void main() {
  group('in a path unit', () {
    testWidgets('one culture card between the header and the words, a bonus', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp();
      await pumpScreen(
        tester,
        const UnitPage(deckId: 'zz-en-words'),
        state: state,
      );
      expect(
        find.text(_l10n.cultureCardKind(_l10n.cultureKindProverb)),
        findsOneWidget,
      );
      expect(find.text(_l10n.cultureCardLineBonus('A1')), findsOneWidget);
      await tester.tap(find.text(_l10n.cultureCardLineBonus('A1')));
      await tester.pumpAndSettle();
      expect(find.byType(CultureItemPage), findsOneWidget);
      expect(find.text(_proverb), findsOneWidget);
    });

    testWidgets('says it counts when Settings says so', (tester) async {
      usePhone(tester);
      final state = await cultureApp();
      state.settings.cultureCounts = true;
      await pumpScreen(
        tester,
        const UnitPage(deckId: 'zz-en-words'),
        state: state,
      );
      expect(find.text(_l10n.cultureCardLineCounts('A1')), findsOneWidget);
    });

    testWidgets('is left out when culture is off, with a line to turn it on', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp();
      state.settings.cultureItems = false;
      await pumpScreen(
        tester,
        const UnitPage(deckId: 'zz-en-words'),
        state: state,
      );
      expect(find.text(_l10n.cultureCardLineBonus('A1')), findsNothing);
      expect(find.text(_l10n.cultureOffHint), findsOneWidget);
    });

    testWidgets('gives a unit nothing when no item is at its level', (
      tester,
    ) async {
      usePhone(tester);
      // At A1 the A2 unit has no item the learner may have; the left-over A1
      // item is woven there, the stanza above the level is not.
      final state = await cultureApp();
      await pumpScreen(
        tester,
        const UnitPage(deckId: 'zz-en-last'),
        state: state,
      );
      expect(find.byType(UnitCultureCard), findsOneWidget);
      expect(find.text(_l10n.cultureCardLineBonus('B1')), findsNothing);
      expect(find.text(_l10n.cultureCardLineBonus('A2')), findsNothing);
    });
  });

  group('on Today', () {
    testWidgets('offers the next item, skippable, and none when off', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp();
      await pumpScreen(
        tester,
        const Scaffold(body: SingleChildScrollView(child: TodayCultureCard())),
        state: state,
      );
      expect(find.text(_l10n.cultureTodayTitle('A1')), findsOneWidget);
      expect(
        find.text(_l10n.cultureTodayLine(_l10n.cultureKindProverb)),
        findsOneWidget,
      );
      state.settings.cultureItems = false;
      await tester.pumpAndSettle();
      expect(find.text(_l10n.cultureTodayTitle('A1')), findsNothing);
    });
  });

  group('an item', () {
    testWidgets('shows a proverb with its meaning, source and no author', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(tester, _item('zz-7101'), state: await cultureApp());
      expect(find.text(_l10n.cultureItemTitle('A1')), findsOneWidget);
      expect(find.text(_proverb), findsOneWidget);
      expect(find.text('Better late than never.'), findsOneWidget);
      expect(
        find.text(
          '${_l10n.cultureNoKnownAuthor} · Refranes de prueba · c. 1600 · '
          '${_l10n.cultureBasisOral}',
        ),
        findsOneWidget,
      );
      expect(find.text(_l10n.cultureNoAuthorTitle), findsOneWidget);
      expect(find.text(_l10n.culturePractise), findsOneWidget);
      expect(find.text(_l10n.cultureBonusNote), findsOneWidget);
    });

    testWidgets('shows a stanza with its creator chip and one legacy line', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp(reach: 'b1');
      await pumpScreen(tester, _item('zz-7201'), state: state);
      expect(find.text(_stanza), findsOneWidget);
      expect(
        find.text(
          'Antonio Machado · Proverbios y cantares · 1912 · '
          '${_l10n.cultureBasisPublicDomainDied('1939')}',
        ),
        findsOneWidget,
      );
      expect(find.byType(CreatorChip), findsOneWidget);
      expect(find.text(_l10n.cultureLifespan('1875', '1939')), findsOneWidget);
      expect(find.text('Edad de Plata · Silver Age'), findsOneWidget);
      expect(
        find.text('His lines are quoted by walkers on pilgrim roads.'),
        findsOneWidget,
      );
      expect(find.text(_l10n.cultureLegacyMore), findsOneWidget);
    });

    testWidgets('shows a passage with its words glossed', (tester) async {
      usePhone(tester);
      final state = await cultureApp(reach: 'b1');
      await pumpScreen(tester, _item('zz-pasaje-1'), state: state);
      expect(find.text('En un lugar de la Mancha.'), findsOneWidget);
      expect(find.text(_l10n.cultureGlossTitle), findsOneWidget);
      expect(
        find.text(_l10n.cultureGlossEntry('lugar', 'village')),
        findsOneWidget,
      );
    });

    testWidgets('hides the person and the legacy when Settings says so', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp(reach: 'b1');
      state.settings.cultureCreators = false;
      await pumpScreen(tester, _item('zz-7201'), state: state);
      expect(find.byType(CreatorChip), findsNothing);
      expect(find.text(_l10n.cultureLegacyTitle), findsNothing);
    });

    testWidgets(
      'is not shown above the level, and shown with support if asked',
      (tester) async {
        usePhone(tester);
        final state = await cultureApp();
        await pumpScreen(tester, _item('zz-7201'), state: state);
        expect(find.text(_stanza), findsNothing);
        expect(find.text(_l10n.cultureNotShownTitle), findsOneWidget);
        expect(find.text(_l10n.cultureNotShownBody('A2')), findsOneWidget);

        state.settings.cultureAboveSupport = true;
        await tester.pumpAndSettle();
        expect(find.text(_stanza), findsOneWidget);
        expect(find.text(_l10n.cultureAboveTitle), findsOneWidget);
        // Not counted, not scheduled: nothing to practise.
        expect(find.text(_l10n.culturePractise), findsNothing);
      },
    );
  });

  group('the creator card', () {
    testWidgets('has no licensed image, a bio at the level and the legacy', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp(reach: 'b1');
      await pumpScreen(tester, _item('zz-7201'), state: state);
      await _tapShown(tester, _chipButton);
      expect(find.byType(CreatorCard), findsOneWidget);
      expect(find.text(_l10n.cultureImageNone), findsWidgets);
      expect(find.text(_l10n.cultureAbout('Antonio Machado')), findsOneWidget);
      expect(find.text('Machado fue poeta y maestro.'), findsOneWidget);
      expect(
        find.text('A teacher and poet who wrote plain, thoughtful verse.'),
        findsOneWidget,
      );
      expect(find.text(_l10n.cultureLegacyTitle), findsWidgets);
      expect(
        find.text(
          _l10n.cultureLegacyYear(
            1969,
            'A singer recorded an album of his poems.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(_l10n.cultureTimelineHeading), findsOneWidget);
    });

    testWidgets(
      'credits a licensed image, drawing the placeholder until it comes',
      (tester) async {
        usePhone(tester);
        final state = await cultureApp(reach: 'b1');
        await pumpScreen(tester, _item('zz-pasaje-1'), state: state);
        await _tapShown(tester, _chipButton);
        expect(
          find.text(
            _l10n.cultureImageCredit(
              'Test fixture · The Fluenough tests · CC-BY-4.0',
            ),
          ),
          findsOneWidget,
        );
        expect(find.text(_l10n.cultureImageLicenceLink), findsOneWidget);
      },
    );

    testWidgets('opens the full timeline from its strip, running to today', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp(reach: 'b1');
      await pumpScreen(tester, _item('zz-7201'), state: state);
      await _tapShown(tester, _chipButton);
      expect(find.byType(TimelineStrip), findsOneWidget);
      await _tapShown(tester, find.text(_l10n.cultureTimelineFull));
      expect(find.byType(CultureTimelinePage), findsOneWidget);
      expect(find.text(_l10n.cultureTimelineToday), findsWidgets);
      expect(
        find.text(
          _l10n.cultureTimelineYearLabel(
            1605,
            'Miguel de Cervantes · Don Quijote',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          _l10n.cultureTimelineYearLabel(
            1912,
            'Antonio Machado · Proverbios y cantares',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(_l10n.cultureTimelineThis), findsWidgets);
      // The one in the card is marked this one; the other is not met yet.
      expect(find.text(_l10n.cultureTimelineNotYet), findsWidgets);
    });
  });

  group('the full culture deck', () {
    testWidgets('lists the items, locks what is above, and no unknown person', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp();
      await pumpScreen(
        tester,
        const CultureDeckPage(language: 'zz'),
        state: state,
      );
      expect(find.text(_l10n.cultureDeckTitle('Testlang')), findsOneWidget);
      expect(find.text(_l10n.cultureDeckCount(3, 1)), findsOneWidget);
      expect(find.text(_proverb), findsOneWidget);
      expect(find.text(_l10n.cultureUnlocksAt('A2')), findsOneWidget);
      expect(find.text(_l10n.cultureUnlocksAt('B1')), findsOneWidget);
      expect(find.text(_stanza), findsNothing);
      // The people only an item above the level cites are not given away.
      expect(find.text(_l10n.culturePeople), findsNothing);
      expect(find.text('Antonio Machado'), findsNothing);
    });

    testWidgets('lists the people once the learner reaches their works', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp(reach: 'b1');
      await pumpScreen(
        tester,
        const CultureDeckPage(language: 'zz'),
        state: state,
      );
      expect(find.text(_l10n.culturePeople), findsOneWidget);
      expect(find.text('Antonio Machado'), findsOneWidget);
      expect(find.text('Miguel de Cervantes'), findsOneWidget);
      await _tapShown(tester, find.byType(CreatorRow).first);
      expect(find.byType(CreatorCard), findsOneWidget);
    });

    testWidgets('shows what is above the level with support, when asked', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp();
      state.settings.cultureAboveSupport = true;
      await pumpScreen(
        tester,
        const CultureDeckPage(language: 'zz'),
        state: state,
      );
      expect(find.text(_stanza), findsOneWidget);
      expect(find.text(_l10n.cultureUnlocksAt('A2')), findsNothing);
    });

    testWidgets('opens an item, and says so when the course has none', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp();
      await pumpScreen(
        tester,
        const CultureDeckPage(language: 'zz'),
        state: state,
      );
      await _tapShown(tester, find.text(_proverb));
      expect(find.byType(CultureItemPage), findsOneWidget);

      final none = await cultureApp(
        files: <String, String>{
          for (final e in cultureWorld().entries)
            if (!e.key.contains('culture-') && !e.key.contains('proverbs-'))
              e.key: e.value,
        },
      );
      await pumpScreen(
        tester,
        const CultureDeckPage(language: 'zz'),
        state: none,
      );
      expect(find.text(_l10n.cultureDeckEmpty), findsOneWidget);
    });
  });

  group('the culture settings', () {
    testWidgets('switch culture off and on, and keep the choices', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp();
      await pumpScreen(tester, const CultureSettingsPage(), state: state);
      expect(state.settings.cultureItems, isTrue);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(state.settings.cultureItems, isFalse);
      expect(find.text(_l10n.cultureSettingShowOff), findsOneWidget);

      await tester.tap(find.text(_l10n.cultureSettingAboveSupport));
      await tester.pumpAndSettle();
      expect(state.settings.cultureAboveSupport, isTrue);
      expect(state.settings.cultureCounts, isFalse);
      expect(state.settings.cultureCreators, isTrue);
    });

    testWidgets('asks how many items a unit is given', (tester) async {
      usePhone(tester);
      final state = await cultureApp();
      await pumpScreen(tester, const CultureSettingsPage(), state: state);
      expect(find.text(_l10n.cultureSettingPerUnitValue(1)), findsOneWidget);
      await tester.tap(find.text(_l10n.cultureSettingPerUnit));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.cultureSettingPerUnitValue(2)));
      await tester.pumpAndSettle();
      expect(state.settings.culturePerUnit, 2);
    });

    test('are kept in the stored settings and come back after a restore', () {
      final settings = SettingsNotifier()
        ..cultureItems = false
        ..cultureAboveSupport = true
        ..cultureCounts = true
        ..culturePerUnit = 2
        ..cultureCreators = false;
      final stored = settings.toStored();
      expect(stored['culture_items'], 'false');
      expect(stored['culture_per_unit'], '2');
      final back = SettingsNotifier()..restore(stored);
      expect(back.cultureItems, isFalse);
      expect(back.cultureAboveSupport, isTrue);
      expect(back.cultureCounts, isTrue);
      expect(back.culturePerUnit, 2);
      expect(back.cultureCreators, isFalse);
      // The count is kept between one and three.
      back.culturePerUnit = 9;
      expect(back.culturePerUnit, 3);
    });
  });

  group('culture off', () {
    test(
      'takes the culture decks out of the lessons and reviews, not search',
      () async {
        final state = await cultureApp();
        bool inDrill() =>
            state.drillDecks.any((e) => e.id == 'zz-en-proverbs-lugar');
        expect(inDrill(), isTrue);
        state.settings.cultureItems = false;
        expect(inDrill(), isFalse);
        expect(state.deckById('zz-en-proverbs-lugar'), isNotNull);
      },
    );
  });

  group('layout', () {
    DrawScreen item(String id, {String reach = 'a1'}) =>
        page(_item(id), state: () => cultureApp(reach: reach));

    screen('a proverb', item('zz-7101'));
    screen('a stanza with its creator', item('zz-7201', reach: 'b1'));
    screen('a passage with its gloss', item('zz-pasaje-1', reach: 'b1'));
    screen('an item above the level, not shown', item('zz-7201'));
    screen(
      'an item above the level, with support',
      page(
        _item('zz-7201'),
        state: () async {
          final state = await cultureApp();
          state.settings.cultureAboveSupport = true;
          return state;
        },
      ),
    );
    screen(
      'the culture deck at A1',
      page(const CultureDeckPage(language: 'zz'), state: () => cultureApp()),
    );
    screen(
      'the culture deck at B1, with its people',
      page(
        const CultureDeckPage(language: 'zz'),
        state: () => cultureApp(reach: 'b1'),
      ),
    );
    screen(
      'the full timeline',
      page(
        const CultureTimelinePage(
          request: CultureTimelineRequest(
            language: 'zz',
            creatorId: 'zz-machado',
          ),
        ),
        state: () => cultureApp(reach: 'b1'),
      ),
    );
    screen(
      'the empty timeline',
      page(
        const CultureTimelinePage(
          request: CultureTimelineRequest(language: 'zz'),
        ),
        state: () => cultureApp(),
      ),
    );
    screen(
      'the culture settings',
      page(const CultureSettingsPage(), state: () => cultureApp()),
    );
    screen(
      'a unit with a culture card',
      page(const UnitPage(deckId: 'zz-en-words'), state: () => cultureApp()),
    );
    screen(
      'Today\'s culture row',
      page(
        const Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: TodayCultureCard(),
            ),
          ),
        ),
        state: () => cultureApp(),
      ),
    );

    screen('the creator card as a sheet', (tester, mode) async {
      final state = await cultureApp(reach: 'b1');
      await pumpScreen(tester, _item('zz-7201'), state: state, themeMode: mode);
      await _tapShown(tester, _chipButton);
    }, onTop: find.byType(CreatorCard));
    screen('the creator card with a licensed image', (tester, mode) async {
      final state = await cultureApp(reach: 'b1');
      await pumpScreen(
        tester,
        _item('zz-pasaje-1'),
        state: state,
        themeMode: mode,
      );
      await _tapShown(tester, _chipButton);
    }, onTop: find.byType(CreatorCard));
  });
}
