import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';

/// A profile's PIN pad, with the wrong-PIN state and Forgot PIN?. Checks
/// with `AppState.checkPin`. Behind `Feature.pinLock`.
///
/// Design screens `pin` and `pin-error`. A Phase 0 stub that shows only its
/// heading; B6 replaces the body, keeping the class name and the required
/// `profileId`, which `AppRoutes` depends on. Optional parameters (a gallery
/// preset) may be added.
class PinPage extends StatelessWidget {
  const PinPage({super.key, required this.profileId});

  /// The profile being opened.
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profile = AppScope.of(context).profileById(profileId);
    return PlaceholderPage(
      title: l10n.pinGreeting(profile?.name ?? l10n.commonUnnamedProfile),
    );
  }
}
