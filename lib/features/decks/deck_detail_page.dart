import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';

/// One deck: counts, practise one skill, only these tags, a card preview,
/// licence, source, voice and id, and Review all due.
///
/// Design screens `deck` and `deck-novoice`. A Phase 0 stub that shows only
/// the deck's name; B2 replaces the body, keeping the class name and the
/// required `deckId`, which `AppRoutes` depends on. Optional parameters may
/// be added.
class DeckDetailPage extends StatelessWidget {
  const DeckDetailPage({super.key, required this.deckId});

  /// The deck to show, by its id.
  final String deckId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entry = AppScope.of(context).deckById(deckId);
    return PlaceholderPage(title: entry?.deck.name ?? l10n.deckNotFound);
  }
}
