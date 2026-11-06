import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'system_settings.dart';

/// Where the phone's wallpaper colour comes from. An interface so that tests
/// need no platform.
abstract interface class WallpaperSource {
  /// The colour the phone draws its Material You palette from, or null when
  /// there is none: not Android, Android below 12, or the phone gave none.
  /// Never throws.
  Future<Color?> read();
}

/// [WallpaperSource] through the app's own platform channel,
/// `app.fluenough/system`, whose `wallpaperColour` answers with the system's
/// primary accent colour on Android 12 and later (API 31), written by
/// `tools/brand_android.py`. A channel is no dependency (AGENTS.md rule 6).
///
/// Only on Android: on the web, desktop and iOS it answers null without
/// asking, so no row about wallpaper colours is drawn there.
class ChannelWallpaperSource implements WallpaperSource {
  const ChannelWallpaperSource({
    this.channel = ChannelSystemSettings.defaultChannel,
  });

  final MethodChannel channel;

  @override
  Future<Color?> read() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final argb = await channel.invokeMethod<int>('wallpaperColour');
      // The channel carries a signed 32 bit value.
      return argb == null ? null : Color(argb & 0xFFFFFFFF);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      // A MainActivity written before this existed.
      return null;
    }
  }
}

/// A [WallpaperSource] with no wallpaper: the web, desktop and iOS builds,
/// and the tests' default.
class NullWallpaperSource implements WallpaperSource {
  const NullWallpaperSource();

  @override
  Future<Color?> read() async => null;
}

/// A [WallpaperSource] that answers [colour]. For tests and the gallery.
class FixedWallpaperSource implements WallpaperSource {
  FixedWallpaperSource(this.colour);

  /// What the phone gives. Can change between calls.
  Color? colour;

  @override
  Future<Color?> read() async => colour;
}

/// The phone's wallpaper colour, read at launch and each time the app comes
/// back to the front (the wallpaper may have changed meanwhile).
///
/// [seed] is null until it is read, and for good where the phone has none.
/// Settings draws its Wallpaper colours row only while [available], and the
/// themes follow it only while the learner has it on.
class WallpaperColours extends ChangeNotifier {
  WallpaperColours(this._source);

  /// No wallpaper: the web, desktop and iOS.
  WallpaperColours.off() : this(const NullWallpaperSource());

  final WallpaperSource _source;
  Color? _seed;
  bool _disposed = false;

  /// The colour the palette is made from, or null.
  Color? get seed => _seed;

  /// The phone gives a palette, so the setting can be offered.
  bool get available => _seed != null;

  /// Reads the colour again, and tells listeners if it changed.
  Future<void> refresh() async {
    Color? read;
    try {
      read = await _source.read();
    } on Object {
      read = null;
    }
    if (_disposed || read == _seed) return;
    _seed = read;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
