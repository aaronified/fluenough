import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Puts the [AppState] where every widget below can reach it (ADR-0007).
///
/// Two ways in:
///
/// - [AppScope.of] subscribes: the caller rebuilds whenever [AppState]
///   notifies (catalog loaded, voices checked, profile changed). Use it in
///   `build`.
/// - [AppScope.read] does not subscribe. Use it in callbacks, `initState` and
///   anywhere a rebuild would be wasted.
///
/// Settings and progress have their own notifiers. Listen to them where they
/// are shown, with `ListenableBuilder(listenable: state.settings, …)`.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  /// The state, subscribing the caller to its changes.
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'no AppScope above this widget');
    return scope!.notifier!;
  }

  /// The state, without subscribing.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'no AppScope above this widget');
    return scope!.notifier!;
  }
}
