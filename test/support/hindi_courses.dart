/// A tiny Hindi course taught from English, Bengali and Telugu in turn,
/// for the native-language choice (ADR-0036, B1 format spec 9.5).
library;

const _hindi =
    'language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }';
const _natives = <String, String>{
  'en': '{ code: en, iso639_3: eng, name: English }',
  'bn': '{ code: bn, iso639_3: ben, name: Bengali }',
  'te': '{ code: te, iso639_3: tel, name: Telugu }',
};

/// Hindi's path, three units, and its first deck a core with an English
/// layer. [bengali] and [telugu] name the units that have a deck in those
/// native languages: unit `a` through a layer of the core, the others as
/// single-file decks.
Map<String, String> hindi({
  Set<String> bengali = const <String>{},
  Set<String> telugu = const <String>{},
}) {
  String layer(String native) =>
      '''
schema: 1
id: hi-$native-a
kind: layer
core: hi-a
native: ${_natives[native]}
name: "A"
license: CC0-1.0
cards:
  "hi-0001": { native: "k ($native)" }
''';
  String single(String native, String name, int n) =>
      '''
schema: 1
id: hi-$native-$name
name: "$name"
$_hindi
native: ${_natives[native]}
license: CC0-1.0
cards:
  - { id: hi-$native-000$n, target: "ख", native: "kh", reading: "kha" }
''';
  final files = <String, String>{
    'decks/hi/hi-path.yaml': '''
schema: 1
kind: path
id: hi-path
language: hi
units:
  - [hi-a]
  - [hi-b]
  - [hi-c]
''',
    'decks/hi/hi-a.yaml':
        '''
schema: 1
id: hi-a
part: core
$_hindi
license: CC0-1.0
cards:
  - { id: hi-0001, target: "क", reading: "ka" }
''',
    'decks/hi/en/hi-en-a.yaml': layer('en'),
    'decks/hi/hi-en-b.yaml': single('en', 'b', 2),
    'decks/hi/hi-en-c.yaml': single('en', 'c', 3),
  };
  for (final (native, units) in <(String, Set<String>)>[
    ('bn', bengali),
    ('te', telugu),
  ]) {
    for (final (n, name) in <String>['a', 'b', 'c'].indexed) {
      if (!units.contains(name)) continue;
      if (name == 'a') {
        files['decks/hi/$native/hi-$native-a.yaml'] = layer(native);
      } else {
        files['decks/hi/hi-$native-$name.yaml'] = single(native, name, n + 1);
      }
    }
  }
  return files;
}
