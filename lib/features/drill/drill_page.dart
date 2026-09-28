import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';

/// A drill session: recognition, production and listening, one card at a
/// time, recording each answer as it is given, then the summary.
///
/// Design screens `drill-recognition`, `drill-recognition-revealed`,
/// `drill-production-accent`, `drill-production-typo`,
/// `drill-production-script`, `drill-production-translit`, `drill-listening`
/// and `drill-rtl`. A Phase 0 stub that shows only a title; B1 replaces the
/// body, keeping the class name and the required `request`, which
/// `AppRoutes` depends on. Optional parameters (a gallery preset) may be
/// added.
///
/// Grammar and minimal pairs are B4's, in `grammar_drill.dart` and
/// `pair_drill.dart`; no live session contains them yet.
class DrillPage extends StatelessWidget {
  const DrillPage({super.key, required this.request});

  /// What the session covers. Build its queue with `AppState.buildSession`.
  final DrillRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PlaceholderPage(title: l10n.todayStartReview);
  }
}
