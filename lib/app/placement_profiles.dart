import 'package:flutter/services.dart' show rootBundle;

import '../core/placement/declaration_options.dart';
import '../core/placement/placement_profile.dart';

// The calibration profiles of Find my level V3, read from
// `assets/placement_profiles.json` once. Anything wrong with the file gives
// the built-in default (today's behaviour): a missing asset, a malformed one,
// or a kill switch.

PlacementProfiles? _loaded;

/// The profiles of this build.
Future<PlacementProfiles> loadPlacementProfiles() async {
  final kept = _loaded;
  if (kept != null) return kept;
  String? text;
  try {
    text = await rootBundle.loadString('assets/placement_profiles.json');
  } on Object {
    text = null;
  }
  return _loaded = PlacementProfiles.parse(text);
}

/// The level band of a course built to [built] levels (`builtA1`...).
PlacementBand bandOfBuilt(int built) => built >= builtB1
    ? PlacementBand.b1
    : built >= builtA2
    ? PlacementBand.a2
    : PlacementBand.a1;
