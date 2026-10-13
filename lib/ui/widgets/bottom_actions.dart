import 'package:flutter/material.dart';

/// The pinned bar at the foot of a screen that holds its main action:
/// Continue, Review all, Send review and the like.
///
/// Used as a [Scaffold.bottomNavigationBar], so the body ends above it. It
/// draws the surface with a divider on top, and its [SafeArea] keeps the
/// buttons above the system navigation bar, which the app draws under edge
/// to edge (#489, #501).
class BottomActions extends StatelessWidget {
  const BottomActions({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
