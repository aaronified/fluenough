import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/speech/asr/ctc_decode.dart';
import 'package:fluenough/core/speech/asr/ctc_head.dart';

Uint8List _f32Bytes(List<num> values) {
  final bd = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    bd.setFloat32(i * 4, values[i].toDouble(), Endian.little);
  }
  return bd.buffer.asUint8List();
}

String _json({
  required List<String> pieces,
  required int blank,
  required int dim,
  required int vocab,
}) => jsonEncode({
  'language': 'toy',
  'pieces': pieces,
  'blank': blank,
  'dim': dim,
  'vocab': vocab,
});

void main() {
  final golden = jsonDecode(
    File('test/fixtures/asr/golden_ctc.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final dim = golden['dim'] as int;
  final vocab = golden['vocab'] as int;
  final blank = golden['blank'] as int;
  final pieces = (golden['pieces'] as List).cast<String>();
  final weights = (golden['weights'] as List).cast<num>();
  final bias = (golden['bias'] as List).cast<num>();
  final encoderOut = [
    for (final row in golden['encoderOutput'] as List)
      Float32List.fromList([
        for (final x in row as List) (x as num).toDouble(),
      ]),
  ];
  final validFrames = golden['validFrames'] as int;

  CtcHead loadGolden({void Function(String)? log}) => CtcHead.fromBytes(
    _f32Bytes([...weights, ...bias]),
    _json(pieces: pieces, blank: blank, dim: dim, vocab: vocab),
    log: log,
  );

  group('CtcHead against golden_ctc.json', () {
    test('logits match the Python head within 1e-4', () {
      final head = loadGolden();
      final logits = head.logits(encoderOut, length: validFrames);
      final want = golden['logits'] as List;
      expect(logits.length, want.length);
      for (var t = 0; t < want.length; t++) {
        final row = (want[t] as List).cast<num>();
        expect(logits[t].length, vocab);
        for (var v = 0; v < vocab; v++) {
          expect(
            logits[t][v],
            closeTo(row[v].toDouble(), 1e-4),
            reason: 'frame $t class $v',
          );
        }
      }
    });

    test(
      'apply gives the golden ids and mean confidence, and the decoded text',
      () {
        final head = loadGolden();
        final result = head.apply(encoderOut, length: validFrames);
        expect(result.ids, (golden['ids'] as List).cast<int>());
        expect(
          result.meanConfidence,
          closeTo((golden['meanConfidence'] as num).toDouble(), 1e-4),
        );
        expect(decode(result.ids, head.pieces, head.blank), golden['text']);
        expect(head.language, 'toy');
      },
    );

    test('decode cases from the golden file', () {
      final head = loadGolden();
      for (final c in golden['decodeCases'] as List) {
        final m = c as Map<String, dynamic>;
        expect(
          decode((m['ids'] as List).cast<int>(), head.pieces, head.blank),
          m['text'],
          reason: 'ids ${m['ids']}',
        );
      }
    });
  });

  group('CtcHead.apply edge cases', () {
    test('no valid frame gives empty ids and confidence 0', () {
      final head = loadGolden();
      final result = head.apply(encoderOut, length: 0);
      expect(result.ids, isEmpty);
      expect(result.meanConfidence, 0.0);
    });

    test('an encoder output with no frames gives empty ids', () {
      final head = loadGolden();
      final empty = List<Float32List>.generate(dim, (_) => Float32List(0));
      final result = head.apply(empty);
      expect(result.ids, isEmpty);
      expect(result.meanConfidence, 0.0);
    });

    test('a row count other than dim throws AsrHeadError and logs it', () {
      final head = loadGolden();
      final messages = <String>[];
      expect(
        () => head.apply(encoderOut.sublist(1), log: messages.add),
        throwsA(isA<AsrHeadError>()),
      );
      expect(messages, isNotEmpty);
    });

    test('a valid length past the frames throws AsrHeadError', () {
      final head = loadGolden();
      expect(
        () => head.apply(encoderOut, length: 99),
        throwsA(isA<AsrHeadError>()),
      );
    });
  });

  group('CtcHead.fromBytes errors', () {
    test('a head file of the wrong size throws AsrHeadError and logs it', () {
      final messages = <String>[];
      final short = _f32Bytes([...weights, ...bias]).sublist(4);
      expect(
        () => CtcHead.fromBytes(
          short,
          _json(pieces: pieces, blank: blank, dim: dim, vocab: vocab),
          log: messages.add,
        ),
        throwsA(isA<AsrHeadError>()),
      );
      expect(messages.single, contains('bytes'));
    });

    test('a head file with extra bytes throws AsrHeadError', () {
      final long = Uint8List.fromList([
        ..._f32Bytes([...weights, ...bias]),
        0,
        0,
        0,
        0,
      ]);
      expect(
        () => CtcHead.fromBytes(
          long,
          _json(pieces: pieces, blank: blank, dim: dim, vocab: vocab),
        ),
        throwsA(isA<AsrHeadError>()),
      );
    });

    test('bad json throws AsrHeadError and logs it', () {
      final messages = <String>[];
      expect(
        () => CtcHead.fromBytes(
          _f32Bytes([...weights, ...bias]),
          '{not json',
          log: messages.add,
        ),
        throwsA(isA<AsrHeadError>()),
      );
      expect(messages.single, contains('does not parse'));
    });

    test('json without an integer vocab throws AsrHeadError', () {
      expect(
        () => CtcHead.fromBytes(
          _f32Bytes([...weights, ...bias]),
          jsonEncode({
            'pieces': pieces,
            'blank': blank,
            'dim': dim,
            'vocab': 'six',
          }),
        ),
        throwsA(isA<AsrHeadError>()),
      );
    });

    test('a blank that is not the last class throws AsrHeadError', () {
      expect(
        () => CtcHead.fromBytes(
          _f32Bytes([...weights, ...bias]),
          _json(pieces: pieces, blank: 0, dim: dim, vocab: vocab),
        ),
        throwsA(isA<AsrHeadError>()),
      );
    });

    test('pieces that do not match the vocab throw AsrHeadError', () {
      expect(
        () => CtcHead.fromBytes(
          _f32Bytes([...weights, ...bias]),
          _json(
            pieces: pieces.sublist(1),
            blank: blank,
            dim: dim,
            vocab: vocab,
          ),
        ),
        throwsA(isA<AsrHeadError>()),
      );
    });
  });
}
