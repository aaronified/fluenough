import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/updates/github_release_notes.dart';
import 'package:fluenough/core/updates/release_check.dart';
import 'package:fluenough/core/updates/release_notes.dart';

import '../support/fake_http.dart';

const String _boiler =
    'Fluenough is GPL-3.0 with an App Store Distribution Exception.\n'
    'Source for this exact build is the tag it was made from.';

/// A release as GitHub lists it.
Map<String, Object?> _release(
  String tag, {
  String? published = '2026-10-05T19:25:08Z',
  Object? body = '',
  Object? draft = false,
  Object? prerelease = false,
}) => <String, Object?>{
  'tag_name': tag,
  'name': tag,
  'draft': draft,
  'prerelease': prerelease,
  'published_at': published,
  'body': body,
  'assets': <Object?>[],
};

ReleaseNotes _reply(Object? json, {int status = 200}) =>
    releaseNotesFromReply(status, jsonEncode(json));

List<String> _tags(ReleaseNotes notes) => <String>[
  for (final release in notes.releases) release.tag,
];

void main() {
  group("GitHub's reply", () {
    test('a release reads as its tag, date and notes', () {
      final notes = _reply(<Object?>[
        _release('v0.3.3', body: '$_boiler\n\n\n## What\'s Changed\n* A thing'),
      ]);
      expect(notes.ok, isTrue);
      expect(notes.failure, isNull);
      final release = notes.releases.single;
      expect(release.tag, 'v0.3.3');
      expect(release.publishedAt, DateTime.utc(2026, 10, 5, 19, 25, 8));
      expect(release.body, "## What's Changed\n* A thing");
    });

    test('they keep the order GitHub gave, newest first', () {
      // Not sorted by version, nor by date: GitHub's order is the answer.
      final notes = _reply(<Object?>[
        _release('v0.3.1', published: '2026-10-04T16:08:26Z'),
        _release('v0.10.0', published: '2026-10-01T10:00:00Z'),
        _release('v0.3.2', published: '2026-10-05T04:48:21Z'),
      ]);
      expect(_tags(notes), <String>['v0.3.1', 'v0.10.0', 'v0.3.2']);
    });

    test('drafts and pre-releases are skipped', () {
      final notes = _reply(<Object?>[
        _release('v0.4.0', draft: true),
        _release('v0.3.4-rc1', prerelease: true),
        _release('v0.3.3'),
        _release('v0.3.3-beta', draft: true, prerelease: true),
        _release('v0.3.2'),
      ]);
      expect(_tags(notes), <String>['v0.3.3', 'v0.3.2']);
    });

    test('a list of nothing but drafts is an answer, with nothing in it', () {
      final notes = _reply(<Object?>[_release('v0.4.0', draft: true)]);
      expect(notes.ok, isTrue);
      expect(notes.releases, isEmpty);
      expect(_reply(<Object?>[]).ok, isTrue);
      expect(_reply(<Object?>[]).releases, isEmpty);
    });

    test('a release needs only its tag', () {
      final notes = _reply(<Object?>[
        <String, Object?>{'tag_name': 'v0.1.0'},
        _release('v0.0.9', published: null, body: null),
        _release('v0.0.8', published: 'yesterday', body: 42),
        _release('v0.0.7', published: '', draft: null, prerelease: null),
      ]);
      expect(_tags(notes), <String>['v0.1.0', 'v0.0.9', 'v0.0.8', 'v0.0.7']);
      for (final release in notes.releases) {
        expect(release.publishedAt, isNull, reason: release.tag);
        expect(release.body, '', reason: release.tag);
      }
    });

    test('a tag is kept as GitHub has it, trimmed', () {
      expect(_tags(_reply(<Object?>[_release(' v0.3.3 ')])), <String>[
        'v0.3.3',
      ]);
    });

    test('an entry that is not a release is left out', () {
      final notes = _reply(<Object?>[
        1,
        'v0.9.0',
        null,
        <Object?>[],
        <String, Object?>{'name': 'no tag'},
        <String, Object?>{'tag_name': 7},
        <String, Object?>{'tag_name': '  '},
        _release('v0.3.3'),
      ]);
      expect(_tags(notes), <String>['v0.3.3']);
    });

    test('a list with entries but not one readable release is a bad reply', () {
      for (final json in <Object?>[
        <Object?>[1, 2],
        <Object?>[
          <String, Object?>{'name': 'x'},
        ],
      ]) {
        expect(
          _reply(json).failure,
          ReleaseCheckFailure.badReply,
          reason: '$json',
        );
      }
    });

    test('bad JSON is a failure, not a throw', () {
      for (final body in <String>[
        '',
        'not json',
        '<html>Unicorn!</html>',
        '[{"tag_name": "v1.0.0"',
        'null',
        '42',
        '"v1.0.0"',
        '{"tag_name": "v1.0.0"}',
        '{"message": "Not Found"}',
      ]) {
        final notes = releaseNotesFromReply(200, body);
        expect(notes.ok, isFalse, reason: body);
        expect(notes.failure, ReleaseCheckFailure.badReply, reason: body);
        expect(notes.releases, isEmpty, reason: body);
      }
    });

    test('403 and 429 are the rate limit; any other error is a bad reply', () {
      final message = <String, Object?>{'message': 'API rate limit exceeded'};
      for (final status in <int>[403, 429]) {
        expect(
          _reply(message, status: status).failure,
          ReleaseCheckFailure.rateLimited,
          reason: '$status',
        );
      }
      for (final status in <int>[404, 500, 502, 301, 304]) {
        expect(
          _reply(<Object?>[_release('v0.3.3')], status: status).failure,
          ReleaseCheckFailure.badReply,
          reason: '$status',
        );
      }
    });
  });

  group('which release is a version', () {
    bool tagIs(String tag, String version) =>
        PublishedRelease(tag: tag).isVersion(version);

    test('the same numbers, with or without the v', () {
      expect(tagIs('v0.3.3', '0.3.3'), isTrue);
      expect(tagIs('0.3.3', '0.3.3'), isTrue);
      expect(tagIs('v0.3', '0.3.0'), isTrue);
      expect(tagIs('v0.3.2', '0.3.3'), isFalse);
      expect(tagIs('v0.3.30', '0.3.3'), isFalse);
    });

    test('a tag that is not a version is no version', () {
      expect(tagIs('nightly', '0.3.3'), isFalse);
      expect(tagIs('v0.3.3-beta', '0.3.3'), isFalse);
      expect(tagIs('v0.3.3', 'dev'), isFalse);
    });
  });

  group("the release workflow's lines", () {
    test('come off the top, with the blank lines after them', () {
      expect(
        withoutReleaseBoilerplate("$_boiler\n\n\n## What's Changed\n* A"),
        "## What's Changed\n* A",
      );
      // A line break of either kind, and a space after a line.
      expect(
        withoutReleaseBoilerplate(
          'Fluenough is GPL-3.0 with an App Store Distribution Exception. \r\n'
          'Source for this exact build is the tag it was made from.\r\n'
          '\r\n'
          '* A\r\n',
        ),
        '* A\n',
      );
    });

    test(
      'either line alone comes off too, and a body of only them is empty',
      () {
        expect(
          withoutReleaseBoilerplate(
            'Source for this exact build is the tag it was made from.\n* A',
          ),
          '* A',
        );
        expect(withoutReleaseBoilerplate(_boiler), '');
        expect(withoutReleaseBoilerplate('$_boiler\n\n'), '');
      },
    );

    test('stay anywhere but whole lines at the top', () {
      for (final body in <String>[
        '',
        '* A\n* B',
        'Notes first.\n$_boiler',
        '* Fluenough is GPL-3.0 with an App Store Distribution Exception.',
        'Fluenough is GPL-3.0 with an App Store Distribution Exception, yes.',
        '\nSource for this exact build is the tag it was made from.x',
      ]) {
        expect(withoutReleaseBoilerplate(body), body, reason: body);
      }
    });

    test('a blank line before a body with none to remove is left alone', () {
      expect(withoutReleaseBoilerplate('\n\n* A'), '\n\n* A');
    });
  });

  group('the GitHub fetch, on a fake client', () {
    final github = GitHubReleaseNotes(
      userAgent: 'fluenough/0.3.3',
      timeout: const Duration(milliseconds: 50),
    );

    test('asks for the 20 newest releases, saying who asks', () async {
      final client = FakeHttpClient(
        () async => (
          200,
          utf8.encode(
            jsonEncode(<Object?>[
              _release('v0.3.3', body: '$_boiler\n\n* A é'),
              _release('v0.3.2', draft: true),
              _release('v0.3.1'),
            ]),
          ),
        ),
      );
      final notes = await withFakeClient(client, github.fetch);
      expect(_tags(notes), <String>['v0.3.3', 'v0.3.1']);
      expect(notes.releases.first.body, '* A é', reason: 'read as UTF-8');
      expect(
        client.asked,
        Uri.parse(
          'https://api.github.com/repos/aaronified/fluenough/releases'
          '?per_page=20',
        ),
      );
      expect(client.sent[HttpHeaders.userAgentHeader], 'fluenough/0.3.3');
      expect(
        client.sent[HttpHeaders.acceptHeader],
        'application/vnd.github+json',
      );
      expect(client.connectionTimeout, github.timeout);
      expect(client.closed, isTrue);
    });

    test('the rate limit, and a reply that is not UTF-8', () async {
      final limited = FakeHttpClient(() async => (403, <int>[]));
      expect(
        (await withFakeClient(limited, github.fetch)).failure,
        ReleaseCheckFailure.rateLimited,
      );
      final garbled = FakeHttpClient(
        () async => (200, <int>[0xff, 0xfe, 0x7b]),
      );
      expect(
        (await withFakeClient(garbled, github.fetch)).failure,
        ReleaseCheckFailure.badReply,
      );
    });

    test('no network, or no answer in time, is offline', () async {
      final refused = FakeHttpClient(
        () async => throw const SocketException('Failed host lookup'),
      );
      expect(
        (await withFakeClient(refused, github.fetch)).failure,
        ReleaseCheckFailure.offline,
      );

      final silent = FakeHttpClient(() => Completer<(int, List<int>)>().future);
      expect(
        (await withFakeClient(silent, github.fetch)).failure,
        ReleaseCheckFailure.offline,
      );
      expect(silent.closed, isTrue, reason: 'the connection is dropped');
    });
  });

  test('the fixed engine answers what it is told, after its gate', () async {
    final gate = Completer<void>();
    final fixed = FixedReleaseNotes(
      const ReleaseNotes(<PublishedRelease>[PublishedRelease(tag: 'v1.0.0')]),
      gate: gate,
    );
    var answered = false;
    final answer = fixed.fetch().then((r) {
      answered = true;
      return r;
    });
    await Future<void>.delayed(Duration.zero);
    expect(answered, isFalse);
    gate.complete();
    expect(_tags(await answer), <String>['v1.0.0']);
    expect(fixed.fetches, 1);
    expect(
      (await const NullReleaseNotes().fetch()).failure,
      ReleaseCheckFailure.offline,
    );
  });
}
