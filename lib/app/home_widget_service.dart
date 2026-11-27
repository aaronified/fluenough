import 'dart:async';

import '../core/widget/home_widget_summary.dart';
import 'home_widget_gateway.dart';

/// Starts a one-shot timer; a test swaps in one it can fire by hand.
typedef WidgetTimer = Timer Function(Duration after, void Function() run);

Timer _realTimer(Duration after, void Function() run) => Timer(after, run);

/// The home-screen widget's data (#108): works out what it shows and hands
/// it to the [HomeWidgetGateway]. It stores again, debounced, when the
/// learner's progress or shown language changes, so a session, an import or
/// a restore reaches the widget once it has been quiet for a moment, and at
/// once when the app is left ([flush]).
///
/// It does nothing, and reads no progress, where the build has no widget
/// ([HomeWidgetGateway.supported]) or the feature is off. No work runs on a
/// timer of its own: the phone draws the widget again at the day's turn
/// ([HomeWidgetSummary.refreshTimes]), from what was stored.
///
/// Not in lib/core: it reads settings-side state and the platform interface.
class HomeWidgetService {
  HomeWidgetService({
    required this.gateway,
    required this.available,
    required this.summary,
    required this.texts,
    this.clock = DateTime.now,
    this.debounce = const Duration(seconds: 10),
    this.timer = _realTimer,
    this.log,
  });

  final HomeWidgetGateway gateway;

  /// Whether the widget is built in this version (`Feature.homeWidget`).
  final bool Function() available;

  /// The numbers to show now, from the log and the shown language (and
  /// `AppState.homeWidgetSummary`), or null when there is nothing to show.
  final HomeWidgetSummary? Function() summary;

  final HomeWidgetTexts Function() texts;
  final DateTime Function() clock;

  /// How long progress must be quiet before it is stored.
  final Duration debounce;
  final WidgetTimer timer;

  /// Reports a problem to the app's log, never to the screen.
  final void Function(String message)? log;

  Timer? _pending;
  Future<void> _queue = Future<void>.value();
  bool _disposed = false;

  /// Whether the widget can be used at all in this build.
  bool get active => !_disposed && gateway.supported && available();

  /// Something the widget shows may have changed: stores it once things have
  /// been quiet for [debounce]. A change inside that time restarts it.
  void changed() {
    if (!active) return;
    _pending?.cancel();
    _pending = timer(debounce, () {
      _pending = null;
      unawaited(flush());
    });
  }

  /// Stores now, for the app being left or opened. Runs one at a time, in
  /// order, and never throws: a failure goes to the log.
  Future<void> flush() {
    _pending?.cancel();
    _pending = null;
    if (!active) return _queue;
    return _queue = _queue.then((_) => _store()).catchError((Object error) {
      log?.call('Home widget error: $error');
    });
  }

  Future<void> _store() async {
    final now = clock();
    final numbers = summary();
    if (numbers == null) return;
    await gateway.save(numbers.toData(texts()));
    await gateway.redraw();
    await gateway.scheduleRedraws(HomeWidgetSummary.refreshTimes(now));
  }

  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _pending = null;
  }
}
