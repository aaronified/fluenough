// Downloads real files from GitHub through the app's own fetcher, and checks
// each against decks/index.json's SHA-256. It reaches the network, so it
// runs only with LIVE_GITHUB=1: CI and the release workflow set it, so no
// release goes out unless the app can really download its decks.
//
// 0.4.0 shipped with every download failing: GitHub gzips every file, and
// the fetcher compared the unzipped body with the compressed Content-Length.
// Every other test used a fake GitHub that never compresses.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/sha256.dart';

/// The real client, through the proxy and certificates the environment
/// names, where it names any: none on GitHub's runners.
class _Environment extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final bundle = Platform.environment['SSL_CERT_FILE'];
    final ctx = bundle == null
        ? context
        : (SecurityContext(withTrustedRoots: true)
            ..setTrustedCertificates(bundle));
    return super.createHttpClient(ctx)
      ..findProxy = HttpClient.findProxyFromEnvironment;
  }
}

void main() {
  final live = Platform.environment['LIVE_GITHUB'] == '1';

  test(
    'the app downloads the index and real decks from GitHub',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final fetcher = GitHubDeckFetcher(userAgent: 'fluenough/live-test');
      final index = await fetcher.fetch('decks/index.json');
      expect(index.failure, isNull, reason: 'decks/index.json');
      final json = jsonDecode(utf8.decode(index.bytes!)) as Map;
      final languages = json['languages'] as List;
      expect(languages, isNotEmpty);
      for (final language in languages) {
        final files = (language as Map)['files'] as List;
        for (final file in files.take(3)) {
          final entry = file as Map;
          final path = entry['path'] as String;
          final fetched = await fetcher.fetch(path);
          expect(fetched.failure, isNull, reason: path);
          expect(sha256Hex(fetched.bytes!), entry['sha256'], reason: path);
        }
      }
    }, _Environment()),
    skip: live ? false : 'reaches GitHub; set LIVE_GITHUB=1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
