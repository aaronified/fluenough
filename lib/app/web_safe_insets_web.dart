import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/painting.dart' show EdgeInsets;

/// A hidden element whose padding is the four `env(safe-area-inset-*)`
/// values; its computed padding is what the browser says they are. CSS
/// pixels are Flutter's logical pixels on the web.
JSObject? _probe;

JSObject? _makeProbe() {
  final document = globalContext.getProperty<JSObject?>('document'.toJS);
  final root = document?.getProperty<JSObject?>('documentElement'.toJS);
  if (document == null || root == null) return null;
  final probe = document.callMethod<JSObject>('createElement'.toJS, 'div'.toJS);
  final style = probe.getProperty<JSObject>('style'.toJS);
  for (final entry in const <String, String>{
    'position': 'fixed',
    'visibility': 'hidden',
    'pointer-events': 'none',
    'width': '0',
    'height': '0',
    'padding-top': 'env(safe-area-inset-top, 0px)',
    'padding-right': 'env(safe-area-inset-right, 0px)',
    'padding-bottom': 'env(safe-area-inset-bottom, 0px)',
    'padding-left': 'env(safe-area-inset-left, 0px)',
  }.entries) {
    style.callMethod<JSAny?>(
      'setProperty'.toJS,
      entry.key.toJS,
      entry.value.toJS,
    );
  }
  root.callMethod<JSAny?>('appendChild'.toJS, probe);
  return probe;
}

/// The window's safe-area insets; zero if the browser cannot say.
EdgeInsets webSafeInsets() {
  try {
    final probe = _probe ??= _makeProbe();
    if (probe == null) return EdgeInsets.zero;
    final computed = globalContext.callMethod<JSObject>(
      'getComputedStyle'.toJS,
      probe,
    );
    double read(String side) {
      final value = computed
          .callMethod<JSString?>('getPropertyValue'.toJS, 'padding-$side'.toJS)
          ?.toDart;
      return double.tryParse((value ?? '').replaceAll('px', '')) ?? 0;
    }

    return EdgeInsets.fromLTRB(
      read('left'),
      read('top'),
      read('right'),
      read('bottom'),
    );
  } on Object {
    return EdgeInsets.zero;
  }
}
