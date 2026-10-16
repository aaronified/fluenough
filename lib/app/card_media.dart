import 'dart:io';

import '../core/decks/deck_index.dart';

/// Where a card's own recording or image is on the phone (#518, #523): the
/// files downloaded with its deck ([DownloadedDecks]).
abstract interface class CardMedia {
  /// The file on the phone that [path] names, as a card names it
  /// (`decks/hi/audio/hi-0001.opus`), or null when it is not there.
  String? localPath(String path);
}

/// No files: every card is spoken by the phone's voice, and shows its
/// emoji picture, if any.
class NoCardMedia implements CardMedia {
  const NoCardMedia();

  @override
  String? localPath(String path) => null;
}

/// The files of a checkout of the repository, under [root]: for tests and
/// the gallery, which read the repository's decks.
class RepositoryCardMedia implements CardMedia {
  const RepositoryCardMedia([this.root = '.']);

  final String root;

  @override
  String? localPath(String path) {
    if (!mediaPathPattern.hasMatch(path)) return null;
    final file = File('$root/$path');
    return file.existsSync() ? file.path : null;
  }
}
