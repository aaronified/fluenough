/// The few pieces of GitHub-flavoured Markdown a release's notes use, read
/// without a package (AGENTS.md rule 6), for Settings' "What's new"
/// (ADR-0031). It reads:
///
/// - `#`, `##` and `###` headings; deeper ones read as level 3;
/// - `*` and `-` bullet lines, however far they are indented;
/// - `**bold**`;
/// - links, `[text](url)`, as their text; and images, `![alt](url)`, as
///   their alt text.
///
/// Anything else stays as the plain text it is: a bare URL, an `@user`, a
/// numbered line, `*italic*`. Each other line is a paragraph of its own,
/// as GitHub shows a release's line breaks, and blank lines only separate.
/// Never throws.
List<MdBlock> parseMarkdownSubset(String text) {
  final blocks = <MdBlock>[];
  for (final line in text.split(RegExp(r'\r\n|\r|\n'))) {
    if (line.trim().isEmpty) continue;
    final heading = _heading.firstMatch(line);
    if (heading != null) {
      final spans = _inline(heading.group(2) ?? '');
      if (spans.isNotEmpty) {
        final level = heading.group(1)!.length;
        blocks.add(
          MdBlock(MdKind.heading, spans, level: level > 3 ? 3 : level),
        );
      }
      continue;
    }
    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      final spans = _inline(bullet.group(1) ?? '');
      if (spans.isNotEmpty) blocks.add(MdBlock(MdKind.bullet, spans));
      continue;
    }
    final spans = _inline(line.trim());
    if (spans.isNotEmpty) blocks.add(MdBlock(MdKind.paragraph, spans));
  }
  return blocks;
}

/// What a block is.
enum MdKind { heading, bullet, paragraph }

/// One line of the notes: a heading, a bullet or a paragraph.
class MdBlock {
  const MdBlock(this.kind, this.spans, {this.level = 0});

  final MdKind kind;

  /// A heading's level, 1 to 3; 0 for the other kinds.
  final int level;

  /// The line's text, never empty, in runs of one style.
  final List<MdSpan> spans;

  /// The line as plain text.
  String get text => spans.map((s) => s.text).join();
}

/// A run of text in one style.
class MdSpan {
  const MdSpan(this.text, {this.bold = false});

  final String text;
  final bool bold;
}

// Up to six hashes and a space, as GitHub has it: `#hashtag` is text. A
// heading with nothing after the hashes matches, and is left out.
final RegExp _heading = RegExp(r'^\s*(#{1,6})(?:\s+(.*?))?\s*$');

// A marker and a space. `**bold**` and `---` are not bullets.
final RegExp _bullet = RegExp(r'^\s*[*-](?:\s+(.*?))?\s*$');

// `[text](url)`, and `![alt](url)`: the text, or the alt, is kept.
final RegExp _link = RegExp(r'!?\[([^\]]*)\]\([^)]*\)');

/// [line] with its links as their text, and its `**bold**` marked. An
/// opening `**` with no closing one is plain text.
List<MdSpan> _inline(String line) {
  final text = line.replaceAllMapped(_link, (m) => m.group(1) ?? '');
  final parts = text.split('**');
  // Markers pair up in order; an odd one left over is not bold.
  final paired = (parts.length - 1) ~/ 2 * 2;
  final spans = <MdSpan>[];
  void add(String run, {required bool bold}) {
    if (run.isEmpty) return;
    if (spans.isNotEmpty && spans.last.bold == bold) {
      spans.last = MdSpan('${spans.last.text}$run', bold: bold);
    } else {
      spans.add(MdSpan(run, bold: bold));
    }
  }

  for (var i = 0; i < parts.length; i++) {
    // Between marker i and marker i + 1, with both paired.
    final bold = i.isOdd && i < paired;
    // The unpaired marker, written out before the text that follows it.
    final unpaired = i == paired + 1;
    add(unpaired ? '**${parts[i]}' : parts[i], bold: bold);
  }
  return spans;
}
