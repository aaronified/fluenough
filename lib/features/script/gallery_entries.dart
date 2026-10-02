import '../../core/models/deck.dart';
import '../../core/models/script_guide.dart';
import '../gallery/gallery_entry.dart';
import 'script_guide_page.dart';

// Debug-only (the gallery is registered only when kDebugMode), so the
// sample guide's text is literal, each line marked for the gate.

const LanguageInfo _bengali = LanguageInfo(
  code: 'bn',
  iso639_3: 'ben',
  name: 'Bengali', // ui-literal-ok: debug-only gallery
  script: 'bengali',
  tts: 'bn-IN',
);

/// A short sample, so the screen shows in the gallery whatever guides the
/// bundled decks carry.
const ScriptGuide _sample = ScriptGuide(
  language: 'bn',
  name: 'How Bengali script works', // ui-literal-ok: debug-only gallery
  intro: 'A few ideas come back in letter after letter.', // ui-literal-ok: debug-only gallery
  features: <ScriptFeature>[
    ScriptFeature(
      id: 'headline',
      name: 'The headline', // ui-literal-ok: debug-only gallery
      term: 'মাত্রা',
      reading: 'matra', // ui-literal-ok: debug-only gallery
      example: 'ক',
      text: 'Most letters hang from a line along the top.', // ui-literal-ok: debug-only gallery
      letters: <String>['ক', 'ঘ', 'ত', 'ন'],
    ),
    ScriptFeature(
      id: 'knot',
      name: 'The knot', // ui-literal-ok: debug-only gallery
      term: 'গুটলি',
      reading: 'gutli', // ui-literal-ok: debug-only gallery
      example: 'ত',
      text: 'A small loop that tells look-alike letters apart.', // ui-literal-ok: debug-only gallery
      letters: <String>['ক', 'খ', 'ত', 'ল'],
    ),
  ],
);

/// The script guide (#30, ADR-0016).
final List<GalleryEntry> scriptGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'script-guide',
    section: GallerySection.learn,
    label: 'Script guide', // ui-literal-ok: debug-only gallery
    note: 'Before the first letters, or from Tips', // ui-literal-ok: debug-only gallery
    builder: (context) => ScriptGuideView(
      guide: _sample,
      language: _bengali,
      actionLabel: 'Start the letters', // ui-literal-ok: debug-only gallery
      onAction: () {},
      onClose: () {},
    ),
  ),
];
