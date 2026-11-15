// Prints the admission verdict entries (`lib/core/placement/admission.dart`)
// for the decks under `decks/` of the working directory, built the way
// `test/placement_v3_real_bank_test.dart` builds its data (Hindustani with its
// script check). Used by `.github/workflows/placement-audit-live.yml`, which
// puts decks-live's `decks/` there; pure Dart, run with the Flutter-bundled
// dart.
//
//   dart run tool/placement_audit_entries.dart [--source live] [--languages es,hi]
import 'dart:io';

import 'package:fluenough/core/placement/admission.dart';
import 'package:fluenough/core/placement/item_bank.dart';

import '../test/support/v3_oracle.dart';

void main(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    options[args[i].replaceFirst('--', '')] = args[i + 1];
  }
  final source = options['source'] ?? kFrozenDecks;
  for (final language in (options['languages'] ?? 'es,hi').split(',')) {
    final data = language == 'hi' ? hindustaniWithScript() : loadData(language);
    final p = ItemBank.auditRuntime(data, source: source);
    stdout.writeln(
      "  '$language': AdmissionProfile(source: '${p.source}', "
      "deckKey: '${p.deckKey}', "
      'excluded: <String>[${p.excluded.map((c) => "'$c'").join(', ')}], '
      'decoys: ${p.decoys}),',
    );
  }
}
