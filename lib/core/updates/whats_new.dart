import 'release_check.dart';

/// What the app shows once after an update (#944): the headline of each
/// CHANGELOG entry of the installed version, as bullets. No Flutter import:
/// the page that shows it is `features/whats_new`.

/// Whether the first launch of [current] is an update the learner has not
/// been told about: [lastSeen] is a version, and an earlier one. False when
/// [lastSeen] is null (a fresh install, or from before this was kept), the
/// same, later (a downgrade) or not a version.
bool isNewVersionSinceSeen(String? lastSeen, String current) =>
    isNewerVersion(current, lastSeen ?? '');

/// The headlines of the entries in the `## [version]` section of
/// [changelog], in their order; empty if the CHANGELOG has no dated section
/// for [version] (a development build is on `## [Unreleased]`), or the
/// section has no entry a learner would notice.
///
/// An entry is a `- ` bullet at the start of a line, with any indented
/// lines under it. Under every `###` heading, since a fix is as much a
/// change as an addition. An entry that starts with a backtick names a file,
/// a command or a tool (`tools/...`, `lib/...`): it is for developers and is
/// left out. The rule for the headline is [headlineOf].
List<String> whatsNewHeadlines(String changelog, String version) {
  final want = parseVersion(version);
  if (want == null) return const <String>[];
  final entries = <String>[];
  var inSection = false;
  StringBuffer? entry;
  void flush() {
    if (entry != null) entries.add(entry.toString());
    entry = null;
  }

  for (final line in changelog.split('\n')) {
    final heading = RegExp(r'^## \[([^\]]*)\]').firstMatch(line);
    if (heading != null) {
      flush();
      final found = parseVersion(heading.group(1)!);
      inSection = found != null && compareVersions(found, want) == 0;
      continue;
    }
    if (!inSection) continue;
    if (line.startsWith('- ')) {
      flush();
      entry = StringBuffer(line.substring(2).trim());
    } else if (line.trim().isEmpty || line.startsWith('#')) {
      flush();
    } else if (entry != null && line.startsWith(' ')) {
      entry!.write(' ${line.trim()}');
    }
  }
  flush();
  return <String>[
    for (final e in entries)
      if (!e.startsWith('`'))
        if (headlineOf(e) case final h when h.isNotEmpty) h,
  ];
}

/// The longest headline shown; a longer one is cut at a word and ends in an
/// ellipsis.
const int maxHeadline = 90;

/// The headline of one CHANGELOG [entry] (the text after its `- `), the
/// short plain phrase of what the learner notices. The rule, in order:
///
/// 1. An entry that starts with a bold phrase, `**Headline.** detail`, has
///    that phrase. This is how entries are written from now on (AGENTS.md,
///    "Changelog entries").
/// 2. Otherwise the text up to the first of an issue reference in
///    parentheses (` (#913)`), a colon, a full stop followed by a space, or
///    a dash with spaces round it. This reads the entries written before the
///    rule: "Situations on Today (#724): six buttons..." gives "Situations
///    on Today".
/// 3. Otherwise the whole entry.
///
/// Backticks, bold marks and a link's address are removed, the end is
/// trimmed of full stops, colons, commas and dashes, and a headline over
/// [maxHeadline] characters is cut at a word.
String headlineOf(String entry) {
  var text = entry.trim();
  final bold = RegExp(r'^\*\*(.+?)\*\*').firstMatch(text);
  String lead;
  if (bold != null) {
    lead = _plain(bold.group(1)!);
  } else {
    text = _plain(text);
    final end = RegExp(r'\s\(#\d+|: |\. |\s[—–]\s|\s-\s').firstMatch(text);
    lead = end == null ? text : text.substring(0, end.start);
  }
  lead = lead.replaceAll(RegExp(r'[\s.:;,—–-]+$'), '').trim();
  if (lead.length > maxHeadline) {
    final cut = lead.lastIndexOf(' ', maxHeadline);
    lead = '${lead.substring(0, cut > 0 ? cut : maxHeadline)}…';
  }
  return lead;
}

String _plain(String text) => text
    .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1)!)
    .replaceAll('`', '')
    .replaceAll('**', '');
