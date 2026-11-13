import '../data/spoken_languages.dart';
import '../private/private_manifest.dart';

/// The languages a learner can name, merged (Plan-Private-Languages, task 8):
/// the built-in list (`assets/languages.yaml`) and the manifests of the
/// **active** private packages (#1017).
///
/// A package for a language the app does not teach is added at the end, as
/// any other entry, with the manifest's name, own name and script. A package
/// that changes a language the app teaches (`te`) replaces that entry's
/// names and scripts with the manifest's, and keeps the rest of the entry (its
/// family, aliases, the sheet's questions, and its place in the list). Pure
/// Dart, no Flutter.
List<SpokenLanguage> mergeLanguageDirectory(
  List<SpokenLanguage> builtIn,
  Iterable<PrivateManifest> packages,
) {
  final byCode = <String, PrivateManifest>{
    for (final manifest in packages) manifest.code: manifest,
  };
  if (byCode.isEmpty) return builtIn;
  final merged = <SpokenLanguage>[];
  final seen = <String>{};
  for (final language in builtIn) {
    seen.add(language.code);
    final manifest = byCode[language.code];
    merged.add(manifest == null ? language : _modified(language, manifest));
  }
  for (final manifest in byCode.values) {
    if (!seen.contains(manifest.code)) merged.add(_added(manifest));
  }
  return merged;
}

List<String> _scripts(PrivateManifest manifest) => <String>[
  for (final script in manifest.language.allScripts)
    if (script.isNotEmpty) script,
];

SpokenLanguage _added(PrivateManifest manifest) {
  final language = manifest.language;
  return SpokenLanguage(
    code: manifest.code,
    iso639_3: language.iso639_3,
    name: language.name,
    ownName: manifest.ownName ?? language.name,
    scripts: _scripts(manifest),
    isPrivate: true,
  );
}

SpokenLanguage _modified(SpokenLanguage base, PrivateManifest manifest) {
  final scripts = _scripts(manifest);
  return SpokenLanguage(
    code: base.code,
    iso639_3: base.iso639_3,
    name: manifest.language.name,
    ownName: manifest.ownName ?? base.ownName,
    scripts: scripts.isEmpty ? base.scripts : scripts,
    family: base.family,
    scriptQuestion: base.scriptQuestion,
    scriptCanRead: base.scriptCanRead,
    scriptsQuestion: base.scriptsQuestion,
    scriptCanReadFor: base.scriptCanReadFor,
    scriptTextUnchecked: base.scriptTextUnchecked,
    aliases: base.aliases,
    dialect: base.dialect,
    scriptOnly: base.scriptOnly,
    typed: base.typed,
    verification: base.verification,
    popular: base.popular,
    isPrivate: true,
  );
}
