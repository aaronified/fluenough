/// The deck-kinds course of the UI tests (typed search tabs, the topic page):
/// language `zz` with a path of three units marked A1, A2 and B1, a hidden
/// professional deck, the fixture's sections file (search kinds, genres and a
/// profession), a situations file and three topics: a topic at A1 over the
/// first deck, one at B1 over the last (above an A1 learner), and a script
/// topic with a list of characters. A fresh learner is at A1.
library;

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';

import 'kinds_course.dart';
import 'kinds_fixture.dart';

const String kindsTopicsFile = '''
schema: 1
id: "zz-topics"
kind: "topics"
language: "zz"
license: "CC-BY-SA-4.0"
topics:
  - id: "zz-house"
    name: { en: "House words" }
    summary: { en: "Words for the house." }
    kind: "words"
    level: "A1"
    decks: ["zz-words"]
    units: ["zz-words"]
    topics: ["zz-library"]
  - id: "zz-library"
    name: { en: "Library words" }
    kind: "words"
    level: "B1"
    decks: ["zz-last"]
    cards: ["zz-0101"]
  - id: "zz-letters"
    name: { en: "Joined letters" }
    kind: "script"
    level: "A1"
    term: { text: "ab", reading: "joined" }
    chars: ["ab", "cd", "ef"]
''';

const String kindsSituationsFile = '''
schema: 1
id: "zz-situations"
name: "Testlang situations"
kind: situations
language: { code: zz, iso639_3: zzz, name: Testlang, script: latin, tts: es-ES }
license: "CC-BY-SA-4.0"
situations:
  - id: "visit"
    icon: "taxi"
    title: { en: "House visit" }
    phrases: ["zz-0001"]
    words: ["zz-0002"]
''';

/// The files of the course, by path.
Map<String, String> kindsWorld() => <String, String>{
  ...kindsCourse(),
  'decks/sections.yaml': kindsFixtureFiles()['decks/sections.yaml']!,
  'decks/zz/zz-topics.yaml': kindsTopicsFile,
  'decks/zz/zz-situations.yaml': kindsSituationsFile,
};

/// The app on [files] (the course by default), loaded and showing `zz`.
Future<AppState> kindsWorldApp({
  Map<String, String>? files,
  SettingsNotifier? settings,
  AppState Function(Map<String, String> files, SettingsNotifier settings)?
  build,
}) async {
  final all = files ?? kindsWorld();
  final s = settings ?? SettingsNotifier(spokenLanguages: const <String>['en']);
  final state =
      build?.call(all, s) ??
      AppState.test(decks: MemoryDeckSource(all), settings: s);
  await state.load();
  state.showLanguage('zz');
  return state;
}
