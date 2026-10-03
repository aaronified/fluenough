import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/session.dart';
import '../../app/skill.dart';
import '../../core/tts/fixed_tts_engine.dart';
import '../decks/deck_detail_page.dart';
import '../gallery/gallery_entry.dart';
import '../settings/settings_page.dart';
import 'drill_page.dart';
import 'drill_preset.dart';
import 'reading_drill.dart';
import 'reading_fixture.dart';

/// Reading comprehension's states (#98): the passage, a question before and
/// after its answer, true or false, the glossary, the passage heard, and
/// where reading decks and their sources show outside the drill. All on
/// [readingFixtureDecks], with a Bengali voice.
final List<GalleryEntry> readingGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'drill-reading',
    section: GallerySection.drills,
    label: 'Reading, the passage', // ui-literal-ok: debug-only gallery
    note: 'Sentences to hear, the source under them (#98)', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(request: _read),
    state: readingState,
  ),
  GalleryEntry(
    id: 'drill-reading-question',
    section: GallerySection.drills,
    label: 'Reading, a question', // ui-literal-ok: debug-only gallery
    note: 'Large choices, the passage under them', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        DrillPage(request: _read, preset: const DrillPreset(questions: true)),
    state: readingState,
  ),
  GalleryEntry(
    id: 'drill-reading-right',
    section: GallerySection.drills,
    label: 'Reading, answered right', // ui-literal-ok: debug-only gallery
    note: 'Correct, and the answer', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        DrillPage(request: _read, preset: const DrillPreset(choice: 0)),
    state: readingState,
  ),
  GalleryEntry(
    id: 'drill-reading-wrong',
    section: GallerySection.drills,
    label: 'Reading, answered wrong', // ui-literal-ok: debug-only gallery
    note: 'Not quite, and the right answer marked', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        DrillPage(request: _read, preset: const DrillPreset(choice: 2)),
    state: readingState,
  ),
  GalleryEntry(
    id: 'drill-reading-true-false',
    section: GallerySection.drills,
    label: 'Reading, true or false', // ui-literal-ok: debug-only gallery
    note: 'A statement about the passage, with Words', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: _read,
      preset: const DrillPreset(target: _home, questions: true),
    ),
    state: readingState,
  ),
  GalleryEntry(
    id: 'drill-reading-glossary',
    section: GallerySection.drills,
    label: 'Reading, words', // ui-literal-ok: debug-only gallery
    note: 'An older spelling and its form today', // ui-literal-ok: debug-only gallery
    builder: (_) => const _GlossaryPreview(),
    state: readingState,
  ),
  GalleryEntry(
    id: 'drill-reading-listening',
    section: GallerySection.drills,
    label: 'Reading, heard', // ui-literal-ok: debug-only gallery
    note: 'Read aloud, the text hidden', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(request: _heard),
    state: readingState,
  ),
  GalleryEntry(
    id: 'drill-reading-listening-answered',
    section: GallerySection.drills,
    label: 'Reading, heard and answered', // ui-literal-ok: debug-only gallery
    note: 'The text shows once answered', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        DrillPage(request: _heard, preset: const DrillPreset(choice: 1)),
    state: readingState,
  ),
  GalleryEntry(
    id: 'deck-reading',
    section: GallerySection.learn,
    label: 'Deck detail, reading', // ui-literal-ok: debug-only gallery
    note:
        'Its passages, with their sources', // ui-literal-ok: debug-only gallery
    builder: (_) => const DeckDetailPage(deckId: readingFixtureDeckId),
    state: readingState,
  ),
  GalleryEntry(
    id: 'settings-sources',
    section: GallerySection.progressAndSettings,
    label: 'Settings, sources', // ui-literal-ok: debug-only gallery
    note: 'The sources the decks name', // ui-literal-ok: debug-only gallery
    builder: (_) => const SettingsPage(),
    state: readingState,
  ),
];

final DrillRequest _read = DrillRequest.deck(
  readingFixtureDeckId,
  skill: Skill.reading,
);

final DrillRequest _heard = DrillRequest.deck(
  readingFixtureDeckId,
  skill: Skill.listening,
);

/// The fixture's second passage, by its first sentence.
const String _home = 'সে কাজ ক’রে বাড়ি যায়।';

/// The reading fixture, with a Bengali voice: what every reading state runs
/// on.
AppState readingState(AppState app) => AppState.test(
  decks: readingFixtureDecks(),
  tts: FixedTtsEngine(<String>{'bn'}),
  now: app.now(),
);

/// The second passage's glossary, as Words opens it.
class _GlossaryPreview extends StatelessWidget {
  const _GlossaryPreview();

  @override
  Widget build(BuildContext context) {
    final entry = AppScope.of(context).deckById(readingFixtureDeckId);
    return Scaffold(
      body: entry == null
          ? const SizedBox.shrink()
          : Glossary(
              passage: entry.deck.passages.last,
              language: entry.language,
            ),
    );
  }
}
