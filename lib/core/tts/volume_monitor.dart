import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

/// Whether the phone's media volume, the one speech plays at, is at zero
/// (ADR-0026). A listening card asks for it to be raised rather than play
/// into silence. Notifies when that changes.
abstract class VolumeMonitor implements Listenable {
  bool get muted;

  void dispose();
}

/// The phone's media volume, as `flutter_volume_controller` reports it.
/// Where the plugin is missing, as in widget tests, the volume reads as not
/// muted.
class SystemVolumeMonitor extends ChangeNotifier implements VolumeMonitor {
  SystemVolumeMonitor() {
    try {
      _subscription = FlutterVolumeController.addListener(_onVolume);
    } on MissingPluginException {
      _subscription = null;
    }
  }

  StreamSubscription<double>? _subscription;
  bool _muted = false;

  @override
  bool get muted => _muted;

  void _onVolume(double volume) {
    final muted = volume <= 0;
    if (muted == _muted) return;
    _muted = muted;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// A volume set by hand, for tests and the gallery: not muted unless
/// [muted] is set.
class FixedVolumeMonitor extends ChangeNotifier implements VolumeMonitor {
  FixedVolumeMonitor({this._muted = false});

  bool _muted;

  @override
  bool get muted => _muted;

  set muted(bool value) {
    if (value == _muted) return;
    _muted = value;
    notifyListeners();
  }
}
