// What the offline admission audit decided for a course language
// (wiki/Plan-Placement-V3.md, "The question bank"): the item classes it
// excluded and the number of decoy units its word tiles carry. The app makes
// a language's bank in seconds by taking this instead of running the audit
// (which is the slow part, and gives the same answer every time for the same
// decks); a language with no entry is audited when its bank is made.
//
// The entries are checked against the real audit by
// `test/placement_v3_real_bank_test.dart`: a change of the decks or of a
// generator that changes the audit's answer fails it until the entry is
// regenerated (`dart run tool/placement_audit.dart`, which prints the line).
//
// Pure Dart.

/// The audit's verdict for one language.
class AdmissionProfile {
  const AdmissionProfile({required this.excluded, required this.decoys});

  /// The classes (`format:class`) that failed the audit, in the order
  /// `ItemBank.excluded` lists them (sorted as text: `F14` before `F1:`).
  final List<String> excluded;

  /// The decoy units of the word tiles (0 when none passed).
  final int decoys;

  bool admits(String auditClass) => !excluded.contains(auditClass);
}

/// The verdicts of the languages audited so far, by language code.
const Map<String, AdmissionProfile> kAdmissionProfiles =
    <String, AdmissionProfile>{
      'es': AdmissionProfile(
        excluded: <String>[
          'F17:cognate',
          'F5:cognate',
          'F6:clean',
          'F6g:clean',
          'S2:cognate',
        ],
        decoys: 2,
      ),
      'hi': AdmissionProfile(
        excluded: <String>[
          'F14:clean',
          'F17:cognate',
          'F1:clean',
          'F5:cognate',
          'S2:clean',
          'S2:cognate',
        ],
        decoys: 2,
      ),
    };
