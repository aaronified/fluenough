/// The notch and home-bar insets of the browser window, for the web build.
///
/// Flutter's web engine reports no padding, so `SafeArea` inside the app
/// does nothing there; on an iPhone with the page installed to the home
/// screen (`viewport-fit=cover`, tools/brand_web.py) the app would be drawn
/// under the notch and the home bar. The CSS `env(safe-area-inset-*)` values
/// have them; the frame (`web_frame.dart`) hands them to the screens as
/// their padding (#1012).
library;

import 'package:flutter/painting.dart' show EdgeInsets;

import 'web_safe_insets_stub.dart'
    if (dart.library.js_interop) 'web_safe_insets_web.dart'
    as impl;

/// The window's safe-area insets in logical pixels, zero where there are none
/// and off the web.
EdgeInsets webSafeInsets() => impl.webSafeInsets();
