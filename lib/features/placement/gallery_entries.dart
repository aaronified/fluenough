import 'dart:math';

import '../../app/app_state.dart';
import '../../app/settings.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'language_picker_page.dart';
import 'picker_fixtures.dart';
import 'placement_page.dart';

/// The first launch of a learner who speaks English.
AppState _firstLaunch(AppState app) => GalleryFixtures.state(
  app,
  settings: SettingsNotifier(spokenLanguages: const <String>['en']),
);

/// The design's profile Aro, learning Hindi and Spanish, past the first
/// launch: the picker opened from Settings.
AppState _learner(AppState app) => GalleryFixtures.state(
  app,
  settings: SettingsNotifier(spokenLanguages: const <String>['en'])
    ..learningChosen = true,
);

/// Choosing what to learn and placement (#117), as first launch shows them
/// after the languages the learner speaks.
final List<GalleryEntry> placementGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'learn-languages',
    section: GallerySection.profiles,
    label: 'What to learn', // ui-literal-ok: debug-only gallery
    note: 'First launch, after the languages you know', // ui-literal-ok: debug-only gallery
    builder: (_) => const LanguagePickerPage(firstRun: true),
    state: _firstLaunch,
  ),
  GalleryEntry(
    id: 'picker-settings',
    section: GallerySection.profiles,
    label: 'Languages I’m learning', // ui-literal-ok: debug-only gallery
    note: 'From Settings: Learning, then Available', // ui-literal-ok: debug-only gallery
    builder: (_) => const LanguagePickerPage(),
    state: _learner,
  ),
  GalleryEntry(
    id: 'picker-search',
    section: GallerySection.profiles,
    label: 'Languages, searching', // ui-literal-ok: debug-only gallery
    note: '“hi” finds Hindi and Marathi', // ui-literal-ok: debug-only gallery
    builder: (_) => const LanguagePickerPage(initialQuery: 'hi'),
    state: _learner,
  ),
  GalleryEntry(
    id: 'picker-search-accents',
    section: GallerySection.profiles,
    label: 'Languages, accents ignored', // ui-literal-ok: debug-only gallery
    note: '“espanol” finds Español', // ui-literal-ok: debug-only gallery
    builder: (_) => const LanguagePickerPage(
      initialQuery: 'espanol',
      ownNames: <String, String>{'es': 'Español'},
    ),
    state: _learner,
  ),
  GalleryEntry(
    id: 'picker-no-match',
    section: GallerySection.profiles,
    label: 'Languages, no match', // ui-literal-ok: debug-only gallery
    note: 'Only languages with decks are listed', // ui-literal-ok: debug-only gallery
    builder: (_) => const LanguagePickerPage(initialQuery: 'tamil'),
    state: _learner,
  ),
  GalleryEntry(
    id: 'picker-script',
    section: GallerySection.profiles,
    label: 'Languages, the script', // ui-literal-ok: debug-only gallery
    note: 'Kannada with its script, Marathi in Latin letters', // ui-literal-ok: debug-only gallery
    builder: (_) => const LanguagePickerPage(
      firstRun: true,
      initialChosen: <String>{'kn', 'mr'},
      initialScript: <String, bool>{'mr': false},
    ),
    state: _firstLaunch,
  ),
  GalleryEntry(
    id: 'picker-alpha',
    section: GallerySection.profiles,
    label: 'Languages, an alpha course', // ui-literal-ok: debug-only gallery
    note: 'Spanish, little written yet', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        const LanguagePickerPage(firstRun: true, initialChosen: <String>{'es'}),
    state: _firstLaunch,
  ),
  GalleryEntry(
    id: 'picker-taught-from',
    section: GallerySection.profiles,
    label: 'Languages, taught from two', // ui-literal-ok: debug-only gallery
    note: 'Illustrative: Telugu from Bengali or Hindi', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        const LanguagePickerPage(firstRun: true, initialChosen: <String>{'te'}),
    state: PickerFixtures.taughtFromTwo,
  ),
  GalleryEntry(
    id: 'picker-taught-from-three',
    section: GallerySection.profiles,
    label: 'Languages, taught from three', // ui-literal-ok: debug-only gallery
    note: 'Illustrative: three, still side by side', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        const LanguagePickerPage(firstRun: true, initialChosen: <String>{'te'}),
    state: PickerFixtures.taughtFromThree,
  ),
  GalleryEntry(
    id: 'picker-taught-from-list',
    section: GallerySection.profiles,
    label: 'Languages, taught from four', // ui-literal-ok: debug-only gallery
    note: 'Illustrative: more than three, a list in a sheet', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        const LanguagePickerPage(firstRun: true, initialChosen: <String>{'te'}),
    state: PickerFixtures.taughtFromFour,
  ),
  GalleryEntry(
    id: 'picker-on-phone',
    section: GallerySection.profiles,
    label: 'Languages, on the phone', // ui-literal-ok: debug-only gallery
    note: 'With deck downloads, from Settings', // ui-literal-ok: debug-only gallery
    builder: (_) => const LanguagePickerPage(),
    state: PickerFixtures.onPhone,
  ),
  GalleryEntry(
    id: 'picker-downloading',
    section: GallerySection.profiles,
    label: 'Languages, downloading', // ui-literal-ok: debug-only gallery
    note: 'Kannada, not ready yet', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        const LanguagePickerPage(firstRun: true, initialChosen: <String>{'kn'}),
    state: PickerFixtures.downloading,
  ),
  GalleryEntry(
    id: 'picker-ready',
    section: GallerySection.profiles,
    label: 'Languages, ready to start', // ui-literal-ok: debug-only gallery
    note: 'Continue is on, the rest keeps coming', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        const LanguagePickerPage(firstRun: true, initialChosen: <String>{'kn'}),
    state: PickerFixtures.ready,
  ),
  GalleryEntry(
    id: 'picker-offline',
    section: GallerySection.profiles,
    label: 'Languages, no connection', // ui-literal-ok: debug-only gallery
    note: 'The bar stops, Try again', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        const LanguagePickerPage(firstRun: true, initialChosen: <String>{'kn'}),
    state: PickerFixtures.offline,
  ),
  GalleryEntry(
    id: 'picker-cancelled',
    section: GallerySection.profiles,
    label: 'Languages, download cancelled', // ui-literal-ok: debug-only gallery
    note: 'The rest from Settings, Deck downloads', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        const LanguagePickerPage(firstRun: true, initialChosen: <String>{'kn'}),
    state: PickerFixtures.cancelled,
  ),
  GalleryEntry(
    id: 'placement-alphabet',
    section: GallerySection.profiles,
    label: 'Placement, the alphabet', // ui-literal-ok: debug-only gallery
    note: 'Learn the alphabet, or Latin letters only (#47)', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        PlacementPage(languages: const <String>['hi'], onFinished: (_) {}),
  ),
  GalleryEntry(
    id: 'placement-ask',
    section: GallerySection.profiles,
    label: 'Placement, asked', // ui-literal-ok: debug-only gallery
    note: 'Find my level, or start from the beginning', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        PlacementPage(languages: const <String>['es'], onFinished: (_) {}),
  ),
  GalleryEntry(
    id: 'placement-check',
    section: GallerySection.profiles,
    label: 'Placement, checking', // ui-literal-ok: debug-only gallery
    note: 'A word from the first part of the course', // ui-literal-ok: debug-only gallery
    builder: (_) => PlacementPage(
      languages: const <String>['hi'],
      onFinished: (_) {},
      random: Random(1),
      checking: true,
    ),
  ),
];
