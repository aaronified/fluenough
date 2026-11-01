import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../app/situations.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/bottom_actions.dart';
import '../decks/word_sheet.dart';
import 'situation_page.dart';

/// A sheet's cards in full, one at a time (#724; mockup
/// `docs/mockups/situations.html`, screen 3): the card's whole word sheet
/// (script, reading, audio, notes, examples, IPA, id and where the learner
/// stands), numbered chips to jump to a card with a dot on those not learnt
/// yet, and "Open in deck". The cards are swiped between (owner, 2026-10-31:
/// swipe is universal across deck viewing); there are no Previous and Next
/// buttons.
class SituationInspectPage extends StatefulWidget {
  const SituationInspectPage({super.key, required this.request});

  final SituationRequest request;

  @override
  State<SituationInspectPage> createState() => _SituationInspectPageState();
}

class _SituationInspectPageState extends State<SituationInspectPage> {
  late int _index = widget.request.index;
  late final PageController _pages = PageController(
    initialPage: widget.request.index,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// The chip's jump: the pages slide there, or switch at once with the
  /// phone's reduce-motion setting on.
  void _jump(int i) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(i);
    } else {
      _pages.animateToPage(
        i,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final file = state.situationsOf(widget.request.language);
    final sheet = file?.byId(widget.request.situationId);
    final cards = sheet == null
        ? const <SheetCard>[]
        : state.sheetCards(widget.request.language, sheet.cardIds);
    if (sheet == null || cards.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final index = _index.clamp(0, cards.length - 1);
    final item = cards[index];
    final spoken = state.settings.spokenLanguages;
    final others = <String>[
      for (final other in file!.situations)
        if (other.id != sheet.id && other.cardIds.contains(item.card.id))
          other.titleFor(spoken),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.situationInspectTitle(
            sheet.titleFor(spoken),
            index + 1,
            cards.length,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
            child: Row(
              spacing: 8,
              children: <Widget>[
                for (final (i, c) in cards.indexed)
                  Semantics(
                    button: true,
                    selected: i == index,
                    label: c.isNew
                        ? '${l10n.situationCardJump(i + 1)}, '
                              '${l10n.situationNotLearnt}'
                        : l10n.situationCardJump(i + 1),
                    excludeSemantics: true,
                    onTap: () => _jump(i),
                    child: ChoiceChip(
                      selected: i == index,
                      onSelected: (_) => _jump(i),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: <Widget>[
                          Text('${i + 1}'),
                          if (c.isNew)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (others.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
              child: Text(
                l10n.situationAlsoOn(others.join(l10n.commonListSeparator)),
                style: Theme.of(context).textTheme.bodySmall!
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: cards.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => WordSheet(
                key: ValueKey<String>(cards[i].card.id),
                card: cards[i].card,
                language: cards[i].deck.language,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActions(
        child: FilledButton.tonal(
          onPressed: () => AppNavigator.openDeck(context, item.deck.id),
          child: Text(l10n.situationOpenInDeck),
        ),
      ),
    );
  }
}
