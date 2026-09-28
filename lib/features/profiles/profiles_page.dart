import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';

/// Who's practising: the profiles on this phone, and Add profile. Behind `Feature.profiles`.
///
/// Design screen `profiles`. A Phase 0 stub that shows only its title;
/// B6 replaces the body, keeping the class name and the constructor's
/// required parameters, which `AppRoutes` depends on. Optional parameters
/// (a gallery preset, say) may be added.
class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PlaceholderPage(title: l10n.profilesTitle);
  }
}
