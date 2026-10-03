/// Facts about this build of the app.
abstract final class AppInfo {
  /// The version, as `pubspec.yaml` has it, without the build number. There
  /// is no package to read it from the build (AGENTS.md rule 6), so it is
  /// kept in step by hand, and
  /// `test/features/settings/settings_page_test.dart` checks it.
  static const String version = '0.2.0';
}
