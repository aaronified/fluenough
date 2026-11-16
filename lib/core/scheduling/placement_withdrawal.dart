import '../models/drill_mode.dart';
import '../private/private_ids.dart';
import 'ask.dart';
import 'replay.dart';

/// Placement credit taken back, as the learner confirmed it (wiki,
/// Plan-Placement-V2, point 17): the credit one moment of a language wrote,
/// for some decks, in some modes and script.
///
/// The review log is append-only (AGENTS.md rule 9), so a withdrawal removes
/// nothing from it. It is a record kept beside it, like a leech action, and
/// the replay leaves out exactly the reviews it names ([isWithdrawnCredit]).
class PlacementWithdrawal {
  PlacementWithdrawal({
    required this.at,
    required this.language,
    required this.creditAt,
    required Iterable<DrillMode> modes,
    required this.script,
    required Iterable<String> deckIds,
  }) : modes = Set<DrillMode>.of(modes),
       deckIds = Set<String>.of(deckIds);

  /// When it was withdrawn.
  final DateTime at;

  /// The language whose credit it is.
  final String language;

  /// The credit's moment: the `placed_at` second.
  final int creditAt;

  /// The drills of the credit.
  final Set<DrillMode> modes;

  /// The script of a script skill's credit; null for the word skills'.
  final String? script;

  /// The decks whose credit it takes back.
  final Set<String> deckIds;

  /// The modes in the order they are stored in: sorted by name.
  List<String> get modeNames => <String>[for (final m in modes) m.name]..sort();

  /// The decks in the order they are stored in: sorted.
  List<String> get sortedDeckIds => deckIds.toList()..sort();

  @override
  String toString() =>
      'PlacementWithdrawal($language@$creditAt ${modeNames.join('+')} '
      '${script ?? '-'} ${deckIds.length} decks)';
}

/// What makes two withdrawals the same one, for an import that must not
/// double them.
String withdrawalIdentity(PlacementWithdrawal w) =>
    '${w.language}|${w.creditAt}|${w.at.millisecondsSinceEpoch}|'
    '${w.modeNames.join(',')}|${w.script ?? ''}|${w.sortedDeckIds.join(',')}';

/// [withdrawals] oldest first, keeping their order for a tie.
List<PlacementWithdrawal> withdrawalsInTimeOrder(
  Iterable<PlacementWithdrawal> withdrawals,
) {
  final indexed = withdrawals.indexed.toList()
    ..sort((a, b) {
      final byTime = a.$2.at.compareTo(b.$2.at);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
  return <PlacementWithdrawal>[for (final (_, w) in indexed) w];
}

/// The language a deck id names: the code before its first dash, which is
/// how a card's language is read from its deck everywhere in the log; for a
/// private package's deck (`fnpd-<code>-...`, #1017) the code after `fnpd-`.
String deckLanguage(String deckId) => languageOfId(deckId);

/// Whether [r] has the shape of what placement credit writes
/// (`creditPlacement`): grade 5, no time taken, no answer, asked its own way
/// (or not recorded, before schema 9). A real answer has an elapsed time or
/// an answer given.
bool hasCreditShape(LoggedReview r) =>
    r.grade == 5 &&
    r.elapsed == Duration.zero &&
    r.answerGiven == null &&
    (r.asked == null || r.asked == Ask.own);

/// The whole second of [at], as `placed_at` keeps a moment.
int momentOf(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

/// Whether [r] is the credit some withdrawal of [withdrawals] takes back, and
/// nothing else: all of these must hold for one withdrawal `w`.
///
/// - [languageOf] of its deck is `w.language`;
/// - it was written within the second of `w.creditAt`;
/// - it is not after `w.at`;
/// - its deck is in `w.deckIds` and its mode in `w.modes`;
/// - its script is `w.script`;
/// - it has the shape of credit ([hasCreditShape]).
///
/// A real answer in the same second has an elapsed time or an answer, so it
/// is never matched.
bool isWithdrawnCredit(
  LoggedReview r,
  List<PlacementWithdrawal> withdrawals, [
  String Function(String deckId)? languageOf,
]) {
  if (withdrawals.isEmpty || !hasCreditShape(r)) return false;
  final language = (languageOf ?? deckLanguage)(r.deckId);
  final second = momentOf(r.at);
  for (final w in withdrawals) {
    if (w.creditAt != second) continue;
    if (w.language != language) continue;
    if (r.at.isAfter(w.at)) continue;
    if (!w.deckIds.contains(r.deckId)) continue;
    if (!w.modes.contains(r.key.mode)) continue;
    if (r.script != w.script) continue;
    return true;
  }
  return false;
}

/// [reviews] without the credit [withdrawals] take back, in the order given,
/// and the reviews it left out. The replay of the first is the replay of the
/// log as if that credit had never been written; the second is what an
/// export still holds.
({List<LoggedReview> kept, List<LoggedReview> withdrawn})
withoutWithdrawnCredit(
  Iterable<LoggedReview> reviews,
  List<PlacementWithdrawal> withdrawals, [
  String Function(String deckId)? languageOf,
]) {
  if (withdrawals.isEmpty) {
    return (kept: reviews.toList(), withdrawn: const <LoggedReview>[]);
  }
  final bySecond = <int, List<PlacementWithdrawal>>{};
  for (final w in withdrawals) {
    bySecond.putIfAbsent(w.creditAt, () => <PlacementWithdrawal>[]).add(w);
  }
  final kept = <LoggedReview>[];
  final withdrawn = <LoggedReview>[];
  for (final r in reviews) {
    final candidates = bySecond[momentOf(r.at)];
    if (candidates != null && isWithdrawnCredit(r, candidates, languageOf)) {
      withdrawn.add(r);
    } else {
      kept.add(r);
    }
  }
  return (kept: kept, withdrawn: withdrawn);
}

/// The withdrawals that take back [language]'s credit above a new level
/// (point 17.3, step 1): for each moment of [moments], the decks for which
/// [above] says yes that hold a credited pair in [modes] (and [script]) among
/// [reviews], at that moment. A moment with no such deck gets no withdrawal.
///
/// [reviews] are the log as the replay reads it, withdrawals already taken
/// out, so credit that is gone is not withdrawn twice.
List<PlacementWithdrawal> withdrawalsAbove({
  required String language,
  required Iterable<LoggedReview> reviews,
  required Set<int> moments,
  required Set<DrillMode> modes,
  required String? script,
  required bool Function(String deckId) above,
  required DateTime at,
}) {
  final decks = <int, Set<String>>{};
  for (final r in reviews) {
    if (!hasCreditShape(r)) continue;
    final moment = momentOf(r.at);
    if (!moments.contains(moment)) continue;
    if (deckLanguage(r.deckId) != language) continue;
    if (!modes.contains(r.key.mode) || r.script != script) continue;
    if (!above(r.deckId)) continue;
    decks.putIfAbsent(moment, () => <String>{}).add(r.deckId);
  }
  return <PlacementWithdrawal>[
    for (final moment in (decks.keys.toList()..sort()))
      PlacementWithdrawal(
        at: at,
        language: language,
        creditAt: moment,
        modes: modes,
        script: script,
        deckIds: decks[moment]!,
      ),
  ];
}
