import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';
import '../gallery/gallery_entry.dart';

/// The grammar drill: lemma, gloss, the slot to fill, the typed form, and the
/// whole pattern table after answering. Built on fixtures and disabled until
/// the expander (#2) gives grammar decks cards; behind `Feature.drillGrammar`.
///
/// Design screen `drill-grammar`. A Phase 0 stub; B4 owns this file and may
/// change this widget's constructor freely: only [grammarGalleryEntries]
/// builds it. Use `DrillFrame`, `AnswerField` and `FeedbackBanner` from
/// `lib/ui/widgets` for the parts every drill shares.
class GrammarDrill extends StatelessWidget {
  const GrammarDrill({super.key});

  @override
  Widget build(BuildContext context) =>
      PlaceholderPage(title: AppLocalizations.of(context)!.skillGrammar);
}

/// B4's gallery entries for the grammar drill. `drill/gallery_entries.dart`
/// already includes them.
final List<GalleryEntry> grammarGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'drill-grammar',
    section: GallerySection.drills,
    label: 'Grammar, wrong', // ui-literal-ok: debug-only gallery
    note: 'Shows the whole table', // ui-literal-ok: debug-only gallery
    builder: (_) => const GrammarDrill(),
  ),
];
