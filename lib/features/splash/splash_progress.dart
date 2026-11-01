import 'package:flutter/foundation.dart';

/// The start-up work the splash waits for, in the order it is named to the
/// learner, with the share of the bar each takes.
enum SplashStage {
  /// The review log is read and replayed (`Progress.ready`).
  history(0.35),

  /// The decks are read (`AppState.status` leaves loading).
  catalog(0.35),

  /// Today's numbers are worked out for the first time: the first frame
  /// after the catalog is ready.
  today(0.20);

  const SplashStage(this.weight);

  /// The part of the bar this stage fills, of 1.
  final double weight;
}

/// Which [SplashStage]s have finished. The app completes them as the
/// start-up seams fire (`StartupMarks`: storage ready, catalog ready, first
/// ready frame); [SplashGate] reads them.
class SplashProgress extends ChangeNotifier {
  /// What is left of the bar for the minimum time on screen: the stages'
  /// weights and this make 1.
  static const double minimumWeight = 0.10;

  final Set<SplashStage> _done = <SplashStage>{};

  bool isDone(SplashStage stage) => _done.contains(stage);

  bool get allDone => _done.length == SplashStage.values.length;

  /// The first stage not finished, in the order of [SplashStage.values];
  /// null once all are.
  SplashStage? get current {
    for (final stage in SplashStage.values) {
      if (!_done.contains(stage)) return stage;
    }
    return null;
  }

  /// The share of the bar the finished stages are worth.
  double get completedWeight =>
      <double>[for (final stage in _done) stage.weight]
          .fold(0.0, (a, b) => a + b);

  /// Records that [stage] has finished; a repeat does nothing.
  void complete(SplashStage stage) {
    if (_done.add(stage)) notifyListeners();
  }
}
