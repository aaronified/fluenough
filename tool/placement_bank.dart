// Exports the question bank of Find my level for a language
// (wiki/Plan-Placement-V2.md, section 13): every question the real
// generators produce from the decks, with stable ids, in two JSON files:
//
//   <out>/<lang>-bank.json      what a role-player sees (no answers)
//   <out>/<lang>-bank-key.json  id -> correct index, accepted answers, unit,
//                               level, guess rate, guess class, card ids
//
// Usage (not the test suite; pure Dart, run with the Flutter-bundled dart):
//
//   dart run tool/placement_bank.dart --language es \
//     [--root decks | $FLUENOUGH_DECKS_ROOT] [--native en] \
//     [--out test/fixtures/placement/banks] [--max 3000] [--seeds 2] [--stride 1] [--picks 5]
import 'dart:convert';
import 'dart:io';

import 'package:fluenough/core/data/placement_course.dart';
import 'package:fluenough/core/placement/question_bank.dart';

Future<void> main(List<String> args) async {
  final options = <String, String>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    options[args[i].replaceFirst('--', '')] = args[i + 1];
  }
  final language = options['language'];
  if (language == null) {
    stderr.writeln('usage: dart run tool/placement_bank.dart --language es');
    exitCode = 2;
    return;
  }
  final root =
      options['root'] ??
      Platform.environment['FLUENOUGH_DECKS_ROOT'] ??
      'decks';
  final native = options['native'] ?? 'en';
  final out = options['out'] ?? 'test/fixtures/placement/banks';
  final files = <String, String>{};
  final base = Directory('$root/$language');
  if (!base.existsSync()) {
    stderr.writeln('no folder $root/$language');
    exitCode = 2;
    return;
  }
  for (final entity in base.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.yaml')) {
      final relative = entity.path.substring(root.length + 1);
      files[relative] = entity.readAsStringSync();
    }
  }
  final course = loadPlacementCourse(files, language: language, native: native);
  stdout.writeln(
    '$language: ${course.data.deckCount} decks, '
    '${course.broken.length} unreadable files',
  );
  final bank = buildQuestionBank(
    course.data,
    seeds: int.parse(options['seeds'] ?? '2'),
    maxQuestions: int.parse(options['max'] ?? '3000'),
    deckStride: int.parse(options['stride'] ?? '1'),
    picks: int.parse(options['picks'] ?? '5'),
  );
  if (faults.isNotEmpty) {
    stderr.writeln('${faults.length} faulty questions left out:');
    for (final f in faults.take(20)) {
      stderr.writeln(' $f');
    }
    if (options['strict'] == 'true') {
      exitCode = 1;
      return;
    }
  }
  Directory(out).createSync(recursive: true);
  const encoder = JsonEncoder.withIndent(' ');
  File('$out/$language-bank.json').writeAsStringSync(
    '${encoder.convert(<String, Object?>{
      'language': language,
      'native': native,
      'deckCount': course.data.deckCount,
      'questions': <Object?>[for (final e in bank.entries) e.toPublicJson()],
    })}\n',
  );
  File('$out/$language-bank-key.json').writeAsStringSync(
    '${encoder.convert(<String, Object?>{
      'language': language,
      'native': native,
      'deckCount': course.data.deckCount,
      'levelMarkDecks': course.data.levelMarkDecks,
      'grammarDecks': course.grammarDecks,
      'questions': <String, Object?>{for (final e in bank.entries) e.id: e.toKeyJson()},
    })}\n',
  );
  final byType = <String, int>{};
  for (final e in bank.entries) {
    byType[e.question.request.variant.label] =
        (byType[e.question.request.variant.label] ?? 0) + 1;
  }
  stdout.writeln('${bank.entries.length} questions: $byType');
}
