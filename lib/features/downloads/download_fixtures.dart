import 'dart:convert';

import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/deck_downloads.dart';
import '../../app/downloaded_decks.dart';
import '../../app/memory_progress.dart';
import '../../app/settings.dart';
import '../../core/decks/deck_fetch.dart';
import '../../core/decks/deck_index.dart';
import '../../core/decks/sha256.dart';
import '../../core/tts/tts_engine.dart';

/// Deck downloads in the gallery (#210): a GitHub held in memory, and a
/// phone with some of it. The files are stand-ins, never parsed: the pages
/// shown read only what the index and the phone say of them.
abstract final class DownloadFixtures {
  /// Hindi and Telugu, which the phone has, and Spanish, which it has not.
  /// Hindi's family deck has changed since the phone downloaded it.
  static final Map<String, String> _github = <String, String>{
    'decks/hi/hi-path.yaml': 'kind: path # v1\n',
    'decks/hi/hi-en-family.yaml': 'kind: vocab # v2\n',
    'decks/te/te-path.yaml': 'kind: path # v1\n',
    'decks/te/te-en-family.yaml': 'kind: vocab # v1\n',
    'decks/es/es-path.yaml': 'kind: path # v1\n',
    'decks/es/es-en-core-100.yaml': 'kind: vocab # v1\n',
  };

  static const Map<String, String> _names = <String, String>{
    'hi': 'Hindi', // ui-literal-ok: debug-only gallery
    'te': 'Telugu', // ui-literal-ok: debug-only gallery
    'es': 'Spanish', // ui-literal-ok: debug-only gallery
  };

  static IndexFile _file(String path, String text) {
    final bytes = utf8.encode(text);
    final name = path.split('/').last.replaceAll('.yaml', '');
    final parts = name.split('-');
    final deck = name.endsWith('-path')
        ? null
        : '${parts.first}-${parts.sublist(2).join('-')}';
    return IndexFile(
      path: path,
      size: bytes.length * 3000,
      sha256: sha256Hex(bytes),
      kind: deck == null ? 'path' : 'vocab',
      native: deck == null ? null : 'en',
      deck: deck,
    );
  }

  static String _index() => jsonEncode(<String, Object?>{
    'version': supportedIndexVersion,
    'languages': <Object?>[
      for (final code in _names.keys)
        <String, Object?>{
          'code': code,
          'name': _names[code],
          'natives': <Object?>[
            <String, String>{'code': 'en', 'name': 'English'},
          ],
          'files': <Object?>[
            for (final MapEntry(key: path, value: text) in _github.entries)
              if (path.startsWith('decks/$code/')) _file(path, text).toJson(),
          ],
        },
    ],
  });

  static AppState _state(
    AppState app, {
    required MemoryDownloadedDecks phone,
    required DeckFetcher fetcher,
    required List<String> learning,
  }) => AppState(
    catalog: DeckCatalog(MemoryDeckSource(const <String, String>{})),
    progress: MemoryProgress(),
    tts: const NullTtsEngine(),
    clock: app.now,
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: learning,
    )..learningChosen = true,
    deckDownloads: DeckDownloads(
      fetcher: fetcher,
      files: phone,
      clock: app.now,
    ),
  );

  /// Languages I'm learning, the day after the last check: Hindi has an
  /// update waiting, Telugu is up to date.
  static AppState updateWaiting(AppState app) {
    final github = <String, String>{..._github, 'decks/index.json': _index()};
    final phone = MemoryDownloadedDecks(<IndexFile, String>{
      for (final MapEntry(key: path, value: text) in _github.entries)
        if (!path.startsWith('decks/es/'))
          _file(path, text.replaceAll('# v2', '# v1')): text.replaceAll(
            '# v2',
            '# v1',
          ),
    });
    phone.notes['index.json'] = github['decks/index.json']!;
    phone.notes['state.json'] = jsonEncode(<String, Object?>{
      'checked': app.now().subtract(const Duration(days: 2)).toIso8601String(),
      'complete': <String>['hi', 'te'],
    });
    return _state(
      app,
      phone: phone,
      fetcher: MemoryDeckFetcher(github),
      learning: const <String>['hi', 'te'],
    );
  }

  /// The first decks of Spanish, with no network: the page says so and
  /// offers Try again.
  static AppState offline(AppState app) => _state(
    app,
    phone: MemoryDownloadedDecks(),
    fetcher: MemoryDeckFetcher(<String, String>{
      ..._github,
      'decks/index.json': _index(),
    }, failure: FetchFailure.offline),
    learning: const <String>['es'],
  );
}
