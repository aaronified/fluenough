// Culture in the course (wiki/Plan-Deck-Kinds-And-Topics.md, T20, the approved
// mockup docs/mockups/culture-in-course.html, default variants): a culture item
// woven into a path unit and offered on Today at the learner's level; its page
// with the text, meaning, gloss, source line, creator chip and legacy line; the
// creator card with the picture's credit or its placeholder, the bio, "Still alive today" and the timeline strip; the full
// timeline to today; the full culture deck with its people; the culture
// options each language keeps (`culture-in-decks`).

import 'package:fluenough/app/culture.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/culture_options.dart';
import 'package:fluenough/features/culture/creator_sheet.dart';
import 'package:fluenough/features/culture/culture_cards.dart';
import 'package:fluenough/features/culture/culture_deck_page.dart';
import 'package:fluenough/features/culture/culture_item_page.dart';
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

    testWidgets('says it counts when the language\'s options say so', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp();
      state.settings.setCultureFor('zz', const CultureOptions(counts: true));
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
      state.settings.setCultureFor('zz', const CultureOptions(items: false));
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
      // A unit with no item at its own level is given a left-over lower one.
      final state = await cultureApp();
      await pumpScreen(
        tester,
        const UnitPage(deckId: 'zz-en-last'),
        state: state,
      );
      expect(find.byType(UnitCultureCard), findsOneWidget);
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
      state.settings.setCultureFor('zz', const CultureOptions(items: false));
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

    testWidgets('hides the person and the legacy when the options say so', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp(reach: 'b1');
      state.settings.setCultureFor('zz', const CultureOptions(creators: false));
      await pumpScreen(tester, _item('zz-7201'), state: state);
      expect(find.byType(CreatorChip), findsNothing);
      expect(find.text(_l10n.cultureLegacyTitle), findsNothing);
    });

    testWidgets('is shown whatever its level', (tester) async {
      usePhone(tester);
      final state = await cultureApp();
      await pumpScreen(tester, _item('zz-7201'), state: state);
      expect(find.text(_stanza), findsOneWidget);
      expect(find.text(_l10n.culturePractise), findsOneWidget);
    });
  });

  group('the creator card', () {
    testWidgets('has no caption without an image, a bio at the level and the legacy', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp(reach: 'b1');
      await pumpScreen(tester, _item('zz-7201'), state: state);
      await _tapShown(tester, _chipButton);
      expect(find.byType(CreatorCard), findsOneWidget);
      // No picture, no caption and no apology text.
      expect(find.text(_l10n.cultureImageNone), findsNothing);
      expect(find.byIcon(Icons.person_outline), findsWidgets);
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
    testWidgets('lists every item, and no unknown person', (tester) async {
      usePhone(tester);
      final state = await cultureApp();
      await pumpScreen(
        tester,
        const CultureDeckPage(language: 'zz'),
        state: state,
      );
      expect(find.text(_l10n.cultureDeckTitle('Testlang')), findsOneWidget);
      expect(find.text(_l10n.cultureDeckCount(3)), findsOneWidget);
      expect(find.text(_proverb), findsOneWidget);
      expect(find.text(_stanza), findsOneWidget);
    });

    testWidgets('lists the people the items cite', (tester) async {
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

  group('the culture options of each language', () {
    test('are per language: one language\'s choice leaves the others', () {
      final settings = SettingsNotifier();
      expect(settings.cultureFor('te'), CultureOptions.defaults);
      settings.setCultureFor(
        'te',
        const CultureOptions(items: false, counts: true),
      );
      expect(settings.cultureFor('te').items, isFalse);
      expect(settings.cultureFor('te').counts, isTrue);
      expect(settings.cultureFor('hi'), CultureOptions.defaults);
      settings.setCultureFor(
        'hi',
        settings.cultureFor('hi').copyWith(creators: false),
      );
      expect(settings.cultureFor('hi').creators, isFalse);
      expect(settings.cultureFor('te').creators, isTrue);
    });

    test('tell the settings\' listeners only when something changed', () {
      final settings = SettingsNotifier();
      var heard = 0;
      settings.addListener(() => heard++);
      settings.setCultureFor('te', CultureOptions.defaults);
      expect(heard, 0);
      settings.setCultureFor('te', const CultureOptions(counts: true));
      expect(heard, 1);
    });

    test('are kept in the stored settings and come back after a restore', () {
      final settings = SettingsNotifier()
        ..setCultureFor(
          'te',
          const CultureOptions(items: false, counts: true, creators: false),
        );
      final stored = settings.toStored();
      expect(stored.containsKey('culture_items'), isFalse);
      expect(stored.containsKey('culture_per_unit'), isFalse);
      expect(stored.containsKey('hide_above_level'), isFalse);
      final back = SettingsNotifier()..restore(stored);
      expect(
        back.cultureFor('te'),
        const CultureOptions(items: false, counts: true, creators: false),
      );
      expect(back.cultureFor('hi'), CultureOptions.defaults);
    });

    test('read an entry with a key missing or wrong as its default', () {
      final back = SettingsNotifier()
        ..restore(<String, String>{
          'culture_by_language':
              '{"te":{"counts":true,"items":"no"},"hi":[],"bad!":{}}',
        });
      expect(back.cultureFor('te'), const CultureOptions(counts: true));
      expect(back.cultureFor('hi'), CultureOptions.defaults);
    });

    test('a store from before they were per language copies the global '
        'values to every language the profile has', () {
      final back = SettingsNotifier()
        ..restore(<String, String>{
          'language_skills': '{"te":{"speak":"learn"},"hi":{"speak":"learn"}}',
          'learning_languages': 'bn',
          'culture_items': 'false',
          'culture_above_support': 'true',
          'culture_counts': 'true',
          'culture_per_unit': '3',
          'culture_creators': 'false',
          'hide_above_level': 'true',
        });
      const carried = CultureOptions(
        items: false,
        counts: true,
        creators: false,
      );
      expect(back.cultureFor('te'), carried);
      expect(back.cultureFor('hi'), carried);
      expect(back.cultureFor('bn'), carried);
      // A language added later starts from the defaults, not the old values.
      expect(back.cultureFor('mr'), CultureOptions.defaults);
      // The old keys are not written again; the map is.
      final stored = back.toStored();
      expect(stored.containsKey('culture_items'), isFalse);
      expect(stored.containsKey('culture_per_unit'), isFalse);
      expect(stored.containsKey('hide_above_level'), isFalse);
      // Restoring what was written gives the same choices.
      final again = SettingsNotifier()..restore(stored);
      expect(again.cultureFor('te'), carried);
      expect(again.cultureFor('mr'), CultureOptions.defaults);
    });

    test('the per-language map wins over old keys left in the store', () {
      final back = SettingsNotifier()
        ..restore(<String, String>{
          'language_skills': '{"te":{"speak":"learn"},"hi":{"speak":"learn"}}',
          'culture_by_language': '{"te":{"counts":true}}',
          'culture_items': 'false',
        });
      expect(back.cultureFor('te'), const CultureOptions(counts: true));
      expect(back.cultureFor('hi'), CultureOptions.defaults);
    });

    test('go back to the defaults when the language is cleared', () {
      final settings = SettingsNotifier()
        ..setCultureFor('te', const CultureOptions(items: false))
        ..setCultureFor('hi', const CultureOptions(items: false))
        ..clearLanguageSettings('te');
      expect(settings.cultureFor('te'), CultureOptions.defaults);
      expect(settings.cultureFor('hi').items, isFalse);
    });

    testWidgets('another language\'s choice leaves this one\'s culture on', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp();
      // Another language's choice does not touch this one.
      state.settings.setCultureFor('hi', const CultureOptions(items: false));
      await pumpScreen(
        tester,
        const UnitPage(deckId: 'zz-en-words'),
        state: state,
      );
      expect(find.text(_l10n.cultureCardLineBonus('A1')), findsOneWidget);
      expect(state.nextCultureItem('zz'), isNotNull);
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
        state.settings.setCultureFor('hi', const CultureOptions(items: false));
        expect(inDrill(), isTrue);
        state.settings.setCultureFor('zz', const CultureOptions(items: false));
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
