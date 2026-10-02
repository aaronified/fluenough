import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/sound/sound_check.dart';
import '../../l10n/app_localizations.dart';
import '../profiles/spoken_languages_picker.dart';
import 'onboarding_step.dart';
import 'spoken_step.dart';

/// The first launch's microphone and sound check (#89): record two
/// seconds, play them back, and ask whether the learner heard them. It is
/// the only place before Settings that asks for the microphone.
///
/// A recording that fails, is refused or is silent leaves speaking off; a
/// playback that fails, or that the learner didn't hear, leaves listening
/// off. With no recording to play, a beep tests the sound. Try again asks
/// for the microphone once more. Next without a check changes nothing.
final OnboardingStep soundCheckStep = OnboardingStep(
  id: 'sound',
  content: (context, at) => SoundCheckContent(answers: at.answers),
);

/// How long the check records.
const Duration soundCheckLength = Duration(seconds: 2);

enum _Phase { ready, recording, playing, asking, done }

class SoundCheckContent extends StatefulWidget {
  const SoundCheckContent({super.key, required this.answers});

  final OnboardingAnswers answers;

  @override
  State<SoundCheckContent> createState() => _SoundCheckContentState();
}

class _SoundCheckContentState extends State<SoundCheckContent> {
  _Phase _phase = _Phase.ready;

  /// While recording or playing, whether a beep stands in.
  bool _beep = false;

  /// What was found, kept in the answers so that coming back to the step
  /// shows it, and saves what it shows.
  SoundCheckResult? get _result => widget.answers.soundCheck;

  @override
  void initState() {
    super.initState();
    if (_result case final result?) {
      _phase = result.hears == null ? _Phase.asking : _Phase.done;
    }
  }

  Future<void> _check() async {
    final state = AppScope.read(context);
    final refusedBefore = _result?.refusals ?? 0;
    setState(() => _phase = _Phase.recording);
    final recording = await state.soundCheck.record(soundCheckLength);
    if (!mounted) return;
    var speaks = false;
    if (recording.ok) {
      // The microphone is granted now, so this asks nothing.
      final setup = await state.startSpeech();
      if (!mounted) return;
      speaks = setup == SpeechSetup.ready;
    }
    setState(() {
      _beep = !recording.ok;
      _phase = _Phase.playing;
    });
    final played = await state.soundCheck.play(
      recording.ok ? recording : beep(),
    );
    if (!mounted) return;
    widget.answers.soundCheck = SoundCheckResult(
      speaks: speaks,
      hears: played ? null : false,
      failure: recording.failure,
      noRecogniser: recording.ok && !speaks,
      beep: !recording.ok,
      refusals:
          refusedBefore + (recording.failure == RecordFailure.refused ? 1 : 0),
    );
    setState(() => _phase = played ? _Phase.asking : _Phase.done);
  }

  void _heard(bool heard) {
    widget.answers.soundCheck = _result!.heard(heard);
    setState(() => _phase = _Phase.done);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: QuestionHeading(
            title: l10n.onboardingSoundTitle,
            body: l10n.onboardingSoundBody,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 24),
          sliver: SliverList.list(children: _body(context, l10n)),
        ),
        SliverToBoxAdapter(
          child: PickerNote(
            icon: Icons.tune,
            text: l10n.onboardingSoundLater(l10n.navSettings),
          ),
        ),
      ],
    );
  }

  List<Widget> _body(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = theme.textTheme.titleMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    switch (_phase) {
      case _Phase.ready:
      case _Phase.recording:
        final recording = _phase == _Phase.recording;
        return <Widget>[
          const SizedBox(height: 16),
          Center(
            child: _RecordButton(
              recording: recording,
              onPressed: recording ? null : _check,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              recording
                  ? l10n.onboardingSoundRecording
                  : l10n.onboardingSoundHint,
              textAlign: TextAlign.center,
              style: status,
            ),
          ),
        ];
      case _Phase.playing:
        return <Widget>[
          const SizedBox(height: 16),
          Icon(Icons.volume_up_outlined, size: 56, color: scheme.primary),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              _beep ? l10n.onboardingSoundBeeping : l10n.onboardingSoundPlaying,
              textAlign: TextAlign.center,
              style: status,
            ),
          ),
        ];
      case _Phase.asking:
        return <Widget>[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              _result?.beep ?? _beep
                  ? l10n.onboardingSoundHeardBeep
                  : l10n.onboardingSoundHeardYou,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          _Answer(
            icon: Icons.check,
            label: l10n.onboardingSoundYes,
            onPressed: () => _heard(true),
          ),
          const SizedBox(height: 8),
          _Answer(
            icon: Icons.close,
            label: l10n.onboardingSoundNo,
            onPressed: () => _heard(false),
          ),
        ];
      case _Phase.done:
        final result = _result!;
        final speaks = result.speaks;
        final hears = result.hears ?? false;
        return <Widget>[
          const SizedBox(height: 8),
          _Outcome(
            ok: speaks,
            text: speaks
                ? l10n.onboardingSoundSpeakingOn
                : result.noRecogniser
                ? l10n.onboardingSoundNoRecogniser
                : switch (result.failure) {
                    // From the second refusal Android no longer asks.
                    RecordFailure.refused when result.refusals > 1 =>
                      l10n.onboardingSoundRefusedForGood,
                    RecordFailure.refused => l10n.onboardingSoundRefused,
                    RecordFailure.silent => l10n.onboardingSoundSilent,
                    _ => l10n.onboardingSoundNotRecorded,
                  },
          ),
          const SizedBox(height: 12),
          _Outcome(
            ok: hears,
            text: hears
                ? l10n.onboardingSoundListeningOn
                : l10n.onboardingSoundListeningOff,
          ),
          if (!speaks || !hears) ...<Widget>[
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _check,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.commonRetry),
              ),
            ),
          ],
        ];
    }
  }
}

/// A large round microphone button, as on the speaking drill, which fills
/// with the recording's progress while it records.
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.recording, required this.onPressed});

  final bool recording;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final plays = recording && !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: l10n.onboardingSoundRecord,
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: 112,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Material(
              color: recording ? scheme.tertiary : scheme.primary,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: Icon(
                  Icons.mic,
                  size: 48,
                  color: recording ? scheme.onTertiary : scheme.onPrimary,
                ),
              ),
            ),
            if (recording)
              // A ring that fills over the recording, then stops: never an
              // endless animation, so tests and the gallery settle.
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: plays ? 0 : 1, end: 1),
                duration: soundCheckLength,
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 6,
                  color: scheme.primary,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One answer to "Did you hear it?", as a full-width row.
class _Answer extends StatelessWidget {
  const _Answer({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
      textStyle: Theme.of(context).textTheme.titleMedium,
    ),
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );
}

/// What the check found for one skill: a tick or a cross, and why.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle : Icons.cancel_outlined,
            color: ok ? scheme.primary : scheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
