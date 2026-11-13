import 'dart:io';

import 'package:fluenough/app/private_import.dart';

/// The tiny `qaa` package of the private-decks tests, as path to text.
const String privateFixtureFolder = 'test/fixtures/private/qaa-tiny';

Future<Map<String, String>> tinyPackage() async {
  final files = await readPackageFolder(Directory(privateFixtureFolder));
  return files ?? (throw StateError('the fixture could not be read'));
}

/// The fixture as another private-use language, `qab` and so on: every
/// `qaa` in a name or in the text becomes [code].
Map<String, String> asCode(Map<String, String> files, String code) => {
  for (final e in files.entries)
    e.key.replaceAll('qaa', code): e.value.replaceAll('qaa', code),
};

/// The fixture as a package for the real language `te`: ids `fnpd-te-`,
/// kind [kind], a path file `te-path.yaml`.
Map<String, String> asTelugu(
  Map<String, String> files, {
  String kind = 'modified-language',
}) {
  String fix(String s) => s
      .replaceAll('fnpd-qaa', 'fnpd-te')
      .replaceAll('"qaa-path"', '"te-path"')
      .replaceAll('"qaa"', '"te"')
      .replaceAll('iso639_3: "te"', 'iso639_3: "tel"')
      .replaceAll('qaa/', 'te/')
      .replaceAll('qaa-path', 'te-path');
  return {
    for (final e in files.entries)
      fix(e.key): e.key == 'manifest.yaml'
          ? fix(e.value)
                .replaceAll('kind: "new-language"', 'kind: "$kind"')
                .replaceFirst(
                  'min_app:',
                  kind == 'modified-language'
                      ? 'based_on: "te-1"\nmin_app:'
                      : 'min_app:',
                )
          : fix(e.value),
  };
}

/// The app's own Telugu course in miniature, as `decks/te/...` files: the
/// fixture with built-in ids (`te-home`, `te-0001`) and the path listing the
/// food unit first.
Map<String, String> tinyBuiltInTelugu(Map<String, String> files) {
  String fix(String s) => s
      .replaceAll('fnpd-qaa-', 'te-')
      .replaceAll('"qaa-path"', '"te-path"')
      .replaceAll('"qaa"', '"te"')
      .replaceAll('iso639_3: "te"', 'iso639_3: "tel"');
  return {
    for (final e in files.entries)
      if (e.key != 'manifest.yaml')
        'decks/${e.key.replaceAll('fnpd-qaa-', 'te-').replaceAll('qaa-path', 'te-path').replaceAll('qaa/', 'te/')}':
            fix(e.value),
  };
}
