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
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/target_text.dart';
import '../../ui/widgets/reading_first.dart';
import 'native_choice.dart';
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

/// Placement for each of [languages] in turn (#117, #481, ADR-0013,
/// `docs/plans/placement-v2.md`): which of the languages the learner speaks
/// to learn it from, when more than one teaches it (ADR-0036); whether to
/// learn its alphabet, for a course with decks that need it; whether the
/// learner knows any of it; then a check of each of its scripts, a walk
/// along its word decks, and where they will start and why, with the
/// chance to try again from there. [onFinished] gets what was found;
/// nothing is saved or recorded here.
///
/// Placement stays short (owner, 2026-10-20: "The goal is to ask minimal
/// questions to place people"): a script the learner says they do not read
/// is placed as new with no questions, and the walk jumps.
class PlacementPage extends StatefulWidget {
  const PlacementPage({
    super.key,
    required this.languages,
    required this.onFinished,
    this.random,
    this.checking = false,
    this.alphabet = const <String, bool>{},
    this.scripts = const <String, Set<String>>{},
    this.natives = const <String, String>{},
    this.asked = const <String>{},
    this.languageNames = const <String, String>{},
  });

  /// Language codes, in the order they are placed.
  final List<String> languages;

  final ValueChanged<PlacementFound> onFinished;

  /// For tests and the gallery, so that the questions are fixed.
  final Random? random;

  /// For the gallery: open on the first language's check, as if Find my
  /// level had been chosen.
  final bool checking;

  /// Whether to learn each language's alphabet, by code, where the
  /// language picker has asked already ("Learn the script", #211): its
  /// alphabet stage is skipped.
  final Map<String, bool> alphabet;

  /// The scripts each language is learned in, by code, where the language
  /// picker's sheet chose them and they are not saved yet (#650): its
  /// course and its cards follow them, as drills will.
  final Map<String, Set<String>> scripts;

  /// The language each is learned from, by code, where the picker has
  /// asked already: its native stage is skipped.
  final Map<String, String> natives;

  /// The languages whose "Find my level" was chosen already, in Languages
  /// I'm learning (#626): each goes straight to its check, with no "Do you
  /// know any?" first.
  final Set<String> asked;

  /// The names of the languages the learner knows, by code, for "You read
  /// Devanagari through Hindi"; a language not here is named as the decks
  /// name it, or by its code.
  final Map<String, String> languageNames;

  @override
  State<PlacementPage> createState() => _PlacementPageState();
}

enum _Stage { native, alphabet, ask, scriptAsk, script, walk, result }

class _PlacementPageState extends State<PlacementPage> {
  int _index = 0;
  _Stage? _stageSet;
  final Map<String, Set<String>> _placed = <String, Set<String>>{};
  final Map<String, Map<String, ScriptStanding>> _found =
      <String, Map<String, ScriptStanding>>{};
  late final Map<String, bool> _alphabet = <String, bool>{...widget.alphabet};
  late final Map<String, String> _natives = <String, String>{...widget.natives};

  /// How each language's placed words are reviewed, as chosen on its result;
  /// Spot-check until then (#761).
  final Map<String, PlacedReview> _review = <String, PlacedReview>{};

  /// Whether placement of the language has begun: its check, or I'm new.
  bool _begun = false;

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

  /// A language's first stage: which language to learn it from, when more
  /// than one the learner speaks teaches it and they have not chosen; else
  /// [_afterNative].
  _Stage get _stage =>
      _stageSet ??
      (!_natives.containsKey(_code) &&
              AppScope.read(context).needsNativeChoice(_code)
          ? _Stage.native
          : _afterNative);
  set _stage(_Stage stage) => _stageSet = stage;

  /// The alphabet, for a course that has decks needing it, else whether the
  /// learner knows any.
  _Stage get _afterNative =>
      !_alphabet.containsKey(_code) && AppScope.read(context).hasAlphabet(_code)
      ? _Stage.alphabet
      : _Stage.ask;

  void _chooseNative(String native) => setState(() {
    _natives[_code] = native;
    _stage = _afterNative;
  });

  void _chooseAlphabet(bool learns) => setState(() {
    _alphabet[_code] = learns;
    _stage = _Stage.ask;
  });

  /// The course's units as the learner will learn it.
  List<List<DeckEntry>> _units(AppState state) => state.courseUnits(
    _code,
    alphabet: _alphabet[_code],
    scripts: widget.scripts[_code],
    native: _natives[_code],
  );

  /// The scripts the language is learned in, where placement knows them
  /// before they are saved: as the picker chose them, or as the alphabet
  /// was answered here. Null for those saved.
  Set<String>? _scripts(AppState state) {
    if (widget.scripts[_code] case final scripts?) return scripts;
    final alphabet = _alphabet[_code];
    if (alphabet == null) return null;
    return state.scriptsLearnedOf(_code, alphabet: alphabet);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Called again once the catalog loads, since build depends on AppScope.
    if (widget.checking && !_begun && _stageSet == null) {
      final state = AppScope.read(context);
      if (state.status == CatalogStatus.ready) _startCheck(state);
    }
  }

  void _find(AppState state) => setState(() => _startCheck(state));

  void _startCheck(AppState state) {
    _begun = true;
    _toCheck = state.placementScripts(_code, native: _natives[_code]);
    _scriptAt = 0;
    if (_toCheck.isEmpty) {
      _startWalk(state);
    } else {
      _stage = _Stage.scriptAsk;
    }
  }

  PlacementScript get _script => _toCheck[_scriptAt];

  /// "Yes, check me": the script's check.
  void _readsScript(AppState state) => setState(() {
    final script = _script;
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
    _check = check;
    if (check.isFinished) {
      _scriptDone(state, check.standing);
    } else {
      _stage = _Stage.script;
    }
  });

  /// "No, I'm new to it": new to the script, with no questions.
  void _newToScript(AppState state) =>
      setState(() => _scriptDone(state, ScriptStanding.newTo));

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
    if (_scriptAt < _toCheck.length) {
      _stage = _Stage.scriptAsk;
    } else {
      _startWalk(state);
    }
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

  void _new() => setState(() {
    _begun = true;
    _toCheck = const <PlacementScript>[];
    _walk = null;
    _placed[_code] = const <String>{};
    _stage = _Stage.result;
  });

  /// Stop here: placement ends, keeping what it found so far.
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
  }

  void _next() {
    if (_index + 1 < widget.languages.length) {
      setState(() {
        _index++;
        _stageSet = null;
        _begun = false;
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
    if (language == null) {
      return Scaffold(
        appBar: AppBar(actions: const <Widget>[ReportButton()]),
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.learnLoading),
        ),
      );
    }
    if (_stage == _Stage.ask && !_begun && widget.asked.contains(_code)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _stage == _Stage.ask && !_begun) {
          _find(AppScope.read(context));
        }
      });
    }
    final checking = switch (_stage) {
      _Stage.scriptAsk || _Stage.script || _Stage.walk => true,
      _ => false,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(language.name),
        actions: <Widget>[
          if (checking)
            TextButton(onPressed: _stop, child: Text(l10n.placementStop)),
          const ReportButton(),
        ],
      ),
      body: SafeArea(
        top: false,
        child: switch (_stage) {
          _Stage.native => NativeChoice(
            language: language,
            onChosen: _chooseNative,
          ),
          _Stage.alphabet => _Alphabet(
            language: language,
            onChoose: _chooseAlphabet,
          ),
          _Stage.ask =>
            widget.asked.contains(_code)
                ? const SizedBox.shrink()
                : _Ask(
                    language: language,
                    onFind: () => _find(state),
                    onNew: _new,
                  ),
          _Stage.scriptAsk => _ScriptAsk(
            script: l10n.scriptNameOr(_script.script, _script.script),
            through: <String>[
              for (final code
                  in state.scriptReadersKnown[_script.script] ??
                      const <String>[])
                widget.languageNames[code] ??
                    state.languages
                        .where((l) => l.code == code)
                        .firstOrNull
                        ?.name ??
                    code,
            ],
            onYes: () => _readsScript(state),
            onNo: () => _newToScript(state),
          ),
          _Stage.script => _question(
            state,
            language,
            _check!.question!,
            (right) => _scriptAnswer(state, right),
            inScript: _script.language,
            onCantSpeak: () => _scriptSkipSay(state),
          ),
          _Stage.walk => _question(
            state,
            language,
            _walk!.question!,
            _walkAnswer,
          ),
          _Stage.result => _Result(
            lines: _resultLines(l10n, state, language),
            tryAgainNote: _tryAgainNote(l10n),
            noFurther: !_canTryAgain,
            onTryAgain: _offersTryAgain ? () => _tryAgain(state) : null,
            last: _index + 1 == widget.languages.length,
            onNext: _next,
            choice: _reviewChoice(l10n, state),
          ),
        },
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

/// "Do you read Devanagari?" (owner, 2026-10-20: "Just ask (even when the
/// user has them known languages/scripts, just acknowledge that and mention
/// in the form) whether user knows devnagari"): always asked, saying so
/// where Languages I know says the learner reads it through [through].
class _ScriptAsk extends StatelessWidget {
  const _ScriptAsk({
    required this.script,
    required this.through,
    required this.onYes,
    required this.onNo,
  });

  final String script;
  final List<String> through;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
      children: <Widget>[
        Text(
          l10n.placementScriptAskTitle(script),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          through.isEmpty
              ? l10n.placementScriptAskBody
              : l10n.placementScriptAskThrough(
                  script,
                  through.join(l10n.commonListSeparator),
                ),
          style: theme.textTheme.bodyLarge!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          style: AppButtonStyles.tall(context),
          onPressed: onYes,
          child: Text(l10n.placementScriptYes),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onNo, child: Text(l10n.placementScriptNo)),
      ],
    );
  }
}

/// "Learn the Hindi alphabet?": the alphabet, or Latin letters only.
class _Alphabet extends StatelessWidget {
  const _Alphabet({required this.language, required this.onChoose});

  final LanguageInfo language;
  final ValueChanged<bool> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
      children: <Widget>[
        Text(
          l10n.alphabetAskTitle(
            language.name,
            l10n.scriptNameOr(language.script, language.name),
          ),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.alphabetAskBody(language.name),
          style: theme.textTheme.bodyLarge!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          style: AppButtonStyles.tall(context),
          onPressed: () => onChoose(true),
          child: Text(l10n.alphabetLearn),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => onChoose(false),
          child: Text(l10n.alphabetSkip),
        ),
      ],
    );
  }
}

/// Where the learner starts and why, Try again from here, and the way on.
class _Result extends StatelessWidget {
  const _Result({
    required this.lines,
    required this.tryAgainNote,
    required this.noFurther,
    required this.onTryAgain,
    required this.last,
    required this.onNext,
    this.choice,
  });

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
    // Not a lazy list: the result is short, and every part of it, the way on
    // included, is built, as it was before the choice was added (#761).
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (i, line) in lines.indexed) ...<Widget>[
            Text(
              line,
              style: i == lines.length - 1 - (noFurther ? 1 : 0)
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
          ],
          ?choice,
          const SizedBox(height: 20),
          FilledButton(
            style: AppButtonStyles.tall(context),
            onPressed: onNext,
            child: Text(last ? l10n.placementDone : l10n.placementNext),
          ),
          if (onTryAgain != null) ...<Widget>[
            const SizedBox(height: 24),
            if (tryAgainNote case final note?)
              Text(
                note,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onTryAgain,
              child: Text(l10n.placementTryAgain),
            ),
          ],
        ],
      ),
    );
  }
}
