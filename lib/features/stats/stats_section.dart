import 'package:flutter/material.dart';

import '../../ui/theme.dart';

/// One of Progress's rounded panels: a heading and its rows, 12 apart.
class StatsSection extends StatelessWidget {
  const StatsSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;

  /// A button at the end of the title's line, such as "All tags".
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.group),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ),
              ?trailing,
            ],
          ),
          for (final child in children) ...<Widget>[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }
}
