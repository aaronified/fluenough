import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/widgets/drill_frame.dart' show DrillGoing;
import '../../ui/widgets/feedback_banner.dart';
import 'drill_session.dart';

/// How a drill's screen goes on and back (#509, phase 0): by swipe and the
/// chevrons, with no Continue button anywhere (owner, 2026-10-31:
/// "Swipe-only everywhere"). [answered] is whether there is nothing left to
/// grade, so that going on is live; a screen gone back to is always
/// answered. Back is there for a card taught, a set shown and a question
/// once it is answered ([DrillSession.canGoBack]). The chevrons stay in view
/// ([pinned]) unless a screen has its own way to go on, as the review's
/// ratings are.
DrillGoing goingOn(
  DrillSession session, {
  required bool answered,
  VoidCallback? onNext,
  bool pinned = true,
}) => DrillGoing(
  onNext: onNext ?? session.next,
  onBack: session.canGoBack ? session.back : null,
  nextOn: answered || session.readOnly,
  pinned: pinned,
);

/// The banner a question gone back to shows in place of its verdict: it was
/// answered, and cannot be changed (owner, 2026-10-31, doubt 14). Null on
/// the current card.
Widget? alreadyAnswered(BuildContext context, DrillSession session) {
  if (!session.readOnly) return null;
  final l10n = AppLocalizations.of(context)!;
  return FeedbackBanner(
    kind: FeedbackKind.locked,
    title: l10n.drillAlreadyAnswered,
    detail: l10n.drillAlreadyAnsweredBody,
  );
}
