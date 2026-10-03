import '../../app.dart';
import '../../app/shell_tab.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'deck_detail_page.dart';
import 'import_fixture.dart';
import 'import_page.dart';
import 'inspect_page.dart';

/// Decks, a deck, and Add a deck, as the design's Gallery lists them. Owned
/// by B2.
///
/// The design's deck is Hindi Core, which is not on this branch (#41), so
/// `deck` shows Spanish Core for Aro, with a Spanish voice. `deck-novoice` is
/// Japanese for Mira, whose language the fixture engine has no voice for.
/// `import-error` shows a real parser error, from `importErrorFixture`.
final List<GalleryEntry> decksGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'decks',
    section: GallerySection.learn,
    label: 'Decks', // ui-literal-ok: debug-only gallery
    note: 'Search and language filter', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: (app) => GalleryFixtures.state(app)..shellTab.value = ShellTab.decks,
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
    builder: (_) => const DeckDetailPage(deckId: 'ja-en-hiragana'),
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
    note: 'File, link, CSV or Anki', // ui-literal-ok: debug-only gallery
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
