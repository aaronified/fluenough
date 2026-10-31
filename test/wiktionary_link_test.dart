// The Wiktionary link on a word's sheet (#422): built from the word, shown
// only for a word the deck marks as having an entry, and opened through the
// app's link opener only when tapped. Words here are made up.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/core/decks/wiktionary_link.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const LanguageInfo _telugu = LanguageInfo(
  code: 'te',
  iso639_3: 'tel',
  name: 'Telugu',
  script: 'telugu',
);

Card _card(
  String id,
  String target, {
  bool marked = false,
  List<CardBase> bases = const <CardBase>[],
}) => Card(
  id: id,
  deckId: 'te-test',
  target: target,
  native: 'x',
  wiktionary: marked,
  bases: bases,
);

List<WiktionaryLink> _links(
  Card card, {
  Map<String, Card> others = const <String, Card>{},
  String edition = 'en',
  String code = 'te',
  String name = 'Telugu',
}) => wiktionaryLinksOf(
  card,
  (id) => others[id],
  edition: edition,
  languageCode: code,
  languageName: name,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the address is built from the word', () {
    test('a word, a phrase and a language with a space in its name', () {
      expect(
        wiktionaryUrl('ఇల్లు', edition: 'en', section: 'Telugu').toString(),
        'https://en.wiktionary.org/wiki/%E0%B0%87%E0%B0%B2%E0%B1%8D%E0%B0%B2%E0%B1%81#Telugu',
      );
      expect(
        wiktionaryUrl(
          ' un  café ',
          edition: 'en',
          section: 'Toki Pona',
        ).toString(),
        'https://en.wiktionary.org/wiki/un_caf%C3%A9#Toki_Pona',
      );
    });

    test('characters that mean something in an address are encoded', () {
      final url = wiktionaryUrl('a/b?c#d%', edition: 'bn')!;
      expect(url.toString(), 'https://bn.wiktionary.org/wiki/a%2Fb%3Fc%23d%25');
      expect(url.fragment, isEmpty);
    });

    test('a right-to-left word is encoded as UTF-8', () {
      expect(
        wiktionaryUrl('بَيْت', edition: 'en').toString(),
        startsWith('https://en.wiktionary.org/wiki/%D8%A8'),
      );
    });

    test('no address for a blank word or a bad edition', () {
      expect(wiktionaryUrl('  ', edition: 'en'), isNull);
      expect(wiktionaryUrl('x', edition: 'EN'), isNull);
      expect(wiktionaryUrl('x', edition: 'evil.com/'), isNull);
    });
  });

  group('which words get a link', () {
    test('only a marked word, and none otherwise', () {
      expect(_links(_card('te-1', 'ఇల్లు')), isEmpty);
      final links = _links(_card('te-1', 'ఇల్లు', marked: true));
      expect(links.single.word, 'ఇల్లు');
      expect(links.single.url.fragment, 'Telugu');
    });

    test('a sentence links the marked base words, not itself', () {
      final others = <String, Card>{
        'te-2': _card('te-2', 'వచ్చు', marked: true),
        'te-3': _card('te-3', 'పోవు'),
      };
      final sentence = _card(
        'te-9',
        'వచ్చాడు పోయాడు',
        bases: const <CardBase>[
          CardBase(word: 'వచ్చాడు', ref: 'te-2'),
          CardBase(word: 'పోయాడు', ref: 'te-3'),
          CardBase(word: 'ఏదో', base: 'ఏది', wiktionary: true),
          CardBase(word: 'ఇంకా', base: 'ఇంక'),
          CardBase(word: 'మళ్ళీ', ref: 'te-2'),
        ],
      );
      expect(_links(sentence, others: others).map((l) => l.word), <String>[
        'వచ్చు',
        'ఏది',
      ]);
    });

    test('another edition names no section; Hindustani is Hindi', () {
      expect(
        _links(_card('te-1', 'x', marked: true), edition: 'bn').single.url,
        Uri.parse('https://bn.wiktionary.org/wiki/x'),
      );
      expect(
        _links(
          _card('hi-1', 'x', marked: true),
          code: 'hi',
          name: 'Hindustani',
        ).single.url.fragment,
        'Hindi',
      );
    });
  });

  group('the word sheet', () {
    testWidgets('shows the link for a marked word and opens it only when '
        'tapped', (tester) async {
      usePhone(tester);
      final links = FixedLinks();
      await pumpScreen(
        tester,
        Scaffold(
          body: WordSheet(
            card: _card('te-1', 'ఇల్లు', marked: true),
            language: _telugu,
          ),
        ),
        state: AppState.test(links: links),
      );
      expect(links.asked, isEmpty, reason: 'nothing is fetched to show it');
      final button = find.byIcon(Icons.open_in_new, skipOffstage: false);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(links.asked, hasLength(1));
      expect(links.asked.single, startsWith('https://en.wiktionary.org/wiki/'));
      expect(links.asked.single, endsWith('#Telugu'));
    });

    testWidgets('shows no link for a word the deck does not mark', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        Scaffold(
          body: WordSheet(card: _card('te-1', 'ఇల్లు'), language: _telugu),
        ),
      );
      expect(find.byIcon(Icons.open_in_new), findsNothing);
    });
  });
}
