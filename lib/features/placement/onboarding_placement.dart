import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/placement.dart' show ScriptStanding;
import '../../app/placement_credit.dart';
import '../../core/scheduling/placed_review.dart';
import 'placement_page.dart';

/// "Find my level" for each language the learner chose to Learn on the first
/// launch, in turn, before the app opens (owner, 2026-11-02: "It should be
/// offered, and skippable to start at the beginning"). It is the same
/// placement as the languages page's, in the same review screen: "Do you know
/// any Hindi?" with Find my level, or Skip, which starts the language at the
/// beginning. What it finds is saved as that page saves it, and the offer is
/// over: [SettingsNotifier.placementOffers] is emptied, which swaps this for
/// the app (`lib/app.dart`).
class OnboardingPlacementOffer extends StatelessWidget {
  const OnboardingPlacementOffer({super.key, required this.languages});

  /// The language codes to offer, in the order the learner set them.
  final List<String> languages;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    return PlacementPage(
      languages: languages,
      skippable: true,
      // Answered already, on the skills sheet: Learn on Read or Write.
      alphabet: <String, bool>{
        for (final code in languages)
          if (state.hasAlphabet(code))
            code: state.settings.learnsAlphabet(code),
      },
      natives: <String, String>{
        for (final code in languages) code: ?state.courseNative(code),
      },
      onFinished: (found) => saveOnboardingPlacement(state, found),
    );
  }
}

/// Saves what placement [found] for the languages offered, as the languages
/// page saves a level found: the decks placed as known replace any before,
/// credited in the log, with the choice of how they are reviewed. A language
/// skipped places nothing. Then the offer is over.
void saveOnboardingPlacement(AppState state, PlacementFound found) {
  final settings = state.settings;
  for (final MapEntry(:key, :value) in found.natives.entries) {
    state.chooseNative(key, value);
  }
  for (final MapEntry(key: code, value: placed) in found.placed.entries) {
    if (placed.isEmpty) continue;
    final replaced = <String>{
      for (final entry in state.decks)
        if (entry.language.code == code) entry.id,
    };
    settings.placedDecks = <String>{
      for (final id in settings.placedDecks)
        if (!replaced.contains(id)) id,
      ...placed,
    };
    state.creditPlacement(
      code,
      placed: placed,
      standings: found.scripts[code] ?? const <String, ScriptStanding>{},
      native: state.courseNative(code),
    );
    settings.setPlacedReview(code, found.review[code] ?? PlacedReview.fallback);
  }
  settings.placementOffers = const <String>[];
}
