import 'package:flutter/widgets.dart';

/// Padding that keeps the end of a scrolling screen clear of the system
/// navigation bar.
///
/// The app draws edge to edge, so on a phone with the three-button bar the
/// bottom 48 dp of every screen is under it (#489). A [ListView] given
/// explicit `padding` ignores the inset it would otherwise add, so the last
/// item stops short of the bar by only the padding written here. Inside a
/// [SafeArea], or a [Scaffold] with a bottom bar of its own, the inset has
/// already been taken and this adds nothing.
extension SystemBarClearance on EdgeInsetsDirectional {
  /// These insets with the bottom system inset added to the bottom edge.
  EdgeInsetsDirectional clearingSystemBar(BuildContext context) =>
      copyWith(bottom: bottom + MediaQuery.paddingOf(context).bottom);
}
