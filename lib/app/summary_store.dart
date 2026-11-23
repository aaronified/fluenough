import '../core/decks/language_summary.dart';
import 'deck_catalog.dart';

/// The language summaries (ADR-0062, 3.4) kept in one file between launches,
/// and in memory while the app runs. A cache: it can be deleted at any time.
class SummaryBook {
  SummaryBook(this.store);

  /// Where the file is kept; the same shape as the catalog snapshot's store.
  final SnapshotStore store;

  final Map<String, LanguageSummary> _byCode = <String, LanguageSummary>{};
  Future<void> _tail = Future<void>.value();
  Future<void>? _opening;

  /// The summaries' file text as last read or written, for a verify job.
  String? text;

  /// Changes whenever a summary is read, kept or forgotten, so that what is
  /// worked out from the summaries can tell when to be worked out again.
  int epoch = 0;

  /// Reads the file, once. A file that cannot be read is no summaries.
  Future<void> open() => _opening ??= _read();

  Future<void> _read() async {
    try {
      text = await store.read();
    } on Object {
      text = null;
    }
    _byCode
      ..clear()
      ..addAll(decodeSummaries(text));
    epoch++;
  }

  /// The summary of [code], or null.
  LanguageSummary? operator [](String code) => _byCode[code];

  Iterable<LanguageSummary> get all => _byCode.values;

  /// Keeps [summary] and writes the file.
  Future<void> put(LanguageSummary summary) {
    _byCode[summary.code] = summary;
    epoch++;
    return _write();
  }

  /// Forgets the summary of [code] and writes the file.
  Future<void> remove(String code) {
    if (_byCode.remove(code) == null) return Future<void>.value();
    epoch++;
    return _write();
  }

  Future<void> _write() {
    final next = encodeSummaries(_byCode.values);
    text = next;
    final done = _tail.then((_) => store.write(next));
    _tail = done.then<void>((_) {}, onError: (Object _) {});
    return done;
  }
}
