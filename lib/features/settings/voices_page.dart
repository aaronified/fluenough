import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/features.dart';
import '../../app/system_settings.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';

/// Which languages the phone can speak, with Test, and how to install a
/// voice.
///
/// Design screen `voices`. Live: every language in the loaded decks, with
/// its voice tag and whether the phone has a voice (installed, missing, or
/// still checking); Test speaks a real card from that language's deck at the
/// learner's speech rate; Check again asks the phone once more
/// (`AppState.refreshVoices`, and `AppState.recheckSpeech` once speaking is
/// set up), for after installing a voice or a language pack.
///
/// The design's "Install voices in phone settings" opens Android's
/// text-to-speech settings, or failing that the voice engine's page for
/// installing voice data, through `AppState.systemSettings`
/// (`Feature.voiceSettingsLink`). Where neither opens — a phone with
/// neither, a platform error, not Android — it explains how to get there,
/// in a dialog.
class VoicesPage extends StatefulWidget {
  const VoicesPage({super.key});

  /// What Test says for [language]: the first card of its first vocabulary
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

  @override
  State<VoicesPage> createState() => _VoicesPageState();
}

class _VoicesPageState extends State<VoicesPage> {
  /// Asking the phone again, after Check again.
  bool _rechecking = false;
  bool _opening = false;

  /// How many voices each available tag has, once asked.
  final Map<String, int> _counts = <String, int>{};
  final Set<String> _asking = <String>{};

  void _countVoices(AppState state, LanguageInfo language) {
    final tag = language.ttsTag;
    if (_counts.containsKey(tag) || !_asking.add(tag)) return;
    state
        .voicesFor(language)
        .then(
          (voices) {
            _asking.remove(tag);
            if (mounted) setState(() => _counts[tag] = voices.length);
          },
          onError: (Object _) {
            _asking.remove(tag);
          },
        );
  }

  Future<void> _checkAgain() async {
    final state = AppScope.read(context);
    setState(() {
      _rechecking = true;
      _counts.clear();
    });
    await Future.wait(<Future<void>>[
      state.refreshVoices(),
      state.recheckSpeech(),
    ]);
    if (mounted) setState(() => _rechecking = false);
  }

  Future<void> _test(AppState state, LanguageInfo language, String text) {
    final l10n = AppLocalizations.of(context)!;
    // Nothing is spoken while sound is off: say so, rather than "Speaking".
    if (!state.settings.soundOn) {
      showAppSnackBar(context, l10n.speakerSoundOff);
      return Future<void>.value();
    }
    showAppSnackBar(context, l10n.voicesSpeaking(text));
    return state.speak(text, language);
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
    final languages = state.languages;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.voicesTitle),
        actions: const <Widget>[ReportButton()],
      ),
      body: ListView(
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
                  _VoiceRow(
                    language: language,
                    status: _rechecking
                        ? VoiceStatus.checking
                        : state.voiceStatus(language),
                    count: _counts[language.ttsTag],
                    sample: VoicesPage.sampleFor(state, language),
                    onCount: () => _countVoices(state, language),
                    onTest: (text) => _test(state, language, text),
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
          if (languages.isNotEmpty &&
              state.features.isAvailable(Feature.drillSpeaking)) ...<Widget>[
            const SizedBox(height: 24),
            _SpeechSection(state: state),
          ],
        ],
      ),
    );
  }
}

/// Which languages the phone's speech recogniser hears, for the speaking
/// drill (#89, ADR-0014), and the learner's leave, per language, to hear
/// one online that the phone cannot hear by itself.
class _SpeechSection extends StatelessWidget {
  const _SpeechSection({required this.state});

  final AppState state;

  Future<void> _switchOn(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final why = switch (await state.setSpeaking(true)) {
      SpeechSetup.ready => null,
      SpeechSetup.refused => l10n.settingsSpeakingRefused,
      SpeechSetup.noRecogniser => l10n.settingsSpeakingNoRecogniser,
    };
    if (why != null && context.mounted) showAppSnackBar(context, why);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = state.settings;
    final style = theme.textTheme.bodyLarge!.copyWith(
      fontSize: 15,
      height: 22 / 15,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final off =
        state.speechReady != true &&
        state.languages.every((l) => state.speechStatus(l) == SpeechStatus.off);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
          child: Text(
            l10n.voicesSpeechHeading,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
          child: Text(
            off ? l10n.voicesSpeechOff : l10n.voicesSpeechIntro,
            style: style,
          ),
        ),
        const SizedBox(height: 16),
        if (off)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.primaryButton),
            ),
            onPressed: () => _switchOn(context),
            icon: const Icon(Icons.mic_none),
            label: Text(l10n.voicesSpeechTurnOn, textAlign: TextAlign.center),
          )
        else
          GroupedList(
            children: <Widget>[
              for (final language in state.languages)
                switch (state.speechStatus(language)) {
                  SpeechStatus.onlineOnly ||
                  SpeechStatus.online => GroupedTile.toggle(
                    title: language.name,
                    subtitle: settings.allowsOnlineSpeech(language.code)
                        ? l10n.voicesSpeechOnline
                        : l10n.voicesSpeechOnlineOnly,
                    value: settings.allowsOnlineSpeech(language.code),
                    onChanged: (on) =>
                        settings.allowOnlineSpeech(language.code, on),
                  ),
                  final status => GroupedTile(
                    title: language.name,
                    subtitle: switch (status) {
                      SpeechStatus.onDevice => l10n.voicesSpeechOnDevice,
                      SpeechStatus.missing => l10n.voicesSpeechMissing,
                      _ => l10n.voicesChecking,
                    },
                  ),
                },
            ],
          ),
      ],
    );
  }
}

/// One language: a status icon, its name and voice tag, its status, and
/// Test when the phone can speak it.
class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.language,
    required this.status,
    required this.count,
    required this.sample,
    required this.onCount,
    required this.onTest,
  });

  final LanguageInfo language;
  final VoiceStatus status;

  /// How many voices the phone has for it, or null until asked.
  final int? count;

  /// A card to speak, or null when the language's decks have none.
  final String? sample;

  /// Asks for [count], when it is still unknown.
  final VoidCallback onCount;

  final ValueChanged<String> onTest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final available = status == VoiceStatus.available;
    if (available && count == null) onCount();

    final String line = switch (status) {
      VoiceStatus.checking => l10n.voicesChecking,
      VoiceStatus.missing => l10n.voicesMissing,
      // An engine that says yes has at least one voice, even if it lists
      // none by name.
      VoiceStatus.available =>
        count == null
            ? l10n.voicesChecking
            : l10n.voicesInstalled(count! < 1 ? 1 : count!),
    };

    final icon = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: available
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
      ),
      child: switch (status) {
        VoiceStatus.available => Icon(
          Icons.check,
          size: 20,
          color: scheme.onPrimaryContainer,
        ),
        VoiceStatus.missing => Icon(
          Icons.volume_off_outlined,
          size: 20,
          color: scheme.onSurfaceVariant,
        ),
        // Still, not a spinner: an endless animation would keep a test or
        // the gallery from ever settling, and the line below says it.
        VoiceStatus.checking => Icon(
          Icons.hourglass_empty,
          size: 20,
          color: scheme.onSurfaceVariant,
        ),
      },
    );

    final text = MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
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
          Text(
            line,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    final say = sample;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 14, 14),
      child: Row(
        children: <Widget>[
          icon,
          const SizedBox(width: 14),
          Expanded(child: text),
          if (available && say != null) ...<Widget>[
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: l10n.voicesTestLabel(language.name),
              excludeSemantics: true,
              onTap: () => onTest(say),
              child: FilledButton.tonalIcon(
                style: AppButtonStyles.compact(context),
                onPressed: () => onTest(say),
                icon: const Icon(Icons.volume_up_outlined, size: 18),
                label: Text(l10n.voicesTest),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
