// The adversary gates of Find my level V3 again, from other seeds (1000 on):
// three times the runs in all, in CI shards of their own so the cost stays
// bounded and the re-tuned picker is judged on more than one draw.
@Timeout(Duration(minutes: 25))
library;

import 'package:flutter_test/flutter_test.dart' show Timeout;

import 'placement_v3_adversaries_test.dart' as base;
import 'support/placement_v3_harness.dart';

void main() {
  kSeedBase = 1000;
  base.main();
}
