import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'expressive_shape.dart';
import 'segmented.dart';

/// The listening drill's play button: a `primary` cookie shape that turns a
/// half turn, with a spring, each time it is pressed, and a speaker icon that
/// becomes a pause icon while [playing].
///
/// 136 in listening, 104 in minimal pairs, smaller on other cards as their
/// speaker (`Speaker`). Screen readers hear "Play the word", or [label] when
/// given, or "Playing" while it plays. [muted], while sound is off in
/// Settings, greys it out and crosses out the speaker; it can still be
/// pressed, to say why nothing plays.
class PlayButton extends StatefulWidget {
  const PlayButton({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.playing = false,
    this.muted = false,
    this.size = 136,
    this.label,
  });

  final VoidCallback? onPressed;

  /// On a card's speaker, switches playing words automatically.
  final VoidCallback? onLongPress;

  final bool playing;

  /// Greyed out: sound is off for the whole app.
  final bool muted;

  final double size;

  /// What it plays, for screen readers: "Play the passage". Null for the
  /// word.
  final String? label;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
  double _turns = 0;

  void _press() {
    // A muted button does not turn: nothing plays.
    if (!widget.muted) setState(() => _turns += 0.5);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;
    final longPress = enabled ? widget.onLongPress : null;
    final muted = widget.muted;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.playing
          ? l10n.drillPlaying
          : widget.label ?? l10n.drillPlay,
      value: muted ? l10n.speakerMuted : null,
      excludeSemantics: true,
      onTap: enabled ? _press : null,
      onLongPress: longPress,
      onLongPressHint: longPress == null ? null : l10n.speakerLongPressHint,
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            AnimatedRotation(
              turns: _turns,
              duration: const Duration(milliseconds: 1400),
              curve: Segmented.morph,
              child: Material(
                color: muted ? scheme.surfaceContainerHighest : scheme.primary,
                shape: const ExpressiveShapeBorder(ExpressiveShape.cookie),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled ? _press : null,
                  onLongPress: longPress,
                  child: SizedBox.square(dimension: widget.size),
                ),
              ),
            ),
            IgnorePointer(
              child: Icon(
                widget.playing
                    ? Icons.pause
                    : muted
                    ? Icons.volume_off_outlined
                    : Icons.volume_up_outlined,
                // Never under 24, so that a small speaker reads as one.
                size: widget.size * 0.32 < 24 ? 24 : widget.size * 0.32,
                color: muted ? scheme.onSurfaceVariant : scheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
