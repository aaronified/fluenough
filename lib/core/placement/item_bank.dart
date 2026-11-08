import 'item_audit.dart';
import 'item_generators.dart';
import 'item_registry.dart';
import 'placement_data.dart';

// The item bank of "Find my level" V3: every generator run over a language's
// decks, the word-tile decoys chosen by the audit, the items of a class that
// fails the admission audit left out, and the rule that a card is never asked
// twice in a run (wiki/Plan-Placement-V3.md, item generation 6).
//
// Pure Dart. The bank is built once per language and course version.

/// The most decoy units a word tile item may carry.
const int kMaxDecoys = 4;

/// A language's admitted items and what the audit found.
class ItemBank {
  ItemBank._(
    this.language,
    this.items,
    this.audit,
    this.excluded,
    this.decoys,
    this.context,
  );

  final String language;

  /// The admitted items.
  final List<RegItem> items;

  /// The audit of every class, admitted or not.
  final AuditReport audit;

  /// The classes left out because the audit failed them, or because their
  /// generator could not meet its admission test.
  final List<String> excluded;

  /// The decoy units of the word tiles (0 when no number passed).
  final int decoys;

  /// The generator context (cards, scores), for the audit and the tests.
  final GenContext context;

  /// Builds the bank for [data].
  static ItemBank build(PlacementLanguageData data, {int seed = 1}) {
    final cx = GenContext(data, seed: seed);
    final g = ItemGenerators(cx);
    final all = <RegItem>[
      ...g.wordToMeaning('F2'),
      ...g.wordToMeaning('F13'),
      ...g.meaningToWord(),
      ...g.typedOrSaid('F7'),
      ...g.gapTyping(),
      ...g.typedOrSaid('F18'),
      ...g.yesNoReal('F1'),
      ...g.yesNoReal('F14'),
      ...g.pseudowords('F1'),
      ...g.pseudowords('F14'),
      ...g.sentenceTiles('F8'),
      ...g.sentenceTiles('F16'),
      ...g.wordOrder(),
      ...g.sentencePicks('F5'),
      ...g.sentencePicks('F17'),
      ...g.cloze(),
      ...g.genderExceptions(),
      ...g.matching(),
    ];
    final excluded = <String>[];
    // Word tiles: the fewest decoys at which the strong anagram solver stays
    // within the admission bound.
    var decoys = 0;
    for (var d = 2; d <= kMaxDecoys; d++) {
      final tiles = g.wordTiles(d);
      if (tiles.isEmpty) break;
      final report = auditItems(tiles, cx);
      final cls = report.classes['F4:clean'];
      if (cls != null && cls.passes) {
        all.addAll(tiles);
        decoys = d;
        break;
      }
    }
    if (decoys == 0) excluded.add('F4:clean');
    final report = auditItems(all, cx);
    final admitted = <RegItem>[
      for (final it in all)
        if (report.admits(it.auditClass)) it else ..._left(excluded, it),
    ];
    return ItemBank._(
      data.language,
      List<RegItem>.unmodifiable(admitted),
      report,
      List<String>.unmodifiable(excluded.toSet().toList()..sort()),
      decoys,
      cx,
    );
  }

  static Iterable<RegItem> _left(List<String> excluded, RegItem it) {
    excluded.add(it.auditClass);
    return const <RegItem>[];
  }

  /// The items of [format] (all if null), by deck.
  Iterable<RegItem> ofFormat(String? format) =>
      format == null ? items : items.where((i) => i.format == format);

  /// The items still askable in a run that has asked [asked]: none shares a
  /// card or a lemma family with any of them. [asked] are items already
  /// asked (a card is never asked twice in a run, drill-down included).
  Iterable<RegItem> available(Iterable<RegItem> asked, {String? format}) {
    final keys = <String>{for (final a in asked) ...a.conflictKeys};
    return ofFormat(format)
        .where((i) => i.conflictKeys.every((k) => !keys.contains(k)));
  }

  /// How many admitted items each format has.
  Map<String, int> get countsByFormat {
    final out = <String, int>{};
    for (final i in items) {
      out[i.format] = (out[i.format] ?? 0) + 1;
    }
    return out;
  }
}
