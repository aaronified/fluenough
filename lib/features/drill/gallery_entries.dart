import '../../app/session.dart';
import '../../app/skill.dart';
import '../gallery/gallery_entry.dart';
import 'drill_page.dart';
import 'grammar_drill.dart';
import 'pair_drill.dart';

/// The drills, as the design's Gallery lists them. Owned by B1, except for
/// grammar and minimal pairs, which B4 lists in `grammar_drill.dart` and
/// `pair_drill.dart` and which are spliced in here already.
///
/// Each drill entry needs a preset — a card at a phase, with an answer typed
/// — which B1 adds to `DrillPage` as optional parameters.
final List<GalleryEntry> drillGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'drill-recognition',
    section: GallerySection.drills,
    label: 'Recognition', // ui-literal-ok: debug-only gallery
    note: 'See it, recall the meaning', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('es-core-100', skill: Skill.recognition),
    ),
  ),
  GalleryEntry(
    id: 'drill-recognition-revealed',
    section: GallerySection.drills,
    label: 'Recognition, self-grade', // ui-literal-ok: debug-only gallery
    note: 'Again, Hard, Good, Easy', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('es-core-100', skill: Skill.recognition),
    ),
  ),
  GalleryEntry(
    id: 'drill-production-accent',
    section: GallerySection.drills,
    label: 'Production, accent missed', // ui-literal-ok: debug-only gallery
    note: 'Right, but mind the accent', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('es-core-100', skill: Skill.production),
    ),
  ),
  GalleryEntry(
    id: 'drill-production-typo',
    section: GallerySection.drills,
    label: 'Production, near miss', // ui-literal-ok: debug-only gallery
    note: 'You judge a one-letter slip', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('es-core-100', skill: Skill.production),
    ),
  ),
  GalleryEntry(
    id: 'drill-production-script',
    section: GallerySection.drills,
    label: 'Production, own keyboard', // ui-literal-ok: debug-only gallery
    note: 'Type in the script; HeliBoard suggested', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('ja-hiragana', skill: Skill.production),
    ),
  ),
  GalleryEntry(
    id: 'drill-production-translit',
    section: GallerySection.drills,
    label: 'Production, transliteration', // ui-literal-ok: debug-only gallery
    note:
        'Type it in Latin letters instead', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('ja-hiragana', skill: Skill.production),
    ),
  ),
  GalleryEntry(
    id: 'drill-listening',
    section: GallerySection.drills,
    label: 'Listening', // ui-literal-ok: debug-only gallery
    note: 'Phone voice, slower option', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('es-core-100', skill: Skill.listening),
    ),
  ),
  ...grammarGalleryEntries,
  ...pairGalleryEntries,
  GalleryEntry(
    id: 'drill-rtl',
    section: GallerySection.drills,
    label: 'Right to left', // ui-literal-ok: debug-only gallery
    note: 'Needs an rtl: true fixture deck until Urdu lands (#40)', // ui-literal-ok: debug-only gallery
    builder: (_) => const DrillPage(request: DrillRequest.today()),
  ),
];
