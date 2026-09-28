import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';

/// Today: cards due by skill, Start review, the streak and week, and the profile's decks.
///
/// Design screen `today`. A Phase 0 stub that shows only its title;
/// B3 replaces the body, keeping the class name and the constructor's
/// required parameters, which `AppRoutes` depends on. Optional parameters
/// (a gallery preset, say) may be added.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PlaceholderPage(title: l10n.navToday, isTab: true);
  }
}
