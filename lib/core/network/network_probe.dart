import 'dart:async';
import 'dart:io';

import '../decks/deck_fetch.dart';

/// Why online speech recognition could not be reached, found by asking two
/// hosts after a `SpeechFailure.network` (owner, 2026-10-29: "Use github and
/// gstatic both. To pinpoint the issue.").
enum NetworkDiagnosis {
  /// Neither host answered: the phone is offline.
  offline,

  /// Google answered, GitHub did not: the app's GitHub access looks blocked
  /// (a firewall or DNS).
  githubBlocked,

  /// GitHub answered, Google did not: Google's servers cannot be reached, so
  /// online speech recognition cannot work.
  googleUnreachable,

  /// Both answered: the recognition service itself failed.
  serviceFailed,
}

/// Finds out why the network failed. Narrow enough that tests fake it; only
/// `main.dart` names the one that reaches the network. Run only after a
/// speech network failure, never in the background.
abstract interface class NetworkProbe {
  /// Never throws.
  Future<NetworkDiagnosis> diagnose();
}

/// Reports the recognition service at fault, without any request: tests and
/// the gallery.
class NullNetworkProbe implements NetworkProbe {
  const NullNetworkProbe();

  @override
  Future<NetworkDiagnosis> diagnose() async => NetworkDiagnosis.serviceFailed;
}

/// A probe that reports what it is told to. For tests and the gallery.
class FixedNetworkProbe implements NetworkProbe {
  FixedNetworkProbe(this.diagnosis);

  NetworkDiagnosis diagnosis;

  /// How many times [diagnose] was called.
  int probes = 0;

  @override
  Future<NetworkDiagnosis> diagnose() async {
    probes++;
    return diagnosis;
  }
}

/// Asks `raw.githubusercontent.com`, where the decks come from, and
/// `connectivitycheck.gstatic.com`, with one HEAD request each through
/// dart:io: no body, no cookies, no headers of ours. They see the phone's IP
/// address and the time.
class SystemNetworkProbe implements NetworkProbe {
  SystemNetworkProbe({
    Uri? github,
    Uri? google,
    this.timeout = const Duration(seconds: 3),
  }) : github = github ?? GitHubDeckFetcher.defaultBase,
       google =
           google ??
           Uri.https('connectivitycheck.gstatic.com', '/generate_204');

  final Uri github;
  final Uri google;
  final Duration timeout;

  @override
  Future<NetworkDiagnosis> diagnose() async {
    final results = await Future.wait(<Future<bool>>[
      _reaches(github, null),
      _reaches(google, HttpStatus.noContent),
    ]);
    final githubOk = results[0];
    final googleOk = results[1];
    if (!githubOk && !googleOk) return NetworkDiagnosis.offline;
    if (googleOk && !githubOk) return NetworkDiagnosis.githubBlocked;
    if (githubOk && !googleOk) return NetworkDiagnosis.googleUnreachable;
    return NetworkDiagnosis.serviceFailed;
  }

  /// Whether [uri] answers within [timeout], with [status] if given, any
  /// answer otherwise.
  Future<bool> _reaches(Uri uri, int? status) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.headUrl(uri).timeout(timeout);
      request.cookies.clear();
      final response = await request.close().timeout(timeout);
      return status == null || response.statusCode == status;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
