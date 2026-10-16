import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/drill_mode.dart';
import '../../core/models/reading.dart';
import '../../core/models/script_guide.dart';
import '../../core/scheduling/session_queue.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../script/script_guide_page.dart';
import 'choice_drill.dart';
import 'drill_preset.dart';
import 'drill_session.dart';
import 'grammar_drill.dart';
import 'match_drill.dart';
import 'rearrange_drill.dart';
import 'reading_drill.dart';
import 'recognition_drill.dart';
import 'speaking_drill.dart';
import 'teach_drill.dart';
import 'typed_drill.dart';

/// A drill session: recognition, production and listening, one card at a
/// time, recording each answer as it is given, then the summary. A reading
/// question, read or heard, is a `ReadingDrill` (#98).
///
/// Design screens `drill-recognition`, `drill-recognition-revealed`,
/// `drill-production-accent`, `drill-production-typo`,
/// `drill-production-script`, `drill-production-translit`, `drill-listening`
/// and `drill-rtl`.
///
/// The queue is built once, when the catalog and the voice check are in,
/// from `AppState.buildSession`; a [DrillSession] owned by this page's
/// `State` runs it. An empty queue shows the empty state. Closing part-way
/// asks first, saying whether the answers so far are recorded.
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

  /// The script guides to show before the session (#30, ADR-0016), in
  /// turn: one for each language with script cards in it whose guide is
  /// unseen, in the order the session reaches them.
  final List<(ScriptGuide, LanguageInfo)> _guides =
      <(ScriptGuide, LanguageInfo)>[];

  /// The queue, kept until the last guide is closed. The session is built
  /// then, so that its clock doesn't time the reading as the first answer.
  List<SessionItem> _items = const <SessionItem>[];
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
    if (request.numbers) {
      final deck = state.deckById(request.deckIds!.single);
      final items = deck == null
          ? const <SessionItem>[]
          : state.numberPracticeFor(deck);
      if (items.isEmpty) return;
      _session = DrillSession(state: state, items: items, recorded: false)
        ..addListener(_onSession);
      return;
    }
    // A preset keeps each item asked its own way, but for its first.
    var items = request.lesson
        ? state.lessonFor(request)
        : preset == null
        ? state.sessionItems(request)
        : state.buildSession(request).items;
    if (preset != null) {
      final ids = request.deckIds;
      items = preset.reorder(
        items,
        cards: <Card>[
          for (final entry in state.decks)
            if (ids == null || ids.contains(entry.id)) ...entry.cards,
        ],
        mode: request.skill?.mode ?? DrillMode.recognition,
        stateOf: (card, mode) => state.progress.stateOf(card.id, mode),
      );
    }
    if (items.isEmpty) return;
    if (preset == null) {
      final languages = <String>{};
      for (final item in items) {
        final entry = state.deckOf(item.card);
        if (entry == null || !entry.isScript) continue;
        final language = entry.language;
        if (!languages.add(language.code)) continue;
        final guide = state.scriptGuideFor(language);
        if (guide != null &&
            !state.settings.hasSeenScriptGuide(language.code)) {
          _guides.add((guide, language));
        }
      }
    }
    _items = items;
    if (_guides.isEmpty) _begin(state);
  }

  void _begin(AppState state) {
    final request = widget.request;
    final preset = widget.preset;
    final session = DrillSession(
      state: state,
      items: _items,
      inputMode: preset?.inputMode,
      recorded: !request.revise,
      revising: request.revise,
      recordsRevision: request.recordsRevision,
    );
    preset?.apply(session);
    _session = session..addListener(_onSession);
  }

  /// Start, on a guide: it is seen, and the next one, or the session,
  /// follows.
  void _guideRead(AppState state, LanguageInfo language) {
    state.settings.markScriptGuideSeen(language.code);
    setState(() {
      _guides.removeAt(0);
      if (_guides.isEmpty) _begin(state);
    });
  }

  void _onSession() {
    final session = _session!;
    if (session.finished && !_summaryShown) {
      _summaryShown = true;
      final request = widget.request;
      if (request.lesson) {
        final state = AppScope.read(context);
        state.settings.markLessonDone(request.language!, state.now());
      }
      AppNavigator.showSummary(
        context,
        session.result.inLanguage(widget.request.language),
      );
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
        content: Text(switch (_session) {
          DrillSession(recorded: false, recordsRevision: false) =>
            l10n.drillEndBodyNotRecorded,
          _ => l10n.drillEndBody,
        }),
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
    if (_guides.isNotEmpty) {
      final (guide, language) = _guides.first;
      return ScriptGuideView(
        key: ValueKey<String>(language.code),
        guide: guide,
        language: language,
        actionLabel: l10n.scriptGuideStart,
        onAction: () => _guideRead(AppScope.read(context), language),
        onClose: _close,
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
          actions: const <Widget>[ReportButton()],
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
          // A reading question, read or heard (#98).
          _ when session.item.card is QuestionCard => ReadingDrill(
            key: ValueKey<(int, bool)>((
              session.position,
              session.showsPassage,
            )),
            session: session,
            onClose: _close,
          ),
          // A lesson teaching a word, and the questions asked another way
          // than the mode's own (ADR-0024).
          _ when session.ask == Ask.teach => TeachDrill(
            key: ValueKey<int>(session.position),
            session: session,
            onClose: _close,
          ),
          _ when session.ask.chooses => ChoiceDrill(
            key: ValueKey<int>(session.position),
            session: session,
            onClose: _close,
          ),
          _ when session.ask == Ask.matchPairs => MatchDrill(
            key: ValueKey<int>(session.position),
            session: session,
            onClose: _close,
          ),
          _ when session.ask == Ask.rearrange => RearrangeDrill(
            key: ValueKey<int>(session.position),
            session: session,
            onClose: _close,
          ),
          DrillMode.recognition => RecognitionDrill(
            key: ValueKey<int>(session.position),
            session: session,
            onClose: _close,
          ),
          // A pattern deck's cell, with its table; a rules table's cell
          // typed is a typed word, its word and meaning the prompt (spec
          // 4.6).
          DrillMode.grammar when session.item.card.rule == null =>
            GrammarDrill.live(
              key: ValueKey<int>(session.position),
              session: session,
              onClose: _close,
            ),
          DrillMode.speaking => SpeakingDrill(
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
