import 'deck_catalog.dart';

/// The deck-owned files downloaded from `decks-live` (owner, 2026-11-11),
/// such as the theme list, as a [DeckSource] listed before the bundled one:
/// [DeckSources] reads a path from the first source that lists it, so a file
/// downloaded replaces the app's bundled copy, and one that was never
/// downloaded, or did not pass its checks, leaves the bundled copy in use.
class SharedDeckSource implements DeckSource {
  /// [texts] gives the files held now, by path; read on every call, so that
  /// a file downloaded after the app started is seen by the next catalog
  /// read.
  SharedDeckSource(this.texts);

  final Map<String, String> Function() texts;

  @override
  Future<List<String>> list() async => texts().keys.toList()..sort();

  @override
  Future<String> read(String path) async =>
      texts()[path] ?? (throw StateError('no deck file at $path'));
}
