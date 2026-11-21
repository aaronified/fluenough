/// What a second speaker is asked (ADR-0058, decision 7, work package W3):
/// the open check of another speaker's proposed fix, the pick among rival
/// fixes, and the per-unit digest of what changed or is contested. Pure
/// Dart.
///
/// The verdict on a card is blind: the card screen shows no earlier answer,
/// and nothing here is shown on it. A proposed fix is open: its original and
/// the proposal are shown together. The reason a first speaker gave is shown
/// only after the second speaker's own verdict, and never decides.
///
/// The other speakers' checks are the data shape of the flagged queue
/// ([OtherChecks]); the review bot does not publish them yet (W9), so until
/// then these are built, and tested, from fixtures.
library;

import '../models/card.dart';
import 'facet_text.dart';
import 'facets.dart';
import 'fix_text.dart';
import 'flagged_queue.dart';
import 'review_quorum.dart';
import 'review_session.dart';

/// What the reviewer is asked about one flagged or contested facet.
sealed class SecondSpeakerStep {
  const SecondSpeakerStep({
    required this.ref,
    required this.facet,
    required this.original,
    required this.tags,
  });

  final QueueCardRef ref;
  final Facet facet;

  /// What the card says now, as [seenTextOf] gives it.
  final String original;

  /// The tags put on the facet.
  final List<PointerTag> tags;
}

/// One speaker's proposed fix: "Accept", "Reject" or "Offer another".
final class ProposalStep extends SecondSpeakerStep {
  const ProposalStep({
    required super.ref,
    required super.facet,
    required super.original,
    required super.tags,
    required this.proposed,
  });

  final String proposed;
}

/// Speakers disagree about the fix: pick one of [fixes].
final class RivalStep extends SecondSpeakerStep {
  const RivalStep({
    required super.ref,
    required super.facet,
    required super.original,
    required super.tags,
    required this.fixes,
  });

  /// At least two, each once after normalisation, in the order proposed.
  final List<String> fixes;
}

/// A tag with no fix: the original, to be called right or fixed.
final class FlagStep extends SecondSpeakerStep {
  const FlagStep({
    required super.ref,
    required super.facet,
    required super.original,
    required super.tags,
  });
}

/// The fixes in [checks] that differ, one per speaker's latest flag, each
/// once after normalisation ([sameFixText]), in the order proposed.
/// [exceptRater] (a rater code, as given) is the reviewer asking: their own
/// fix is not a rival to themselves.
List<String> rivalFixesOf(Iterable<ReviewCheck> checks, {String? exceptRater}) {
  final latest = <String, ReviewCheck>{};
  for (final check in checks) {
    if (check.key.isNotEmpty) {
      latest.remove(check.key);
      latest[check.key] = check;
    }
  }
  final skip = exceptRater?.trim().toUpperCase();
  final out = <String>[];
  for (final check in latest.values) {
    if (check.key == skip || check.endorses) continue;
    final fix = check.answer!.replacement;
    if (fix == null || fix.isEmpty) continue;
    if (out.any((seen) => sameFixText(seen, fix))) continue;
    out.add(fix);
  }
  return out;
}

/// The steps of the flagged-only mode for [flagged], in facet order: for
/// each flagged or contested facet, a [RivalStep] when two or more other
/// speakers proposed different fixes, else a [ProposalStep] when there is a
/// fix, else a [FlagStep].
List<SecondSpeakerStep> stepsOfFlagged(
  FlaggedCard flagged,
  Card card,
  FlaggedSourceDeck deck,
  String? ownCode,
) {
  final ref = QueueCardRef(deckId: flagged.deckId, cardId: flagged.cardId);
  final out = <SecondSpeakerStep>[];
  for (final f in flagged.facets) {
    final original = seenTextOf(card, f.facet);
    final checks = deck.others[card.id]?[f.facet] ?? const <ReviewCheck>[];
    final rivals = rivalFixesOf(checks, exceptRater: ownCode);
    if (rivals.length >= 2) {
      out.add(
        RivalStep(
          ref: ref,
          facet: f.facet,
          original: original,
          tags: f.tags,
          fixes: rivals,
        ),
      );
    } else if (f.existingFix != null) {
      out.add(
        ProposalStep(
          ref: ref,
          facet: f.facet,
          original: original,
          tags: f.tags,
          proposed: f.existingFix!,
        ),
      );
    } else {
      out.add(
        FlagStep(ref: ref, facet: f.facet, original: original, tags: f.tags),
      );
    }
  }
  return out;
}

/// Why a digest row is there.
enum DigestKind {
  /// A fix is proposed or agreed.
  changed,

  /// Speakers disagree.
  contested,
}

/// One row of a unit's digest.
class DigestItem {
  const DigestItem({
    required this.ref,
    required this.facet,
    required this.kind,
    required this.before,
    this.after,
    this.reason,
  });

  final QueueCardRef ref;
  final Facet facet;
  final DigestKind kind;

  /// What the card says now.
  final String before;

  /// The proposed text, when there is one.
  final String? after;

  /// What a first speaker said as the reason: advisory, shown only after
  /// the second speaker's own verdict.
  final String? reason;

  /// A key for the row.
  String get id => '${ref.deckId}|${ref.cardId}|${facet.wire}';
}

/// The reasons first speakers gave, by card id and then facet.
typedef DigestReasons = Map<String, Map<Facet, String>>;

/// The digest of unit [number] of [source]: for every card of the unit and
/// every facet that applies to it, a row where another speaker's checks
/// ([FlaggedSourceDeck.others]) propose a fix or disagree, in path order.
/// Only others' checks count: what the reviewer said does not make a row.
List<DigestItem> digestOf(
  ReviewSource source,
  int number, {
  DigestReasons reasons = const <String, Map<Facet, String>>{},
}) {
  final out = <DigestItem>[];
  for (final ref in source.cardsOf(number)) {
    final found = source.find(ref);
    if (found == null) continue;
    final card = found.card;
    final deck = found.deck;
    final byFacet = deck.others[card.id];
    if (byFacet == null || byFacet.isEmpty) continue;
    final applicable = facetsOf(card, inUnit: deck.inUnit);
    for (final facet in Facet.values) {
      if (!applicable.contains(facet)) continue;
      final checks = byFacet[facet];
      if (checks == null || checks.isEmpty) continue;
      final status = facetStatus(checks);
      final fixes = rivalFixesOf(checks);
      final DigestKind kind;
      if (status == FacetStatus.contested) {
        kind = DigestKind.contested;
      } else if ((status == FacetStatus.agreedFix ||
              status == FacetStatus.flagged) &&
          fixes.isNotEmpty) {
        kind = DigestKind.changed;
      } else {
        continue;
      }
      out.add(
        DigestItem(
          ref: ref,
          facet: facet,
          kind: kind,
          before: seenTextOf(card, facet),
          after: fixes.firstOrNull,
          reason: reasons[card.id]?[facet],
        ),
      );
    }
  }
  return out;
}
