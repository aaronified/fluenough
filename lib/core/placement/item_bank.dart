import 'admission.dart';
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

class _Step {
  _Step(this.make, {this.starter = false});

  final List<RegItem> Function() make;
  final bool starter;
}

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

  /// Builds the bank for [data]: every generator, and the admission audit of
  /// every class (the offline audit's build: tools and tests).
  static ItemBank build(
    PlacementLanguageData data, {
    int seed = 1,
    bool runtime = false,
  }) {
    final cx = GenContext(data, seed: seed);
    final g = ItemGenerators(cx);
    final all = <RegItem>[];
    for (final step in _steps(g, runtime: runtime)) {
      all.addAll(step.make());
    }
    return _finish(data, cx, g, all);
  }

  /// The items a run asks, built in steps (the app's build): the generators
  /// of the formats a screen can show, the cheap and most asked first. After
  /// the [starter] steps the clean items of the formats they made are handed
  /// to [onStarter] (a run can begin with them; the audit has passed these
  /// classes for the course languages, and a cognate class is left to the full
  /// bank); the rest follows, then the admission audit of the classes made,
  /// and the full list is returned. A [pause] between steps lets a thread
  /// that must not be held draw; [onProgress] says how far it is (0 to 1);
  /// [cancelled] stops it with null.
  static Future<List<RegItem>?> buildItems(
    PlacementLanguageData data, {
    int seed = 1,
    Future<void> Function()? pause,
    void Function(double progress)? onProgress,
    void Function(List<RegItem> starter)? onStarter,
    bool Function()? cancelled,
  }) async {
    final made = await _generateRuntime(
      data,
      seed: seed,
      pause: pause,
      onProgress: onProgress,
      onStarter: onStarter,
      cancelled: cancelled,
    );
    if (made == null) return null;
    final (cx, g, all, profile) = made;
    if (profile != null) {
      // The audit's verdict for this course, on these decks, is known: no
      // audit now.
      final tiles = profile.decoys > 0
          ? g.wordTiles(profile.decoys)
          : const <RegItem>[];
      onProgress?.call(1);
      return List<RegItem>.unmodifiable(<RegItem>[
        for (final it in <RegItem>[...all, ...tiles])
          if (profile.admits(it.auditClass)) it,
      ]);
    }
    final bank = _finish(data, cx, g, all);
    onProgress?.call(1);
    return bank.items;
  }

  /// The audit of what the app makes: the same generators as [buildItems], the
  /// audit run on their output, and its verdict (the classes excluded and the
  /// decoys of the word tiles). This is the verdict `admission.dart` stores.
  static AdmissionProfile auditRuntime(
    PlacementLanguageData data, {
    int seed = 1,
  }) {
    final bank = build(data, seed: seed, runtime: true);
    return AdmissionProfile(
      deckKey: admissionKey(data),
      excluded: bank.excluded,
      decoys: bank.decoys,
    );
  }

  /// The generators of the app's build, run in steps. Null when cancelled;
  /// the stored verdict that applies to [data] (null when there is none, or
  /// it was made on other decks) comes with them. The starter is offered only
  /// under such a verdict, and only the classes it admits.
  static Future<(GenContext, ItemGenerators, List<RegItem>, AdmissionProfile?)?>
  _generateRuntime(
    PlacementLanguageData data, {
    required int seed,
    Future<void> Function()? pause,
    void Function(double progress)? onProgress,
    void Function(List<RegItem> starter)? onStarter,
    bool Function()? cancelled,
  }) async {
    final cx = GenContext(data, seed: seed);
    final g = ItemGenerators(cx);
    final steps = _steps(g, runtime: true).toList();
    final profile = AdmissionProfile.of(data);
    final total = steps.length + 1;
    final all = <RegItem>[];
    var starterSent = false;
    for (var i = 0; i < steps.length; i++) {
      if (cancelled?.call() ?? false) return null;
      all.addAll(steps[i].make());
      onProgress?.call((i + 1) / total);
      if (!starterSent && i + 1 < steps.length && !steps[i + 1].starter) {
        starterSent = true;
        // A run may begin on the first formats only where the audit has
        // already passed their classes, on these decks.
        if (profile != null) {
          onStarter?.call(starterOf(all, profile));
        }
      }
      await pause?.call();
    }
    if (cancelled?.call() ?? false) return null;
    return (cx, g, all, profile);
  }

  /// The same bank as [build], built in steps with a [pause] between them,
  /// reporting [onProgress] (0 to 1) after each, and stopping with null when
  /// [cancelled] says so.
  static Future<ItemBank?> buildAsync(
    PlacementLanguageData data, {
    int seed = 1,
    Future<void> Function()? pause,
    void Function(double progress)? onProgress,
    bool Function()? cancelled,
  }) async {
    final cx = GenContext(data, seed: seed);
    final g = ItemGenerators(cx);
    final steps = _steps(g).toList();
    // The word tiles and the audit weigh as one step.
    final total = steps.length + 1;
    final all = <RegItem>[];
    for (var i = 0; i < steps.length; i++) {
      if (cancelled?.call() ?? false) return null;
      all.addAll(steps[i].make());
      onProgress?.call((i + 1) / total);
      await pause?.call();
    }
    if (cancelled?.call() ?? false) return null;
    onProgress?.call(steps.length / total);
    await pause?.call();
    final bank = _finish(data, cx, g, all);
    onProgress?.call(1);
    return bank;
  }

  /// The formats a run may begin with ([starterOf]): the cheap generators,
  /// which make the most asked items.
  static const Set<String> starterFormats = <String>{
    'F2',
    'F13',
    'F7',
    'F18',
    'F8',
    'F24',
  };

  /// What a run can begin with out of [items] (a whole bank, or what the
  /// first generators made): the clean items of the starter formats, in the
  /// bank's order.
  ///
  /// With a [profile], only the classes it admits (the starter of a run is
  /// then the same list whether it is cut from what the generators made or
  /// from the admitted bank).
  static List<RegItem> starterOf(
    Iterable<RegItem> items, [
    AdmissionProfile? profile,
  ]) => <RegItem>[
    for (final it in items)
      if (starterFormats.contains(it.format) &&
          it.cognateClass == 'clean' &&
          (profile == null || profile.admits(it.auditClass)))
        it,
  ];

  /// The generators, in the order the bank lists their items. With [runtime],
  /// only the formats a screen can show, the starter formats first; the items
  /// the picker never asks (word order, matching, cloze, gender) are not made.
  /// A generator that makes one item for two formats (the pseudowords, the
  /// sentence picks) runs once.
  static Iterable<_Step> _steps(ItemGenerators g, {bool runtime = false}) {
    List<RegItem>? pseudo;
    List<RegItem>? picks;
    List<RegItem> pseudoOf(String format) {
      pseudo ??= g.pseudowords('F1');
      return format == 'F1'
          ? pseudo!
          : <RegItem>[for (final i in pseudo!) i.withFormat(format)];
    }

    List<RegItem> picksOf(String format) {
      picks ??= g.sentencePicks('F5');
      return format == 'F5'
          ? picks!
          : <RegItem>[for (final i in picks!) i.withFormat(format)];
    }

    // A format's items, or those of the format it reverses (the English
    // spoken), made once.
    final made = <String, List<RegItem>>{};
    List<RegItem> reverseOf(String format) {
      final base = baseFormat(format);
      final items = made[base] ??= switch (base) {
        'F3' => g.meaningToWord(),
        'F13' => g.wordToMeaning('F13'),
        'F7' => g.typedOrSaid('F7'),
        'F8' => g.sentenceTiles('F8'),
        _ => g.gapTyping(),
      };
      return base == format
          ? items
          : <RegItem>[for (final i in items) i.withFormat(format)];
    }

    if (runtime) {
      return <_Step>[
        _Step(() => g.wordToMeaning('F2'), starter: true),
        _Step(() => reverseOf('F13'), starter: true),
        _Step(() => reverseOf('F26')),
        _Step(() => reverseOf('F7'), starter: true),
        _Step(() => g.typedOrSaid('F18'), starter: true),
        _Step(() => reverseOf('F8'), starter: true),
        _Step(() => reverseOf('F24'), starter: true),
        _Step(() => reverseOf('F23')),
        _Step(() => reverseOf('F21')),
        _Step(() => reverseOf('F25')),
        _Step(() => reverseOf('F3')),
        _Step(() => reverseOf('F22')),
        _Step(() => g.yesNoReal('F1')),
        _Step(() => g.yesNoReal('F14')),
        _Step(() => pseudoOf('F1')),
        _Step(() => pseudoOf('F14')),
        _Step(() => picksOf('F5')),
        _Step(() => picksOf('F17')),
      ];
    }
    return <_Step>[
      _Step(() => g.wordToMeaning('F2')),
      _Step(() => reverseOf('F13')),
      _Step(() => reverseOf('F26')),
      _Step(() => reverseOf('F3')),
      _Step(() => reverseOf('F22')),
      _Step(() => reverseOf('F7')),
      _Step(() => reverseOf('F23')),
      _Step(() => reverseOf('F21')),
      _Step(() => reverseOf('F25')),
      _Step(() => g.typedOrSaid('F18')),
      _Step(() => g.yesNoReal('F1')),
      _Step(() => g.yesNoReal('F14')),
      _Step(() => pseudoOf('F1')),
      _Step(() => pseudoOf('F14')),
      _Step(() => reverseOf('F8')),
      _Step(() => reverseOf('F24')),
      _Step(g.wordOrder),
      _Step(() => picksOf('F5')),
      _Step(() => picksOf('F17')),
      _Step(g.cloze),
      _Step(g.genderExceptions),
      _Step(g.matching),
    ];
  }

  static ItemBank _finish(
    PlacementLanguageData data,
    GenContext cx,
    ItemGenerators g,
    List<RegItem> all,
  ) {
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
