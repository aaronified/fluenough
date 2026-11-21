import '../models/card.dart';
import '../review/facets.dart';
import '../review/review_quorum.dart';
import 'item_registry.dart';
import 'placement_data.dart';
import 'reviewer_check_rules.dart';

// The item bank of the reviewer check (ADR-0058, decision 2): the placement
// registry's items, admitted again under the owner's stricter rule.
//
// "Do not use any question type where a right answer can be marked wrong,
// even a 1% chance is too bad." So only picks are asked; the key comes only
// from a card two distinct reviewers have checked (or from a fix two
// reviewers agreed on); every distractor is proved to be a different word
// with no meaning in common with the key; and what risk is left is made
// harmless by the run (no feedback, an "also right" tap, no single miss
// decides). Pure Dart.

/// Where an item's key came from.
enum ReviewerItemTier {
  /// Built from fix history: the agreed fix is the key, the old form is a
  /// distractor two reviewers agreed was wrong.
  gold,

  /// The key card is checked twice on the facets the item depends on.
  checked,

  /// New: passes every rule but its key card is not checked twice. Asked
  /// unscored in a pilot slot until [ItemPromotion] promotes it.
  pilot,
}

/// One item the check may ask.
class ReviewerItem {
  const ReviewerItem({
    required this.item,
    required this.group,
    required this.tier,
  });

  final RegItem item;
  final ReviewerGroup group;
  final ReviewerItemTier tier;

  String get id => item.id;

  /// The chance a guesser answers it right: the null of the group's test.
  double get nullGuess => reviewerNullGuess(item.format);

  /// The keys two items must not share in one run (card and lemma).
  Set<String> get conflictKeys => item.conflictKeys;
}

// ------------------------------------------------------------ the pilot slot

/// What the Verified reviewers said of one pilot item.
class PilotTally {
  const PilotTally({this.verified = 0, this.agreeing = 0});

  /// Verified responses.
  final int verified;

  /// How many of them picked the key.
  final int agreeing;
}

/// What a tally says to do with a pilot item.
enum PilotVerdict { keepPiloting, promote, retire }

/// Verified responses an item needs before it is judged ("about 8").
const int kPilotResponses = 8;

/// The agreement that promotes an item.
const double kPilotPromoteAt = 0.9;

/// A split between these shares retires an item as dialect-sensitive
/// ("about 60/40").
const double kPilotSplitLow = 0.4;
const double kPilotSplitHigh = 0.6;

/// The verdict on [tally]: promote at [kPilotResponses] responses with
/// [kPilotPromoteAt] or more agreeing; retire a 60/40 split as
/// dialect-sensitive; otherwise keep piloting.
PilotVerdict judgePilot(PilotTally tally) {
  if (tally.verified < kPilotResponses) return PilotVerdict.keepPiloting;
  final share = tally.agreeing / tally.verified;
  if (share >= kPilotPromoteAt) return PilotVerdict.promote;
  if (share >= kPilotSplitLow && share <= kPilotSplitHigh) {
    return PilotVerdict.retire;
  }
  return PilotVerdict.keepPiloting;
}

/// Which pilot items have been promoted or retired. The Verified population
/// that fills it does not exist yet (the owner mints the first signed keys),
/// so nothing is promoted by default: [NoItemPromoted], and the check runs
/// on the gold items and the twice-checked cards alone.
abstract interface class ItemPromotion {
  /// Whether the pilot item [itemId] now counts toward the score.
  bool isPromoted(String itemId);

  /// Whether the pilot item [itemId] is retired and never asked again.
  bool isRetired(String itemId);
}

/// The default: no item is promoted, none retired.
class NoItemPromoted implements ItemPromotion {
  const NoItemPromoted();

  @override
  bool isPromoted(String itemId) => false;

  @override
  bool isRetired(String itemId) => false;
}

/// Promotion decided by [judgePilot] over tallies kept somewhere else (a
/// ledger the Verified reviewers' responses will fill).
class TallyPromotion implements ItemPromotion {
  const TallyPromotion(this.tallies);

  final Map<String, PilotTally> tallies;

  PilotVerdict _verdict(String id) =>
      judgePilot(tallies[id] ?? const PilotTally());

  @override
  bool isPromoted(String itemId) => _verdict(itemId) == PilotVerdict.promote;

  @override
  bool isRetired(String itemId) => _verdict(itemId) == PilotVerdict.retire;
}

/// Where the answers to pilot items go. Nothing leaves the phone, so the
/// default drops them; a later change gives it a home for the Verified
/// reviewers' responses.
abstract interface class PilotSink {
  void record(String itemId, {required bool pickedKey});
}

/// The default: pilot answers are not kept.
class NoPilotSink implements PilotSink {
  const NoPilotSink();

  @override
  void record(String itemId, {required bool pickedKey}) {}
}

// -------------------------------------------------------------- fix history

/// A fix two reviewers agreed on: the old form and the agreed one. Becomes a
/// gold item.
class FixHistoryEntry {
  const FixHistoryEntry({
    required this.cardId,
    required this.facet,
    required this.oldForm,
    required this.agreedFix,
  });

  final String cardId;

  /// [Facet.word] (the written form) or [Facet.meaning].
  final Facet facet;
  final String oldForm;
  final String agreedFix;
}

// -------------------------------------------------------------------- text

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

final RegExp _lead = RegExp(r'^(to|the|a|an)\s+');

/// The comparison forms of a word or gloss: itself, without a parenthesis,
/// the head before a comma, semicolon or slash, each without a leading
/// "to", "the", "a" or "an".
Set<String> reviewerForms(String text) {
  final out = <String>{};
  void add(String s) {
    final n = _norm(s);
    if (n.isEmpty) return;
    out.add(n);
    final bare = n.replaceFirst(_lead, '');
    if (bare.isNotEmpty) out.add(bare);
  }

  final n = _norm(text);
  final noParen = _norm(n.replaceAll(RegExp(r'\([^)]*\)'), ''));
  for (final s in <String>[n, noParen]) {
    add(s);
    add(s.split(RegExp(r'[,;/]')).first);
  }
  return out;
}

Set<String> _meaningForms(Card c) => <String>{
  ...reviewerForms(c.native),
  for (final a in c.altNative) ...reviewerForms(a),
  for (final s in c.senses) ...reviewerForms(s.native),
};

Set<String> _targetForms(Card c) => <String>{
  ...reviewerForms(c.target),
  for (final a in c.altTarget) ...reviewerForms(a),
  for (final v in c.targetScripts.values) ...reviewerForms(v),
};

bool _meet(Set<String> a, Set<String> b) => a.any(b.contains);

/// Whether the card [cardId] is checked twice on the facets an item of
/// [group] depends on: for each of them that the card has, two distinct
/// reviewers' latest answers are all "right" ([facetReachedQuorum]).
typedef CheckedTwice = bool Function(String cardId, ReviewerGroup group);

/// A [CheckedTwice] from the other speakers' checks of each card
/// (`OtherChecks`: card id, then facet, then the checks).
CheckedTwice checkedTwiceFrom(
  Map<String, Map<Facet, List<ReviewCheck>>> checks,
  Card? Function(String id) cardOf,
) {
  return (String cardId, ReviewerGroup group) {
    final card = cardOf(cardId);
    final byFacet = checks[cardId];
    if (card == null || byFacet == null) return false;
    final applicable = facetsOf(card);
    for (final facet in reviewerFacetsNeeded(group)) {
      if (!applicable.contains(facet)) continue;
      if (!facetReachedQuorum(byFacet[facet] ?? const <ReviewCheck>[])) {
        return false;
      }
    }
    return true;
  };
}

// --------------------------------------------------------------------- bank

/// The check's items for one course.
class ReviewerBank {
  ReviewerBank._(this.scored, this.pilot, this.topStart, this.topEnd);

  /// The scored items by group.
  final Map<ReviewerGroup, List<ReviewerItem>> scored;

  /// The pilot items, asked unscored.
  final List<ReviewerItem> pilot;

  /// The first and last deck index of the top band.
  final int topStart;
  final int topEnd;

  /// How many distinct cards [group]'s scored items ask about.
  int distinctCards(ReviewerGroup group) => <String>{
    for (final i in scored[group] ?? const <ReviewerItem>[]) i.item.cardId,
  }.length;

  /// Whether [group] has the cards the check needs to ask it.
  bool offers(ReviewerGroup group) =>
      distinctCards(group) >= (kReviewerMinPool[group] ?? 1 << 30);

  /// A thin course: too few eligible items for Read or Write, so there is no
  /// check to take and the reviewer asks for a reviewer key instead.
  bool get thin => !offers(ReviewerGroup.read) || !offers(ReviewerGroup.write);

  /// The first and last deck index of [data]'s top band: the last quarter of
  /// the decks up to the B1 milestone (the whole path when none is marked).
  static (int, int) bandOf(PlacementLanguageData data) {
    final top = data.levelMarkDecks.isEmpty
        ? data.deckCount - 1
        : data.levelMarkDecks.last.clamp(0, data.deckCount - 1);
    final size = ((top + 1) * kReviewerTopBandShare).round().clamp(1, top + 1);
    return (top - size + 1, top);
  }

  /// A cheap look, before any item is made, at whether [data]'s course could
  /// have a check: enough distinct cards of the top band are checked twice
  /// for Read and Write. A course that fails this is thin for certain; one
  /// that passes may still be thin once the items are made.
  static bool mayOffer(PlacementLanguageData data, CheckedTwice checkedTwice) {
    if (data.deckCount == 0) return false;
    final (start, top) = bandOf(data);
    for (final group in <ReviewerGroup>[
      ReviewerGroup.read,
      ReviewerGroup.write,
    ]) {
      var n = 0;
      for (var d = start; d <= top; d++) {
        for (final card in data.decks[d].cards) {
          if (checkedTwice(card.id, group)) n++;
        }
      }
      if (n < (kReviewerMinPool[group] ?? 1)) return false;
    }
    return true;
  }

  /// An empty bank (a language without placement).
  static ReviewerBank empty() => ReviewerBank._(
    <ReviewerGroup, List<ReviewerItem>>{},
    const <ReviewerItem>[],
    0,
    0,
  );

  /// The check's bank for [data], from the placement items [items].
  ///
  /// [checkedTwice] says which cards are checked twice, [history] gives the
  /// gold items, [promotion] which pilot items count.
  static ReviewerBank build({
    required PlacementLanguageData data,
    required Iterable<RegItem> items,
    required CheckedTwice checkedTwice,
    Iterable<FixHistoryEntry> history = const <FixHistoryEntry>[],
    ItemPromotion promotion = const NoItemPromoted(),
  }) {
    if (data.deckCount == 0) return empty();
    final (start, top) = bandOf(data);
    final index = _Index(data);
    final scored = <ReviewerGroup, List<ReviewerItem>>{
      for (final g in ReviewerGroup.values) g: <ReviewerItem>[],
    };
    final pilot = <ReviewerItem>[];
    final sorted = items.toList()..sort((a, b) => a.id.compareTo(b.id));
    for (final it in sorted) {
      final group = kReviewerFormats[it.format];
      if (group == null) continue;
      if (it.deck < start || it.deck > top) continue;
      if (!index.admits(it)) continue;
      if (promotion.isRetired(it.id)) continue;
      if (checkedTwice(it.cardId, group)) {
        scored[group]!.add(
          ReviewerItem(item: it, group: group, tier: ReviewerItemTier.checked),
        );
      } else if (promotion.isPromoted(it.id)) {
        scored[group]!.add(
          ReviewerItem(item: it, group: group, tier: ReviewerItemTier.pilot),
        );
      } else {
        pilot.add(
          ReviewerItem(item: it, group: group, tier: ReviewerItemTier.pilot),
        );
      }
    }
    for (final entry in history) {
      final gold = index.goldItem(entry, start, top);
      if (gold != null) {
        scored[gold.group]!.add(gold);
      }
    }
    return ReviewerBank._(scored, pilot, start, top);
  }
}

/// The text-to-card indexes of a course and the provability rules.
class _Index {
  _Index(this.data) {
    for (final deck in data.decks) {
      for (final card in deck.cards) {
        for (final f in _meaningForms(card)) {
          (byMeaning[f] ??= <Card>[]).add(card);
        }
        for (final f in _targetForms(card)) {
          (byTarget[f] ??= <Card>[]).add(card);
        }
      }
    }
  }

  final PlacementLanguageData data;
  final Map<String, List<Card>> byMeaning = <String, List<Card>>{};
  final Map<String, List<Card>> byTarget = <String, List<Card>>{};

  /// The cards a written option stands for, by meaning or by word.
  List<Card> _cardsOf(String text, {required bool meaning}) {
    final found = <Card>{};
    for (final f in reviewerForms(text)) {
      found.addAll((meaning ? byMeaning : byTarget)[f] ?? const <Card>[]);
    }
    return found.toList();
  }

  /// Whether [it] passes the owner's item rule.
  bool admits(RegItem it) {
    if (it.pseudo || !it.isReal || it.weight < 1) return false;
    if (it.cognateClass != 'clean') return false;
    final n = it.options.length;
    if (n < 4 || it.correct < 0 || it.correct >= n) return false;
    final group = kReviewerFormats[it.format];
    if (group == null) return false;
    // Options are meanings for a word pick (F2, F13, F26, F27) and words for
    // the other two (F3, F28).
    final meaningOptions = switch (it.format) {
      'F2' || 'F13' || 'F26' || 'F27' => true,
      _ => false,
    };
    final keyText = it.options[it.correct];
    final keyCards = _cardsOf(keyText, meaning: meaningOptions);
    if (keyCards.isEmpty) return false;
    if (!meaningOptions && it.format == 'F3') {
      // The prompt is the key card's meaning: the key option must be its word.
      final card = data.cardById(it.cardId);
      if (card == null || !keyCards.contains(card)) return false;
    }
    if (meaningOptions) {
      final card = data.cardById(it.cardId);
      if (card == null || !keyCards.contains(card)) return false;
    }
    final keyMeanings = <String>{for (final c in keyCards) ..._meaningForms(c)};
    final keyTargets = <String>{for (final c in keyCards) ..._targetForms(c)};
    final keyIds = <String>{for (final c in keyCards) c.id};
    final keyForms = reviewerForms(keyText);
    final keyPos = <String>{
      for (final c in keyCards)
        if (c.pos != null && c.pos!.isNotEmpty) c.pos!,
    };
    for (var i = 0; i < n; i++) {
      if (i == it.correct) continue;
      final text = it.options[i];
      if (_meet(reviewerForms(text), keyForms)) return false;
      final cards = _cardsOf(text, meaning: meaningOptions);
      // A distractor that is no card of the course cannot be proved wrong.
      if (cards.isEmpty) return false;
      for (final c in cards) {
        if (keyIds.contains(c.id)) return false;
        if (_meet(_meaningForms(c), keyMeanings)) return false;
        if (_meet(_targetForms(c), keyTargets)) return false;
        // Near misses share the key's word class.
        if (keyPos.isNotEmpty &&
            c.pos != null &&
            c.pos!.isNotEmpty &&
            !keyPos.contains(c.pos)) {
          return false;
        }
      }
    }
    return true;
  }

  /// The gold item of a fix: the agreed form is the key, the old form a
  /// distractor, and two further distractors come from the card's deck.
  ReviewerItem? goldItem(FixHistoryEntry e, int start, int top) {
    final card = data.cardById(e.cardId);
    final deck = data.deckIndexOf(e.cardId);
    if (card == null || deck == null || deck < start || deck > top) {
      return null;
    }
    final asMeaning = e.facet == Facet.meaning;
    if (!asMeaning && e.facet != Facet.word) return null;
    if (_norm(e.oldForm) == _norm(e.agreedFix)) return null;
    final used = <String>{_norm(e.agreedFix), _norm(e.oldForm)};
    final keyMeanings = <String>{
      ..._meaningForms(card),
      if (asMeaning) ...reviewerForms(e.agreedFix),
    };
    final keyTargets = <String>{
      ..._targetForms(card),
      if (!asMeaning) ...reviewerForms(e.agreedFix),
    };
    final extra = <String>[];
    final pool = data.decks[deck].cards.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final c in pool) {
      if (extra.length == 2) break;
      if (c.id == card.id) continue;
      if (_meet(_meaningForms(c), keyMeanings)) continue;
      if (_meet(_targetForms(c), keyTargets)) continue;
      final text = asMeaning ? c.native : c.target;
      if (text.trim().isEmpty || !used.add(_norm(text))) continue;
      extra.add(text);
    }
    if (extra.length < 2) return null;
    final options = <String>[e.agreedFix, e.oldForm, ...extra];
    final format = asMeaning ? 'F2' : 'F3';
    return ReviewerItem(
      item: RegItem(
        id: 'gold:${e.cardId}:${e.facet.wire}',
        format: format,
        cardId: e.cardId,
        deck: deck,
        prompt: asMeaning ? card.target : card.native,
        options: options,
        correct: 0,
        lemmas: <String>{'gold:${e.cardId}'},
      ),
      group: kReviewerFormats[format]!,
      tier: ReviewerItemTier.gold,
    );
  }
}
