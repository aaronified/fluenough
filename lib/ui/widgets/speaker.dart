import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';
import 'play_button.dart';
import 'snack.dart';

/// What a speaker on a drill card does, the owner's spec: a tap plays; a
/// long press switches Play words automatically, and says which it is now;
/// every tenth tap while words do not play automatically says that a long
/// press makes them, so that it reaches those who tap it most. With sound
/// off in Settings, a tap or a long press says so instead.
///
/// [Speaker] does all of it; the reading drill's buttons for a sentence
/// call these.
abstract final class SpeakerActions {
  /// Every this many taps on a speaker, while words do not play
  /// automatically, a tap says that a long press makes them.
  static const int tipEvery = 10;

  /// A tap: plays with [onPlay], or says that sound is off.
  static void tap(BuildContext context, VoidCallback onPlay) {
    final settings = AppScope.read(context).settings;
    final l10n = AppLocalizations.of(context)!;
    if (!settings.soundOn) {
      showAppSnackBar(context, l10n.speakerSoundOff);
      return;
    }
    if (!settings.autoplay && settings.countSpeakerTap() % tipEvery == 0) {
      showAppSnackBar(context, l10n.speakerAutoplayTip);
    }
    onPlay();
  }

  /// A long press: switches playing words automatically, or says that
  /// sound is off.
  static void longPress(BuildContext context) {
    final settings = AppScope.read(context).settings;
    final l10n = AppLocalizations.of(context)!;
    if (!settings.soundOn) {
      showAppSnackBar(context, l10n.speakerSoundOff);
      return;
    }
    settings.autoplay = !settings.autoplay;
    showAppSnackBar(
      context,
      settings.autoplay ? l10n.speakerAutoplayOn : l10n.speakerAutoplayOff,
    );
  }
}

/// A drill card's speaker: a [PlayButton] that does what [SpeakerActions]
/// says, greyed out while sound is off.
///
/// With Play words automatically on, it plays once as it first appears: as
/// the card shows, or, where hearing the word would give the answer away,
/// as the answer comes in and the speaker with it. Build it where it should
/// appear, and give it a key of its own where a card's other content comes
/// and goes around it.
///
/// Where the phone has no voice for the language, leave it out, as the
/// cards always have.
class Speaker extends StatefulWidget {
  const Speaker({
    super.key,
    required this.onPlay,
    this.playing = false,
    this.size = defaultSize,
    this.label,
    this.enabled = true,
    this.playOnAppear = false,
    this.autoplay = true,
  });

  /// A speaker under a card's word, rather than a listening card's big one.
  static const double defaultSize = 64;

  final VoidCallback onPlay;
  final bool playing;
  final double size;

  /// What it plays, for screen readers: "Play the passage". Null for the
  /// word.
  final String? label;

  /// False to draw it disabled: a drill that is incoming.
  final bool enabled;

  /// Plays as it appears whatever Play words automatically says: the card
  /// teaching a word, which always has.
  final bool playOnAppear;

  /// Whether Play words automatically plays it as it appears. False where it
  /// would play the same thing again and again, such as a heard passage on
  /// each of its questions.
  final bool autoplay;

  @override
  State<Speaker> createState() => _SpeakerState();
}

class _SpeakerState extends State<Speaker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enabled) return;
      final settings = AppScope.read(context).settings;
      if (!settings.soundOn) return;
      if (widget.playOnAppear || (widget.autoplay && settings.autoplay)) {
        widget.onPlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => PlayButton(
        onPressed: widget.enabled
            ? () => SpeakerActions.tap(context, widget.onPlay)
            : null,
        onLongPress: widget.enabled
            ? () => SpeakerActions.longPress(context)
            : null,
        playing: widget.playing,
        muted: !settings.soundOn,
        size: widget.size,
        label: widget.label,
      ),
    );
  }
}

/// A small speaker, as an icon: the reading drill's button beside each
/// sentence. Does what [SpeakerActions] says, greyed out while sound is
/// off; never plays by itself.
class SpeakerIcon extends StatelessWidget {
  const SpeakerIcon({
    super.key,
    required this.onPlay,
    required this.label,
    this.playing = false,
  });

  final VoidCallback onPlay;

  /// What it plays, for screen readers and as its tooltip.
  final String label;

  final bool playing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final muted = !settings.soundOn;
        void tap() => SpeakerActions.tap(context, onPlay);
        void longPress() => SpeakerActions.longPress(context);
        return Semantics(
          button: true,
          label: label,
          value: muted ? l10n.speakerMuted : null,
          excludeSemantics: true,
          onTap: tap,
          onLongPress: longPress,
          onLongPressHint: l10n.speakerLongPressHint,
          child: Tooltip(
            message: label,
            // Long press is the speaker's own: the tooltip waits for hover.
            triggerMode: TooltipTriggerMode.manual,
            child: InkResponse(
              onTap: tap,
              onLongPress: longPress,
              radius: 24,
              child: SizedBox.square(
                dimension: 48,
                child: Icon(
                  playing
                      ? Icons.pause
                      : muted
                      ? Icons.volume_off_outlined
                      : Icons.volume_up_outlined,
                  color: muted
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
