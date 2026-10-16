/// The app's own log (#162): what the app did and what went wrong, for
/// reports. Pure Dart: the file it is kept in, and the hooks that fill it,
/// are in `lib/app/app_log.dart`.
///
/// It records errors and warnings, and key events: screens opened, decks
/// loaded, fits run, imports and exports. Never an answer typed, and never
/// a card's contents (owner, 2026-10-09).
library;

/// How much an entry matters.
enum LogLevel {
  /// Something went wrong: an error the app caught, or one it did not.
  error('ERROR'),

  /// Something did not work, and the app went on: a file not saved.
  warning('WARN'),

  /// A key event: a screen opened, decks loaded, a fit run, an import.
  event('EVENT');

  const LogLevel(this.tag);

  /// How a line writes the level.
  final String tag;
}

/// How long the log keeps an entry, and how many entries it keeps at most:
/// whichever keeps fewer (owner, 2026-10-09).
const Duration logMaxAge = Duration(days: 7);
const int logMaxLines = 2000;

/// The name the log goes by as a file: exported from Settings, or attached
/// to a report.
const String appLogFileName = 'fluenough-app-log.txt';

/// The most characters an entry keeps: an error's text past it is cut.
const int logMaxMessage = 2000;

/// One thing the log recorded, one line in its file.
class LogEntry {
  const LogEntry(this.time, this.level, this.message);

  final DateTime time;
  final LogLevel level;

  /// What happened, in English for whoever reads a report. May run over
  /// several lines, as an error's stack does; [line] keeps it on one.
  final String message;

  /// The entry as one line: `2026-10-09T09:52:01.123Z EVENT Opened /deck`.
  /// The time is UTC. A line break in [message] is written `\n` and a
  /// backslash `\\`, so that one entry is always one line.
  String get line =>
      '${time.toUtc().toIso8601String()} ${level.tag} ${_escape(message)}';

  /// The entry [line] wrote, or null for a line that is not one, which a
  /// reader skips.
  static LogEntry? parse(String line) {
    final first = line.indexOf(' ');
    if (first < 0) return null;
    final second = line.indexOf(' ', first + 1);
    final tag = second < 0
        ? line.substring(first + 1)
        : line.substring(first + 1, second);
    final time = DateTime.tryParse(line.substring(0, first));
    final level = <LogLevel?>[
      for (final level in LogLevel.values)
        if (level.tag == tag) level,
    ].firstOrNull;
    if (time == null || level == null) return null;
    final message = second < 0 ? '' : _unescape(line.substring(second + 1));
    return LogEntry(time, level, message);
  }

  @override
  bool operator ==(Object other) =>
      other is LogEntry &&
      other.time == time &&
      other.level == level &&
      other.message == message;

  @override
  int get hashCode => Object.hash(time, level, message);

  @override
  String toString() => line;
}

String _escape(String text) => text
    .replaceAll('\\', r'\\')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('\n', r'\n');

String _unescape(String text) {
  final out = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '\\' && i + 1 < text.length) {
      final next = text[i + 1];
      if (next == 'n' || next == '\\') {
        out.write(next == 'n' ? '\n' : '\\');
        i++;
        continue;
      }
    }
    out.write(char);
  }
  return out.toString();
}

/// [entries], oldest first, without those older than [maxAge] at [now],
/// and then only the last [maxLines]: the cap is whichever keeps fewer.
List<LogEntry> capLog(
  Iterable<LogEntry> entries,
  DateTime now, {
  Duration maxAge = logMaxAge,
  int maxLines = logMaxLines,
}) {
  final since = now.subtract(maxAge);
  final kept = <LogEntry>[
    for (final entry in entries)
      if (!entry.time.isBefore(since)) entry,
  ];
  return kept.length <= maxLines ? kept : kept.sublist(kept.length - maxLines);
}

/// The log as its file holds it, and as it is shown, copied and attached:
/// one [LogEntry.line] each, oldest first.
String logText(Iterable<LogEntry> entries) =>
    <String>[for (final entry in entries) entry.line].join('\n');

/// [entries] read back from [text], as [logText] writes them, skipping any
/// line that is not one.
List<LogEntry> parseLog(String text) => <LogEntry>[
  for (final line in text.split('\n')) ?LogEntry.parse(line.trimRight()),
];

/// How many stack frames an error keeps: enough to find where, not the
/// whole stack.
const int logStackFrames = 8;

/// [error] as the log records it: [what] was being done, the error's type,
/// and the first [logStackFrames] lines of [stack].
///
/// Never the error's text, which can hold what the log must not: sqlite's
/// names the statement and its parameters, among them an answer typed; a
/// [FormatException]'s quotes the deck it could not read, and a
/// `FileSystemException`'s names a file the learner chose. The stack says
/// where, and code is all it names.
String describeError(String what, Object error, StackTrace? stack) {
  final frames = (stack?.toString() ?? '')
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .take(logStackFrames);
  return <String>['$what: ${error.runtimeType}', ...frames].join('\n');
}
