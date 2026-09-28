import '../../app.dart';
import '../gallery/gallery_entry.dart';

/// Today, as the design's Gallery lists it. Owned by B3.
///
/// Runs the whole shell, so the navigation bar shows as it does in the app.
final List<GalleryEntry> todayGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'today',
    section: GallerySection.learn,
    label: 'Today', // ui-literal-ok: debug-only gallery
    note: 'Due cards by skill, streak', // ui-literal-ok: debug-only gallery
    builder: (_) => const AppShell(),
  ),
];
