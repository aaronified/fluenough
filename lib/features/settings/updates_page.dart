import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'settings_section_page.dart';
import 'update_section.dart';

/// Settings' Updates page: checking for a newer version, the automatic
/// check and the release notes, what [UpdateSection] held on the tab.
class UpdatesPage extends StatelessWidget {
  const UpdatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsSectionPage(
      title: l10n.settingsRowUpdates,
      builder: (context) => const <Widget>[UpdateSection(heading: false)],
    );
  }
}
