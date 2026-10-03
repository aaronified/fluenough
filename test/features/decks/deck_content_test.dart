import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/features/decks/deck_content.dart';
import 'package:fluenough/l10n/app_localizations_en.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState state;
  final l10n = AppLocalizationsEn();

  setUpAll(() async {
    state = AppState.test();
    await state.load();
  });

  test('a vocab deck offers the modes its cards take part in', () {
    final spanish = state.deckById('es-en-core-100')!;
    expect(deckSkills(spanish, SettingsNotifier()), <Skill>[
      Skill.recognition,
      Skill.production,
      Skill.listening,
    ]);
  });

  test('a grammar deck offers grammar, and no deck offers pairs yet', () {
    final grammar = state.deckById('es-en-grammar-present-ar')!;
    expect(deckSkills(grammar, SettingsNotifier()), <Skill>[Skill.grammar]);
    for (final entry in state.decks) {
      expect(declaresPairs(entry), isFalse, reason: entry.id);
      expect(
        deckSkills(entry, SettingsNotifier()),
        isNot(contains(Skill.pair)),
      );
    }
  });

  test('a skill switched off in Settings is left out', () {
    final spanish = state.deckById('es-en-core-100')!;
    final settings = SettingsNotifier(
      enabledSkills: <Skill>{Skill.recognition, Skill.listening},
    );
    expect(deckSkills(spanish, settings), <Skill>[
      Skill.recognition,
      Skill.listening,
    ]);
  });

  test('the tag filter lists card tags, not deck tags', () {
    final spanish = state.deckById('es-en-core-100')!;
    final tags = cardTagsOf(spanish);
    expect(tags, contains('people'));
    expect(tags, isNot(contains('beginner')), reason: 'a deck tag');
    expect(tags.toSet(), hasLength(tags.length));
    expect(showsTagFilter(spanish), isTrue);
    // The Hindi vowels carry no card tags, so there is nothing to filter.
    expect(showsTagFilter(state.deckById('hi-en-script-vowels')!), isFalse);
  });

  test('a grammar deck previews its pattern cells, lemma and slot', () {
    final grammar = state.deckById('es-en-grammar-present-ar')!;
    final pattern = grammar.deck.pattern!;
    final first = pattern.entries.first;
    final preview = previewOf(grammar, l10n);
    expect(preview, hasLength(4));
    expect(preview.first.target, first.forms[pattern.slots.first]);
    expect(
      preview.first.native,
      l10n.deckGrammarCell(first.lemma, pattern.slots.first),
    );
  });

  test('a vocab preview is deck content, never a card id', () {
    final spanish = state.deckById('es-en-core-100')!;
    final ids = spanish.cards.map((c) => c.id).toSet();
    for (final line in previewOf(spanish, l10n)) {
      expect(ids, isNot(contains(line.target)));
      expect(ids, isNot(contains(line.native)));
    }
  });

  test('search matches a deck name or its language name', () {
    // Named "First words", in Hindi.
    final words = state.deckById('hi-en-first-words')!;
    expect(deckMatches(words, ''), isTrue);
    expect(deckMatches(words, 'FIRST'), isTrue);
    expect(deckMatches(words, 'hindi'), isTrue);
    expect(deckMatches(words, 'spanish'), isFalse);
  });

  test('every word of a search must match something about the deck', () {
    final nouns = state.deckById('hi-en-grammar-nouns')!;
    final also = <String>['Market', 'Grammar'];
    expect(deckMatches(nouns, 'hindi market', also: also), isTrue);
    expect(deckMatches(nouns, '  Market   HINDI ', also: also), isTrue);
    expect(deckMatches(nouns, 'grammar', also: also), isTrue);
    expect(deckMatches(nouns, 'bengali market', also: also), isFalse);
    expect(deckMatches(nouns, 'hindi transport', also: also), isFalse);
  });

  test('a deck is searched under its own theme, or its unit\'s', () {
    final themes = state.themesByDeck;
    expect(themes['hi-en-market']?.id, 'market');
    // Grammar has no theme of its own: it takes its unit's on the path.
    expect(themes['hi-en-grammar-nouns']?.id, 'market');
    expect(themes['hi-en-grammar-articles']?.id, 'market');
  });
}
