import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/speech/asr/log_mel.dart';

Map<String, dynamic> _golden() =>
    jsonDecode(File('test/fixtures/asr/golden_mel.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('logMel (#1004)', () {
    test('matches the numpy golden frames within 1e-3', () {
      final golden = _golden();
      final pcm = base64Decode(golden['pcm16leBase64'] as String);
      final logs = <String>[];
      final frames = logMel(pcm, log: logs.add);
      expect(logs, isEmpty);
      expect(frames.length, golden['frames']);
      expect(frames.first.length, golden['melBins']);
      final indexes = (golden['frameIndexes'] as List).cast<int>();
      final values = (golden['values'] as List).cast<List>();
      for (var k = 0; k < indexes.length; k++) {
        final frame = frames[indexes[k]];
        final expected = values[k];
        for (var m = 0; m < expected.length; m++) {
          expect(
            frame[m],
            closeTo((expected[m] as num).toDouble(), 1e-3),
            reason: 'frame ${indexes[k]} bin $m',
          );
        }
      }
    });

    test('empty input returns no frames and logs why', () {
      final logs = <String>[];
      final frames = logMel(Uint8List(0), log: logs.add);
      expect(frames, isEmpty);
      expect(logs, hasLength(1));
    });

    test('input shorter than one window (400 samples) returns no frames', () {
      final logs = <String>[];
      final frames = logMel(Uint8List(399 * 2), log: logs.add);
      expect(frames, isEmpty);
      expect(logs, hasLength(1));
    });

    test('a trailing odd byte is ignored and logged', () {
      final pcm = base64Decode(_golden()['pcm16leBase64'] as String);
      final logs = <String>[];
      final odd = Uint8List(pcm.length + 1)..setRange(0, pcm.length, pcm);
      final frames = logMel(odd, log: logs.add);
      final even = logMel(pcm);
      expect(logs, hasLength(1));
      expect(frames.length, even.length);
      expect(frames.last[0], closeTo(even.last[0], 1e-6));
    });

    test('null log is accepted for the same inputs', () {
      expect(logMel(Uint8List(0)), isEmpty);
      expect(logMel(Uint8List(2 * 10)), isEmpty);
    });
  });
}
