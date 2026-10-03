import '../../app/app_state.dart';
import '../../app/session.dart';
import '../../app/settings.dart';
import '../../app/skill.dart';
import '../../core/speech/speech_engine.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'drill_page.dart';
import 'drill_preset.dart';
import 'drill_session.dart';
import 'grammar_drill.dart';
import 'pair_drill.dart';
import 'reading_gallery_entries.dart';
import 'rtl_fixture.dart';

/// The drills, as the design's Gallery lists them. Owned by B1, except for
/// grammar and minimal pairs, which B4 lists in `grammar_drill.dart` and
/// `pair_drill.dart` and which are spliced in here already.
///
/// Each entry is a real session on the bundled decks, started part-way by a
/// [DrillPreset]. The design draws Hindi; this branch has no Hindi deck yet
/// (#41), so the script states use Japanese. The presets find their cards
/// by target text, never by id.
final List<GalleryEntry> drillGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'drill-recognition',
    section: GallerySection.drills,
    label: 'Recognition', // ui-literal-ok: debug-only gallery
    note: 'See it, recall the meaning', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('ja-en-hiragana', skill: Skill.recognition),
    ),
  ),
  GalleryEntry(
    id: 'drill-recognition-revealed',
    section: GallerySection.drills,
    label: 'Recognition, self-grade', // ui-literal-ok: debug-only gallery
    note: 'Again, Hard, Good, Easy', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('es-en-core-100', skill: Skill.recognition),
      preset: const DrillPreset(target: 'la casa', reveal: true),
    ),
  ),
  GalleryEntry(
    id: 'drill-production-accent',
    section: GallerySection.drills,
    label: 'Production, accent missed', // ui-literal-ok: debug-only gallery
    note: 'Right, but mind the accent', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('es-en-core-100', skill: Skill.production),
      preset: const DrillPreset(
        target: 'el niño',
        typed: 'el nino',
        check: true,
      ),
    ),
  ),
  GalleryEntry(
    id: 'drill-production-typo',
    section: GallerySection.drills,
    label: 'Production, near miss', // ui-literal-ok: debug-only gallery
    note: 'You judge a one-letter slip', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('es-en-core-100', skill: Skill.production),
      preset: const DrillPreset(
        target: 'la ventana',
        typed: 'la ventna',
        check: true,
      ),
    ),
  ),
  GalleryEntry(
    id: 'drill-production-script',
    section: GallerySection.drills,
    label: 'Production, own keyboard', // ui-literal-ok: debug-only gallery
    note: 'Type in the script; HeliBoard suggested', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('ja-en-hiragana', skill: Skill.production),
      preset: const DrillPreset(target: 'か'),
    ),
  ),
  GalleryEntry(
    id: 'drill-production-translit',
    section: GallerySection.drills,
    label: 'Production, transliteration', // ui-literal-ok: debug-only gallery
    note: 'Latin letters instead (#47)', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('ja-en-hiragana', skill: Skill.production),
      preset: const DrillPreset(
        target: 'か',
        typed: 'ka',
        inputMode: InputMode.translit,
      ),
    ),
  ),
  GalleryEntry(
    id: 'drill-listening',
    section: GallerySection.drills,
    label: 'Listening', // ui-literal-ok: debug-only gallery
    note: 'Phone voice, slower option', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('es-en-core-100', skill: Skill.listening),
    ),
  ),
  GalleryEntry(
    id: 'drill-speaking',
    section: GallerySection.drills,
    label: 'Speaking', // ui-literal-ok: debug-only gallery
    note: 'See the meaning, say the word (#89)', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck('es-en-core-100', skill: Skill.speaking),
    ),
    state: speakingOn,
  ),
  ...grammarGalleryEntries,
  ...pairGalleryEntries,
  ...readingGalleryEntries,
  GalleryEntry(
    id: 'drill-rtl',
    section: GallerySection.drills,
    label: 'Right to left', // ui-literal-ok: debug-only gallery
    note: 'An rtl: true fixture deck until Urdu lands (#40)', // ui-literal-ok: debug-only gallery
    builder: (_) => DrillPage(
      request: DrillRequest.deck(rtlFixtureDeckId, skill: Skill.production),
      preset: const DrillPreset(target: 'کتاب', typed: 'کتاب', check: true),
    ),
    state: (app) => AppState.test(decks: rtlFixtureDecks(), now: app.now()),
  ),
];

/// Speaking switched on, with a recogniser that hears Spanish and Hindi on
/// the phone and has the microphone already: the speaking drill's gallery
/// state.
AppState speakingOn(AppState app) => GalleryFixtures.state(
  app,
  speech: FixedSpeechEngine(onDevice: <String>{'es', 'hi'}, granted: true),
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningChosen: true,
    enabledSkills: Skill.values.toSet(),
  ),
);
