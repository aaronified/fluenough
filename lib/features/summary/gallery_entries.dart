import '../../app/app_scope.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'summary_page.dart';

/// The session summary, as the design's Gallery lists it. Owned by B3.
final List<GalleryEntry> summaryGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'summary',
    section: GallerySection.drills,
    label: 'Session summary', // ui-literal-ok: debug-only gallery
    note: 'Score by skill', // ui-literal-ok: debug-only gallery
    builder: (context) => SummaryPage(
      result: GalleryFixtures.sessionResult(AppScope.read(context).now()),
    ),
  ),
];
