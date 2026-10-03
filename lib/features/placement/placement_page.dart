import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/placement.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/target_text.dart';

/// Placement for each of [languages] in turn (#117, ADR-0013): whether the
/// learner knows any of it, a short check if they do, and where they will
/// start. [onFinished] gets the decks placed as known, by language; nothing
/// is saved or recorded here.
class PlacementPage extends StatefulWidget {
  const PlacementPage({
    super.key,
    required this.languages,
    required this.onFinished,
    this.random,
    this.checking = false,
  });

  /// Language codes, in the order they are placed.
  final List<String> languages;

  final ValueChanged<Map<String, Set<String>>> onFinished;

  /// For tests and the gallery, so that the questions are fixed.
  final Random? random;

  /// For the gallery: open on the first language's check, as if Find my
  /// level had been chosen.
  final bool checking;

  @override
  State<PlacementPage> createState() => _PlacementPageState();
}

enum _Stage { ask, check, result }

class _PlacementPageState extends State<PlacementPage> {
  int _index = 0;
  _Stage _stage = _Stage.ask;
  Placement? _placement;
  final Map<String, Set<String>> _placed = <String, Set<String>>{};

  String get _code => widget.languages[_index];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Called again once the catalog loads, since build depends on AppScope.
    if (widget.checking && _placement == null && _stage == _Stage.ask) {
      final state = AppScope.read(context);
      if (state.status == CatalogStatus.ready) _startCheck(state);
    }
  }

  void _find(AppState state) => setState(() => _startCheck(state));

  void _startCheck(AppState state) {
    final placement = Placement(
      state.courseUnits(_code),
      random: widget.random,
    );
    _placement = placement;
    if (placement.isFinished) {
      _finishCheck(placement);
    } else {
      _stage = _Stage.check;
    }
  }

  void _new() => setState(() {
    _placement = null;
    _placed[_code] = const <String>{};
    _stage = _Stage.result;
  });

  void _answer(String? chosen) => setState(() {
    final placement = _placement!..answer(chosen);
    if (placement.isFinished) _finishCheck(placement);
  });

  void _stop() => setState(() => _finishCheck(_placement!..stop()));

  void _finishCheck(Placement placement) {
    _placed[_code] = placement.placedDeckIds;
    _stage = _Stage.result;
  }

  void _next() {
    if (_index + 1 < widget.languages.length) {
      setState(() {
        _index++;
        _stage = _Stage.ask;
        _placement = null;
      });
    } else {
      widget.onFinished(Map<String, Set<String>>.unmodifiable(_placed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final language = state.languages.where((l) => l.code == _code).firstOrNull;
    if (language == null) {
      return Scaffold(
        appBar: AppBar(actions: const <Widget>[ReportButton()]),
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.learnLoading),
        ),
      );
    }
    final placement = _placement;
    final question = placement?.question;
    return Scaffold(
      appBar: AppBar(
        title: Text(language.name),
        actions: <Widget>[
          if (_stage == _Stage.check)
            TextButton(onPressed: _stop, child: Text(l10n.placementStop)),
          const ReportButton(),
        ],
      ),
      body: SafeArea(
        top: false,
        child: switch (_stage) {
          _Stage.ask => _Ask(
            language: language,
            onFind: () => _find(state),
            onNew: _new,
          ),
          _Stage.check => _Check(
            language: language,
            question: question!,
            unit: placement!.unit,
            units: placement.units.length,
            onAnswer: _answer,
          ),
          _Stage.result => _Result(
            text: _resultText(l10n, state, language),
            last: _index + 1 == widget.languages.length,
            onNext: _next,
          ),
        },
      ),
    );
  }

  String _resultText(
    AppLocalizations l10n,
    AppState state,
    LanguageInfo language,
  ) {
    final placement = _placement;
    final units = placement?.units ?? state.courseUnits(_code);
    final known = placement?.unit ?? 0;
    // Where Today will start: the first unit from there that is not
    // finished by study either, as the pending window has it. Placement
    // from before, which this replaces, does not count.
    bool studied(DeckEntry e) =>
        !state.canDrill(e) || state.notStudiedIn(e) == 0;
    final start = units
        .skip(known)
        .where((unit) => !unit.every(studied))
        .firstOrNull;
    if (start == null) return l10n.placementResultAll(language.name);
    final deck = start.first.deck.name;
    if (known > 0) return l10n.placementResultFrom(known, language.name, deck);
    return identical(start, units.firstOrNull)
        ? l10n.placementResultStart(language.name, deck)
        : l10n.placementResultContinue(language.name, deck);
  }
}

/// "Do you know any Hindi?", with Find my level and I'm new.
class _Ask extends StatelessWidget {
  const _Ask({
    required this.language,
    required this.onFind,
    required this.onNew,
  });

  final LanguageInfo language;
  final VoidCallback onFind;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
      children: <Widget>[
        Text(
          l10n.placementAskTitle(language.name),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.placementAskBody,
          style: theme.textTheme.bodyLarge!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          style: AppButtonStyles.tall(context),
          onPressed: onFind,
          child: Text(l10n.placementFind),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onNew,
          child: Text(l10n.placementNew(language.name)),
        ),
      ],
    );
  }
}

/// One question: the target, alone, and the meanings to choose from.
class _Check extends StatelessWidget {
  const _Check({
    required this.language,
    required this.question,
    required this.unit,
    required this.units,
    required this.onAnswer,
  });

  final LanguageInfo language;
  final PlacementQuestion question;
  final int unit;
  final int units;
  final ValueChanged<String?> onAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
      children: <Widget>[
        Text(
          l10n.placementProgress(unit + 1, units),
          style: theme.textTheme.labelLarge!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(minHeight: 160),
          alignment: Alignment.center,
          padding: const EdgeInsetsDirectional.all(24),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: TargetText.hero(question.card.target, language: language),
        ),
        const SizedBox(height: 16),
        Text(l10n.placementQuestion, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final option in question.options) ...<Widget>[
          OutlinedButton(
            onPressed: () => onAnswer(option),
            child: Text(option, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
        ],
        TextButton(
          onPressed: () => onAnswer(null),
          child: Text(l10n.placementDontKnow),
        ),
      ],
    );
  }
}

/// Where the learner starts, and the way on.
class _Result extends StatelessWidget {
  const _Result({required this.text, required this.last, required this.onNext});

  final String text;
  final bool last;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
      children: <Widget>[
        Text(text, style: theme.textTheme.titleLarge),
        const SizedBox(height: 32),
        FilledButton(
          style: AppButtonStyles.tall(context),
          onPressed: onNext,
          child: Text(last ? l10n.placementDone : l10n.placementNext),
        ),
      ],
    );
  }
}
