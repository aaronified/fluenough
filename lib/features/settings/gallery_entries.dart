import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app/shell_tab.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'appearance_page.dart';
import 'backup_section.dart';
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
    id: 'settings-update-available',
    section: GallerySection.progressAndSettings,
    label: 'Settings, update available', // ui-literal-ok: debug-only gallery
    note: 'Download, and a dot on the tab', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: SettingsFixtures.updateAvailable,
  ),
  GalleryEntry(
    id: 'settings-update-current',
    section: GallerySection.progressAndSettings,
    label: 'Settings, up to date', // ui-literal-ok: debug-only gallery
    note: 'Nothing newer on GitHub', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: SettingsFixtures.upToDate,
  ),
  GalleryEntry(
    id: 'settings-update-checking',
    section: GallerySection.progressAndSettings,
    label:
        'Settings, checking for updates', // ui-literal-ok: debug-only gallery
    note: 'GitHub has not answered yet', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: SettingsFixtures.updateChecking,
  ),
  GalleryEntry(
    id: 'settings-update-failed',
    section: GallerySection.progressAndSettings,
    label: 'Settings, update check failed', // ui-literal-ok: debug-only gallery
    note: 'Offline, with Try again', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: SettingsFixtures.updateFailed,
  ),
  GalleryEntry(
    id: 'settings-update-downloading',
    section: GallerySection.progressAndSettings,
    label:
        'Settings, downloading an update', // ui-literal-ok: debug-only gallery
    note: 'Its progress, in the row', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: SettingsFixtures.updateDownloading,
  ),
  GalleryEntry(
    id: 'settings-update-installing',
    section: GallerySection.progressAndSettings,
    label:
        'Settings, installing an update', // ui-literal-ok: debug-only gallery
    note: "Android's installer is open", // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: SettingsFixtures.updateInstalling,
  ),
  GalleryEntry(
    id: 'settings-update-not-allowed',
    section: GallerySection.progressAndSettings,
    label: 'Settings, update not allowed', // ui-literal-ok: debug-only gallery
    note: 'How to allow installs, and the download page', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
    state: SettingsFixtures.updateNotAllowed,
  ),
  GalleryEntry(
    id: 'settings-backup',
    section: GallerySection.progressAndSettings,
    label: 'Back up to the cloud', // ui-literal-ok: debug-only gallery
    note: 'Five services, each incoming (#139)', // ui-literal-ok: debug-only gallery
    builder: (_) => const Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.all(16),
          child: BackupSection(),
        ),
      ),
    ),
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
