import 'package:flutter/material.dart';

import '../theme.dart';
import 'report_button.dart';

/// The large title at the top of a tab: "Decks", "Progress", "Settings".
/// 32/40 semibold, 24 from the start edge, marked as a heading.
///
/// A page pushed on top of a tab uses an [AppBar] instead; the theme gives it
/// the design's 64 px height and 22/28 title.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 12, 8),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
        ),
        ReportButton(detail: title),
      ],
    ),
  );
}

/// A centred icon, title, body and action: for "nothing here" states such as
/// no decks matching a search, and for a tab whose content is incoming.
///
/// Not for an incoming feature on its own (that is `IncomingFeature`), nor for
/// something missing on this phone (that says why and how to fix it).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Icon(icon, size: 32, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            if (body != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A screen that is not built yet: its title, and nothing else. Phase 0 puts
/// one behind every route so that the app runs end to end; each feature's
/// builder replaces theirs. Pushed pages get an [AppBar] with a back button.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, this.isTab = false});

  final String title;

  /// A tab's page has a [TabHeader] instead of an [AppBar].
  final bool isTab;

  @override
  Widget build(BuildContext context) {
    if (isTab) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[TabHeader(title: title)],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const <Widget>[ReportButton()],
      ),
      body: const SizedBox.expand(),
    );
  }
}
