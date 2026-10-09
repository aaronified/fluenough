import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Why a file could not be downloaded (ADR-0037).
enum FetchFailure {
  /// GitHub could not be reached, or the connection broke part-way: no
  /// network, or one that goes nowhere.
  offline,

  /// GitHub refused for now: too many requests from this network.
  rateLimited,

  /// GitHub has no such file: it was removed after the index was read.
  notFound,

  /// GitHub answered with something that is not the file: an error, a
  /// file too large, or one that does not match the index's hash.
  badReply,
}

/// A downloaded file's bytes, or why there are none.
class Fetched {
  const Fetched(Uint8List this.bytes) : failure = null;

  const Fetched.failed(FetchFailure this.failure) : bytes = null;

  final Uint8List? bytes;
  final FetchFailure? failure;

  bool get ok => bytes != null;
}

/// Where the decks come from: the repository's `main` branch, path by path,
/// `decks/index.json` first. Narrow enough that tests fake it; only
/// `main.dart` names the one that reaches GitHub.
abstract interface class DeckFetcher {
  /// Downloads [path], such as `decks/index.json`. Never throws: a failure
  /// is a [Fetched.failed].
  Future<Fetched> fetch(String path);
}

/// No network: every download fails as [FetchFailure.offline]. The
/// default, so that no test or gallery state reaches GitHub.
class NullDeckFetcher implements DeckFetcher {
  const NullDeckFetcher();

  @override
  Future<Fetched> fetch(String path) async =>
      const Fetched.failed(FetchFailure.offline);
}

/// The decks on GitHub, from `raw.githubusercontent.com` through dart:io's
/// own client, as the update check reaches GitHub (ADR-0017). No account
/// and no token.
///
/// What GitHub learns is the phone's address, which files it asked for, and
/// [userAgent]. Nothing else is sent.
class GitHubDeckFetcher implements DeckFetcher {
  GitHubDeckFetcher({
    required this.userAgent,
    Uri? base,
    this.timeout = const Duration(seconds: 30),
    this.maxBytes = 8 * 1024 * 1024,
  }) : base = base ?? defaultBase;

  /// The repository's `main` branch, which the app downloads its decks
  /// from: the latest decks, not those of the app's release (ADR-0037).
  static final Uri defaultBase = Uri.https(
    'raw.githubusercontent.com',
    '/aaronified/fluenough/main/',
  );

  final Uri base;

  /// Sent as the User-Agent: `fluenough/0.3.4`.
  final String userAgent;

  /// How long one file may take, from connecting to the last byte.
  final Duration timeout;

  /// The most a file may be. The largest deck is far under it; more is
  /// not a deck.
  final int maxBytes;

  @override
  Future<Fetched> fetch(String path) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      return await _get(client, base.resolve(path)).timeout(timeout);
    } on _TooLarge {
      return const Fetched.failed(FetchFailure.badReply);
    } catch (_) {
      // No network, no DNS, a refused connection, a failed TLS handshake,
      // the connection closing part-way, or the timeout: GitHub was not
      // reached, or not all the way.
      return const Fetched.failed(FetchFailure.offline);
    } finally {
      client.close(force: true);
    }
  }

  Future<Fetched> _get(HttpClient client, Uri uri) async {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, userAgent);
    final response = await request.close();
    final status = response.statusCode;
    if (status != HttpStatus.ok) {
      // Drain, so the connection closes cleanly.
      await response.drain<void>().catchError((_) {});
      return Fetched.failed(failureFor(status));
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      bytes.add(chunk);
      if (bytes.length > maxBytes) throw const _TooLarge();
    }
    final expected = response.contentLength;
    // A body cut short of what the server said is a broken connection.
    if (expected >= 0 && bytes.length != expected) {
      return const Fetched.failed(FetchFailure.offline);
    }
    return Fetched(bytes.takeBytes());
  }

  /// What an HTTP [status] other than 200 means here. GitHub answers 429,
  /// and sometimes 403, when one address asks too often.
  static FetchFailure failureFor(int status) => switch (status) {
    HttpStatus.notFound => FetchFailure.notFound,
    HttpStatus.tooManyRequests ||
    HttpStatus.forbidden => FetchFailure.rateLimited,
    _ => FetchFailure.badReply,
  };
}

class _TooLarge implements Exception {
  const _TooLarge();
}
