// The honest personas of Find my level V3 in es again, under the calibration
// profile at every safe edge of its clamps at once, the per-cell time gate
// included: a range a profile file may take is only as wide as the gates have
// been run.
@Timeout(Duration(minutes: 15))
library;

import 'package:flutter_test/flutter_test.dart' show Timeout;

import 'support/placement_v3_harness.dart';
import 'support/placement_v3_honest_suite.dart';

void main() {
  kHarnessProfile = kSafeEdgeProfile;
  honestSuite('es');
}
