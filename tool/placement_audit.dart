// Builds the item bank of Find my level V3 for languages and writes what the
// admission audit measured (wiki/Plan-Placement-V3.md): per item class, the
// best solver's expected accuracy against the admission bound.
//
//   dart run tool/placement_audit.dart [--root decks] [--native en] \
//     [--languages es,hi] [--out test/fixtures/placement/adversary/audit_profile.json]
//
// The replay harness reads the file as the leak rates of the "fixed" bank.
// Not the test suite; pure Dart, run with the Flutter-bundled dart.
import 'dart:convert';
import 'dart:io';

import 'package:fluenough/core/data/placement_course.dart';
import 'package:fluenough/core/placement/item_bank.dart';

Future<void> main(List<String> args) async {
  final options = <String, String>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    options[args[i].replaceFirst('--', '')] = args[i + 1];
  }
  final root = options['root'] ?? 'decks';
  final native = options['native'] ?? 'en';
  final out =
      options['out'] ?? 'test/fixtures/placement/adversary/audit_profile.json';
  final languages = (options['languages'] ?? 'es,hi').split(',');
  final result = <String, Object?>{};
  for (final language in languages) {
    final files = <String, String>{};
    for (final e in Directory('$root/$language').listSync(recursive: true)) {
      if (e is File && e.path.endsWith('.yaml')) {
        files[e.path.substring(root.length + 1)] = e.readAsStringSync();
      }
    }
    final course = loadPlacementCourse(
      files,
      language: language,
      native: native,
    );
    final bank = ItemBank.build(course.data);
    final classes = <String, Object?>{};
    for (final key in bank.audit.classes.keys.toList()..sort()) {
      final c = bank.audit.classes[key]!;
      classes[key] = <String, Object?>{
        'n': c.n,
        'accuracy': double.parse(c.accuracy.toStringAsFixed(4)),
        'upper': double.parse(c.upper.toStringAsFixed(4)),
        'bound': double.parse(c.bound.toStringAsFixed(4)),
        'solver': c.solver,
        'solvers': <String, Object?>{
          for (final e in c.solvers.entries)
            e.key: double.parse(e.value.toStringAsFixed(4)),
        },
        'passes': c.passes,
      };
    }
    result[language] = <String, Object?>{
      'decks': course.data.deckCount,
      'wordCards': bank.context.vocab.length,
      'sentenceCards': bank.context.sentences.length,
      'wordTileDecoys': bank.decoys,
      'excluded': bank.excluded,
      'items': bank.countsByFormat,
      'classes': classes,
    };
    stdout.writeln(
      '$language: ${bank.items.length} items, excluded ${bank.excluded}',
    );
  }
  const encoder = JsonEncoder.withIndent(' ');
  File(out).writeAsStringSync(
    '${encoder.convert(<String, Object?>{'source': 'tool/placement_audit.dart over the decks of the repository; the leak rate of a clean item of a format is the best solver\'s expected accuracy (item_audit.dart). Regenerate when the decks change a lot.', 'languages': result})}\n',
  );
}
