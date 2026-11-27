/// The phone's home-screen widget, as the app needs it: an interface so that
/// tests, the web build, iOS and the desktop need no plugin (docs/adr/0007).
/// `lib/app/plugin_home_widget_gateway.dart` is the implementation on
/// Android, and only `lib/main.dart` names it (#108).
abstract interface class HomeWidgetGateway {
  /// Whether this build has a home-screen widget at all: Android only.
  bool get supported;

  /// Stores [data] where the widget reads it.
  Future<void> save(Map<String, String> data);

  /// Has the widget drawn again from what is stored.
  Future<void> redraw();

  /// Replaces the times the phone has the widget drawn again by itself, with
  /// no help from the app.
  Future<void> scheduleRedraws(List<DateTime> times);
}

/// No widget: the web build, iOS, the desktop, and Android if the plugin
/// could not start.
class NullHomeWidgetGateway implements HomeWidgetGateway {
  const NullHomeWidgetGateway();

  @override
  bool get supported => false;

  @override
  Future<void> save(Map<String, String> data) async {}

  @override
  Future<void> redraw() async {}

  @override
  Future<void> scheduleRedraws(List<DateTime> times) async {}
}
