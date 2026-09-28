import '../../app.dart';
import '../../app/features.dart';
import '../../app/shell_tab.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'leeches_page.dart';

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
    state: (app) =>
        GalleryFixtures.state(app, features: FeatureRegistry.all())
          ..shellTab.value = ShellTab.progress,
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
