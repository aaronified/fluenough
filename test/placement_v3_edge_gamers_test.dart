// The gamers gates of Find my level V3 again, under the calibration profile at
// every safe edge of its clamps at once (`PlacementProfile.safestEdge`): the
// ranges a profile file may take are only as wide as the gates have been run.
@Timeout(Duration(minutes: 25))
library;

import 'package:flutter_test/flutter_test.dart' show Timeout;

import 'placement_v3_gamers_test.dart' as base;
import 'support/placement_v3_harness.dart';

void main() {
  kHarnessProfile = kSafeEdgeProfile;
  base.main();
}
