import 'package:flutter/material.dart' hide Card;

import '../../app/app_state.dart';
import '../../core/decks/wiktionary_link.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/widgets/target_text.dart';
import 'card_bases.dart';

/// The Wiktionary links [card] shows on its sheet (#422): its own entry and
/// those of its base words, only where the deck marks the word as having one,
/// in the Wiktionary of the language the learner is taught from.
List<WiktionaryLink> wiktionaryLinksFor(
  AppState state,
  Card card,
  LanguageInfo language,
) {
  final native = state.deckOf(card)?.deck.native.code ?? 'en';
  return wiktionaryLinksOf(
    card,
    baseFinder(state, language: language.code, native: native),
    edition: native,
    languageCode: language.code,
    languageName: language.name,
  );
}

/// One row a link: "Wiktionary: ఇల్లు", which opens the entry in the browser.
/// Nothing is fetched until it is tapped, and where nothing can open it the
/// address is copied instead. Nothing at all for a word with no link.
class WiktionaryLinks extends StatelessWidget {
  const WiktionaryLinks({
    super.key,
    required this.links,
    required this.language,
  });

  final List<WiktionaryLink> links;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final link in links)
          TextButton.icon(
            onPressed: () => openLink(
              context,
              link.url.toString(),
              copied: l10n.sourcesLinkCopied,
            ),
            icon: const Icon(Icons.open_in_new, size: 20),
            label: Text.rich(
              quotingTarget(l10n.cardWiktionaryLink(link.word), <String>[
                link.word,
              ], language),
            ),
          ),
      ],
    );
  }
}
