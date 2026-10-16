import '../gallery/gallery_entry.dart';
import '../placement/language_picker_page.dart';
import 'download_fixtures.dart';
import 'download_page.dart';

/// Deck downloads (#210): Languages I'm learning with an update waiting,
/// where deck updates now live (#467), and the first decks of a language
/// with no network.
final List<GalleryEntry> downloadsGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'learning-deck-updates',
    section: GallerySection.progressAndSettings,
    label: 'Languages I’m learning, deck updates', // ui-literal-ok: debug-only gallery
    note: 'An update waiting for Hindi', // ui-literal-ok: debug-only gallery
    builder: (_) => const LanguagePickerPage(),
    state: DownloadFixtures.updateWaiting,
  ),
  GalleryEntry(
    id: 'downloads-offline',
    section: GallerySection.profiles,
    label: 'Getting your decks, offline', // ui-literal-ok: debug-only gallery
    note: 'No connection, Try again', // ui-literal-ok: debug-only gallery
    builder: (_) => const DownloadPage(languages: <String>['es']),
    state: DownloadFixtures.offline,
  ),
];
