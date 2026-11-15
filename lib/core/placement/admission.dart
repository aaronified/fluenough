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
// A language holds one verdict per deck source (`AdmissionProfile.source`): the
// frozen decks bundled under main's `decks/` and the live decks the apps
// download from `decks-live` (#1270). Each has its own key, so a change of one
// source's decks leaves the other's verdict intact, and a phone on live decks
// is not left without one.
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
    this.source = kFrozenDecks,
  });

  /// Which decks the verdict was made on: [kFrozenDecks] (main's `decks/`) or
  /// [kLiveDecks] (`decks-live`). Only a label for people; [of] picks by
  /// [deckKey], so a source nobody has audited costs nothing.
  final String source;

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

  /// The verdict stored for [data]'s language, if one was made on these decks
  /// (whichever source). [profiles] is for tests; the app uses
  /// [kAdmissionProfiles].
  static AdmissionProfile? of(
    PlacementLanguageData data, [
    Map<String, List<AdmissionProfile>> profiles = kAdmissionProfiles,
  ]) {
    final entries = profiles[data.language];
    if (entries == null || entries.isEmpty) return null;
    final key = admissionKey(data);
    for (final profile in entries) {
      if (profile.deckKey == key) return profile;
    }
    return null;
  }
}

/// [AdmissionProfile.source] of main's frozen `decks/`.
const String kFrozenDecks = 'frozen';

/// [AdmissionProfile.source] of the live decks (`decks-live`).
const String kLiveDecks = 'live';

/// The verdicts of the languages audited so far, by language code: one entry
/// per deck source that has been audited.
const Map<String, List<AdmissionProfile>> kAdmissionProfiles =
    <String, List<AdmissionProfile>>{
      'es': <AdmissionProfile>[
        AdmissionProfile(
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
      ],
      'hi': <AdmissionProfile>[
        AdmissionProfile(
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
      ],
    };
