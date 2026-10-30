import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// How a situation looks and is named on Today: an icon and a colour of its
/// own (owner, 2026-10-30: "each situation button has its own colours").
///
/// The colours are the theme's [ModeColors], whose container and text pairs
/// are already checked for contrast in light, dark and the high-contrast
/// themes; a situation is not a skill, but it borrows the pairs, one each.
extension SituationVisuals on String {
  /// The icon for the situation key `this`, a plain one for a key the app
  /// does not know.
  IconData get situationIcon => switch (this) {
    'taxi' => Icons.local_taxi_outlined,
    'shops' => Icons.shopping_basket_outlined,
    'eat' => Icons.restaurant_outlined,
    'doctor' => Icons.local_pharmacy_outlined,
    'traffic' => Icons.traffic_outlined,
    'rail' => Icons.train_outlined,
    _ => Icons.chat_bubble_outline,
  };

  /// The colours for the situation key `this`.
  ModeColor situationColor(BuildContext context) {
    final modes = ModeColors.of(context);
    return switch (this) {
      'taxi' => modes.reading,
      'shops' => modes.production,
      'eat' => modes.speaking,
      'doctor' => modes.pair,
      'traffic' => modes.recognition,
      'rail' => modes.listening,
      _ => modes.grammar,
    };
  }

  /// The one-word name of the situation key `this` on Today, for a course
  /// whose sheets are not written yet.
  String situationName(AppLocalizations l10n) => switch (this) {
    'taxi' => l10n.situationTaxi,
    'shops' => l10n.situationShops,
    'eat' => l10n.situationEat,
    'doctor' => l10n.situationDoctor,
    'traffic' => l10n.situationTraffic,
    'rail' => l10n.situationRail,
    _ => this,
  };
}
