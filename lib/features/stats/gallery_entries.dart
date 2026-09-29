import '../../app.dart';
import '../../app/app_state.dart';
import '../../app/features.dart';
import '../../app/shell_tab.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'leeches.dart';
import 'leeches_page.dart';
import 'stats_numbers.dart';

/// Progress and leeches, as the design's Gallery lists them. Owned by B7.
///
/// Both run with every feature on, so they show the built screens on the
/// fixture history rather than the tab's incoming state.
final List<GalleryEntry> statsGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'stats',
    section: GallerySection.progressAndSettings,
    label: 'Progress', // ui-literal-ok: debug-only gallery
    note: 'From the review log', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: (app) => _onProgress(
      GalleryFixtures.state(app, features: FeatureRegistry.all()),
    ),
  ),
  GalleryEntry(
    id: 'leeches',
    section: GallerySection.progressAndSettings,
    label: 'Leeches', // ui-literal-ok: debug-only gallery
    note: 'Reset or set aside', // ui-literal-ok: debug-only gallery
    builder: (_) => const LeechesPage(),
    state: (app) => GalleryFixtures.state(app, features: FeatureRegistry.all()),
  ),
];

/// States the design does not draw, listed in the gallery after the
/// design's own Progress and Leeches entries.
final List<GalleryEntry> statsGalleryStates = <GalleryEntry>[
  GalleryEntry(
    id: 'stats-incoming',
    section: GallerySection.progressAndSettings,
    label: 'Progress, as shipped', // ui-literal-ok: debug-only gallery
    note: 'Incoming until #18', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: (app) => _onProgress(GalleryFixtures.state(app)),
  ),
  GalleryEntry(
    id: 'stats-empty',
    section: GallerySection.progressAndSettings,
    label: 'Progress, no reviews', // ui-literal-ok: debug-only gallery
    note: 'Before the first session', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: (app) => _onProgress(
      GalleryFixtures.state(
        app,
        features: FeatureRegistry.all(),
        history: false,
      ),
    ),
  ),
  GalleryEntry(
    id: 'stats-leeches-incoming',
    section: GallerySection.progressAndSettings,
    label: 'Progress before #19', // ui-literal-ok: debug-only gallery
    note: 'Leeches row incoming', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: (app) => _onProgress(
      GalleryFixtures.state(app, features: const FeatureRegistry.shipped()),
    ),
  ),
  GalleryEntry(
    id: 'leeches-acted',
    section: GallerySection.progressAndSettings,
    label: 'Leeches, one reset', // ui-literal-ok: debug-only gallery
    note: 'Dimmed, with Undo', // ui-literal-ok: debug-only gallery
    builder: (_) => const LeechesPage(),
    state: (app) {
      final state = GalleryFixtures.state(app, features: FeatureRegistry.all());
      // The new state loads later; [app] shares its catalog and is loaded.
      final first = findLeeches(
        state.progress,
        cardOf: cardLookupOf(app),
      ).first;
      LeechActions.of(state.progress).toggleReset(first.key, now: state.now());
      return state;
    },
  ),
  GalleryEntry(
    id: 'leeches-empty',
    section: GallerySection.progressAndSettings,
    label: 'Leeches, none', // ui-literal-ok: debug-only gallery
    note: 'Nothing missed often', // ui-literal-ok: debug-only gallery
    builder: (_) => const LeechesPage(),
    state: (app) => GalleryFixtures.state(
      app,
      features: FeatureRegistry.all(),
      history: false,
    ),
  ),
];

AppState _onProgress(AppState state) =>
    state..shellTab.value = ShellTab.progress;
