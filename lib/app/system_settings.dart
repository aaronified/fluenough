import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Which of the phone's own pages opened for installing a voice.
enum VoiceSettingsPage {
  /// Android's text-to-speech settings: the preferred engine, and the way
  /// to its voice data.
  textToSpeech,

  /// A text-to-speech engine's own page for installing voice data, when
  /// the phone has no text-to-speech settings to open.
  installVoices,

  /// Nothing: the phone has neither, or this is not Android.
  none,
}

/// Opens the phone's own settings. An interface so that tests need no
/// platform.
abstract interface class SystemSettings {
  /// Opens where the phone's voices are installed, and says which page
  /// opened, or [VoiceSettingsPage.none]. May throw if the platform cannot
  /// be asked; Settings > Voices then explains the way there instead.
  Future<VoiceSettingsPage> openVoiceSettings();
}

/// [SystemSettings] through the app's own platform channel,
/// `app.fluenough/system`. Its Android side is in MainActivity, which
/// `tools/brand_android.py` writes after `flutter create`, as android/ is
/// never committed (AGENTS.md rule 4). No plugin does this, and a channel
/// needs no dependency (rule 6).
///
/// Only on Android: anywhere else it opens nothing.
class ChannelSystemSettings implements SystemSettings {
  const ChannelSystemSettings({this.channel = defaultChannel});

  /// The channel MainActivity listens on.
  static const MethodChannel defaultChannel = MethodChannel(
    'app.fluenough/system',
  );

  final MethodChannel channel;

  @override
  Future<VoiceSettingsPage> openVoiceSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return VoiceSettingsPage.none;
    }
    final opened = await channel.invokeMethod<String>('openVoiceSettings');
    return VoiceSettingsPage.values.asNameMap()[opened] ??
        VoiceSettingsPage.none;
  }
}

/// [SystemSettings] that opens nothing: for a build given none, such as the
/// gallery's.
class NullSystemSettings implements SystemSettings {
  const NullSystemSettings();

  @override
  Future<VoiceSettingsPage> openVoiceSettings() async => VoiceSettingsPage.none;
}

/// A [SystemSettings] that answers [opens], or throws [error] when it is
/// set, and counts how often it was asked. For tests.
class FixedSystemSettings implements SystemSettings {
  FixedSystemSettings({
    this.opens = VoiceSettingsPage.textToSpeech,
    this.error,
  });

  /// What opens. Can change between calls.
  VoiceSettingsPage opens;

  /// Thrown instead, when set.
  Object? error;

  /// How many times the voice settings were asked for.
  int voiceSettingsAsked = 0;

  @override
  Future<VoiceSettingsPage> openVoiceSettings() async {
    voiceSettingsAsked++;
    final thrown = error;
    if (thrown != null) throw thrown;
    return opens;
  }
}
