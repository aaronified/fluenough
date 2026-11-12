import 'dart:typed_data';

import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/decks/weave.dart';
import '../../core/models/card_source.dart';
import '../../core/models/creator.dart';
import '../../core/models/deck.dart' show LanguageInfo;
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/result_marks.dart';

/// The languages the learner reads the interface and deck prose in, best known
/// first: the app's own language, then those they speak.
List<String> cultureSpoken(BuildContext context, AppState state) => <String>[
  Localizations.localeOf(context).languageCode,
  ...state.settings.spokenLanguages,
];

/// The language [code], or a bare one when the catalog has none (a test that
/// asks before the decks are in).
LanguageInfo cultureLanguage(AppState state, String code) {
  final found = state.languageByCode(code);
  if (found != null) return found;
  for (final language in state.languages) {
    if (language.code == code) return language;
  }
  return LanguageInfo(code: code, iso639_3: code, name: code);
}

/// What a culture item is called on its row and its page.
String cultureKindName(AppLocalizations l10n, CultureKind kind) =>
    switch (kind) {
      CultureKind.proverb => l10n.cultureKindProverb,
      CultureKind.line => l10n.cultureKindLine,
      CultureKind.passage => l10n.cultureKindPassage,
    };

/// A year as the app writes it: `1862`, `c. 1750`, `500 BCE`.
String creatorYearText(AppLocalizations l10n, CreatorYear year) {
  final base = year.year < 0 ? l10n.cultureYearBce(-year.year) : '${year.year}';
  return year.circa ? l10n.cultureYearCirca(base) : base;
}

/// A creator's dates: `1861 to 1941`, `born 1962`, or null when none is known.
String? creatorDates(AppLocalizations l10n, Creator creator) {
  final born = creator.born;
  final died = creator.died;
  if (born != null && died != null) {
    return l10n.cultureLifespan(
      creatorYearText(l10n, born),
      creatorYearText(l10n, died),
    );
  }
  if (born != null) {
    return creator.living
        ? l10n.cultureLifespanLiving(creatorYearText(l10n, born))
        : l10n.cultureBorn(creatorYearText(l10n, born));
  }
  if (died != null) return l10n.cultureDied(creatorYearText(l10n, died));
  return null;
}

/// A creator's era in the language's own tradition beside the spoken name:
/// `आधुनिक काल (ādhunika kāla) · Modern period`; null when the creator has none
/// the file lists.
String? creatorEraText(
  CreatorsFile? file,
  Creator creator,
  String language,
  List<String> spoken,
) {
  final era = file?.eraById(creator.era);
  return era == null ? null : eraNameText(era, language, spoken);
}

/// [era]'s name in the language learned with its reading, and in the first
/// spoken language it is written in: `आधुनिक काल (ādhunika kāla) · Modern period`.
String eraNameText(CreatorEra era, String language, List<String> spoken) {
  final own = era.names[language];
  final reading = era.readings[language];
  final other = era.nameFor(spoken);
  if (own == null || own.isEmpty || own == other) return other;
  final named = reading == null || reading.isEmpty ? own : '$own ($reading)';
  return other.isEmpty ? named : '$named · $other';
}

/// The source line of an item: author, work, date and why it may be quoted,
/// such as `Kabir · Dohavali · c. 1500 · public domain: author died c. 1518`.
/// Null when the card has no source block.
String? cultureSourceLine(AppLocalizations l10n, CardSource? source) {
  if (source == null || source.isEmpty) return null;
  final parts = <String>[];
  final author = source.author;
  if (author != null && author.isNotEmpty) {
    parts.add(
      author.toLowerCase() == 'anonymous' ? l10n.cultureNoKnownAuthor : author,
    );
  }
  final work = source.work ?? source.collection;
  if (work != null && work.isNotEmpty) parts.add(work);
  if (source.date != null) parts.add(source.date!);
  final basis = switch (source.basisKind) {
    SourceBasis.publicDomain =>
      source.authorDied == null
          ? l10n.cultureBasisPublicDomain
          : l10n.cultureBasisPublicDomainDied('${source.authorDied}'),
    SourceBasis.licensed => l10n.cultureBasisLicensed(source.licence ?? ''),
    SourceBasis.quotation => l10n.cultureBasisQuotation,
    SourceBasis.oralTradition => l10n.cultureBasisOral,
    null => null,
  };
  if (basis != null) parts.add(basis);
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The credit line under a creator's picture: who made it and on what licence,
/// or that there is no licensed image yet.
String cultureImageCredit(AppLocalizations l10n, Creator creator) {
  final image = creator.image;
  if (image == null) return l10n.cultureImageNone;
  final licence = image.licence == 'public-domain'
      ? l10n.cultureImagePublicDomain
      : image.licence;
  final parts = <String>[
    ?image.credit,
    if (image.author != null && image.author != image.credit) image.author!,
    ?licence,
  ];
  return parts.isEmpty
      ? l10n.cultureImageNone
      : l10n.cultureImageCredit(parts.join(' · '));
}

/// A creator's picture, or the placeholder when the file has none or it cannot
/// be fetched: a person on the secondary container. The picture is fetched
/// when first shown and kept (`DeckDownloads.creatorImage`).
class CreatorThumb extends StatefulWidget {
  const CreatorThumb({super.key, required this.creator, this.size = 48});

  final Creator creator;
  final double size;

  @override
  State<CreatorThumb> createState() => _CreatorThumbState();
}

class _CreatorThumbState extends State<CreatorThumb> {
  Future<Uint8List?>? _image;
  String? _loaded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(CreatorThumb old) {
    super.didUpdateWidget(old);
    _load();
  }

  void _load() {
    final path = widget.creator.image?.file;
    if (path == null || path == _loaded) return;
    _loaded = path;
    final downloads = AppScope.read(context).deckDownloads;
    _image = downloads?.creatorImage(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final size = widget.size;
    final name = widget.creator.nameFor(const <String>['en']).text;
    Widget placeholder() => Semantics(
      label: l10n.cultureImageNone,
      child: Icon(
        Icons.person_outline,
        size: size * 0.55,
        color: scheme.onSecondaryContainer,
      ),
    );
    final future = _image;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      alignment: Alignment.center,
      child: future == null
          ? placeholder()
          : FutureBuilder<Uint8List?>(
              future: future,
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) return placeholder();
                return Image.memory(
                  bytes,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  semanticLabel: l10n.cultureImageOf(name),
                  errorBuilder: (context, error, stack) => placeholder(),
                );
              },
            ),
    );
  }
}

/// A creator on a line: picture, name in the language learned with its reading,
/// the spoken name, dates and era. Tapping it is [onTap]'s.
class CreatorSummary extends StatelessWidget {
  const CreatorSummary({
    super.key,
    required this.creator,
    required this.language,
    required this.file,
    this.size = 56,
    this.large = false,
  });

  final Creator creator;
  final LanguageInfo language;
  final CreatorsFile? file;
  final double size;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final state = AppScope.of(context);
    final spoken = cultureSpoken(context, state);
    final target = creator.names[language.code] ?? creator.nameFor(spoken);
    final other = creator.nameFor(spoken).text;
    final dates = creatorDates(l10n, creator);
    final era = creatorEraText(file, creator, language.code, spoken);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CreatorThumb(creator: creator, size: size),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TargetText(
                target.text,
                language: language,
                fontSize: large ? 22 : 17,
                fontWeight: FontWeight.w500,
                textAlign: TextAlign.start,
              ),
              if (target.reading != null) Text(target.reading!, style: muted),
              if (other.isNotEmpty && other != target.text)
                Text(other, style: muted),
              if (dates != null) Text(dates, style: muted),
              if (era != null) Text(era, style: muted),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Still alive today": how the person and the work still shape the culture,
/// the summary and the concrete examples; or with [lineOnly] the one line.
class LegacyBlock extends StatelessWidget {
  const LegacyBlock({
    super.key,
    required this.view,
    this.lineOnly = false,
    this.language,
  });

  final LegacyView view;
  final bool lineOnly;
  final LanguageInfo? language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final spoken = cultureSpoken(context, state);
    final items = <String>[
      for (final item in view.items)
        if (item.textFor(spoken).isNotEmpty)
          item.year == null
              ? item.textFor(spoken)
              : l10n.cultureLegacyYear(item.year!, item.textFor(spoken)),
    ];
    final first = view.text.isNotEmpty
        ? view.text
        : items.isEmpty
        ? ''
        : items.first;
    if (first.isEmpty && items.isEmpty) return const SizedBox.shrink();
    final target = view.target;
    return Semantics(
      container: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: DecoratedBox(
          decoration: BoxDecoration(color: scheme.surfaceContainerHigh),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(width: 4, color: scheme.primary),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      12,
                      12,
                      14,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.cultureLegacyTitle,
                            style: theme.textTheme.titleSmall!.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (target != null &&
                            language != null &&
                            !lineOnly) ...<Widget>[
                          TargetText(
                            target.text,
                            language: language!,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            textAlign: TextAlign.start,
                          ),
                          if (target.reading != null)
                            Text(
                              target.reading!,
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(height: 4),
                        ],
                        if (lineOnly)
                          Text(first, style: theme.textTheme.bodyMedium)
                        else ...<Widget>[
                          if (view.text.isNotEmpty)
                            Text(view.text, style: theme.textTheme.bodyMedium),
                          for (final item in items) ...<Widget>[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    top: 7,
                                    end: 8,
                                  ),
                                  child: Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The amber "above your level" notice: a lock, the words, and what it means
/// for an item shown with support.
class AboveLevelNotice extends StatelessWidget {
  const AboveLevelNotice({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amber = amberOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.lock_outline, color: amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
