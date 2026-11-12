import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/culture.dart';
import '../../core/models/creator.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/widgets/target_text.dart';
import 'culture_parts.dart';
import 'culture_timeline.dart';

/// The creator card as a bottom sheet (approved mockup `culture-in-course`,
/// screen 3): the picture with its credit and licence line, or the placeholder
/// and that there is no licensed image yet; the name in the language learned
/// and the spoken one, dates and the era in the language's own tradition; the
/// bio at the learner's level; "Still alive today"; and the timeline.
///
/// Opened from the creator chip of an item and the People list of the culture
/// deck. A creator the file does not have opens nothing.
Future<void> showCreatorSheet(
  BuildContext context, {
  required String language,
  required String creatorId,
}) {
  final state = AppScope.read(context);
  final creator = state.creatorsOf(language)?.byId(creatorId);
  if (creator == null) {
    state.log.warning('Creator $creatorId of $language is not in its file');
    return Future<void>.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) =>
        CreatorCard(language: language, creator: creator),
  );
}

/// The creator card's content.
class CreatorCard extends StatelessWidget {
  const CreatorCard({super.key, required this.language, required this.creator});

  final String language;
  final Creator creator;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final info = cultureLanguage(state, language);
    final file = state.creatorsOf(language);
    final spoken = cultureSpoken(context, state);
    final level = state.levelIn(language);
    final name = creator.nameFor(spoken, target: language).text;
    final bio = creator.bioFor(spoken);
    final bioTarget = creator.bioTargetFor(level);
    final legacy = creator.legacyFor(level, spoken);
    final image = creator.image;
    final licenceUrl = image?.licenceUrl ?? image?.sourceUrl;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: CreatorSummary(
                creator: creator,
                language: info,
                file: file,
                size: 96,
                large: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              cultureImageCredit(l10n, creator),
              style: theme.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (licenceUrl != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  style: AppButtonStyles.inline(context),
                  onPressed: () => openLink(
                    context,
                    licenceUrl,
                    copied: l10n.cultureLinkCopied,
                  ),
                  child: Text(l10n.cultureImageLicenceLink),
                ),
              ),
            if (bio.isNotEmpty || bioTarget != null) ...<Widget>[
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(
                  l10n.cultureAbout(name),
                  style: theme.textTheme.titleSmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (bioTarget != null) ...<Widget>[
                TargetText(
                  bioTarget.text,
                  language: info,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  textAlign: TextAlign.start,
                ),
                if (bioTarget.reading != null)
                  Text(
                    bioTarget.reading!,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 4),
              ],
              if (bio.isNotEmpty) Text(bio, style: theme.textTheme.bodyMedium),
            ],
            if (legacy != null) ...<Widget>[
              const SizedBox(height: 14),
              LegacyBlock(view: legacy, language: info),
            ],
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(
                l10n.cultureTimelineHeading,
                style: theme.textTheme.titleSmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            TimelineStrip(language: language, creatorId: creator.id),
          ],
        ),
      ),
    );
  }
}

/// The creator [creatorId] of [language] as a tappable line that opens their
/// card: the person's picture, names, dates and era, with a chevron.
class CreatorChip extends StatelessWidget {
  const CreatorChip({
    super.key,
    required this.language,
    required this.creatorId,
    this.showLegacyLine = true,
  });

  final String language;
  final String creatorId;
  final bool showLegacyLine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final file = state.creatorsOf(language);
    final creator = file?.byId(creatorId);
    if (creator == null) return const SizedBox.shrink();
    final info = cultureLanguage(state, language);
    final spoken = cultureSpoken(context, state);
    final legacy = showLegacyLine
        ? creator.legacyFor(state.levelIn(language), spoken)
        : null;
    final line = _legacyLine(legacy, spoken);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          hint: l10n.cultureCreatorOpens,
          child: Material(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.field),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showCreatorSheet(
                context,
                language: language,
                creatorId: creatorId,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: CreatorSummary(
                        creator: creator,
                        language: info,
                        file: file,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (line != null) ...<Widget>[
          const SizedBox(height: 10),
          LegacyBlock(view: line, lineOnly: true),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4, start: 4),
            child: Text(
              l10n.cultureLegacyMore,
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// The legacy cut to its first line, for the inline view.
  LegacyView? _legacyLine(LegacyView? view, List<String> spoken) {
    if (view == null) return null;
    final first = view.text.isNotEmpty
        ? view.text
        : view.items.isEmpty
        ? ''
        : view.items.first.textFor(spoken);
    if (first.isEmpty) return null;
    return LegacyView(text: first, items: const <LegacyItem>[]);
  }
}

/// A creator row of a list: picture, name, dates; a tap opens the card.
class CreatorRow extends StatelessWidget {
  const CreatorRow({super.key, required this.language, required this.creator});

  final String language;
  final Creator creator;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final info = cultureLanguage(state, language);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => showCreatorSheet(
          context,
          language: language,
          creatorId: creator.id,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: CreatorSummary(
                  creator: creator,
                  language: info,
                  file: state.creatorsOf(language),
                  size: 44,
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
