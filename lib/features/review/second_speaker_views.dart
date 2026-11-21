import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../core/review/facet_text.dart';
import '../../core/review/facets.dart';
import '../../core/review/flagged_queue.dart';
import '../../core/review/review_quorum.dart';
import '../../core/review/review_receipt.dart';
import '../../core/review/review_session.dart';
import '../../core/review/second_speaker.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'facet_labels.dart';
import 'facet_tags_sheet.dart';

/// What a second speaker sees on a flagged facet (ADR-0058, decision 7;
/// docs/mockups/reviewer-ux.html, frames 3b and 3c): another speaker's
/// proposed fix beside what the card says now, with "Accept", "Reject" and
/// "Offer another"; or the rival fixes, to pick one; or, for a tag with no
/// fix, what the card says now, to call right or to fix. Every answer goes
/// through `Reviewing.answerFacet` with the receipt that says what it was.
class SecondSpeakerStepView extends StatelessWidget {
  const SecondSpeakerStepView({
    super.key,
    required this.step,
    required this.deck,
    required this.card,
    required this.onDone,
  });

  final SecondSpeakerStep step;
  final DeckEntry deck;
  final Card card;

  /// Called once an answer is given.
  final VoidCallback onDone;

  static const Key acceptKey = ValueKey<String>('second-accept');
  static const Key rejectKey = ValueKey<String>('second-reject');
  static const Key offerKey = ValueKey<String>('second-offer');
  static const Key rightKey = ValueKey<String>('second-right');
  static const Key chooseKey = ValueKey<String>('second-choose');
  static const Key noneKey = ValueKey<String>('second-none');

  /// The option holding rival fix number [i].
  static Key fixKey(int i) => ValueKey<String>('second-fix-$i');

  /// The option holding what the card says now, among rival fixes.
  static const Key nowKey = ValueKey<String>('second-now');

  FlaggedFacet get _flagged => FlaggedFacet(
    facet: step.facet,
    status: FacetStatus.flagged,
    tags: step.tags,
    existingFix: switch (step) {
      ProposalStep(:final proposed) => proposed,
      _ => null,
    },
  );

  void _give(
    BuildContext context,
    FacetAnswer answer,
    ReceiptDecision decision,
  ) {
    AppScope.read(context).reviewing
        .answerFacet(deck, card, step.facet, answer, decision: decision);
    onDone();
  }

  /// "Offer another": the tags sheet, then the answer it gives.
  Future<void> _offer(BuildContext context) async {
    final answer = await showFacetTagsSheet(
      context,
      card: card,
      facet: step.facet,
      languageName: deck.language.name,
      current: FacetAnswer.flagged(step.tags.toSet()),
    );
    if (answer == null || !context.mounted) return;
    final resolved = answer.hasReplacement
        ? resolveFlagged(
            _flagged,
            FlaggedResolution.offerFix,
            fix: answer.replacement,
          )
        : null;
    _give(context, answer, resolved?.decision ?? ReceiptDecision.flagged);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = Text(
      facetTitle(l10n, step.facet).toUpperCase(),
      style: theme.textTheme.labelSmall!.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
    final buttons = switch (step) {
      ProposalStep() => <Widget>[
        FilledButton(
          key: SecondSpeakerStepView.acceptKey,
          style: _tall,
          onPressed: () {
            final a = resolveFlagged(_flagged, FlaggedResolution.agreeWithFix)!;
            _give(context, a.answer, a.decision);
          },
          child: Text(l10n.reviewSecondAccept),
        ),
        OutlinedButton(
          key: SecondSpeakerStepView.rejectKey,
          style: _tallOut,
          onPressed: () => _give(
            context,
            const FacetAnswer.right(),
            ReceiptDecision.rejected,
          ),
          child: Text(l10n.reviewSecondReject),
        ),
        TextButton(
          key: SecondSpeakerStepView.offerKey,
          style: _tallOut,
          onPressed: () => _offer(context),
          child: Text(l10n.reviewSecondOffer),
        ),
      ],
      FlagStep() => <Widget>[
        FilledButton(
          key: SecondSpeakerStepView.rightKey,
          style: _tall,
          onPressed: () {
            final a = resolveFlagged(_flagged, FlaggedResolution.right)!;
            _give(context, a.answer, a.decision);
          },
          child: Text(l10n.reviewSecondRight),
        ),
        TextButton(
          key: SecondSpeakerStepView.offerKey,
          style: _tallOut,
          onPressed: () => _offer(context),
          child: Text(l10n.reviewSecondFix),
        ),
      ],
      RivalStep() => const <Widget>[],
    };
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
      children: <Widget>[
        label,
        const SizedBox(height: 6),
        switch (step) {
          final ProposalStep s => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: <Widget>[
              Expanded(
                child: _Box(label: l10n.reviewSecondNow, text: s.original),
              ),
              Expanded(
                child: _Box(
                  label: l10n.reviewSecondProposed,
                  text: s.proposed,
                  emphasised: true,
                ),
              ),
            ],
          ),
          final RivalStep s => _Rivals(
            step: s,
            onChoose: (fix) {
              if (fix == null) {
                _give(
                  context,
                  FacetAnswer.flagged(step.tags.toSet()),
                  ReceiptDecision.rejected,
                );
              } else if (fix.isEmpty) {
                final a = resolveFlagged(_flagged, FlaggedResolution.right)!;
                _give(context, a.answer, a.decision);
              } else {
                final a = resolveFlagged(
                  FlaggedFacet(
                    facet: step.facet,
                    status: FacetStatus.contested,
                    tags: step.tags,
                    existingFix: fix,
                  ),
                  FlaggedResolution.agreeWithFix,
                )!;
                _give(context, a.answer, a.decision);
              }
            },
            onOffer: () => _offer(context),
          ),
          final FlagStep s => _Box(
            label: l10n.reviewSecondNow,
            text: s.original,
          ),
        },
        if (buttons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: buttons,
            ),
          ),
      ],
    );
  }

  static final ButtonStyle _tall = FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
  );
  static final ButtonStyle _tallOut = ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
  );
}

/// A labelled box of text; [emphasised] outlines it in the accent colour.
class _Box extends StatelessWidget {
  const _Box({
    required this.label,
    required this.text,
    this.emphasised = false,
  });

  final String label;
  final String text;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: emphasised ? Border.all(color: scheme.primary, width: 2) : null,
      ),
      child: Semantics(
        container: true,
        label: '$label: $text',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall!.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// The pick-one list of rival fixes (frame 3c): what the card says now, each
/// fix, and "None of these". [onChoose] gets the fix chosen, an empty string
/// for what the card says now, or null for "None of these".
class _Rivals extends StatefulWidget {
  const _Rivals({
    required this.step,
    required this.onChoose,
    required this.onOffer,
  });

  final RivalStep step;
  final void Function(String? fix) onChoose;
  final VoidCallback onOffer;

  @override
  State<_Rivals> createState() => _RivalsState();
}

class _RivalsState extends State<_Rivals> {
  /// -2 nothing, -1 what the card says now, 0.. a fix, [none] none of them.
  static const int none = 1 << 20;
  int _picked = -2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fixes = widget.step.fixes;
    Widget option(Key key, int value, String text, {String? small}) {
      final on = _picked == value;
      return Semantics(
        inMutuallyExclusiveGroup: true,
        checked: on,
        button: true,
        label: small == null ? text : '$text, $small',
        excludeSemantics: true,
        onTap: () => setState(() => _picked = value),
        // hint-ok: shows text
        child: InkWell(
          key: key,
          onTap: () => setState(() => _picked = value),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: <Widget>[
                Icon(
                  on ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                  color: on ? scheme.primary : scheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(text, style: theme.textTheme.bodyMedium),
                      if (small != null)
                        Text(
                          small,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        option(
          SecondSpeakerStepView.nowKey,
          -1,
          widget.step.original,
          small: l10n.reviewSecondNow,
        ),
        for (final (i, fix) in fixes.indexed)
          option(SecondSpeakerStepView.fixKey(i), i, fix),
        option(SecondSpeakerStepView.noneKey, none, l10n.reviewRivalNone),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: <Widget>[
              FilledButton(
                key: SecondSpeakerStepView.chooseKey,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _picked == -2
                    ? null
                    : () => widget.onChoose(switch (_picked) {
                        -1 => '',
                        none => null,
                        final i => fixes[i],
                      }),
                child: Text(l10n.reviewRivalChoose),
              ),
              TextButton(
                key: SecondSpeakerStepView.offerKey,
                style: ButtonStyle(
                  minimumSize: WidgetStateProperty.all(
                    const Size.fromHeight(48),
                  ),
                ),
                onPressed: widget.onOffer,
                child: Text(l10n.reviewSecondOffer),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A unit's digest (frame 3d): a row for each facet another speaker changed
/// or speakers contest, with a tick and a flag for the reviewer's own
/// verdict. The reason a first speaker gave is shown only once the reviewer
/// has given their verdict on the row. A "Done" button at the end goes on.
class ReviewDigestView extends StatelessWidget {
  const ReviewDigestView({
    super.key,
    required this.items,
    required this.source,
    required this.onDone,
  });

  final List<DigestItem> items;
  final ReviewSource source;
  final VoidCallback onDone;

  /// The row of [item].
  static Key rowKey(DigestItem item) => ValueKey<String>('digest-${item.id}');
  static Key tickKey(DigestItem item) =>
      ValueKey<String>('digest-tick-${item.id}');
  static Key flagKey(DigestItem item) =>
      ValueKey<String>('digest-flag-${item.id}');
  static Key reasonKey(DigestItem item) =>
      ValueKey<String>('digest-reason-${item.id}');
  static const Key doneKey = ValueKey<String>('digest-done');

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
          children: <Widget>[
            for (final item in items) _row(context, item),
            const SizedBox(height: 18),
            FilledButton(
              key: ReviewDigestView.doneKey,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              onPressed: onDone,
              child: Text(l10n.commonDone),
            ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, DigestItem item) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final found = source.find(item.ref);
    final deck = found == null ? null : state.deckById(found.deck.deckId);
    final card = found?.card;
    final own = deck == null || card == null
        ? null
        : state.reviewing.reviewOf(deck, card)?.facets[item.facet];
    final title = facetTitle(l10n, item.facet);
    final text = item.after == null
        ? item.before
        : l10n.reviewDigestChange(item.before, item.after!);
    final pill = item.kind == DigestKind.contested
        ? l10n.reviewFlaggedPillContested
        : l10n.reviewDigestChanged;

    void give(FacetAnswer a, ReceiptDecision d) {
      if (deck != null && card != null) {
        state.reviewing.answerFacet(deck, card, item.facet, a, decision: d);
      }
    }

    Future<void> flag() async {
      if (deck == null || card == null) return;
      final a = await showFacetTagsSheet(
        context,
        card: card,
        facet: item.facet,
        languageName: deck.language.name,
      );
      if (a == null) return;
      give(
        a,
        a.hasReplacement
            ? ReceiptDecision.offeredOther
            : ReceiptDecision.flagged,
      );
    }

    return Container(
      key: ReviewDigestView.rowKey(item),
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  container: true,
                  label: '${l10n.reviewFacetValue(title, text)}, $pill',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title.toUpperCase(),
                        style: theme.textTheme.labelSmall!.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(text, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      _Pill(label: pill),
                    ],
                  ),
                ),
              ),
              if (own == null) ...<Widget>[
                _VerdictButton(
                  key: ReviewDigestView.tickKey(item),
                  icon: Icons.check,
                  hint: l10n.hintRight,
                  label: l10n.reviewRightFacet(title),
                  onPressed: () => item.after != null
                      ? give(
                          FacetAnswer.flagged(<PointerTag>{
                            ownTagOf(item.facet),
                          }, replacement: item.after),
                          ReceiptDecision.accepted,
                        )
                      : give(const FacetAnswer.right(), ReceiptDecision.right),
                ),
                _VerdictButton(
                  key: ReviewDigestView.flagKey(item),
                  icon: Icons.flag_outlined,
                  hint: l10n.hintFlag,
                  label: l10n.reviewFlagFacet(title),
                  onPressed: flag,
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    own.isRight ? Icons.check : Icons.flag,
                    size: 22,
                    color: scheme.primary,
                    semanticLabel: own.isRight
                        ? l10n.reviewRightFacetOn(title)
                        : l10n.reviewFlagFacetOn(title),
                  ),
                ),
            ],
          ),
          if (own != null && item.reason != null)
            Container(
              key: ReviewDigestView.reasonKey(item),
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: <Widget>[
                  Icon(
                    Icons.format_quote,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Text(
                      item.reason!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VerdictButton extends StatelessWidget {
  const _VerdictButton({
    super.key,
    required this.icon,
    required this.hint,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String hint;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    excludeSemantics: true,
    onTap: onPressed,
    child: IconButton(
      tooltip: hint,
      onPressed: onPressed,
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      icon: Icon(icon, size: 22),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.labelMedium!.copyWith(
            color: scheme.onTertiaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
