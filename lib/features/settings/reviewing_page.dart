import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';
import '../review/review_section.dart';
import 'settings_section_page.dart';

/// Settings' Reviewing page: reviewer mode (docs/plans/deck-browser.md),
/// what [ReviewSection] held on the tab.
class ReviewingPage extends StatelessWidget {
  const ReviewingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsSectionPage(
      title: l10n.settingsRowReviewing,
      listenable: AppScope.of(context).settings,
      builder: (context) => const <Widget>[ReviewSection(heading: false)],
    );
  }
}
