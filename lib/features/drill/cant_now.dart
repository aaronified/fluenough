import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/skill.dart';
import '../../l10n/app_localizations.dart';
import 'drill_session.dart';

/// "Can't speak now" or "Can't listen now" (#89), on a speaking or listening
/// card from the moment it shows: pause the skill for an hour, or switch it
/// off for the card's language or everywhere. The rest of the session skips
/// what the choice reaches, unrecorded; Settings turns it back on.
class CantNowButton extends StatelessWidget {
  const CantNowButton({super.key, required this.session});

  final DrillSession session;

  /// How long a pause lasts.
  static const Duration pause = Duration(hours: 1);

  Future<void> _choose(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final settings = state.settings;
    final skill = session.skill;
    final language = session.deck.language;
    final choice = await showModalBottomSheet<_Choice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(l10n.cantNowPause),
              onTap: () => Navigator.of(context).pop(_Choice.pause),
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: Text(l10n.cantNowOffFor(language.name)),
              onTap: () => Navigator.of(context).pop(_Choice.offForLanguage),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(l10n.cantNowOffEverywhere),
              onTap: () => Navigator.of(context).pop(_Choice.offEverywhere),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
              child: Text(
                l10n.cantNowHint,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    switch (choice) {
      case null:
        return;
      case _Choice.pause:
        settings.pause(skill, until: state.now().add(pause));
        session.skipSkill();
      case _Choice.offForLanguage:
        settings.setOffFor(skill, language.code, true);
        session.skipSkill(onlyLanguage: language.code);
      case _Choice.offEverywhere:
        if (skill == Skill.speaking) {
          await state.setSpeaking(false);
        } else {
          settings.setSkillEnabled(skill, false);
        }
        session.skipSkill();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextButton.icon(
      onPressed: () => _choose(context),
      icon: Icon(
        session.skill == Skill.speaking
            ? Icons.mic_off_outlined
            : Icons.hearing_disabled_outlined,
      ),
      label: Text(
        session.skill == Skill.speaking
            ? l10n.drillCantSpeak
            : l10n.drillCantListen,
        textAlign: TextAlign.center,
      ),
    );
  }
}

enum _Choice { pause, offForLanguage, offEverywhere }
