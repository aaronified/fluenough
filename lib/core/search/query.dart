/// What the Decks search bar's text means (#527): free text, and three
/// tokens, `kind:`, `status:` and `theme:`, that narrow it. Free of
/// Flutter.
library;

/// The tokens the search bar takes, in the order their chips sit
/// (mockup section 4). `level:`, `in:`, `has:` and `coming:` were not
/// chosen (owner, 2026-10-16).
enum SearchToken {
  kind,
  status,
  theme;

  /// What is typed: `kind`.
  String get key => name;
}

/// What a result is, for the `kind:` token and the chip on a row. A
/// sentence or phrasebook deck has none: it is found by text only (owner,
/// 2026-10-16: "Leave out phrases as that will otherwise confuse people").
enum SearchKind {
  words,
  grammar,
  script,
  reading;

  /// What is typed after `kind:`.
  String get slug => name;
}

/// A card's one status, in the order the first that holds wins (owner,
/// 2026-10-16: "Yes, both"): set aside, struggling, forgetting, learning,
/// learnt, not learnt.
enum CardStatus {
  setAside('set-aside'),
  struggling('struggling'),
  forgetting('forgetting'),
  learning('learning'),
  learnt('learnt'),
  notLearnt('not-learnt');

  const CardStatus(this.slug);

  /// What is typed after `status:`.
  final String slug;
}

/// What one skill of a card says about it, for [cardStatusOf].
class SkillState {
  const SkillState({
    required this.scheduled,
    this.intervalDays = 0,
    this.due = false,
    this.lapses = 0,
  });

  /// The skill has been drilled: it has a schedule.
  final bool scheduled;

  /// Days to its next review, when scheduled.
  final int intervalDays;

  /// Its review is due now.
  final bool due;

  /// Lapses over its whole history.
  final int lapses;
}

/// The days out every skill is scheduled for a card to be learnt: Anki's
/// "mature", `StudyHours.rememberedDays`.
const int learntDays = 21;

/// The lapses at which a skill is a leech, `kLeechThreshold`.
const int struggleLapses = 5;

/// A card's status from its [skills] (those drillable now) and whether a
/// skill of it was [setAside] (read over all its skills: the drillable
/// ones leave set-aside pairs out).
CardStatus cardStatusOf({
  required bool setAside,
  required Iterable<SkillState> skills,
  int learnt = learntDays,
  int struggle = struggleLapses,
}) {
  if (setAside) return CardStatus.setAside;
  final list = skills.toList();
  if (list.any((s) => s.lapses >= struggle)) return CardStatus.struggling;
  if (list.any((s) => s.scheduled && s.due)) return CardStatus.forgetting;
  if (!list.any((s) => s.scheduled)) return CardStatus.notLearnt;
  if (list.every((s) => s.scheduled && s.intervalDays >= learnt)) {
    return CardStatus.learnt;
  }
  return CardStatus.learning;
}

/// The bar's text read: the chips it holds, what is left as text, and a
/// token being typed that has no value yet.
class ParsedSearch {
  const ParsedSearch({
    this.chips = const <SearchToken, String>{},
    this.text = '',
    this.pending,
    this.pendingPrefix = '',
  });

  /// Each token's chosen value (its slug, or a theme's id).
  final Map<SearchToken, String> chips;

  /// The free text, its words single-spaced.
  final String text;

  /// A token typed with its colon and no whole value yet, such as `kind:gr`:
  /// its combobox is open.
  final SearchToken? pending;

  /// What is typed after the pending token's colon.
  final String pendingPrefix;

  bool get isEmpty => chips.isEmpty && text.isEmpty;

  /// The kind chip's value.
  SearchKind? get kind => _byName(SearchKind.values, chips[SearchToken.kind]);

  /// The status chip's value.
  CardStatus? get status {
    final v = chips[SearchToken.status];
    for (final s in CardStatus.values) {
      if (s.slug == v) return s;
    }
    return null;
  }

  /// The theme chip's value: a theme id.
  String? get theme => chips[SearchToken.theme];
}

T? _byName<T extends Enum>(List<T> values, String? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

final RegExp _tokenWord = RegExp(r'^(kind|status|theme):(.*)$');

/// Reads [input], as typed in the bar. A word `kind:grammar` whose value is
/// whole becomes a chip once a space follows it (or when it is not the last
/// word); a token with a value still being typed is [ParsedSearch.pending].
/// A value that is none of the token's is left as text. [themes] are the
/// theme ids `theme:` accepts, such as `first-words`.
ParsedSearch parseSearch(String input, {Iterable<String> themes = const []}) {
  final chips = <SearchToken, String>{};
  final text = <String>[];
  SearchToken? pending;
  var prefix = '';
  final words = input.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final trailingSpace = input.isNotEmpty && RegExp(r'\s$').hasMatch(input);
  final themeSet = themes.toSet();
  for (final (i, word) in words.indexed) {
    final lower = word.toLowerCase();
    final m = _tokenWord.firstMatch(lower);
    final last = i == words.length - 1 && !trailingSpace;
    if (m == null) {
      text.add(word);
      continue;
    }
    final token = SearchToken.values.byName(m.group(1)!);
    final value = m.group(2)!;
    final whole = switch (token) {
      SearchToken.kind => SearchKind.values.any((k) => k.slug == value),
      SearchToken.status => CardStatus.values.any((s) => s.slug == value),
      SearchToken.theme => themeSet.contains(value),
    };
    if (whole && !last) {
      chips[token] = value;
    } else if (last) {
      pending = token;
      prefix = value;
    } else {
      text.add(word);
    }
  }
  return ParsedSearch(
    chips: chips,
    text: text.join(' '),
    pending: pending,
    pendingPrefix: prefix,
  );
}

/// [parsed] written back as the bar's text, chips first.
String writeSearch(Map<SearchToken, String> chips, String text) => <String>[
  for (final t in SearchToken.values)
    if (chips[t] != null) '${t.key}:${chips[t]}',
  if (text.isNotEmpty) text,
].join(' ');
