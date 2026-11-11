import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'speech_engine.dart';
import 'web_speech_browser.dart';

/// The Web Speech API through `dart:js_interop`, with no package: every call
/// is guarded, as a browser may lack any part of it.
SpeechBrowser openSpeechBrowser() => _WebSpeechBrowser();

class _WebSpeechBrowser implements SpeechBrowser {
  JSObject? _active;

  /// `SpeechRecognition`, or Chrome's, Edge's and Safari's prefixed one.
  static JSFunction? get _constructor {
    for (final name in const <String>[
      'SpeechRecognition',
      'webkitSpeechRecognition',
    ]) {
      if (globalContext.has(name)) {
        final value = globalContext.getProperty<JSAny?>(name.toJS);
        if (value.isA<JSFunction>()) return value as JSFunction;
      }
    }
    return null;
  }

  @override
  bool get hasRecognition {
    try {
      return _constructor != null;
    } on Object {
      return false;
    }
  }

  JSObject? get _mediaDevices {
    final navigator = globalContext.getProperty<JSObject?>('navigator'.toJS);
    final devices = navigator?.getProperty<JSObject?>('mediaDevices'.toJS);
    return devices;
  }

  @override
  Future<BrowserMicrophone> microphone() async {
    try {
      final navigator = globalContext.getProperty<JSObject?>('navigator'.toJS);
      final permissions = navigator?.getProperty<JSObject?>('permissions'.toJS);
      if (permissions == null) return BrowserMicrophone.unknown;
      final query = JSObject()..setProperty('name'.toJS, 'microphone'.toJS);
      final status = await permissions
          .callMethod<JSPromise<JSObject>>('query'.toJS, query)
          .toDart;
      return switch (status.getProperty<JSString>('state'.toJS).toDart) {
        'granted' => BrowserMicrophone.granted,
        'denied' => BrowserMicrophone.denied,
        _ => BrowserMicrophone.unknown,
      };
    } on Object {
      // Safari has no "microphone" permission to query.
      return BrowserMicrophone.unknown;
    }
  }

  @override
  Future<bool> askMicrophone() async {
    try {
      final devices = _mediaDevices;
      // A page that is not on https has no microphone to ask for.
      if (devices == null) return false;
      final constraints = JSObject()..setProperty('audio'.toJS, true.toJS);
      final stream = await devices
          .callMethod<JSPromise<JSObject>>('getUserMedia'.toJS, constraints)
          .toDart;
      // Only the permission was wanted: let go of the microphone.
      final tracks = stream.callMethod<JSArray<JSObject>>('getTracks'.toJS);
      for (final track in tracks.toDart) {
        track.callMethod<JSAny?>('stop'.toJS);
      }
      return true;
    } on Object catch (e) {
      // No microphone at all is not a refusal: said apart, so that the app
      // does not tell the learner to allow what is not there.
      if (_errorName(e) case 'NotFoundError' || 'DevicesNotFoundError') {
        throw const SpeechError('no-microphone');
      }
      return false;
    }
  }

  static String? _errorName(Object error) {
    try {
      return (error as JSObject).getProperty<JSString?>('name'.toJS)?.toDart;
    } on Object {
      return null;
    }
  }

  /// Whether the browser may record beside the recogniser (not Safari, not
  /// iOS): see [recorderBesideRecognition].
  static bool get _recorderAllowed {
    try {
      final navigator = globalContext.getProperty<JSObject?>('navigator'.toJS);
      final agent = navigator?.getProperty<JSString?>('userAgent'.toJS)?.toDart;
      return agent != null && recorderBesideRecognition(agent);
    } on Object {
      return false;
    }
  }

  @override
  BrowserSession recognise(String lang, {bool record = false}) {
    final done = Completer<BrowserHeard>();
    // The recorder starts with the recogniser and stops with it. A listen
    // that ends in an error, or is cancelled, keeps nothing.
    final recorder = _BrowserRecorder(_mediaDevices);
    var ended = false;
    void finish(BrowserHeard heard, {required bool keep}) {
      if (ended) return;
      ended = true;
      unawaited(() async {
        final audio = await recorder.stop(keep: keep && heard.error == null);
        if (!done.isCompleted) done.complete(heard.withAudio(audio));
      }());
    }

    JSObject? recognition;
    try {
      recognition = _constructor!.callAsConstructor<JSObject>();
      _active = recognition;
      recognition
        ..setProperty('lang'.toJS, lang.toJS)
        ..setProperty('continuous'.toJS, false.toJS)
        ..setProperty('interimResults'.toJS, false.toJS)
        ..setProperty('maxAlternatives'.toJS, 5.toJS);
      var heard = const BrowserHeard(<SpeechAlternative>[]);
      recognition
        ..setProperty(
          'onresult'.toJS,
          ((JSObject event) {
            try {
              heard = BrowserHeard(_readings(event));
            } on Object {
              heard = const BrowserHeard.error('unreadable');
            }
          }).toJS,
        )
        ..setProperty(
          'onerror'.toJS,
          ((JSObject event) {
            final code = event.getProperty<JSString?>('error'.toJS)?.toDart;
            finish(BrowserHeard.error(code ?? 'error'), keep: false);
          }).toJS,
        )
        // The end comes after the result, or alone when nothing was said.
        ..setProperty(
          'onend'.toJS,
          ((JSObject _) => finish(heard, keep: true)).toJS,
        )
        ..callMethod<JSAny?>('start'.toJS);
      // The recogniser has the microphone first; the recorder never delays
      // it and gives up quietly where the browser will not share.
      if (record && _recorderAllowed) unawaited(recorder.start());
    } on Object catch (e) {
      finish(BrowserHeard.error('${e.runtimeType}'), keep: false);
    }
    final started = recognition;
    return BrowserSession(done.future, () {
      finish(const BrowserHeard.error('aborted'), keep: false);
      try {
        started?.callMethod<JSAny?>('abort'.toJS);
      } on Object {
        // Already over.
      }
    });
  }

  /// Every reading of every result of the event, best first.
  static List<SpeechAlternative> _readings(JSObject event) {
    final results = event.getProperty<JSObject>('results'.toJS);
    final count = results.getProperty<JSNumber>('length'.toJS).toDartInt;
    final readings = <SpeechAlternative>[];
    for (var i = 0; i < count; i++) {
      final result = results.callMethod<JSObject>('item'.toJS, i.toJS);
      final length = result.getProperty<JSNumber>('length'.toJS).toDartInt;
      for (var j = 0; j < length; j++) {
        final alternative = result.callMethod<JSObject>('item'.toJS, j.toJS);
        final text = alternative
            .getProperty<JSString>('transcript'.toJS)
            .toDart;
        final confidence = alternative
            .getProperty<JSNumber?>('confidence'.toJS)
            ?.toDartDouble;
        readings.add(
          SpeechAlternative(
            text,
            // Chrome gives 0 to a reading it did not score.
            confidence: confidence == null || confidence <= 0
                ? null
                : confidence,
          ),
        );
      }
    }
    return readings;
  }

  @override
  void stop() {
    try {
      _active?.callMethod<JSAny?>('stop'.toJS);
    } on Object {
      // Nothing listening.
    }
  }
}

/// A `MediaRecorder` on its own microphone stream, for the take of one
/// listen: started beside the recogniser, stopped with it, decoded to 16-bit
/// mono PCM in memory (ADR-0054). Every step is guarded: a browser that will
/// not share the microphone, or cannot decode, gives no audio and the
/// recogniser is unaffected. Nothing is written anywhere.
class _BrowserRecorder {
  _BrowserRecorder(this._devices);

  final JSObject? _devices;
  JSObject? _stream;
  JSObject? _recorder;
  final List<JSObject> _chunks = <JSObject>[];
  Future<void>? _starting;
  bool _stopping = false;

  Future<void> start() => _starting = _start();

  Future<void> _start() async {
    try {
      final devices = _devices;
      final recorderClass = globalContext.getProperty<JSAny?>(
        'MediaRecorder'.toJS,
      );
      if (devices == null || !recorderClass.isA<JSFunction>()) return;
      final constraints = JSObject()..setProperty('audio'.toJS, true.toJS);
      final stream = await devices
          .callMethod<JSPromise<JSObject>>('getUserMedia'.toJS, constraints)
          .toDart;
      if (_stopping) {
        _release(stream);
        return;
      }
      _stream = stream;
      final recorder = (recorderClass as JSFunction)
          .callAsConstructor<JSObject>(stream);
      recorder.setProperty(
        'ondataavailable'.toJS,
        ((JSObject event) {
          final data = event.getProperty<JSObject?>('data'.toJS);
          final size =
              data?.getProperty<JSNumber?>('size'.toJS)?.toDartInt ?? 0;
          if (data != null && size > 0) _chunks.add(data);
        }).toJS,
      );
      _recorder = recorder;
      recorder.callMethod<JSAny?>('start'.toJS);
    } on Object {
      _stream = null;
      _recorder = null;
    }
  }

  static void _release(JSObject? stream) {
    try {
      final tracks = stream?.callMethod<JSArray<JSObject>>('getTracks'.toJS);
      for (final track in tracks?.toDart ?? const <JSObject>[]) {
        track.callMethod<JSAny?>('stop'.toJS);
      }
    } on Object {
      // Already stopped.
    }
  }

  /// Stops, lets go of the microphone and, when [keep], gives the take; null
  /// when nothing usable was recorded or [keep] is false (the take is then
  /// dropped, never decoded).
  Future<OwnAudio?> stop({required bool keep}) async {
    _stopping = true;
    try {
      await _starting;
    } on Object {
      // Never started.
    }
    final recorder = _recorder;
    final stream = _stream;
    _recorder = null;
    _stream = null;
    try {
      if (recorder != null &&
          recorder.getProperty<JSString?>('state'.toJS)?.toDart != 'inactive') {
        final stopped = Completer<void>();
        recorder.setProperty(
          'onstop'.toJS,
          ((JSObject _) {
            if (!stopped.isCompleted) stopped.complete();
          }).toJS,
        );
        recorder.callMethod<JSAny?>('stop'.toJS);
        await stopped.future.timeout(const Duration(seconds: 2));
      }
    } on Object {
      // Whatever arrived is what there is.
    }
    _release(stream);
    final chunks = List<JSObject>.of(_chunks);
    _chunks.clear();
    if (!keep || chunks.isEmpty) return null;
    return _decode(chunks);
  }

  static Future<OwnAudio?> _decode(List<JSObject> chunks) async {
    JSObject? context;
    try {
      final blobClass = globalContext.getProperty<JSFunction>('Blob'.toJS);
      final blob = blobClass.callAsConstructor<JSObject>(
        <JSAny>[for (final c in chunks) c].toJS,
      );
      final bytes = await blob
          .callMethod<JSPromise<JSArrayBuffer>>('arrayBuffer'.toJS)
          .toDart;
      var contextClass = globalContext.getProperty<JSAny?>('AudioContext'.toJS);
      if (!contextClass.isA<JSFunction>()) {
        contextClass = globalContext.getProperty<JSAny?>(
          'webkitAudioContext'.toJS,
        );
      }
      if (!contextClass.isA<JSFunction>()) return null;
      context = (contextClass as JSFunction).callAsConstructor<JSObject>();
      final buffer = await context
          .callMethod<JSPromise<JSObject>>('decodeAudioData'.toJS, bytes)
          .toDart;
      final rate = buffer.getProperty<JSNumber>('sampleRate'.toJS).toDartInt;
      final data = buffer
          .callMethod<JSFloat32Array>('getChannelData'.toJS, 0.toJS)
          .toDart;
      final pcm = ByteData(data.length * 2);
      var peak = 0.0;
      for (var i = 0; i < data.length; i++) {
        final v = data[i].clamp(-1.0, 1.0);
        if (v.abs() > peak) peak = v.abs();
        pcm.setInt16(i * 2, (v * 32767).round(), Endian.little);
      }
      // Silence is not the learner's voice (the browser shut the microphone
      // to this reader): no take.
      if (peak < 0.01) return null;
      return OwnAudio(pcm.buffer.asUint8List(), sampleRate: rate);
    } on Object {
      return null;
    } finally {
      try {
        context?.callMethod<JSAny?>('close'.toJS);
      } on Object {
        // Already closed.
      }
    }
  }
}
