import 'package:fluenough/ui/widgets/hint.dart';
import 'package:flutter_test/flutter_test.dart';

/// The [LabelledIconButton] whose screen-reader label is [label]. Its
/// tooltip is one word shared by many buttons ("Edit"), so a test that wants
/// one of them, such as the pencil of one part, finds it by its label.
Finder byButtonLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is LabelledIconButton && widget.label == label,
  description: 'button labelled "$label"',
);
