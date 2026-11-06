/// What the page around a web build can tell the app, and do for it (#1012):
/// is it installed, can the browser's own install prompt be shown, is the
/// browser asked to keep this site's storage, and a small per-device store.
///
/// [openWebPlatform] is the real one where `dart:js_interop` exists, which
/// is only in a browser build; anywhere else, such as the Dart VM that runs
/// the tests, it answers null, and so does the Android and iOS app, so
/// nothing about the web is ever shown there.
library;

import 'web_platform_stub.dart'
    if (dart.library.js_interop) 'web_platform_web.dart'
    as impl;

/// The browser, as [WebInstall] needs it. Every member must be safe to call
/// in a browser that lacks the feature: the answer is then "no".
abstract class WebPlatform {
  /// Running as an installed app: `display-mode: standalone`, or Safari's
  /// `navigator.standalone`.
  bool get isStandalone;

  /// An iPhone, iPad or iPod (an iPad may call itself a Mac). Installing
  /// there is from the Share menu, as there is no install prompt.
  bool get isIos;

  /// The browser has offered its own install prompt, and it is still held:
  /// `beforeinstallprompt`, in Chrome on Android and desktop.
  bool get canPrompt;

  /// Shows the browser's install prompt. True if the learner accepted.
  Future<bool> prompt();

  /// Called when [canPrompt] or [isStandalone] may have changed: the prompt
  /// became available, or the app was installed.
  void onChanged(void Function() listener);

  /// `navigator.storage.persisted()`: has the browser agreed to keep this
  /// site's storage? False where it cannot say.
  Future<bool> persisted();

  /// `navigator.storage.persist()`: asks, and returns the browser's answer.
  Future<bool> requestPersist();

  /// A value kept in the browser on this device, or null. It goes when the
  /// site's data does, which is right for a hint about that data.
  String? read(String key);

  /// Keeps [value] under [key], or removes it when null. Never throws.
  void write(String key, String? value);
}

/// The browser's [WebPlatform], or null when this is not a browser build.
WebPlatform? openWebPlatform() => impl.openWebPlatform();
