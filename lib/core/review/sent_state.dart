/// What became of a suggestion the reviewer sent (#471,
/// the reviewer mode mockup, section 1), worked out from the deck files
/// on the phone alone: the phone keeps what was sent, not the review bot's
/// answer, so it reads the deck.
///
/// Never carries a rater code: a state is a count, never a person.
library;

import '../models/proposal.dart';
import 'deck_review.dart';

/// Where a sent suggestion stands.
enum SentOutcome {
  /// The field now says what the suggestion said.
  accepted,

  /// The field has changed another way: the proposal is gone and the field
  /// says neither what it said then nor what was suggested.
  rejected,

  /// The proposal is still in the deck, short of the acceptances it needs.
  waiting,

  /// The phone cannot tell: the part is one the review bot does not turn
  /// into proposals, or the downloaded deck does not carry the proposal
  /// yet.
  unknown,
}

/// Why the phone cannot tell, for an [SentOutcome.unknown].
enum SentUnknown {
  /// An example, a picture, a base or an "Also heard": the owner decides.
  notTracked,

  /// The deck on the phone has neither the proposal nor a changed field:
  /// the review mail may not be in a deck update yet, or the deck is gone
  /// from the phone.
  notInDeckYet,
}

class SentState {
  const SentState(this.outcome, {this.moreNeeded = 0, this.unknown});

  final SentOutcome outcome;

  /// For [SentOutcome.waiting], how many more acceptances it needs: at
  /// least 0, which means enough have accepted and the deck update is next.
  final int moreNeeded;

  /// For [SentOutcome.unknown], why.
  final SentUnknown? unknown;

  @override
  bool operator ==(Object other) =>
      other is SentState &&
      other.outcome == outcome &&
      other.moreNeeded == moreNeeded &&
      other.unknown == unknown;

  @override
  int get hashCode => Object.hash(outcome, moreNeeded, unknown);

  @override
  String toString() => 'SentState($outcome, $moreNeeded, $unknown)';
}

/// The proposal field a suggestion on [part] becomes, or null for a part
/// the review bot does not turn into proposals (ADR-0038).
ProposalField? proposalFieldOf(CardPart part) => switch (part) {
  CardPart.word => ProposalField.target,
  CardPart.reading => ProposalField.reading,
  CardPart.ipa => ProposalField.ipa,
  CardPart.meaning => ProposalField.native,
  CardPart.notes => ProposalField.notes,
  _ => null,
};

/// The state of [suggestion], sent by the reviewer whose rater code is
/// [code], when the card's field says [current] ("" when it has none, null
/// when the card is not on the phone) and [proposals] are the card's
/// proposals in the deck files on the phone. [agreementsNeeded] is how many
/// other reviewers must accept a proposal.
SentState sentStateOf({
  required Suggestion suggestion,
  required String? current,
  required List<Proposal> proposals,
  required String? code,
  required int agreementsNeeded,
}) {
  final field = proposalFieldOf(suggestion.part);
  if (field == null) {
    return const SentState(
      SentOutcome.unknown,
      unknown: SentUnknown.notTracked,
    );
  }
  for (final p in proposals) {
    if (p.field == field &&
        p.text.trim() == suggestion.text.trim() &&
        (code == null || p.by == code)) {
      final more = agreementsNeeded - p.accepted.length;
      return SentState(SentOutcome.waiting, moreNeeded: more < 0 ? 0 : more);
    }
  }
  if (current == null) {
    return const SentState(
      SentOutcome.unknown,
      unknown: SentUnknown.notInDeckYet,
    );
  }
  if (current.trim() == suggestion.text.trim()) {
    return const SentState(SentOutcome.accepted);
  }
  if (current.trim() == suggestion.now.trim()) {
    return const SentState(
      SentOutcome.unknown,
      unknown: SentUnknown.notInDeckYet,
    );
  }
  return const SentState(SentOutcome.rejected);
}
