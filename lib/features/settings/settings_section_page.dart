import 'package:flutter/material.dart';

import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/system_bar.dart';

/// A page of Settings, pushed from the tab: its title, the report button,
/// and the rows of the section in a list. The page's title names the
/// section, so its groups carry no heading of their own
/// (docs/mockups/settings.html).
///
/// [builder] runs again whenever [listenable] notifies, so the rows show
/// what is set now.
class SettingsSectionPage extends StatelessWidget {
  const SettingsSectionPage({
    super.key,
    required this.title,
    required this.builder,
    this.listenable,
  });

  final String title;

  /// What the page shows changes with this, such as the settings.
  final Listenable? listenable;

  /// The rows, each 20 apart.
  final List<Widget> Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) {
    final listenable = this.listenable;
    Widget list(BuildContext context) {
      final rows = builder(context);
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          16,
          8,
          16,
          24,
        ).clearingSystemBar(context),
        children: <Widget>[
          for (var i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 20),
            rows[i],
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const <Widget>[ReportButton()],
      ),
      body: listenable == null
          ? Builder(builder: list)
          : ListenableBuilder(
              listenable: listenable,
              builder: (c, _) => list(c),
            ),
    );
  }
}
