import 'package:home_widget/home_widget.dart';

import '../core/widget/home_widget_summary.dart';
import 'home_widget_gateway.dart';

/// [HomeWidgetGateway] through the `home_widget` plugin (#108, owner,
/// 2026-11-27), on Android.
///
/// Only `lib/main.dart` imports this file, and only on Android, so the web
/// build, which starts from `lib/main_web.dart`, never reaches the plugin.
/// The widget itself, `DueWidgetProvider`, is native code that
/// `tools/brand_android.py` writes into the generated android/ from
/// `tools/android_templates/widget/`.
class PluginHomeWidgetGateway implements HomeWidgetGateway {
  const PluginHomeWidgetGateway();

  @override
  bool get supported => true;

  @override
  Future<void> save(Map<String, String> data) async {
    for (final MapEntry(:key, :value) in data.entries) {
      await HomeWidget.saveWidgetData<String>(key, value);
    }
  }

  @override
  Future<void> redraw() async {
    await HomeWidget.updateWidget(androidName: HomeWidgetKeys.androidName);
  }

  @override
  Future<void> scheduleRedraws(List<DateTime> times) async {
    await HomeWidget.scheduleWidgetUpdates(
      times,
      androidName: HomeWidgetKeys.androidName,
    );
  }
}
