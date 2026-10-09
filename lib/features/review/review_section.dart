import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/snack.dart';
import '../decks/path_parts.dart' show joinParts;
import 'how_reviewing_works.dart';
import 'review_waiting.dart';
import 'send_reviews_sheet.dart';
import 'waiting_page.dart';

/// Settings' Reviewing group (docs/plans/deck-browser.md): the "Review
/// decks" switch, which asks once and then shows the rater code the phone
/// made, with Copy; the languages the reviewer reviews, and what waits for
/// review in them; the decks waiting to send; "Send the last mail again",
/// for a mail that never went; the decks the reviewer helped build; and
/// "How reviewing works", which opens by itself the first time reviewing is
/// turned on.
///
/// Turning reviewing off keeps the code and the reviews.
class ReviewSection extends StatelessWidget {
  const ReviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // What it shows is kept in the settings, which notify on their own.
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) => _build(context, state),
    );
  }

  Widget _build(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final reviewing = state.reviewing;
    final code = reviewing.code;
    final on = reviewing.on && code != null;
    final waiting = reviewing.unsent.length;
    final lastSent = reviewing.lastSent.length;
    final reviewed = on ? reviewLanguagesOf(state) : const <LanguageInfo>[];
    final toReview = <String>{
      for (final language in reviewed)
        for (final deck in state.decks)
          if (deck.language.code == language.code && awaitsReview(state, deck))
            deck.id,
    }.length;
    final helped = <String>[
      if (code != null)
        for (final entry in state.decks)
          if (reviewing.helpedBuild(entry))
            l10n.reviewSettingsHelpedDeck(entry.deck.name, entry.language.name),
    ];
    return GroupedList.settings(
      header: l10n.reviewSettingsSection,
      children: <Widget>[
        GroupedTile.toggle(
          leading: const Icon(Icons.rate_review_outlined),
          title: l10n.reviewSettingsSwitch,
          subtitleOn: l10n.reviewSettingsSwitchOn,
          subtitleOff: l10n.reviewSettingsSwitchOff,
          value: on,
          onChanged: (value) =>
              value ? _turnOn(context, state) : reviewing.turnOff(),
        ),
        if (on)
          GroupedTile(
            leading: const Icon(Icons.key_outlined),
            title: l10n.reviewSettingsCode,
            subtitle: '$code',
            trailing: IconButton(
              tooltip: l10n.reviewSettingsCopy,
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: '$code'));
                if (context.mounted) {
                  showAppSnackBar(context, l10n.reviewSettingsCopied);
                }
              },
            ),
          ),
        if (on) ...<Widget>[
          GroupedTile(
            leading: const Icon(Icons.translate_outlined),
            title: l10n.reviewSettingsLanguages,
            subtitle: reviewed.isEmpty
                ? l10n.reviewSettingsLanguagesNone
                : joinParts(l10n, <String>[for (final l in reviewed) l.name]),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showReviewLanguages(context),
          ),
          GroupedTile(
            leading: const Icon(Icons.pending_actions_outlined),
            title: l10n.reviewSettingsWaiting,
            subtitle: l10n.reviewSettingsWaitingDesc(toReview),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => AppNavigator.openWaitingForReview(context),
          ),
        ],
        if (waiting > 0)
          GroupedTile(
            leading: const Icon(Icons.outbox_outlined),
            title: l10n.reviewSettingsToSend,
            subtitle: l10n.reviewDecksWaiting(waiting),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showSendReviews(context),
          ),
        if (code != null && lastSent > 0)
          GroupedTile(
            leading: const Icon(Icons.replay_outlined),
            title: l10n.reviewSettingsSendAgain,
            subtitle: l10n.reviewSettingsSendAgainDesc(lastSent),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              reviewing.sendAgain();
              showSendReviews(context);
            },
          ),
        if (helped.isNotEmpty)
          GroupedTile(
            leading: const Icon(Icons.favorite_outline),
            title: l10n.reviewSettingsHelped,
            subtitle: helped.join('\n'),
          ),
        GroupedTile(
          leading: const Icon(Icons.info_outline),
          title: l10n.reviewSettingsHow,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showHowReviewingWorks(context),
        ),
      ],
    );
  }

  /// Asks once, then turns reviewing on, and the first time opens "How
  /// reviewing works" by itself.
  static Future<void> _turnOn(BuildContext context, AppState state) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final muted = Theme.of(context).textTheme.bodyMedium!
            .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
        return AlertDialog(
          title: Text(l10n.reviewTurnOnTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: <Widget>[
                Text(l10n.reviewTurnOnBody, style: muted),
                Text(l10n.reviewTurnOnMany, style: muted),
                Text(l10n.reviewTurnOnPublic, style: muted),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.reviewTurnOn),
            ),
          ],
        );
      },
    );
    if (yes != true) return;
    final first = state.reviewing.turnOn();
    if (first && context.mounted) await showHowReviewingWorks(context);
  }
}
