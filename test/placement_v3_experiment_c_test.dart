@Timeout(Duration(minutes: 40))
library;

import 'package:fluenough/core/placement/drill_down.dart';
import 'package:flutter_test/flutter_test.dart' show Timeout;

import 'support/placement_v3_experiment.dart';

void main() => experiment(<String, DrillConfig>{
  'p+later2': const DrillConfig(powerScore: true, laterMax: 2),
  'p+later3': const DrillConfig(powerScore: true, laterMax: 3),
  'p+cases1': const DrillConfig(powerScore: true, maxCases: 1),
  'p+af2+single3': const DrillConfig(powerScore: true, allFailedPerSkill: 2, singleMax: 3),
});
