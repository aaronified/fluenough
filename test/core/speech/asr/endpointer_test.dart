import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/speech/asr/endpointer.dart';

const int _rate = 16000;

/// Samples for [milliseconds] at 16 kHz.
int _samplesFor(int milliseconds) => milliseconds * _rate ~/ 1000;

/// Little-endian int16 mono PCM: silence when [amplitude] is 0, else a
/// 440 Hz tone at that fraction of full scale (RMS about 0.7 of it).
Uint8List _pcm(int samples, {double amplitude = 0}) {
  final out = Uint8List(samples * 2);
  final data = ByteData.sublistView(out);
  for (var n = 0; n < samples; n++) {
    final value = amplitude == 0
        ? 0
        : (amplitude * 32767 * math.sin(2 * math.pi * 440 * n / _rate)).round();
    data.setInt16(2 * n, value, Endian.little);
  }
  return out;
}

Uint8List _silence(int milliseconds) => _pcm(_samplesFor(milliseconds));

Uint8List _loud(int milliseconds) =>
    _pcm(_samplesFor(milliseconds), amplitude: 0.3);

/// Feeds [pcm] to [endpointer] in pieces of [chunkBytes] bytes.
void _feedInChunks(Endpointer endpointer, Uint8List pcm, int chunkBytes) {
  var offset = 0;
  while (offset < pcm.length) {
    final end = math.min(offset + chunkBytes, pcm.length);
    endpointer.feed(pcm.sublist(offset, end));
    offset = end;
  }
}

void main() {
  group('Endpointer (#1004)', () {
    test('silence only: done after neverSpeechSeconds, no speech', () {
      final logs = <String>[];
      final endpointer = Endpointer(
        _rate,
        maxSeconds: 8,
        neverSpeechSeconds: 2,
        log: logs.add,
      );
      _feedInChunks(endpointer, _silence(1900), 3200);
      expect(endpointer.speechStarted, isFalse);
      expect(endpointer.done, isFalse);

      _feedInChunks(endpointer, _silence(100), 3200);
      expect(endpointer.speechStarted, isFalse);
      expect(endpointer.done, isTrue);
      expect(logs, isEmpty);
    });

    test('a loud burst then silence: speech starts, done after quietFor', () {
      final endpointer = Endpointer(
        _rate,
        maxSeconds: 8,
        neverSpeechSeconds: 5,
        quietFor: 1.0,
      );
      _feedInChunks(endpointer, _loud(500), 3200);
      expect(endpointer.speechStarted, isTrue);
      expect(endpointer.done, isFalse);

      _feedInChunks(endpointer, _silence(900), 3200);
      expect(endpointer.done, isFalse, reason: '0.9 s of quiet is not 1.0 s');

      _feedInChunks(endpointer, _silence(100), 3200);
      expect(endpointer.done, isTrue);
    });

    test('continuous speech: done at maxSeconds', () {
      final endpointer = Endpointer(
        _rate,
        maxSeconds: 2,
        neverSpeechSeconds: 5,
      );
      _feedInChunks(endpointer, _loud(1900), 3200);
      expect(endpointer.speechStarted, isTrue);
      expect(endpointer.done, isFalse);

      _feedInChunks(endpointer, _loud(100), 3200);
      expect(endpointer.done, isTrue);
    });

    test('odd chunk sizes give the same timing as one large chunk', () {
      final pcm = Uint8List.fromList([..._loud(500), ..._silence(1200)]);
      final endpointer = Endpointer(
        _rate,
        maxSeconds: 8,
        neverSpeechSeconds: 5,
      );
      // Speech plus 0.9 s of quiet: not done yet, whatever the chunking.
      final beforeLastTenth = _samplesFor(1400) * 2;
      const sizes = [1, 3, 7, 1001, 2, 5];
      var offset = 0;
      var index = 0;
      while (offset < beforeLastTenth) {
        final size = sizes[index % sizes.length];
        index++;
        final end = math.min(offset + size, beforeLastTenth);
        endpointer.feed(pcm.sublist(offset, end));
        offset = end;
      }
      expect(endpointer.speechStarted, isTrue);
      expect(endpointer.done, isFalse);

      endpointer.feed(pcm.sublist(offset));
      expect(endpointer.done, isTrue);
    });

    test('zero-length chunks change nothing', () {
      final endpointer = Endpointer(
        _rate,
        maxSeconds: 8,
        neverSpeechSeconds: 1,
      );
      for (var k = 0; k < 3; k++) {
        endpointer.feed(Uint8List(0));
      }
      expect(endpointer.speechStarted, isFalse);
      expect(endpointer.done, isFalse);

      endpointer.feed(_loud(100));
      expect(endpointer.speechStarted, isTrue);
      endpointer.feed(Uint8List(0));
      expect(endpointer.done, isFalse);
    });

    test('feeding after done is ignored', () {
      final endpointer = Endpointer(
        _rate,
        maxSeconds: 8,
        neverSpeechSeconds: 1,
      );
      endpointer.feed(_silence(1000));
      expect(endpointer.done, isTrue);

      endpointer.feed(_loud(500));
      expect(endpointer.speechStarted, isFalse);
      expect(endpointer.done, isTrue);
    });
  });
}
