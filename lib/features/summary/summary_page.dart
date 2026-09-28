import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';

/// The end of a session: cards and correct, minutes, streak, a score per skill, what is due tomorrow.
///
/// Design screen `summary`. A Phase 0 stub that shows only its title;
/// B3 replaces the body, keeping the class name and the constructor's
/// required parameters, which `AppRoutes` depends on. Optional parameters
/// (a gallery preset, say) may be added.
class SummaryPage extends StatelessWidget {
  const SummaryPage({super.key, required this.result});

  /// The finished session, from the drill.
  final SessionResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PlaceholderPage(title: l10n.summaryTitle);
  }
}
