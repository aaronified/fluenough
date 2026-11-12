@Timeout(Duration(minutes: 40))
library;

import 'package:fluenough/core/placement/drill_down.dart';
import 'package:flutter_test/flutter_test.dart' show Timeout;

import 'support/placement_v3_experiment.dart';

void main() => experiment(<String, DrillConfig>{
  'p+af2+later2': const DrillConfig(powerScore: true, allFailedPerSkill: 2, laterMax: 2),
  'p+af2+later3': const DrillConfig(powerScore: true, allFailedPerSkill: 2, laterMax: 3),
  'af2+later2': const DrillConfig(allFailedPerSkill: 2, laterMax: 2),
  'af2+later3': const DrillConfig(allFailedPerSkill: 2, laterMax: 3),
});
