import '../review/facets.dart';

// The reviewer check (ADR-0058, decisions 1 and 2, work package W6;
// wiki/Plan-Reviewer-UX.md): the placement engine's items in a stricter mode,
// run to grant Provisional reviewer status for a course. This file holds the
// switch, the constants and the group and facet rules. Pure Dart.
//
// What leaves the phone: nothing but the coarse set of facets passed
// ([passedFacetsWire]), in the first review mail. No score, no count, no item.

/// The launch gate (Plan-Placement-V3, "Adversarial review and required
/// amendments"; ADR-0058, decision 1). The check ships OFF: no screen, row or
/// offer exists while this is false. It is switched on, by changing this one
/// constant, only after the persona replay and the adversarial retest of the
/// stricter mode (`test/reviewer_check_replay_test.dart`) have passed on the
/// decks that will ship, and a release carries it.
const bool kReviewerCheckEnabled = false;

/// Days before a course's check can be taken again (owner: "7-day cooldown
/// per course"). The new attempt asks fresh items.
const int kReviewerCheckCooldownDays = 7;

/// A group of items the check scores on its own: the skill a right answer is
/// evidence for.
enum ReviewerGroup {
  /// Written word, pick its meaning (F2, F27).
  read('read'),

  /// Meaning, pick the written word (F3): the word's spelling is what is
  /// picked, so this is the check's evidence for Write. No typed answer is
  /// ever asked (owner: a right answer must never be marked wrong).
  write('write'),

  /// Heard word, pick its meaning (F13, F26).
  hear('hear'),

  /// A sentence with a blank, pick the word of the right class (F28): the
  /// Read-plus-grammar evidence for unit placement and grammar notes.
  grammar('grammar');

  const ReviewerGroup(this.wire);

  /// The name in a record.
  final String wire;

  static ReviewerGroup? fromWire(Object? wire) {
    for (final group in values) {
      if (group.wire == wire) return group;
    }
    return null;
  }
}

/// The formats the check may ask, by group. Pick items only: no typed
/// answer, no tile sentence, no yes/no and no matching in this first build
/// (a yes/no pseudoword cannot be proved a non-word in every dialect, and
/// matching has no screen yet; both are allowed by the owner's rule and are
/// left for a later change).
const Map<String, ReviewerGroup> kReviewerFormats = <String, ReviewerGroup>{
  'F2': ReviewerGroup.read,
  'F27': ReviewerGroup.read,
  'F3': ReviewerGroup.write,
  'F13': ReviewerGroup.hear,
  'F26': ReviewerGroup.hear,
  'F28': ReviewerGroup.grammar,
};

/// How many scored items each group asks in a run.
const Map<ReviewerGroup, int> kReviewerItems = <ReviewerGroup, int>{
  ReviewerGroup.read: 28,
  ReviewerGroup.write: 28,
  ReviewerGroup.hear: 20,
  ReviewerGroup.grammar: 10,
};

/// Spare items each group may draw on when one is suspended or cannot be
/// played.
const int kReviewerReserve = 2;

/// The fewest scored items a group needs to be judged at all (suspended
/// items leave the score; a group left with fewer is "not enough").
const Map<ReviewerGroup, int> kReviewerMinScored = <ReviewerGroup, int>{
  ReviewerGroup.read: 24,
  ReviewerGroup.write: 24,
  ReviewerGroup.hear: 17,
  ReviewerGroup.grammar: 8,
};

/// The fewest distinct eligible cards a group needs in the top band for the
/// course to be offered the check at all. A course with fewer is "thin".
const Map<ReviewerGroup, int> kReviewerMinPool = <ReviewerGroup, int>{
  ReviewerGroup.read: 36,
  ReviewerGroup.write: 36,
  ReviewerGroup.hear: 26,
  ReviewerGroup.grammar: 14,
};

/// The chance a guesser may pass a group, the check's confidence target (it
/// replaces placement's 80% range). It is tested against the guess rates of
/// [reviewerNullGuess], which sit above the best solver the admission audit
/// measured.
const Map<ReviewerGroup, double> kReviewerAlpha = <ReviewerGroup, double>{
  ReviewerGroup.read: 0.01,
  ReviewerGroup.write: 0.01,
  ReviewerGroup.hear: 0.01,
  ReviewerGroup.grammar: 0.02,
};

/// The share of a group's scored items a reviewer must also get right, on
/// top of beating guessing: someone who knows half of the top band's words
/// beats a guesser but is not in the top band.
const double kReviewerMinAccuracy = 0.85;

/// How many items of a group "also right" may suspend and replace. Each
/// suspension beyond this counts as a miss against the group: the tap is a
/// safety valve for a flawed item, not a way to choose the scored items.
const int kReviewerMaxSuspended = 1;

/// How many items of a group may be left out because they could not be
/// played. More and the group is "not enough".
const int kReviewerMaxSkipped = 3;

/// The share of the path, up to the B1 milestone, that is the top band.
const double kReviewerTopBandShare = 0.25;

/// How many unscored pilot items a run carries.
const int kReviewerPilotSlots = 2;

/// How many past item ids a course remembers, so a retake is fresh.
const int kReviewerUsedMemory = 400;

/// The chance a guesser is assumed to answer one item of [format] right, as
/// the null of the group's test. A four-option pick is audited at about 0.26
/// for the best solver, so 0.35 leaves room for what the audit could not
/// find; a six-option look-alike pick is audited at 0.17.
double reviewerNullGuess(String format) => switch (format) {
  'F26' || 'F27' => 0.25,
  _ => 0.35,
};

/// The facets a Read and Write pass makes the reviewer eligible for.
const Set<Facet> kReadWriteFacets = <Facet>{
  Facet.word,
  Facet.meaning,
  Facet.example,
  Facet.note,
};

/// The facets a Hear pass adds (with Read and Write).
const Set<Facet> kHearFacets = <Facet>{Facet.reading, Facet.ipa, Facet.audio};

/// The facets a grammar pass adds (with Read); the grammar notes are the
/// [ReviewerEligibility.grammarNotes] flag.
const Set<Facet> kGrammarFacets = <Facet>{Facet.unitPlacement};

/// The facets of a card an item of [group] depends on: the key card must be
/// settled on each of these, among the facets it has.
Set<Facet> reviewerFacetsNeeded(ReviewerGroup group) => switch (group) {
  ReviewerGroup.hear => const <Facet>{Facet.word, Facet.meaning, Facet.reading},
  _ => const <Facet>{Facet.word, Facet.meaning},
};

/// What a passed check makes a reviewer eligible for, for one course.
class ReviewerEligibility {
  const ReviewerEligibility({
    this.facets = const <Facet>{},
    this.grammarNotes = false,
  });

  final Set<Facet> facets;

  /// Whether grammar notes are included (the Read-plus-grammar pass).
  final bool grammarNotes;

  /// Whether anything is passed: the check granted Provisional status.
  bool get passed => facets.isNotEmpty;

  /// The coarse flag the first review mail carries: facet names, sorted, and
  /// `grammar_notes` when included. Never a score.
  List<String> get passedFacetsWire => <String>[
    for (final facet in Facet.values)
      if (facets.contains(facet)) facet.wire,
    if (grammarNotes) 'grammar_notes',
  ];

  /// The eligibility a stored [wire] list stands for.
  static ReviewerEligibility fromWire(Object? wire) {
    if (wire is! List) return const ReviewerEligibility();
    final facets = <Facet>{};
    var grammar = false;
    for (final name in wire) {
      if (name == 'grammar_notes') {
        grammar = true;
        continue;
      }
      final facet = Facet.fromWire(name);
      if (facet != null) facets.add(facet);
    }
    return ReviewerEligibility(facets: facets, grammarNotes: grammar);
  }

  /// This and [other] together (a retake adds facets, never takes them).
  ReviewerEligibility union(ReviewerEligibility other) => ReviewerEligibility(
    facets: <Facet>{...facets, ...other.facets},
    grammarNotes: grammarNotes || other.grammarNotes,
  );
}

/// How a group ended.
enum ReviewerGroupStatus {
  /// Not asked (no pool, or no sound).
  notAsked,

  /// Too few scored items to judge.
  notEnough,

  /// Judged, not shown to beat guessing.
  notYet,

  /// Judged, beat guessing at the check's confidence.
  passed,
}

/// The eligibility the group statuses of a run give: the whole rule of
/// "Facet eligibility" in one place.
///
/// Read and Write together give word, meaning, example and notes; Hear on
/// top of them gives reading, IPA and audio; grammar with Read gives unit
/// placement and grammar notes. A self-rated Say never counts.
ReviewerEligibility eligibilityOf(
  Map<ReviewerGroup, ReviewerGroupStatus> status,
) {
  bool ok(ReviewerGroup g) => status[g] == ReviewerGroupStatus.passed;
  final facets = <Facet>{};
  if (ok(ReviewerGroup.read) && ok(ReviewerGroup.write)) {
    facets.addAll(kReadWriteFacets);
    if (ok(ReviewerGroup.hear)) facets.addAll(kHearFacets);
  }
  var grammar = false;
  if (ok(ReviewerGroup.read) && ok(ReviewerGroup.grammar)) {
    facets.addAll(kGrammarFacets);
    grammar = true;
  }
  return ReviewerEligibility(facets: facets, grammarNotes: grammar);
}
