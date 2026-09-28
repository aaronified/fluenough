import '../../app.dart';
import '../../app/shell_tab.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'appearance_page.dart';
import 'voices_page.dart';

/// Settings, Appearance and Voices, as the design's Gallery lists them.
/// Owned by B5.
final List<GalleryEntry> settingsGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'settings',
    section: GallerySection.progressAndSettings,
    label: 'Settings', // ui-literal-ok: debug-only gallery
    note:
        'Learning, sound, reminder, data', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: (app) =>
        GalleryFixtures.state(app)..shellTab.value = ShellTab.settings,
  ),
  GalleryEntry(
    id: 'appearance',
    section: GallerySection.progressAndSettings,
    label: 'Appearance', // ui-literal-ok: debug-only gallery
    note: 'Theme, colour, contrast, text size', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppearancePage(),
  ),
  GalleryEntry(
    id: 'voices',
    section: GallerySection.progressAndSettings,
    label: 'Voices', // ui-literal-ok: debug-only gallery
    note: 'Which languages can speak', // ui-literal-ok: debug-only gallery
    builder: (_) => const VoicesPage(),
  ),
];
