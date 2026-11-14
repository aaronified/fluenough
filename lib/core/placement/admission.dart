import 'placement_data.dart';

// What the offline admission audit decided for a course language
// (wiki/Plan-Placement-V3.md, "The question bank"): the item classes it
// excluded and the number of decoy units its word tiles carry, for the items
// the app makes (`ItemBank.buildItems`) from one set of decks. The app takes
// this instead of running the audit (the slow part of making a bank, which
// gives the same answer for the same decks and generators); a language with no
// entry, or whose decks are not the ones audited, is audited when its bank is
// made, and its run begins on the whole bank.
//
// The entries are checked against the real audit of the app's own output by
// `test/placement_v3_real_bank_test.dart`: a change of the decks or of a
// generator that changes the audit's answer fails it until the entry is
// regenerated (`dart run tool/placement_audit.dart --runtime`, which prints
// the entry).
//
// Pure Dart.

/// A key of the decks a verdict was made on: the decks in path order with
/// every card's id, word and meaning (FNV-1a), so that an edited card, not
/// only an added one, makes the verdict stale. It does not include what a
/// learner has already learned (`stableCardIds`), which a verdict does not
/// depend on.
String admissionKey(PlacementLanguageData data) {
  var hash = 0x811c9dc5;
  void mix(String text) {
    for (final unit in text.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    hash = ((hash ^ 0x1f) * 0x01000193) & 0xffffffff;
  }

  for (final deck in data.decks) {
    mix(deck.id);
    for (final card in deck.cards) {
      mix(card.id);
      mix(card.target);
      mix(card.native);
    }
  }
  return '${data.decks.length}-${hash.toRadixString(16)}';
}

/// The audit's verdict for one language on one set of decks.
class AdmissionProfile {
  const AdmissionProfile({
    required this.deckKey,
    required this.excluded,
    required this.decoys,
  });

  /// [admissionKey] of the decks it was made on.
  final String deckKey;

  /// The classes (`format:class`) the app makes that failed the audit, in
  /// the order `ItemBank.excluded` lists them (sorted as text: `F14` before
  /// `F1:`). Classes the app never makes (word order, matching, cloze,
  /// gender) are not here.
  final List<String> excluded;

  /// The decoy units of the word tiles (0 when none passed).
  final int decoys;

  bool admits(String auditClass) => !excluded.contains(auditClass);

  /// The verdict stored for [data]'s language, if it was made on these decks.
  static AdmissionProfile? of(PlacementLanguageData data) {
    final profile = kAdmissionProfiles[data.language];
    return profile != null && profile.deckKey == admissionKey(data)
        ? profile
        : null;
  }
}

/// The verdicts of the languages audited so far, by language code.
const Map<String, AdmissionProfile> kAdmissionProfiles =
    <String, AdmissionProfile>{
      'es': AdmissionProfile(
        deckKey: '171-5453385b',
        excluded: <String>[
          'F17:clean',
          'F17:cognate',
          'F28:cognate',
          'F5:clean',
          'F5:cognate',
        ],
        decoys: 2,
      ),
      'hi': AdmissionProfile(
        deckKey: '139-84ae5a22',
        excluded: <String>[
          'F14:clean',
          'F17:clean',
          'F1:clean',
          'F28:clean',
          'F28:cognate',
          'F5:clean',
        ],
        decoys: 2,
      ),
    };
