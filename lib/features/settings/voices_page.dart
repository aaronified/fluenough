import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';

/// Which catalog languages the phone can speak, with Test, and how to install a voice.
///
/// Design screen `voices`. A Phase 0 stub that shows only its title;
/// B5 replaces the body, keeping the class name and the constructor's
/// required parameters, which `AppRoutes` depends on. Optional parameters
/// (a gallery preset, say) may be added.
class VoicesPage extends StatelessWidget {
  const VoicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PlaceholderPage(title: l10n.voicesTitle);
  }
}
