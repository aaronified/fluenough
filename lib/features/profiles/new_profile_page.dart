import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';

/// A new profile: shape, name, the language they speak, the languages they learn, an optional PIN.
///
/// Design screen `new-profile`. A Phase 0 stub that shows only its title;
/// B6 replaces the body, keeping the class name and the constructor's
/// required parameters, which `AppRoutes` depends on. Optional parameters
/// (a gallery preset, say) may be added.
class NewProfilePage extends StatelessWidget {
  const NewProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PlaceholderPage(title: l10n.newProfileTitle);
  }
}
