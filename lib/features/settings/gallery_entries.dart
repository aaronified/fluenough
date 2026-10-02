import '../../app.dart';
import '../../app/shell_tab.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'appearance_page.dart';
import 'settings_fixtures.dart';
import 'voices_page.dart';

/// Settings, Appearance and Voices, as the design's Gallery lists them.
/// Owned by B5.
///
/// Settings runs the whole shell, as this version ships it. Appearance runs
/// with every feature on, as the design draws it; `appearance-incoming` below
/// is how this version shows it. Voices has Spanish installed and Japanese
/// missing.
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
    state: SettingsFixtures.appearanceLive,
  ),
  GalleryEntry(
    id: 'voices',
    section: GallerySection.progressAndSettings,
    label: 'Voices', // ui-literal-ok: debug-only gallery
    note: 'Which languages can speak', // ui-literal-ok: debug-only gallery
    builder: (_) => const VoicesPage(),
  ),
];

/// Settings, Appearance and Voices in their other notable states.
///
/// The gallery lists them after the design's screens, and
/// `test/features/settings/` pumps each of them.
final List<GalleryEntry> settingsGalleryStates = <GalleryEntry>[
  GalleryEntry(
    id: 'settings-all-on',
    section: GallerySection.progressAndSettings,
    label: 'Settings, every feature on', // ui-literal-ok: debug-only gallery
    note: 'Reminder time, PIN, export, app language', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: (app) =>
        SettingsFixtures.allOn(app)..shellTab.value = ShellTab.settings,
  ),
  GalleryEntry(
    id: 'appearance-incoming',
    section: GallerySection.progressAndSettings,
    label: 'Appearance, this version', // ui-literal-ok: debug-only gallery
    note: 'Wallpaper colours incoming', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppearancePage(),
  ),
  GalleryEntry(
    id: 'voices-checking',
    section: GallerySection.progressAndSettings,
    label: 'Voices, checking', // ui-literal-ok: debug-only gallery
    note: 'The phone has not answered yet', // ui-literal-ok: debug-only gallery
    builder: (_) => const VoicesPage(),
    state: SettingsFixtures.voicesChecking,
  ),
  GalleryEntry(
    id: 'voices-none',
    section: GallerySection.progressAndSettings,
    label: 'Voices, no decks', // ui-literal-ok: debug-only gallery
    note: 'Nothing to check', // ui-literal-ok: debug-only gallery
    builder: (_) => const VoicesPage(),
    state: SettingsFixtures.noDecks,
  ),
];
