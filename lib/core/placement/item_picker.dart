import 'dart:math' as math;

import '../models/card.dart';
import '../scheduling/distractors.dart';
import 'guessability.dart';
import 'placement_data.dart';

// How an item of a question is chosen (wiki/Plan-Placement-V2.md, section
// 2.2) and how its wrong options are: the hardness score, the shortlist of
// the five hardest, and the distractor rules. Pure and deterministic given
// the seed.

/// 32-bit FNV-1a of [text]: the same on every platform, unlike
/// `String.hashCode`, so a seed gives the same question everywhere.
int stableHash(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// A random source for [seed] and [salt] (an id, a request number).
math.Random seededRandom(int seed, String salt) =>
    math.Random((seed * 1000003) ^ stableHash(salt));

/// [text] as a meaning is compared: lower case, brackets and punctuation
/// dropped, a leading "to " or article dropped, one space.
String foldMeaning(String text) {
  var out = text.toLowerCase();
  out = out.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ');
  out = out.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  out = out.replaceFirst(RegExp(r'^(to|the|a|an) '), '');
  return out;
}

/// The Levenshtein distance of [a] and [b], in whole characters.
int editDistance(String a, String b) {
  final x = a.runes.toList();
  final y = b.runes.toList();
  if (x.isEmpty) return y.length;
  if (y.isEmpty) return x.length;
  var previous = List<int>.generate(y.length + 1, (i) => i);
  for (var i = 1; i <= x.length; i++) {
    final current = <int>[i, ...List<int>.filled(y.length, 0)];
    for (var j = 1; j <= y.length; j++) {
      final cost = x[i - 1] == y[j - 1] ? 0 : 1;
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
    }
    previous = current;
  }
  return previous[y.length];
}

/// [editDistance] as a share of the longer text, 0 (equal) to 1.
double normalisedEdit(String a, String b) {
  final longest = math.max(a.runes.length, b.runes.length);
  return longest == 0 ? 0 : editDistance(a, b) / longest;
}

/// Whether [a] and [b] mean the same: they share a meaning, one lists the
/// other as a synonym, or they are written alike (a homograph is right for
/// either meaning, so it is never a wrong option).
bool sameMeaning(Card a, Card b) {
  if (a.id == b.id || a.target == b.target) return true;
  final keys = <String>{for (final m in a.meanings) foldMeaning(m)};
  if (b.meanings.any((m) => keys.contains(foldMeaning(m)))) return true;
  bool lists(Card x, Card y) => x.synonyms.any(
    (s) => s.ref == y.id || (s.word != null && s.word == y.target),
  );
  return lists(a, b) || lists(b, a);
}

/// A card that can be asked: a taught item, not a table's form (a rules
/// table's cell, or a pattern's cell, whose prompt is "lemma (gloss) —
/// person": a form to produce, not a word whose meaning is picked, and one
/// whose options would leak the lemma), a letter, a digit or a
/// practice-only card.
bool isAskable(Card card) =>
    card.rule == null &&
    !card.isGrammarCell &&
    !card.practiceOnly &&
    !card.isLetterOrDigit &&
    card.target.trim().isNotEmpty &&
    card.native.trim().isNotEmpty;

/// A sentence or phrase of two words or more: [Card.rearranges].
bool isSentenceCard(Card card) => card.rearranges;

/// A single word, or a word with its article.
bool isWordCard(Card card) => !card.rearranges && card.pos != 'phrase';

/// The word families [card] belongs to: its own id and the base words it is
/// inflected from, by card or by text. A base spelled like the word itself
/// (an article, a particle) does not tie two cards together.
Set<String> wordFamilies(Card card, PlacementLanguageData data) {
  final out = <String>{card.id};
  for (final base in card.bases) {
    final ref = base.ref;
    final other = ref == null ? null : data.cardById(ref);
    final text = base.base ?? other?.target;
    if (ref != null && ref != card.id) out.add(ref);
    if (text != null && text.toLowerCase() != base.word.toLowerCase()) {
      out.add(text.toLowerCase());
    }
  }
  return out;
}

/// Whether [card] is an inflected form: one of its base words is not the
/// word as written.
bool isInflected(Card card, PlacementLanguageData data) {
  for (final base in card.bases) {
    final text =
        base.base ??
        (base.ref == null ? null : data.cardById(base.ref!)?.target);
    if (text != null && text.toLowerCase() != base.word.toLowerCase()) {
      return true;
    }
  }
  return false;
}

/// An item with its score and the wrong options it was scored against.
class RankedItem {
  const RankedItem({
    required this.card,
    required this.deck,
    required this.depth,
    required this.form,
    required this.closeness,
    required this.score,
    required this.wrong,
  });

  final Card card;
  final int deck;
  final double depth;
  final double form;
  final double closeness;

  /// `0.35 depth + 0.30 form + 0.35 closeness`.
  final double score;

  /// The wrong options the closeness was measured against (empty for a
  /// question with no pick).
  final List<Card> wrong;
}

/// How many times [count] candidates are gathered before the ones that look
/// most like the answer are chosen among them.
const int _luredPoolFactor = 10;

/// The plan's weights of the hardness score (section 2.2, question 8i).
const double depthWeight = 0.35;
const double formWeight = 0.30;
const double closenessWeight = 0.35;

/// At most this many candidates get their closeness measured: the ones with
/// the highest depth and form. A bound on cost only; with 100 decks the last
/// quarter holds a few hundred cards.
const int closenessCandidates = 80;

/// Chooses items and wrong options for the builder.
class PlacementItemPicker {
  PlacementItemPicker(this.data, {this.seed = 0});

  final PlacementLanguageData data;

  /// Seeds the order of equally good wrong options.
  final int seed;

  final Map<int, List<int>> _lengthsByDeck = <int, List<int>>{};

  /// The deck's depth: its index over the last index.
  double depthOf(int deck) =>
      data.deckCount <= 1 ? 1 : deck / (data.deckCount - 1);

  int _lengthOf(Card card) =>
      isSentenceCard(card) ? card.wordCount : card.target.runes.length;

  /// The form part (section 2.2): 1 for an inflected form, a compound, an
  /// idiom or a sentence of a grammar unit; otherwise the item's length as a
  /// share of the shorter items of its deck; plus 0.2 if a note names a stem
  /// change. Capped at 1.
  double formOf(Card card, int deck) {
    final deckData = data.decks[deck];
    final double form;
    final tags = card.tags;
    if (isSentenceCard(card)
        ? deckData.isGrammar
        : (isInflected(card, data) ||
              tags.contains('compound') ||
              tags.contains('idiom') ||
              card.pos == 'idiom')) {
      form = 1.0;
    } else {
      final lengths = _lengthsByDeck.putIfAbsent(
        deck,
        () => <int>[
          for (final c in deckData.cards)
            if (isSentenceCard(c) == isSentenceCard(card)) _lengthOf(c),
        ]..sort(),
      );
      final mine = _lengthOf(card);
      final shorter = lengths.where((n) => n < mine).length;
      form = lengths.length <= 1 ? 0.0 : shorter / (lengths.length - 1);
    }
    final stem = card.notes.any(
      (n) => RegExp(r'\bstem\b', caseSensitive: false).hasMatch(n.text),
    );
    return math.min(1.0, form + (stem ? 0.2 : 0));
  }

  /// How close [wrong] is to [answer] (section 2.2): 1 if they differ by one
  /// swap of a sounds-file contrast; otherwise one minus the edit distance of
  /// their readings, plus 0.2 if one is a base of the other, 0.1 for the same
  /// part of speech and 0.1 for a tag in common; capped at 1.
  double closenessOf(Card answer, Card wrong) {
    final sounds = data.sounds;
    if (sounds != null && sounds.between(wrong.target, answer.target) != null) {
      return 1;
    }
    final a = answer.reading ?? answer.target;
    final b = wrong.reading ?? wrong.target;
    var close = 1 - normalisedEdit(a.toLowerCase(), b.toLowerCase());
    final shared = distractorSources(answer, wrong);
    if (shared.contains(DistractorSource.base)) close += 0.2;
    if (shared.contains(DistractorSource.pos)) close += 0.1;
    if (shared.contains(DistractorSource.tag)) close += 0.1;
    return math.min(1, close);
  }

  /// The wrong options for [answer], [count] of them where the decks give
  /// that many: from [answer]'s deck first, then the decks around it, nearest
  /// first; [sameKind] only (a sentence is not offered for a word); never one
  /// that means the same, is spelled the same, or shows what an option
  /// already shows ([show]); never an id of [asked] unless [relaxAsked]. In
  /// each deck the cards that share most with the answer come first (its word
  /// family, part of speech, tags, [rankDistractors]), in a seeded order
  /// within a rank.
  List<Card> distractorsFor(
    Card answer,
    int deck, {
    required bool Function(Card) sameKind,
    required String Function(Card) show,
    int count = 3,
    Set<String> asked = const <String>{},
    bool relaxAsked = false,
    Set<String> exclude = const <String>{},
    String? lure,
  }) {
    final random = seededRandom(seed, answer.id);
    final shown = <String>{show(answer)};
    final out = <Card>[];
    // What the cards the answer lists as synonyms mean: an option that shows
    // it would be right too.
    final blocked = <String>{
      for (final s in answer.synonyms)
        if (s.ref != null)
          for (final m in data.cardById(s.ref!)?.meanings ?? const <String>[])
            foldMeaning(m),
    };
    bool ok(Card c) =>
        c.id != answer.id &&
        isAskable(c) &&
        sameKind(c) &&
        !exclude.contains(c.id) &&
        (relaxAsked || !asked.contains(c.id)) &&
        !sameMeaning(answer, c) &&
        !c.meanings.any((m) => blocked.contains(foldMeaning(m))) &&
        !shown.contains(show(c));
    final last = data.deckCount - 1;
    // With a [lure] (the text the learner is shown as the prompt) the wrong
    // options must look as much like it as the right one does: a pool of
    // the best-ranked candidates is gathered, and the [count] whose letters
    // resemble the prompt about as much as the answer's do are kept, so that
    // no option gives itself away by being spelled like the prompt.
    final pool = <Card>[];
    final poolShown = <String>{};
    final poolSize = count * _luredPoolFactor;
    for (var distance = 0; distance <= last; distance++) {
      final tier = <Card>[
        if (deck - distance >= 0) ...data.decks[deck - distance].cards,
        if (distance > 0 && deck + distance <= last)
          ...data.decks[deck + distance].cards,
      ];
      if (tier.isEmpty) continue;
      for (final group in rankDistractors(answer, tier)) {
        final shuffled = <Card>[...group]..shuffle(random);
        for (final c in shuffled) {
          if (lure != null) {
            if (pool.length >= poolSize) break;
            if (!ok(c) || !poolShown.add(show(c))) continue;
            pool.add(c);
            continue;
          }
          if (out.length >= count) return out;
          if (!ok(c)) continue;
          shown.add(show(c));
          out.add(c);
        }
      }
      if (lure != null) {
        if (pool.length >= poolSize) break;
      } else if (out.length >= count) {
        return out;
      }
    }
    if (lure == null) return out;
    final target = surfaceSimilarity(lure, show(answer));
    double gap(Card c) => (surfaceSimilarity(lure, show(c)) - target).abs();
    final order = <int>[for (var i = 0; i < pool.length; i++) i]
      ..sort((a, b) {
        final c = gap(pool[a]).compareTo(gap(pool[b]));
        return c != 0 ? c : a.compareTo(b);
      });
    for (final i in order) {
      if (out.length >= count) break;
      out.add(pool[i]);
    }
    return out;
  }

  /// [candidates] ranked hardest first (section 2.2). Each is a card with the
  /// deck it is in. [wrongFor] gives the wrong options a candidate is scored
  /// against (none for a question with no pick); a candidate it returns null
  /// for is dropped, since it cannot be asked.
  List<RankedItem> rank(
    Iterable<({Card card, int deck})> candidates, {
    required List<Card>? Function(Card card, int deck) wrongFor,
    double Function(Card card, int deck)? formOverride,
    double Function(Card card, Card wrong)? closenessBetween,
  }) {
    double form(Card c, int d) => formOverride?.call(c, d) ?? formOf(c, d);
    final partial = <({Card card, int deck, double depth, double form})>[
      for (final c in candidates)
        (
          card: c.card,
          deck: c.deck,
          depth: depthOf(c.deck),
          form: form(c.card, c.deck),
        ),
    ];
    int byPartial(
      ({Card card, int deck, double depth, double form}) a,
      ({Card card, int deck, double depth, double form}) b,
    ) {
      final x = depthWeight * a.depth + formWeight * a.form;
      final y = depthWeight * b.depth + formWeight * b.form;
      final c = y.compareTo(x);
      return c != 0 ? c : a.card.id.compareTo(b.card.id);
    }

    partial.sort(byPartial);
    final out = <RankedItem>[];
    for (final p in partial.take(closenessCandidates)) {
      final wrong = wrongFor(p.card, p.deck);
      if (wrong == null) continue;
      var closeness = 0.0;
      for (final w in wrong) {
        closeness = math.max(
          closeness,
          closenessBetween == null
              ? closenessOf(p.card, w)
              : closenessBetween(p.card, w),
        );
      }
      out.add(
        RankedItem(
          card: p.card,
          deck: p.deck,
          depth: p.depth,
          form: p.form,
          closeness: closeness,
          score:
              depthWeight * p.depth +
              formWeight * p.form +
              closenessWeight * closeness,
          wrong: wrong,
        ),
      );
    }
    out.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.card.id.compareTo(b.card.id);
    });
    return out;
  }

  /// The item a request asks for: [pick] (0 to 4) among the five hardest of
  /// [ranked], so that two runs do not ask the same five.
  static RankedItem? pickFromShortlist(List<RankedItem> ranked, int pick) {
    if (ranked.isEmpty) return null;
    final shortlist = ranked.take(5).toList();
    return shortlist[pick % shortlist.length];
  }
}
