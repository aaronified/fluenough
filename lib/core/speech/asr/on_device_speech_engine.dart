/// The on-device AI listener as a [SpeechEngine] (#1004).
///
/// One capture does both jobs: a [PcmRecorder] gives 16 kHz PCM, an
/// [Endpointer] ends the take, and the same bytes go through [logMel], the
/// [AsrRuntime] (the encoder), the language's [CtcHead] and [decode]. The
/// answer carries the text, the mean confidence and the take itself as
/// [OwnAudio], so "Your recording" needs no second recorder.
///
/// [listen] never throws. Every outcome, good or bad, goes to the injected
/// logger with the language, the codes and the timings, and nothing is
/// printed or swallowed silently. The failures and their codes are in
/// [AsrSpeechCode].
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../speech_engine.dart';
import 'asr_pack.dart';
import 'asr_runtime.dart';
import 'ctc_decode.dart';
import 'ctc_head.dart';
import 'endpointer.dart';
import 'log_mel.dart';
import 'pcm_recorder.dart';

/// The [SpeechHeard.code]s of the on-device listener.
abstract final class AsrSpeechCode {
  /// No pack for the language is installed ([SpeechFailure.notOnDevice]).
  static const String noPack = 'asr_no_pack';

  /// The model or the head failed to load or run ([SpeechFailure.other]).
  /// The preferring engine falls back to the system recogniser on this one.
  static const String runtimeError = 'asr_runtime_error';

  /// The encoder and head ran and the text is empty
  /// ([SpeechFailure.noMatch]). Never retried with another recogniser.
  static const String empty = 'asr_empty';

  /// Nobody spoke before the take ended ([SpeechFailure.noMatch]).
  static const String noSpeech = 'asr_no_speech';

  /// [SpeechEngine.stop] ended the listen before any speech
  /// ([SpeechFailure.noMatch]).
  static const String stopped = 'asr_stopped';

  /// The recorder gave no audio in time ([SpeechFailure.other]).
  static const String timeout = 'asr_timeout';

  /// The recorder failed, or its stream ended with no audio
  /// ([SpeechFailure.other]).
  static const String recordError = 'asr_record_error';

  /// Another listen is still running ([SpeechFailure.other]).
  static const String busy = 'asr_busy';

  /// Anything not foreseen ([SpeechFailure.other]).
  static const String unexpected = 'asr_error';

  /// The microphone permission is missing ([SpeechFailure.permissionDenied]).
  static const String permission = 'error_permission';
}

/// The sample rate the models and the front end work at.
const int asrSampleRate = 16000;

class OnDeviceSpeechEngine implements SpeechEngine {
  OnDeviceSpeechEngine({
    required this.packs,
    required this.recorder,
    required this.runtime,
    required this.log,
    this.neverSpeechSeconds = 5,
    this.quietFor = 1.0,
    this.timeoutGrace = const Duration(seconds: 2),
    this.threads = 0,
  });

  final AsrPackLocator packs;
  final PcmRecorder recorder;
  final AsrRuntime runtime;

  /// Receives a line for every outcome and every caught error.
  final void Function(String) log;

  /// Seconds without speech after which the take ends (capped by the
  /// listen's own length).
  final double neverSpeechSeconds;

  /// Seconds of quiet after speech that end the take.
  final double quietFor;

  /// How long past `listenFor` a recorder may stay silent before the listen
  /// gives up on it.
  final Duration timeoutGrace;

  /// Threads for the encoder; 0 lets the runtime choose.
  final int threads;

  String? _loadedPath;
  final Map<String, CtcHead> _heads = <String, CtcHead>{};
  bool _busy = false;
  void Function(String)? _endTake;

  @override
  Future<bool> hasPermission() async {
    try {
      return await recorder.hasPermission();
    } catch (e, st) {
      log('OnDeviceSpeechEngine: permission check failed: $e\n$st');
      return false;
    }
  }

  /// The recorder cannot ask the learner, so this only reports whether the
  /// permission is there and at least one pack is installed.
  @override
  Future<bool> start() async {
    final granted = await hasPermission();
    return granted && (await languages()).isNotEmpty;
  }

  @override
  Future<Set<String>> languages() async {
    try {
      return await packs.installed();
    } catch (e, st) {
      log('OnDeviceSpeechEngine: listing packs failed: $e\n$st');
      return const <String>{};
    }
  }

  @override
  Future<SpeechHeard> listen({
    required String bcp47,
    required bool onDevice,
    Duration listenFor = const Duration(seconds: 8),
  }) async {
    final code = bcp47.split(RegExp('[-_]')).first.toLowerCase();
    if (_busy) {
      return _fail(
        code,
        SpeechFailure.other,
        AsrSpeechCode.busy,
        'a listen is already running',
      );
    }
    _busy = true;
    try {
      return await _listen(code, listenFor);
    } catch (e, st) {
      return _fail(
        code,
        SpeechFailure.other,
        AsrSpeechCode.unexpected,
        'unexpected error: $e\n$st',
      );
    } finally {
      _busy = false;
      _endTake = null;
    }
  }

  /// Ends the take now. What was heard so far is still recognised when
  /// anyone had started speaking; otherwise the listen is a no-match with
  /// [AsrSpeechCode.stopped].
  @override
  Future<void> stop() async {
    try {
      _endTake?.call('stopped');
    } catch (e, st) {
      log('OnDeviceSpeechEngine: stop failed: $e\n$st');
    }
  }

  Future<SpeechHeard> _listen(String code, Duration listenFor) async {
    final total = Stopwatch()..start();
    AsrPack? pack;
    try {
      pack = await packs.find(code);
    } catch (e, st) {
      log('OnDeviceSpeechEngine: finding the $code pack failed: $e\n$st');
    }
    if (pack == null) {
      return _fail(
        code,
        SpeechFailure.notOnDevice,
        AsrSpeechCode.noPack,
        'no pack installed',
      );
    }
    if (!await hasPermission()) {
      return _fail(
        code,
        SpeechFailure.permissionDenied,
        AsrSpeechCode.permission,
        'microphone permission is not granted',
      );
    }

    // Load while recording, so the first words are not lost to the load.
    final loadWatch = Stopwatch()..start();
    final loading = _load(pack).then((CtcHead? head) {
      loadWatch.stop();
      return head;
    });
    final take = await _record(code, listenFor);
    final head = await loading;
    final failedTake = take.failure;
    if (failedTake != null) return failedTake;
    if (head == null) {
      return _fail(
        code,
        SpeechFailure.other,
        AsrSpeechCode.runtimeError,
        'the model or head did not load',
      );
    }

    final pcm = take.pcm;
    final audioMs = pcm.length * 1000 ~/ (2 * asrSampleRate);
    final melWatch = Stopwatch()..start();
    final List<Float32List> mel;
    try {
      mel = logMel(pcm, log: log);
    } catch (e, st) {
      return _fail(
        code,
        SpeechFailure.other,
        AsrSpeechCode.runtimeError,
        'log-mel failed: $e\n$st',
      );
    }
    melWatch.stop();
    if (mel.isEmpty) {
      return _fail(
        code,
        SpeechFailure.noMatch,
        AsrSpeechCode.empty,
        'the take is too short to analyse (${audioMs}ms)',
      );
    }

    final frames = mel.length;
    final bins = mel.first.length;
    final features = Float32List(bins * frames);
    for (var t = 0; t < frames; t++) {
      for (var b = 0; b < bins; b++) {
        features[b * frames + t] = mel[t][b];
      }
    }

    final runWatch = Stopwatch()..start();
    final CtcResult result;
    try {
      final AsrOutput out = await runtime.run(features, frames);
      runWatch.stop();
      if (out.dim <= 0 ||
          out.frames <= 0 ||
          out.data.length != out.dim * out.frames) {
        throw AsrError(
          AsrErrorCode.runFailed,
          'encoder output of ${out.data.length} values is not '
          '${out.dim} x ${out.frames}',
        );
      }
      final rows = List<Float32List>.generate(
        out.dim,
        (int d) => Float32List.sublistView(
          out.data,
          d * out.frames,
          (d + 1) * out.frames,
        ),
        growable: false,
      );
      result = head.apply(rows, log: log);
    } on AsrError catch (e) {
      return _fail(
        code,
        SpeechFailure.other,
        AsrSpeechCode.runtimeError,
        'runtime failed: ${e.code}: ${e.message}',
      );
    } catch (e, st) {
      return _fail(
        code,
        SpeechFailure.other,
        AsrSpeechCode.runtimeError,
        'encoder or head failed: $e\n$st',
      );
    }

    final String text;
    try {
      text = decode(result.ids, head.pieces, head.blank, log: log);
    } catch (e, st) {
      return _fail(
        code,
        SpeechFailure.other,
        AsrSpeechCode.runtimeError,
        'decode failed: $e\n$st',
      );
    }
    if (text.isEmpty) {
      return _fail(
        code,
        SpeechFailure.noMatch,
        AsrSpeechCode.empty,
        'empty transcript (audio ${audioMs}ms, '
        'confidence ${result.meanConfidence.toStringAsFixed(3)})',
      );
    }

    final rtf = audioMs == 0
        ? 0.0
        : (melWatch.elapsedMilliseconds + runWatch.elapsedMilliseconds) /
              audioMs;
    log(
      'OnDeviceSpeechEngine: heard $code, ${text.runes.length} characters, '
      'confidence ${result.meanConfidence.toStringAsFixed(3)}; audio '
      '${audioMs}ms, load ${loadWatch.elapsedMilliseconds}ms, mel '
      '${melWatch.elapsedMilliseconds}ms, encoder '
      '${runWatch.elapsedMilliseconds}ms, real-time factor '
      '${rtf.toStringAsFixed(2)}, total ${total.elapsedMilliseconds}ms',
    );
    return SpeechHeard(<SpeechAlternative>[
      SpeechAlternative(text, confidence: result.meanConfidence),
    ], ownAudio: OwnAudio(pcm, sampleRate: asrSampleRate));
  }

  /// Loads the encoder (once per file) and the head (once per pack).
  /// Never throws: a failure is logged and gives null.
  Future<CtcHead?> _load(AsrPack pack) async {
    try {
      if (_loadedPath != pack.encoderPath) {
        _loadedPath = null;
        await runtime.load(pack.encoderPath, threads: threads);
        _loadedPath = pack.encoderPath;
      }
      final key = '${pack.code}|${pack.encoderPath}';
      var head = _heads[key];
      if (head == null) {
        head = CtcHead.fromBytes(
          await pack.readHeadBytes(),
          await pack.readHeadJson(),
          log: log,
        );
        _heads[key] = head;
      }
      return head;
    } on AsrError catch (e) {
      log(
        'OnDeviceSpeechEngine: loading the ${pack.code} model failed: '
        '${e.code}: ${e.message}',
      );
    } catch (e, st) {
      log(
        'OnDeviceSpeechEngine: loading the ${pack.code} pack failed: $e\n$st',
      );
    }
    return null;
  }

  /// Records one take. A failure is returned as a ready [SpeechHeard].
  Future<({Uint8List pcm, SpeechHeard? failure})> _record(
    String code,
    Duration listenFor,
  ) async {
    final bytes = BytesBuilder(copy: false);
    final done = Completer<String>();
    void finish(String why) {
      if (!done.isCompleted) done.complete(why);
    }

    final maxSeconds = math.max(listenFor.inMilliseconds / 1000, 0.1);
    final Endpointer endpointer;
    try {
      endpointer = Endpointer(
        asrSampleRate,
        maxSeconds: maxSeconds,
        neverSpeechSeconds: math.min(neverSpeechSeconds, maxSeconds),
        quietFor: quietFor,
        log: log,
      );
    } catch (e, st) {
      return (
        pcm: Uint8List(0),
        failure: _fail(
          code,
          SpeechFailure.other,
          AsrSpeechCode.unexpected,
          'cannot set up the end-of-speech detector: $e\n$st',
        ),
      );
    }

    StreamSubscription<Uint8List>? sub;
    Timer? timer;
    var why = 'error';
    _endTake = finish;
    try {
      final stream = recorder.start(asrSampleRate);
      sub = stream.listen(
        (Uint8List chunk) {
          try {
            bytes.add(chunk);
            endpointer.feed(chunk);
            if (endpointer.done) finish('endpoint');
          } catch (e, st) {
            log('OnDeviceSpeechEngine: handling audio failed: $e\n$st');
            finish('error');
          }
        },
        onError: (Object e, StackTrace st) {
          log('OnDeviceSpeechEngine: the audio stream failed: $e\n$st');
          finish('error');
        },
        onDone: () => finish('end'),
      );
      timer = Timer(listenFor + timeoutGrace, () => finish('timeout'));
      why = await done.future;
    } catch (e, st) {
      log('OnDeviceSpeechEngine: recording failed: $e\n$st');
    } finally {
      timer?.cancel();
      try {
        await sub?.cancel();
      } catch (e, st) {
        log('OnDeviceSpeechEngine: closing the audio stream failed: $e\n$st');
      }
      try {
        await recorder.stop();
      } catch (e, st) {
        log('OnDeviceSpeechEngine: stopping the recorder failed: $e\n$st');
      }
    }

    var pcm = bytes.takeBytes();
    if (pcm.length.isOdd) pcm = Uint8List.sublistView(pcm, 0, pcm.length - 1);
    final spoke = endpointer.speechStarted;
    if (why == 'error' && !spoke) {
      return (
        pcm: pcm,
        failure: _fail(
          code,
          SpeechFailure.other,
          AsrSpeechCode.recordError,
          'the recorder failed',
        ),
      );
    }
    if (pcm.isEmpty) {
      if (why == 'stopped') {
        return (
          pcm: pcm,
          failure: _fail(
            code,
            SpeechFailure.noMatch,
            AsrSpeechCode.stopped,
            'stopped before any audio arrived',
          ),
        );
      }
      final timedOut = why == 'timeout';
      return (
        pcm: pcm,
        failure: _fail(
          code,
          SpeechFailure.other,
          timedOut ? AsrSpeechCode.timeout : AsrSpeechCode.recordError,
          timedOut ? 'no audio arrived in time' : 'no audio arrived ($why)',
        ),
      );
    }
    if (!spoke) {
      final stopped = why == 'stopped';
      return (
        pcm: pcm,
        failure: _fail(
          code,
          SpeechFailure.noMatch,
          stopped ? AsrSpeechCode.stopped : AsrSpeechCode.noSpeech,
          stopped ? 'stopped before anyone spoke' : 'nobody spoke',
        ),
      );
    }
    return (pcm: pcm, failure: null);
  }

  SpeechHeard _fail(
    String code,
    SpeechFailure failure,
    String reason,
    String detail,
  ) {
    log('OnDeviceSpeechEngine: $code listen failed ($reason): $detail');
    return SpeechHeard.failed(failure, code: reason);
  }
}
