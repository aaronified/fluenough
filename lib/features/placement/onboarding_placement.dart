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
/// placement as the languages page's, in the same review screen, and asks
/// nothing the skills sheet did not ("Language choice itself is now unified.
/// Use the new paradigm.").
///
/// Under the first question of each language is **Start at the beginning**:
/// it places nothing, saves nothing for that language, and goes on to the
/// next, or the app. The header's close button is different: it stops the
/// check where it is and keeps what was found so far: the levels and decks
/// already passed, and nothing where none was. Each language's result is saved as soon as it
/// is done, and the language leaves [SettingsNotifier.placementOffers] as the
/// learner goes on from it, so leaving the app between two does not offer the
/// first again. When the last has gone, `lib/app.dart` swaps this for the app.
class OnboardingPlacementOffer extends StatefulWidget {
  const OnboardingPlacementOffer({super.key, required this.languages});

  /// The language codes to offer, in the order the learner set them.
  final List<String> languages;

  @override
  State<OnboardingPlacementOffer> createState() =>
      _OnboardingPlacementOfferState();
}

class _OnboardingPlacementOfferState extends State<OnboardingPlacementOffer> {
  /// The offer as it began: the settings' list shrinks as each is done, and
  /// the page places the languages it was given.
  late final List<String> _languages = widget.languages;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    return PlacementPage(
      languages: _languages,
      skippable: true,
      // Answered already, on the skills sheet: Learn on Read or Write.
      alphabet: <String, bool>{
        for (final code in _languages)
          if (state.hasAlphabet(code))
            code: state.settings.learnsAlphabet(code),
      },
      onLanguageDone: (code, found, {required leaving}) {
        saveLanguagePlacement(state, found);
        if (leaving) {
          state.settings.placementOffers = <String>[
            for (final offered in state.settings.placementOffers)
              if (offered != code) offered,
          ];
        }
      },
      onFinished: (_) {},
    );
  }
}

/// Saves what placement [found], as the languages page saves a level found:
/// the decks placed as known replace any before, credited in the log, with
/// the choice of how they are reviewed. A language that placed nothing, as
/// one skipped, saves nothing: it starts at its beginning. The language the
/// course is taught from is not touched: only the learner's own choice sets
/// it.
void saveLanguagePlacement(AppState state, PlacementFound found) {
  final settings = state.settings;
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
}
