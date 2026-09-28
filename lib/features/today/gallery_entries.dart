import '../../app.dart';
import '../gallery/gallery_entry.dart';
import 'today_fixtures.dart';

/// Today, as the design's Gallery lists it. Owned by B3.
///
/// Runs the whole shell, so the navigation bar shows as it does in the app.
/// The design's own state: Aro, mid-streak, with cards due.
final List<GalleryEntry> todayGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'today',
    section: GallerySection.learn,
    label: 'Today', // ui-literal-ok: debug-only gallery
    note: 'Due cards by skill, streak', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
  ),
];

/// Today's other notable states.
///
/// Not in the gallery's list yet: `test/gallery_test.dart` holds that list to
/// exactly the design's screen ids, so these wait for Phase 2 to splice them
/// into `allGalleryEntries`. `test/features/today/` pumps each of them.
final List<GalleryEntry> todayGalleryStates = <GalleryEntry>[
  GalleryEntry(
    id: 'today-fresh',
    section: GallerySection.learn,
    label: 'Today, first day', // ui-literal-ok: debug-only gallery
    note: 'No name, no streak, new cards only', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: todayFreshState,
  ),
  GalleryEntry(
    id: 'today-all-done',
    section: GallerySection.learn,
    label: 'Today, all done', // ui-literal-ok: debug-only gallery
    note: 'Session finished, streak kept', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: todayAllDoneState,
  ),
  GalleryEntry(
    id: 'today-no-voice',
    section: GallerySection.learn,
    label: 'Today, no voice', // ui-literal-ok: debug-only gallery
    note: 'Listening explains itself and opens Voices', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: todayNoVoiceState,
  ),
];
