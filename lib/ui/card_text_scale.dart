import 'package:flutter/widgets.dart';

import '../app/settings.dart';
import 'theme.dart';

/// The largest card text size that keeps a card within
/// [AppSizes.maxTextScale] in all, with the phone's own text at
/// [phoneScale]: `1.4 / phoneScale`, the phone's scale taken at the app's
/// cap, and never below 1.0 or above [SettingsNotifier.maxCardTextScale]
/// (owner, 2026-10-13, #505). Phone at 1.2: about 1.17. At 1.4 or more: 1.0.
double maxCardTextScaleFor(double phoneScale) {
  final phone = phoneScale.clamp(0.0, AppSizes.maxTextScale);
  if (phone <= 0) return SettingsNotifier.maxCardTextScale;
  return (AppSizes.maxTextScale / phone)
      .clamp(1.0, SettingsNotifier.maxCardTextScale)
      .toDouble();
}

/// The phone's text scale as the app draws it, at most
/// [AppSizes.maxTextScale].
double phoneTextScaleOf(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) / 14;

/// Whether the phone's text is large enough that rows put their actions
/// under the text instead of beside it. The one check for it: always the
/// scale at body size ([phoneTextScaleOf]), never `scale(1)`, which is
/// outside Android's nonlinear font table and is not the body size's factor.
bool isLargeText(BuildContext context) => phoneTextScaleOf(context) > 1.3;

/// The largest card text size the phone's text allows here.
double maxCardTextScaleOf(BuildContext context) =>
    maxCardTextScaleFor(phoneTextScaleOf(context));

/// The card text size a drill draws with: the learner's, held at
/// [maxCardTextScaleOf]. The saved value is left as it is, so it returns if
/// the phone's text gets smaller again.
double cardTextScaleOf(BuildContext context, SettingsNotifier settings) {
  final max = maxCardTextScaleOf(context);
  final saved = settings.cardTextScale;
  return saved > max ? max : saved;
}
