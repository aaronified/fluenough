import 'package:flutter/widgets.dart';

import '../../app/app_state.dart';

/// The gallery's sections, in the design's order (Gallery.dc.html).
///
/// Debug-only text, so the titles are literals: see `GalleryEntry`.
enum GallerySection {
  profiles('Profiles and sign-in'), // ui-literal-ok: debug-only gallery
  learn('Learn'), // ui-literal-ok: debug-only gallery
  drills('Drills'), // ui-literal-ok: debug-only gallery
  progressAndSettings(
    'Progress and settings', // ui-literal-ok: debug-only gallery
  );

  const GallerySection(this.title);

  final String title;
}

/// One screen in one state, as the design's Gallery lists it.
///
/// Each feature lists its own in `lib/features/<feature>/gallery_entries.dart`,
/// so that no two builders edit the same list. The gallery is debug-only, so
/// [label] and [note] are literals rather than tokens: mark each line
/// `// ui-literal-ok: debug-only gallery`, which `tools/check_ui_strings.py`
/// allows.
class GalleryEntry {
  const GalleryEntry({
    required this.id,
    required this.section,
    required this.label,
    required this.note,
    required this.builder,
    this.state,
  });

  /// The design's screen id, its `start` value: `drill-production-accent`.
  final String id;

  final GallerySection section;

  /// What the design's Gallery calls it: "Production, accent missed".
  final String label;

  /// The design's caption: "Right, but mind the accent".
  final String note;

  /// Builds the screen. It runs inside its own `Navigator`, so pushing a
  /// route from it stays inside the preview.
  final WidgetBuilder builder;

  /// Builds the state the screen runs on, from the app's own, whose catalog
  /// is already loaded. Null runs it on `GalleryFixtures.state(app)`. See
  /// `lib/features/gallery/fixtures.dart`.
  final AppState Function(AppState app)? state;
}
