import '../l10n/app_localizations.dart';

/// A script named by its own name (#551).
extension ScriptNames on AppLocalizations {
  /// [script]'s own name, such as Eastern Nagari for `bengali`, or
  /// [fallback] for a script with none, or none given: the language's name,
  /// as the app named a script before #551.
  String scriptNameOr(String? script, String fallback) {
    final name = script == null ? '' : scriptName(script);
    return name.isEmpty ? fallback : name;
  }
}
