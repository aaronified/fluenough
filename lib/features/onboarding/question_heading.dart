import 'package:flutter/material.dart';

/// A question's title and what the answer is for, on the 24 px line. It
/// scrolls with the answers. The title grows at most one and a half times,
/// as Android's own scaling does for large type, so the first answers stay
/// in view at the largest text size.
class QuestionHeading extends StatelessWidget {
  const QuestionHeading({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            namesRoute: true,
            child: Text(
              title,
              style: theme.textTheme.headlineMedium,
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: theme.textTheme.bodyLarge!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
