import 'package:drift/drift.dart';

/// A [DateTime] stored as whole milliseconds since the Unix epoch, and read
/// back in local time.
///
/// Drift's default keeps whole seconds, which would round every review's
/// time. Reading back in local time keeps the app's calendar days (the daily
/// cap, streaks) on the learner's own days rather than UTC's.
class EpochMs extends TypeConverter<DateTime, int> {
  const EpochMs();

  @override
  DateTime fromSql(int fromDb) => DateTime.fromMillisecondsSinceEpoch(fromDb);

  @override
  int toSql(DateTime value) => value.millisecondsSinceEpoch;
}
