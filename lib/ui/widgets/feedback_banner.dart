import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/models/deck.dart';
import 'target_text.dart';

/// What a drill's feedback says about the answer, which sets its colour and
/// icon. Each is also said in words: the colour never stands alone.
enum FeedbackKind {
  /// Right: `primaryContainer`, a tick.
  correct,

  /// Right apart from the accent or the article: `tertiaryContainer`, a
  /// warning.
  close,

  /// A near miss the learner judges: `secondaryContainer`, a warning.
  nearMiss,

  /// Wrong, or "Don't know": `errorContainer`, a cross.
  wrong,
}

/// The status panel at the foot of a drill once an answer is in: a bold
/// [title] ("Right, but mind the accent") and an optional [detail] ("You
/// typed “el nino”. Written: el niño").
///
/// A live region, so screen readers announce it as it appears. [detail]
/// often quotes deck content, so its direction is taken from its own text,
/// and each of [quotes] in the title or the detail is read in [language].
class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({
    super.key,
    required this.kind,
    required this.title,
    this.detail,
    this.quotes = const <String>[],
    this.language,
  });

  final FeedbackKind kind;
  final String title;
  final String? detail;

  /// The deck content the title and the detail quote: the answer, what was
  /// typed.
  final List<String> quotes;

  /// The language of [quotes], or null to mark none.
  final LanguageInfo? language;

  TextSpan _span(String text) {
    final language = this.language;
    return language == null
        ? TextSpan(text: text)
        : quotingTarget(text, quotes, language);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (kind) {
      FeedbackKind.correct => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      FeedbackKind.close => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.error_outline,
      ),
      FeedbackKind.nearMiss => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.error_outline,
      ),
      FeedbackKind.wrong => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.highlight_off,
      ),
    };
    final text = detail;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 2),
              child: Icon(icon, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text.rich(
                    _span(title),
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (text != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text.rich(
                      _span(text),
                      textDirection: intl.Bidi.detectRtlDirectionality(text)
                          ? TextDirection.rtl
                          : null,
                      style: theme.textTheme.bodyMedium!.copyWith(color: fg),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
