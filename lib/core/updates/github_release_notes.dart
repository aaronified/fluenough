import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'release_check.dart';
import 'release_notes.dart';

/// The app's recent releases on GitHub, from its REST API through dart:io's
/// own client, as [GitHubReleaseCheck] asks for the newest one (ADR-0017,
/// ADR-0031). No account: GitHub allows 60 requests an hour from one
/// address, and the app asks only when the learner opens "What's new".
///
/// What GitHub learns is the phone's address, that it asked, and
/// [userAgent]. Nothing else is sent.
class GitHubReleaseNotes implements ReleaseNotesEngine {
  GitHubReleaseNotes({
    required this.userAgent,
    this.timeout = const Duration(seconds: 15),
  });

  /// The 20 newest releases, drafts and pre-releases included: they are left
  /// out when the reply is read.
  static final Uri releasesUri = Uri.https(
    'api.github.com',
    '/repos/aaronified/fluenough/releases',
    <String, String>{'per_page': '20'},
  );

  /// Sent as the User-Agent, which GitHub's API requires: `fluenough/0.3.4`.
  final String userAgent;

  /// How long the whole fetch may take, from connecting to the last byte.
  final Duration timeout;

  @override
  Future<ReleaseNotes> fetch() async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      return await _ask(client).timeout(timeout);
    } on FormatException {
      // The reply was not UTF-8.
      return const ReleaseNotes.failed(ReleaseCheckFailure.badReply);
    } catch (_) {
      // No network, no DNS, a refused connection, a failed TLS handshake or
      // the timeout: all of them mean GitHub was not reached.
      return const ReleaseNotes.failed(ReleaseCheckFailure.offline);
    } finally {
      client.close(force: true);
    }
  }

  Future<ReleaseNotes> _ask(HttpClient client) async {
    final request = await client.getUrl(releasesUri);
    request.headers
      ..set(HttpHeaders.userAgentHeader, userAgent)
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return releaseNotesFromReply(response.statusCode, body);
  }
}
