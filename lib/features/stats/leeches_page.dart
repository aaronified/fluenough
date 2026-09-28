import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';

/// Cards missed again and again, with Reset and Set aside. Behind `Feature.leeches`.
///
/// Design screen `leeches`. A Phase 0 stub that shows only its title;
/// B7 replaces the body, keeping the class name and the constructor's
/// required parameters, which `AppRoutes` depends on. Optional parameters
/// (a gallery preset, say) may be added.
class LeechesPage extends StatelessWidget {
  const LeechesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PlaceholderPage(title: l10n.leechesTitle);
  }
}
