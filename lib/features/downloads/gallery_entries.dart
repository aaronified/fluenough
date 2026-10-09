import '../gallery/gallery_entry.dart';
import 'deck_downloads_page.dart';
import 'download_fixtures.dart';
import 'download_page.dart';

/// Deck downloads (#210): Settings > Deck downloads with an update waiting,
/// and the first decks of a language with no network.
final List<GalleryEntry> downloadsGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'deck-downloads',
    section: GallerySection.progressAndSettings,
    label: 'Deck downloads', // ui-literal-ok: debug-only gallery
    note: 'An update waiting for Hindi', // ui-literal-ok: debug-only gallery
    builder: (_) => const DeckDownloadsPage(),
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
