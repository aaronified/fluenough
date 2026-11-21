/// The flagged queue (ADR-0058, decision 5 and 10, work package W4): the
/// cards with a facet that a reviewer flagged and nobody has resolved, or
/// that reviewers disagree about, and how a reviewer resolves one. Pure
/// Dart.
///
/// A facet is flagged when it has a pointer tag and no fix two reviewers
/// agree on, contested when its reviewers disagree ([facetStatus]). The
/// queue only reads; an answer goes through [Reviews] like any other facet
/// answer, with [FlaggedResolution.answerFor] making it.
library;

import '../models/card.dart';
import 'deck_review.dart';
import 'facet_compare.dart';
import 'facets.dart';
import 'fix_text.dart';
import 'review_pairs.dart';
import 'review_problems.dart';
import 'review_quorum.dart';
import 'review_receipt.dart';

/// The other reviewers' checks of a deck's cards, by card id and then
/// facet: what the downloaded decks and the sent reviews say. The review
/// bot does not publish them yet (W9), so until then it is empty and the
/// queue holds the reviewer's own flags.
typedef OtherChecks = Map<String, Map<Facet, List<ReviewCheck>>>;

/// One deck as the queue reads it.
class FlaggedSourceDeck {
  const FlaggedSourceDeck({
    required this.deckId,
    required this.pair,
    required this.cards,
    this.others = const <String, Map<Facet, List<ReviewCheck>>>{},
    this.inUnit = true,
  });

  final String deckId;

  /// The course the deck belongs to; only decks of a course the reviewer may
  /// review are listed.
  final ReviewPair pair;
  final List<Card> cards;
  final OtherChecks others;

  /// Whether the cards sit in a path unit ([facetsOf]).
  final bool inUnit;
}

/// A facet of a card that is flagged or contested.
class FlaggedFacet {
  const FlaggedFacet({
    required this.facet,
    required this.status,
    required this.tags,
    this.existingFix,
  });

  final Facet facet;

  /// [FacetStatus.flagged] or [FacetStatus.contested].
  final FacetStatus status;

  /// Every tag put on the facet, in [PointerTag]'s order.
  final List<PointerTag> tags;

  /// The replacement text a flagging reviewer proposed (the latest one),
  /// which another reviewer may agree with; null when none gave one.
  final String? existingFix;

  bool get isContested => status == FacetStatus.contested;
}

/// A card with at least one flagged or contested facet.
class FlaggedCard {
  const FlaggedCard({
    required this.deckId,
    required this.cardId,
    required this.pair,
    required this.facets,
  });

  final String deckId;
  final String cardId;
  final ReviewPair pair;

  /// In [Facet]'s order; never empty.
  final List<FlaggedFacet> facets;

  /// Contested when any facet is, else flagged: the row's pill.
  bool get isContested => facets.any((f) => f.isContested);

  /// The tags of the flagged facets, each once, for a row's reason; the
  /// contested facets are named by their facet instead ([contestedFacets]).
  List<PointerTag> get flaggedTags => <PointerTag>[
    for (final tag in PointerTag.values)
      if (facets.any((f) => !f.isContested && f.tags.contains(tag))) tag,
  ];

  /// The contested facets, in [Facet]'s order.
  List<Facet> get contestedFacets => <Facet>[
    for (final f in facets)
      if (f.isContested) f.facet,
  ];

  /// The facet to open first.
  FlaggedFacet get first => facets.first;
}

/// The flagged queue of the courses a reviewer may review.
class FlaggedQueue {
  const FlaggedQueue(this.cards);

  static const FlaggedQueue empty = FlaggedQueue(<FlaggedCard>[]);

  /// Deck by deck in the order given, cards in deck order.
  final List<FlaggedCard> cards;

  /// The tab's badge: the cards, not the facets.
  int get count => cards.length;

  bool get isEmpty => cards.isEmpty;

  /// The queue of [decks]: for each deck of a course in [allowed], each card
  /// with a facet flagged or contested, from [reviews] (this reviewer's own
  /// answers, sent or not, as [ownCode]) and the deck's [FlaggedSourceDeck.others].
  /// A malformed entry is reported and skipped, never throws.
  static FlaggedQueue build({
    required Iterable<FlaggedSourceDeck> decks,
    required Set<ReviewPair> allowed,
    required Reviews reviews,
    required String? ownCode,
  }) {
    final out = <FlaggedCard>[];
    for (final deck in decks) {
      if (!allowed.contains(deck.pair)) continue;
      for (final card in deck.cards) {
        try {
          final flagged = _flaggedFacets(deck, card, reviews, ownCode);
          if (flagged.isNotEmpty) {
            out.add(
              FlaggedCard(
                deckId: deck.deckId,
                cardId: card.id,
                pair: deck.pair,
                facets: flagged,
              ),
            );
          }
        } on Object catch (e) {
          ReviewProblems.report('flagged queue: card ${card.id}: $e');
        }
      }
    }
    return FlaggedQueue(List<FlaggedCard>.unmodifiable(out));
  }

  static List<FlaggedFacet> _flaggedFacets(
    FlaggedSourceDeck deck,
    Card card,
    Reviews reviews,
    String? ownCode,
  ) {
    final own = reviews.card(deck.deckId, card.id)?.facets;
    final others = deck.others[card.id];
    if ((own == null || own.isEmpty) && (others == null || others.isEmpty)) {
      return const <FlaggedFacet>[];
    }
    final applicable = facetsOf(card, inUnit: deck.inUnit);
    final result = <FlaggedFacet>[];
    for (final facet in Facet.values) {
      if (!applicable.contains(facet)) continue;
      final checks = <ReviewCheck>[
        ...?others?[facet],
        if (ownCode != null && own?[facet] != null)
          ReviewCheck(rater: ownCode, answer: own![facet]),
      ];
      if (checks.isEmpty) continue;
      final status = facetStatus(
        checks,
        language: languageOfFacet(facet, deck.pair),
      );
      if (status != FacetStatus.flagged && status != FacetStatus.contested) {
        continue;
      }
      result.add(_describe(facet, status, checks));
    }
    return result;
  }

  static FlaggedFacet _describe(
    Facet facet,
    FacetStatus status,
    List<ReviewCheck> checks,
  ) {
    final latest = <String, ReviewCheck>{};
    for (final check in checks) {
      if (check.key.isNotEmpty) latest[check.key] = check;
    }
    final flags = latest.values.where((c) => !c.endorses).toList();
    final tags = <PointerTag>{for (final c in flags) ...c.answer!.tags};
    String? fix;
    for (final c in flags) {
      if (c.answer!.hasReplacement) fix = c.answer!.replacement;
    }
    return FlaggedFacet(
      facet: facet,
      status: status,
      tags: <PointerTag>[
        for (final tag in PointerTag.values)
          if (tags.contains(tag)) tag,
      ],
      existingFix: fix,
    );
  }
}

/// How a reviewer answers a flagged facet.
enum FlaggedResolution {
  /// "It is right": the flag is not shared.
  right,

  /// Offer a fix of their own.
  offerFix,

  /// Agree with the fix already offered.
  agreeWithFix,
}

/// A reviewer's answer on a flagged facet, as it goes into the review: the
/// [answer] stored for the facet, and the [decision] its receipt records.
class FlaggedAnswer {
  const FlaggedAnswer(this.answer, this.decision);

  final FacetAnswer answer;
  final ReceiptDecision decision;
}

/// The answer [how] gives on [flagged], or null when it cannot be made:
/// [FlaggedResolution.offerFix] without [fix] text, or
/// [FlaggedResolution.agreeWithFix] when no fix was offered.
///
/// An agreement is the same flag and the same fix text as the existing one,
/// which [facetStatus] counts as agreement once normalised; a fix of the
/// reviewer's own that differs makes the facet contested. The result goes
/// to `Reviewing.answerFacet`, the path every facet answer takes.
FlaggedAnswer? resolveFlagged(
  FlaggedFacet flagged,
  FlaggedResolution how, {
  String? fix,
}) {
  switch (how) {
    case FlaggedResolution.right:
      return const FlaggedAnswer(FacetAnswer.right(), ReceiptDecision.right);
    case FlaggedResolution.offerFix:
      final text = fix?.trim();
      if (text == null || text.isEmpty || flagged.tags.isEmpty) return null;
      final same = flagged.existingFix;
      final isOther = same == null || !sameFixText(same, text);
      return FlaggedAnswer(
        FacetAnswer.flagged(flagged.tags.toSet(), replacement: text),
        isOther ? ReceiptDecision.offeredOther : ReceiptDecision.accepted,
      );
    case FlaggedResolution.agreeWithFix:
      final text = flagged.existingFix;
      if (text == null || flagged.tags.isEmpty) return null;
      return FlaggedAnswer(
        FacetAnswer.flagged(flagged.tags.toSet(), replacement: text),
        ReceiptDecision.accepted,
      );
  }
}
