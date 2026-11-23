import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';

/// Reads the unit of [language] when a page of it opens, and draws a spinner
/// in the page's place until it is there (ADR-0062,
/// Plan-Lazy-Language-Loading, P-C4): culture, topics, situations and what
/// lists a language's facts read that one language's files, and the learner
/// may open them for a language the bar is not on.
///
/// Draws [child] at once when the catalog is read whole, when the language is
/// not on the phone and when its unit is read; a unit that failed shows the
/// page with what it has, as the review pages do.
class LanguageUnitLoader extends StatefulWidget {
  const LanguageUnitLoader({
    super.key,
    required this.language,
    required this.child,
  });

  final String language;
  final Widget child;

  @override
  State<LanguageUnitLoader> createState() => _LanguageUnitLoaderState();
}

class _LanguageUnitLoaderState extends State<LanguageUnitLoader> {
  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    if (state.isLanguageReading(widget.language)) {
      unawaited(state.ensureLoaded(widget.language));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.isLanguageReading(widget.language)) return widget.child;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: CircularProgressIndicator(
          semanticsLabel: AppLocalizations.of(context)!.commonLoadingDecks,
        ),
      ),
    );
  }
}
