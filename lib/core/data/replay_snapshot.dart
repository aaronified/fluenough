import 'dart:convert';
import 'dart:typed_data';

import '../models/drill_mode.dart';
import '../models/leech_action.dart';
import '../models/review_event.dart';
import '../scheduling/ask.dart';
import '../scheduling/fsrs.dart';
import '../scheduling/replay.dart';
import '../scheduling/skill_parameters.dart';

/// The result of replaying the review log, kept as compact binary (#857,
/// ADR-0051), and the stamp that says which log it is the result for.
///
/// A snapshot holds what the replay works out and nothing the database
/// already gives: the events with their states before and after, the word
/// skills' states and the script skills' events and states, and each pair's
/// state from its own reviews (what `card_states` caches). The leech actions
/// and the fitted parameters are read from the database, the progress index
/// and each language's last study are built from the events, so a snapshot
/// can only disagree with a replay about what it holds.
///
/// Size, for about 10,000 cards and 50,000 reviews: an event is about 50
/// bytes (a flags byte, its time, two small indexes into a table of the
/// card and deck ids, the grade, the elapsed milliseconds and the state
/// after; the state before is a flag when it is the one the pair's previous
/// event ended in, which it is except after a reset or an implied review).
/// That is about 2.5 MB, the script skills' events about the same again for
/// a learner who answers script decks, and the state tables about 1.5 MB.
/// The same data as JSON is more than three times that. Decoding reads it
/// once, in an isolate.
///
/// Every number is written exactly: a double as its 8 bytes, a time as
/// microseconds with its zone flag, so that what is read back is equal to
/// what was written, which is what lets a snapshot stand in for a replay.
///
/// Pure Dart, no Flutter: this is in `lib/core` and stays so.
abstract final class ReplaySnapshot {
  /// The layout of the bytes. Raised when it changes, which makes every
  /// snapshot written before it unusable.
  static const int format = 1;

  static const List<int> _magic = <int>[0x46, 0x4c, 0x53, 0x4e]; // FLSN
}

/// What a snapshot holds: [Replayed] as memory keeps it, and the states from
/// each pair's own reviews.
typedef SnapshotContents = ({
  Replayed memory,
  Map<ProgressKey, FsrsState> cacheStates,
});

/// [memory] and [cacheStates] as bytes that [decodeSnapshot] reads back.
Uint8List encodeSnapshot({
  required Replayed memory,
  required Map<ProgressKey, FsrsState> cacheStates,
}) {
  final strings = _Strings();
  final body = _Out();
  _writeEvents(body, strings, memory.events, script: false);
  _writeEvents(body, strings, memory.scriptEvents, script: true);
  body.varint(memory.states.length);
  for (final MapEntry(:key, :value) in memory.states.entries) {
    body
      ..varint(strings.of(key.cardId))
      ..u8(key.mode.index);
    _writeState(body, value, null);
  }
  body.varint(memory.scriptStates.length);
  for (final MapEntry(:key, :value) in memory.scriptStates.entries) {
    body
      ..varint(strings.of(key.cardId))
      ..u8(key.mode.index)
      ..varint(strings.of(key.script));
    _writeState(body, value, null);
  }
  body.varint(cacheStates.length);
  for (final MapEntry(:key, :value) in cacheStates.entries) {
    body
      ..varint(strings.of(key.cardId))
      ..u8(key.mode.index);
    final same = memory.states[key];
    if (same != null && _sameState(same, value)) {
      body.u8(0);
    } else {
      body.u8(1);
      _writeState(body, value, null);
    }
  }
  final out = _Out()..bytes(ReplaySnapshot._magic);
  out
    ..u8(ReplaySnapshot.format)
    ..varint(strings.values.length);
  for (final text in strings.values) {
    final encoded = utf8.encode(text);
    out
      ..varint(encoded.length)
      ..bytes(encoded);
  }
  out.bytes(body.view());
  final payload = out.view();
  final sum = _adler32(payload, payload.length);
  final whole = Uint8List(payload.length + 4)
    ..setRange(0, payload.length, payload);
  ByteData.view(whole.buffer).setUint32(payload.length, sum);
  return whole;
}

/// What [encodeSnapshot] wrote in [bytes]. Throws, [FormatException] or a
/// [RangeError], for anything that is not one: another [ReplaySnapshot.format],
/// bytes cut short or changed, an index into nothing. The caller treats every
/// throw as no snapshot.
SnapshotContents decodeSnapshot(Uint8List bytes) {
  if (bytes.length < ReplaySnapshot._magic.length + 5) {
    throw const FormatException('snapshot too short');
  }
  final end = bytes.length - 4;
  final stored = ByteData.view(
    bytes.buffer,
    bytes.offsetInBytes,
  ).getUint32(end);
  if (_adler32(bytes, end) != stored) {
    throw const FormatException('snapshot checksum differs');
  }
  final input = _In(bytes, end);
  for (final byte in ReplaySnapshot._magic) {
    if (input.u8() != byte) throw const FormatException('not a snapshot');
  }
  if (input.u8() != ReplaySnapshot.format) {
    throw const FormatException('another snapshot format');
  }
  final strings = <String>[
    for (var i = input.varint(); i > 0; i--)
      utf8.decode(input.take(input.varint())),
  ];
  final events = _readEvents(input, strings, script: false);
  final scriptEvents = _readEvents(input, strings, script: true);
  final states = <ProgressKey, FsrsState>{};
  for (var i = input.varint(); i > 0; i--) {
    final key = (cardId: strings[input.varint()], mode: _mode(input.u8()));
    states[key] = _readState(input, null);
  }
  final scriptStates = <ScriptKey, FsrsState>{};
  for (var i = input.varint(); i > 0; i--) {
    final key = (
      cardId: strings[input.varint()],
      mode: _mode(input.u8()),
      script: strings[input.varint()],
    );
    scriptStates[key] = _readState(input, null);
  }
  final cacheStates = <ProgressKey, FsrsState>{};
  for (var i = input.varint(); i > 0; i--) {
    final key = (cardId: strings[input.varint()], mode: _mode(input.u8()));
    final explicit = input.u8();
    if (explicit == 0) {
      cacheStates[key] =
          states[key] ?? (throw const FormatException('state missing'));
    } else if (explicit == 1) {
      cacheStates[key] = _readState(input, null);
    } else {
      throw const FormatException('bad cache flag');
    }
  }
  if (!input.atEnd) throw const FormatException('trailing bytes');
  return (
    memory: (
      events: events,
      states: states,
      scriptEvents: scriptEvents,
      scriptStates: scriptStates,
    ),
    cacheStates: cacheStates,
  );
}

DrillMode _mode(int index) {
  if (index < 0 || index >= DrillMode.values.length) {
    throw const FormatException('unknown mode');
  }
  return DrillMode.values[index];
}

// Event flags.
const int _utc = 1;
const int _hasAnswer = 2;
const int _hasScript = 4;
const int _hasAsked = 8;
const int _hasBefore = 16;
const int _beforeIsLast = 32;
const int _hasShare = 64;

void _writeEvents(
  _Out out,
  _Strings strings,
  List<ReviewEvent> events, {
  required bool script,
}) {
  out.varint(events.length);
  // The state each pair last ended in, so that an event whose state before is
  // that one says so in a bit.
  final last = <Object, FsrsState>{};
  for (final e in events) {
    final key = script ? e.scriptKey : e.key;
    final before = e.before;
    final lastEnd = last[key];
    final beforeIsLast =
        before != null && lastEnd != null && _sameState(before, lastEnd);
    var flags = e.at.isUtc ? _utc : 0;
    if (e.answerGiven != null) flags |= _hasAnswer;
    if (e.script != null) flags |= _hasScript;
    if (e.asked != null) flags |= _hasAsked;
    if (before != null) flags |= _hasBefore;
    if (beforeIsLast) flags |= _beforeIsLast;
    if (e.share != 1) flags |= _hasShare;
    out
      ..u8(flags)
      ..time(e.at)
      ..varint(strings.of(e.cardId))
      ..varint(strings.of(e.deckId))
      ..u8(e.mode.index)
      ..u8(e.grade)
      // The log keeps whole milliseconds, so a replay of it has them.
      ..varint(e.elapsed.inMilliseconds);
    if (e.answerGiven != null) out.varint(strings.of(e.answerGiven!));
    if (e.script != null) out.varint(strings.of(e.script!));
    if (e.asked != null) out.u8(e.asked!.index);
    if (e.share != 1) out.f64(e.share);
    if (before != null && !beforeIsLast) _writeState(out, before, null);
    _writeState(out, e.after, e.at);
    last[key] = e.after;
  }
}

List<ReviewEvent> _readEvents(
  _In input,
  List<String> strings, {
  required bool script,
}) {
  final events = <ReviewEvent>[];
  final last = <Object, FsrsState>{};
  for (var i = input.varint(); i > 0; i--) {
    final flags = input.u8();
    final at = input.time((flags & _utc) != 0);
    final cardId = strings[input.varint()];
    final deckId = strings[input.varint()];
    final mode = _mode(input.u8());
    final grade = input.u8();
    final elapsed = Duration(milliseconds: input.varint());
    final answer = (flags & _hasAnswer) != 0 ? strings[input.varint()] : null;
    final scriptName = (flags & _hasScript) != 0
        ? strings[input.varint()]
        : null;
    Ask? asked;
    if ((flags & _hasAsked) != 0) {
      final index = input.u8();
      if (index >= Ask.values.length) {
        throw const FormatException('unknown way of asking');
      }
      asked = Ask.values[index];
    }
    final share = (flags & _hasShare) != 0 ? input.f64() : 1.0;
    final key = script
        ? (cardId: cardId, mode: mode, script: scriptName ?? '')
        : (cardId: cardId, mode: mode);
    FsrsState? before;
    if ((flags & _beforeIsLast) != 0) {
      before = last[key] ?? (throw const FormatException('state missing'));
    } else if ((flags & _hasBefore) != 0) {
      before = _readState(input, null);
    }
    final after = _readState(input, at);
    last[key] = after;
    events.add(
      ReviewEvent(
        at: at,
        deckId: deckId,
        cardId: cardId,
        mode: mode,
        grade: grade,
        elapsed: elapsed,
        answerGiven: answer,
        script: scriptName,
        asked: asked,
        share: share,
        before: before,
        after: after,
      ),
    );
  }
  return events;
}

// State flags.
const int _dueUtc = 1;
const int _lastUtc = 2;
const int _lastIsAnchor = 4;
const int _dueIsInterval = 8;

/// [state]: its flags, stability, difficulty, recall, interval, repetitions
/// and lapses, then the times that are not implied. [anchor] is the time of
/// the review the state follows, which is `lastReviewAt`.
void _writeState(_Out out, FsrsState state, DateTime? anchor) {
  final last = state.lastReviewAt.microsecondsSinceEpoch;
  final lastIsAnchor = anchor != null && anchor.microsecondsSinceEpoch == last;
  final dueIsInterval =
      state.dueAt.microsecondsSinceEpoch - last ==
      state.intervalDays * Duration.microsecondsPerDay;
  var flags = 0;
  if (state.dueAt.isUtc) flags |= _dueUtc;
  if (state.lastReviewAt.isUtc) flags |= _lastUtc;
  if (lastIsAnchor) flags |= _lastIsAnchor;
  if (dueIsInterval) flags |= _dueIsInterval;
  out
    ..u8(flags)
    ..f64(state.stability)
    ..f64(state.difficulty)
    ..f64(state.recallAtReview)
    ..zigzag(state.intervalDays)
    ..varint(state.repetitions)
    ..varint(state.lapses);
  if (!lastIsAnchor) out.i64(last);
  if (!dueIsInterval) out.i64(state.dueAt.microsecondsSinceEpoch);
}

FsrsState _readState(_In input, DateTime? anchor) {
  final flags = input.u8();
  final stability = input.f64();
  final difficulty = input.f64();
  final recall = input.f64();
  final interval = input.zigzag();
  final repetitions = input.varint();
  final lapses = input.varint();
  final lastUs = (flags & _lastIsAnchor) != 0
      ? (anchor ?? (throw const FormatException('no anchor')))
            .microsecondsSinceEpoch
      : input.i64();
  final dueUs = (flags & _dueIsInterval) != 0
      ? lastUs + interval * Duration.microsecondsPerDay
      : input.i64();
  return FsrsState(
    stability: stability,
    difficulty: difficulty,
    intervalDays: interval,
    dueAt: DateTime.fromMicrosecondsSinceEpoch(
      dueUs,
      isUtc: (flags & _dueUtc) != 0,
    ),
    lastReviewAt: DateTime.fromMicrosecondsSinceEpoch(
      lastUs,
      isUtc: (flags & _lastUtc) != 0,
    ),
    repetitions: repetitions,
    lapses: lapses,
    recallAtReview: recall,
  );
}

bool _sameState(FsrsState a, FsrsState b) =>
    a.stability == b.stability &&
    a.difficulty == b.difficulty &&
    a.recallAtReview == b.recallAtReview &&
    a.intervalDays == b.intervalDays &&
    a.repetitions == b.repetitions &&
    a.lapses == b.lapses &&
    a.dueAt.microsecondsSinceEpoch == b.dueAt.microsecondsSinceEpoch &&
    a.dueAt.isUtc == b.dueAt.isUtc &&
    a.lastReviewAt.microsecondsSinceEpoch ==
        b.lastReviewAt.microsecondsSinceEpoch &&
    a.lastReviewAt.isUtc == b.lastReviewAt.isUtc;

/// Adler-32 of the first [length] bytes of [bytes]: enough to notice a
/// snapshot cut short or changed. Plain additions, so it is the same on the
/// web as on the phone.
int _adler32(Uint8List bytes, int length) {
  var a = 1;
  var b = 0;
  for (var i = 0; i < length; i++) {
    a = (a + bytes[i]) % 65521;
    b = (b + a) % 65521;
  }
  return b * 65536 + a;
}

/// The strings the events name, each once, by first use.
class _Strings {
  final Map<String, int> _index = <String, int>{};
  final List<String> values = <String>[];

  int of(String text) => _index.putIfAbsent(text, () {
    values.add(text);
    return values.length - 1;
  });
}

/// A growing buffer of bytes. 64-bit values are written as two 32-bit
/// halves, because the web has no 64-bit accessors.
class _Out {
  Uint8List _buffer = Uint8List(1 << 16);
  late ByteData _data = ByteData.view(_buffer.buffer);
  int _length = 0;

  Uint8List view() => Uint8List.sublistView(_buffer, 0, _length);

  void _room(int more) {
    if (_length + more <= _buffer.length) return;
    var size = _buffer.length * 2;
    while (size < _length + more) {
      size *= 2;
    }
    final grown = Uint8List(size)..setRange(0, _length, _buffer);
    _buffer = grown;
    _data = ByteData.view(grown.buffer);
  }

  void u8(int value) {
    _room(1);
    _buffer[_length++] = value;
  }

  void bytes(List<int> values) {
    _room(values.length);
    _buffer.setRange(_length, _length + values.length, values);
    _length += values.length;
  }

  /// An unsigned integer in 7-bit groups, low first.
  void varint(int value) {
    while (value >= 0x80) {
      u8((value % 0x80) | 0x80);
      value ~/= 0x80;
    }
    u8(value);
  }

  /// A signed integer, small ones in few bytes.
  void zigzag(int value) => varint(value >= 0 ? value * 2 : -value * 2 - 1);

  void f64(double value) {
    _room(8);
    _data.setFloat64(_length, value);
    _length += 8;
  }

  void i64(int value) {
    _room(8);
    final high = (value / 4294967296).floor();
    _data.setInt32(_length, high);
    _data.setUint32(_length + 4, value - high * 4294967296);
    _length += 8;
  }

  void time(DateTime at) => i64(at.microsecondsSinceEpoch);
}

/// Reads what [_Out] wrote, up to [end]. Reading past it throws.
class _In {
  _In(Uint8List bytes, this._end)
    : _bytes = bytes,
      _data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);

  final Uint8List _bytes;
  final ByteData _data;
  final int _end;
  int _at = 0;

  bool get atEnd => _at == _end;

  void _need(int count) {
    if (_at + count > _end) throw const FormatException('snapshot cut short');
  }

  int u8() {
    _need(1);
    return _bytes[_at++];
  }

  Uint8List take(int count) {
    _need(count);
    final slice = Uint8List.sublistView(_bytes, _at, _at + count);
    _at += count;
    return slice;
  }

  int varint() {
    var result = 0;
    var scale = 1;
    for (var i = 0; i < 9; i++) {
      final byte = u8();
      result += (byte & 0x7f) * scale;
      if (byte < 0x80) return result;
      scale *= 0x80;
    }
    throw const FormatException('number too long');
  }

  int zigzag() {
    final n = varint();
    return n.isEven ? n ~/ 2 : -((n + 1) ~/ 2);
  }

  double f64() {
    _need(8);
    final value = _data.getFloat64(_at);
    _at += 8;
    return value;
  }

  int i64() {
    _need(8);
    final high = _data.getInt32(_at);
    final low = _data.getUint32(_at + 4);
    _at += 8;
    return high * 4294967296 + low;
  }

  DateTime time(bool utc) =>
      DateTime.fromMicrosecondsSinceEpoch(i64(), isUtc: utc);
}

/// Which log, which fits and which code a snapshot was made from, as text
/// that is equal exactly when they are equal (#857, ADR-0051).
///
/// The review log is append-only (AGENTS.md rule 9), and the one thing that
/// replaces it, a restore, writes new rows with new, higher ids, because the
/// ids never repeat. So the log as it is now is the log a snapshot was made
/// from when these agree: how many reviews, their lowest, highest and summed
/// ids, the latest time, and sums of their times, grades and elapsed
/// milliseconds. The leech actions are few and are hashed whole, in order;
/// so are the fitted parameters, bit for bit. The app version and the
/// snapshot's format cover the code, and a hash of FSRS's default parameters
/// and of the enums the bytes index covers a build whose scheduling differs
/// under one version.
class LogStamp {
  const LogStamp._(this.text, this.reviews);

  /// The stamp for the log summarised by the arguments, written by [text].
  factory LogStamp({
    required String app,
    required int reviews,
    required int firstId,
    required int lastId,
    required int sumIds,
    required int latest,
    required int sumTimes,
    required int sumGrades,
    required int sumElapsed,
    required Iterable<LeechAction> leechActions,
    required Map<SkillKey, FittedParameters> fitted,
  }) {
    final actions = leechActions.toList();
    final buffer = StringBuffer();
    for (final a in actions) {
      buffer
        ..write(a.at.microsecondsSinceEpoch)
        ..write(',')
        ..write(a.key.cardId)
        ..write(',')
        ..write(a.key.mode.name)
        ..write(',')
        ..write(a.kind.name)
        ..write(';');
    }
    final parts = <String>[
      'snapshot${ReplaySnapshot.format}',
      app,
      _digest(_codeDescription()),
      'r$reviews:$firstId:$lastId:$sumIds:$latest:$sumTimes:$sumGrades:'
          '$sumElapsed',
      'l${actions.length}:${_digest(buffer.toString())}',
      'f${fitted.length}:${_fittedDigest(fitted)}',
    ];
    return LogStamp._(parts.join('|'), reviews);
  }

  /// The stamp as text, for comparing and for the database.
  final String text;

  /// How many reviews the log it stands for holds.
  final int reviews;

  @override
  bool operator ==(Object other) => other is LogStamp && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => text;
}

/// What a replay depends on besides the log: FSRS's default parameters and
/// the order of the enums the bytes index.
String _codeDescription() =>
    '${Fsrs.w.map((w) => w.toString()).join(',')}|'
    '${DrillMode.values.map((v) => v.name).join(',')}|'
    '${Ask.values.map((v) => v.name).join(',')}';

String _fittedDigest(Map<SkillKey, FittedParameters> fitted) {
  final keys = fitted.keys.toList()
    ..sort((a, b) {
      final byLanguage = a.language.compareTo(b.language);
      return byLanguage != 0 ? byLanguage : a.mode.name.compareTo(b.mode.name);
    });
  final out = _Out();
  for (final key in keys) {
    final fit = fitted[key]!;
    final name = utf8.encode('${key.language}/${key.mode.name}');
    out
      ..varint(name.length)
      ..bytes(name);
    for (final value in fit.values) {
      out.f64(value);
    }
    out
      ..time(fit.fittedAt)
      ..varint(fit.reviewCount)
      ..f64(fit.lossBefore ?? double.nan)
      ..f64(fit.lossAfter ?? double.nan)
      ..u8((fit.lossBefore == null ? 1 : 0) | (fit.lossAfter == null ? 2 : 0));
  }
  return _digestBytes(out.view());
}

String _digest(String text) => _digestBytes(utf8.encode(text));

/// Two FNV-1a hashes of [bytes], seeded apart, as 16 hex digits. Not a
/// cryptographic hash: it only has to tell two fits or two sets of actions
/// apart, which nobody is trying to forge. Kept to 32-bit arithmetic that the
/// web computes exactly.
String _digestBytes(List<int> bytes) {
  var a = 0x811c9dc5;
  var b = 0x01234567;
  for (var i = 0; i < bytes.length; i++) {
    a = _fnv(a, bytes[i]);
    b = _fnv(b, (bytes[i] + i) & 0xff);
  }
  return a.toRadixString(16).padLeft(8, '0') +
      b.toRadixString(16).padLeft(8, '0');
}

/// One FNV-1a step, `(hash ^ byte) * 16777619` modulo 2^32.
int _fnv(int hash, int byte) {
  final x = hash ^ byte;
  return (x * 0x193 + ((x << 24) & 0xffffffff)) & 0xffffffff;
}
