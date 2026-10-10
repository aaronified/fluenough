import 'dart:convert';

import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/deck_downloads.dart';
import '../../app/downloaded_decks.dart';
import '../../app/memory_progress.dart';
import '../../app/settings.dart';
import '../../core/decks/deck_fetch.dart';
import '../../core/decks/deck_index.dart';
import '../../core/tts/tts_engine.dart';

/// The language picker's states for the debug gallery and its tests
/// (#211): a deck index of the eight courses, and deck downloads frozen in
/// each state the mockup draws. **Illustrative**, as the mockup is: the
/// sizes are the courses' on `main`, the rest is made up so that each
/// state shows, and the second native languages are invented (today every
/// deck is taught from English).
abstract final class PickerFixtures {
  /// Each course: its name, own name, icon, script, size in KB, and how
  /// much of its 30-unit B1 plan is written (units, words in each).
  static const List<
    ({
      String code,
      String name,
      String own,
      String icon,
      String script,
      int kb,
      int units,
      int words,
    })
  >
  _courses = [
    (
      code: 'as',
      name: 'Assamese',
      own: 'অসমীয়া',
      icon: 'অ',
      script: 'bengali',
      kb: 339,
      units: 6,
      words: 81,
    ),
    (
      code: 'bn',
      name: 'Bengali',
      own: 'বাংলা',
      icon: 'বা',
      script: 'bengali',
      kb: 407,
      units: 11,
      words: 59,
    ),
    (
      code: 'es',
      name: 'Spanish',
      own: 'Español',
      icon: 'Es',
      script: 'latin',
      kb: 10,
      units: 1,
      words: 35,
    ),
    (
      code: 'gu',
      name: 'Gujarati',
      own: 'ગુજરાતી',
      icon: 'ગુ',
      script: 'gujarati',
      kb: 305,
      units: 6,
      words: 90,
    ),
    (
      code: 'hi',
      name: 'Hindi',
      own: 'हिन्दी',
      icon: 'हि',
      script: 'devanagari',
      kb: 304,
      units: 6,
      words: 86,
    ),
    (
      code: 'kn',
      name: 'Kannada',
      own: 'ಕನ್ನಡ',
      icon: 'ಕ',
      script: 'kannada',
      kb: 287,
      units: 6,
      words: 77,
    ),
    (
      code: 'mr',
      name: 'Marathi',
      own: 'मराठी',
      icon: 'म',
      script: 'devanagari',
      kb: 328,
      units: 6,
      words: 86,
    ),
    (
      code: 'te',
      name: 'Telugu',
      own: 'తెలుగు',
      icon: 'తె',
      script: 'telugu',
      kb: 259,
      units: 10,
      words: 44,
    ),
  ];

  /// Words planned in each unit: 30 of them make 2,700 words by B1.
  static const int _planned = 90;

  static const Map<String, String> _nativeNames = <String, String>{
    'en': 'English', // ui-literal-ok: debug-only gallery
    'bn': 'Bengali', // ui-literal-ok: debug-only gallery
    'hi': 'Hindi', // ui-literal-ok: debug-only gallery
    'gu': 'Gujarati', // ui-literal-ok: debug-only gallery
    'mr': 'Marathi', // ui-literal-ok: debug-only gallery
  };

  /// The index: every course taught from English, and Telugu also from the
  /// languages in [teluguFrom].
  static String index({List<String> teluguFrom = const <String>[]}) =>
      jsonEncode(<String, Object?>{
        'version': supportedIndexVersion,
        'languages': <Object?>[
          for (final c in _courses)
            <String, Object?>{
              'code': c.code,
              'name': c.name,
              'own_name': c.own,
              'icon': c.icon,
              'script': c.script,
              'script_decks': c.script != 'latin',
              'natives': <Object?>[
                for (final n in <String>[
                  if (c.code == 'te') ...teluguFrom,
                  'en',
                ])
                  <String, String>{'code': n, 'name': _nativeNames[n]!},
              ],
              'size': c.kb * 1024,
              'units': <Object?>[
                for (var u = 0; u < 30; u++)
                  <String, Object?>{
                    'decks': <String>['${c.code}-unit-$u'],
                    if (u >= c.units) 'planned': true,
                    'words': _planned,
                    'grammar': <String>['topic-$u'],
                    if (u == 9) 'milestone': 'A1',
                    if (u == 19) 'milestone': 'A2',
                    if (u == 29) 'milestone': 'B1',
                    if (u < c.units)
                      'has': <String, int>{
                        for (final n in <String>[
                          if (c.code == 'te') ...teluguFrom,
                          'en',
                        ])
                          // Taught from a learner's language, a little less
                          // is written so far.
                          n: n == 'en' ? c.words : c.words ~/ 2,
                      },
                  },
              ],
              'files': <Object?>[
                <String, Object?>{
                  'path': 'decks/${c.code}/${c.code}-path.yaml',
                  'size': c.kb * 1024,
                  'sha256': '0' * 64,
                  'kind': 'path',
                },
              ],
            },
        ],
      });

  static AppState _state(
    AppState app, {
    required DeckDownloads downloads,
    List<String> spoken = const <String>['en'],
    List<String> learning = const <String>[],
  }) => AppState(
    catalog: DeckCatalog(MemoryDeckSource(const <String, String>{})),
    progress: MemoryProgress(),
    tts: const NullTtsEngine(),
    clock: app.now,
    settings: SettingsNotifier(
      spokenLanguages: spoken,
      learningLanguages: learning,
    )..learningChosen = learning.isNotEmpty,
    deckDownloads: downloads,
  );

  static MemoryDownloadedDecks _phone(String index) =>
      MemoryDownloadedDecks()..notes['index.json'] = index;

  /// The first launch of a learner who speaks Bengali and Hindi: Telugu is
  /// taught from both, so it comes first and offers the choice; Kannada is
  /// taught only from English. Nothing is on the phone yet.
  static AppState taughtFromTwo(AppState app) =>
      _taughtFrom(app, const <String>['bn', 'hi']);

  /// As [taughtFromTwo], for a learner who speaks three languages that all
  /// teach Telugu: the most that sit side by side, the widest of them.
  static AppState taughtFromThree(AppState app) =>
      _taughtFrom(app, const <String>['bn', 'hi', 'gu']);

  /// As [taughtFromTwo], for a learner who speaks four languages that all
  /// teach Telugu: too many to sit side by side, so a list in a sheet.
  static AppState taughtFromFour(AppState app) =>
      _taughtFrom(app, const <String>['bn', 'hi', 'gu', 'mr']);

  static AppState _taughtFrom(AppState app, List<String> spoken) {
    final text = index(teluguFrom: spoken);
    return _state(
      app,
      spoken: spoken,
      downloads: _FrozenDownloads(_phone(text), text),
    );
  }

  /// Settings, for a learner of Hindi, Spanish and Telugu: all three on the
  /// phone, the rest not.
  static AppState onPhone(AppState app) {
    final text = index();
    return _state(
      app,
      learning: const <String>['hi', 'es', 'te'],
      downloads: _FrozenDownloads(
        _phone(text),
        text,
        onPhone: const <String>{'hi', 'es', 'te'},
      ),
    );
  }

  /// The first launch with Kannada chosen, its first decks still coming.
  static AppState downloading(AppState app) => _downloading(app, decks: 3);

  /// Kannada's first five decks are in: Continue is on, the rest keeps
  /// coming.
  static AppState ready(AppState app) => _downloading(app, decks: 12);

  /// Kannada's download stopped: no connection.
  static AppState offline(AppState app) =>
      _downloading(app, decks: 3, failure: DeckDownloadFailure.offline);

  /// Kannada's download cancelled after its first decks: the rest waits on
  /// Languages I'm learning.
  static AppState cancelled(AppState app) =>
      _downloading(app, decks: 12, paused: true);

  static AppState _downloading(
    AppState app, {
    required int decks,
    DeckDownloadFailure? failure,
    bool paused = false,
  }) {
    final text = index();
    const total = 52;
    const totalBytes = 287 * 1024;
    final bytes = totalBytes * decks ~/ total;
    return _state(
      app,
      downloads: _FrozenDownloads(
        _phone(text),
        text,
        onPhone: decks >= decksBeforeReady ? const <String>{'kn'} : const {},
        downloading: failure == null && !paused
            ? const <String>{'kn'}
            : const <String>{},
        failures: <String, DeckDownloadFailure>{'kn': ?failure},
        paused: paused ? const <String>{'kn'} : const <String>{},
        progress: <String, LanguageDownload>{
          'kn': (
            decks: decks,
            totalDecks: total,
            bytes: bytes,
            totalBytes: totalBytes,
            readyBytes: totalBytes * 15 ~/ 200,
            ready: decks >= decksBeforeReady,
          ),
        },
      ),
    );
  }
}

/// Deck downloads held still in one state, for the gallery: nothing is
/// fetched, and what each language is doing is as given.
class _FrozenDownloads extends DeckDownloads {
  _FrozenDownloads(
    MemoryDownloadedDecks phone,
    String index, {
    this.onPhone = const <String>{},
    this.downloading = const <String>{},
    this.failures = const <String, DeckDownloadFailure>{},
    this.paused = const <String>{},
    this.progress = const <String, LanguageDownload>{},
  }) : super(
         fetcher: MemoryDeckFetcher(<String, String>{
           'decks/index.json': index,
         }, failure: FetchFailure.offline),
         files: phone,
         clock: DateTime.now,
       );

  final Set<String> onPhone;
  final Set<String> downloading;
  final Map<String, DeckDownloadFailure> failures;
  final Set<String> paused;
  final Map<String, LanguageDownload> progress;

  @override
  Set<String> get languagesOnPhone => onPhone;

  @override
  int sizeOnPhone(String language) => index?.language(language)?.size ?? 0;

  @override
  bool isReady(String language, List<String> spoken) =>
      progress[language]?.ready ?? onPhone.contains(language);

  @override
  bool isDownloading(String language) => downloading.contains(language);

  @override
  bool hasJob(String language) => downloading.contains(language);

  @override
  DeckDownloadFailure? failureOf(String language) => failures[language];

  @override
  bool isPaused(String language) => paused.contains(language);

  @override
  LanguageDownload? languageDownload(String language, List<String> spoken) {
    if (progress[language] case final given?) return given;
    final entry = index?.language(language);
    if (entry == null) return null;
    final whole = onPhone.contains(language);
    return (
      decks: whole ? 52 : 0,
      totalDecks: 52,
      bytes: whole ? entry.size : 0,
      totalBytes: entry.size,
      readyBytes: entry.size * 15 ~/ 200,
      ready: whole,
    );
  }

  @override
  Future<DeckDownloadFailure?> download(
    String language,
    List<String> spoken,
  ) async => null;

  @override
  Future<void> cancel(String language) async {}
}
