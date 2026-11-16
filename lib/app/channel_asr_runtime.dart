import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../core/speech/asr/asr_runtime.dart';

/// [AsrRuntime] over ONNX Runtime on Android, through the app's channel
/// `app.fluenough/asr` (#1004). Its Kotlin side, `AsrChannel`, and the
/// Gradle dependency it needs are written by `tools/brand_android.py`.
///
/// Every failure is logged through [log] with its code and thrown as an
/// [AsrError]: a `PlatformException` keeps its code (`no_model`,
/// `load_failed`, `run_failed`, `out_of_memory`), a missing channel or a
/// malformed answer is `load_failed` or `run_failed`. Nothing else is
/// thrown, and nothing is silent.
///
/// Features cross the channel as the bytes of the [Float32List], in the
/// phone's own byte order (little-endian on every Android phone), which is
/// what the Kotlin side reads.
class ChannelAsrRuntime implements AsrRuntime {
  ChannelAsrRuntime({required this.log, this.channel = defaultChannel});

  static const MethodChannel defaultChannel = MethodChannel(
    'app.fluenough/asr',
  );

  final MethodChannel channel;
  final AsrLog log;

  @override
  Future<void> load(String modelPath, {int threads = 0}) async {
    try {
      await channel.invokeMethod<void>('load', <String, Object?>{
        'path': modelPath,
        'threads': threads,
      });
    } on Object catch (e) {
      throw _fail('load', AsrErrorCode.loadFailed, e);
    }
  }

  @override
  Future<AsrOutput> run(Float32List features, int frames) async {
    try {
      if (frames <= 0 || features.isEmpty || features.length % frames != 0) {
        throw AsrError(
          AsrErrorCode.runFailed,
          '${features.length} feature values do not make whole rows of '
          '$frames frames',
        );
      }
      final Map<Object?, Object?>? answer = await channel
          .invokeMapMethod<Object?, Object?>('run', <String, Object?>{
            'features': features.buffer.asUint8List(
              features.offsetInBytes,
              features.lengthInBytes,
            ),
            'frames': frames,
          });
      return _output(answer);
    } on Object catch (e) {
      throw _fail('run', AsrErrorCode.runFailed, e);
    }
  }

  @override
  Future<void> close() async {
    try {
      await channel.invokeMethod<void>('close');
    } on Object catch (e) {
      throw _fail('close', AsrErrorCode.runFailed, e);
    }
  }

  /// The answer of `run` as an [AsrOutput], or an [AsrError] if it is not
  /// the bytes and the `[1, dim, frames]` shape that were promised.
  AsrOutput _output(Map<Object?, Object?>? answer) {
    final data = answer?['data'];
    final dims = answer?['dims'];
    if (data is! Uint8List || dims is! List<Object?>) {
      throw const AsrError(
        AsrErrorCode.runFailed,
        'the listener answered without data and dims',
      );
    }
    if (dims.length != 3 ||
        dims[0] != 1 ||
        dims[1] is! int ||
        dims[2] is! int) {
      throw AsrError(
        AsrErrorCode.runFailed,
        'the listener answered with dims $dims, expected [1, dim, frames]',
      );
    }
    final dim = dims[1] as int;
    final frames = dims[2] as int;
    if (dim <= 0 || frames < 0 || data.length != dim * frames * 4) {
      throw AsrError(
        AsrErrorCode.runFailed,
        '${data.length} bytes do not fit dims $dims',
      );
    }
    // A copy, so that the floats are aligned whatever the bytes' offset.
    final floats = Uint8List.fromList(data).buffer.asFloat32List();
    return AsrOutput(floats, dim, frames);
  }

  /// Logs [error] and returns the [AsrError] to throw for it. [fallback] is
  /// the code when the failure carries none of its own.
  AsrError _fail(String method, String fallback, Object error) {
    final AsrError out;
    if (error is AsrError) {
      out = error;
    } else if (error is PlatformException) {
      out = AsrError(error.code, error.message ?? 'no message');
    } else if (error is MissingPluginException) {
      out = AsrError(
        fallback,
        'the listener is not in this build (no app.fluenough/asr channel)',
      );
    } else {
      out = AsrError(fallback, '${error.runtimeType}: $error');
    }
    _note('asr $method failed: code=${out.code} message=${out.message}');
    return out;
  }

  // A logger that throws must not hide the failure it was told about.
  void _note(String line) {
    try {
      log(line);
    } on Object {
      // Nowhere left to report it to.
    }
  }
}
