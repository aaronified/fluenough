@Timeout(Duration(minutes: 40))
library;

import 'package:fluenough/core/placement/joint_model.dart';
import 'package:flutter_test/flutter_test.dart' show Timeout;

import 'support/placement_v3_experiment.dart';

void main() => experiment(<String, GuessCalibration>{
  'f26-27': withBounds(<String, double>{'F26:clean': 0.27, 'F27:clean': 0.27}),
});
