/// Synonym sets for typed English meanings (ADR-0050, #924).
///
/// A set is a list of English words or phrases that are interchangeable in
/// every situation, and each member accepts every other. The sets come from
/// `assets/synonyms/en.yaml`, a restricted YAML subset this file reads itself
/// (no `yaml` package, AGENTS.md rule 6). Pure Dart; no Flutter imports.
///
/// Matching is the owner's frame (2026-10-30, on #924): the whole answer, with
/// at most one lead word before it and nothing after it. See [exact] and
/// [typo], and the wiki's Plan-Synonym-Dictionary for the table of cases.
library;

import 'dart:convert' show LineSplitter;

/// One accepted form of a card's answer, in `meaningKey` form.
class SynonymForm {
  const SynonymForm(this.key, {this.verb = false});

  /// The comparison form: lower case, no punctuation, no leading "to".
  final String key;

  /// Whether the card wrote it with a leading "to": a verb card, the only
  /// kind a typed "to" is free on.
  final bool verb;
}

/// A typed answer that a synonym set accepted.
class SynonymMatch {
  const SynonymMatch(this.form, this.member);

  /// Which of the card's forms, by index, the answer was a synonym of.
  final int form;

  /// The set member the answer was read as, spelled right and carrying the
  /// card's ending. For a typo, what the learner meant.
  final String member;
}

class SynonymSets {
  const SynonymSets._(this._sets, this._index);

  /// No sets: grading is as it was without them.
  static const SynonymSets empty = SynonymSets._(
    <List<String>>[],
    <String, int>{},
  );

  /// Reads the file's text. Throws a [FormatException] for anything outside
  /// the subset: an unknown line, a member not in double quotes, a set of
  /// fewer than two, an empty or repeated member, a word in two sets, or a
  /// `version` other than 1.
  factory SynonymSets.parse(String text) {
    final sets = <List<String>>[];
    final index = <String, int>{};
    var seenSets = false;
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('version:')) {
        if (line.substring(8).trim() != '1') {
          throw FormatException('Unknown synonym file version', line);
        }
        continue;
      }
      if (line == 'sets:' || line == 'sets: []') {
        seenSets = true;
        continue;
      }
      final match = _setLine.firstMatch(line);
      if (!seenSets || match == null) {
        throw FormatException('Not a synonym set line', line);
      }
      final members = <String>[];
      for (final part in match.group(1)!.split(',')) {
        final member = _quoted.firstMatch(part.trim())?.group(1)?.trim();
        if (member == null || member.isEmpty) {
          throw FormatException('A set member must be a quoted word', line);
        }
        if (index.containsKey(member) || members.contains(member)) {
          throw FormatException('A word is in two sets or twice', member);
        }
        members.add(member);
      }
      if (members.length < 2) {
        throw FormatException('A set needs two members', line);
      }
      for (final member in members) {
        index[member] = sets.length;
      }
      sets.add(members);
    }
    return SynonymSets._(sets, index);
  }

  /// [parse], or [empty] for a file that cannot be read: a bad file means no
  /// synonyms, never a crash.
  static SynonymSets tryParse(String? text) {
    if (text == null) return empty;
    try {
      return SynonymSets.parse(text);
    } on FormatException {
      return empty;
    }
  }

  static final RegExp _setLine = RegExp(r'^-\s*\[(.*)\]$');
  static final RegExp _quoted = RegExp(r'^"([^"\\]*)"$');

  final List<List<String>> _sets;
  final Map<String, int> _index;

  bool get isEmpty => _sets.isEmpty;

  /// The other members of the set [key] is in, or none.
  Set<String> equivalents(String key) {
    final i = _index[key];
    if (i == null) return const <String>{};
    return {
      for (final member in _sets[i])
        if (member != key) member,
    };
  }

  // ---------------------------------------------------------------------------
  // Matching
  // ---------------------------------------------------------------------------

  /// Whether [typedKey] (a `meaningKey`, typed with a leading "to" when
  /// [typedTo]) is a synonym of one of the card's [forms]: the whole core is
  /// in one set with the form's core, with equal regular endings. [exclude]
  /// are typed keys the card refuses (its `not_synonyms`).
  SynonymMatch? exact(
    String typedKey,
    List<SynonymForm> forms, {
    bool typedTo = false,
    Set<String> exclude = const <String>{},
  }) {
    if (isEmpty || typedKey.isEmpty || exclude.contains(typedKey)) return null;
    final typed = _parses(typedKey);
    for (var i = 0; i < forms.length; i++) {
      final form = forms[i];
      for (final t in typed) {
        if (exclude.contains(t.core)) continue;
        final options = _resolve(t.core);
        for (final c in _parses(form.key)) {
          if (!_leadsFit(t.lead, c.lead, typedTo: typedTo, verb: form.verb)) {
            continue;
          }
          // British -elled, American -eled: one word, by rule (travelling,
          // traveling), for the listed lemmas only, whatever the sets hold.
          if (_doubledL(t.core) == _doubledL(c.core) && t.core != c.core) {
            return SynonymMatch(i, t.core);
          }
          for (final cardOption in _resolve(c.core)) {
            for (final o in options) {
              if (o.set == cardOption.set &&
                  o.label == cardOption.label &&
                  o.lemma != cardOption.lemma) {
                return SynonymMatch(i, _inflect(o.lemma, o.label).first);
              }
            }
          }
        }
      }
    }
    return null;
  }

  /// A typed core that is a slip for a member of a form's set: the card's own
  /// thresholds counted in the member's letters (none under [shortThreshold],
  /// [typoDistance] below [longThreshold], [longTypoDistance] from it), the
  /// ending equal, the lead rules as in [exact]. A typed word that is itself a
  /// member of some set is a real word and is never matched here.
  SynonymMatch? typo(
    String typedKey,
    List<SynonymForm> forms, {
    required int typoDistance,
    required int longTypoDistance,
    required int longThreshold,
    required int shortThreshold,
    bool typedTo = false,
    Set<String> exclude = const <String>{},
  }) {
    if (isEmpty || typedKey.isEmpty || exclude.contains(typedKey)) return null;
    final typed = [
      for (final t in _parses(typedKey))
        if (_resolve(t.core).isEmpty && !exclude.contains(t.core)) t,
    ];
    // The whole key being a real word rules out every reading of it.
    if (_resolve(typedKey).isNotEmpty) return null;
    for (var i = 0; i < forms.length; i++) {
      final form = forms[i];
      for (final t in typed) {
        for (final c in _parses(form.key)) {
          if (!_leadsFit(t.lead, c.lead, typedTo: typedTo, verb: form.verb)) {
            continue;
          }
          for (final cardOption in _resolve(c.core)) {
            for (final member in _sets[cardOption.set]) {
              if (member == cardOption.lemma) continue;
              final letters = member.runes.length;
              final allowed = letters < shortThreshold
                  ? 0
                  : letters >= longThreshold
                  ? longTypoDistance
                  : typoDistance;
              if (allowed == 0) continue;
              for (final candidate in _inflect(member, cardOption.label)) {
                if (candidate != t.core &&
                    _within(t.core, candidate, allowed)) {
                  return SynonymMatch(i, candidate);
                }
              }
            }
          }
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // The frame: a lead word, then the core
  // ---------------------------------------------------------------------------

  static const Set<String> _articles = {'a', 'an', 'the'};

  /// Leads that are part of the meaning, so both sides must carry the same.
  static const Set<String> _matchingLeads = {
    'my', 'your', 'his', 'her', 'its', 'our', 'their', //
    'this', 'that', 'these', 'those', //
    'is', 'are', 'am', 'was', 'were', 'be',
  };

  /// Every way to read [key] as `[lead] core`: the whole key first (so "be
  /// careful" is read as a member before "be" is taken as a lead), then, for
  /// a key of two words or more that starts with a lead word, the rest.
  static List<({String? lead, String core})> _parses(String key) {
    final out = <({String? lead, String core})>[(lead: null, core: key)];
    final space = key.indexOf(' ');
    if (space > 0) {
      final first = key.substring(0, space);
      if (_articles.contains(first) || _matchingLeads.contains(first)) {
        out.add((lead: first, core: key.substring(space + 1)));
      }
    }
    return out;
  }

  /// Whether the two sides' leads allow a match. An article is free on either
  /// side (a and an alike; the only with the), except that a verb card, or a
  /// typed "to", takes none (a part-of-speech clash). A possessive,
  /// demonstrative or copula must be on both sides, the same.
  static bool _leadsFit(
    String? typed,
    String? card, {
    required bool typedTo,
    required bool verb,
  }) {
    // A typed "to" counts only on a card that starts with "to" itself.
    if (typedTo && !verb) return false;
    final typedArticle = typed != null && _articles.contains(typed);
    final cardArticle = card != null && _articles.contains(card);
    if (typedArticle && verb) return false;
    if (typed == null && card == null) return true;
    if (typed == null) return cardArticle;
    if (card == null) return typedArticle;
    if (typedArticle && cardArticle) {
      return (typed == 'the') == (card == 'the');
    }
    return typed == card;
  }

  // ---------------------------------------------------------------------------
  // Endings
  // ---------------------------------------------------------------------------

  /// What a core is in the sets: a whole member (no ending), or a member
  /// with a regular ending, found by rule. A form that is itself a member is
  /// read as that member only.
  List<_Option> _resolve(String core) {
    final whole = _index[core];
    if (whole != null) return [_Option(whole, core, '')];
    final words = core.split(' ');
    final v = _verbIndex(words);
    final out = <_Option>[];
    for (final (lemma, label) in _lemmas(words[v])) {
      final phrase = [...words]..[v] = lemma;
      final key = phrase.join(' ');
      final set = _index[key];
      if (set != null) out.add(_Option(set, key, label));
    }
    return out;
  }

  /// The word of a phrase that takes an ending: the last, or for a phrasal
  /// verb ("give up") its verb.
  static int _verbIndex(List<String> words) {
    var i = words.length - 1;
    while (i > 0 && _particles.contains(words[i])) {
      i--;
    }
    return i;
  }

  /// A word that may carry a doubled final l: a lazy stem ending in l, an
  /// optional second l, then an ending.
  static final RegExp _ell = RegExp(
    r'\b([a-z]+?l)(l?)(ed|ing|ers?|ors?)(?=\s|$)',
  );

  /// The lemmas the British -ll- and American -l- spellings are one word for:
  /// travelled / traveled, counsellor / counselor. A closed list, so that a
  /// slip such as "teling" for "telling" is never read as a spelling variant
  /// and meets the card's own typo pass instead. Only lemmas truly spelled
  /// both ways; a word unsure is left out (rebel, control, fulfil, pull and
  /// fill are not here).
  static const Set<String> _doubledLLemmas = {
    'bevel', 'cancel', 'channel', 'chisel', 'counsel', 'dial', 'duel', //
    'enamel', 'equal', 'fuel', 'funnel', 'grovel', 'jewel', 'label', //
    'level', 'libel', 'marvel', 'medal', 'model', 'panel', 'pedal', //
    'pencil', 'quarrel', 'rival', 'shovel', 'signal', 'snorkel', //
    'swivel', 'total', 'travel', 'trowel', 'tunnel', 'yodel',
  };

  /// [core] with a doubled final l before an ending made single, for the
  /// lemmas of [_doubledLLemmas] only: the British and American spellings of
  /// one word (cancelled, canceled) share this form. Any other word is
  /// returned as it is.
  static String _doubledL(String core) => core.replaceAllMapped(
    _ell,
    (m) => _doubledLLemmas.contains(m[1]) ? '${m[1]}${m[3]}' : m[0]!,
  );

  static const Set<String> _particles = {
    'up', 'down', 'off', 'on', 'out', 'in', 'over', 'away', 'back', //
    'through', 'around', 'about', 'apart', 'by', 'forward', 'together',
    'along',
  };

  static String _cut(String w, int n) => w.substring(0, w.length - n);

  /// The ways a word may be a lemma and a regular ending: `s` (-s, -es,
  /// -ies), `ed`, `ing`, `er`, `est`.
  static List<(String, String)> _lemmas(String w) {
    final out = <(String, String)>[];
    void add(String lemma, String label) {
      if (lemma.length >= 2) out.add((lemma, label));
    }

    void withDoubling(String stem, String label) {
      add(stem, label);
      if (stem.length >= 3 && stem[stem.length - 1] == stem[stem.length - 2]) {
        add(_cut(stem, 1), label);
      }
    }

    if (w.length < 3) return out;
    if (w.endsWith('ies')) add('${_cut(w, 3)}y', 's');
    if (w.endsWith('es')) add(_cut(w, 2), 's');
    if (w.endsWith('s') && !w.endsWith('ss')) add(_cut(w, 1), 's');
    if (w.endsWith('ied')) add('${_cut(w, 3)}y', 'ed');
    if (w.endsWith('ed')) {
      withDoubling(_cut(w, 2), 'ed');
      add(_cut(w, 1), 'ed');
    }
    if (w.endsWith('ing')) {
      withDoubling(_cut(w, 3), 'ing');
      add('${_cut(w, 3)}e', 'ing');
    }
    if (w.endsWith('ier')) add('${_cut(w, 3)}y', 'er');
    if (w.endsWith('er')) {
      withDoubling(_cut(w, 2), 'er');
      add(_cut(w, 1), 'er');
    }
    if (w.endsWith('iest')) add('${_cut(w, 4)}y', 'est');
    if (w.endsWith('est')) {
      withDoubling(_cut(w, 3), 'est');
      add(_cut(w, 2), 'est');
    }
    return out;
  }

  /// The spellings of [member] with the ending [label] (the member itself
  /// for none): the verb of a phrase takes it. Never empty.
  static List<String> _inflect(String member, String label) {
    if (label.isEmpty) return [member];
    final words = member.split(' ');
    final v = _verbIndex(words);
    final w = words[v];
    final forms = <String>{};
    final consonantY =
        w.length > 1 && w.endsWith('y') && !'aeiou'.contains(w[w.length - 2]);
    final dropE = w.endsWith('e');
    final last = w[w.length - 1];
    switch (label) {
      case 's':
        if (consonantY) forms.add('${_cut(w, 1)}ies');
        forms.add('${w}s');
        forms.add('${w}es');
      case 'ed':
        if (consonantY) forms.add('${_cut(w, 1)}ied');
        forms.add(dropE ? '${w}d' : '${w}ed');
        forms.add('$w${last}ed');
      case 'ing':
        forms.add(dropE ? '${_cut(w, 1)}ing' : '${w}ing');
        forms.add('$w${last}ing');
      case 'er':
      case 'est':
        if (consonantY) forms.add('${_cut(w, 1)}i$label');
        forms.add(dropE ? '$w${label.substring(1)}' : '$w$label');
        forms.add('$w$last$label');
    }
    forms.remove('');
    return [
      for (final f in forms) ([...words]..[v] = f).join(' '),
    ];
  }

  static bool _within(String a, String b, int allowed) {
    if ((a.length - b.length).abs() > allowed) return false;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      var rowMin = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var best = previous[j - 1] + cost;
        if (current[j - 1] + 1 < best) best = current[j - 1] + 1;
        if (previous[j] + 1 < best) best = previous[j] + 1;
        current[j] = best;
        if (best < rowMin) rowMin = best;
      }
      if (rowMin > allowed) return false;
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[b.length] <= allowed;
  }
}

class _Option {
  const _Option(this.set, this.lemma, this.label);

  /// The set the lemma is a member of.
  final int set;
  final String lemma;

  /// The regular ending taken off, or empty for a whole member.
  final String label;
}
