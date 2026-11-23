import 'dart:async';

import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../core/models/card.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/hint.dart';
import '../../ui/widgets/snack.dart';
import '../downloads/download_page.dart';

/// "The sounds of this word": opens a session of the IPA course's cards whose
/// symbols occur in the word's IPA, recorded in the IPA course (owner,
/// 2026-10-16: "Yes, recorded"). Shown on every card that has an IPA; for a
/// learner who is not learning the IPA it first offers to add the course
/// (owner, 2026-10-16: "Show, offer to add").
///
/// The IPA course is a dependency of every language, read when the catalog is
/// read one language at a time (ADR-0062): the button is shown from the card's
/// IPA and enabled once the course's unit is read, which the button asks for
/// when it first shows.
class SoundsOfWordButton extends StatefulWidget {
  const SoundsOfWordButton({super.key, required this.card});

  final Card card;

  @override
  State<SoundsOfWordButton> createState() => _SoundsOfWordButtonState();
}

class _SoundsOfWordButtonState extends State<SoundsOfWordButton> {
  @override
  void initState() {
    super.initState();
    if (widget.card.ipa != null) {
      unawaited(AppScope.read(context).ensureIpaReady());
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    if (card.ipa == null) return const SizedBox.shrink();
    final state = AppScope.of(context);
    final language = state.deckOf(card)?.language;
    // The IPA's own cards are the sounds already.
    if (language == null || language.isIpa) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return LabelledIconButton(
      label: l10n.soundsOfWordLabel,
      hint: l10n.soundsOfWordButton,
      onPressed: state.ipaReady ? () => openSoundsOfWord(context, card) : null,
      icon: const Icon(Icons.graphic_eq),
    );
  }
}

/// Asks a learner not learning the IPA whether to add the course, and
/// downloads it if it is not on the phone yet. False when they decline or
/// leave.
Future<bool> _ensureIpaCourse(BuildContext context) async {
  final state = AppScope.read(context);
  final l10n = AppLocalizations.of(context)!;
  if (!state.learnsIpa) {
    final add = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.soundsOfWordOfferTitle),
        content: Text(l10n.soundsOfWordOfferBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.soundsOfWordOfferNotNow),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.soundsOfWordOfferAdd),
          ),
        ],
      ),
    );
    if (add != true || !context.mounted) return false;
    state.addIpaCourse();
  }
  if (state.languagesToDownload(const <String>['ipa']).isNotEmpty) {
    final ready = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => DownloadPage(
          languages: const <String>['ipa'],
          onReady: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (ready != true || !context.mounted) return false;
  }
  return true;
}

/// Opens the session of [card]'s sounds. A learner not learning the IPA is
/// asked first whether to add the course, and the course is downloaded if it
/// is not on the phone yet.
Future<void> openSoundsOfWord(BuildContext context, Card card) async {
  if (!await _ensureIpaCourse(context) || !context.mounted) return;
  final state = AppScope.read(context);
  // The unit of the IPA course, which a download of it has just put on the
  // phone, may not be read yet.
  await state.ensureIpaReady();
  if (!context.mounted) return;
  final request = state.soundsOfWordRequest(card);
  if (request == null) {
    showAppSnackBar(context, AppLocalizations.of(context)!.soundsOfWordNone);
    return;
  }
  await AppNavigator.startDrill(context, request);
}

/// Opens the practice of one sound, [symbol], a card of the IPA course, as
/// "The sounds of this word" does for all of a word's: recorded in the IPA
/// course. The course is offered and downloaded first where it is not
/// there.
Future<void> openSoundPractice(BuildContext context, Card symbol) async {
  if (!await _ensureIpaCourse(context) || !context.mounted) return;
  await AppNavigator.startDrill(
    context,
    DrillRequest.sounds(<String>{symbol.id}),
  );
}
