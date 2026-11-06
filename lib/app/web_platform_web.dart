import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'storage_persist.dart';
import 'web_platform.dart';

/// The page's real [WebPlatform], through `dart:js_interop` alone (AGENTS.md
/// rule 6). Only the browser compiles this file; see `web_platform.dart`.
///
/// `beforeinstallprompt` often fires before the app has started, so the page
/// holds it (tools/web/register_sw.js, which sets `fluenoughInstallPrompt`)
/// and says so with `fluenough-install` events; this reads and listens.
WebPlatform? openWebPlatform() => _BrowserPlatform();

class _BrowserPlatform implements WebPlatform {
  JSObject get _window => globalContext;

  JSObject? _object(JSObject from, String name) {
    try {
      return from.getProperty<JSObject?>(name.toJS);
    } on Object {
      return null;
    }
  }

  @override
  bool get isStandalone {
    try {
      final navigator = _object(_window, 'navigator');
      if (navigator?.getProperty<JSAny?>('standalone'.toJS)
          case final JSBoolean on when on.toDart) {
        return true;
      }
      final query = _window.callMethod<JSObject>(
        'matchMedia'.toJS,
        '(display-mode: standalone)'.toJS,
      );
      return query.getProperty<JSBoolean>('matches'.toJS).toDart;
    } on Object {
      return false;
    }
  }

  @override
  bool get isIos {
    try {
      final navigator = _object(_window, 'navigator');
      final agent =
          navigator?.getProperty<JSString?>('userAgent'.toJS)?.toDart ?? '';
      if (RegExp(r'iPhone|iPad|iPod').hasMatch(agent)) return true;
      // iPadOS reports a Mac, but a Mac has no touch screen.
      final platform =
          navigator?.getProperty<JSString?>('platform'.toJS)?.toDart ?? '';
      final touch =
          navigator?.getProperty<JSNumber?>('maxTouchPoints'.toJS)?.toDartInt ??
          0;
      return platform == 'MacIntel' && touch > 1;
    } on Object {
      return false;
    }
  }

  JSObject? get _held => _object(_window, 'fluenoughInstallPrompt');

  @override
  bool get canPrompt => _held != null;

  @override
  Future<bool> prompt() async {
    final event = _held;
    if (event == null) return false;
    try {
      // The browser lets an event be used once.
      _window.setProperty('fluenoughInstallPrompt'.toJS, null);
      await event.callMethod<JSPromise<JSAny?>>('prompt'.toJS).toDart;
      final choice = await event
          .getProperty<JSPromise<JSObject>>('userChoice'.toJS)
          .toDart;
      return choice.getProperty<JSString?>('outcome'.toJS)?.toDart ==
          'accepted';
    } on Object {
      return false;
    }
  }

  @override
  void onChanged(void Function() listener) {
    try {
      final handler = ((JSObject _) => listener()).toJS;
      _window.callMethod<JSAny?>(
        'addEventListener'.toJS,
        'fluenough-install'.toJS,
        handler,
      );
    } on Object {
      // No events: the state is read once.
    }
  }

  @override
  Future<bool> persisted() async {
    try {
      final storage = _object(_object(_window, 'navigator')!, 'storage');
      if (storage == null || !storage.has('persisted')) return false;
      final kept = await storage
          .callMethod<JSPromise<JSBoolean>>('persisted'.toJS)
          .toDart;
      return kept.toDart;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> requestPersist() => requestPersistentStorage();

  JSObject? get _local => _object(_window, 'localStorage');

  @override
  String? read(String key) {
    try {
      return _local?.callMethod<JSString?>('getItem'.toJS, key.toJS)?.toDart;
    } on Object {
      return null;
    }
  }

  @override
  void write(String key, String? value) {
    try {
      if (value == null) {
        _local?.callMethod<JSAny?>('removeItem'.toJS, key.toJS);
      } else {
        _local?.callMethod<JSAny?>('setItem'.toJS, key.toJS, value.toJS);
      }
    } on Object {
      // Storage denied: the hint shows again next visit, which is harmless.
    }
  }
}
