import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/deck_catalog.dart';
import '../../app/language_offer.dart';
import '../../app/script_test.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/target_text.dart';

/// "How well do you know Eastern Nagari?" (#554): the [ScriptTest] of a
/// course's script [lessons], for a learner who reads its script through
/// another language. It closes with whether the test was passed, or null
/// when left before the end; it saves nothing itself.
class ScriptTestPage extends StatefulWidget {
  const ScriptTestPage({
    super.key,
    required this.script,
    required this.lessons,
    this.random,
  });

  /// The script's own name, such as "Eastern Nagari".
  final String script;

  /// The course's script decks, from [ScriptLessons.scriptLessons].
  final List<DeckEntry> lessons;

  /// For tests, so that the questions are fixed.
  final Random? random;

  @override
  State<ScriptTestPage> createState() => _ScriptTestPageState();
}

class _ScriptTestPageState extends State<ScriptTestPage> {
  late ScriptTest _test = _start();

  ScriptTest _start() => ScriptTest(widget.lessons, random: widget.random);

  LanguageInfo get _language => widget.lessons.first.language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final test = _test;
    final question = test.question;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scriptTestTitle(widget.script)),
        actions: const <Widget>[ReportButton()],
      ),
      body: SafeArea(
        top: false,
        child: question == null
            ? _Result(
                test: test,
                language: _language.name,
                onDone: () => Navigator.of(context).pop(test.passed),
                onRetake: () => setState(() => _test = _start()),
              )
            : _Question(
                test: test,
                language: _language,
                onAnswer: (chosen) => setState(() => test.answer(chosen)),
              ),
      ),
    );
  }
}

/// One question: the letter or conjunct alone, and what it is.
class _Question extends StatelessWidget {
  const _Question({
    required this.test,
    required this.language,
    required this.onAnswer,
  });

  final ScriptTest test;
  final LanguageInfo language;
  final ValueChanged<String?> onAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final question = test.question!;
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
      children: <Widget>[
        Text(
          l10n.scriptTestProgress(test.asked + 1, test.questions.length),
          style: theme.textTheme.labelLarge!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(minHeight: 160),
          alignment: Alignment.center,
          padding: const EdgeInsetsDirectional.all(24),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: TargetText.hero(question.card.target, language: language),
        ),
        const SizedBox(height: 16),
        Text(l10n.scriptTestQuestion, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final option in question.options) ...<Widget>[
          OutlinedButton(
            onPressed: () => onAnswer(option),
            child: Text(option, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
        ],
        TextButton(
          onPressed: () => onAnswer(null),
          child: Text(l10n.placementDontKnow),
        ),
      ],
    );
  }
}

/// Passed or not, and the way back; not passed, the test again.
class _Result extends StatelessWidget {
  const _Result({
    required this.test,
    required this.language,
    required this.onDone,
    required this.onRetake,
  });

  final ScriptTest test;
  final String language;
  final VoidCallback onDone;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final total = test.questions.length;
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
      children: <Widget>[
        Text(
          test.passed
              ? l10n.scriptTestPassed(test.right, total, language)
              : l10n.scriptTestFailed(test.right, total, language),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 32),
        FilledButton(
          style: AppButtonStyles.tall(context),
          onPressed: onDone,
          child: Text(l10n.scriptTestDone),
        ),
        if (!test.passed) ...<Widget>[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetake,
            child: Text(l10n.scriptTestRetake),
          ),
        ],
      ],
    );
  }
}

/// Inside a language's card, under its "Learn the script" switch, for a
/// learner who reads its script through [through], other languages they
/// know (#554): the script test that skips its script lessons, or, once
/// passed, that they are skipped, and the test again.
class ScriptTestOffer extends StatelessWidget {
  const ScriptTestOffer({
    super.key,
    required this.language,
    required this.script,
    required this.through,
    required this.ownLetters,
    required this.skipped,
    required this.onTake,
  });

  final String language;

  /// The script's own name.
  final String script;

  /// The names of the languages the script is read through.
  final List<String> through;

  /// The letters the language adds to the script, with their readings.
  final List<ScriptLetter> ownLetters;

  /// Whether a passed test has skipped the script lessons.
  final bool skipped;

  /// Opens the test; null while the script decks are not on the phone.
  final VoidCallback? onTake;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium;
    final letters = <String>[
      for (final l in ownLetters)
        l.reading == null
            ? l.letter
            : l10n.scriptTestLetter(l.letter, l.reading!),
    ].join(l10n.commonListSeparator);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (skipped)
          Text(l10n.scriptTestSkippedNote(language), style: body)
        else ...<Widget>[
          Text(
            l10n.scriptTestOffer(
              script,
              through.join(l10n.commonListSeparator),
              language,
            ),
            style: body,
          ),
          if (letters.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(l10n.scriptTestOwnLetters(language, letters), style: body),
          ],
        ],
        const SizedBox(height: 8),
        if (onTake == null)
          Text(
            l10n.scriptTestWaiting,
            style: body!.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              onPressed: onTake,
              child: Text(
                skipped ? l10n.scriptTestRetake : l10n.scriptTestTake,
              ),
            ),
          ),
      ],
    );
  }
}
