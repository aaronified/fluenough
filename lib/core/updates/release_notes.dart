import 'dart:async';
import 'dart:convert';

import 'release_check.dart';

/// One published release, as Settings' "What's new" lists it (ADR-0031).
class PublishedRelease {
  const PublishedRelease({required this.tag, this.publishedAt, this.body = ''});

  /// The release's tag, as GitHub has it: `v0.3.3`.
  final String tag;

  /// When it was published, or null if GitHub did not say.
  final DateTime? publishedAt;

  /// The release's notes, GitHub-flavoured Markdown, without the lines the
  /// release workflow puts at the top of every one
  /// ([withoutReleaseBoilerplate]). Empty if it has none.
  final String body;

  /// Whether this release is [version], such as `0.3.3`: the same numbers,
  /// so that `v0.3` and `0.3.0` match. False for a tag that is not a
  /// version.
  bool isVersion(String version) {
    final mine = parseVersion(tag);
    final theirs = parseVersion(version);
    return mine != null && theirs != null && compareVersions(mine, theirs) == 0;
  }
}

/// The app's releases, newest first, or why they could not be fetched.
class ReleaseNotes {
  const ReleaseNotes(this.releases) : failure = null;

  const ReleaseNotes.failed(ReleaseCheckFailure this.failure)
    : releases = const <PublishedRelease>[];

  /// Published releases only, in the order GitHub gives them: newest first.
  /// Empty when [failure] is set, and when there is none yet.
  final List<PublishedRelease> releases;

  /// Why there are no [releases]: the same reasons an update check fails.
  final ReleaseCheckFailure? failure;

  bool get ok => failure == null;
}

/// Where the app asks for its release notes (ADR-0031). Narrow enough that
/// tests fake it; only `main.dart` names the one that reaches GitHub.
abstract interface class ReleaseNotesEngine {
  /// Asks for the newest published releases. Never throws: a failure is a
  /// [ReleaseNotes.failed].
  Future<ReleaseNotes> fetch();
}

/// No network: every fetch fails as [ReleaseCheckFailure.offline]. The
/// default, so that no test or gallery state reaches GitHub.
class NullReleaseNotes implements ReleaseNotesEngine {
  const NullReleaseNotes();

  @override
  Future<ReleaseNotes> fetch() async =>
      const ReleaseNotes.failed(ReleaseCheckFailure.offline);
}

/// A release notes engine that answers what it is told to. For tests and
/// the gallery.
class FixedReleaseNotes implements ReleaseNotesEngine {
  FixedReleaseNotes(this.answer, {this.gate});

  /// What every fetch answers. Can change between fetches.
  ReleaseNotes answer;

  /// While set and not completed, a fetch waits on it, so that the loading
  /// state can be seen.
  Completer<void>? gate;

  /// How many times [fetch] was called.
  int fetches = 0;

  @override
  Future<ReleaseNotes> fetch() async {
    fetches++;
    await gate?.future;
    return answer;
  }
}

/// The two lines the release workflow writes at the top of every release
/// (`.github/workflows/release.yml`), above the generated notes.
const List<String> _boilerplate = <String>[
  'Fluenough is GPL-3.0 with an App Store Distribution Exception.',
  'Source for this exact build is the tag it was made from.',
];

/// [body] without the lines the release workflow adds at its top, and the
/// blank lines after them. Only whole lines at the very top are removed:
/// the same words further down, or inside a line, stay, and so does a body
/// that does not start with them.
String withoutReleaseBoilerplate(String body) {
  final lines = body.split(RegExp(r'\r\n|\r|\n'));
  var next = 0;
  var removed = false;
  while (next < lines.length) {
    final line = lines[next].trim();
    if (_boilerplate.contains(line)) {
      removed = true;
    } else if (!removed || line.isNotEmpty) {
      break;
    }
    next++;
  }
  return removed ? lines.skip(next).join('\n') : body;
}

/// GitHub's reply to `releases`, its [status] and [body], as the releases
/// it lists, in its order.
///
/// Drafts and pre-releases are left out, though GitHub does not list drafts
/// to an account that cannot push. Each release needs a `tag_name`; its
/// `published_at` and `body` are optional. An entry that is not a release
/// is left out; a reply with entries but not one readable release is a bad
/// reply, since the shape changed.
ReleaseNotes releaseNotesFromReply(int status, String body) {
  const bad = ReleaseNotes.failed(ReleaseCheckFailure.badReply);
  // GitHub says 403 for its hourly limit, and 429 for its burst limit.
  if (status == 403 || status == 429) {
    return const ReleaseNotes.failed(ReleaseCheckFailure.rateLimited);
  }
  if (status != 200) return bad;
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    return bad;
  }
  if (json is! List) return bad;
  final releases = <PublishedRelease>[];
  var unreadable = 0;
  for (final entry in json) {
    final tag = entry is Map ? entry['tag_name'] : null;
    if (entry is! Map || tag is! String || tag.trim().isEmpty) {
      unreadable++;
      continue;
    }
    if (entry['draft'] == true || entry['prerelease'] == true) continue;
    final published = entry['published_at'];
    final text = entry['body'];
    releases.add(
      PublishedRelease(
        tag: tag.trim(),
        publishedAt: published is String ? DateTime.tryParse(published) : null,
        body: text is String ? withoutReleaseBoilerplate(text) : '',
      ),
    );
  }
  if (releases.isEmpty && unreadable > 0) return bad;
  return ReleaseNotes(releases);
}
