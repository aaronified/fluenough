import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/features.dart';
import '../../app/skill.dart';
import '../../app/system_settings.dart';
import '../../core/models/deck.dart';
import '../../core/tts/tts_engine.dart';
import '../../core/tts/voice_apps.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/widgets/system_bar.dart';
import '../decks/word_sheet.dart' show isRude;
import 'settings_controls.dart';
import 'speech_test_sheet.dart';

/// One card per language, for hearing it and for speaking it, in the order
/// the learner learns them: the languages the profile learns first.
///
/// Design screen `voices`. Each card has the language's name, icon and
/// voice tag, then:
///
/// - **Listening:** whether the phone has a voice and how many, a choice of
///   voice where it has several (#123), and Play, which speaks a word of
///   the course in the chosen voice at the learner's speech rate. With no
///   voice, "Install a voice" opens the same help as "Install voices". A
///   course that uses several voice tags, such as `hi-IN` and `ur-PK` for
///   Hindustani, lists each (#641), and says which voice is in use: the
///   learner's choice (Automatic, or a voice, which may be another
///   engine's), or the course's other voice as a backup while the deck's
///   own is missing. Under "Other voices", the apps that add a voice for
///   the language, each with its store links (#642, `assets/voice_apps.yaml`);
///   coming back from a store asks the phone again.
/// - **Speaking:** whether the phone's recogniser hears the language, the
///   switch that allows it online where it is heard only online, and "Say
///   something", which opens [SpeechTestSheet]. With speaking off, "Switch
///   on speaking" in its place.
///
/// A failed Play shows the engine's error code in small print, and every
/// speech and voice error goes to the app log (`AppState.speak`,
/// `AppState.listenFor`).
///
/// Under the cards, as before: "Install voices in phone settings", which
/// opens Android's text-to-speech settings, or failing that the voice
/// engine's page for installing voice data, through
/// `AppState.systemSettings` (`Feature.voiceSettingsLink`), and explains
/// the way there where neither opens; and "Check again", which asks the
/// phone once more (`AppState.refreshVoices`, and `AppState.recheckSpeech`
/// once speaking is set up), for after installing a voice or a language
/// pack.
class VoicesPage extends StatefulWidget {
  const VoicesPage({super.key, this.apps});

  /// The voice apps listed under Other voices, for tests and the gallery.
  /// Null reads them from [appsAsset].
  final List<VoiceApp>? apps;

  /// The hand-kept list of apps that install as phone voices (#642).
  static const String appsAsset = 'assets/voice_apps.yaml';

  /// What Play says for [language]: the first card of its first vocabulary
  /// deck, or of a script deck when that is all there is, passing over any
  /// rude word. Null when no deck in the language has a card to say, such as
  /// a grammar deck on its own.
  static String? sampleFor(AppState state, LanguageInfo language) {
    final decks = <DeckEntry>[
      for (final deck in state.decks)
        if (deck.language.code == language.code && deck.cards.isNotEmpty) deck,
    ];
    if (decks.isEmpty) return null;
    // Never a rude word (docs/plans/offensive-words.md).
    for (final deck in <DeckEntry>[
      ...decks.where((d) => !d.isScript),
      ...decks.where((d) => d.isScript),
    ]) {
      for (final card in deck.cards) {
        if (!isRude(card, deck)) return card.target;
      }
    }
    return null;
  }

  /// [state]'s languages in the order the learner learns them: those the
  /// profile learns first, then the rest, each in the catalog's order.
  static List<LanguageInfo> ordered(AppState state) {
    final learns = state.currentProfile.learns;
    return <LanguageInfo>[
      // The IPA has no voice to choose: its examples are said in their own
      // languages' (ADR-0041).
      ...state.languages.where((l) => !l.isIpa && learns(l.code)),
      ...state.languages.where((l) => !l.isIpa && !learns(l.code)),
    ];
  }

  @override
  State<VoicesPage> createState() => _VoicesPageState();
}

class _VoicesPageState extends State<VoicesPage> with WidgetsBindingObserver {
  /// Asking the phone again, after Check again.
  bool _rechecking = false;

  /// The voice apps, once read from [VoicesPage.appsAsset].
  List<VoiceApp>? _apps;

  bool _loadingApps = false;

  /// Whether the learner went off to a store, so that coming back asks the
  /// phone for its voices again (#642).
  bool _inStore = false;

  /// Whether "Other languages on this phone" is open, once the learner
  /// opened or closed it.
  bool? _othersOpen;
  bool _opening = false;

  /// The voices each available tag has, once asked.
  final Map<String, List<TtsVoice>> _voices = <String, List<TtsVoice>>{};
  final Set<String> _asking = <String>{};

  /// The engine's error code from the last Play, by language code.
  final Map<String, String> _playFailed = <String, String>{};

  @override
  void initState() {
    super.initState();
    _apps = widget.apps;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_apps == null && !_loadingApps) {
      _loadingApps = true;
      unawaited(_loadApps(DefaultAssetBundle.of(context).loadString));
    }
  }

  Future<void> _loadApps(Future<String> Function(String key) load) async {
    List<VoiceApp> apps;
    try {
      apps = parseVoiceApps(await load(VoicesPage.appsAsset));
    } catch (_) {
      // The list is a help, not the page: without it there is none.
      apps = const <VoiceApp>[];
    }
    if (mounted && _apps == null) setState(() => _apps = apps);
  }

  /// Back from a store: the phone may have a new voice.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _inStore) {
      _inStore = false;
      if (!_rechecking) unawaited(_checkAgain());
    }
  }

  Future<void> _openStore(String url) {
    _inStore = true;
    return openLink(
      context,
      url,
      copied: AppLocalizations.of(context)!.voiceAppLinkCopied,
    );
  }

  void _askVoices(AppState state, LanguageInfo language) {
    final tag = language.ttsTag;
    if (_voices.containsKey(tag) || !_asking.add(tag)) return;
    state.voicesFor(language).then((voices) {
      _asking.remove(tag);
      if (mounted) setState(() => _voices[tag] = voices);
    });
  }

  Future<void> _checkAgain() async {
    final state = AppScope.read(context);
    setState(() {
      _rechecking = true;
      _voices.clear();
      _playFailed.clear();
    });
    await Future.wait(<Future<void>>[
      state.refreshVoices(),
      state.recheckSpeech(),
    ]);
    if (mounted) setState(() => _rechecking = false);
  }

  Future<void> _play(AppState state, LanguageInfo language, String text) async {
    final l10n = AppLocalizations.of(context)!;
    // Nothing is spoken while sound is off: say so, rather than "Speaking".
    if (!state.settings.soundOn) {
      showAppSnackBar(context, l10n.speakerSoundOff);
      return;
    }
    showAppSnackBar(context, l10n.voicesSpeaking(text));
    setState(() => _playFailed.remove(language.code));
    final error = await state.speak(text, language);
    if (error != null && mounted) {
      setState(() => _playFailed[language.code] = error);
    }
  }

  Future<void> _switchOnSpeaking() async {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final why = switch (await state.setSpeaking(true)) {
      SpeechSetup.ready => null,
      SpeechSetup.refused => l10n.settingsSpeakingRefused,
      SpeechSetup.noRecogniser => l10n.settingsSpeakingNoRecogniser,
    };
    if (why != null && mounted) showAppSnackBar(context, why);
  }

  /// Opens the phone's voice settings, or explains the way there when
  /// nothing opens.
  Future<void> _installVoices() async {
    // A second tap while the first is still asking the phone does nothing.
    if (_opening) return;
    _opening = true;
    try {
      final state = AppScope.read(context);
      if (state.features.isAvailable(Feature.voiceSettingsLink)) {
        try {
          final opened = await state.systemSettings.openVoiceSettings();
          if (opened != VoiceSettingsPage.none) return;
        } catch (_) {
          // Whatever went wrong, the way there is explained below instead.
        }
      }
      if (mounted) await _explainInstall();
    } finally {
      _opening = false;
    }
  }

  Future<void> _explainInstall() => showDialog<void>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return AlertDialog(
        title: Text(l10n.voicesInstallTitle),
        content: Text(l10n.voicesInstallSteps),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonGotIt),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final languages = VoicesPage.ordered(state);
    final learns = state.currentProfile.learns;
    // The languages learned, as cards; every other language with decks on
    // the phone, those only reviewed among them, folded below (#463).
    final learning = <LanguageInfo>[
      for (final l in languages)
        if (learns(l.code)) l,
    ];
    final others = <LanguageInfo>[
      for (final l in languages)
        if (!learns(l.code)) l,
    ];
    // Folded unless nothing is learned, then open, until the learner says.
    final othersOpen = _othersOpen ?? learning.isEmpty;
    final speaking = state.features.isAvailable(Feature.drillSpeaking);
    Widget card(LanguageInfo language) {
      final blocks = state.voiceBlocksOf(language.code);
      // The course's other voices, such as ur-PK beside hi-IN (#641).
      final others = <LanguageInfo>[
        for (final block in blocks)
          if (block.ttsTag != language.ttsTag) block,
      ];
      for (final other in others) {
        if (state.voiceStatus(other) == VoiceStatus.available) {
          _askVoices(state, other);
        }
      }
      final codes = <String>{
        language.code,
        for (final block in blocks) block.ttsTag.split('-').first,
      };
      return LanguageVoiceCard(
        language: language,
        glyph: _glyphOf(state, language),
        voiceStatus: _rechecking
            ? VoiceStatus.checking
            : state.voiceStatus(language),
        voices: _voices[language.ttsTag],
        otherTags: <CourseVoice>[
          for (final other in others)
            (
              tag: other.ttsTag,
              status: _rechecking
                  ? VoiceStatus.checking
                  : state.voiceStatus(other),
              backup: _rechecking ? null : state.backupVoice(other)?.ttsTag,
            ),
        ],
        otherVoices: <TtsVoice>[
          for (final other in others) ...?_voices[other.ttsTag],
        ],
        backup: _rechecking ? null : state.backupVoice(language)?.ttsTag,
        chosen: state.settings.voiceFor(language.code),
        sample: VoicesPage.sampleFor(state, language),
        playFailed: _playFailed[language.code],
        speechStatus: speaking ? _speechOf(state, language) : null,
        allowsOnline: state.settings.allowsOnlineSpeech(language.code),
        apps: <VoiceApp>[
          for (final app in _apps ?? const <VoiceApp>[])
            if (app.covers(codes)) app,
        ],
        onAskVoices: () => _askVoices(state, language),
        onChoose: (voice) => state.settings.chooseVoice(language.code, voice),
        onPlay: (text) => _play(state, language, text),
        onInstall: _installVoices,
        onSay: () => showSpeechTest(context, language),
        onSwitchOnSpeaking: _switchOnSpeaking,
        onAllowOnline: (on) =>
            state.settings.allowOnlineSpeech(language.code, on),
        onOpenStore: _openStore,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.voicesTitle),
        actions: const <Widget>[ReportButton()],
      ),
      // The voice chosen, speaking and online leave are settings.
      body: ListenableBuilder(
        listenable: state.settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            16,
            0,
            16,
            24,
          ).clearingSystemBar(context),
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
              child: Text(
                languages.isEmpty ? l10n.voicesNone : l10n.voicesIntro,
                style: theme.textTheme.bodyLarge!.copyWith(
                  fontSize: 15,
                  height: 22 / 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (learning.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              GroupedList(
                children: <Widget>[
                  for (final language in learning) card(language),
                ],
              ),
            ],
            if (others.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              _FoldHeader(
                label: l10n.voicesOtherLanguages,
                expanded: othersOpen,
                onToggle: () => setState(() => _othersOpen = !othersOpen),
              ),
              if (othersOpen) ...<Widget>[
                const SizedBox(height: 8),
                GroupedList(
                  children: <Widget>[
                    for (final language in others) card(language),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                textStyle: theme.textTheme.titleMedium,
              ),
              onPressed: _installVoices,
              icon: const Icon(Icons.settings_outlined),
              label: Text(l10n.voicesInstall, textAlign: TextAlign.center),
            ),
            if (languages.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _rechecking ? null : _checkAgain,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.voicesCheckAgain),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The recogniser's status for [language], or [SpeechStatus.off] while
  /// the speaking skill is switched off, so that the card offers to switch
  /// it on.
  static SpeechStatus _speechOf(AppState state, LanguageInfo language) =>
      state.settings.isEnabled(Skill.speaking)
      ? state.speechStatus(language)
      : SpeechStatus.off;

  /// The language's icon, the first letter of its own name (ADR-0027), or
  /// the glyph of its first deck when it names none.
  static String _glyphOf(AppState state, LanguageInfo language) {
    if (language.icon case final icon?) return icon;
    for (final entry in state.decks) {
      if (entry.language.code == language.code) return entry.glyph;
    }
    return language.name.characters.first;
  }
}

/// The header of "Other languages on this phone" (#463): tapping it opens
/// or folds the section, its arrow shows which, and a screen reader hears
/// it as expanded or collapsed.
class _FoldHeader extends StatelessWidget {
  const _FoldHeader({
    required this.label,
    required this.expanded,
    required this.onToggle,
  });

  final String label;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Semantics(
        expanded: expanded,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.small),
          onTap: onToggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(label, style: theme.textTheme.titleMedium),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of a course's voice tags beside the card's own, such as `ur-PK`
/// beside `hi-IN` (#641): whether the phone has it and, while it does not,
/// the tag of the voice that says its cards instead, or null.
typedef CourseVoice = ({String tag, VoiceStatus status, String? backup});

/// One language's card on the Voices page: hearing it and speaking it.
class LanguageVoiceCard extends StatelessWidget {
  const LanguageVoiceCard({
    super.key,
    required this.language,
    required this.glyph,
    required this.voiceStatus,
    required this.voices,
    required this.chosen,
    required this.sample,
    required this.speechStatus,
    required this.allowsOnline,
    required this.onAskVoices,
    required this.onChoose,
    required this.onPlay,
    required this.onInstall,
    required this.onSay,
    required this.onSwitchOnSpeaking,
    required this.onAllowOnline,
    required this.onOpenStore,
    this.otherTags = const <CourseVoice>[],
    this.otherVoices = const <TtsVoice>[],
    this.backup,
    this.apps = const <VoiceApp>[],
    this.playFailed,
  });

  final LanguageInfo language;

  /// The language's icon.
  final String glyph;

  final VoiceStatus voiceStatus;

  /// The phone's voices for it, or null until asked.
  final List<TtsVoice>? voices;

  /// The course's other voice tags and whether the phone has each: `ur-PK`
  /// beside `hi-IN` for Hindustani (#641).
  final List<CourseVoice> otherTags;

  /// The phone's voices for [otherTags], those asked for so far.
  final List<TtsVoice> otherVoices;

  /// The tag of the course's other voice that stands in for this one while
  /// it is missing, or null (#641).
  final String? backup;

  /// The voice apps that cover the language, for Other voices (#642).
  final List<VoiceApp> apps;

  /// The voice chosen for it, by name, or null for Automatic.
  final String? chosen;

  /// A word to speak, or null when the language's decks have none.
  final String? sample;

  /// The engine's error code from the last Play, or null.
  final String? playFailed;

  /// Whether the recogniser hears it, [SpeechStatus.off] while speaking is
  /// off, or null when speaking is not in this version.
  final SpeechStatus? speechStatus;

  /// Whether the learner allows it to be heard online.
  final bool allowsOnline;

  /// Asks for [voices], when they are still unknown.
  final VoidCallback onAskVoices;

  final ValueChanged<String?> onChoose;
  final ValueChanged<String> onPlay;
  final VoidCallback onInstall;
  final VoidCallback onSay;
  final VoidCallback onSwitchOnSpeaking;
  final ValueChanged<bool> onAllowOnline;

  /// Opens a voice app's store link.
  final ValueChanged<String> onOpenStore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final available = voiceStatus == VoiceStatus.available;
    if (available && voices == null) onAskVoices();

    final header = Row(
      children: <Widget>[
        ExcludeSemantics(
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondaryContainer,
            ),
            child: Text(
              glyph,
              locale: Locale(language.code),
              textScaler: TextScaler.noScaling,
              style: theme.textTheme.titleMedium!.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: language.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  const WidgetSpan(child: SizedBox(width: 6)),
                  TextSpan(
                    text: language.ttsTag,
                    style: theme.textTheme.bodySmall!.copyWith(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          header,
          const SizedBox(height: 12),
          ..._listening(context),
          if (speechStatus case final status?) ...<Widget>[
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 12),
            ..._speaking(context, status),
          ],
        ],
      ),
    );
  }

  List<Widget> _listening(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final voices = this.voices;
    final available = voiceStatus == VoiceStatus.available;
    final String line = switch (voiceStatus) {
      VoiceStatus.checking => l10n.voicesChecking,
      // With a backup the language is still heard: not "skipped".
      VoiceStatus.missing =>
        backup == null
            ? l10n.voicesMissing
            : l10n.deckVoiceMissing(language.ttsTag),
      // An engine that says yes has at least one voice, even if it lists
      // none by name.
      VoiceStatus.available =>
        voices == null
            ? l10n.voicesChecking
            : l10n.voicesInstalled(voices.isEmpty ? 1 : voices.length),
    };
    final say = sample;
    final failed = playFailed;
    // Every voice of the course the learner can choose among (#641).
    final choices = <TtsVoice>[...?voices, ...otherVoices];
    final chosenNow = choices.any((v) => v.name == chosen) ? chosen : null;
    final hasVoice =
        available || otherTags.any((t) => t.status == VoiceStatus.available);
    // A voice the course uses that the phone lacks and nothing stands in
    // for: it can be downloaded (#641).
    final canDownload =
        (voiceStatus == VoiceStatus.missing && backup == null) ||
        otherTags.any((t) => t.status == VoiceStatus.missing);
    final String? inUse;
    if (backup case final tag?) {
      inUse = l10n.voicesInUseBackup(tag);
    } else if (!available || voices == null) {
      inUse = null;
    } else if (chosenNow != null) {
      inUse = l10n.voicesInUseChosen(chosenNow);
    } else {
      inUse = l10n.voicesInUseAutomatic(language.ttsTag);
    }
    return <Widget>[
      _Part(
        icon: available ? Icons.volume_up_outlined : Icons.volume_off_outlined,
        title: l10n.voicesListening,
        line: line,
      ),
      for (final other in otherTags) ...<Widget>[
        const SizedBox(height: 8),
        _Part(
          icon: other.status == VoiceStatus.available
              ? Icons.volume_up_outlined
              : Icons.volume_off_outlined,
          title: l10n.voicesListening,
          line: switch (other.status) {
            VoiceStatus.available => l10n.deckVoiceInstalled(other.tag),
            VoiceStatus.missing =>
              other.backup == null
                  ? l10n.deckVoiceMissing(other.tag)
                  : l10n.deckVoiceBackup(other.tag, other.backup!),
            VoiceStatus.checking => l10n.deckVoiceChecking(other.tag),
          },
        ),
      ],
      if (inUse != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 34, top: 8),
          child: Text(inUse, style: settingsHelpStyle(theme)),
        ),
      if (canDownload)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 34, top: 8),
          child: Text(l10n.voicesDownloadHint, style: settingsHelpStyle(theme)),
        ),
      if (hasVoice && choices.length > 1) ...<Widget>[
        const SizedBox(height: 10),
        _VoiceChoice(
          language: language,
          voices: choices,
          chosen: chosenNow,
          onChoose: onChoose,
        ),
      ],
      if (failed != null) ...<Widget>[
        const SizedBox(height: 8),
        MergeSemantics(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.voicesPlayFailed,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                Text(
                  l10n.voicesErrorCode(failed),
                  style: settingsHelpStyle(theme),
                ),
              ],
            ),
          ),
        ),
      ],
      if (voiceStatus == VoiceStatus.missing || (available && say != null))
        _Actions(
          children: <Widget>[
            if (voiceStatus == VoiceStatus.missing)
              OutlinedButton.icon(
                style: AppButtonStyles.compact(context),
                onPressed: onInstall,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(l10n.voicesInstallOne),
              )
            else if (say != null)
              Semantics(
                button: true,
                label: l10n.voicesPlayLabel(language.name),
                excludeSemantics: true,
                onTap: () => onPlay(say),
                child: FilledButton.tonalIcon(
                  style: AppButtonStyles.compact(context),
                  onPressed: () => onPlay(say),
                  icon: const Icon(Icons.volume_up_outlined, size: 18),
                  label: Text(l10n.voicesPlay),
                ),
              ),
          ],
        ),
      // Apps that add a voice for it (#642), open where it has none.
      if (apps.isNotEmpty)
        _OtherVoices(
          apps: apps,
          open: canDownload,
          onOpenStore: onOpenStore,
        ),
    ];
  }

  List<Widget> _speaking(BuildContext context, SpeechStatus status) {
    final l10n = AppLocalizations.of(context)!;
    final online =
        status == SpeechStatus.online || status == SpeechStatus.onlineOnly;
    final String line = switch (status) {
      SpeechStatus.off => l10n.voicesSpeechOff,
      SpeechStatus.checking => l10n.voicesChecking,
      SpeechStatus.onDevice => l10n.voicesSpeechOnDevice,
      SpeechStatus.online ||
      SpeechStatus.onlineOnly => l10n.voicesSpeechOnlyOnline,
      SpeechStatus.missing => l10n.voicesSpeechMissing,
    };
    final canTest = switch (status) {
      SpeechStatus.onDevice ||
      SpeechStatus.online ||
      SpeechStatus.onlineOnly => true,
      _ => false,
    };
    return <Widget>[
      _Part(
        icon: status == SpeechStatus.missing
            ? Icons.mic_off_outlined
            : Icons.mic_none,
        title: l10n.voicesSpeakingPart,
        line: line,
      ),
      // Where it is heard only online, a switch of its own allows it: not
      // named Speaking, which it does not switch off.
      if (online) ...<Widget>[
        const SizedBox(height: 8),
        GroupedTile.toggle(
          leading: const Icon(Icons.cloud_outlined, size: 22),
          leadingGap: 12,
          title: l10n.voicesOnlineSwitch,
          subtitleOn: l10n.voicesSpeechOnline,
          subtitleOff: l10n.voicesSpeechOnlineOnly,
          padding: EdgeInsetsDirectional.zero,
          value: allowsOnline,
          onChanged: onAllowOnline,
        ),
      ],
      if (status == SpeechStatus.off || canTest)
        _Actions(
          children: <Widget>[
            if (status == SpeechStatus.off)
              FilledButton.tonalIcon(
                style: AppButtonStyles.compact(context),
                onPressed: onSwitchOnSpeaking,
                icon: const Icon(Icons.mic_none, size: 18),
                label: Text(l10n.voicesSpeechTurnOn),
              )
            else
              Semantics(
                button: true,
                label: l10n.voicesSayLabel(language.name),
                excludeSemantics: true,
                onTap: onSay,
                child: FilledButton.tonalIcon(
                  style: AppButtonStyles.compact(context),
                  onPressed: onSay,
                  icon: const Icon(Icons.record_voice_over_outlined, size: 18),
                  label: Text(l10n.voicesSay),
                ),
              ),
          ],
        ),
    ];
  }
}

/// A part of a card: an icon, its heading and its line, read as one.
class _Part extends StatelessWidget {
  const _Part({required this.icon, required this.title, required this.line});

  final IconData icon;
  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                Text(
                  line,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
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

/// A part's buttons, under its line, at the end.
class _Actions extends StatelessWidget {
  const _Actions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 8),
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: children,
    ),
  );
}

/// The menu of a language's voices: the phone's default first, then each
/// voice by the phone's name for it, marked where it needs a connection.
class _VoiceChoice extends StatelessWidget {
  const _VoiceChoice({
    required this.language,
    required this.voices,
    required this.chosen,
    required this.onChoose,
  });

  final LanguageInfo language;
  final List<TtsVoice> voices;
  final String? chosen;
  final ValueChanged<String?> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 34),
      child: DropdownButtonFormField<String?>(
        initialValue: chosen,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.voicesVoice,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: <DropdownMenuItem<String?>>[
          DropdownMenuItem<String?>(child: Text(l10n.voicesVoiceDefault)),
          for (final voice in voices)
            DropdownMenuItem<String?>(
              value: voice.name,
              child: Text(
                voice.networkRequired
                    ? l10n.voicesVoiceOnline(voice.name)
                    : voice.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChoose,
      ),
    );
  }
}

/// "Other voices" on a language's card (#642): the apps that add a voice for
/// it to the phone, folded until the learner opens it (open from the start
/// where the language has no voice), each with its links.
class _OtherVoices extends StatefulWidget {
  const _OtherVoices({
    required this.apps,
    required this.open,
    required this.onOpenStore,
  });

  final List<VoiceApp> apps;
  final bool open;
  final ValueChanged<String> onOpenStore;

  @override
  State<_OtherVoices> createState() => _OtherVoicesState();
}

class _OtherVoicesState extends State<_OtherVoices> {
  late bool _open = widget.open;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 8),
        _FoldHeader(
          label: l10n.voicesOthersTitle,
          expanded: _open,
          onToggle: () => setState(() => _open = !_open),
        ),
        if (_open) ...<Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
            child: Text(
              l10n.voicesOthersIntro,
              style: settingsHelpStyle(theme),
            ),
          ),
          for (final app in widget.apps)
            _VoiceAppTile(app: app, onOpenStore: widget.onOpenStore),
        ],
      ],
    );
  }
}

/// A voice app: its name and voice family, what it is, what it needs, and
/// a button for each place to get it.
class _VoiceAppTile extends StatelessWidget {
  const _VoiceAppTile({required this.app, required this.onOpenStore});

  final VoiceApp app;
  final ValueChanged<String> onOpenStore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final needs = <String>[
      if (app.minAndroid case final version?) l10n.voiceAppAndroid(version),
      if (app.arm64Only) l10n.voiceAppArm64,
    ];
    String storeName(String store) => switch (store) {
      'fdroid' => l10n.voiceAppFdroid,
      'play' => l10n.voiceAppPlay,
      _ => l10n.voiceAppGithub,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 12, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(app.name, style: theme.textTheme.titleSmall),
                Text(app.voices, style: settingsHelpStyle(theme)),
                Text(app.note, style: theme.textTheme.bodyMedium),
                if (needs.isNotEmpty)
                  Text(
                    needs.join(l10n.commonListSeparator),
                    style: settingsHelpStyle(theme),
                  ),
              ],
            ),
          ),
          _Actions(
            children: <Widget>[
              for (final (store, url) in app.links)
                Semantics(
                  button: true,
                  label: l10n.voiceAppGetLabel(app.name, storeName(store)),
                  excludeSemantics: true,
                  onTap: () => onOpenStore(url),
                  child: OutlinedButton(
                    style: AppButtonStyles.compact(context),
                    onPressed: () => onOpenStore(url),
                    child: Text(storeName(store)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
