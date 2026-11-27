// The Add a deck page, from a link (#22): the link is downloaded by a fake
// fetcher, checked as a picked file is, and added or replaced.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_import.dart';
import 'package:fluenough/core/decks/deck_link.dart';
import 'package:fluenough/features/decks/import_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// Answers links from [reply], recording the addresses asked for.
class _FakeLinks implements DeckLinkFetcher {
  _FakeLinks(this.reply);

  final LinkFetched Function(Uri uri) reply;
  final List<Uri> asked = <Uri>[];

  @override
  Future<LinkFetched> fetch(Uri uri) async {
    asked.add(uri);
    return reply(uri);
  }
}

const String _link = 'https://example.org/decks/my-words.yaml';

/// Text that is YAML but not a deck.
const String _notADeck = 'schema: 1\nkind: path';

/// The template, as a deck that passes every check.
Future<String> _template() =>
    rootBundle.loadString(deckTemplateAsset, cache: false);

/// The page open on From a link, in a window tall enough to show all of it.
Future<void> _open(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpScreen(
    tester,
    const ImportPage(initialSource: ImportSource.url),
    state: state,
  );
}

Future<void> _fetch(WidgetTester tester, String link) async {
  await tester.enterText(find.byType(TextField), link);
  await tester.tap(find.text(l10nOf(tester).importFetch));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a linked deck is checked, then added', (tester) async {
    final text = await _template();
    final links = _FakeLinks((uri) => LinkFetched(text));
    final state = AppState.test(deckLinks: links);
    await _open(tester, state);
    final l10n = l10nOf(tester);

    await _fetch(tester, _link);
    expect(links.asked.map((u) => '$u'), <String>[_link]);
    expect(find.text(l10n.importChecked), findsOneWidget);
    expect(find.text('My words'), findsOneWidget);
    expect(find.text(l10n.importAdd), findsOneWidget);
    expect(find.text(l10n.importReplaces), findsNothing);
    expect(state.deckById('hi-en-my-words'), isNull);

    await tester.tap(find.text(l10n.importAdd));
    for (var i = 0; i < 20; i++) {
      if (state.deckById('hi-en-my-words') != null) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(state.deckById('hi-en-my-words'), isNotNull);
  });

  testWidgets('a deck added before offers Replace, not Add', (tester) async {
    final text = await _template();
    final state = AppState.test(
      deckLinks: _FakeLinks((uri) => LinkFetched(text)),
    );
    await state.load();
    final check = state.checkDeck(text, 'my-words.yaml') as DeckAccepted;
    await state.addDeck(check.deck, text);
    await _open(tester, state);
    final l10n = l10nOf(tester);

    await _fetch(tester, _link);
    expect(find.text(l10n.importReplaces), findsOneWidget);
    expect(find.text(l10n.importReplace), findsOneWidget);
    expect(find.text(l10n.importAdd), findsNothing);
  });

  testWidgets('a file that is not a deck is refused', (tester) async {
    final links = _FakeLinks((uri) => const LinkFetched(_notADeck));
    final state = AppState.test(deckLinks: links);
    await _open(tester, state);
    final l10n = l10nOf(tester);

    await _fetch(tester, _link);
    expect(find.text(l10n.importErrorTitle), findsOneWidget);
    expect(find.text(l10n.importChecked), findsNothing);
    expect(find.text(l10n.importAdd), findsNothing);
  });

  testWidgets('a link that fails says why, and adds nothing', (tester) async {
    final links = _FakeLinks(
      (uri) => const LinkFetched.failed(LinkFailure.notFound),
    );
    final state = AppState.test(deckLinks: links);
    await _open(tester, state);
    final l10n = l10nOf(tester);

    await _fetch(tester, _link);
    expect(links.asked, hasLength(1));
    expect(find.text(l10n.importLinkNotFound), findsOneWidget);
    expect(find.text(l10n.importAdd), findsNothing);
  });

  testWidgets('a bad link is refused without being fetched', (tester) async {
    final links = _FakeLinks((uri) => const LinkFetched('x'));
    final state = AppState.test(deckLinks: links);
    await _open(tester, state);
    final l10n = l10nOf(tester);

    await _fetch(tester, 'http://example.org/my-words.yaml');
    expect(find.text(l10n.importLinkNotHttps), findsOneWidget);

    await _fetch(tester, 'my-words');
    expect(find.text(l10n.importLinkNotALink), findsOneWidget);
    expect(find.text(l10n.importLinkNotHttps), findsNothing);
    expect(links.asked, isEmpty);
  });
}
