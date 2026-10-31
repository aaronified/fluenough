import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/situations.dart';
import '../../l10n/app_localizations.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../ui/widgets/ipa_line.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/card_bases.dart';
import '../decks/ipa_info_dot.dart';
import 'situation_page.dart';

/// A sheet's cards, one at a time, swiped between (#724; owner, 2026-10-31:
/// swipe is universal across deck viewing and swipe-only, and a situation is
/// quick help, so a card shows only what is needed in the moment). Each page
/// holds the phrase in script, its reading, a speaker, its IPA with an info
/// dot (whose popup explains the sounds, [IpaInfoDot]) and its meaning, and
/// below it, by scrolling, its root words (owner, 2026-10-31).
/// Numbered chips, with a dot on those not learnt yet, show where the learner
/// is and jump to a card. No Previous, Next or "Open in deck": a swipe moves
/// between cards, and the whole word sheet is on the deck's page.
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
    final spoken = state.settings.spokenLanguages;
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
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: cards.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _CardPage(
                key: ValueKey<String>(cards[i].card.id),
                card: cards[i].card,
                language: cards[i].deck.language,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One card of a sheet: only what is needed in the moment.
class _CardPage extends StatelessWidget {
  const _CardPage({super.key, required this.card, required this.language});

  final Card card;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    return ListenableBuilder(
      // IPA pronunciations is a setting: off, the IPA and its dot go.
      listenable: state.settings,
      builder: (context, _) {
        final reading = card.reading;
        final ipa = ipaToShow(context, card.ipa, target: card.target);
        // The root words help memory: below the meaning, by scrolling.
        final bases = basesOf(state, card, language);
        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: TargetText(
                      card.target,
                      language: language,
                      fontSize: 52,
                      fontWeight: FontWeight.w500,
                      textAlign: TextAlign.start,
                      card: card,
                    ),
                  ),
                  if (reading != null)
                    Text(
                      reading,
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  Row(
                    children: <Widget>[
                      if (state.hasVoice(language))
                        SpeakerIcon(
                          onPlay: () => state.speakCard(card, language),
                          label: l10n.drillPlay,
                        ),
                      if (ipa != null) ...<Widget>[
                        Flexible(
                          child: IpaLine(ipa, textAlign: TextAlign.start),
                        ),
                        IpaInfoDot(card: card),
                      ],
                    ],
                  ),
                  Text(
                    card.native,
                    style: theme.textTheme.headlineSmall!.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (bases.isNotEmpty)
                    BaseLine(bases: bases, language: language),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
