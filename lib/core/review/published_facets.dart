/// What other reviewers said about each facet of a card, as the decks publish
/// it (ADR-0058 amendment, work package W9; the format is
/// wiki/Deck-Format.md, "Facet checks"). Pure Dart.
///
/// The review bot writes one line on a card's entry, `facet_checks`:
///
///     facet_checks: {"reading": {"by": ["FL-A", "FL-B"]},
///       "meaning": {"flags": [{"by": "FL-C", "tags": ["meaning_wrong"],
///       "fix": "dog"}]}}
///
/// Per facet, `by` lists the rater codes whose latest answer is "right" and
/// `flags` the other raters' latest answers: the code, the pointer tags and
/// the replacement text, if one was given. One answer a rater and facet. It
/// holds rater codes only, never an address. The app reads it into
/// `FlaggedSourceDeck.others` ([OtherChecks]) beside the sign-offs of
/// `checked_by`, so the flagged queue and the second-speaker views see the
/// other speakers' facet answers.
///
/// **Never shown as a number.** Nothing here counts for a screen.
library;

import 'facets.dart';
import 'review_problems.dart';
import 'review_quorum.dart';

/// One rater's flag on a facet.
class PublishedFlag {
  const PublishedFlag({required this.rater, required this.tags, this.fix});

  final String rater;
  final Set<PointerTag> tags;

  /// The replacement text they proposed, or null.
  final String? fix;

  @override
  bool operator ==(Object other) =>
      other is PublishedFlag &&
      other.rater == rater &&
      other.fix == fix &&
      other.tags.length == tags.length &&
      other.tags.containsAll(tags);

  @override
  int get hashCode => Object.hash(rater, fix, Object.hashAllUnordered(tags));
}

/// What a deck publishes about one facet of one card.
class PublishedFacet {
  const PublishedFacet({
    this.by = const <String>[],
    this.flags = const <PublishedFlag>[],
  });

  /// The rater codes whose latest answer is "right".
  final List<String> by;

  /// The raters whose latest answer is a flag.
  final List<PublishedFlag> flags;

  bool get isEmpty => by.isEmpty && flags.isEmpty;

  /// The facet [json] holds (`{"by": [...], "flags": [...]}`), or null when
  /// it holds nothing usable. Read leniently, as `checked_by` is: what is
  /// not of the shape is reported and left out, the rest stays. A flag whose
  /// tags are all unknown or do not belong on [facet] is dropped, never
  /// turned into "right".
  static PublishedFacet? fromJson(Facet facet, Object? json) {
    try {
      if (json is! Map) {
        ReviewProblems.report('facet_checks ${facet.wire}: not an object');
        return null;
      }
      final by = <String>[];
      final rawBy = json['by'];
      if (rawBy is List) {
        for (final code in rawBy) {
          if (code is String && code.trim().isNotEmpty) by.add(code);
        }
      }
      final flags = <PublishedFlag>[];
      final rawFlags = json['flags'];
      if (rawFlags is List) {
        for (final item in rawFlags) {
          final flag = _flagFrom(facet, item);
          if (flag != null) flags.add(flag);
        }
      }
      final found = PublishedFacet(
        by: List<String>.unmodifiable(by),
        flags: List<PublishedFlag>.unmodifiable(flags),
      );
      return found.isEmpty ? null : found;
    } on Object catch (e) {
      ReviewProblems.report('facet_checks ${facet.wire}: unreadable: $e');
      return null;
    }
  }

  static PublishedFlag? _flagFrom(Facet facet, Object? item) {
    if (item is! Map || item['by'] is! String) {
      ReviewProblems.report('facet_checks ${facet.wire}: flag unreadable');
      return null;
    }
    final tags = <PointerTag>{};
    final raw = item['tags'];
    if (raw is List) {
      for (final wire in raw) {
        final tag = PointerTag.fromWire(wire);
        if (tag != null && tag.facets.contains(facet)) tags.add(tag);
      }
    }
    if (tags.isEmpty) {
      ReviewProblems.report('facet_checks ${facet.wire}: flag with no tag');
      return null;
    }
    final fix = item['fix'];
    return PublishedFlag(
      rater: item['by'] as String,
      tags: Set<PointerTag>.unmodifiable(tags),
      fix: fix is String && fix.isNotEmpty ? fix : null,
    );
  }

  /// This facet's checks, as [ReviewCheck]s: each code of [by] right, each
  /// flag a flag. One source of truth: where a facet is published, nothing
  /// else counts for it (see [otherChecksOfCard]).
  List<ReviewCheck> get checks => <ReviewCheck>[
    for (final code in by) ReviewCheck(rater: code),
    for (final flag in flags)
      ReviewCheck(
        rater: flag.rater,
        answer: FacetAnswer.flagged(flag.tags, replacement: flag.fix),
      ),
  ];

  @override
  bool operator ==(Object other) =>
      other is PublishedFacet &&
      _same(other.by, by) &&
      _same(other.flags, flags);

  @override
  int get hashCode => Object.hash(Object.hashAll(by), Object.hashAll(flags));
}

bool _same<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The published facets of each card of a deck, by card id.
typedef PublishedFacets = Map<String, Map<Facet, PublishedFacet>>;

/// The facets [json], a card entry's `facet_checks`, holds, by facet; an
/// unknown facet or an entry that is not one is reported and left out.
Map<Facet, PublishedFacet> publishedFacetsFrom(Object? json) {
  final out = <Facet, PublishedFacet>{};
  if (json is! Map) {
    if (json != null) ReviewProblems.report('facet_checks: not an object');
    return out;
  }
  for (final MapEntry(:key, :value) in json.entries) {
    final facet = Facet.fromWire(key);
    if (facet == null) {
      ReviewProblems.report('facet_checks: unknown facet $key');
      continue;
    }
    final found = PublishedFacet.fromJson(facet, value);
    if (found != null) out[facet] = found;
  }
  return out;
}

/// [a] and [b], the published facets of a card's core entry and its layer's,
/// as the merged deck's card has them: per facet, the codes of both, each
/// once, and the flags of both, one a rater (the layer's replaces the
/// core's, being the later reading of the same reviewer's answer).
Map<Facet, PublishedFacet> mergePublishedFacets(
  Map<Facet, PublishedFacet> a,
  Map<Facet, PublishedFacet> b,
) {
  final out = <Facet, PublishedFacet>{};
  for (final facet in <Facet>{...a.keys, ...b.keys}) {
    final first = a[facet];
    final second = b[facet];
    final by = <String>{...?first?.by, ...?second?.by};
    final flags = <String, PublishedFlag>{
      for (final f in <PublishedFlag>[...?first?.flags, ...?second?.flags])
        f.rater.trim().toUpperCase(): f,
    };
    final flagged = flags.keys.toSet();
    final merged = PublishedFacet(
      by: List<String>.unmodifiable(<String>[
        for (final code in by)
          if (!flagged.contains(code.trim().toUpperCase())) code,
      ]),
      flags: List<PublishedFlag>.unmodifiable(flags.values),
    );
    if (!merged.isEmpty) out[facet] = merged;
  }
  return out;
}

/// The other speakers' checks of one card, from its `checked_by` codes
/// ([bareCodes], each a check of every facet the card has: [applicable]) and
/// its published facets ([published]).
///
/// One source of truth, as the tools read it (`checks_of` in
/// `tools/review_facets.py`): a facet that is published is read from
/// `facet_checks` alone, and `checked_by`, which the bot then keeps as a mirror
/// of the full sign-offs, does not count for it again; a facet that is not
/// published (an old deck, or an entry with no `facet_checks`) is read from
/// `checked_by`. Facets the card does not have are left out.
Map<Facet, List<ReviewCheck>> otherChecksOfCard({
  required Set<Facet> applicable,
  required List<String> bareCodes,
  required Map<Facet, PublishedFacet> published,
}) {
  final out = <Facet, List<ReviewCheck>>{};
  for (final facet in applicable) {
    final checks =
        published[facet]?.checks ??
        <ReviewCheck>[for (final code in bareCodes) ReviewCheck(rater: code)];
    if (checks.isNotEmpty) out[facet] = checks;
  }
  return out;
}
