import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_downloads.dart';
import '../../app/language_offer.dart';
import '../../app/script_test.dart';
import '../../core/data/spoken_languages.dart';
import '../../core/decks/deck_index.dart' show decksBeforeReady;
import '../../core/decks/ipa_course.dart';
import '../../core/decks/language_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';
import '../downloads/deck_update_controls.dart';
import '../downloads/download_text.dart';
import '../downloads/language_download_row.dart';
import '../downloads/update_escape.dart';
import '../profiles/spoken_languages_picker.dart';
import 'language_row.dart';
import 'language_sheet.dart';
import 'language_download.dart';
import 'placement_page.dart';
import 'script_test_page.dart';

/// The languages the learner learns (#211, #626, `docs/plans/language-picker.md`
/// and the approved mockup `docs/mockups/languages-learning.html`): asked on
/// first launch, after the languages they speak, and from Settings.
///
/// Laid out as Languages you know is: the search bar, pinned to the top once
/// the list scrolls; "Learning", the languages chosen; "Popular", the most
/// complete courses; then every language grouped by family, folded by
/// default. Each language is a plain row with its names, its Alpha, Beta or
/// Complete tag and the learner's own progress; a language on the phone shows
/// its size and state, "Update available" while an update waits, and Remove
/// as a red cross. Tapping a row opens its bottom sheet: the course (with its
/// A1, A2, B1 and culture line), the script details, and for a language
/// learned "Find my level". "Learn this language" is fixed at the sheet's
/// bottom and leads to two screens, each with Back: which scripts to learn,
/// then where to start. With deck downloads, a new language's download
/// starts as it is chosen. From Settings, one button at the top checks for
/// deck updates and then reads "Update all (N)". Continue waits only for each
/// new language's first five decks, then runs placement for those that chose
/// "Find my level" (ADR-0013) and saves; a language already learned needs
/// none. Stopping a language the learner learns asks first: its progress is
/// kept, but its decks leave Today. Leaving without saving stops the
/// downloads of the languages it chose.
class LanguagePickerPage extends StatefulWidget {
  const LanguagePickerPage({
    super.key,
    this.firstRun = false,
    this.ownNames,
    this.initialQuery = '',
    this.initialChosen = const <String>{},
    this.initialScript = const <String, bool>{},
    this.spokenList,
  });

  /// On first launch there is nothing to go back to, and finishing goes on
  /// to the app.
  final bool firstRun;

  /// Each language's own name, by code, for those the deck index does not
  /// name. Null reads them from `assets/languages.yaml`.
  final Map<String, String>? ownNames;

  /// For the gallery and tests: the search to open with, languages chosen
  /// besides those learned, and their "Learn the script" switches.
  final String initialQuery;
  final Set<String> initialChosen;
  final Map<String, bool> initialScript;

  /// The languages a learner can speak, from `assets/languages.yaml`, for
  /// the scripts each is written in (#554). Null reads them from there.
  final List<SpokenLanguage>? spokenList;

  @override
  State<LanguagePickerPage> createState() => _LanguagePickerPageState();
}

class _LanguagePickerPageState extends State<LanguagePickerPage> {
  /// The app, kept from initState: [_learning] is read first once the
  /// list shows, when the courses are known, which may be in [dispose],
  /// where the tree can no longer be read.
  late final AppState _app;
  late final Set<String> _learning = _learningOf(_app);
  late Set<String> _ticked = <String>{..._learning, ...widget.initialChosen};

  /// Which of the IPA course is chosen, "my languages" or "whole chart":
  /// two entries of one language in the list, with one progress between
  /// them (ADR-0041). Only meaningful while the IPA is [_ticked].
  late IpaScope _scope = _app.settings.ipaScope;

  /// The scope as it was saved, which the entry of the IPA the learner
  /// already has is.
  late final IpaScope _savedScope = _app.settings.ipaScope;

  /// Whether [language]'s entry is the one chosen: a language with one
  /// entry when its code is, the IPA when its scope is too.
  bool _isTicked(CatalogLanguage language) =>
      _ticked.contains(language.code) &&
      (language.variant == null || language.variant == _scope.name);

  /// Whether [language]'s entry is the one the learner already learns.
  bool _isLearned(CatalogLanguage language) =>
      _learning.contains(language.code) &&
      (language.variant == null || language.variant == _savedScope.name);

  /// The IPA as the two entries it is offered as, in the place of its one:
  /// "IPA: my languages" and "IPA: whole chart".
  List<CatalogLanguage> _withIpaEntries(
    AppLocalizations l10n,
    List<CatalogLanguage> all,
  ) => <CatalogLanguage>[
    for (final language in all)
      if (language.code == ipaLanguageCode) ...<CatalogLanguage>[
        language.asVariant(IpaScope.mine.name, l10n.pickerIpaMine),
        language.asVariant(IpaScope.whole.name, l10n.pickerIpaWhole),
      ] else
        language,
  ];

  /// The scripts each language's sheet chose to learn, by language: none
  /// is Latin letters only. Applied on Continue, the language's own script
  /// as "Learn the script" (#211); a script besides it is recorded, for
  /// placement per script (#481).
  final Map<String, Set<String>> _scriptsChosen = <String, Set<String>>{};

  /// Where each newly chosen language's sheet said to start: "Find my
  /// level" (true, the default) or at the beginning, for the language and
  /// for each of its scripts.
  final Map<String, bool> _findLanguage = <String, bool>{};
  final Map<String, Map<String, bool>> _findScripts =
      <String, Map<String, bool>>{};

  /// The families open in the list, by id. Every family starts folded.
  final Set<String> _openFamilies = <String>{};

  /// Whether each newly chosen language's script test was passed (#554):
  /// saved with the rest, its script lessons then placed as known.
  final Map<String, bool> _scriptPassed = <String, bool>{};

  /// The languages a learner can speak, for the scripts each is written in.
  late List<SpokenLanguage> _spokenList =
      widget.spokenList ?? const <SpokenLanguage>[];
  bool _listAsked = false;

  /// The language each newly chosen one is learned from, where the learner
  /// had a choice.
  final Map<String, String> _native = <String, String>{};

  late final TextEditingController _search = TextEditingController(
    text: widget.initialQuery,
  );
  late Map<String, String> _ownNames =
      widget.ownNames ?? const <String, String>{};
  final Map<String, GlobalKey> _cardKeys = <String, GlobalKey>{};
  final ScrollController _scroll = ScrollController();

  /// The languages whose download has shown on their card: it stays, to
  /// say when all of it is in.
  final Set<String> _downloadShown = <String>{};

  /// Each Try again after a failure, for [UpdateEscape]: of the list of
  /// courses, and of reading the decks.
  int _indexRetries = 0;
  int _catalogRetries = 0;

  /// Each chosen language's failures in a row, for [UpdateEscape], with
  /// how many of its decks were on the phone at the last: a failure after
  /// more decks came in starts again at one. Forgotten once it downloads,
  /// is cancelled or is no longer chosen ([_watchFailures]).
  final Map<String, ({int count, int decks})> _failedRuns =
      <String, ({int count, int decks})>{};

  /// The chosen languages whose download has failed, as last seen.
  final Set<String> _failing = <String>{};

  /// Whether what was chosen here was saved. A language newly chosen but
  /// not saved stops downloading when the page closes.
  bool _saved = false;

  /// What the current profile learns, once the learner has chosen;
  /// nothing on first launch.
  static Set<String> _learningOf(AppState state) => <String>{
    if (state.settings.learningChosen)
      for (final language in state.languagesOnOffer)
        if (state.currentProfile.learns(language.code)) language.code,
  };

  @override
  void initState() {
    super.initState();
    // The list of courses, read from GitHub the first time (#210).
    final state = _app = AppScope.read(context);
    final downloads = state.deckDownloads;
    downloads?.addListener(_watchFailures);
    if (downloads != null && downloads.index == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => downloads.refreshIndex(),
      );
    }
    for (final code in widget.initialChosen) {
      _startDownload(state, code);
    }
    _watchFailures();
    _search.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listAsked || widget.spokenList != null) {
      if (widget.ownNames == null && _ownNames.isEmpty) {
        _ownNames = <String, String>{
          for (final l in _spokenList) l.code: l.ownName,
        };
      }
      return;
    }
    _listAsked = true;
    DefaultAssetBundle.of(context)
        .loadString(SpokenLanguagesPicker.asset)
        .then(parseSpokenLanguages)
        .then((languages) {
          if (!mounted) return;
          setState(() {
            _spokenList = languages;
            if (widget.ownNames == null) {
              _ownNames = <String, String>{
                for (final l in languages) l.code: l.ownName,
              };
            }
          });
        }, onError: (Object _) {});
  }

  @override
  void dispose() {
    // Leaving without saving (Back, or a placement abandoned): a language
    // chosen here is not learned, so its download stops. What is in stays,
    // and its card here can finish it.
    final downloads = _app.deckDownloads;
    if (!_saved && downloads != null) {
      for (final code in _ticked.difference(_learning)) {
        if (downloads.hasJob(code)) unawaited(downloads.cancel(code));
      }
    }
    downloads?.removeListener(_watchFailures);
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<String> get _spoken => AppScope.read(context).settings.spokenLanguages;

  // ---------------------------------------------------------------------------
  // Choosing

  /// Whether the learner learns [language] now: saved, and still chosen.
  bool _learnsNow(CatalogLanguage language) =>
      _isLearned(language) && _isTicked(language);

  /// Learns [language], as its sheet answered: chosen, with the scripts to
  /// learn and where to start. A language already learned takes only the
  /// scripts, applied on Continue.
  void _learn(AppState state, CatalogLanguage language, SheetReply reply) {
    final code = language.code;
    final l10n = AppLocalizations.of(context)!;
    final variant = language.variant;
    final already = _learnsNow(language);
    // The other entry of the IPA, while it is chosen: its scope changes,
    // and it is still the one language, learned once.
    final switchScope =
        variant != null && _ticked.contains(code) && variant != _scope.name;
    setState(() {
      _scriptsChosen[code] = reply.scripts;
      if (already) return;
      _findLanguage[code] = reply.findLanguage;
      _findScripts[code] = reply.findScripts;
      _scriptPassed[code] = reply.scriptPassed;
      if (reply.native case final native?) _native[code] = native;
      _ticked = <String>{..._ticked, code};
      if (variant != null) _scope = IpaScope.tryParse(variant) ?? _scope;
    });
    if (already) return;
    _announce(l10n.pickerAnnounceChosen(language.name));
    if (!switchScope) _startDownload(state, code);
    _showCard(language.key);
  }

  /// Stops learning [language], or un-chooses it: its download stops if it
  /// was only asked for here.
  void _stop(AppState state, CatalogLanguage language) {
    final code = language.code;
    final l10n = AppLocalizations.of(context)!;
    final downloads = state.deckDownloads;
    // From the moment it is asked for, not only once its files are known.
    if (!_learning.contains(code) &&
        downloads != null &&
        downloads.hasJob(code)) {
      unawaited(downloads.cancel(code));
    }
    _forgetFailures(code);
    setState(() {
      _ticked = <String>{..._ticked}..remove(code);
      _scriptsChosen.remove(code);
    });
    _announce(l10n.pickerAnnounceUnchosen(language.name));
  }

  /// Opens [language]'s sheet and applies its answer.
  Future<void> _open(AppState state, CatalogLanguage language) async {
    final l10n = AppLocalizations.of(context)!;
    final spoken = state.settings.spokenLanguages;
    final code = language.code;
    final learns = _learnsNow(language);
    final chosen = _isTicked(language) && !learns;
    final native = _isLearned(language)
        ? state.courseNative(code)
        : _nativeChoice(state, language);
    final progress = language.progressFor(spoken, native: native);
    final downloads = state.deckDownloads;
    final download = downloads?.languageDownload(code, spoken);
    final onPhone = downloads?.languagesOnPhone.contains(code) ?? false;
    final size = downloads == null || download == null
        ? null
        : formatSize(
            l10n,
            onPhone ? downloads.sizeOnPhone(code) : download.totalBytes,
          );
    final share = learns && (progress?.hasPlan ?? false)
        ? state.learnedShare(code)
        : null;
    final scripts = _sheetScripts(state, language);
    final primary = language.script;
    final reply = await showModalBottomSheet<SheetReply>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => LanguageSheet(
        language: language,
        spoken: spoken,
        learned: learns,
        chosen: chosen,
        knows: spoken.contains(code),
        scripts: scripts,
        initialScripts: _scriptsFor(state, language),
        storage: size == null
            ? ''
            : (onPhone
                  ? l10n.pickerOnPhone(size)
                  : l10n.pickerNotOnPhone(size)),
        you: switch (share) {
          final share? => l10n.pickerYou(B1Progress.percentOf(share)),
          null when learns && !(progress?.hasPlan ?? false) =>
            l10n.pickerYouWords(state.learnedWords(code)),
          _ => null,
        },
        native: native,
        hasPlacement: code != ipaLanguageCode,
        findLanguage: _findLanguage[code] ?? true,
        findScripts: _findScripts[code] ?? const <String, bool>{},
        confirmStop: learns ? () => _confirmStop(state, language) : null,
        scriptPassed: _scriptPassed[code] ?? false,
        scriptTest: primary == null || !language.scriptDecks
            ? null
            : (context, passed, onResult) => _scriptTest(
                context,
                state,
                language,
                learns: learns,
                passed: passed,
                onResult: onResult,
                native: native,
              ),
      ),
    );
    if (reply == null || !mounted) return;
    switch (reply.action) {
      case SheetAction.learn:
        _learn(state, language, reply);
      case SheetAction.stop:
        _stop(state, language);
      case SheetAction.find:
        _findLevel(state, language);
    }
  }

  /// The scripts [language] offers to learn, one option each: the scripts
  /// `assets/languages.yaml` gives it except Latin, its own first; else the
  /// script of its decks. None for a course without script decks.
  List<String> _scriptCodes(CatalogLanguage language) {
    if (!language.scriptDecks) return const <String>[];
    final listed = <String>[
      for (final entry in _spokenList)
        if (entry.code == language.code)
          for (final script in entry.scripts)
            if (script != 'latin' && script.isNotEmpty) script,
    ];
    if (listed.isNotEmpty) return listed;
    final own = language.script;
    return own == null || own == 'latin' ? const <String>[] : <String>[own];
  }

  /// Whether the learner reads [script] through a language they know.
  bool _readsScript(CatalogLanguage language, String? script) {
    if (script == null) return false;
    final readers = scriptReaders(
      _spokenList,
      _app.settings.scriptsRead,
    )[script];
    return readers != null && readers.isNotEmpty;
  }

  /// The scripts ticked when [language]'s sheet opens: what the learner
  /// chose here before; for a language learned, its own script when it is
  /// learned; for a new one, each script they do not read already.
  Set<String> _scriptsFor(AppState state, CatalogLanguage language) {
    final code = language.code;
    if (_scriptsChosen[code] case final chosen?) return <String>{...chosen};
    final own = language.script;
    if (_learnsNow(language)) {
      return <String>{
        if (own != null && state.settings.learnsAlphabet(code)) own,
      };
    }
    return <String>{
      for (final script in _scriptCodes(language))
        if (script == own
            ? (widget.initialScript[code] ?? !_readsScript(language, script))
            : !_readsScript(language, script))
          script,
    };
  }

  /// What the sheet says of each of [language]'s scripts.
  List<SheetScript> _sheetScripts(AppState state, CatalogLanguage language) {
    final codes = _scriptCodes(language);
    if (codes.isEmpty) return const <SheetScript>[];
    final readers = scriptReaders(_spokenList, state.settings.scriptsRead);
    final names = <String, String>{for (final l in _spokenList) l.code: l.name};
    final learning = _scriptsFor(state, language);
    final catalog = state.catalogLanguages(ownNames: _ownNames);
    return <SheetScript>[
      for (final script in codes)
        () {
          final sharing = <String>[
            for (final other in catalog)
              if (other.code != language.code &&
                  _isTicked(other) &&
                  _scriptCodes(other).contains(script))
                other.name,
          ];
          final known = <String>[
            for (final reader in readers[script] ?? const <String>[])
              if (reader != language.code &&
                  !sharing.contains(names[reader] ?? reader))
                names[reader] ?? reader,
          ];
          final own = script == language.script;
          return SheetScript(
            code: script,
            reads: readers[script]?.isNotEmpty ?? false,
            learning: _learnsNow(language) && learning.contains(script),
            decks: own ? state.scriptPreview(language.code)?.decks : null,
            progress: own && _learnsNow(language)
                ? state.scriptProgress(language.code)
                : null,
            sharedLearning: sharing,
            sharedKnown: known,
          );
        }(),
    ];
  }

  /// Whether [language]'s primary script is learned: what the sheet chose,
  /// else the setting for a language learned, else on.
  bool _learnsScript(AppState state, CatalogLanguage language) {
    final code = language.code;
    if (_scriptsChosen[code] case final chosen?) {
      return chosen.contains(language.script);
    }
    if (widget.initialScript[code] case final on?) return on;
    return _isLearned(language) ? state.settings.learnsAlphabet(code) : true;
  }

  /// Tells a screen reader of a change it would not otherwise hear: a card
  /// that moves between the groups.
  void _announce(String text) => unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      text,
      Directionality.of(context),
    ),
  );

  /// A language not on the phone starts downloading as it is chosen.
  void _startDownload(AppState state, String code) {
    final downloads = state.deckDownloads;
    if (downloads == null || downloads.isReady(code, _spoken)) return;
    // One under way goes on; one that failed waits for Try again.
    if (downloads.isDownloading(code) || downloads.failureOf(code) != null) {
      return;
    }
    unawaited(state.downloadLanguage(code));
  }

  /// Keeps a row in view after it moves to "Learning", at the top of the
  /// list: when the move takes it out of what the list has built, back to
  /// the top first.
  void _showCard(String code) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_cardKeys[code]?.currentContext == null && _scroll.hasClients) {
        _scroll.jumpTo(0);
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(code));
        WidgetsBinding.instance.scheduleFrame();
        return;
      }
      _reveal(code);
    });
  }

  void _reveal(String code) {
    final context = _cardKeys[code]?.currentContext;
    if (context == null || !context.mounted || !_scroll.hasClients) return;
    // Above the screen, its top comes to the top; below, its end to the
    // bottom.
    final box = context.findRenderObject();
    if (box == null) return;
    final above =
        RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset <
        _scroll.offset;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 250),
      alignmentPolicy: above
          ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
          : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  Future<bool> _confirmStop(AppState state, CatalogLanguage language) async {
    final l10n = AppLocalizations.of(context)!;
    final share = state.learnedShare(language.code);
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pickerStopTitle(language.name)),
        content: Text(
          share == null
              ? l10n.pickerStopBodyPlain
              : l10n.pickerStopBody(B1Progress.percentOf(share)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.pickerStopConfirm),
          ),
        ],
      ),
    );
    return stop ?? false;
  }

  /// Find my level, on demand, for a language already learned (#626): the
  /// placement check from its first question, then the decks it places as
  /// known replace what placement found before. Nothing else changes.
  void _findLevel(AppState state, CatalogLanguage language) {
    final code = language.code;
    final native = state.courseNative(code);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/placement'),
        builder: (_) => PlacementPage(
          languages: <String>[code],
          asked: <String>{code},
          alphabet: <String, bool>{
            if (language.scriptDecks) code: state.settings.learnsAlphabet(code),
          },
          natives: <String, String>{code: ?native},
          onFinished: (found) {
            final settings = state.settings;
            final replaced = <String>{
              for (final entry in state.decks)
                if (entry.language.code == code) entry.id,
            };
            Navigator.of(context).pop();
            settings.placedDecks = <String>{
              for (final id in settings.placedDecks)
                if (!replaced.contains(id)) id,
              ...?found.placed[code],
            };
          },
        ),
      ),
    );
  }

  void _cancel(AppState state, CatalogLanguage language) {
    final code = language.code;
    final downloads = state.deckDownloads!;
    final ready = downloads.isReady(code, _spoken);
    _forgetFailures(code);
    unawaited(downloads.cancel(code));
    // Before its first decks are in, a cancelled language cannot be
    // started, so it is no longer chosen. After, the course works with
    // what arrived, and the rest comes from its card here.
    if (ready) return;
    setState(() => _ticked = <String>{..._ticked}..remove(code));
    // Its card closes, taking the line that says where the rest comes
    // from, so that is a toast, which a screen reader announces.
    showAppSnackBar(
      context,
      AppLocalizations.of(context)!.pickerCancelledUnchosen(language.name),
    );
  }

  /// Counts each chosen language's failures in a row ([_failedRuns]): a
  /// new failure adds one, unless decks arrived since the last; a download
  /// that ends without one, finished or cancelled, forgets them.
  void _watchFailures() {
    final downloads = _app.deckDownloads;
    if (downloads == null) return;
    for (final code in _ticked) {
      if (downloads.failureOf(code) != null) {
        if (!_failing.add(code)) continue;
        final decks =
            downloads
                .languageDownload(code, _app.settings.spokenLanguages)
                ?.decks ??
            0;
        final last = _failedRuns[code];
        _failedRuns[code] = (
          count: last != null && decks <= last.decks ? last.count + 1 : 1,
          decks: decks,
        );
      } else {
        _failing.remove(code);
        if (!downloads.isDownloading(code)) _failedRuns.remove(code);
      }
    }
  }

  /// Forgets [code]'s failures: it is no longer chosen, or was cancelled.
  void _forgetFailures(String code) {
    _failing.remove(code);
    _failedRuns.remove(code);
  }

  void _retry(AppState state, String code) {
    final downloads = state.deckDownloads!;
    if (downloads.isReady(code, _spoken)) {
      unawaited(downloads.downloadRest(code, _spoken));
    } else {
      unawaited(state.downloadLanguage(code));
    }
  }

  /// The language [language] is to be learned from, where the learner
  /// speaks more than one that teaches it: what they picked on its card,
  /// else what the app suggests, the best covered. Placement does not ask
  /// again. Null when there is no choice to make.
  String? _nativeChoice(AppState state, CatalogLanguage language) {
    final spoken = state.settings.spokenLanguages;
    final options = language.spokenNatives(spoken);
    if (options.length < 2) return null;
    final code = language.code;
    final suggested = state.courseNative(code);
    if (_native[code] case final picked?) return picked;
    if (options.any((o) => o.code == suggested)) return suggested;
    // Before its decks are on the phone, the best covered by the index,
    // ties to the language the learner knows best.
    int covered(CatalogNative o) =>
        o.progress.hasPlan ? o.progress.writtenWords : o.progress.courseWords;
    return options
        .reduce((best, o) => covered(o) > covered(best) ? o : best)
        .code;
  }

  // ---------------------------------------------------------------------------
  // Continue

  /// The newly chosen languages, in the catalog's order.
  List<String> _added(List<CatalogLanguage> all) => <String>{
    for (final language in all)
      if (_ticked.contains(language.code) && !_learning.contains(language.code))
        language.code,
  }.toList();

  /// Those of [added] whose first decks are not on the phone yet.
  List<String> _waiting(AppState state, List<String> added) {
    final downloads = state.deckDownloads;
    if (downloads == null) return const <String>[];
    return <String>[
      for (final code in added)
        if (!downloads.isReady(code, _spoken)) code,
    ];
  }

  /// Whether [language] is placed by a check after Continue: the learner
  /// chose "Find my level" for it, which is the default, whether or not they
  /// speak it (the check cannot place a script apart from the language yet:
  /// #481).
  bool _placed(CatalogLanguage language) =>
      _findLanguage[language.code] ?? true;

  void _continue(AppState state, List<CatalogLanguage> all) {
    final chosen = <String>{
      for (final language in all)
        if (_ticked.contains(language.code)) language.code,
    }.toList();
    // The IPA is placed by nothing: it has no level to find.
    final added = <String>[
      for (final code in _added(all))
        if (code != ipaLanguageCode) code,
    ];
    final byCode = <String, CatalogLanguage>{for (final l in all) l.code: l};
    // Whether to learn each script, for a language with script decks that is
    // new, or whose sheet answered: its own script is the course's alphabet.
    final alphabet = <String, bool>{
      for (final code in chosen)
        if (byCode[code] case final language?
            when language.scriptDecks &&
                (added.contains(code) || _scriptsChosen.containsKey(code)))
          code: _learnsScript(state, language),
    };
    final natives = <String, String>{
      for (final code in added)
        if (byCode[code] case final language?)
          code: ?_nativeChoice(state, language),
    };
    final place = <String>[
      for (final code in added)
        if (_placed(byCode[code]!)) code,
    ];
    if (place.isEmpty) {
      _save(
        state,
        chosen,
        const <String, Set<String>>{},
        alphabet: alphabet,
        natives: natives,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/placement'),
        builder: (_) => PlacementPage(
          languages: place,
          // "Find my level" is asked for already, in each sheet.
          asked: place.toSet(),
          alphabet: <String, bool>{
            for (final code in place) code: ?alphabet[code],
          },
          natives: <String, String>{
            for (final code in place) code: ?natives[code],
          },
          onFinished: (found) => _save(
            state,
            chosen,
            found.placed,
            alphabet: <String, bool>{...alphabet, ...found.alphabet},
            natives: <String, String>{...natives, ...found.natives},
          ),
        ),
      ),
    );
  }

  /// Saves [chosen], with [placed] replacing what placement found before for
  /// each language in it, and goes back to where this page was opened from:
  /// the app, on first launch.
  void _save(
    AppState state,
    List<String> chosen,
    Map<String, Set<String>> placed, {
    Map<String, bool> alphabet = const <String, bool>{},
    Map<String, String> natives = const <String, String>{},
  }) {
    _saved = true;
    final settings = state.settings;
    settings.ipaScope = _scope;
    for (final MapEntry(:key, :value) in alphabet.entries) {
      settings.setLearnsAlphabet(key, value);
    }
    for (final MapEntry(:key, :value) in natives.entries) {
      state.chooseNative(key, value);
    }
    final replaced = <String>{
      for (final entry in state.decks)
        if (placed.containsKey(entry.language.code)) entry.id,
    };
    // Back to the first route first: from Settings that is the app; on
    // first launch it is this page, which saving then swaps for the app.
    Navigator.of(context).popUntil((route) => route.isFirst);
    settings.placedDecks = <String>{
      for (final id in settings.placedDecks)
        if (!replaced.contains(id)) id,
      for (final ids in placed.values) ...ids,
    };
    // A passed script test places the script lessons, whatever placement
    // found (#554).
    for (final code in chosen) {
      if ((_scriptPassed[code] ?? false) && settings.learnsAlphabet(code)) {
        state.skipScriptLessons(code, true);
      }
    }
    settings.learningChosen = true;
    state.setLearningLanguages(chosen);
  }

  // ---------------------------------------------------------------------------
  // The page

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final downloads = state.deckDownloads;
    return Scaffold(
      appBar: widget.firstRun
          ? null
          : AppBar(
              title: Text(AppLocalizations.of(context)!.pickerSettingsTitle),
              actions: const <Widget>[ReportButton()],
            ),
      body: SafeArea(
        bottom: false,
        top: widget.firstRun,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: downloads == null
                  ? _body(context, state)
                  : ListenableBuilder(
                      listenable: downloads,
                      builder: (context, _) =>
                          _body(context, state, indexing: downloads),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The list, or why there is none yet. With [indexing], the list of
  /// courses on GitHub, which is read before anything else: while there is
  /// none and nothing on the phone, the page waits for it, or says why it
  /// could not be read and offers Try again.
  Widget _body(
    BuildContext context,
    AppState state, {
    DeckDownloads? indexing,
  }) {
    final waiting = _waitingBody(context, state, indexing: indexing);
    if (waiting == null) return _list(context, state);
    if (!widget.firstRun) return waiting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TabHeader(title: AppLocalizations.of(context)!.learnTitle),
        Expanded(child: waiting),
      ],
    );
  }

  /// Why there is no list yet, or null once there is one.
  Widget? _waitingBody(
    BuildContext context,
    AppState state, {
    DeckDownloads? indexing,
  }) {
    final l10n = AppLocalizations.of(context)!;
    if (indexing != null &&
        state.languagesOnOffer.isEmpty &&
        state.status != CatalogStatus.loading) {
      if (indexing.indexStatus == IndexStatus.failed) {
        return EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l10n.downloadsIndexFailed,
          body: downloadFailureText(l10n, indexing.indexFailure),
          action: _withEscape(
            FilledButton(
              onPressed: () {
                setState(() => _indexRetries++);
                unawaited(indexing.refreshIndex());
              },
              child: Text(l10n.commonRetry),
            ),
            failures: _indexRetries + 1,
            detail: 'course list: ${indexing.indexFailure?.name}',
          ),
        );
      }
      return Center(
        child: CircularProgressIndicator(
          semanticsLabel: l10n.downloadsIndexLoading,
        ),
      );
    }
    return switch (state.status) {
      CatalogStatus.loading => Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.learnLoading),
      ),
      CatalogStatus.failed => EmptyState(
        icon: Icons.error_outline,
        title: l10n.commonDecksFailed,
        body: l10n.commonDecksFailedBody,
        action: _withEscape(
          FilledButton(
            onPressed: () {
              setState(() => _catalogRetries++);
              unawaited(state.reload());
            },
            child: Text(l10n.commonRetry),
          ),
          failures: _catalogRetries + 1,
          detail: 'decks failed to load',
        ),
      ),
      CatalogStatus.ready => null,
    };
  }

  /// A failure's Try again, with the update check under it: on first
  /// launch, Settings and its check are out of reach, and a fault in the
  /// app itself can be what fails, as in 0.4.0.
  Widget _withEscape(
    Widget retry, {
    required int failures,
    required String detail,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      retry,
      const SizedBox(height: 8),
      UpdateEscape(failures: failures, detail: detail),
    ],
  );

  /// The families, in the order Languages you know lists them: as
  /// `assets/languages.yaml` first uses them.
  List<String> get _familyOrder =>
      <String>{for (final language in _spokenList) ?language.family}.toList();

  Map<String, String> get _familyOf => <String, String>{
    for (final language in _spokenList) language.code: ?language.family,
  };

  Widget _list(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final spoken = state.settings.spokenLanguages;
    final base = state.catalogLanguages(ownNames: _ownNames);
    final all = _withIpaEntries(l10n, base);
    final query = _search.text;
    final searching = query.trim().isNotEmpty;
    final shown = <CatalogLanguage>[
      for (final language in all)
        if (LanguageSearch.matches(language, query)) language,
    ];
    final learning = pickerOrder(shown.where(_isTicked), spoken);
    final popular = popularOf(all.where((l) => !_isTicked(l)), spoken);
    final families = groupByFamily(
      shown,
      order: _familyOrder,
      familyOf: _familyOf,
    );
    final totals = <String, int>{
      for (final family in groupByFamily(
        all,
        order: _familyOrder,
        familyOf: _familyOf,
      ))
        family.id: family.languages.length,
    };
    final added = _added(all);
    final waiting = _waiting(state, added);
    final names = <String, String>{for (final l in base) l.code: l.name};
    String join(List<String> codes) =>
        <String>[for (final code in codes) names[code] ?? code]
            .join(l10n.commonListSeparator);
    final hint = _ticked.isEmpty
        ? l10n.pickerHintChoose
        : waiting.isNotEmpty
        ? l10n.pickerHintWaiting(decksBeforeReady, join(waiting))
        : added.isNotEmpty
        ? l10n.pickerHintNext(join(added))
        : null;
    final canGo = _ticked.isNotEmpty && waiting.isEmpty;
    // A chosen language whose decks will not come: on first launch nothing
    // else can be reached, so the update check is offered here.
    final failed = <String>[
      for (final code in _ticked)
        if (state.deckDownloads?.failureOf(code) case final failure?)
          '$code: ${failure.name}',
    ];
    // Each language's own failures in a row: the most of any failing now.
    final runs = <int>[
      for (final code in _ticked)
        if (state.deckDownloads?.failureOf(code) != null)
          _failedRuns[code]?.count ?? 1,
    ];

    // A language can be in "Popular" and its family at once: each row's key
    // names its group, as keys in one list must differ.
    Widget row(
      CatalogLanguage language, {
      required bool learningGroup,
      String group = 'listed',
    }) {
      final tile = _row(context, state, language, query, learningGroup, group);
      return learningGroup
          ? KeyedSubtree(
              key: _cardKeys.putIfAbsent(language.key, GlobalKey.new),
              child: tile,
            )
          : tile;
    }

    final body = <Widget>[
      if (searching) ...<Widget>[
        for (final family in families) ...<Widget>[
          PickerHeading(
            l10n.knownFamily(family.id),
            note: l10n.knownSearchMatches(
              family.languages.length,
              totals[family.id] ?? family.languages.length,
            ),
          ),
          for (final language in family.languages)
            row(language, learningGroup: false),
        ],
      ] else ...<Widget>[
        if (learning.isNotEmpty) ...<Widget>[
          PickerHeading(l10n.pickerGroupLearning(learning.length)),
          for (final language in learning) row(language, learningGroup: true),
        ],
        if (popular.isNotEmpty) ...<Widget>[
          PickerHeading(
            l10n.pickerGroupPopular(popular.length),
            note: l10n.pickerPopularNote,
          ),
          for (final language in popular)
            row(language, learningGroup: false, group: 'popular'),
        ],
        PickerHeading(l10n.knownAllLanguages, note: l10n.knownByFamily),
        for (final family in families) ...<Widget>[
          FamilyRow(
            id: family.id,
            count: family.languages.length,
            open: _openFamilies.contains(family.id),
            onToggle: () => setState(
              () => _openFamilies.contains(family.id)
                  ? _openFamilies.remove(family.id)
                  : _openFamilies.add(family.id),
            ),
          ),
          if (_openFamilies.contains(family.id))
            for (final language in family.languages)
              row(language, learningGroup: false),
        ],
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          // On first launch the title scrolls away and the search stays: at
          // large text sizes, a title fixed above it would leave the list no
          // room.
          child: CustomScrollView(
            controller: _scroll,
            slivers: <Widget>[
              if (widget.firstRun)
                SliverToBoxAdapter(child: TabHeader(title: l10n.learnTitle)),
              // The intro and the update button scroll away with the list;
              // the search bar below them stays at the top once they have
              // (owner, 2026-10-18).
              SliverToBoxAdapter(
                child: widget.firstRun && !searching
                    ? Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSizes.gutter + 8,
                          8,
                          AppSizes.gutter,
                          0,
                        ),
                        child: Text(
                          l10n.learnBody,
                          style: theme.textTheme.bodyLarge!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    // Deck updates (#467), where Settings' Deck downloads
                    // page was: above the languages, out of a search.
                    : !widget.firstRun && !searching
                    ? switch (state.deckDownloads) {
                        final downloads? => Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            AppSizes.gutter + 8,
                            8,
                            AppSizes.gutter,
                            0,
                          ),
                          child: DeckUpdateControls(
                            downloads: downloads,
                            names: names,
                          ),
                        ),
                        null => const SizedBox.shrink(),
                      }
                    : const SizedBox.shrink(),
              ),
              PinnedHeaderSliver(
                child: ColoredBox(
                  color: theme.scaffoldBackgroundColor,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSizes.gutter,
                      8,
                      AppSizes.gutter,
                      4,
                    ),
                    // One screen-reader node, the bar's full 56 in height,
                    // named by its hint even once the hint gives way to a
                    // search, as on Decks; the clear button sits over it,
                    // a node of its own.
                    child: Stack(
                      alignment: AlignmentDirectional.centerEnd,
                      children: <Widget>[
                        MergeSemantics(
                          child: Semantics(
                            label: query.isEmpty ? null : l10n.pickerSearchHint,
                            child: SearchBar(
                              controller: _search,
                              hintText: l10n.pickerSearchHint,
                              elevation: const WidgetStatePropertyAll<double>(
                                0,
                              ),
                              constraints: const BoxConstraints(minHeight: 56),
                              padding:
                                  const WidgetStatePropertyAll<
                                    EdgeInsetsGeometry
                                  >(
                                    EdgeInsetsDirectional.symmetric(
                                      horizontal: 16,
                                    ),
                                  ),
                              leading: const Icon(Icons.search),
                              trailing: <Widget>[
                                if (query.isNotEmpty) const SizedBox(width: 40),
                              ],
                            ),
                          ),
                        ),
                        if (query.isNotEmpty)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 4),
                            child: IconButton(
                              tooltip: l10n.pickerClearSearch,
                              icon: const Icon(Icons.close),
                              onPressed: _search.clear,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (shown.isEmpty)
                SliverFillRemaining(
                  // Announced as it appears, title and body as one node: the
                  // list empties silently.
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label:
                        '${l10n.pickerNoMatchTitle(query.trim())}\n'
                        '${l10n.pickerNoMatchBody}',
                    excludeSemantics: true,
                    child: EmptyState(
                      icon: Icons.search,
                      title: l10n.pickerNoMatchTitle(query.trim()),
                      body: l10n.pickerNoMatchBody,
                    ),
                  ),
                )
              else
                // The list ends with its last row (owner, 2026-10-18): no
                // blank area above Continue.
                SliverPadding(
                  padding: const EdgeInsetsDirectional.only(bottom: 4),
                  sliver: SliverList.list(children: body),
                ),
            ],
          ),
        ),
        Material(
          color: theme.colorScheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSizes.gutter,
                12,
                AppSizes.gutter,
                AppSizes.gutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (failed.isNotEmpty) ...<Widget>[
                    UpdateEscape(
                      failures: runs.reduce(math.max),
                      detail: 'decks of ${failed.join(', ')}',
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (hint != null) ...<Widget>[
                    // Not a live region: a download's ready point is
                    // announced from its row, once.
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    style: AppButtonStyles.tall(context),
                    onPressed: canGo ? () => _continue(state, all) : null,
                    child: Text(l10n.commonContinue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Whether [code]'s card shows its download: while it downloads, after
  /// it failed or stopped part way, and once shown, until the page closes.
  bool _showsDownload(
    DeckDownloads downloads,
    LanguageDownload download,
    String code,
  ) {
    final active =
        downloads.isDownloading(code) ||
        downloads.failureOf(code) != null ||
        (download.decks > 0 && download.decks < download.totalDecks);
    if (active) _downloadShown.add(code);
    return active || _downloadShown.contains(code);
  }

  /// The script test's offer (#554) for [language]'s own script, in the
  /// sheet's script screen, for a learner who reads it through another
  /// language they know; null for anyone else, and for a language whose
  /// script is its own, such as Telugu to a reader of Bengali. [passed] is
  /// whether a passed test has skipped its lessons, and [onResult] hears
  /// what a test finds.
  Widget? _scriptTest(
    BuildContext context,
    AppState state,
    CatalogLanguage language, {
    required bool learns,
    required bool passed,
    required ValueChanged<bool> onResult,
    String? native,
  }) {
    final script = language.script;
    if (script == null) return null;
    final code = language.code;
    final readers = scriptReaders(_spokenList, state.settings.scriptsRead);
    final names = <String, String>{for (final l in _spokenList) l.code: l.name};
    final through = <String>[
      for (final reader in readers[script] ?? const <String>[])
        if (reader != code) names[reader] ?? reader,
    ];
    if (through.isEmpty) return null;
    final l10n = AppLocalizations.of(context)!;
    final lessons = state.scriptLessons(code, native: native);
    final scriptName = l10n.scriptNameOr(script, language.name);
    return ScriptTestOffer(
      key: ValueKey<String>('script-test-$code'),
      language: language.name,
      script: scriptName,
      through: through,
      ownLetters: <String, ScriptLetter>{
        for (final entry in lessons)
          for (final card in entry.cards)
            if (card.tags.contains(ownLetterTag))
              card.target: (letter: card.target, reading: card.reading),
      }.values.toList(),
      skipped: learns
          ? state.scriptLessonsSkipped(code, native: native)
          : passed,
      onTake: lessons.isEmpty
          ? null
          : () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  settings: const RouteSettings(name: '/script-test'),
                  builder: (_) =>
                      ScriptTestPage(script: scriptName, lessons: lessons),
                ),
              );
              if (result == null || !mounted) return;
              if (learns) {
                state.skipScriptLessons(code, result, native: native);
              }
              onResult(result);
            },
    );
  }

  /// [language]'s row: opens its sheet. A language on the phone, learned or
  /// not chosen, has its row of buttons in every group and in search
  /// (#467, #626), and one newly chosen its download below.
  Widget _row(
    BuildContext context,
    AppState state,
    CatalogLanguage language,
    String query,
    bool learningGroup,
    String group,
  ) {
    final spoken = state.settings.spokenLanguages;
    final code = language.code;
    final ticked = _isTicked(language);
    final learns = _isLearned(language) && ticked;
    final native = _isLearned(language)
        ? state.courseNative(code)
        : _nativeChoice(state, language);
    final progress = language.progressFor(spoken, native: native);
    final downloads = state.deckDownloads;
    final download = downloads?.languageDownload(code, spoken);
    final share = learns && progress != null && progress.hasPlan
        ? state.learnedShare(code)
        : null;
    return LanguageRow(
      key: ValueKey<String>(
        learningGroup ? 'language-${language.key}' : '$group-${language.key}',
      ),
      language: language,
      chosen: ticked,
      onTap: () => _open(state, language),
      progress: progress,
      you: share,
      youWords: learns && share == null && !(progress?.hasPlan ?? false)
          ? state.learnedWords(code)
          : null,
      query: query,
      // A language on the phone has its size, state and buttons (#467).
      actions:
          !widget.firstRun &&
              (learns || !ticked) &&
              downloads != null &&
              hasDownloadRow(downloads, code)
          ? LanguageRowActions(
              code: code,
              name: language.name,
              // Removed, it is no longer learned: Continue must not bring it
              // back.
              onRemoved: () {
                if (!mounted) return;
                setState(() {
                  _learning.remove(code);
                  _ticked = <String>{..._ticked}..remove(code);
                });
              },
            )
          : null,
      below: <Widget>[
        if (learningGroup &&
            ticked &&
            !learns &&
            downloads != null &&
            download != null &&
            _showsDownload(downloads, download, code))
          LanguageDownloadBlock(
            name: language.name,
            download: download,
            downloading: downloads.isDownloading(code),
            paused: downloads.isPaused(code),
            failure: downloads.failureOf(code),
            onCancel: () => _cancel(state, language),
            onRetry: () => _retry(state, code),
          ),
      ],
    );
  }
}
