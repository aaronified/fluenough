/// The starter package: a tiny invented language written as a private
/// package, with a comment on each part, for a learner who wants to write
/// their own (#1017, Plan-Private-Languages task 21; wiki Private-language
/// package). Pure Dart: its text is checked by the same import every package
/// goes through, so it never drifts from the format.
library;

import 'dart:typed_data';

import 'private_export.dart';

/// The starter package's files, by path in the package, manifest first.
const Map<String, String> privateStarterFiles = <String, String>{
  'manifest.yaml': r'''# The manifest says what the package is. Change `qaa` (and `Tiny`) to your
# own language: a code from qaa to qtz that is not taken, or the real code of
# a language the app teaches when you are changing its course. `revision`
# goes up by one each time you give the package to someone again.
# `qaa` is an ISO 639-3 code kept for private use, so it can never be a
# real course.
format: "fluenough-private"
package: "fnpd-qaa"
revision: 1
kind: "new-language"
min_app: "0.9.0"
license: "CC-BY-SA-4.0"
language:
  code: "qaa"
  iso639_3: "qaa"
  name: "Tiny"
  script: "latin"
''',
  'qaa-path.yaml': r'''# The path lists the units in the order they are taught. Each unit names
# decks by id (yours start with fnpd-<code>-; a course you change can also
# name the app's own decks), and `words` is how many new words it teaches.
schema: 1
kind: "path"
id: "qaa-path"
language: "qaa"
units:
  - decks: ["fnpd-qaa-home"]
    words: 3
  - decks: ["fnpd-qaa-food"]
    words: 3
''',
  'qaa/fnpd-qaa-home.yaml': r'''# A core deck: the language itself. Every card has an id that you write,
# that starts with fnpd-<code>- and that you never change or reuse: the
# phone keeps a learner's progress under it.
schema: 1
id: "fnpd-qaa-home"
part: "core"
kind: "vocab"
language: { code: "qaa", iso639_3: "qaa", name: "Tiny", script: "latin" }
license: "CC-BY-SA-4.0"
tags: ["beginner"]
cards:
  - id: "fnpd-qaa-0001"
    target: "kolu"
    ipa: "ˈkolu"
    pos: "noun"
    tags: ["home"]
  - id: "fnpd-qaa-0002"
    target: "mira"
    ipa: "ˈmira"
    pos: "noun"
    tags: ["home"]
  - id: "fnpd-qaa-0003"
    target: "tepa"
    ipa: "ˈtepa"
    pos: "noun"
    tags: ["home"]
''',
  'qaa/en/fnpd-qaa-en-home.yaml': r'''# A layer: what the cards mean in one native language (here English).
# It lists each card of its core by id. Write one layer for each language
# the learner can be taught from.
schema: 1
id: "fnpd-qaa-en-home"
kind: "layer"
core: "fnpd-qaa-home"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Home"
license: "CC-BY-SA-4.0"
description: "Three words for the house, in an invented language."
cards:
  "fnpd-qaa-0001":
    native: "house"
  "fnpd-qaa-0002":
    native: "door"
  "fnpd-qaa-0003":
    native: "roof"
''',
  'qaa/fnpd-qaa-food.yaml': r'''schema: 1
id: "fnpd-qaa-food"
part: "core"
kind: "vocab"
language: { code: "qaa", iso639_3: "qaa", name: "Tiny", script: "latin" }
license: "CC-BY-SA-4.0"
tags: ["beginner"]
cards:
  - id: "fnpd-qaa-0004"
    target: "nesi"
    ipa: "ˈnesi"
    pos: "noun"
    tags: ["food"]
  - id: "fnpd-qaa-0005"
    target: "lomu"
    ipa: "ˈlomu"
    pos: "noun"
    tags: ["food"]
  - id: "fnpd-qaa-0006"
    target: "sika"
    ipa: "ˈsika"
    pos: "noun"
    tags: ["food"]
''',
  'qaa/en/fnpd-qaa-en-food.yaml': r'''schema: 1
id: "fnpd-qaa-en-food"
kind: "layer"
core: "fnpd-qaa-food"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Food"
license: "CC-BY-SA-4.0"
description: "Three words for food, in an invented language."
cards:
  "fnpd-qaa-0004":
    native: "bread"
  "fnpd-qaa-0005":
    native: "water"
  "fnpd-qaa-0006":
    native: "salt"
''',
};

/// The starter package as a `.fnzip`, which imports with no error.
Uint8List privateStarterArchive() => PrivateExport.archive(privateStarterFiles);

/// The file name the starter is offered under.
const String privateStarterFileName = 'fluenough-starter.fnzip';
