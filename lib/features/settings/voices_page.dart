import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/features.dart';
import '../../app/skill.dart';
import '../../app/system_settings.dart';
import '../../core/models/deck.dart';
import '../../core/tts/tts_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';
import 'settings_controls.dart';
import 'speech_test_sheet.dart';

/// One card per language, for hearing it and for speaking it
/// (docs/plans/voices-per-language.md), in the order the learner learns
/// them: the languages the profile learns first.
///
/// Design screen `voices`. Each card has the language's name, icon and
/// voice tag, then:
///
/// - **Listening:** whether the phone has a voice and how many, a choice of
///   voice where it has several (#123), and Play, which speaks a word of
///   the course in the chosen voice at the learner's speech rate. With no
///   voice, "Install a voice" opens the same help as "Install voices".
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
  const VoicesPage({super.key});

  /// What Play says for [language]: the first card of its first vocabulary
  /// deck, or of a script deck when that is all there is. Null when no deck
  /// in the language has cards, such as a grammar deck on its own.
  static String? sampleFor(AppState state, LanguageInfo language) {
    final decks = <DeckEntry>[
      for (final deck in state.decks)
        if (deck.language.code == language.code && deck.cards.isNotEmpty) deck,
    ];
    if (decks.isEmpty) return null;
    final deck = decks.firstWhere(
      (d) => !d.isScript,
      orElse: () => decks.first,
    );
    return deck.cards.first.target;
  }

  /// [state]'s languages in the order the learner learns them: those the
  /// profile learns first, then the rest, each in the catalog's order.
  static List<LanguageInfo> ordered(AppState state) {
    final learns = state.currentProfile.learns;
    return <LanguageInfo>[
      ...state.languages.where((l) => learns(l.code)),
      ...state.languages.where((l) => !learns(l.code)),
    ];
  }

  @override
  State<VoicesPage> createState() => _VoicesPageState();
}

class _VoicesPageState extends State<VoicesPage> {
  /// Asking the phone again, after Check again.
  bool _rechecking = false;
  bool _opening = false;

  /// The voices each available tag has, once asked.
  final Map<String, List<TtsVoice>> _voices = <String, List<TtsVoice>>{};
  final Set<String> _asking = <String>{};

  /// The engine's error code from the last Play, by language code.
  final Map<String, String> _playFailed = <String, String>{};

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
    final speaking = state.features.isAvailable(Feature.drillSpeaking);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.voicesTitle),
        actions: const <Widget>[ReportButton()],
      ),
      // The voice chosen, speaking and online leave are settings.
      body: ListenableBuilder(
        listenable: state.settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
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
            if (languages.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              GroupedList(
                children: <Widget>[
                  for (final language in languages)
                    LanguageVoiceCard(
                      language: language,
                      glyph: _glyphOf(state, language),
                      voiceStatus: _rechecking
                          ? VoiceStatus.checking
                          : state.voiceStatus(language),
                      voices: _voices[language.ttsTag],
                      chosen: state.settings.voiceFor(language.code),
                      sample: VoicesPage.sampleFor(state, language),
                      playFailed: _playFailed[language.code],
                      speechStatus: speaking
                          ? _speechOf(state, language)
                          : null,
                      allowsOnline: state.settings.allowsOnlineSpeech(
                        language.code,
                      ),
                      onAskVoices: () => _askVoices(state, language),
                      onChoose: (voice) =>
                          state.settings.chooseVoice(language.code, voice),
                      onPlay: (text) => _play(state, language, text),
                      onInstall: _installVoices,
                      onSay: () => showSpeechTest(context, language),
                      onSwitchOnSpeaking: _switchOnSpeaking,
                      onAllowOnline: (on) =>
                          state.settings.allowOnlineSpeech(language.code, on),
                    ),
                ],
              ),
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
    this.playFailed,
  });

  final LanguageInfo language;

  /// The language's icon.
  final String glyph;

  final VoiceStatus voiceStatus;

  /// The phone's voices for it, or null until asked.
  final List<TtsVoice>? voices;

  /// The voice chosen for it, by name, or null for the phone's default.
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
      VoiceStatus.missing => l10n.voicesMissing,
      // An engine that says yes has at least one voice, even if it lists
      // none by name.
      VoiceStatus.available =>
        voices == null
            ? l10n.voicesChecking
            : l10n.voicesInstalled(voices.isEmpty ? 1 : voices.length),
    };
    final say = sample;
    final failed = playFailed;
    return <Widget>[
      _Part(
        icon: available ? Icons.volume_up_outlined : Icons.volume_off_outlined,
        title: l10n.voicesListening,
        line: line,
      ),
      if (available && voices != null && voices.length > 1) ...<Widget>[
        const SizedBox(height: 10),
        _VoiceChoice(
          language: language,
          voices: voices,
          chosen: voices.any((v) => v.name == chosen) ? chosen : null,
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
      SpeechStatus.online => l10n.voicesSpeechOnline,
      SpeechStatus.onlineOnly => l10n.voicesSpeechOnlineOnly,
      SpeechStatus.missing => l10n.voicesSpeechMissing,
    };
    final canTest = switch (status) {
      SpeechStatus.onDevice ||
      SpeechStatus.online ||
      SpeechStatus.onlineOnly => true,
      _ => false,
    };
    return <Widget>[
      // Where it is heard only online, the switch carries the line.
      if (online)
        GroupedTile.toggle(
          leading: const Icon(Icons.cloud_outlined, size: 22),
          leadingGap: 12,
          title: l10n.voicesSpeakingPart,
          subtitleOn: l10n.voicesSpeechOnline,
          subtitleOff: l10n.voicesSpeechOnlineOnly,
          padding: EdgeInsetsDirectional.zero,
          value: allowsOnline,
          onChanged: onAllowOnline,
        )
      else
        _Part(
          icon: status == SpeechStatus.missing
              ? Icons.mic_off_outlined
              : Icons.mic_none,
          title: l10n.voicesSpeakingPart,
          line: line,
        ),
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
