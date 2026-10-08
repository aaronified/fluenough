import '../models/card.dart';
import '../models/drill_mode.dart';
import '../models/reading.dart';
import 'session_queue.dart';

/// How a session item is asked (ADR-0024). Whichever way, it records the
/// item's own mode.
enum Ask {
  /// The mode's own way: recognition rated by the learner, production,
  /// listening and grammar typed, speaking said, reading chosen.
  own,

  /// Shown the target, choose its meaning. Recognition.
  chooseMeaning,

  /// Shown the meaning, choose the target. Production.
  chooseWord,

  /// Hear the target, choose it: script practice, where what is heard is
  /// the form. Listening.
  hearAndChoose,

  /// Hear the target, choose its meaning: Hear's choose grade (ADR-0034).
  /// Listening.
  hearMeaning,

  /// Match the targets of a few items with their meanings, by dragging or
  /// tapping. Recognition, for each.
  matchPairs,

  /// Put the target's words in order. Production.
  rearrange,

  /// Shown the word, its reading and meaning, and played aloud: a lesson
  /// teaching it, before its first question. Records nothing.
  teach;

  /// Whether the learner picks one of the options the session offers.
  bool get chooses =>
      this == chooseMeaning ||
      this == chooseWord ||
      this == hearAndChoose ||
      this == hearMeaning;

  /// Whether the options are meanings rather than words.
  bool get choosesMeaning => this == chooseMeaning || this == hearMeaning;

  /// What [card] shows as an option of this kind of question: its meaning
  /// for [chooseMeaning] and [hearMeaning], else its target.
  String optionOf(Card card) => choosesMeaning ? card.native : card.target;
}

/// How many items a match pairs question matches.
const int matchSize = 4;

/// [items] as a review asks them (ADR-0024), in the same order.
///
/// - **Recognition** is chosen rather than rated: in fours, in turn, match
///   pairs and then multiple choice, a last four short of four by multiple
///   choice. Four whose meanings or targets are not all different cannot be
///   matched, and are chosen. Where [canChoose] finds too little to choose
///   from, it stays rated.
/// - **Production** of a card that [Card.rearranges] is rearranged.
/// - **Listening** is Hear (ADR-0034): its meaning is chosen while the pair
///   is new or was last missed, and typed once it was last remembered.
///   Where [hearsForm] says what is heard is the form itself, as in script
///   practice, it is typed as heard.
///
/// Reading questions and every other mode are asked their own way.
List<SessionItem> reviewAsks(
  List<SessionItem> items, {
  required bool Function(SessionItem item) canChoose,
  bool Function(SessionItem item)? hearsForm,
}) {
  final recognised = <int>[
    for (final (i, item) in items.indexed)
      if (item.mode == DrillMode.recognition &&
          item.card is! QuestionCard &&
          canChoose(item))
        i,
  ];
  // By index: the item asked another way, or null where a match took it.
  final asked = <int, SessionItem?>{};
  for (var start = 0; start < recognised.length; start += matchSize) {
    final chunk = recognised.skip(start).take(matchSize).toList();
    final group = <SessionItem>[for (final i in chunk) items[i]];
    if ((start ~/ matchSize).isEven &&
        chunk.length == matchSize &&
        _matchable(group)) {
      asked[chunk.first] = group.first.askedAs(Ask.matchPairs, group: group);
      for (final i in chunk.skip(1)) {
        asked[i] = null;
      }
    } else {
      for (final i in chunk) {
        asked[i] = items[i].askedAs(Ask.chooseMeaning);
      }
    }
  }
  for (final (i, item) in items.indexed) {
    if (item.mode == DrillMode.production && item.card.rearranges) {
      asked[i] = item.askedAs(Ask.rearrange);
    }
    if (item.mode == DrillMode.listening &&
        item.card is! QuestionCard &&
        !(hearsForm?.call(item) ?? false) &&
        (item.state?.repetitions ?? 0) == 0 &&
        canChoose(item.askedAs(Ask.hearMeaning))) {
      asked[i] = item.askedAs(Ask.hearMeaning);
    }
  }
  return <SessionItem>[
    for (final (i, item) in items.indexed)
      if (!asked.containsKey(i)) item else ?asked[i],
  ];
}

/// Whether [group] can be matched: no two of its cards share a meaning or
/// a target, which would make two matches right.
bool _matchable(List<SessionItem> group) {
  final natives = <String>{for (final item in group) item.card.native};
  final targets = <String>{for (final item in group) item.card.target};
  return natives.length == group.length && targets.length == group.length;
}
