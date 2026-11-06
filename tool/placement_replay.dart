// Replays personas through the real placement engine in bank mode and writes
// the outcome tables (wiki/Plan-Placement-V2.md, section 13).
//
//   dart run tool/placement_replay.dart --language es [--runs 100] \
//     [--banks test/fixtures/placement/banks] \
//     [--answers test/fixtures/placement/answers] \
//     [--out test/fixtures/placement/outcomes]
//
// Answer files are <lang>-<persona>-draw<k>.json (question id to a pick
// index, an option's text, or a boolean). Writes <lang>-outcomes.csv (one
// row per run and skill) and prints a summary per persona.
import 'dart:convert';
import 'dart:io';

import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/question_bank.dart';
import 'package:fluenough/core/placement/replay.dart';

Future<void> main(List<String> args) async {
  final o = <String, String>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    o[args[i].replaceFirst('--', '')] = args[i + 1];
  }
  final language = o['language'] ?? 'es';
  final banks = o['banks'] ?? 'test/fixtures/placement/banks';
  final answers = o['answers'] ?? 'test/fixtures/placement/answers';
  final out = o['out'] ?? 'test/fixtures/placement/outcomes';
  final runs = int.parse(o['runs'] ?? '100');
  final pub = jsonDecode(
    File('$banks/$language-bank.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final key = jsonDecode(
    File('$banks/$language-bank-key.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final bank = bankFromJson(
    pub['questions']! as List<Object?>,
    key['questions']! as Map<String, Object?>,
    language: language,
  );
  final deckCount = key['deckCount']! as int;
  final marks = <int>[for (final m in key['levelMarkDecks']! as List) m as int];
  final grammar = <int>[for (final m in key['grammarDecks']! as List) m as int];
  final personas = <String, List<Map<String, Object?>>>{};
  final pattern = RegExp('^$language-(.+)-draw[0-9]+\\.json\$');
  for (final f in Directory(answers).listSync().whereType<File>()) {
    final m = pattern.firstMatch(f.uri.pathSegments.last);
    if (m == null) continue;
    (personas[m[1]!] ??= <Map<String, Object?>>[]).add(
      jsonDecode(f.readAsStringSync()) as Map<String, Object?>,
    );
  }
  Directory(out).createSync(recursive: true);
  final csv = StringBuffer(
    'persona,seed,asked,fallback,skill,unit25,label25,atLeast25,'
    'unitEnd,labelEnd,atLeastEnd\n',
  );
  for (final MapEntry(key: persona, value: draws) in personas.entries) {
    final declaration = persona.contains('expert') || persona.contains('native')
        ? PlacementDeclaration.expert
        : PlacementDeclaration.amateur;
    var fallback = 0;
    final units = <int>[];
    for (var seed = 1; seed <= runs; seed++) {
      final r = replayRun(
        persona: persona,
        bank: bank,
        deckCount: deckCount,
        levelMarkDecks: marks,
        grammarDecks: grammar,
        draws: draws,
        declaration: declaration,
        seed: seed,
      );
      fallback += r.guessedFallback;
      for (final skill in r.atEnd.keys) {
        final a = r.atCheckpoint[skill] ?? r.atEnd[skill]!;
        final b = r.atEnd[skill]!;
        csv.writeln(
          '$persona,$seed,${r.asked},${r.guessedFallback},${skill.name},'
          '${a.unit},${a.label.name},${a.atLeast},'
          '${b.unit},${b.label.name},${b.atLeast}',
        );
        if (skill.name == 'read') units.add(b.unit);
      }
    }
    units.sort();
    stdout.writeln(
      '$persona: ${draws.length} draws, $runs runs, Read unit at end '
      'median ${units.isEmpty ? '-' : units[units.length ~/ 2]}, '
      'max ${units.isEmpty ? '-' : units.last}, guessed answers $fallback',
    );
  }
  File('$out/$language-outcomes.csv').writeAsStringSync(csv.toString());
}
