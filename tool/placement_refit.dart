// Re-fits the calibration profile of Find my level V3 from collected exports
// (wiki/Plan-Placement-V3.md, "Adapting placement to a language").
//
//   dart run tool/placement_refit.dart --exports <folder or file> \
//     [--asset assets/placement_profiles.json] [--out <same as asset>] \
//     [--min 200] [--dry]
//
// Reads every `*.json` export of "Share placement data", fits each language
// that has an edge (`kGatedEdges`) and enough decided placements, prints for
// every language whether it moved and why not when it did not, and writes the
// asset with the fitted languages' values, a higher version and `fitted`
// recorded. A language that is not moved is left exactly as it was. The values
// can never leave the clamps (they are cut by the language's edge); run the
// gates (`test/placement_v3_*`) and bump `test/fixtures/placement/
// profile_snapshot.json` before shipping. Pure Dart; run with the
// Flutter-bundled dart.
import 'dart:convert';
import 'dart:io';

import 'package:fluenough/core/placement/outcome_log.dart';
import 'package:fluenough/core/placement/profile_refit.dart';

Future<void> main(List<String> args) async {
  final options = <String, String>{};
  final flags = <String>{};
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--dry') {
      flags.add('dry');
    } else if (i + 1 < args.length) {
      options[args[i].replaceFirst('--', '')] = args[++i];
    }
  }
  final exports = options['exports'];
  if (exports == null) {
    stderr.writeln(
      'usage: dart run tool/placement_refit.dart --exports <path>',
    );
    exitCode = 2;
    return;
  }
  final assetPath = options['asset'] ?? 'assets/placement_profiles.json';
  final out = options['out'] ?? assetPath;
  final rules = RefitRules(
    minOutcomes: int.tryParse(options['min'] ?? '') ?? 200,
  );
  final files = <File>[
    if (FileSystemEntity.isDirectorySync(exports))
      for (final e in Directory(exports).listSync(recursive: true))
        if (e is File && e.path.endsWith('.json')) e else File(exports),
  ];
  final outcomes = <PlacementOutcome>[
    for (final f in files) ...importOutcomes(f.readAsStringSync()),
  ];
  stdout.writeln('${files.length} files, ${outcomes.length} placements');
  final asset = File(assetPath).readAsStringSync();
  final languages =
      ((jsonDecode(asset) as Map)['languages'] as Map?)
          ?.cast<String, dynamic>() ??
      const <String, dynamic>{};
  final results = <RefitResult>[];
  for (final language
      in outcomes.map((o) => o.language).toSet().toList()..sort()) {
    final entry = languages[language];
    final current = entry is Map && entry['fitted'] is Map
        ? ((entry['fitted'] as Map)['carefulness'] as num? ?? 0).toDouble()
        : 0.0;
    final r = refitLanguage(language, outcomes, current: current, rules: rules);
    results.add(r);
    stdout.writeln(
      '$language: ${r.moved ? 'MOVED to ${r.carefulness}' : 'held at ${r.carefulness}'}'
      ' (${r.reason})',
    );
  }
  if (flags.contains('dry') || !results.any((r) => r.moved)) {
    stdout.writeln('nothing written');
    return;
  }
  File(out).writeAsStringSync(applyRefit(asset, results));
  stdout.writeln('wrote $out');
}
