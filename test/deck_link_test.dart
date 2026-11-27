// Adding a deck from a link (#22): reading the address, and downloading the
// file with a fake HTTP client, so that no test reaches the network.

import 'dart:async';

import 'package:fluenough/core/decks/deck_link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.StreamedResponse _reply(
  int status,
  List<int> body, {
  Map<String, String> headers = const <String, String>{},
}) {
  return http.StreamedResponse(
    Stream<List<int>>.value(body),
    status,
    headers: headers,
    contentLength: body.length,
  );
}

http.StreamedResponse _redirect(String to) {
  final headers = <String, String>{'location': to};
  return _reply(302, const <int>[], headers: headers);
}

/// A fetcher whose client answers each request with [answer], and records
/// the addresses asked for in [asked].
HttpDeckLinkFetcher _fetcher(
  List<Uri> asked,
  Future<http.StreamedResponse> Function(http.BaseRequest request) answer, {
  Duration timeout = const Duration(seconds: 5),
  int maxBytes = 1024,
  int maxRedirects = 5,
}) {
  final client = MockClient.streaming((request, body) {
    asked.add(request.url);
    return answer(request);
  });
  return HttpDeckLinkFetcher(
    client: client,
    timeout: timeout,
    maxBytes: maxBytes,
    maxRedirects: maxRedirects,
  );
}

void main() {
  group('parseDeckLink', () {
    test('accepts an https address, trimmed', () {
      final parsed = parseDeckLink('  https://example.org/a/deck.yaml \n');
      expect(parsed.failure, isNull);
      expect('${parsed.uri}', 'https://example.org/a/deck.yaml');
    });

    test('refuses http, saying why', () {
      final parsed = parseDeckLink('http://example.org/deck.yaml');
      expect(parsed.uri, isNull);
      expect(parsed.failure, LinkFailure.notHttps);
    });

    test('refuses what is not a web address', () {
      for (final input in <String>[
        '',
        '   ',
        'example.org/deck.yaml',
        'javascript:alert(1)',
        'mailto:someone@example.org',
        'ftp://example.org/deck.yaml',
        'file:///sdcard/deck.yaml',
        'https://user:secret@example.org/deck.yaml',
      ]) {
        final parsed = parseDeckLink(input);
        expect(parsed.uri, isNull, reason: input);
        expect(parsed.failure, LinkFailure.notALink, reason: input);
      }
    });

    test('turns a GitHub file page into the raw file', () {
      final page = parseDeckLink('https://github.com/o/r/blob/main/d/x.yaml');
      const file = 'https://raw.githubusercontent.com/o/r/main/d/x.yaml';
      expect('${page.uri}', file);
      // A raw link is left as it is.
      const raw = 'https://raw.githubusercontent.com/o/r/main/x.yaml';
      expect('${parseDeckLink(raw).uri}', raw);
    });

    test('names a deck by the last part of its path, or its host', () {
      expect(deckLinkName(Uri.parse('https://x.org/a/b.yaml')), 'b.yaml');
      expect(deckLinkName(Uri.parse('https://x.org/')), 'x.org');
    });
  });

  group('HttpDeckLinkFetcher', () {
    test('downloads the text, asking once and following nothing', () async {
      final asked = <Uri>[];
      var followed = true;
      final fetcher = _fetcher(asked, (request) async {
        followed = request.followRedirects;
        return _reply(200, 'schema: 1\n'.codeUnits);
      });
      final got = await fetcher.fetch(Uri.parse('https://a.org/d.yaml'));
      expect(got.failure, isNull);
      expect(got.text, 'schema: 1\n');
      expect(asked.map((u) => '$u'), <String>['https://a.org/d.yaml']);
      expect(followed, isFalse);
    });

    test('drops a leading byte-order mark', () async {
      final fetcher = _fetcher(
        <Uri>[],
        (request) async => _reply(200, <int>[0xEF, 0xBB, 0xBF, 0x61]),
      );
      final got = await fetcher.fetch(Uri.parse('https://a.org/d.yaml'));
      expect(got.text, 'a');
    });

    test('says what each failing status means', () async {
      final expected = <int, LinkFailure>{
        404: LinkFailure.notFound,
        410: LinkFailure.notFound,
        401: LinkFailure.refused,
        403: LinkFailure.refused,
        429: LinkFailure.refused,
        500: LinkFailure.badReply,
        204: LinkFailure.badReply,
      };
      for (final entry in expected.entries) {
        final fetcher = _fetcher(
          <Uri>[],
          (request) async => _reply(entry.key, 'x'.codeUnits),
        );
        final got = await fetcher.fetch(Uri.parse('https://a.org/d.yaml'));
        expect(got.text, isNull, reason: '${entry.key}');
        expect(got.failure, entry.value, reason: '${entry.key}');
      }
    });

    test('never asks for an address that is not https', () async {
      final asked = <Uri>[];
      final fetcher = _fetcher(asked, (request) async => _reply(200, [97]));
      final got = await fetcher.fetch(Uri.parse('http://a.org/d.yaml'));
      expect(got.failure, LinkFailure.notHttps);
      expect(asked, isEmpty);
    });

    test('follows a redirect that stays on https', () async {
      final asked = <Uri>[];
      final fetcher = _fetcher(asked, (request) async {
        return switch (request.url.path) {
          '/start' => _redirect('https://b.org/next'),
          '/next' => _redirect('/final.yaml'),
          _ => _reply(200, 'ok'.codeUnits),
        };
      });
      final got = await fetcher.fetch(Uri.parse('https://a.org/start'));
      expect(got.text, 'ok');
      expect(asked.map((u) => '$u'), <String>[
        'https://a.org/start',
        'https://b.org/next',
        'https://b.org/final.yaml',
      ]);
    });

    test('refuses a redirect to http, and asks no further', () async {
      final asked = <Uri>[];
      final fetcher = _fetcher(
        asked,
        (request) async => _redirect('http://b.org/d.yaml'),
      );
      final got = await fetcher.fetch(Uri.parse('https://a.org/d.yaml'));
      expect(got.failure, LinkFailure.notHttps);
      expect(asked, hasLength(1));
    });

    test('gives up on a redirect loop or a redirect to nowhere', () async {
      final asked = <Uri>[];
      final loop = _fetcher(
        asked,
        (request) async => _redirect('https://a.org/d.yaml'),
        maxRedirects: 2,
      );
      final got = await loop.fetch(Uri.parse('https://a.org/d.yaml'));
      expect(got.failure, LinkFailure.badReply);
      expect(asked, hasLength(3));

      final nowhere = _fetcher(
        <Uri>[],
        (request) async => _reply(302, const <int>[]),
      );
      final none = await nowhere.fetch(Uri.parse('https://a.org/d.yaml'));
      expect(none.failure, LinkFailure.badReply);
    });

    test('refuses a file larger than a deck may be', () async {
      // By what the reply says it is.
      final claimed = _fetcher(
        <Uri>[],
        (request) async => _reply(200, List<int>.filled(20, 97)),
        maxBytes: 10,
      );
      final byClaim = await claimed.fetch(Uri.parse('https://a.org/d.yaml'));
      expect(byClaim.failure, LinkFailure.tooLarge);
      // By what arrives, when it does not say.
      final streamed = _fetcher(
        <Uri>[],
        (request) async => http.StreamedResponse(
          Stream<List<int>>.fromIterable(<List<int>>[
            List<int>.filled(6, 97),
            List<int>.filled(6, 97),
          ]),
          200,
        ),
        maxBytes: 10,
      );
      final byBody = await streamed.fetch(Uri.parse('https://a.org/d.yaml'));
      expect(byBody.failure, LinkFailure.tooLarge);
    });

    test('refuses a file that is not text', () async {
      final fetcher = _fetcher(
        <Uri>[],
        (request) async => _reply(200, <int>[0xFF, 0xFE, 0xFD]),
      );
      final got = await fetcher.fetch(Uri.parse('https://a.org/d.yaml'));
      expect(got.failure, LinkFailure.notText);
    });

    test('a broken connection is offline, keeping the cause', () async {
      final fetcher = _fetcher(
        <Uri>[],
        (request) async => throw http.ClientException('down'),
      );
      final got = await fetcher.fetch(Uri.parse('https://a.org/d.yaml'));
      expect(got.failure, LinkFailure.offline);
      expect(got.cause, 'ClientException');
    });

    test('an unanswered request is offline after the timeout', () async {
      final never = Completer<http.StreamedResponse>();
      final fetcher = _fetcher(
        <Uri>[],
        (request) => never.future,
        timeout: const Duration(milliseconds: 20),
      );
      final got = await fetcher.fetch(Uri.parse('https://a.org/d.yaml'));
      expect(got.failure, LinkFailure.offline);
      expect(got.cause, 'TimeoutException');
    });
  });
}
