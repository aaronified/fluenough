@Timeout(Duration(minutes: 40))
library;

import 'package:fluenough/core/placement/joint_model.dart';
import 'package:flutter_test/flutter_test.dart' show Timeout;

import 'support/placement_v3_experiment.dart';

void main() => experiment(<String, GuessCalibration>{
  'f26-27+writes': withBounds(<String, double>{'F26:clean': 0.27, 'F27:clean': 0.27, 'F21:clean': 0.17, 'F8:clean': 0.12, 'F7:clean': 0.10}),
});
