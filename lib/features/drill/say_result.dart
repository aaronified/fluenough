import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/decks/script_fonts.dart';
import '../../core/grading/answer_grader.dart';
import '../../core/grading/heard_reading.dart';
import '../../core/models/deck.dart';
import '../../core/sound/sound_check.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/ipa_line.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';
import 'drill_session.dart';
import 'speaking_practice.dart' show unheardMessage;

/// What an answered Say question adds under its card (#509, phase 0; owner,
/// 2026-11-02, docs/mockups/shared-shell): what the phone heard, then the
/// learner's own recording, then what the last Try again came to.
///
/// - [HeardBox]: the heard script, the differing word underlined, and under
///   it its reading, or its IPA.
/// - [RecordingRow]: Replay (Pause while it plays), Word and Again, three
///   icon-only buttons, each with a one-word tooltip and the full phrase as
///   its screen-reader label.
///
/// The result of a Try again is graded in the feedback banner; this says
/// that it was practice, and that the first answer is the one that counts.
class SayResult extends StatelessWidget {
  const SayResult({super.key, required this.session});

  final DrillSession session;

  /// The widgets of the answer area, 16 apart in the frame.
  static List<Widget> parts(BuildContext context, DrillSession session) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final retried = session.retried;
    final unheard = session.unheard;
    final answer = retried ?? session.answer!;
    final String? status;
    final TextStyle statusStyle;
    if (session.hearing) {
      status = l10n.drillHearingHint;
      statusStyle = theme.textTheme.bodyLarge!.copyWith(
        color: scheme.onSurfaceVariant,
      );
    } else if (unheard != null) {
      status = unheardMessage(
        l10n,
        unheard,
        session.deck.language,
        session.networkWhy,
      );
      statusStyle = theme.textTheme.bodyLarge!.copyWith(color: scheme.error);
    } else if (retried != null) {
      final sooner = session.firstTryFailed;
      status = switch (retried.graded?.outcome) {
        AnswerOutcome.exact =>
          sooner ? l10n.drillRetryPassedSooner : l10n.drillRetryPassed,
        AnswerOutcome.closeDiacritics || AnswerOutcome.closeTypo =>
          sooner ? l10n.drillRetryAlmostSooner : l10n.drillRetryAlmost,
        AnswerOutcome.wrong || null => l10n.drillRetryPractice,
      };
      statusStyle = theme.textTheme.bodyLarge!.copyWith(
        color: scheme.onSurfaceVariant,
      );
    } else {
      status = null;
      statusStyle = theme.textTheme.bodyLarge!;
    }
    final selfFailure = session.selfFailure;
    return <Widget>[
      if (answer.graded != null && answer.typed.trim().isNotEmpty)
        HeardBox(session: session, answer: answer),
      RecordingRow(session: session),
      if (status != null)
        Semantics(
          liveRegion: true,
          child: Text(status, textAlign: TextAlign.center, style: statusStyle),
        ),
      if (selfFailure != null)
        Semantics(
          liveRegion: true,
          child: Text(
            switch (selfFailure) {
              RecordFailure.refused => l10n.drillHearYourselfRefused,
              RecordFailure.silent => l10n.drillHearYourselfSilent,
              RecordFailure.failed => l10n.drillHearYourselfFailed,
            },
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge!.copyWith(color: scheme.error),
          ),
        ),
      if (status == null && selfFailure == null)
        Text(
          session.retries > 0 ? l10n.sayRetakeHint : l10n.sayCompareHint,
          style: theme.textTheme.bodyMedium!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: parts(context, session),
  );
}

/// What the phone's recogniser heard, approximately (owner, 2026-11-02):
/// the heard script with the word that differs underlined, then a line that
/// follows the "IPA replaces transliteration" switch (#697).
///
/// - A heard text that is a card, the one asked or another of the deck: its
///   reading, or, with the switch on and the card having an IPA, its narrow
///   `[ ]` and broad `/ /` IPA, through [readingLines] and [ReadingText].
/// - Any other text: a rule-based reading ([heardReading], Indic first), and
///   with the switch on, a line saying no card matches, so there is no IPA.
class HeardBox extends StatelessWidget {
  const HeardBox({super.key, required this.session, required this.answer});

  final DrillSession session;
  final TypedAnswer answer;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = session.deck.language;
    final heard = answer.typed.trim();
    final right = answer.graded?.outcome.isCorrect ?? false;
    final matched = right ? session.item.card : answer.heardCard;
    final differing = right
        ? const <int>{}
        : differingWords(heard, session.acceptedAnswers.first);
    final caption = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurface,
    );
    final lines = matched == null
        ? null
        : readingLines(
            context,
            reading: matched.reading,
            ipa: matched.ipa,
            target: matched.target,
          );
    final settings = AppScope.read(context).settings;
    final ipaOn = settings.showIpa && settings.ipaReplacesReading;
    final guess = matched == null ? heardReading(heard, language.code) : null;
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: <Widget>[
              Text(
                l10n.sayHeardLabel,
                style: theme.textTheme.labelLarge!.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _HeardScript(
                text: heard,
                language: language,
                differing: differing,
              ),
              if (lines != null) ...<Widget>[
                if (lines.swapped && matched?.phonetic != null)
                  ReadingText(
                    matched!.phonetic!,
                    swapped: true,
                    style: caption,
                  ),
                if (lines.reading case final reading?)
                  ReadingText(reading, swapped: lines.swapped, style: caption),
              ] else ...<Widget>[
                if (guess != null) Text(guess, style: caption),
                if (ipaOn)
                  Text(
                    l10n.sayHeardNoCard,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final RegExp _marks = RegExp(r'[\p{P}\p{S}]', unicode: true);

/// The heard script, in the deck's font, with each word of [differing]
/// underlined with a wavy line in the error colour.
class _HeardScript extends StatelessWidget {
  const _HeardScript({
    required this.text,
    required this.language,
    required this.differing,
  });

  final String text;
  final LanguageInfo language;
  final Set<int> differing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fonts = AppScope.read(context).deckDownloads?.fonts;
    Widget build(String? family) {
      final base = theme.textTheme.titleLarge!.copyWith(
        fontFamily: family,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      );
      // The words are numbered as [differingWords] numbers them: a piece
      // that is only punctuation is no word.
      final spans = <InlineSpan>[];
      var number = 0;
      for (final (i, word) in text.split(RegExp(r'\s+')).indexed) {
        if (i > 0) spans.add(const TextSpan(text: ' '));
        final isWord = word.replaceAll(_marks, '').isNotEmpty;
        final wrong = isWord && differing.contains(number);
        if (isWord) number++;
        spans.add(
          TextSpan(
            text: word,
            style: wrong
                ? TextStyle(
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.wavy,
                    decorationColor: scheme.error,
                    decorationThickness: 2,
                  )
                : null,
          ),
        );
      }
      return Text.rich(
        TextSpan(children: spans),
        style: base,
        locale: targetLocale(language),
        textDirection: language.rightToLeft
            ? TextDirection.rtl
            : TextDirection.ltr,
      );
    }

    if (fonts == null) return build(null);
    return ListenableBuilder(
      listenable: fonts,
      builder: (context, _) =>
          build(fonts.familyFor(fontScriptFor(language.code, language.script))),
    );
  }
}

/// "Your recording", Word and Again in one row of icon-only buttons (owner,
/// 2026-11-02). Replay plays the take the engine kept; where none is kept
/// (every engine today, ADR-0054) it records the word again, as "Hear
/// yourself" does, and plays that. Word plays the word, Again records a new
/// take. The take is in memory only.
class RecordingRow extends StatelessWidget {
  const RecordingRow({super.key, required this.session});

  final DrillSession session;

  static String _time(Duration d) {
    final seconds = (d.inMilliseconds / 1000).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final playing = session.replaying;
    final recording = session.hearingSelf == SelfTake.recording;
    final busy =
        session.hearing || session.hearingSelf != SelfTake.idle || playing;
    final length = session.ownTakeLength;

    Widget button({
      required String hint,
      required String label,
      required IconData icon,
      required VoidCallback? onPressed,
      required bool primary,
    }) => Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      excludeSemantics: true,
      onTap: onPressed,
      child: IconButton.filled(
        tooltip: hint,
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          fixedSize: const Size.square(48),
          backgroundColor: primary ? scheme.primary : scheme.secondaryContainer,
          foregroundColor: primary
              ? scheme.onPrimary
              : scheme.onSecondaryContainer,
        ),
      ),
    );

    final locked = session.readOnly;
    final Widget caption;
    if (locked) {
      // A card gone back to: the take belongs to the current card, so there
      // is nothing to say about it here.
      caption = const SizedBox.shrink();
    } else if (playing) {
      caption = _Progress(
        key: const ValueKey<String>('replay'),
        length: length,
      );
    } else {
      caption = Text(
        recording
            ? l10n.drillHearYourselfRecording
            : session.hasOwnTake && length != null
            ? l10n.sayRecordingKept(_time(length))
            : l10n.sayRecordingNone,
        style: theme.textTheme.bodySmall!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainerLow,
      shape: const StadiumBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.primaryButton),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 8, 4),
          child: Row(
            spacing: 8,
            children: <Widget>[
              button(
                hint: playing ? l10n.sayPauseHint : l10n.sayReplayHint,
                label: playing ? l10n.sayPauseLabel : l10n.sayReplayLabel,
                icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                primary: true,
                onPressed: locked || session.hearing || recording
                    ? null
                    : () {
                        if (!session.soundOn) {
                          showAppSnackBar(context, l10n.speakerSoundOff);
                          return;
                        }
                        session.replayOwn();
                      },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: <Widget>[
                    Text(
                      l10n.sayYourRecording,
                      style: theme.textTheme.labelLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    caption,
                  ],
                ),
              ),
              button(
                hint: l10n.sayWordHint,
                label: l10n.drillPlay,
                icon: Icons.volume_up_outlined,
                primary: false,
                onPressed: session.canPlay && !busy
                    ? () => SpeakerActions.tap(context, session.play)
                    : null,
              ),
              button(
                hint: l10n.sayAgainHint,
                label: l10n.sayAgainLabel,
                icon: Icons.mic,
                primary: false,
                onPressed: locked || busy
                    ? null
                    : () {
                        if (!session.soundOn) {
                          showAppSnackBar(context, l10n.speakerSoundOff);
                          return;
                        }
                        session.hearSelf();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar and "0:01 of 0:02" under Your recording while it plays.
class _Progress extends StatelessWidget {
  const _Progress({super.key, required this.length});

  final Duration? length;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final length = this.length;
    if (length == null || length == Duration.zero) {
      return const LinearProgressIndicator(
        minHeight: AppRadii.mark,
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.mark)),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: length,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: <Widget>[
          LinearProgressIndicator(
            value: value,
            minHeight: AppRadii.mark,
            borderRadius: BorderRadius.circular(AppRadii.mark),
          ),
          Text(
            l10n.sayRecordingProgress(
              RecordingRow._time(length * value),
              RecordingRow._time(length),
            ),
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
