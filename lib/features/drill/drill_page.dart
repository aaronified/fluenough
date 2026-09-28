import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../core/models/card.dart';
import '../../core/models/drill_mode.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';
import 'drill_preset.dart';
import 'drill_session.dart';
import 'recognition_drill.dart';
import 'typed_drill.dart';

/// A drill session: recognition, production and listening, one card at a
/// time, recording each answer as it is given, then the summary.
///
/// Design screens `drill-recognition`, `drill-recognition-revealed`,
/// `drill-production-accent`, `drill-production-typo`,
/// `drill-production-script`, `drill-production-translit`, `drill-listening`
/// and `drill-rtl`.
///
/// The queue is built once, when the catalog and the voice check are in,
/// from `AppState.buildSession`; a [DrillSession] owned by this page's
/// `State` runs it. An empty queue shows the empty state. Closing part-way
/// asks first, since the answers so far are already recorded.
///
/// Grammar and minimal pairs are B4's, in `grammar_drill.dart` and
/// `pair_drill.dart`; no live session contains them yet.
class DrillPage extends StatefulWidget {
  const DrillPage({super.key, required this.request, this.preset});

  /// What the session covers.
  final DrillRequest request;

  /// Starts part-way through: the gallery's states. Null for a real session.
  final DrillPreset? preset;

  @override
  State<DrillPage> createState() => _DrillPageState();
}

class _DrillPageState extends State<DrillPage> {
  DrillSession? _session;
  bool _loaded = false;
  bool _failed = false;
  bool _summaryShown = false;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    // `load` also waits for the voice check, which decides whether
    // listening cards are in the queue. It is safe to call again.
    _await(state, state.load());
  }

  void _await(AppState state, Future<void> loading) {
    loading.then((_) {
      if (mounted) setState(() => _start(state));
    });
  }

  /// "Try again" after the catalog failed: back to the spinner, then start
  /// on whatever the reload brings.
  void _retry() {
    final state = AppScope.read(context);
    setState(() {
      _loaded = false;
      _failed = false;
    });
    _await(state, state.reload());
  }

  void _start(AppState state) {
    _loaded = true;
    if (state.status == CatalogStatus.failed) {
      _failed = true;
      return;
    }
    final request = widget.request;
    final preset = widget.preset;
    var items = state.buildSession(request).items;
    if (preset != null) {
      final ids = request.deckIds;
      items = preset.reorder(
        items,
        cards: <Card>[
          for (final entry in state.decks)
            if (ids == null || ids.contains(entry.id)) ...entry.cards,
        ],
        mode: request.skill?.mode ?? DrillMode.recognition,
        stateOf: (card, mode) =>
            state.progress.stateOf(card.deckId, card.id, mode),
      );
    }
    if (items.isEmpty) return;
    final session = DrillSession(
      state: state,
      items: items,
      inputMode: preset?.inputMode ?? InputMode.script,
    );
    preset?.apply(session);
    _session = session..addListener(_onSession);
  }

  void _onSession() {
    final session = _session!;
    if (session.finished && !_summaryShown) {
      _summaryShown = true;
      AppNavigator.showSummary(context, session.result);
    }
  }

  @override
  void dispose() {
    _session
      ?..removeListener(_onSession)
      ..dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  Future<void> _confirmEnd() async {
    final l10n = AppLocalizations.of(context)!;
    final end = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.drillEndTitle),
        content: Text(l10n.drillEndBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.drillEndKeepGoing),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.drillEndSession),
          ),
        ],
      ),
    );
    if (end == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_loaded) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            semanticsLabel: l10n.commonLoadingDecks,
          ),
        ),
      );
    }
    final session = _session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _close,
            tooltip: l10n.commonClose,
            icon: const Icon(Icons.close),
          ),
        ),
        body: _failed
            ? EmptyState(
                icon: Icons.error_outline,
                title: l10n.commonDecksFailed,
                body: l10n.commonDecksFailedBody,
                action: FilledButton(
                  onPressed: _retry,
                  child: Text(l10n.commonRetry),
                ),
              )
            : EmptyState(
                icon: Icons.event_available_outlined,
                title: l10n.drillEmptyTitle,
                body: l10n.drillEmptyBody,
              ),
      );
    }
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => PopScope(
        canPop: !session.hasAnswers || session.finished,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmEnd();
        },
        child: switch (session.item.mode) {
          DrillMode.recognition => RecognitionDrill(
            key: ValueKey<int>(session.position),
            session: session,
            onClose: _close,
          ),
          _ => TypedDrill(
            key: ValueKey<int>(session.position),
            session: session,
            onClose: _close,
            initialText: session.position == 1 ? widget.preset?.typed : null,
          ),
        },
      ),
    );
  }
}
