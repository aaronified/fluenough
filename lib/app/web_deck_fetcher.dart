import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/decks/deck_fetch.dart';

/// The decks on GitHub, fetched by the browser: `GitHubDeckFetcher` reads
/// them through dart:io's client, which a browser does not have.
/// `raw.githubusercontent.com` answers with `access-control-allow-origin: *`,
/// so a page on github.io may read it. A dropped connection is retried as
/// `GitHubDeckFetcher` does; the browser sets the User-Agent itself.
class WebDeckFetcher implements DeckFetcher {
  WebDeckFetcher({
    http.Client? client,
    Uri? base,
    this.timeout = const Duration(minutes: 2),
    this.maxBytes = 32 * 1024 * 1024,
    this.retryDelays = const <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 9),
    ],
  }) : _client = client ?? http.Client(),
       base = base ?? GitHubDeckFetcher.defaultBase;

  final http.Client _client;
  final Uri base;
  final Duration timeout;
  final int maxBytes;
  final List<Duration> retryDelays;

  @override
  Future<Fetched> fetch(String path) async {
    var fetched = await _fetchOnce(path);
    for (final wait in retryDelays) {
      if (fetched.failure != FetchFailure.offline) break;
      await Future<void>.delayed(wait);
      fetched = await _fetchOnce(path);
    }
    return fetched;
  }

  Future<Fetched> _fetchOnce(String path) async {
    try {
      final response = await _client.get(base.resolve(path)).timeout(timeout);
      if (response.statusCode != 200) {
        return Fetched.failed(
          GitHubDeckFetcher.failureFor(response.statusCode),
        );
      }
      if (response.bodyBytes.length > maxBytes) {
        return const Fetched.failed(FetchFailure.badReply);
      }
      return Fetched(Uint8List.fromList(response.bodyBytes));
    } catch (e) {
      return Fetched.failed(
        FetchFailure.offline,
        cause: e.runtimeType.toString(),
      );
    }
  }
}
