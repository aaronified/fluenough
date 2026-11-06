import 'package:flutter/foundation.dart';

import 'web_platform.dart';

/// How the web build offers to be installed, and what it says about the
/// browser keeping its storage (#1012, wiki: Plan-Web-Pwa).
///
/// Only a browser build has a [WebPlatform]; the Android and iOS apps and
/// the tests' default have none ([WebInstall.off]), so [onWeb] is false and
/// nothing about installing is shown there, by construction rather than by
/// a flag.
class WebInstall extends ChangeNotifier {
  WebInstall(this._platform, {this._clock = DateTime.now}) {
    _platform?.onChanged(_changed);
  }

  /// No browser: the apps.
  WebInstall.off() : this(null);

  final WebPlatform? _platform;
  final DateTime Function() _clock;

  /// Stored on this device, so cleared with the site's data (the learner has
  /// then lost their decks and progress anyway). "Got it" is never again.
  static const String dismissedKey = 'installHintDismissed';

  /// "Later" hides the hint until this date, as an ISO 8601 string.
  static const String laterUntilKey = 'installHintLaterUntil';

  /// Safari clears a site's data after 7 days unused, so "Later" is as long.
  static const Duration laterFor = Duration(days: 7);

  bool? _persisted;
  bool _asking = false;

  /// This is a browser build.
  bool get onWeb => _platform != null;

  /// Running as an installed app, which the browser keeps storage for.
  bool get installed => _platform?.isStandalone ?? false;

  /// On an iPhone or iPad, where installing is Share, then Add to Home Screen.
  bool get isIos => _platform?.isIos ?? false;

  /// The browser's own install prompt can be shown now (Chrome, Android).
  bool get canPrompt => !installed && (_platform?.canPrompt ?? false);

  /// Install is by the browser's prompt, or by the how-to; false where the
  /// browser has neither (desktop Safari, Firefox).
  bool get canInstall => !installed && (canPrompt || isIos);

  /// The browser has agreed to keep this site's storage, or this is an
  /// installed app. Null before it has been asked.
  bool? get kept => installed ? true : _persisted;

  /// Reads whether storage is kept. Never throws.
  Future<void> load() async {
    final platform = _platform;
    if (platform == null) return;
    final persisted = await platform.persisted();
    if (persisted == _persisted) return;
    _persisted = persisted;
    notifyListeners();
  }

  /// Asks the browser to keep this site's storage, once at a time. Safari
  /// and Chrome decide for themselves; the answer is in [kept].
  Future<void> requestPersist() async {
    final platform = _platform;
    if (platform == null || _asking) return;
    _asking = true;
    try {
      _persisted = await platform.requestPersist();
    } finally {
      _asking = false;
    }
    notifyListeners();
  }

  /// The hint on Today: installing is possible, and the learner has not
  /// said "Got it" or "Later" for now.
  bool get hintVisible {
    final platform = _platform;
    if (platform == null || !canInstall) return false;
    if (platform.read(dismissedKey) != null) return false;
    final until = DateTime.tryParse(platform.read(laterUntilKey) ?? '');
    return until == null || !_clock().isBefore(until);
  }

  /// "Got it": never again on this device. Settings still has the how-to.
  void gotIt() {
    _platform?.write(dismissedKey, '1');
    notifyListeners();
  }

  /// "Later": not for [laterFor].
  void later() {
    _platform?.write(
      laterUntilKey,
      _clock().add(laterFor).toUtc().toIso8601String(),
    );
    notifyListeners();
  }

  /// Shows the browser's install prompt. The hint is done with either way:
  /// accepted, the app is installed; declined, the learner said no.
  Future<void> install() async {
    final platform = _platform;
    if (platform == null) return;
    final accepted = await platform.prompt();
    if (!accepted) later();
    notifyListeners();
  }

  void _changed() => notifyListeners();
}
