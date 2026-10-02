import 'dart:math';

import '../gallery/gallery_entry.dart';
import 'learn_languages_page.dart';
import 'placement_page.dart';

/// Choosing what to learn and placement (#117), as first launch shows them
/// after the languages the learner speaks.
final List<GalleryEntry> placementGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'learn-languages',
    section: GallerySection.profiles,
    label: 'What to learn', // ui-literal-ok: debug-only gallery
    note: 'First launch, after the languages you speak', // ui-literal-ok: debug-only gallery
    builder: (_) => const LearnLanguagesPage(firstRun: true),
  ),
  GalleryEntry(
    id: 'placement-ask',
    section: GallerySection.profiles,
    label: 'Placement, asked', // ui-literal-ok: debug-only gallery
    note: 'Find my level, or start from the beginning', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        PlacementPage(languages: const <String>['hi'], onFinished: (_) {}),
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
