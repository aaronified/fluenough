import 'dart:convert';

import 'package:yaml/yaml.dart';

import 'private_package.dart';

/// One card of a package as the update summary lists it: its id, the word,
/// its reading and its meaning (from the first layer that has one).
class PrivateCardLine {
  const PrivateCardLine({
    required this.id,
    required this.target,
    this.reading,
    this.meaning,
    this.fields = const <String>[],
    this.replaces,
  });

  final String id;
  final String target;
  final String? reading;
  final String? meaning;

  /// For a changed card, the names of the fields that differ.
  final List<String> fields;

  /// The built-in card this one replaces (`replaces`), when it says.
  final String? replaces;
}

/// What a newer revision of an installed package does to it (Plan-Private-
/// Languages, task 18; mockup `private-update-summary`): the cards it adds,
/// changes and drops, the ids that are retired, and how the path moves.
///
/// Progress belongs to a card's id and ids never change in an update, so the
/// summary only needs to say which cards stay, which are new, and which go.
/// Pure Dart; reads text only and never throws.
class PrivateUpdateSummary {
  const PrivateUpdateSummary({
    required this.fromRevision,
    required this.toRevision,
    required this.added,
    required this.changed,
    required this.removed,
    required this.retiredNow,
    required this.retiredEarlier,
    required this.unitsBefore,
    required this.unitsAfter,
    required this.unchanged,
  });

  final int fromRevision;
  final int toRevision;

  /// Cards the new revision adds, sorted by id.
  final List<PrivateCardLine> added;

  /// Cards in both whose text differs.
  final List<PrivateCardLine> changed;

  /// Cards of the installed revision that the new one drops.
  final List<PrivateCardLine> removed;

  /// The ids this update retires: the cards it drops.
  final int retiredNow;

  /// Ids retired by earlier revisions (and by a removed package of the same
  /// id) that still stay retired.
  final int retiredEarlier;

  /// Units of the path before and after, 0 for a package with no path.
  final int unitsBefore;
  final int unitsAfter;

  /// Cards in both, unchanged.
  final int unchanged;

  /// Every retired id, now and earlier.
  int get retiredTotal => retiredNow + retiredEarlier;

  /// Changed cards that say which built-in card they replace.
  List<PrivateCardLine> get replacing => <PrivateCardLine>[
    for (final c in changed)
      if (c.replaces != null) c,
  ];

  /// Changed cards that keep their id and their progress.
  List<PrivateCardLine> get keepingProgress => <PrivateCardLine>[
    for (final c in changed)
      if (c.replaces == null) c,
  ];

  /// Whether the update changes anything about the cards or the path.
  bool get isEmpty =>
      added.isEmpty &&
      changed.isEmpty &&
      removed.isEmpty &&
      unitsBefore == unitsAfter;

  /// Compares the installed package [before] with the new [after] (path in
  /// the package to text). [retired] are the ids the package will have
  /// retired once installed, the cards dropped now among them.
  static PrivateUpdateSummary compute({
    required Map<String, String> before,
    required Map<String, String> after,
    required int fromRevision,
    required int toRevision,
    Iterable<String> retired = const <String>[],
  }) {
    final old = _Index.of(before);
    final now = _Index.of(after);
    final added = <PrivateCardLine>[];
    final changed = <PrivateCardLine>[];
    final removed = <PrivateCardLine>[];
    var unchanged = 0;
    for (final id in now.cards.keys.toList()..sort()) {
      final card = now.cards[id]!;
      final was = old.cards[id];
      if (was == null) {
        added.add(card.line(now.meanings[id]));
      } else if (was.signature != card.signature ||
          old.meanings[id] != now.meanings[id]) {
        changed.add(
          card.line(
            now.meanings[id],
            fields: <String>[
              ..._differing(was.fields, card.fields),
              if (old.meanings[id] != now.meanings[id]) 'native',
            ],
          ),
        );
      } else {
        unchanged++;
      }
    }
    for (final id in old.cards.keys.toList()..sort()) {
      if (!now.cards.containsKey(id)) {
        removed.add(old.cards[id]!.line(old.meanings[id]));
      }
    }
    final retiredAll = retired.toSet();
    final dropped = removed.map((c) => c.id).toSet();
    return PrivateUpdateSummary(
      fromRevision: fromRevision,
      toRevision: toRevision,
      added: added,
      changed: changed,
      removed: removed,
      retiredNow: dropped.length,
      retiredEarlier: retiredAll.difference(dropped).length,
      unitsBefore: old.units,
      unitsAfter: now.units,
      unchanged: unchanged,
    );
  }

  static List<String> _differing(
    Map<String, String> a,
    Map<String, String> b,
  ) => <String>[
    for (final key in <String>{...a.keys, ...b.keys}.toList()..sort())
      if (a[key] != b[key]) key,
  ];
}

class _Card {
  const _Card(this.id, this.fields);

  final String id;

  /// Each field of the card, by name, as JSON text.
  final Map<String, String> fields;

  String get signature => jsonEncode(fields);

  PrivateCardLine line(String? meaning, {List<String> fields = const []}) =>
      PrivateCardLine(
        id: id,
        target: _text(this.fields['target']) ?? '',
        reading: _text(this.fields['reading']),
        meaning: meaning,
        fields: fields,
        replaces: _text(this.fields['replaces']),
      );
}

/// A JSON-encoded string field read back as text, or null for anything else.
String? _text(String? json) {
  if (json == null) return null;
  try {
    final value = jsonDecode(json);
    return value is String && value.trim().isNotEmpty ? value : null;
  } on FormatException {
    return null;
  }
}

Object? _plain(Object? node) {
  if (node is YamlMap) {
    return <String, Object?>{
      for (final e in node.entries) '${e.key}': _plain(e.value),
    };
  }
  if (node is YamlList) return <Object?>[for (final e in node) _plain(e)];
  return node;
}

class _Index {
  _Index(this.cards, this.meanings, this.units);

  final Map<String, _Card> cards;

  /// The first layer's meaning of each card, by id.
  final Map<String, String> meanings;
  final int units;

  static _Index of(Map<String, String> files) {
    final cards = <String, _Card>{};
    final meanings = <String, String>{};
    var units = 0;
    final paths = files.keys.toList()..sort();
    for (final path in paths) {
      if (path == privateManifestFile) continue;
      try {
        final root = loadYaml(files[path]!);
        if (root is! YamlMap) continue;
        final kind = root['kind'];
        if (kind == 'path') {
          final list = root['units'];
          if (list is YamlList) units += list.length;
          continue;
        }
        final list = root['cards'];
        if (list is YamlList) {
          for (final card in list) {
            if (card is! YamlMap || card['id'] is! String) continue;
            final id = card['id'] as String;
            cards[id] = _Card(id, <String, String>{
              for (final e in card.entries)
                if ('${e.key}' != 'id') '${e.key}': jsonEncode(_plain(e.value)),
            });
          }
        } else if (list is YamlMap && kind == 'layer') {
          for (final e in list.entries) {
            final native = e.value is YamlMap
                ? (e.value as YamlMap)['native']
                : null;
            if (e.key is String && native is String) {
              meanings.putIfAbsent(e.key as String, () => native);
            }
          }
        }
      } on Object {
        // A file that does not read is the import's finding, not the
        // summary's: it is left out of the comparison.
        continue;
      }
    }
    return _Index(cards, meanings, units);
  }
}
