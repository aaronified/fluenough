/// The per-language CTC head of the on-device listener: a 1x1 convolution of the
/// encoder output, one matrix multiply per frame, then the greedy (argmax) ids.
///
/// Port of `tools/asr/ctc.py` (`Head`). Head file layout: little-endian float32,
/// no header, weights `[vocab x dim]` row-major, then bias `[vocab]`. The json
/// beside it holds `pieces` (vocab - 1 entries), `blank` (always the last class,
/// vocab - 1), `dim`, `vocab` and an optional `language`.
///
/// The encoder output is `[dim][frames]`: one row per encoder channel, each row
/// holding that channel's value for every frame, as the Python `enc` argument.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Raised when a head file or its json is malformed, or an encoder output does not
/// fit the head. The message says what was wrong; the same message is logged first.
class AsrHeadError implements Exception {
  const AsrHeadError(this.message);

  final String message;

  @override
  String toString() => 'AsrHeadError: $message';
}

/// Greedy CTC output for one utterance: the argmax id of each valid frame and the
/// mean over those frames of the max softmax probability (`meanConfidence`).
class CtcResult {
  const CtcResult({required this.ids, required this.meanConfidence});

  final List<int> ids;
  final double meanConfidence;
}

class CtcHead {
  CtcHead._({
    required this.weights,
    required this.bias,
    required this.pieces,
    required this.blank,
    required this.dim,
    required this.vocab,
    required this.language,
  });

  /// Row-major `[vocab x dim]`.
  final Float32List weights;

  /// `[vocab]`.
  final Float32List bias;

  /// Word pieces for classes `0 .. vocab - 2`; the blank is the last class.
  final List<String> pieces;

  final int blank;
  final int dim;
  final int vocab;
  final String language;

  /// Reads a head from its `.f32` bytes and its `.json` text.
  ///
  /// Throws [AsrHeadError] (after calling [log]) when the byte count is not
  /// `(vocab * dim + vocab) * 4`, or the json is not an object with the fields above
  /// of the right types, or the pieces and blank do not match the vocab size.
  factory CtcHead.fromBytes(
    Uint8List f32,
    String json, {
    void Function(String)? log,
  }) {
    try {
      final Object? meta = _parseJson(json, log);
      if (meta is! Map<String, dynamic>) {
        throw _fail('head json is not an object', log);
      }
      final vocab = _intField(meta, 'vocab', log);
      final dim = _intField(meta, 'dim', log);
      final blank = _intField(meta, 'blank', log);
      if (dim < 1) {
        throw _fail('head dim $dim must be at least 1', log);
      }
      if (vocab < 2) {
        throw _fail(
          'head vocab $vocab must be at least 2 (one piece and the blank)',
          log,
        );
      }
      if (blank != vocab - 1) {
        throw _fail(
          'head blank $blank is not the last class (vocab $vocab)',
          log,
        );
      }
      final Object? rawPieces = meta['pieces'];
      if (rawPieces is! List) {
        throw _fail('head json field "pieces" is not a list', log);
      }
      final pieces = <String>[];
      for (final p in rawPieces) {
        if (p is! String) {
          throw _fail('head json "pieces" holds a non-string entry', log);
        }
        pieces.add(p);
      }
      if (pieces.length != vocab - 1) {
        throw _fail(
          'head has ${pieces.length} pieces for $vocab classes (the blank is extra)',
          log,
        );
      }
      final Object? rawLanguage = meta['language'];
      final language = rawLanguage is String ? rawLanguage : '';

      final floats = vocab * dim + vocab;
      if (f32.lengthInBytes != floats * 4) {
        throw _fail(
          'head file has ${f32.lengthInBytes} bytes, want ${floats * 4} '
          '($floats float32 for vocab $vocab, dim $dim)',
          log,
        );
      }
      final bd = ByteData.sublistView(f32);
      final weights = Float32List(vocab * dim);
      for (var i = 0; i < weights.length; i++) {
        weights[i] = bd.getFloat32(i * 4, Endian.little);
      }
      final bias = Float32List(vocab);
      final biasStart = vocab * dim * 4;
      for (var i = 0; i < vocab; i++) {
        bias[i] = bd.getFloat32(biasStart + i * 4, Endian.little);
      }
      return CtcHead._(
        weights: weights,
        bias: bias,
        pieces: List.unmodifiable(pieces),
        blank: blank,
        dim: dim,
        vocab: vocab,
        language: language,
      );
    } on AsrHeadError {
      rethrow;
    } catch (e, st) {
      log?.call('head load failed: $e\n$st');
      throw AsrHeadError('head load failed: $e');
    }
  }

  /// Logits for each valid frame: `[frames][vocab]`, as `ctc.py` `Head.logits`.
  ///
  /// [encoderOut] is `[dim][frames]`. [length] is the valid frame count (the
  /// encoder's second output); null means every frame. Throws [AsrHeadError] (after
  /// calling [log]) on a row count other than [dim], ragged rows, or a length outside
  /// `0 .. frames`.
  List<Float64List> logits(
    List<Float32List> encoderOut, {
    int? length,
    void Function(String)? log,
  }) {
    try {
      if (encoderOut.length != dim) {
        throw _fail(
          'encoder output has ${encoderOut.length} rows, head wants $dim',
          log,
        );
      }
      final frames = encoderOut.isEmpty ? 0 : encoderOut[0].length;
      for (final row in encoderOut) {
        if (row.length != frames) {
          throw _fail(
            'encoder output rows differ in length (${row.length} vs $frames)',
            log,
          );
        }
      }
      var n = frames;
      if (length != null) {
        if (length < 0 || length > frames) {
          throw _fail('valid length $length is outside 0..$frames', log);
        }
        n = length;
      }
      final out = List<Float64List>.generate(
        n,
        (_) => Float64List(vocab),
        growable: false,
      );
      for (var t = 0; t < n; t++) {
        final row = out[t];
        for (var v = 0; v < vocab; v++) {
          var s = bias[v].toDouble();
          final base = v * dim;
          for (var d = 0; d < dim; d++) {
            s += encoderOut[d][t] * weights[base + d];
          }
          row[v] = s;
        }
      }
      return out;
    } on AsrHeadError {
      rethrow;
    } catch (e, st) {
      log?.call('head logits failed: $e\n$st');
      throw AsrHeadError('head logits failed: $e');
    }
  }

  /// Greedy ids per valid frame and the mean max-probability over those frames,
  /// as `ctc.py` `Head.apply`. No valid frame gives empty ids and confidence 0.
  CtcResult apply(
    List<Float32List> encoderOut, {
    int? length,
    void Function(String)? log,
  }) {
    try {
      final lg = logits(encoderOut, length: length, log: log);
      if (lg.isEmpty) {
        return const CtcResult(ids: [], meanConfidence: 0.0);
      }
      final ids = List<int>.filled(lg.length, 0, growable: false);
      var confSum = 0.0;
      for (var t = 0; t < lg.length; t++) {
        final row = lg[t];
        var best = 0;
        var max = row[0];
        for (var v = 1; v < vocab; v++) {
          if (row[v] > max) {
            max = row[v];
            best = v;
          }
        }
        // max softmax probability = exp(max - max) / sum = 1 / sum(exp(x - max))
        var sum = 0.0;
        for (var v = 0; v < vocab; v++) {
          sum += math.exp(row[v] - max);
        }
        ids[t] = best;
        confSum += 1.0 / sum;
      }
      return CtcResult(ids: ids, meanConfidence: confSum / lg.length);
    } on AsrHeadError {
      rethrow;
    } catch (e, st) {
      log?.call('head apply failed: $e\n$st');
      throw AsrHeadError('head apply failed: $e');
    }
  }
}

Object? _parseJson(String json, void Function(String)? log) {
  try {
    return jsonDecode(json);
  } on FormatException catch (e) {
    throw _fail('head json does not parse: ${e.message}', log);
  }
}

int _intField(
  Map<String, dynamic> meta,
  String key,
  void Function(String)? log,
) {
  final v = meta[key];
  if (v is! int) {
    throw _fail('head json field "$key" is missing or not an integer', log);
  }
  return v;
}

/// Logs [message] when a logger is injected and returns the error to throw.
AsrHeadError _fail(String message, void Function(String)? log) {
  log?.call(message);
  return AsrHeadError(message);
}
