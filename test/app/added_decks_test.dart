import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/added_decks.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_import.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/import_error_card.dart';
import 'package:fluenough/features/decks/import_page.dart';

import '../support/harness.dart';

/// Answers the file dialogs from memory.
class FakeDeckFiles implements DeckFiles {
  FakeDeckFiles({this.picked});

  ({String name, String text})? picked;
  final Map<String, String> saved = <String, String>{};

  @override
  Future<bool> save(String fileName, String contents) async {
    saved[fileName] = contents;
    return true;
  }

  @override
  Future<({String name, String text})?> open({required String title}) async =>
      picked;
}

/// The template, as the learner downloads it: Hindi from English, a market
/// deck with two cards of its own and one ref. Not cached: a future cached
/// in one test's zone never completes in the next.
Future<String> template() =>
    rootBundle.loadString(deckTemplateAsset, cache: false);

void main() {
  testWidgets('the template can be added, and joins the bottom of its '
      'theme\'s unit', (tester) async {
    final state = AppState.test();
    await state.load();
    final text = await template();

    final check = state.checkDeck(text, 'my-words.yaml');
    expect(check, isA<DeckAccepted>());
    check as DeckAccepted;
    expect(check.deck.id, 'hi-en-my-words');
    expect(check.cardCount, 3);
    expect(check.replaces, isFalse);

    await state.addDeck(check.deck, text);
    final added = state.deckById('hi-en-my-words')!;
    expect(added.bundled, isFalse);
    expect(added.cards.map((c) => c.id), [
      'hi-my-0001',
      'hi-my-0002',
      'hi-0231',
    ]);
    final path = state.pathOf(added)!;
    final unit = path.units[path.unitOf('hi-en-market')!];
    expect(unit.last, 'hi-en-my-words');
    final order = state.decks.map((e) => e.id).toList();
    expect(
      order.indexOf('hi-en-my-words'),
      order.indexOf(unit[unit.length - 2]) + 1,
    );
  });

  testWidgets('a deck with no theme the course has goes at the end', (
    tester,
  ) async {
    final state = AppState.test();
    await state.load();
    final text = (await template()).replaceFirst(
      'theme: market',
      'theme: weather',
    );
    await state.addDeck(
      (state.checkDeck(text, 'w.yaml') as DeckAccepted).deck,
      text,
    );
    final added = state.deckById('hi-en-my-words')!;
    expect(state.pathOf(added)!.units.last, ['hi-en-my-words']);
    final hindi = [
      for (final e in state.decks)
        if (e.language.code == 'hi') e.id,
    ];
    expect(hindi.last, 'hi-en-my-words');
  });

  testWidgets('a file is refused when it is not a deck, or has the id of a '
      'deck or card it would clash with', (tester) async {
    final state = AppState.test();
    await state.load();
    final text = await template();

    expect(
      state.checkDeck('schema: 1\nkind: path\n', 'x.yaml'),
      isA<DeckUnreadable>(),
    );
    expect(
      state.checkDeck(
        text.replaceFirst('id: hi-en-my-words', 'id: hi-en-market'),
        'x.yaml',
      ),
      isA<DeckIdBundled>().having((c) => c.deckId, 'deckId', 'hi-en-market'),
    );
    expect(
      state.checkDeck(
        text.replaceFirst('id: hi-my-0002', 'id: hi-0232'),
        'x.yaml',
      ),
      isA<DeckCardTaken>().having((c) => c.cardId, 'cardId', 'hi-0232'),
    );

    // A deck added before is replaced, and so may keep its own cards.
    await state.addDeck(
      (state.checkDeck(text, 'x.yaml') as DeckAccepted).deck,
      text,
    );
    expect(
      state.checkDeck(text, 'x.yaml'),
      isA<DeckAccepted>().having((c) => c.replaces, 'replaces', isTrue),
    );
  });

  testWidgets('a bundled deck keeps its id over an added one', (tester) async {
    final market = File('decks/hi/hi-en-market.yaml').readAsStringSync();
    final state = AppState.test(
      addedDecks: MemoryDeckStore(<String, String>{'hi-en-market': market}),
    );
    await state.load();
    expect(state.deckById('hi-en-market')!.bundled, isTrue);
    expect(
      state.brokenDecks.map((b) => b.path),
      contains('${addedDeckPrefix}hi-en-market.yaml'),
    );
  });

  test('FileDeckStore keeps one file per deck, listed under added/', () async {
    final dir = await Directory.systemTemp.createTemp('decks');
    addTearDown(() => dir.delete(recursive: true));
    final store = FileDeckStore(Directory('${dir.path}/decks'));
    expect(await store.list(), isEmpty);
    await store.save('hi-en-b', 'b');
    await store.save('hi-en-a', 'a');
    await store.save('hi-en-a', 'a2');
    expect(await store.list(), ['added/hi-en-a.yaml', 'added/hi-en-b.yaml']);
    expect(await store.read('added/hi-en-a.yaml'), 'a2');
    await store.remove('hi-en-a');
    expect(await store.list(), ['added/hi-en-b.yaml']);
  });

  group('the import page', () {
    testWidgets('saves the template', (tester) async {
      usePhone(tester);
      final files = FakeDeckFiles();
      await pumpScreen(
        tester,
        const ImportPage(),
        state: AppState.test(deckFiles: files),
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.importTemplate));
      await tester.pumpAndSettle();
      expect(files.saved[deckTemplateFile], await template());
      expect(
        find.text(l10n.importTemplateSaved(deckTemplateFile)),
        findsOneWidget,
      );
    });

    testWidgets('checks a chosen file, then adds it', (tester) async {
      usePhone(tester);
      final files = FakeDeckFiles(
        picked: (name: 'my-words.yaml', text: await template()),
      );
      final state = await pumpScreen(
        tester,
        const ImportPage(),
        state: AppState.test(deckFiles: files),
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.importChoose));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l10n.importAdd),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Already built below the screen, the button is only jumped to, with no
      // drag: lay it out there before tapping it.
      await tester.pumpAndSettle();
      expect(find.text(l10n.importChecked), findsOneWidget);
      expect(find.text('My words'), findsOneWidget);
      expect(find.text(l10n.importDeckMeta(3, 'CC0-1.0')), findsOneWidget);

      await tester.tap(find.text(l10n.importAdd));
      await tester.pumpAndSettle();
      expect(state.deckById('hi-en-my-words'), isNotNull);
      expect(find.text(l10n.importAdded('My words')), findsOneWidget);
    });

    testWidgets('says why a file is refused, and adds nothing', (tester) async {
      usePhone(tester);
      final text = (await template()).replaceFirst(
        'id: hi-en-my-words',
        'id: hi-en-market',
      );
      final state = await pumpScreen(
        tester,
        const ImportPage(),
        state: AppState.test(
          deckFiles: FakeDeckFiles(picked: (name: 'm.yaml', text: text)),
        ),
      );
      final l10n = l10nOf(tester);
      final before = state.decks.length;
      await tester.tap(find.text(l10n.importChoose));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(ImportErrorCard),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          l10n.importErrorIn('m.yaml', l10n.importIdBundled('hi-en-market')),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.importAdd), findsNothing);
      expect(state.decks.length, before);
    });
  });

  testWidgets('an added deck can be removed from its page; a bundled one '
      'cannot', (tester) async {
    usePhone(tester);
    final store = MemoryDeckStore(<String, String>{
      'hi-en-my-words': await template(),
    });
    final state = AppState.test(addedDecks: store);
    await pumpScreen(
      tester,
      const DeckDetailPage(deckId: 'hi-en-market'),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(find.byTooltip(l10n.deckRemove), findsNothing);

    await pumpScreen(
      tester,
      const DeckDetailPage(deckId: 'hi-en-my-words'),
      state: state,
    );
    await tester.tap(find.byTooltip(l10n.deckRemove));
    await tester.pumpAndSettle();
    expect(find.text(l10n.deckRemoveTitle('My words')), findsOneWidget);
    await tester.tap(find.text(l10n.deckRemoveConfirm));
    await tester.pumpAndSettle();
    expect(state.deckById('hi-en-my-words'), isNull);
    expect(await store.list(), isEmpty);
  });
}
