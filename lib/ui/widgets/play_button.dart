import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'expressive_shape.dart';
import 'segmented.dart';

/// The listening drill's play button: a `primary` cookie shape that turns a
/// half turn, with a spring, each time it is pressed, and a speaker icon that
/// becomes a pause icon while [playing].
///
/// 136 in listening, 104 in minimal pairs. Screen readers hear "Play the
/// word", or "Playing" while it plays.
class PlayButton extends StatefulWidget {
  const PlayButton({
    super.key,
    required this.onPressed,
    this.playing = false,
    this.size = 136,
  });

  final VoidCallback? onPressed;
  final bool playing;
  final double size;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
  double _turns = 0;

  void _press() {
    setState(() => _turns += 0.5);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.playing ? l10n.drillPlaying : l10n.drillPlay,
      excludeSemantics: true,
      onTap: widget.onPressed == null ? null : _press,
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
                color: scheme.primary,
                shape: const ExpressiveShapeBorder(ExpressiveShape.cookie),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onPressed == null ? null : _press,
                  child: SizedBox.square(dimension: widget.size),
                ),
              ),
            ),
            IgnorePointer(
              child: Icon(
                widget.playing ? Icons.pause : Icons.volume_up_outlined,
                size: widget.size * 0.32,
                color: scheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
