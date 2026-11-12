@Timeout(Duration(minutes: 40))
library;

import 'package:fluenough/core/placement/drill_down.dart';
import 'package:flutter_test/flutter_test.dart' show Timeout;

import 'support/placement_v3_experiment.dart';

void main() => experiment(<String, DrillConfig>{
  'fb5': const DrillConfig(fallbackTop: 0.5),
  'fb6': const DrillConfig(fallbackTop: 0.6),
  'cases1': const DrillConfig(maxCases: 1),
  'single3': const DrillConfig(singleMax: 3),
});
