import 'package:fluenough/app/home_widget_gateway.dart';

/// A [HomeWidgetGateway] that keeps what it is asked, so a test can read what
/// the widget would hold, and can be told to fail.
class FakeHomeWidgetGateway implements HomeWidgetGateway {
  FakeHomeWidgetGateway({this.supported = true});

  @override
  bool supported;

  /// What the widget holds now: every save merged, as the plugin's storage is.
  final Map<String, String> stored = <String, String>{};

  /// How many times the data was saved.
  int saves = 0;

  /// How many times the widget was asked to draw again.
  int redraws = 0;

  /// The times last scheduled for the phone to draw the widget again.
  List<DateTime> scheduled = <DateTime>[];

  /// Makes every call throw, as a phone without the plugin's side would.
  bool failing = false;

  @override
  Future<void> save(Map<String, String> data) async {
    if (failing) throw StateError('no widget storage');
    saves++;
    stored.addAll(data);
  }

  @override
  Future<void> redraw() async {
    if (failing) throw StateError('no widget');
    redraws++;
  }

  @override
  Future<void> scheduleRedraws(List<DateTime> times) async {
    if (failing) throw StateError('no alarms');
    scheduled = List<DateTime>.of(times);
  }
}
