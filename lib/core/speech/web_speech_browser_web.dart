import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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

  @override
  BrowserSession recognise(String lang) {
    final done = Completer<BrowserHeard>();
    void finish(BrowserHeard heard) {
      if (!done.isCompleted) done.complete(heard);
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
            finish(BrowserHeard.error(code ?? 'error'));
          }).toJS,
        )
        // The end comes after the result, or alone when nothing was said.
        ..setProperty('onend'.toJS, ((JSObject _) => finish(heard)).toJS)
        ..callMethod<JSAny?>('start'.toJS);
    } on Object catch (e) {
      finish(BrowserHeard.error('${e.runtimeType}'));
    }
    final started = recognition;
    return BrowserSession(done.future, () {
      finish(const BrowserHeard.error('aborted'));
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
