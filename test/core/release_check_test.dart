import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/updates/github_release_check.dart';
import 'package:fluenough/core/updates/release_check.dart';

/// Answers one request in place of the network: [reply] gives the status and
/// the body's bytes, and never answers if it never completes.
class _FakeClient implements HttpClient {
  _FakeClient(this.reply);

  final Future<(int, List<int>)> Function() reply;
  Uri? asked;
  final Map<String, Object> sent = <String, Object>{};
  bool closed = false;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    asked = url;
    return _FakeRequest(this);
  }

  @override
  void close({bool force = false}) => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.client);

  final _FakeClient client;

  @override
  HttpHeaders get headers => _FakeHeaders(client.sent);

  @override
  Future<HttpClientResponse> close() async {
    final (status, bytes) = await client.reply();
    return _FakeResponse(status, bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHeaders implements HttpHeaders {
  _FakeHeaders(this.sent);

  final Map<String, Object> sent;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      sent[name] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.statusCode, this.bytes);

  @override
  final int statusCode;
  final List<int> bytes;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [check]'s answer, with every HttpClient it makes replaced by [client].
Future<LatestRelease> _ask(GitHubReleaseCheck check, _FakeClient client) =>
    HttpOverrides.runZoned(check.latest, createHttpClient: (_) => client);

void main() {
  group('versions', () {
    test('a tag or a version reads as its numbers', () {
      expect(parseVersion('v0.1.0'), <int>[0, 1, 0]);
      expect(parseVersion('0.2'), <int>[0, 2]);
      expect(parseVersion('V1.10.3'), <int>[1, 10, 3]);
      expect(parseVersion(' v2 '), <int>[2]);
    });

    test('anything but dotted numbers is not a version', () {
      for (final text in <String>[
        '',
        'v',
        'latest',
        'v1.2.x',
        '1..2',
        '.1.2',
        'v0.2.0-beta',
        '1.2.3+4',
        '99999999999999999999.0',
      ]) {
        expect(parseVersion(text), isNull, reason: text);
      }
    });

    test('they compare as numbers, a missing one counting as 0', () {
      int compare(String a, String b) =>
          compareVersions(parseVersion(a)!, parseVersion(b)!).sign;
      expect(compare('0.2', '0.2.0'), 0);
      expect(compare('0.10.0', '0.9.0'), 1, reason: 'not compared as text');
      expect(compare('1.0.0', '0.99.99'), 1);
      expect(compare('0.1.0', '0.1.1'), -1);
      expect(compare('0.1.1', '0.1'), 1);
    });

    test('only a later version is newer', () {
      expect(isNewerVersion('0.2.0', '0.1.0'), isTrue);
      expect(isNewerVersion('v0.1.1', '0.1.0'), isTrue);
      expect(isNewerVersion('0.1.0', '0.1.0'), isFalse);
      expect(isNewerVersion('0.0.9', '0.1.0'), isFalse);
      expect(isNewerVersion(null, '0.1.0'), isFalse);
      expect(isNewerVersion('nightly', '0.1.0'), isFalse);
      expect(isNewerVersion('0.2.0', 'dev'), isFalse);
    });
  });

  group("GitHub's reply", () {
    LatestRelease reply(Object? json, {int status = 200}) =>
        releaseFromReply(status, jsonEncode(json));

    test('a release reads as its tag, without the v', () {
      final release = reply(<String, Object?>{
        'tag_name': 'v0.2.0',
        'name': 'Fluenough 0.2.0',
        'draft': false,
      });
      expect(release.ok, isTrue);
      expect(release.version, '0.2.0');
      expect(release.failure, isNull);
    });

    test("the APK's SHA-256 comes from its asset's digest", () {
      const hex =
          '76DC0A465867B957DFDA3876DFC4AC498E95E69605708253B7C5DF8224EF8A04';
      Map<String, Object?> asset(String name, Object? digest) =>
          <String, Object?>{'name': name, 'digest': digest};
      LatestRelease withAssets(List<Object?> assets) =>
          reply(<String, Object?>{'tag_name': 'v0.2.0', 'assets': assets});

      expect(
        withAssets(<Object?>[
          asset('notes.txt', 'sha256:${'0' * 64}'),
          asset('app-release.apk', 'sha256:$hex'),
        ]).apkSha256,
        hex.toLowerCase(),
      );
      // None, or one that is not a SHA-256: download without a check.
      for (final assets in <List<Object?>>[
        <Object?>[],
        <Object?>[asset('app-release.apk', null)],
        <Object?>[asset('app-release.apk', 'md5:${'0' * 32}')],
        <Object?>[asset('app-release.apk', 'sha256:${'0' * 63}')],
        <Object?>[asset('app-debug.apk', 'sha256:$hex')],
        <Object?>['app-release.apk'],
      ]) {
        final release = withAssets(assets);
        expect(release.version, '0.2.0', reason: '$assets');
        expect(release.apkSha256, isNull, reason: '$assets');
      }
      expect(reply(<String, Object?>{'tag_name': 'v0.2.0'}).apkSha256, isNull);
      expect(
        reply(<String, Object?>{
          'tag_name': 'v0.2.0',
          'assets': 'app-release.apk',
        }).apkSha256,
        isNull,
      );
    });

    test('a missing, empty or unreadable tag is a bad reply', () {
      for (final json in <Object?>[
        <String, Object?>{'name': 'v0.2.0'},
        <String, Object?>{'tag_name': null},
        <String, Object?>{'tag_name': ''},
        <String, Object?>{'tag_name': 2},
        <String, Object?>{'tag_name': 'nightly'},
        <String, Object?>{'tag_name': 'v0.2.0-rc1'},
        <Object?>['v0.2.0'],
        'v0.2.0',
        null,
      ]) {
        final release = reply(json);
        expect(release.ok, isFalse, reason: '$json');
        expect(release.failure, ReleaseCheckFailure.badReply, reason: '$json');
      }
      expect(
        releaseFromReply(200, '<html>Unicorn!</html>').failure,
        ReleaseCheckFailure.badReply,
      );
      expect(releaseFromReply(200, '').failure, ReleaseCheckFailure.badReply);
    });

    test('403 and 429 are the rate limit; any other error is a bad reply', () {
      final message = <String, Object?>{'message': 'API rate limit exceeded'};
      expect(
        reply(message, status: 403).failure,
        ReleaseCheckFailure.rateLimited,
      );
      expect(
        reply(message, status: 429).failure,
        ReleaseCheckFailure.rateLimited,
      );
      for (final status in <int>[404, 500, 502, 301]) {
        expect(
          reply(<String, Object?>{
            'tag_name': 'v9.0.0',
          }, status: status).failure,
          ReleaseCheckFailure.badReply,
          reason: '$status',
        );
      }
    });
  });

  group('the GitHub check, on a fake client', () {
    final check = GitHubReleaseCheck(
      userAgent: 'fluenough/0.1.0',
      timeout: const Duration(milliseconds: 50),
    );

    test('asks for the latest release, saying who asks', () async {
      final client = _FakeClient(
        () async => (200, utf8.encode('{"tag_name": "v0.3.1"}')),
      );
      final release = await _ask(check, client);
      expect(release.version, '0.3.1');
      expect(
        client.asked,
        Uri.parse(
          'https://api.github.com/repos/aaronified/fluenough/releases/latest',
        ),
      );
      expect(client.sent[HttpHeaders.userAgentHeader], 'fluenough/0.1.0');
      expect(
        client.sent[HttpHeaders.acceptHeader],
        'application/vnd.github+json',
      );
      expect(client.connectionTimeout, check.timeout);
      expect(client.closed, isTrue);
    });

    test('the rate limit, and a reply that is not UTF-8', () async {
      expect(
        (await _ask(check, _FakeClient(() async => (403, <int>[])))).failure,
        ReleaseCheckFailure.rateLimited,
      );
      expect(
        (await _ask(
          check,
          _FakeClient(() async => (200, <int>[0xff, 0xfe, 0x7b])),
        )).failure,
        ReleaseCheckFailure.badReply,
      );
    });

    test('no network, or no answer in time, is offline', () async {
      final refused = _FakeClient(
        () async => throw const SocketException('Failed host lookup'),
      );
      expect((await _ask(check, refused)).failure, ReleaseCheckFailure.offline);

      final silent = _FakeClient(() => Completer<(int, List<int>)>().future);
      expect((await _ask(check, silent)).failure, ReleaseCheckFailure.offline);
      expect(silent.closed, isTrue, reason: 'the connection is dropped');
    });
  });

  test('the fixed check answers what it is told, after its gate', () async {
    final gate = Completer<void>();
    final fixed = FixedReleaseCheck(const LatestRelease('1.0.0'), gate: gate);
    var answered = false;
    final answer = fixed.latest().then((r) {
      answered = true;
      return r;
    });
    await Future<void>.delayed(Duration.zero);
    expect(answered, isFalse);
    gate.complete();
    expect((await answer).version, '1.0.0');
    expect(fixed.checks, 1);
    expect(
      (await const NullReleaseCheck().latest()).failure,
      ReleaseCheckFailure.offline,
    );
  });
}
