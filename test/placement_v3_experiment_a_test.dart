@Timeout(Duration(minutes: 40))
library;

import 'package:fluenough/core/placement/joint_model.dart';
import 'package:flutter_test/flutter_test.dart' show Timeout;

import 'support/placement_v3_experiment.dart';

void main() => experiment(<String, GuessCalibration>{
  'cal0': withBounds(<String, double>{}),
});
