import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/private/private_ids.dart' show languageOfId;
import 'review_waiting.dart';

/// The languages a reviewer's pages read: those of the courses they review.
/// The catalog is read one language at a time (ADR-0062), so a page that
/// lists what waits in them reads their units first ([ReviewLoader]).
Set<String> reviewLanguageCodes(AppState state) => <String>{
  for (final language in reviewLanguagesOf(state)) language.code,
};

/// [reviewLanguageCodes] and the languages of what the reviewer has already
/// reviewed or answered, which the pages that list those read as well.
Set<String> reviewedLanguageCodes(AppState state) => <String>{
  ...reviewLanguageCodes(state),
  for (final review in state.reviewing.reviews.decks.values)
    languageOfId(review.deckId),
  for (final answer in state.reviewing.unsentAnswers) answer.language,
};

/// Whether any of [codes] is on the phone and its unit is being read, so
/// that a page that lists what is in them draws a spinner and not an empty
/// state. Never true when the catalog is read whole.
bool anyReading(AppState state, Iterable<String> codes) =>
    codes.any(state.isLanguageReading);

/// Reads the units of [codes] that are on the phone and not read yet, one
/// after another, for a page that lists what is in them. Does nothing when
/// the catalog is read whole.
Future<void> readLanguages(AppState state, Iterable<String> codes) async {
  for (final code in codes) {
    if (state.isLanguageReading(code)) await state.ensureLoaded(code);
  }
}

/// Reads, one after another, the units of the languages a reviewer's page
/// draws on, once the page is on screen: [languages], by default those of
/// the courses the reviewer reviews (Plan-Lazy-Language-Loading, P-C3). A
/// language the reviewer ticks later is read as well. It reads nothing when
/// the catalog is read whole, and nothing for a language that is not on the
/// phone. The page draws what is there, and again as each unit arrives.
class ReviewLoader extends StatefulWidget {
  const ReviewLoader({
    super.key,
    required this.child,
    this.languages = reviewLanguageCodes,
  });

  final Widget child;

  /// The language codes to read, asked again whenever the settings change.
  final Set<String> Function(AppState state) languages;

  @override
  State<ReviewLoader> createState() => _ReviewLoaderState();
}

class _ReviewLoaderState extends State<ReviewLoader> {
  late final AppState _state;

  /// The languages asked for already, so that each is asked once.
  final Set<String> _asked = <String>{};

  @override
  void initState() {
    super.initState();
    _state = AppScope.read(context);
    _state.settings.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _state.settings.removeListener(_load);
    super.dispose();
  }

  void _load() {
    final codes = <String>[
      for (final code in widget.languages(_state))
        if (_asked.add(code)) code,
    ];
    if (codes.isNotEmpty) unawaited(_read(codes));
  }

  Future<void> _read(List<String> codes) async {
    for (final code in codes) {
      if (!mounted) return;
      if (_state.isLanguageReading(code)) await _state.ensureLoaded(code);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
