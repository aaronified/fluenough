import '../../app.dart';
import '../../app/profile.dart';
import '../../app/settings.dart';
import '../gallery/fixtures.dart';
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
/// The gallery lists them after the design's screens, and
/// `test/features/today/` pumps each of them.
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
    id: 'today-adjusted',
    section: GallerySection.learn,
    label: 'Today, adjusted to you', // ui-literal-ok: debug-only gallery
    note: 'The settled strip, marks on the tiles', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: (app) => GalleryFixtures.adjusted(GalleryFixtures.state(app)),
  ),
  GalleryEntry(
    id: 'today-one-language',
    section: GallerySection.learn,
    label: 'Today, one language shown', // ui-literal-ok: debug-only gallery
    note: 'The language bar on Spanish, of two', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: todayOneLanguageState,
  ),
  GalleryEntry(
    id: 'today-eight-languages',
    section: GallerySection.learn,
    label: 'Today, eight languages', // ui-literal-ok: debug-only gallery
    note: 'The language bar scrolls, its ends faded', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: (app) => GalleryFixtures.state(
      app,
      // Aro, learning the languages chosen here rather than her two.
      profiles: const <Profile>[Profile(id: 'aro', name: 'Aro')],
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>[
          'hi',
          'bn',
          'te',
          'mr',
          'gu',
          'kn',
          'as',
          'es',
        ],
        learningChosen: true,
        languageChoice: 'gu',
      ),
    ),
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
