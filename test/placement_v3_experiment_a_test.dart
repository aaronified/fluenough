@Timeout(Duration(minutes: 40))
library;

import 'package:fluenough/core/placement/drill_down.dart';
import 'package:flutter_test/flutter_test.dart' show Timeout;

import 'support/placement_v3_experiment.dart';

void main() => experiment(<String, DrillConfig>{
  'base': const DrillConfig(),
  'af2': const DrillConfig(allFailedPerSkill: 2),
  'adapt': const DrillConfig(adaptive: true),
  'af2+adapt': const DrillConfig(allFailedPerSkill: 2, adaptive: true),
});
