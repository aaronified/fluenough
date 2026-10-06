import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'release_check.dart';

/// The newest release on GitHub, from its REST API through dart:io's own
/// client (ADR-0017). No account: GitHub allows 60 requests an hour from one
/// address, and the app asks once a day at most unless the learner taps.
///
/// What GitHub learns is the phone's address, that it asked, and
/// [userAgent]. Nothing else is sent.
class GitHubReleaseCheck implements ReleaseCheckEngine {
  GitHubReleaseCheck({
    required this.userAgent,
    this.timeout = const Duration(seconds: 15),
  });

  /// The newest release that is not a draft or a pre-release.
  static final Uri latestUri = Uri.https(
    'api.github.com',
    '/repos/aaronified/fluenough/releases/latest',
  );

  /// Sent as the User-Agent, which GitHub's API requires: `fluenough/0.3.4`.
  final String userAgent;

  /// How long the whole check may take, from connecting to the last byte.
  final Duration timeout;

  @override
  Future<LatestRelease> latest() async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      return await _ask(client).timeout(timeout);
    } on FormatException {
      // The reply was not UTF-8.
      return const LatestRelease.failed(ReleaseCheckFailure.badReply);
    } catch (_) {
      // No network, no DNS, a refused connection, a failed TLS handshake or
      // the timeout: all of them mean GitHub was not reached.
      return const LatestRelease.failed(ReleaseCheckFailure.offline);
    } finally {
      client.close(force: true);
    }
  }

  Future<LatestRelease> _ask(HttpClient client) async {
    final request = await client.getUrl(latestUri);
    request.headers
      ..set(HttpHeaders.userAgentHeader, userAgent)
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return releaseFromReply(response.statusCode, body);
  }
}
