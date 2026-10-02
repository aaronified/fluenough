import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../app/skill.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/mode_pill.dart';
import 'deck_content.dart';

/// "Practise one skill": a row per skill the deck offers, each starting a
/// session on the deck in that skill alone.
///
/// A row is in one of three states, kept apart as ADR-0008 asks:
///
/// - **live**: the skill's pill, and a button with the number the session
///   would drill, which starts `DrillRequest.deck(id, skill:, tags:)`;
/// - **missing on this phone**: a skill that needs a voice, on a phone
///   without one for the language — a muted pill, `deckNoVoice`, and Set up,
///   which opens Voices; and speaking, where the phone cannot recognise the
///   language, or only online without the learner's leave, the same way;
/// - **set aside**: a skill switched off for this language, or paused
///   (#89) — a muted pill, why, and Turn on or Resume;
/// - **incoming**: a skill whose drill is not built yet, such as grammar
///   (#2) — dimmed, with the badge.
class SkillSection extends StatelessWidget {
  const SkillSection({
    super.key,
    required this.entry,
    this.tags = const <String>{},
  });

  final DeckEntry entry;

  /// The tags chosen in "Only these tags"; a session drills only cards
  /// carrying one of them. Empty means every card.
  final Set<String> tags;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final skills = deckSkills(entry, state.settings);
    if (skills.isEmpty) return const SizedBox.shrink();
    return GroupedList(
      header: l10n.deckPractiseOne,
      children: <Widget>[for (final skill in skills) _row(context, skill)],
    );
  }

  /// The line under [skill]. On a reading deck, listening is hearing a
  /// passage, not typing a word (#98).
  String _description(AppLocalizations l10n, Skill skill) =>
      skill == Skill.listening && entry.deck.kind == DeckKind.reading
      ? l10n.skillListeningReadingDeckDesc
      : skill.deckDescription(l10n, entry.language.name);

  Widget _row(BuildContext context, Skill skill) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final state = AppScope.of(context);
    final language = entry.language;
    const padding = EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12);
    const leadingGap = 14.0;
    const trailingGap = 12.0;

    if (isIncoming(context, skill.feature)) {
      return GroupedTile(
        feature: skill.feature,
        padding: padding,
        leadingGap: leadingGap,
        leading: ModePill(skill: skill, size: ModePillSize.large),
        title: skill.label(l10n),
        subtitle: _description(l10n, skill),
      );
    }

    // Switched off for this language, or paused (#89): muted, with the way
    // back.
    final settings = state.settings;
    final pausedUntil = settings.pausedUntil(skill);
    if (skill.pausable &&
        (settings.isOffFor(skill, language.code) ||
            (pausedUntil != null && pausedUntil.isAfter(state.now())))) {
      final off = settings.isOffFor(skill, language.code);
      return GroupedTile(
        padding: padding,
        leadingGap: leadingGap,
        trailingGap: trailingGap,
        leading: ModePill(skill: skill, size: ModePillSize.large, muted: true),
        title: skill.label(l10n),
        titleColor: scheme.onSurfaceVariant,
        subtitle: off
            ? l10n.deckSkillOffFor(language.name)
            : l10n.settingsPausedUntil(
                MaterialLocalizations.of(context)
                    .formatTimeOfDay(TimeOfDay.fromDateTime(pausedUntil!)),
              ),
        trailing: OutlinedButton(
          style: AppButtonStyles.compact(context)
              .merge(OutlinedButton.styleFrom(foregroundColor: scheme.primary)),
          onPressed: off
              ? () => settings.setOffFor(skill, language.code, false)
              : () => settings.resume(skill),
          child: Text(off ? l10n.deckTurnOn : l10n.settingsResume),
        ),
      );
    }

    final String? missing;
    if (skill.needsVoice && !state.hasVoice(language)) {
      missing = l10n.deckNoVoice(language.name);
    } else if (skill.needsMicrophone) {
      missing = switch (state.speechStatus(language)) {
        SpeechStatus.onDevice ||
        SpeechStatus.online ||
        SpeechStatus.checking => null,
        SpeechStatus.onlineOnly => l10n.deckSpeechOnlineOnly(language.name),
        SpeechStatus.off ||
        SpeechStatus.missing => l10n.deckNoSpeech(language.name),
      };
    } else {
      missing = null;
    }
    if (missing != null) {
      return GroupedTile(
        padding: padding,
        leadingGap: leadingGap,
        trailingGap: trailingGap,
        leading: ModePill(skill: skill, size: ModePillSize.large, muted: true),
        title: skill.label(l10n),
        titleColor: scheme.onSurfaceVariant,
        subtitle: missing,
        trailing: OutlinedButton(
          style: AppButtonStyles.compact(context)
              .merge(OutlinedButton.styleFrom(foregroundColor: scheme.primary)),
          onPressed: () => AppNavigator.openVoices(context),
          child: Text(l10n.deckSetUpVoice),
        ),
      );
    }

    final request = DrillRequest.deck(entry.id, skill: skill, tags: tags);
    final count = state.buildSession(request).items.length;
    final label = skill.label(l10n);
    return GroupedTile(
      padding: padding,
      leadingGap: leadingGap,
      trailingGap: trailingGap,
      leading: ModePill(skill: skill, size: ModePillSize.large),
      title: label,
      subtitle: _description(l10n, skill),
      trailing: FilledButton.tonalIcon(
        style: AppButtonStyles.compact(context)
            .merge(const ButtonStyle(iconAlignment: IconAlignment.end)),
        onPressed: count == 0
            ? null
            : () => AppNavigator.startDrill(context, request),
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: Text(
          formatCount(context, count),
          semanticsLabel: l10n.deckStartSkill(label, count),
        ),
      ),
    );
  }
}
