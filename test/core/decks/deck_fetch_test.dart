import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/decks/deck_fetch.dart';

import '../../support/fake_http.dart';

void main() {
  final fetcher = GitHubDeckFetcher(userAgent: 'fluenough/test');

  Future<(Fetched, FakeHttpClient)> fetch(
    Future<(int, List<int>)> Function() reply, {
    int? claims,
  }) async {
    final client = FakeHttpClient(reply)..contentLength = claims;
    final fetched = await withFakeClient(
      client,
      () => fetcher.fetch('decks/hi/hi-path.yaml'),
    );
    return (fetched, client);
  }

  test('downloads a file from main, with no token', () async {
    final (fetched, client) = await fetch(
      () async => (200, utf8.encode('kind: path\n')),
    );
    expect(utf8.decode(fetched.bytes!), 'kind: path\n');
    expect(
      client.asked.toString(),
      'https://raw.githubusercontent.com/aaronified/fluenough/main/'
      'decks/hi/hi-path.yaml',
    );
    expect(client.sent[HttpHeaders.userAgentHeader], 'fluenough/test');
    expect(client.sent.keys, isNot(contains(HttpHeaders.authorizationHeader)));
    expect(client.closed, isTrue);
  });

  test('says when GitHub limits it', () async {
    for (final status in <int>[403, 429]) {
      final (fetched, _) = await fetch(() async => (status, <int>[]));
      expect(fetched.failure, FetchFailure.rateLimited, reason: '$status');
    }
  });

  test('says when a file is gone', () async {
    final (fetched, _) = await fetch(() async => (404, <int>[]));
    expect(fetched.failure, FetchFailure.notFound);
  });

  test('says when GitHub answers with an error', () async {
    final (fetched, _) = await fetch(() async => (500, <int>[]));
    expect(fetched.failure, FetchFailure.badReply);
  });

  test('says so with no network', () async {
    final (fetched, client) = await fetch(
      () async => throw const SocketException('Failed host lookup'),
    );
    expect(fetched.failure, FetchFailure.offline);
    expect(client.closed, isTrue);
  });

  test('a body cut short is a broken connection, not a file', () async {
    final (fetched, _) = await fetch(
      () async => (200, utf8.encode('kind: pa')),
      claims: 20,
    );
    expect(fetched.failure, FetchFailure.offline);
  });

  test('refuses a file too large to be a deck', () async {
    final small = GitHubDeckFetcher(userAgent: 'fluenough/test', maxBytes: 4);
    final client = FakeHttpClient(() async => (200, utf8.encode('12345')));
    final fetched = await withFakeClient(
      client,
      () => small.fetch('decks/hi/hi-path.yaml'),
    );
    expect(fetched.failure, FetchFailure.badReply);
  });

  test('the null fetcher never reaches the network', () async {
    expect(
      (await const NullDeckFetcher().fetch('decks/index.json')).failure,
      FetchFailure.offline,
    );
  });
}
