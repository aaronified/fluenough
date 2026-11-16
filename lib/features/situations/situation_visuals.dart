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
    'hotel' => Icons.hotel_outlined,
    'post' => Icons.local_post_office_outlined,
    'bank' => Icons.account_balance_outlined,
    'greeting' => Icons.waving_hand_outlined,
    'emergency' => Icons.emergency_outlined,
    'school' => Icons.school_outlined,
    'work' => Icons.work_outline,
    'travel' => Icons.luggage_outlined,
    _ => Icons.chat_bubble_outline,
  };

  /// The colours for the situation key `this`.
  ModeColor situationColor(BuildContext context) =>
      _colorIn(ModeColors.of(context));

  /// The colour of a muted tile's icon (#1145): the tile's colour from the
  /// opposite brightness, deep in the light theme and pale in the dark, so
  /// that it reads against the plain surface.
  Color situationAccent(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _colorIn(dark ? ModeColors.light : ModeColors.dark).container;
  }

  ModeColor _colorIn(ModeColors modes) {
    return switch (this) {
      'taxi' => modes.reading,
      'shops' => modes.production,
      'eat' => modes.speaking,
      'doctor' => modes.pair,
      'traffic' => modes.recognition,
      'rail' => modes.listening,
      'hotel' => modes.pair,
      'post' => modes.reading,
      'bank' => modes.production,
      'greeting' => modes.speaking,
      'emergency' => modes.gesture,
      'school' => modes.recognition,
      'work' => modes.listening,
      'travel' => modes.grammar,
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
    'hotel' => l10n.situationHotel,
    'post' => l10n.situationPost,
    'bank' => l10n.situationBank,
    'greeting' => l10n.situationGreeting,
    'emergency' => l10n.situationEmergency,
    'school' => l10n.situationSchool,
    'work' => l10n.situationWork,
    'travel' => l10n.situationTravel,
    _ => this,
  };
}
