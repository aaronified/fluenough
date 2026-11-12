@Timeout(Duration(minutes: 40))
library;

import 'package:fluenough/core/placement/drill_down.dart';
import 'package:flutter_test/flutter_test.dart' show Timeout;

import 'support/placement_v3_experiment.dart';

void main() => experiment(<String, DrillConfig>{
  'p': const DrillConfig(powerScore: true),
  'p+af2': const DrillConfig(powerScore: true, allFailedPerSkill: 2),
  'p+af2+cases1': const DrillConfig(powerScore: true, allFailedPerSkill: 2, maxCases: 1),
  'af2+cases1': const DrillConfig(allFailedPerSkill: 2, maxCases: 1),
});
