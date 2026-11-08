import 'dart:io';

import 'package:fluenough/core/data/placement_course.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:fluenough/core/placement/v3_session.dart';
import 'package:yaml/yaml.dart';

/// A language's placement data, read from its decks.
PlacementLanguageData loadData(String language) {
  final files = <String, String>{};
  for (final e in Directory('decks/$language').listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.yaml')) {
      files[e.path.substring('decks/'.length)] = e.readAsStringSync();
    }
  }
  return loadPlacementCourse(files, language: language).data;
}

/// A learner who knows every item up to deck [known] and answers right on
/// those, wrong on the others.
void answerV3(V3Run run, int known, {bool readsScript = true}) {
  final q = run.question!;
  final gate = q.gateItem;
  if (gate != null) {
    return readsScript
        ? run.answerPick(gate.correct)
        : run.answerPick((gate.correct + 1) % 4);
  }
  final item = q.item!;
  final right = item.deck <= known;
  switch (q.mode) {
    case V3Mode.pick:
      run.answerPick(
        right ? item.correct : (item.correct + 1) % item.options.length,
      );
    case V3Mode.tiles:
      final order = <int>[];
      final used = <int>{};
      for (final t in item.answerTiles) {
        final i = List<int>.generate(
          item.tiles.length,
          (i) => i,
        ).firstWhere((i) => !used.contains(i) && item.tiles[i] == t);
        used.add(i);
        order.add(i);
      }
      run.answerTiles(right ? order : order.reversed.toList());
    case V3Mode.type:
      run.answerTyped(right ? item.accepted.first : 'qqq');
    case V3Mode.gap:
      run.answerTyped(right ? item.accepted.first : 'qqq');
    case V3Mode.yesNo:
      run.answerYesNo(yes: !item.pseudo && right);
    case V3Mode.say:
      run.answerSaid(right ? <String>[item.accepted.first] : <String>['qqq']);
    case V3Mode.rateSay:
      run.answerRated(good: right);
  }
}

/// The Hindustani data with its Devanagari letters, as the app gives them
/// ([PlacementScriptData] is read from the script decks by the app).
PlacementLanguageData hindustaniWithScript() {
  final base = loadData('hi');
  List<Card> read(String name) {
    final doc = loadYaml(File('decks/hi/$name.yaml').readAsStringSync());
    return <Card>[
      for (final (i, c) in ((doc as YamlMap)['cards'] as YamlList).indexed)
        Card(
          id: '$name-$i',
          deckId: name,
          target: (c as YamlMap)['target'] as String,
          native: '',
          reading: c['reading'] as String?,
        ),
    ];
  }

  return PlacementLanguageData(
    language: base.language,
    decks: base.decks,
    sounds: base.sounds,
    levelMarkDecks: base.levelMarkDecks,
    scripts: <PlacementScriptData>[
      PlacementScriptData(
        script: 'devanagari',
        letters: <Card>[
          ...read('hi-script-vowels'),
          ...read('hi-script-consonants'),
        ],
        joined: <Card>[
          ...read('hi-script-vowel-signs'),
          ...read('hi-script-conjuncts'),
        ],
      ),
    ],
  );
}
