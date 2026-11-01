import 'package:drift/drift.dart';

import 'converters.dart';

/// What opening the app works out from the whole review log, kept so that the
/// next launch need not work it out again (#857, ADR-0051). Added by
/// migration 10.
///
/// A cache, like `card_states`: every byte of it can be rebuilt by replaying
/// `reviews`, so it may be replaced or emptied at any time, and nothing reads
/// it without first checking its [stamp] against the log as it is now. It
/// never changes `reviews` or `leech_actions`. One row, [logName].
@DataClassName('ReplaySnapshotRow')
class ReplaySnapshots extends Table {
  /// Which snapshot this is: only [logName] so far.
  TextColumn get name => text()();

  /// The log, the fitted parameters and the code this was made from, as
  /// `LogStamp.text` writes them. Used only while it equals the stamp of the
  /// database now.
  TextColumn get stamp => text()();

  /// The replay's result in the compact binary form of `replay_snapshot.dart`.
  BlobColumn get payload => blob()();

  IntColumn get writtenAt => integer().map(const EpochMs())();

  @override
  Set<Column<Object>> get primaryKey => {name};

  /// The only row's name.
  static const String logName = 'review-log';
}
