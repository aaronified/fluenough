import 'dart:math' as math;

import '../models/card.dart';
import 'cognate_score.dart';
import 'item_registry.dart';
import 'placement_data.dart';

// The item generators of "Find my level" V3, with the item-generation fixes of
// the adversarial review (wiki/Plan-Placement-V3.md):
//
// 1. near-cognates are never in a word-level format; a sentence with fewer
//    than two non-cognate content words counts half;
// 2. word tiles carry decoy letters (or syllable units for a syllabic script);
// 3. a word-order pair keeps its end marks fixed and swaps one constituent;
// 4. word picks have distractors of the same part of speech and surface
//    shape, and one lure that looks like the answer; sentence picks have
//    one-word contrasts of the right translation;
// 5. a cloze has no English hint and options that share the blank's ending,
//    so the ending cannot decide; exception nouns become gender items;
// 6. (the registry's availability rule) a card is never asked twice.
//
// Everything is derived from a [PlacementLanguageData]; there is no
// per-language content. Pure Dart, deterministic for a seed.

/// The cognate score from which a word is left out of word-level formats.
const double kWordLevelCognateMax = 0.45;

/// The share of word-pick items that carry a look-alike lure.
const double kLureRate = 0.15;

final RegExp _marks = RegExp(r'^[^\p{L}\p{M}]+|[^\p{L}\p{M}]+$', unicode: true);
final RegExp _mark = RegExp(r'\p{M}', unicode: true);

const Set<int> _viramas = <int>{
  0x94d, 0x9cd, 0xa4d, 0xacd, 0xb4d, 0xbcd, 0xc4d, 0xccd, 0xd4d, //
};

/// The units a word is built from by tiles: letters with their marks, and,
/// for an Indic script, a consonant with its vowel sign and any conjunct
/// (so the unit is a syllable-sized piece, not a bare code point).
List<String> tileUnits(String word) {
  final units = <String>[];
  var joinNext = false;
  for (final r in word.runes) {
    final ch = String.fromCharCode(r);
    final isMark = _mark.hasMatch(ch);
    if (units.isNotEmpty && (isMark || joinNext)) {
      units[units.length - 1] = units.last + ch;
    } else {
      units.add(ch);
    }
    joinNext = _viramas.contains(r);
  }
  return units;
}

/// A word card of the course, with what the generators need of it.
class VocabWord {
  VocabWord({
    required this.card,
    required this.deck,
    required this.display,
    required this.word,
    required this.roman,
    required this.gloss,
    required this.glossHead,
    required this.pos,
    required this.article,
    required this.cognateScore,
    required this.lemma,
  }) : units = tileUnits(word);

  final Card card;
  final int deck;

  /// The target as the deck shows it (`el lunes`).
  final String display;

  /// The content word without its article (`lunes`).
  final String word;

  /// [word] romanised (the reading's word for a Devanagari card).
  final String roman;

  /// The short English meaning (`Monday`), and its one headword.
  final String gloss;
  final String glossHead;
  final String pos;

  /// The leading article token, or ''.
  final String article;
  final double cognateScore;
  final String lemma;
  final List<String> units;

  bool get cognate => cognateScore >= kCognateThreshold;

  /// Too much like its meaning for a word-level format: a partial cognate
  /// (0.45 or more) leaks to a similarity cue even below the cognate line.
  bool get leaky => cognateScore >= kWordLevelCognateMax;

  /// Set by the context: one of the course's first 100 words.
  bool early = false;

  /// The last two units: what a form's ending is made of.
  String get suffix =>
      units.length < 2 ? word : units.sublist(units.length - 2).join();
}

/// A sentence card of the course.
class SentenceInfo {
  SentenceInfo({
    required this.card,
    required this.deck,
    required this.words,
    required this.leadingMark,
    required this.trailingMark,
    required this.english,
    required this.nonCognateContent,
    required this.cognateScore,
    required this.lemmas,
    required this.inner,
  });

  final Card card;
  final int deck;
  final List<String> words;
  final String leadingMark;
  final String trailingMark;
  final String english;
  final int nonCognateContent;
  final double cognateScore;
  final Set<String> lemmas;

  /// Whether the sentence has punctuation inside (a comma): such a sentence
  /// is not used for tiles, which keep only the end marks.
  final bool inner;

  String get text => '$leadingMark${words.join(' ')}$trailingMark';
}

/// The edit distance of two unit lists, stopping at [limit] (the result is
/// [limit] when it is that or more).
int unitDistance(List<String> a, List<String> b, int limit) {
  if ((a.length - b.length).abs() >= limit) return limit;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    var rowMin = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
      if (cur[j] < rowMin) rowMin = cur[j];
    }
    if (rowMin >= limit) return limit;
    prev = cur;
  }
  return math.min(prev[b.length], limit);
}

String _stripMarks(String t) => t.replaceAll(_marks, '');

/// The language's items' common ground: the word and sentence cards read from
/// the data, with their cognate scores.
class GenContext {
  GenContext(this.data, {int seed = 1})
    : scorer = CognateScorer(data.language),
      rng = math.Random(seed) {
    _read();
    for (final v in early) {
      v.early = true;
    }
  }

  final PlacementLanguageData data;
  final CognateScorer scorer;
  final math.Random rng;

  final List<VocabWord> vocab = <VocabWord>[];

  /// Whether [v] is in the held-out half of the course's words (every other
  /// word): the yes/no audit trains its pattern model on the other half and
  /// scores the pseudowords made from the held-out words, so no word is
  /// scored by a model that has seen it.
  bool heldOut(VocabWord v) => _index[v.card.id]!.isOdd;
  final Map<String, int> _index = <String, int>{};
  final List<SentenceInfo> sentences = <SentenceInfo>[];
  final Map<String, List<VocabWord>> byPos = <String, List<VocabWord>>{};
  final Map<String, List<VocabWord>> byHead = <String, List<VocabWord>>{};
  final Set<String> articles = <String>{};

  /// The article each gender takes ('m', 'f'), when the course shows them.
  final Map<String, String> genderArticle = <String, String>{};

  int get deckCount => data.deckCount;

  /// The first 100 word cards of the course (by deck): the words a gamer
  /// that has done only the opening is assumed to know. Distractors avoid
  /// them (for an item that is not one of them), so a known word cannot be
  /// eliminated from the options.
  late final List<VocabWord> early = vocab.take(100).toList();
  late final Set<String> earlyIds = <String>{for (final v in early) v.card.id};
  late final Set<String> earlyGlossHeads = <String>{
    for (final v in early) ...<String>{v.glossHead, ...glossWords(v.gloss)},
  }..remove('');

  /// How far [v]'s word is from the nearest other word of the course, in
  /// units (4 means four or more).
  int nearestOther(VocabWord v) =>
      _nearest[v.card.id] ??= _nearestDistance(v.units, exclude: v.card.id);
  final Map<String, int> _nearest = <String, int>{};

  /// The distance from [units] to the nearest word of the course other than
  /// [exclude], up to 4.
  int _nearestDistance(List<String> units, {String? exclude}) {
    var best = 4;
    for (final w in vocab) {
      if (w.card.id == exclude) continue;
      if ((w.units.length - units.length).abs() >= best) continue;
      final d = unitDistance(units, w.units, best);
      if (d < best) best = d;
      if (best == 0) break;
    }
    return best;
  }

  /// The nearest-word distance of a made-up word (a pseudoword).
  int nearestToPseudo(List<String> units) => _nearestDistance(units);

  static const Set<String> _wordPos = <String>{
    'noun',
    'verb',
    'adj',
    'adv',
    'pronoun',
    'other',
  };

  void _read() {
    // First pass: the leading tokens of two-token cards are the articles.
    final lead = <String, int>{};
    for (final deck in data.decks) {
      for (final c in deck.cards) {
        if (!_isWordCard(c)) continue;
        final t = targetWords(c.target);
        if (t.length == 2) {
          lead[t[0].toLowerCase()] = (lead[t[0].toLowerCase()] ?? 0) + 1;
        }
      }
    }
    for (final e in lead.entries) {
      if (e.value >= 12) articles.add(e.key);
    }
    final genderVotes = <String, Map<String, int>>{};
    final seenCards = <String>{};
    for (final (di, deck) in data.decks.indexed) {
      for (final c in deck.cards) {
        if (c.rule != null || c.isGrammarCell || c.isLetterOrDigit) continue;
        // A card listed in two decks counts once, at its first deck.
        if (!seenCards.add(c.id)) continue;
        if (c.native.trim().isEmpty || c.practiceOnly) continue;
        final tokens = targetWords(c.target);
        if (_isWordCard(c)) {
          String article = '';
          String word;
          if (tokens.length == 1) {
            word = tokens[0];
          } else if (tokens.length == 2 &&
              articles.contains(tokens[0].toLowerCase())) {
            article = tokens[0].toLowerCase();
            word = tokens[1];
          } else {
            continue;
          }
          final romanWords = targetWords(c.reading ?? '');
          final roman = romanWords.isNotEmpty && c.reading != null
              ? romanWords.last
              : word;
          final gloss = shortGloss(c.native);
          final head = _headword(gloss);
          final v = VocabWord(
            card: c,
            deck: di,
            display: c.target,
            word: word,
            roman: roman,
            gloss: gloss,
            glossHead: head,
            pos: c.pos!,
            article: article,
            cognateScore: scorer.scoreCard(c),
            lemma: _lemma(c, word),
          );
          if (v.units.length < 2) continue;
          _index[v.card.id] = vocab.length;
          vocab.add(v);
          (byPos[v.pos] ??= <VocabWord>[]).add(v);
          if (head.isNotEmpty) (byHead[head] ??= <VocabWord>[]).add(v);
          if (c.gender != null && article.isNotEmpty && c.pos == 'noun') {
            final g = c.gender!;
            (genderVotes[g] ??= <String, int>{})[article] =
                ((genderVotes[g] ?? const <String, int>{})[article] ?? 0) + 1;
          }
        } else if (tokens.length >= 3 && tokens.length <= 10) {
          _addSentence(c, di, tokens);
        }
      }
    }
    for (final g in const <String>['m', 'f']) {
      final votes = genderVotes[g];
      if (votes == null || votes.isEmpty) continue;
      final best = votes.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final other = <String>['m', 'f'].firstWhere((x) => x != g);
      final contra = genderVotes[other]?[best.key] ?? 0;
      if (best.value >= 10 && contra * 10 <= best.value) {
        genderArticle[g] = best.key;
      }
    }
    if (genderArticle['m'] == genderArticle['f']) genderArticle.clear();
  }

  static bool _isLatin(String s) => RegExp('^[A-Za-z]').hasMatch(s);

  bool _isWordCard(Card c) =>
      c.pos != null &&
      _wordPos.contains(c.pos) &&
      c.rule == null &&
      !c.isGrammarCell &&
      !c.isLetterOrDigit &&
      !RegExp(r'[?!.,;:¿¡।]').hasMatch(c.target) &&
      c.wordCount <= 2;

  String _headword(String gloss) {
    var g = gloss.toLowerCase().trim();
    for (final p in const <String>['to ', 'the ', 'a ', 'an ']) {
      if (g.startsWith(p)) {
        g = g.substring(p.length);
        break;
      }
    }
    return RegExp(r"^[a-z']+$").hasMatch(g) ? g : '';
  }

  String _lemma(Card c, String word) {
    for (final b in c.bases) {
      if (b.base != null && latinLetters(b.word) == latinLetters(word)) {
        return foldAccents(b.base!);
      }
    }
    return foldAccents(word);
  }

  void _addSentence(Card c, int deck, List<String> words) {
    final text = c.target.trim();
    final first = text.indexOf(RegExp(r'[\p{L}\p{M}]', unicode: true));
    var last = text.length - 1;
    while (last > 0 &&
        !RegExp(r'[\p{L}\p{M}]', unicode: true).hasMatch(text[last])) {
      last--;
    }
    if (first < 0) return;
    final lead = text.substring(0, first);
    final trail = text.substring(last + 1);
    final raw = text.split(RegExp(r'\s+'));
    var inner = false;
    for (var i = 0; i < raw.length; i++) {
      final stripped = _stripMarks(raw[i]);
      final plain = raw[i];
      final expectedMarks =
          (i == 0 ? lead.length : 0) + (i == raw.length - 1 ? trail.length : 0);
      if (plain.length - stripped.length != expectedMarks) inner = true;
    }
    final english = shortGloss(c.native);
    final romanWords = c.reading == null ? words : targetWords(c.reading!);
    var nonCog = 0;
    var best = 0.0;
    final eng = glossWords(english);
    final lemmas = <String>{};
    for (final w in romanWords) {
      if (latinLetters(w).length < 4) continue;
      var s = 0.0;
      for (final e in eng) {
        s = math.max(s, wordSimilarity(w, e, data.language));
      }
      best = math.max(best, s);
      if (s < kCognateThreshold) nonCog++;
    }
    for (final b in c.bases) {
      final l = b.base ?? b.word;
      if (latinLetters(l).length >= 4 || !_isLatin(l)) {
        lemmas.add(foldAccents(l));
      }
    }
    // A card with no listed bases still has its word forms.
    if (c.bases.isEmpty) {
      for (final w in words) {
        if (latinLetters(w).length >= 4 || !_isLatin(w)) {
          lemmas.add(foldAccents(w));
        }
      }
    }
    if (eng.isEmpty) return;
    sentences.add(
      SentenceInfo(
        card: c,
        deck: deck,
        words: words,
        leadingMark: lead,
        trailingMark: trail,
        english: english,
        nonCognateContent: nonCog,
        cognateScore: best,
        lemmas: lemmas,
        inner: inner,
      ),
    );
  }

  /// A shuffled copy of [list] with this context's seeded generator.
  List<T> shuffled<T>(Iterable<T> list) => List<T>.of(list)..shuffle(rng);

  /// The word cards near [deck] (within [span] decks), other than [not].
  Iterable<VocabWord> near(VocabWord v, {int? span}) {
    final s = span ?? math.max(6, deckCount ~/ 12);
    return (byPos[v.pos] ?? const <VocabWord>[]).where(
      (o) => o.card.id != v.card.id && (o.deck - v.deck).abs() <= s,
    );
  }
}

// ---------------------------------------------------------------------------

/// The generators: each returns the items of one format for a context.
class ItemGenerators {
  ItemGenerators(this.cx);

  final GenContext cx;

  static String _key(String cardId, String fmt) => '$cardId:$fmt';

  /// Distractor words of [v]: the same part of speech and surface shape
  /// (the article it takes, a similar length, the same last unit), near it on
  /// the path, with one lure when [lure] finds a look-alike.
  List<VocabWord> _shapeMatches(VocabWord v) {
    final pool = cx.near(v).where((o) {
      if (o.glossHead.isNotEmpty && o.glossHead == v.glossHead) return false;
      if (o.gloss.toLowerCase() == v.gloss.toLowerCase()) return false;
      if (o.lemma == v.lemma) return false;
      if (o.display == v.display) return false;
      if (!v.early && o.early) return false;
      if (o.article != v.article && (o.article.isEmpty != v.article.isEmpty)) {
        return false;
      }
      return (o.units.length - v.units.length).abs() <= 2;
    }).toList();
    pool.sort((a, b) {
      final sa = a.units.last == v.units.last ? 0 : 1;
      final sb = b.units.last == v.units.last ? 0 : 1;
      return sa != sb ? sa.compareTo(sb) : a.card.id.compareTo(b.card.id);
    });
    return pool;
  }

  /// The word of the same part of speech whose [text] most resembles [like]
  /// (a cognate lure or false friend), if any resembles it at 0.3 or more.
  VocabWord? _lure(
    VocabWord v,
    String like,
    String Function(VocabWord) text,
    Set<String> taken,
  ) {
    VocabWord? best;
    var bestScore = 0.3;
    final pool = cx.shuffled(cx.near(v, span: cx.deckCount)).take(150);
    for (final o in pool) {
      if (taken.contains(o.card.id) || o.card.id == v.card.id) continue;
      if (o.glossHead == v.glossHead || o.lemma == v.lemma) continue;
      if (o.display == v.display) continue;
      if (!v.early && o.early) continue;
      final s = wordSimilarity(text(o), like, cx.data.language);
      if (s > bestScore) {
        best = o;
        bestScore = s;
      }
    }
    return best;
  }

  /// [candidates] ordered so that those whose English meaning has the same
  /// number of words and nearly the same length as [v]'s come first: no
  /// option is the odd one out by length.
  List<VocabWord> _byGlossLength(VocabWord v, List<VocabWord> candidates) {
    int words(String g) => g.trim().split(RegExp(r'\s+')).length;
    int rank(VocabWord o) {
      final sameWords = words(o.gloss) == words(v.gloss) ? 0 : 1;
      final sameEnd = o.units.last == v.units.last ? 0 : 1;
      return sameWords * 100 +
          (o.gloss.length - v.gloss.length).abs() * 2 +
          sameEnd;
    }

    final index = <VocabWord, int>{
      for (var i = 0; i < candidates.length; i++) candidates[i]: i,
    };
    final list = List<VocabWord>.of(candidates);
    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : index[a]!.compareTo(index[b]!);
    });
    return list;
  }

  /// The first 24 of [candidates] reordered so that those whose resemblance
  /// to the prompt ([sim]) is closest to the right answer's ([own]), and
  /// whose English meaning is closest in length to [v]'s, come first: no
  /// option stands out as the one that looks like the prompt or is longer.
  List<VocabWord> _matchAffinity(
    VocabWord v,
    List<VocabWord> candidates,
    double Function(VocabWord) sim,
    double own,
  ) {
    double cost(VocabWord o) =>
        (sim(o) - own).abs() * 8 +
        (o.gloss.length - v.gloss.length).abs() * 0.5 +
        (o.units.last == v.units.last ? 0 : 0.3);
    final head = candidates.take(24).toList()
      ..sort((a, b) => cost(a).compareTo(cost(b)));
    return <VocabWord>[...head, ...candidates.skip(24)];
  }

  /// Written word to meaning (F2), heard word to meaning (F13).
  List<RegItem> wordToMeaning(String format) {
    final out = <RegItem>[];
    for (final v in cx.vocab) {
      if (v.leaky || v.gloss.isEmpty) continue;
      String english(VocabWord o) =>
          o.glossHead.isEmpty ? o.gloss : o.glossHead;
      final shapes = _matchAffinity(
        v,
        _byGlossLength(v, _shapeMatches(v)),
        (o) => wordSimilarity(v.roman, english(o), cx.data.language),
        wordSimilarity(v.roman, english(v), cx.data.language),
      );
      final taken = <String>{};
      final distractors = <VocabWord>[];
      // A look-alike lure in a minority of items only: an option that
      // resembles the prompt is always wrong, so a solver that drops the
      // most similar option would gain on a bank where every item has one.
      final lure = cx.rng.nextDouble() < kLureRate
          ? _lure(
              v,
              v.roman,
              (o) => o.glossHead.isEmpty ? o.gloss : o.glossHead,
              taken,
            )
          : null;
      if (lure != null) {
        distractors.add(lure);
        taken.add(lure.card.id);
      }
      for (final o in shapes) {
        if (distractors.length >= 3) break;
        if (taken.contains(o.card.id)) continue;
        if (distractors.any(
          (d) => d.gloss.toLowerCase() == o.gloss.toLowerCase(),
        )) {
          continue;
        }
        distractors.add(o);
        taken.add(o.card.id);
      }
      if (distractors.length < 3) continue;
      final opts = cx.shuffled(<String>[
        v.gloss,
        ...distractors.map((d) => d.gloss),
      ]);
      out.add(
        RegItem(
          id: _key(v.card.id, format),
          format: format,
          cardId: v.card.id,
          deck: v.deck,
          prompt: v.display,
          promptRoman: v.roman,
          options: opts,
          optionsRoman: opts,
          correct: opts.indexOf(v.gloss),
          cognateScore: v.cognateScore,
          lemmas: <String>{v.lemma},
          coCards: <String>{for (final d in distractors) d.card.id},
        ),
      );
    }
    return out;
  }

  /// English meaning to the written word (F3).
  List<RegItem> meaningToWord() {
    final out = <RegItem>[];
    for (final v in cx.vocab) {
      if (v.leaky || v.gloss.isEmpty) continue;
      final like = v.glossHead.isEmpty ? v.gloss : v.glossHead;
      final shapes = _matchAffinity(
        v,
        _shapeMatches(v),
        (o) => wordSimilarity(o.roman, like, cx.data.language),
        wordSimilarity(v.roman, like, cx.data.language),
      );
      final taken = <String>{};
      final distractors = <VocabWord>[];
      final lure = cx.rng.nextDouble() < kLureRate
          ? _lure(v, like, (o) => o.roman, taken)
          : null;
      if (lure != null) {
        distractors.add(lure);
        taken.add(lure.card.id);
      }
      for (final o in shapes) {
        if (distractors.length >= 3) break;
        if (taken.contains(o.card.id)) continue;
        if (distractors.any((d) => d.display == o.display)) continue;
        distractors.add(o);
        taken.add(o.card.id);
      }
      if (distractors.length < 3) continue;
      final opts = cx.shuffled(<VocabWord>[v, ...distractors]);
      out.add(
        RegItem(
          id: _key(v.card.id, 'F3'),
          format: 'F3',
          cardId: v.card.id,
          deck: v.deck,
          prompt: v.gloss,
          promptRoman: v.gloss,
          options: [for (final o in opts) o.display],
          optionsRoman: [for (final o in opts) o.roman],
          correct: opts.indexOf(v),
          cognateScore: v.cognateScore,
          lemmas: <String>{v.lemma},
          coCards: <String>{for (final d in distractors) d.card.id},
        ),
      );
    }
    return out;
  }

  /// Word tiles (F4) with [decoys] extra units, from words of 4 to 7 units.
  List<RegItem> wordTiles(int decoys) {
    final out = <RegItem>[];
    for (final v in cx.vocab) {
      if (v.leaky || v.gloss.isEmpty) continue;
      if (v.units.length < 4 || v.units.length > 7) continue;
      final used = <String>{...v.units};
      final candidates = <String>[];
      for (final o in _shapeMatches(v)) {
        for (final u in o.units) {
          if (!used.contains(u) && !candidates.contains(u)) candidates.add(u);
        }
        if (candidates.length >= decoys + 3) break;
      }
      if (candidates.length < decoys) continue;
      final picked = cx.shuffled(candidates).take(decoys).toList();
      out.add(
        RegItem(
          id: _key(v.card.id, 'F4'),
          format: 'F4',
          cardId: v.card.id,
          deck: v.deck,
          prompt: v.gloss,
          promptRoman: v.gloss,
          tiles: cx.shuffled(<String>[...v.units, ...picked]),
          answerTiles: v.units,
          accepted: <String>[v.word],
          cognateScore: v.cognateScore,
          decoyCount: decoys,
          lemmas: <String>{v.lemma},
        ),
      );
    }
    return out;
  }

  /// English meaning, type the word (F7), and the same to say (F18).
  List<RegItem> typedOrSaid(String format) {
    final out = <RegItem>[];
    for (final v in cx.vocab) {
      if (v.leaky || v.gloss.isEmpty) continue;
      final accepted = <String>{
        v.word,
        for (final a in v.card.altTarget) ...targetWords(a),
      };
      out.add(
        RegItem(
          id: _key(v.card.id, format),
          format: format,
          cardId: v.card.id,
          deck: v.deck,
          prompt: v.gloss,
          promptRoman: v.gloss,
          accepted: accepted.toList(),
          answerTiles: <String>[v.roman],
          cognateScore: v.cognateScore,
          lemmas: <String>{v.lemma},
        ),
      );
    }
    return out;
  }

  /// Written yes/no (F1) and heard yes/no (F14): real words, then the
  /// pseudowords the registry builds.
  List<RegItem> yesNoReal(String format) => <RegItem>[
    for (final v in cx.vocab)
      if (!v.leaky &&
          v.gloss.isNotEmpty &&
          v.units.length >= 4 &&
          v.units.length <= 8)
        RegItem(
          id: _key(v.card.id, format),
          format: format,
          cardId: v.card.id,
          deck: v.deck,
          // The bare word, as a pseudoword is shown: no article.
          prompt: v.word,
          promptRoman: v.roman,
          cognateScore: v.cognateScore,
          lemmas: <String>{v.lemma},
        ),
  ];

  /// Pseudowords: made-up words the audit's pattern detectors cannot tell
  /// from real ones. Each is made from a real word by one to three changes
  /// (two units swapped, or one replaced), and is accepted only if it is as
  /// typical of the language's letter patterns as a real word drawn at random
  /// (each scored without the word it came from, as a learner who has not
  /// seen that word would) and as far from the nearest other word as that
  /// real word is.
  List<RegItem> pseudowords(String format, {int count = 400}) {
    final real = <String>{for (final v in cx.vocab) v.word.toLowerCase()};
    final tri = <String, int>{};
    final bi = <String, int>{};
    final edge = <String, int>{};
    void add(List<String> units, int by) {
      final u = <String>['^', ...units, r'$'];
      for (var i = 0; i + 2 < u.length; i++) {
        final k = u.sublist(i, i + 3).join('|');
        tri[k] = (tri[k] ?? 0) + by;
      }
      for (var i = 0; i + 1 < u.length; i++) {
        final k = u.sublist(i, i + 2).join('|');
        bi[k] = (bi[k] ?? 0) + by;
      }
      final e = '${units.first}|${units.last}';
      edge[e] = (edge[e] ?? 0) + by;
    }

    for (final v in cx.vocab) {
      add(v.units, 1);
    }
    double mean(List<String> u, int n, Map<String, int> counts) {
      var total = 0.0;
      var k = 0;
      for (var i = 0; i + n <= u.length; i++) {
        total += math.log(
          1 + math.max(0, counts[u.sublist(i, i + n).join('|')] ?? 0),
        );
        k++;
      }
      return k == 0 ? 0 : total / k;
    }

    // How typical a word is of the language's letter patterns, three ways,
    // leaving out the word it came from.
    List<double> typical(List<String> units, List<String> leaveOut) {
      add(leaveOut, -1);
      final padded = <String>['^', ...units, r'$'];
      final out = <double>[
        mean(padded, 3, tri),
        mean(padded, 2, bi),
        math.log(1 + math.max(0, edge['${units.first}|${units.last}'] ?? 0)),
      ];
      add(leaveOut, 1);
      return out;
    }

    final single = cx.vocab
        .where(
          (v) =>
              !v.leaky &&
              v.gloss.isNotEmpty &&
              v.units.length >= 4 &&
              v.units.length <= 8,
        )
        .toList();
    if (single.isEmpty) {
      return <RegItem>[];
    }
    final realTypical = <List<double>>[
      for (final v in single) typical(v.units, v.units),
    ];
    final realNear = <int>[for (final v in single) cx.nearestOther(v)];
    final tolerance = <double>[
      for (var k = 0; k < 3; k++)
        (realTypical.map((t) => t[k]).reduce(math.max) -
                realTypical.map((t) => t[k]).reduce(math.min)) /
            20,
    ];
    final byLength = <int, List<VocabWord>>{};
    for (final v in single) {
      (byLength[v.units.length] ??= <VocabWord>[]).add(v);
    }
    final out = <RegItem>[];
    final seen = <String>{};
    // One real word to imitate at a time, tried up to 600 times: a pseudoword
    // that is hard to match is dropped, not matched to an easier word, so the
    // pseudowords keep the real words' lengths.
    var wants = 0;
    while (out.length < count && wants < count * 6) {
      wants++;
      final want = cx.rng.nextInt(single.length);
      final sources = byLength[single[want].units.length]!;
      for (var tries = 0; tries < 600; tries++) {
        final v = sources[cx.rng.nextInt(sources.length)];
        final w = cx.vocab[cx.rng.nextInt(cx.vocab.length)];
        final u = List<String>.of(v.units);
        final changes = 1 + cx.rng.nextInt(3);
        for (var c = 0; c < changes; c++) {
          final i = 1 + cx.rng.nextInt(u.length - 2);
          if (cx.rng.nextBool() && i + 1 < u.length - 1) {
            final t = u[i];
            u[i] = u[i + 1];
            u[i + 1] = t;
          } else {
            u[i] = w.units[math.min(i, w.units.length - 1)];
          }
        }
        final text = u.join();
        if (real.contains(text.toLowerCase()) || seen.contains(text)) {
          continue;
        }
        final t = typical(u, v.units);
        var close = true;
        for (var k = 0; k < 3; k++) {
          if ((t[k] - realTypical[want][k]).abs() > tolerance[k]) {
            close = false;
          }
        }
        if (!close) {
          continue;
        }
        if (math.min(cx.nearestToPseudo(u), 3) != math.min(realNear[want], 3)) {
          continue;
        }
        seen.add(text);
        out.add(
          RegItem(
            id: 'pw${out.length}:$format',
            format: format,
            cardId: 'pw${out.length}',
            deck: 0,
            prompt: text,
            promptRoman: text,
            pseudo: true,
            isReal: false,
            coCards: <String>{v.card.id},
          ),
        );
        break;
      }
    }
    return out;
  }

  /// Sentence tiles: English to a built sentence (F8), a heard sentence built
  /// (F16). Two decoy tokens from other sentences near it; the end marks stay
  /// where they are.
  List<RegItem> sentenceTiles(String format) {
    final out = <RegItem>[];
    for (final s in cx.sentences) {
      if (s.inner || s.words.length > 9) continue;
      final lower = [for (final w in s.words) w.toLowerCase()];
      final decoys = <String>[];
      final pool = cx.sentences.where(
        (o) => o.card.id != s.card.id && (o.deck - s.deck).abs() <= 6,
      );
      for (final o in cx.shuffled(pool)) {
        for (final w in o.words) {
          final l = w.toLowerCase();
          if (!lower.contains(l) && !decoys.contains(l)) {
            decoys.add(l);
          }
        }
        if (decoys.length >= 6) break;
      }
      if (decoys.length < 2) continue;
      out.add(
        RegItem(
          id: _key(s.card.id, format),
          format: format,
          cardId: s.card.id,
          deck: s.deck,
          prompt: format == 'F8' ? s.english : s.text,
          tiles: cx.shuffled(<String>[...lower, ...decoys.take(2)]),
          answerTiles: lower,
          leadingMark: s.leadingMark,
          trailingMark: s.trailingMark,
          cognateScore: s.cognateScore,
          nonCognateContent: s.nonCognateContent,
          weight: s.nonCognateContent >= 2 ? 1 : 0.5,
          decoyCount: 2,
          lemmas: s.lemmas,
        ),
      );
    }
    return out;
  }

  /// Word order (S2): the sentence and itself with one constituent (an
  /// adjacent pair of words) swapped; the end marks stay put. Of the possible
  /// swaps the one whose word pairs occur most often elsewhere in the course
  /// is used, so the wrong order is the most natural-looking one.
  List<RegItem> wordOrder() {
    final out = <RegItem>[];
    final counts = <String, int>{};
    for (final s in cx.sentences) {
      final w = <String>['^', for (final x in s.words) x.toLowerCase(), r'$'];
      for (var i = 0; i + 1 < w.length; i++) {
        counts['${w[i]}|${w[i + 1]}'] =
            (counts['${w[i]}|${w[i + 1]}'] ?? 0) + 1;
      }
    }
    String ending(String word) {
      final u = tileUnits(word.toLowerCase());
      return u.length < 2 ? word.toLowerCase() : u.sublist(u.length - 2).join();
    }

    final endCounts = <String, int>{};
    for (final s in cx.sentences) {
      final w = <String>['^', for (final x in s.words) ending(x), r'$'];
      for (var i = 0; i + 1 < w.length; i++) {
        endCounts['${w[i]}|${w[i + 1]}'] =
            (endCounts['${w[i]}|${w[i + 1]}'] ?? 0) + 1;
      }
    }
    double plausibility(List<String> words) {
      final w = <String>['^', for (final x in words) x.toLowerCase(), r'$'];
      final e = <String>['^', for (final x in words) ending(x), r'$'];
      var total = 0.0;
      for (var i = 0; i + 1 < w.length; i++) {
        total += math.log(1 + (counts['${w[i]}|${w[i + 1]}'] ?? 0));
        total += math.log(1 + (endCounts['${e[i]}|${e[i + 1]}'] ?? 0));
      }
      return total;
    }

    for (final s in cx.sentences) {
      if (s.inner || s.words.length < 3) continue;
      final lower = [for (final w in s.words) w];
      final at = <int>[
        for (var i = 0; i + 1 < lower.length; i++)
          if (lower[i].toLowerCase() != lower[i + 1].toLowerCase()) i,
      ];
      if (at.isEmpty) continue;
      var i = at.first;
      var bestScore = double.negativeInfinity;
      for (final k in at) {
        final trial = List<String>.of(lower);
        final tmp = trial[k];
        trial[k] = trial[k + 1];
        trial[k + 1] = tmp;
        final score = plausibility(trial);
        if (score > bestScore) {
          bestScore = score;
          i = k;
        }
      }
      final swapped = List<String>.of(lower);
      final t = swapped[i];
      swapped[i] = swapped[i + 1];
      swapped[i + 1] = t;
      // Capitalisation stays with the position, as the end marks do.
      if (i == 0) {
        swapped[0] = _capitalLike(swapped[0], lower[0]);
        swapped[1] = _capitalLike(swapped[1], lower[1]);
      }
      final good = '${s.leadingMark}${lower.join(' ')}${s.trailingMark}';
      final bad = '${s.leadingMark}${swapped.join(' ')}${s.trailingMark}';
      if (good == bad) continue;
      final opts = cx.shuffled(<String>[good, bad]);
      out.add(
        RegItem(
          id: _key(s.card.id, 'S2'),
          format: 'S2',
          cardId: s.card.id,
          deck: s.deck,
          prompt: s.english,
          promptRoman: s.english,
          options: opts,
          optionsRoman: opts,
          correct: opts.indexOf(good),
          cognateScore: s.cognateScore,
          nonCognateContent: s.nonCognateContent,
          weight: s.nonCognateContent >= 2 ? 1 : 0.5,
          lemmas: s.lemmas,
        ),
      );
    }
    return out;
  }

  String _capitalLike(String word, String model) {
    if (word.isEmpty || model.isEmpty) return word;
    final upper = model[0] != model[0].toLowerCase();
    return upper
        ? word[0].toUpperCase() + word.substring(1)
        : word[0].toLowerCase() + word.substring(1);
  }

  /// Sentence picks: a written sentence (F5) or a heard one (F17), pick its
  /// English meaning. The wrong options change one word of the right
  /// translation for a word of the same part of speech and a similar length
  /// and a similar resemblance to the sentence's own words.
  List<RegItem> sentencePicks(String format) {
    final out = <RegItem>[];
    for (final s in cx.sentences) {
      final english = s.english;
      final romans =
          (s.card.reading == null ? s.words : targetWords(s.card.reading!))
              .where((w) => latinLetters(w).length >= 4)
              .toList();
      double affinity(String token) {
        var best = 0.0;
        for (final w in romans) {
          best = math.max(best, wordSimilarity(w, token, cx.data.language));
        }
        return best;
      }

      final matches = RegExp(r"[A-Za-z']+").allMatches(english).toList();
      final variants = <String>[];
      final order = cx.shuffled(matches);
      for (final m in order) {
        if (variants.length >= 3) break;
        final token = m[0]!;
        final heads = cx.byHead[token.toLowerCase()];
        if (heads == null || token.length < 3) continue;
        // A word the gamer's first 100 words give away stays in every option.
        if (cx.earlyGlossHeads.contains(token.toLowerCase())) continue;
        final pos = heads.first.pos;
        if (pos != 'noun' && pos != 'verb' && pos != 'adj') continue;
        final a0 = affinity(token);
        final cands = <(double, String)>[];
        final pool = cx.shuffled(cx.byPos[pos] ?? const <VocabWord>[]).take(60);
        for (final o in pool) {
          final h = o.glossHead;
          if (h.isEmpty || h == token.toLowerCase()) continue;
          if ((h.length - token.length).abs() > 2) continue;
          if (english.toLowerCase().contains(h)) continue;
          if (cx.earlyGlossHeads.contains(h)) continue;
          cands.add(((affinity(h) - a0).abs(), h));
        }
        if (cands.isEmpty) continue;
        cands.sort(
          (x, y) => x.$1 != y.$1 ? x.$1.compareTo(y.$1) : x.$2.compareTo(y.$2),
        );
        final top = cands.take(4).toList();
        final h = top[cx.rng.nextInt(top.length)].$2;
        final cased = token[0] != token[0].toLowerCase()
            ? h[0].toUpperCase() + h.substring(1)
            : h;
        final v = english.replaceRange(m.start, m.end, cased);
        if (v != english && !variants.contains(v)) variants.add(v);
      }
      if (variants.length < 3) continue;
      final opts = cx.shuffled(<String>[english, ...variants]);
      out.add(
        RegItem(
          id: _key(s.card.id, format),
          format: format,
          cardId: s.card.id,
          deck: s.deck,
          prompt: s.text,
          promptRoman: s.card.reading ?? s.text,
          options: opts,
          optionsRoman: opts,
          correct: opts.indexOf(english),
          cognateScore: s.cognateScore,
          nonCognateContent: s.nonCognateContent,
          weight: s.nonCognateContent >= 2 ? 1 : 0.5,
          lemmas: s.lemmas,
        ),
      );
    }
    return out;
  }

  /// Cloze (F6): a word of a sentence blanked, with no English hint. The
  /// options share the blank's ending (its last two units) and differ in
  /// stem, so only the meaning of the sentence decides.
  List<RegItem> cloze() {
    final out = <RegItem>[];
    // Word pairs of the course: a distractor is the more plausible in its
    // place the more often it stands next to the neighbours of the blank, so
    // among words of the right ending and length the most plausible are
    // used, and a context cue does not pick the answer.
    final pairs = <String, int>{};
    for (final s in cx.sentences) {
      final w = <String>['^', for (final x in s.words) x.toLowerCase(), r'$'];
      for (var i = 0; i + 1 < w.length; i++) {
        pairs['${w[i]}|${w[i + 1]}'] = (pairs['${w[i]}|${w[i + 1]}'] ?? 0) + 1;
      }
    }
    final pool = <(SentenceInfo, int, String)>[];
    for (final s in cx.sentences) {
      for (var i = 0; i < s.words.length; i++) {
        final u = tileUnits(s.words[i].toLowerCase());
        if (u.length < 3) continue;
        pool.add((s, i, s.words[i].toLowerCase()));
      }
    }
    final byDeck = <int, List<(SentenceInfo, int, String)>>{};
    for (final p in pool) {
      (byDeck[p.$1.deck] ??= <(SentenceInfo, int, String)>[]).add(p);
    }
    for (final s in cx.sentences) {
      if (s.inner) continue;
      // A blank on a content word, not the first word (capital letters).
      final idx = <int>[
        for (var i = 1; i < s.words.length; i++)
          if (tileUnits(s.words[i]).length >= 3) i,
      ];
      if (idx.isEmpty) continue;
      final i = idx[cx.rng.nextInt(idx.length)];
      final target = s.words[i].toLowerCase();
      final tu = tileUnits(target);
      // The ending is the last two units (the last one for a short word).
      final tail = tu.length >= 5 ? 2 : 1;
      final suffix = tu.sublist(tu.length - tail).join();
      final stem = tu.take(3).join();
      // Distractors: words of the same ending and nearly the same length (no
      // option is the odd one out), with a different stem, from sentences
      // near this one; the closest in length first.
      final found = <(int, String)>[];
      for (var d = -6; d <= 6; d++) {
        for (final p
            in byDeck[s.deck + d] ?? const <(SentenceInfo, int, String)>[]) {
          final w = p.$3;
          final u = tileUnits(w);
          if (p.$1.card.id == s.card.id) continue;
          if ((u.length - tu.length).abs() > 1) continue;
          if (u.length < tail || u.sublist(u.length - tail).join() != suffix) {
            continue;
          }
          if (u.take(3).join() == stem) continue;
          if (w == target || found.any((f) => f.$2 == w)) continue;
          found.add(((u.length - tu.length).abs(), w));
        }
      }
      final prev = i == 0 ? '^' : s.words[i - 1].toLowerCase();
      final next = i + 1 >= s.words.length
          ? r'$'
          : s.words[i + 1].toLowerCase();
      double fit(String w) =>
          math.log(1 + (pairs['$prev|$w'] ?? 0)) +
          math.log(1 + (pairs['$w|$next'] ?? 0));
      final shuffledFound = cx.shuffled(found);
      shuffledFound.sort((x, y) {
        final byLength = x.$1.compareTo(y.$1);
        return byLength != 0 ? byLength : fit(y.$2).compareTo(fit(x.$2));
      });
      final options = <String>[
        target,
        for (final f in shuffledFound.take(3)) f.$2,
      ];
      if (options.length < 4) continue;
      final blanked = <String>[
        for (var k = 0; k < s.words.length; k++) k == i ? '___' : s.words[k],
      ];
      final opts = cx.shuffled(options);
      out.add(
        RegItem(
          id: _key(s.card.id, 'F6'),
          format: 'F6',
          cardId: s.card.id,
          deck: s.deck,
          prompt: '${s.leadingMark}${blanked.join(' ')}${s.trailingMark}',
          options: opts,
          optionsRoman: opts,
          correct: opts.indexOf(target),
          cognateScore: s.cognateScore,
          nonCognateContent: s.nonCognateContent,
          weight: s.nonCognateContent >= 2 ? 1 : 0.5,
          lemmas: s.lemmas,
        ),
      );
    }
    return out;
  }

  /// Gender items: for a noun whose ending does not predict its gender (an
  /// exception such as `la mano`), pick its article. Only where the course
  /// shows nouns with articles for both genders.
  List<RegItem> genderExceptions() {
    final m = cx.genderArticle['m'];
    final f = cx.genderArticle['f'];
    if (m == null || f == null) return <RegItem>[];
    // The gender each ending is dominated by.
    final stats = <String, Map<String, int>>{};
    for (final v in cx.vocab) {
      final g = v.card.gender;
      if (v.pos != 'noun' || v.article.isEmpty || (g != 'm' && g != 'f')) {
        continue;
      }
      final end = v.units.last;
      (stats[end] ??= <String, int>{})[g!] =
          ((stats[end] ?? const <String, int>{})[g] ?? 0) + 1;
    }
    final dominant = <String, String>{};
    for (final e in stats.entries) {
      final total = (e.value['m'] ?? 0) + (e.value['f'] ?? 0);
      for (final g in const <String>['m', 'f']) {
        final n = e.value[g] ?? 0;
        if (total >= 15 && n * 100 >= total * 85) dominant[e.key] = g;
      }
    }
    // Exceptions, and as many nouns that follow their ending's rule: a solver
    // that always picks the article the ending suggests, or always the
    // opposite, then gets half of them.
    final exceptions = <RegItem>[];
    final regular = <RegItem>[];
    for (final v in cx.vocab) {
      final g = v.card.gender;
      if (v.pos != 'noun' || v.article.isEmpty || (g != 'm' && g != 'f')) {
        continue;
      }
      final dom = dominant[v.units.last];
      if (dom == null || v.leaky) {
        continue;
      }
      final right = g == 'm' ? m : f;
      final wrong = g == 'm' ? f : m;
      final opts = cx.shuffled(<String>[right, wrong]);
      (dom == g ? regular : exceptions).add(
        RegItem(
          id: _key(v.card.id, 'F6g'),
          format: 'F6g',
          cardId: v.card.id,
          deck: v.deck,
          prompt: '___ ${v.word}',
          options: opts,
          optionsRoman: opts,
          correct: opts.indexOf(right),
          cognateScore: v.cognateScore,
          genderException: dom != g,
          lemmas: <String>{v.lemma},
        ),
      );
    }
    final out = <RegItem>[
      ...exceptions,
      ...cx.shuffled(regular).take(exceptions.length),
    ];
    return out;
  }

  /// Matching screens (F9): four words of one part of speech, near each
  /// other on the path, none a near-cognate, with their four meanings.
  List<RegItem> matching({int perCard = 8}) {
    final out = <RegItem>[];
    final used = <String>{};
    // Matching is stricter than the other word formats: a word that merely
    // looks a little like its meaning (0.45) is left out too.
    bool eligible(VocabWord v) => !v.leaky && v.gloss.isNotEmpty;
    final seeds = cx.vocab.where(eligible).toList();
    for (var n = 0; n < seeds.length; n += perCard) {
      final v = seeds[n];
      final others = cx
          .near(v)
          .where((o) => eligible(o) && !used.contains(o.card.id))
          .toList();
      final chosen = <VocabWord>[v];
      for (final o in cx.shuffled(others)) {
        if (chosen.length >= 4) break;
        if (chosen.any(
          (c) =>
              c.gloss.toLowerCase() == o.gloss.toLowerCase() ||
              c.lemma == o.lemma,
        )) {
          continue;
        }
        chosen.add(o);
      }
      if (chosen.length < 4) continue;
      used.addAll(chosen.map((c) => c.card.id));
      out.add(
        RegItem(
          id: _key(v.card.id, 'F9'),
          format: 'F9',
          cardId: v.card.id,
          deck: chosen.map((c) => c.deck).reduce(math.max),
          prompt: chosen.map((c) => c.display).join(' | '),
          pairs: <(String, String)>[for (final c in chosen) (c.roman, c.gloss)],
          options: cx.shuffled(chosen.map((c) => c.gloss)),
          cognateScore: chosen.map((c) => c.cognateScore).reduce(math.max),
          lemmas: <String>{for (final c in chosen) c.lemma},
          coCards: <String>{for (final c in chosen) c.card.id},
        ),
      );
    }
    return out;
  }
}
