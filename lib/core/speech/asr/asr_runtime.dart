/// The runtime of the on-device listener (#1004): one speech-model encoder
/// loaded from a file, run on log-mel features, released when done.
///
/// An interface, so that the engine and its tests never meet a platform:
/// `lib/app/channel_asr_runtime.dart` implements it over ONNX Runtime on
/// Android (`AsrChannel`, written by `tools/brand_android.py`), a test uses
/// [FakeAsrRuntime], and another runtime (iOS, or another model family) can
/// replace it without touching the engine. Pure Dart: no Flutter imports.
library;

import 'dart:typed_data';

/// A line for the app log. Every failure of the runtime goes through one,
/// with its code, so that nothing is lost silently.
typedef AsrLog = void Function(String message);

/// The codes of [AsrError] the runtime uses. A platform may send others;
/// they are passed on as they come.
abstract final class AsrErrorCode {
  /// [AsrRuntime.run] with no model loaded.
  static const String noModel = 'no_model';

  /// The model file is missing, unreadable or not a model this can run.
  static const String loadFailed = 'load_failed';

  /// The model failed on this input.
  static const String runFailed = 'run_failed';

  /// The phone ran out of memory loading or running the model.
  static const String outOfMemory = 'out_of_memory';
}

/// Why the runtime did not do what it was asked: a [code] (see
/// [AsrErrorCode]) and a [message] for the log. The runtime throws nothing
/// else.
class AsrError implements Exception {
  const AsrError(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AsrError($code): $message';
}

/// The encoder's answer: [data], row-major float32 of shape `[1, dim,
/// frames]`, so the value of feature `d` at frame `t` is
/// `data[d * frames + t]`.
class AsrOutput {
  const AsrOutput(this.data, this.dim, this.frames);

  final Float32List data;

  /// The encoder's width D (512 for the per-language IndicConformer).
  final int dim;

  /// The number of output frames T', after the encoder's subsampling.
  final int frames;
}

/// A speech-model encoder that can be loaded, run and closed.
abstract class AsrRuntime {
  /// Loads the model file at [modelPath], replacing any model loaded
  /// before. [threads] is how many threads to compute with; 0 lets the
  /// runtime choose. Throws [AsrError] (`load_failed`, `out_of_memory`).
  Future<void> load(String modelPath, {int threads = 0});

  /// Runs the model on [features], float32 of shape `[1, bins, frames]`
  /// laid out row by row (all frames of bin 0, then bin 1, and so on), so
  /// `features.length` is `bins * frames`. Throws [AsrError] (`no_model`,
  /// `run_failed`, `out_of_memory`).
  Future<AsrOutput> run(Float32List features, int frames);

  /// Releases the model. Safe to call when nothing is loaded.
  Future<void> close();
}

/// An [AsrRuntime] for tests: no model, no platform. It records what it was
/// asked, answers [output] (or [onRun]), and can be told to fail.
class FakeAsrRuntime implements AsrRuntime {
  FakeAsrRuntime({
    AsrOutput? output,
    this.onRun,
    this.loadError,
    this.runError,
    this.closeError,
  }) : output = output ?? AsrOutput(Float32List(0), 1, 0);

  /// What [run] answers when [onRun] is null.
  AsrOutput output;

  /// Computes the answer from the features, instead of [output].
  AsrOutput Function(Float32List features, int frames)? onRun;

  /// Thrown by [load], [run] and [close] when set.
  AsrError? loadError;
  AsrError? runError;
  AsrError? closeError;

  /// The path and threads of the last successful [load], or null.
  String? loadedPath;
  int? loadedThreads;

  /// How many times each was called, failed calls included.
  int loadCalls = 0;
  int runCalls = 0;
  int closeCalls = 0;

  /// The features and frames of each [run] that reached the model.
  final List<(Float32List, int)> runs = <(Float32List, int)>[];

  bool get isLoaded => loadedPath != null;

  @override
  Future<void> load(String modelPath, {int threads = 0}) async {
    loadCalls++;
    final error = loadError;
    if (error != null) throw error;
    loadedPath = modelPath;
    loadedThreads = threads;
  }

  @override
  Future<AsrOutput> run(Float32List features, int frames) async {
    runCalls++;
    if (!isLoaded) {
      throw const AsrError(AsrErrorCode.noModel, 'no model is loaded');
    }
    final error = runError;
    if (error != null) throw error;
    runs.add((features, frames));
    final compute = onRun;
    return compute == null ? output : compute(features, frames);
  }

  @override
  Future<void> close() async {
    closeCalls++;
    final error = closeError;
    if (error != null) throw error;
    loadedPath = null;
    loadedThreads = null;
  }
}
