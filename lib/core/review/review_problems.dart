/// Where the review code reports what it could not read or use, so that one
/// malformed entry never stops the rest (ADR-0058, W1).
///
/// Pure Dart: the app's log (`AppLog` in `lib/app`) is wired in at startup
/// (`ReviewProblems.sink = log.warning`). A message never carries a card's
/// text or a reviewer's answer (the log's rule, owner, 2026-10-09): only
/// what kind of thing was wrong and, at most, a card id or a facet name.
library;

/// Takes one line for the log.
typedef ReviewProblemSink = void Function(String message);

abstract final class ReviewProblems {
  /// The log's warning, set once at startup; null in tests that do not look.
  static ReviewProblemSink? sink;

  /// Reports [message]. Never throws, whatever the sink does.
  static void report(String message) {
    try {
      sink?.call(message);
    } on Object {
      // The log failing must not stop the review.
    }
  }
}
