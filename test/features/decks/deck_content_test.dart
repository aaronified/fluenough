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
    // Every hiragana card has the one tag, which would filter nothing.
    expect(showsTagFilter(state.deckById('ja-en-hiragana')!), isFalse);
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
    final hiragana = state.deckById('ja-en-hiragana')!;
    expect(deckMatches(hiragana, ''), isTrue);
    expect(deckMatches(hiragana, 'HIRA'), isTrue);
    expect(deckMatches(hiragana, 'japanese'), isTrue);
    expect(deckMatches(hiragana, 'spanish'), isFalse);
  });
}
