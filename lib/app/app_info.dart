import 'dart:io';

/// Facts about this build of the app.
abstract final class AppInfo {
  /// The version, as `pubspec.yaml` has it, without the build number. There
  /// is no package to read it from the build (AGENTS.md rule 6), so it is
  /// kept in step by hand, and
  /// `test/features/settings/settings_page_test.dart` checks it.
  static const String version = '0.3.4';

  /// The phone's system, such as `Android 14 (API 34)`, for a report whose
  /// reporter agrees to send it (ADR-0021). Android's own properties need no
  /// package; anywhere else, or if they cannot be read, what Dart knows.
  /// Asked each time rather than kept: a future kept from one test's zone
  /// never completes in the next.
  static Future<String> system() async {
    if (Platform.isAndroid) {
      try {
        Future<String> property(String name) async =>
            ((await Process.run('getprop', <String>[name])).stdout as String)
                .trim();
        final release = await property('ro.build.version.release');
        final sdk = await property('ro.build.version.sdk');
        if (release.isNotEmpty) return 'Android $release (API $sdk)';
      } on Exception {
        // Falls through to what Dart knows.
      }
    }
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }
}
