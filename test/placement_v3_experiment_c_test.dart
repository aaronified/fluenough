@Timeout(Duration(minutes: 40))
library;

import 'package:fluenough/core/placement/drill_down.dart';
import 'package:flutter_test/flutter_test.dart' show Timeout;

import 'support/placement_v3_experiment.dart';

void main() => experiment(<String, DrillConfig>{
  'wide11': const DrillConfig(wideClasses: 11),
  'single2': const DrillConfig(singleMax: 2),
  'af2+fb5': const DrillConfig(allFailedPerSkill: 2, fallbackTop: 0.5),
  'identify9': const DrillConfig(identify: 0.9),
});
