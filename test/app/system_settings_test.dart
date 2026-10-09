import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/system_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const settings = ChannelSystemSettings();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Answers the channel as MainActivity would, with [answer], and records
  /// each method asked for.
  List<String> answer(Object? answer) {
    final asked = <String>[];
    messenger.setMockMethodCallHandler(ChannelSystemSettings.defaultChannel, (
      call,
    ) async {
      asked.add(call.method);
      return answer;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        ChannelSystemSettings.defaultChannel,
        null,
      ),
    );
    return asked;
  }

  test('the channel is the one tools/brand_android.py writes', () {
    expect(ChannelSystemSettings.defaultChannel.name, 'app.fluenough/system');
  });

  test(
    'on Android it asks MainActivity, and reads which page opened',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      for (final page in VoiceSettingsPage.values) {
        final asked = answer(page.name);
        expect(await settings.openVoiceSettings(), page);
        expect(asked, <String>['openVoiceSettings']);
      }
    },
  );

  test('an answer it does not know, or none, is none', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    answer('somethingElse');
    expect(await settings.openVoiceSettings(), VoiceSettingsPage.none);
    answer(null);
    expect(await settings.openVoiceSettings(), VoiceSettingsPage.none);
  });

  test('a platform error reaches the caller', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    messenger.setMockMethodCallHandler(
      ChannelSystemSettings.defaultChannel,
      (call) async => throw PlatformException(code: 'failed'),
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        ChannelSystemSettings.defaultChannel,
        null,
      ),
    );
    await expectLater(
      settings.openVoiceSettings(),
      throwsA(isA<PlatformException>()),
    );
  });

  test('anywhere but Android it opens nothing, and asks nothing', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final asked = answer(VoiceSettingsPage.textToSpeech.name);
    expect(await settings.openVoiceSettings(), VoiceSettingsPage.none);
    expect(asked, isEmpty);
  });

  test('the fakes', () async {
    expect(
      await const NullSystemSettings().openVoiceSettings(),
      VoiceSettingsPage.none,
    );
    final fixed = FixedSystemSettings();
    expect(await fixed.openVoiceSettings(), VoiceSettingsPage.textToSpeech);
    fixed.error = StateError('no');
    await expectLater(fixed.openVoiceSettings(), throwsStateError);
    expect(fixed.voiceSettingsAsked, 2);
  });
}
