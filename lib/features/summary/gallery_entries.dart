import '../../app/app_scope.dart';
import '../../app/session.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'summary_page.dart';

/// The session summary, as the design's Gallery lists it. Owned by B3.
///
/// The design's seven answers over four minutes, on Aro's fixture history, so
/// the streak and what is due tomorrow are computed from real reviews.
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

/// The summary's other notable state, waiting for Phase 2 to splice it into
/// the gallery for the same reason as `todayGalleryStates`.
final List<GalleryEntry> summaryGalleryStates = <GalleryEntry>[
  GalleryEntry(
    id: 'summary-empty',
    section: GallerySection.drills,
    label: 'Session summary, empty', // ui-literal-ok: debug-only gallery
    note: 'Ended before any answer', // ui-literal-ok: debug-only gallery
    builder: (context) {
      final now = AppScope.read(context).now();
      return SummaryPage(
        result: SessionResult(
          answers: const <SessionAnswer>[],
          startedAt: now,
          endedAt: now,
        ),
      );
    },
  ),
];
