import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';
import '../gallery/gallery_entry.dart';

/// The minimal-pairs drill: hear one of two similar sounds, pick which.
/// Built on fixtures and disabled until #31 gives it an ADR, deck data shaped
/// `{a, b, contrast}` and a device check; behind `Feature.drillPair`.
///
/// Design screen `drill-pair`. A Phase 0 stub; B4 owns this file and may
/// change this widget's constructor freely: only [pairGalleryEntries] builds
/// it. Use `DrillFrame`, `PlayButton` and `FeedbackBanner` from
/// `lib/ui/widgets` for the parts every drill shares.
class PairDrill extends StatelessWidget {
  const PairDrill({super.key});

  @override
  Widget build(BuildContext context) =>
      PlaceholderPage(title: AppLocalizations.of(context)!.skillPair);
}

/// B4's gallery entries for minimal pairs. `drill/gallery_entries.dart`
/// already includes them.
final List<GalleryEntry> pairGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'drill-pair',
    section: GallerySection.drills,
    label: 'Minimal pairs', // ui-literal-ok: debug-only gallery
    note: 'Aspirated or not', // ui-literal-ok: debug-only gallery
    builder: (_) => const PairDrill(),
  ),
];
