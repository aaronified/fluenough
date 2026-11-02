import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/placement.dart';
import '../../app/placement_plan.dart';
import '../../core/grading/romanised.dart';
import '../../core/models/deck.dart';
import '../../core/scheduling/placed_review.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/target_text.dart';
import '../../ui/widgets/reading_first.dart';
import 'placed_review_choice.dart';
import 'placement_questions.dart';

/// What placement found, by language: the decks placed as known; for a
/// language with an alphabet, whether it is learned; for a language taught
/// from more than one the learner speaks, which they chose; and how well
/// the learner reads each script checked; and, for a language with words
/// placed, how the learner chose to have them reviewed (#761).
typedef PlacementFound = ({
  Map<String, Set<String>> placed,
  Map<String, bool> alphabet,
  Map<String, String> natives,
  Map<String, Map<String, ScriptStanding>> scripts,
  Map<String, PlacedReview> review,
});

/// Called when a language's placement is done: with what was found for that
/// language alone. [leaving] is false when its result is first shown, and
/// true when the learner goes on from it (with the review choice made there).
typedef PlacementLanguageDone = void Function(
  String code,
  PlacementFound found, {
  required bool leaving,
});

/// Placement for each of [languages] in turn (#117, #481, ADR-0013,
/// `docs/plans/placement-v2.md`), all in the review's own screen. It asks the
/// learner nothing the language flow has asked (owner, 2026-11-02: "Language
/// choice itself is now unified. Use the new paradigm."): whether to learn
/// the alphabet is the Learn pill on the script, which scripts the learner
/// reads is the script pills of the languages they know, and which language
/// the course is taught from is the course's own (`AppState.courseNative`).
/// So it goes straight to a check of each script the learner reads, a walk
/// along the word decks, and where they will start and why, with the chance
/// to try again from there. The header's close button stops, keeping what was
/// found. [onFinished] gets what was found for every language, after the
/// last; [onLanguageDone] gets each language's as it is done. Nothing is
/// saved or recorded here.
///
/// Placement stays short (owner, 2026-10-20: "The goal is to ask minimal
/// questions to place people"): a script the learner does not read is placed
/// as new with no questions, and the walk jumps.
class PlacementPage extends StatefulWidget {
  const PlacementPage({
    super.key,
    required this.languages,
    required this.onFinished,
    this.onLanguageDone,
    this.random,
    this.alphabet = const <String, bool>{},
    this.scripts = const <String, Set<String>>{},
    this.natives = const <String, String>{},
    this.languageNames = const <String, String>{},
    this.skippable = false,
  });

  /// Language codes, in the order they are placed.
  final List<String> languages;

  final ValueChanged<PlacementFound> onFinished;

  /// Each language's findings as it is done, rather than only at the end.
  final PlacementLanguageDone? onLanguageDone;

  /// For tests and the gallery, so that the questions are fixed.
  final Random? random;

  /// Whether to learn each language's alphabet, by code, where the
  /// language picker has asked already ("Learn the script", #211); where
  /// not, the Learn pill on its script says.
  final Map<String, bool> alphabet;

  /// The scripts each language is learned in, by code, where the language
  /// picker's sheet chose them and they are not saved yet (#650): its
  /// course and its cards follow them, as drills will.
  final Map<String, Set<String>> scripts;

  /// The language each is learned from, by code, where it was chosen
  /// already; else the course's own.
  final Map<String, String> natives;

  /// The names of the languages the learner knows, by code; a language not
  /// here is named as the decks name it, or by its code.
  final Map<String, String> languageNames;

  /// Whether the first question of each language offers "Start at the
  /// beginning", which places nothing for it and goes on (onboarding's
  /// offer, owner, 2026-11-02: "It should be offered, and skippable to start
  /// at the beginning").
  final bool skippable;

  @override
  State<PlacementPage> createState() => _PlacementPageState();
}

/// The parts of placement that follow the learner's skills: the script
/// check, the word walk and the result.
enum _Stage { script, walk, result }

class _PlacementPageState extends State<PlacementPage> {
  int _index = 0;
  _Stage? _stage;
  final Map<String, Set<String>> _placed = <String, Set<String>>{};
  final Map<String, Map<String, ScriptStanding>> _found =
      <String, Map<String, ScriptStanding>>{};
  late final Map<String, bool> _alphabet = <String, bool>{...widget.alphabet};
  late final Map<String, String> _natives = <String, String>{...widget.natives};

  /// How each language's placed words are reviewed, as chosen on its result;
  /// Spot-check until then (#761).
  final Map<String, PlacedReview> _review = <String, PlacedReview>{};

  List<PlacementScript> _toCheck = const <PlacementScript>[];
  int _scriptAt = 0;
  ScriptCheck? _check;
  final Map<String, ScriptStanding> _standings = <String, ScriptStanding>{};
  DeckWalk? _walk;

  /// Where the try before this one landed, by deck; null on the first.
  int? _before;

  /// Whether the learner may try the walk again: the last try got further.
  bool _canTryAgain = true;
  bool _stopped = false;

  /// The questions answered for this language, for "Question 4".
  int _number = 0;

  String get _code => widget.languages[_index];

  /// The course's units as the learner will learn it.
  List<List<DeckEntry>> _units(AppState state) => state.courseUnits(
    _code,
    alphabet: _alphabet[_code],
    scripts: widget.scripts[_code],
    native: _natives[_code],
  );

  /// The scripts the language is learned in, where placement knows them
  /// before they are saved: as the picker chose them, or as the Learn pill
  /// says. Null for those saved.
  Set<String>? _scripts(AppState state) {
    if (widget.scripts[_code] case final scripts?) return scripts;
    final alphabet = _alphabet[_code];
    if (alphabet == null) return null;
    return state.scriptsLearnedOf(_code, alphabet: alphabet);
  }

  /// Begins the language: its alphabet as its pill says, then its scripts.
  void _begin(AppState state) {
    if (!_alphabet.containsKey(_code) && state.hasAlphabet(_code)) {
      _alphabet[_code] = state.settings.learnsAlphabet(_code);
    }
    _toCheck = state.placementScripts(_code, native: _natives[_code]);
    _scriptAt = 0;
    _nextScript(state);
  }

  PlacementScript get _script => _toCheck[_scriptAt];

  /// Whether the learner reads [script]: the script pills of the languages
  /// they know say so (Read known), as Languages I know has always kept it
  /// (#554). A script they learn, or have not said they read, is new to
  /// them, with no questions (owner, 2026-10-20).
  bool _reads(AppState state, String script) =>
      state.scriptReadersKnown.containsKey(script);

  /// Goes on to the next script that is checked, placing the others as new;
  /// after the last, the walk.
  void _nextScript(AppState state) {
    while (_scriptAt < _toCheck.length) {
      final script = _script;
      if (!_reads(state, script.script)) {
        _standings[script.script] = ScriptStanding.newTo;
        _scriptAt++;
        continue;
      }
      final language = script.language;
      final check = ScriptCheck(
        script: script.script,
        decks: script.decks,
        words: script.words,
        canHear:
            state.settings.soundOn &&
            state.voiceStatus(language) == VoiceStatus.available,
        canSay: state.canHear(language),
        random: widget.random,
      );
      if (check.isFinished) {
        _standings[script.script] = check.standing;
        _scriptAt++;
        continue;
      }
      _check = check;
      _stage = _Stage.script;
      return;
    }
    _check = null;
    _startWalk(state);
  }

  void _scriptAnswer(AppState state, bool right) => setState(() {
    _number++;
    final check = _check!..answer(right);
    if (check.isFinished) _scriptDone(state, check.standing);
  });

  /// "I can't speak now": skips the read-aloud question, unanswered.
  void _scriptSkipSay(AppState state) => setState(() {
    final check = _check!..skipSay();
    if (check.isFinished) _scriptDone(state, check.standing);
  });

  void _scriptDone(AppState state, ScriptStanding standing) {
    _standings[_script.script] = standing;
    _check = null;
    _scriptAt++;
    _nextScript(state);
  }

  void _startWalk(AppState state, {int start = 0}) {
    final walk = DeckWalk(
      state.walkDecks(_code, native: _natives[_code]),
      start: start,
      random: widget.random,
    );
    _walk = walk;
    if (walk.isFinished) {
      _finish();
    } else {
      _stage = _Stage.walk;
    }
  }

  void _walkAnswer(bool right) => setState(() {
    _number++;
    final walk = _walk!..answer(right);
    if (walk.isFinished) _finish();
  });

  /// "Try again from here": the walk again, from where it landed.
  void _tryAgain(AppState state) => setState(() {
    _before = _walk!.landing;
    _startWalk(state, start: _before!);
  });

  /// "Start at the beginning": nothing is placed for the language, and on to
  /// the next, with no result between.
  void _skip() {
    _check = null;
    _walk = null;
    _placed[_code] = const <String>{};
    _next();
  }

  /// The header's close button: placement of the language ends, keeping what
  /// it found so far, which is nothing before the first answer.
  void _stop() => setState(() {
    _stopped = true;
    if (_check case final check?) {
      check.stop();
      _standings[_script.script] = check.standing;
      _check = null;
    }
    _walk?.stop();
    _finish();
  });

  void _finish() {
    final walk = _walk;
    if (walk != null && _before != null) {
      _canTryAgain = gotFurther(_before!, walk.landing);
    }
    _placed[_code] = <String>{
      for (final script in _toCheck)
        if (_standings[script.script] case final standing?)
          ...ScriptCheck.placedFor(script.decks, standing),
      ...?walk?.placedDeckIds,
    };
    _found[_code] = Map<String, ScriptStanding>.unmodifiable(_standings);
    _stage = _Stage.result;
    widget.onLanguageDone?.call(_code, _foundFor(_code), leaving: false);
  }

  PlacementFound _foundFor(String code) => (
    placed: <String, Set<String>>{code: _placed[code] ?? const <String>{}},
    alphabet: <String, bool>{code: ?_alphabet[code]},
    natives: <String, String>{code: ?_natives[code]},
    scripts: <String, Map<String, ScriptStanding>>{code: ?_found[code]},
    review: <String, PlacedReview>{
      if ((_placed[code] ?? const <String>{}).isNotEmpty)
        code: _review[code] ?? PlacedReview.fallback,
    },
  );

  void _next() {
    widget.onLanguageDone?.call(_code, _foundFor(_code), leaving: true);
    if (_index + 1 < widget.languages.length) {
      setState(() {
        _index++;
        _stage = null;
        _toCheck = const <PlacementScript>[];
        _scriptAt = 0;
        _check = null;
        _standings.clear();
        _walk = null;
        _before = null;
        _canTryAgain = true;
        _stopped = false;
        _number = 0;
      });
    } else {
      widget.onFinished((
        placed: Map<String, Set<String>>.unmodifiable(_placed),
        alphabet: Map<String, bool>.unmodifiable(_alphabet),
        natives: Map<String, String>.unmodifiable(_natives),
        scripts: Map<String, Map<String, ScriptStanding>>.unmodifiable(_found),
        review: Map<String, PlacedReview>.unmodifiable(<String, PlacedReview>{
          for (final MapEntry(:key, :value) in _placed.entries)
            if (value.isNotEmpty) key: _review[key] ?? PlacedReview.fallback,
        }),
      ));
    }
  }

  /// The scripts the walk shows words in (#675): those learned that the
  /// check found the learner reads; else those it found they read; else
  /// none, and each word shows its reading first. Null where no script was
  /// checked, for the scripts as drills show them.
  Set<String>? _walkScripts(AppState state) {
    if (_toCheck.isEmpty) return _scripts(state);
    final read = <String>{
      for (final MapEntry(:key, :value) in _standings.entries)
        if (value == ScriptStanding.joined || value == ScriptStanding.reads)
          key,
    };
    final learned = _scripts(state) ?? state.scriptsLearnedOf(_code);
    final both = learned.intersection(read);
    return both.isNotEmpty ? both : read;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final language = state.languages.where((l) => l.code == _code).firstOrNull;
    final stage = _stage;
    if (language == null || stage == null) {
      // Begins once the catalog has the language: nothing is asked first.
      if (language != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _stage == null) {
            setState(() => _begin(AppScope.read(context)));
          }
        });
      }
      return Scaffold(
        appBar: AppBar(actions: const <Widget>[ReportButton()]),
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.learnLoading),
        ),
      );
    }
    // Every screen is the review's own (owner, 2026-11-02): a question is
    // drawn by its frame, whose header closes it, and so is the result.
    if (stage == _Stage.result) {
      return _Result(
        language: language.name,
        lines: _resultLines(l10n, state, language),
        tryAgainNote: _tryAgainNote(l10n),
        noFurther: !_canTryAgain,
        onTryAgain: _offersTryAgain ? () => _tryAgain(state) : null,
        last: _index + 1 == widget.languages.length,
        onNext: _next,
        choice: _reviewChoice(l10n, state),
      );
    }
    final inWalk = stage == _Stage.walk;
    final ask = inWalk ? _walk?.question : _check?.question;
    if (ask == null) {
      // Between one language and the next, or as the last is left.
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.learnLoading),
        ),
      );
    }
    final deck = state.deckOf(ask.card);
    return PlacementShell(
      onClose: _stop,
      onSkip: widget.skippable && _number == 0 ? _skip : null,
      deckName: inWalk
          ? (deck?.deck.name ?? language.name)
          : l10n.scriptNameOr(_script.script, _script.script),
      progress: _number / (_number + 8),
      reportDetail: '${ask.card.id} in placement',
      child: inWalk
          ? _question(state, language, ask, _walkAnswer)
          : _question(
              state,
              language,
              ask,
              (right) => _scriptAnswer(state, right),
              inScript: _script.language,
              onCantSpeak: () => _scriptSkipSay(state),
            ),
    );
  }

  /// The question of how the words just placed are reviewed (#761), under
  /// the result; null when nothing was placed.
  Widget? _reviewChoice(AppLocalizations l10n, AppState state) {
    final decks = <DeckEntry>[
      for (final id in _placed[_code] ?? const <String>{}) ?state.deckById(id),
    ];
    final words = decks.fold<int>(0, (n, deck) => n + deck.cards.length);
    if (words == 0) return null;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.placedReviewSummary(words, decks.length),
          style: theme.textTheme.bodyMedium!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(l10n.placedReviewQuestion, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        PlacedReviewOptions(
          value: _review[_code] ?? PlacedReview.fallback,
          tagged: PlacedReview.fallback,
          onChanged: (choice) => setState(() => _review[_code] = choice),
        ),
        Text(
          l10n.placedReviewFoot,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Whether the result offers "Try again from here": after a walk that
  /// did not reach the end, that the learner did not stop, while each try
  /// gets at least a deck further than the last.
  bool get _offersTryAgain {
    final walk = _walk;
    return walk != null &&
        !_stopped &&
        _canTryAgain &&
        walk.landing < walk.decks.length;
  }

  String? _tryAgainNote(AppLocalizations l10n) {
    final walk = _walk;
    if (walk == null || !_offersTryAgain) return null;
    return l10n.placementTryAgainNote(walk.decks[walk.landing].deck.name);
  }

  /// The question [ask] on screen. [inScript] is the script check's
  /// script, in which its words are shown; null in the walk, which shows
  /// each word as [_walkScripts] says.
  Widget _question(
    AppState state,
    LanguageInfo language,
    PlacementAsk ask,
    ValueChanged<bool> onAnswer, {
    LanguageInfo? inScript,
    VoidCallback? onCantSpeak,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final number = _number + 1;
    final key = ValueKey<Object>(ask);
    final card = ask.card;
    final written = state.deckOf(card)?.language ?? language;
    final romanised = RomanisedSpelling(state.romanisationFor(written));
    switch (ask) {
      case MatchQuestion():
        return PlacementMatch(
          key: key,
          question: ask,
          number: number,
          language: inScript ?? written,
          onAnswer: onAnswer,
        );
      case HearQuestion():
        return PlacementHear(
          key: key,
          question: ask,
          number: number,
          onAnswer: onAnswer,
        );
      case SayQuestion():
        return PlacementSay(
          key: key,
          question: ask,
          number: number,
          onAnswer: onAnswer,
          onCantSpeak: onCantSpeak,
        );
      case TypeQuestion(produce: false):
        return PlacementType(
          key: key,
          question: ask,
          number: number,
          title: Text(l10n.placementTransliterate),
          shown: TargetText.hero(ask.shown!, language: ask.language!),
          hint: l10n.placementTypeHint,
          romanised: romanised,
          onAnswer: onAnswer,
        );
      case TileQuestion():
        final scripts = _walkScripts(state);
        final shown = state.targetShown(card, written, scripts: scripts);
        return PlacementTiles(
          key: key,
          question: ask,
          number: number,
          spelling: shown.text,
          language: shown.language,
          latin:
              (_toCheck.isNotEmpty && (scripts?.isEmpty ?? true)) ||
              state.readsFirst(written, scripts: scripts),
          onAnswer: onAnswer,
        );
      case TypeQuestion(produce: true):
        return PlacementType(
          key: key,
          question: ask,
          number: number,
          title: Text(l10n.placementProduce(language.name, card.native)),
          hint: l10n.placementProduceHint,
          romanised: romanised,
          onAnswer: onAnswer,
        );
      case PlacementQuestion():
        if (inScript != null) {
          return PlacementChoice(
            key: key,
            question: ask,
            number: number,
            title: Text(l10n.scriptTestQuestion),
            shown: TargetText.hero(card.target, language: written),
            onAnswer: onAnswer,
            feedback: false,
          );
        }
        final scripts = _walkScripts(state);
        // Where the check found no script the learner reads, each word
        // shows its reading first.
        final readsFirst =
            (_toCheck.isNotEmpty && (scripts?.isEmpty ?? true)) ||
            state.readsFirst(written, scripts: scripts);
        return PlacementChoice(
          key: key,
          question: ask,
          number: number,
          title: ask.formOf == null
              ? Text(l10n.placementQuestion)
              : _formQuestion(state, written, ask.formOf!, readsFirst, scripts),
          shown: switch (card.reading) {
            final reading? when readsFirst => ReadingFirst(
              reading: reading,
              target: card.target,
              language: written,
              fontSize: 48,
            ),
            _ => TargetText.hero(
              card.target,
              language: written,
              card: card,
              scripts: scripts,
            ),
          },
          onAnswer: onAnswer,
        );
    }
  }

  /// "Which form of घर (house, m) is this?": the word once, here, so that
  /// the options are its forms alone. The word as the learner reads it: in
  /// their script, where a card of the course spells it in that script, or
  /// romanised where they read none.
  Widget _formQuestion(
    AppState state,
    LanguageInfo written,
    PlacementWord word,
    bool readsFirst,
    Set<String>? scripts,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final shown = readsFirst
        ? (text: word.reading ?? word.lemma, language: written)
        : _lemmaShown(state, written, word.lemma, scripts);
    return Text.rich(
      quotingTarget(
        l10n.placementFormQuestion(shown.text, word.gloss),
        <String>[shown.text],
        shown.language,
      ),
    );
  }

  /// [lemma] as [AppState.targetShown] shows a card of [language]'s course
  /// written so; as it is where none is.
  ({String text, LanguageInfo language}) _lemmaShown(
    AppState state,
    LanguageInfo language,
    String lemma,
    Set<String>? scripts,
  ) {
    for (final entry in state.decks) {
      if (entry.language.code != language.code) continue;
      for (final card in entry.cards) {
        if (card.target == lemma && card.targetScripts.isNotEmpty) {
          return state.targetShown(card, entry.language, scripts: scripts);
        }
      }
    }
    return (text: lemma, language: language);
  }

  /// Where the learner will start, and why: a line for each script
  /// checked, one for the words, and where teaching starts.
  List<String> _resultLines(
    AppLocalizations l10n,
    AppState state,
    LanguageInfo language,
  ) {
    final units = _units(state);
    // A course may have nothing yet but its alphabet decks (#47).
    if (units.isEmpty) {
      return <String>[l10n.placementNoAlphabet(language.name)];
    }
    final lines = <String>[
      for (final script in _toCheck)
        if (_standings[script.script] case final standing?)
          _scriptLine(
            l10n,
            l10n.scriptNameOr(script.script, script.script),
            standing,
          ),
      ?_wordsLine(l10n),
    ];
    final placed = _placed[_code] ?? const <String>{};
    // Where Today will start: the first deck from there that is not
    // finished by study either. Placement from before, which this
    // replaces, does not count.
    bool studied(DeckEntry e) =>
        !state.canDrill(e) || state.notStudiedIn(e) == 0;
    final course = <DeckEntry>[for (final unit in units) ...unit];
    final start = course
        .where((e) => !placed.contains(e.id) && !studied(e))
        .firstOrNull;
    if (start == null) {
      lines.add(l10n.placementResultAll(language.name));
    } else if (course.any((e) => placed.contains(e.id))) {
      lines.add(l10n.placementResultAt(language.name, start.deck.name));
    } else if (identical(start, course.firstOrNull)) {
      lines.add(l10n.placementResultStart(language.name, start.deck.name));
    } else {
      lines.add(l10n.placementResultContinue(language.name, start.deck.name));
    }
    if (!_canTryAgain) lines.add(l10n.placementNoFurther);
    return lines;
  }

  static String _scriptLine(
    AppLocalizations l10n,
    String script,
    ScriptStanding standing,
  ) => switch (standing) {
    ScriptStanding.reads => l10n.placementScriptReads(script),
    ScriptStanding.joined => l10n.placementScriptJoined(script),
    ScriptStanding.letters => l10n.placementScriptLetters(script),
    ScriptStanding.newTo => l10n.placementScriptNew(script),
  };

  /// What the walk found of the words: where it stopped, and what it
  /// missed.
  String? _wordsLine(AppLocalizations l10n) {
    final walk = _walk;
    if (walk == null || walk.decks.isEmpty) return null;
    final decks = walk.decks;
    final landing = walk.landing;
    if (landing >= decks.length) return l10n.placementWordsAll;
    if (walk.stopped) {
      return l10n.placementWordsStopped(decks[landing].deck.name);
    }
    final missed = walk.missed;
    if (missed == null) return null;
    final missedName = decks[missed].deck.name;
    if (landing == 0) return l10n.placementWordsFirst(missedName);
    return l10n.placementWordsMissed(decks[landing - 1].deck.name, missedName);
  }
}

/// Where the learner starts and why, Try again from here, and the way on,
/// in the review's own frame: the lines on its card, and the choice of how
/// placed words are reviewed below it, Continue at its foot.
class _Result extends StatelessWidget {
  const _Result({
    required this.language,
    required this.lines,
    required this.tryAgainNote,
    required this.noFurther,
    required this.onTryAgain,
    required this.last,
    required this.onNext,
    this.choice,
  });

  final String language;
  final List<String> lines;
  final String? tryAgainNote;
  final bool noFurther;
  final VoidCallback? onTryAgain;
  final bool last;
  final VoidCallback onNext;

  /// How the placed words are reviewed, asked before the way on.
  final Widget? choice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return DrillFrame(
      deckName: '',
      position: 1,
      total: 0,
      positionLabel: language,
      progress: 1,
      reportDetail: 'placement result',
      card: <Widget>[
        for (final (i, line) in lines.indexed)
          Text(
            line,
            textAlign: TextAlign.center,
            style: i == lines.length - 1 - (noFurther ? 1 : 0)
                ? theme.textTheme.titleLarge
                : theme.textTheme.bodyLarge,
          ),
      ],
      belowCard: <Widget>[
        ?choice,
        if (onTryAgain != null && tryAgainNote != null)
          Text(
            tryAgainNote!,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
      actions: <Widget>[
        FilledButton(
          onPressed: onNext,
          style: AppButtonStyles.tall(context),
          child: Text(last ? l10n.placementDone : l10n.placementNext),
        ),
        if (onTryAgain != null)
          OutlinedButton(
            onPressed: onTryAgain,
            child: Text(l10n.placementTryAgain),
          ),
      ],
    );
  }
}
