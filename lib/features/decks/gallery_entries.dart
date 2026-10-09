import '../../app.dart';
import '../../app/shell_tab.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'deck_detail_page.dart';
import 'import_fixture.dart';
import 'import_page.dart';
import 'decks_page.dart';
import 'inspect_page.dart';
import 'path_fixture.dart';
import 'unit_page.dart';

/// Decks, a unit, a deck, and Add a deck, as the design's Gallery lists
/// them. Owned by B2.
///
/// The path's entries are Aro learning Telugu (`PathFixtures`), as the
/// owner's design draws it; all but `decks`, which is the tab as it ships,
/// pass the design's plan of levels and coming units, which no path marks
/// yet.
///
/// The design's deck is Hindi Core, which is not on this branch (#41), so
/// `deck` shows Spanish Core for Aro, with a Spanish voice. `deck-novoice` is
/// Marathi for Mira, whose language the fixture engine has no voice for.
/// `import-error` shows a real parser error, from `importErrorFixture`.
final List<GalleryEntry> decksGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'decks',
    section: GallerySection.learn,
    label: 'Decks: the path', // ui-literal-ok: debug-only gallery
    note: 'Opens where you are', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: (app) => PathFixtures.state(app)..shellTab.value = ShellTab.decks,
  ),
  GalleryEntry(
    id: 'decks-levels',
    section: GallerySection.learn,
    label: 'Decks: toward B1', // ui-literal-ok: debug-only gallery
    note:
        'Levels, milestones, coming units', // ui-literal-ok: debug-only gallery
    builder: (_) => const DecksPage(planOf: PathFixtures.planOf),
    state: PathFixtures.state,
  ),
  GalleryEntry(
    id: 'decks-a1-earned',
    section: GallerySection.learn,
    label: 'Decks: A1 earned', // ui-literal-ok: debug-only gallery
    note: 'A CEFR level as an achievement', // ui-literal-ok: debug-only gallery
    builder: (_) => const DecksPage(planOf: PathFixtures.planOf),
    state: (app) => PathFixtures.state(app, upTo: 'te-en-market'),
  ),
  GalleryEntry(
    id: 'decks-another-course',
    section: GallerySection.learn,
    label: 'Decks: another course', // ui-literal-ok: debug-only gallery
    note: 'Course chips switch the path', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        const DecksPage(planOf: PathFixtures.planOf, initialLanguage: 'hi'),
    state: PathFixtures.state,
  ),
  GalleryEntry(
    id: 'decks-search',
    section: GallerySection.learn,
    label: 'Decks: search', // ui-literal-ok: debug-only gallery
    note: 'Units across courses', // ui-literal-ok: debug-only gallery
    builder: (_) => const DecksPage(
      planOf: PathFixtures.planOf,
      initialQuery: 'family', // ui-literal-ok: debug-only gallery
    ),
    state: PathFixtures.state,
  ),
  GalleryEntry(
    id: 'unit',
    section: GallerySection.learn,
    label: 'Unit: Family', // ui-literal-ok: debug-only gallery
    note: 'Words, then rules, then sentences', // ui-literal-ok: debug-only gallery
    builder: (_) => const UnitPage(
      deckId: PathFixtures.familyDeck,
      plan: PathFixtures.telugu,
    ),
    state: PathFixtures.state,
  ),
  GalleryEntry(
    id: 'unit-word',
    section: GallerySection.learn,
    label: 'Unit: a word\'s card', // ui-literal-ok: debug-only gallery
    note: 'With the sound-alike warning', // ui-literal-ok: debug-only gallery
    builder: (_) => const UnitPage(
      deckId: 'te-en-sound-differences',
      plan: PathFixtures.telugu,
      openWord: PathFixtures.soundAlikeCard,
    ),
    state: PathFixtures.state,
  ),
  GalleryEntry(
    id: 'deck',
    section: GallerySection.learn,
    label: 'Deck detail', // ui-literal-ok: debug-only gallery
    note: 'Start one skill or all due', // ui-literal-ok: debug-only gallery
    builder: (_) => const DeckDetailPage(deckId: 'es-en-core-100'),
  ),
  GalleryEntry(
    id: 'deck-novoice',
    section: GallerySection.learn,
    label: 'Deck, no voice', // ui-literal-ok: debug-only gallery
    note: 'Listening disabled, with a way to fix it', // ui-literal-ok: debug-only gallery
    builder: (_) => const DeckDetailPage(deckId: 'mr-en-script-consonants'),
    state: (app) => GalleryFixtures.state(app, currentProfileId: 'mira'),
  ),
  GalleryEntry(
    id: 'inspect',
    section: GallerySection.learn,
    label: 'Inspect a deck', // ui-literal-ok: debug-only gallery
    note:
        'Every card in full, with its id', // ui-literal-ok: debug-only gallery
    builder: (_) => const InspectPage(deckId: 'hi-en-market'),
  ),
  GalleryEntry(
    id: 'inspect-grammar',
    section: GallerySection.learn,
    label: 'Inspect a grammar deck', // ui-literal-ok: debug-only gallery
    note: 'Each table whole, a cell id per form', // ui-literal-ok: debug-only gallery
    builder: (_) => const InspectPage(deckId: 'hi-en-grammar-present'),
  ),
  GalleryEntry(
    id: 'inspect-reading',
    section: GallerySection.learn,
    label: 'Inspect a reading deck', // ui-literal-ok: debug-only gallery
    note: 'Passages, questions with answers, glossary', // ui-literal-ok: debug-only gallery
    builder: (_) => const InspectPage(deckId: 'bn-en-reading-sahaj-path-1'),
  ),
  GalleryEntry(
    id: 'import',
    section: GallerySection.learn,
    label: 'Add a deck', // ui-literal-ok: debug-only gallery
    note: 'File, link or CSV', // ui-literal-ok: debug-only gallery
    builder: (_) => const ImportPage(),
  ),
  GalleryEntry(
    id: 'import-error',
    section: GallerySection.learn,
    label: 'Add a deck, error', // ui-literal-ok: debug-only gallery
    note: 'Line number and the fix', // ui-literal-ok: debug-only gallery
    builder: (_) => ImportPage(
      initialUrl: 'https://example.org/decks/$importErrorFixtureFile', // ui-literal-ok: debug-only gallery
      error: importErrorFixture(),
    ),
  ),
];
