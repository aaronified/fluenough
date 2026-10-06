import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/snack.dart';

/// Match pairs' one speaker button (ADR-0032): it switches whether a word
/// tile says its word when it is tapped, `SettingsNotifier.matchTapToHear`,
/// remembered between sessions and on to begin with.
///
/// Built as `SpeakerIcon` is, and shown only where the phone has a voice for
/// the language. While sound is off in Settings it is greyed out and crossed
/// out, and a tap says so instead of switching anything, as a speaker's does.
/// Screen readers hear what it does and its state, "Hear words when tapped,
/// on", and the state again when it changes.
class MatchHearToggle extends StatelessWidget {
  const MatchHearToggle({super.key});

  /// The button is this square, the least a tap target should be.
  static const double size = 48;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final muted = !settings.soundOn;
        final on = settings.matchTapToHear;
        String labelOf(bool state) =>
            state ? l10n.drillMatchHearOn : l10n.drillMatchHearOff;
        void tap() {
          if (muted) {
            showAppSnackBar(context, l10n.speakerSoundOff);
            return;
          }
          settings.matchTapToHear = !on;
          // The state is in the label, which a screen reader does not read
          // again by itself when it changes.
          SemanticsService.sendAnnouncement(
            View.of(context),
            labelOf(!on),
            Directionality.of(context),
          );
        }

        final lit = on && !muted;
        return Semantics(
          button: true,
          label: labelOf(on),
          value: muted ? l10n.speakerMuted : null,
          excludeSemantics: true,
          onTap: tap,
          child: Tooltip(
            message: labelOf(on),
            child: InkResponse(
              onTap: tap,
              radius: size / 2,
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: lit ? scheme.secondaryContainer : null,
                    ),
                    child: SizedBox.square(
                      dimension: size - 8,
                      child: Icon(
                        lit
                            ? Icons.volume_up_outlined
                            : Icons.volume_off_outlined,
                        color: lit
                            ? scheme.onSecondaryContainer
                            : muted
                            ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
