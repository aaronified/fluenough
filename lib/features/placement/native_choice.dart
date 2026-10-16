import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/report_button.dart';

/// Which of the languages the learner speaks to learn [language] from
/// (ADR-0036): each that teaches it, with how much of the course it
/// teaches so far, [AppState.suggestedNative] chosen to start with.
/// Asked by placement when a course is opened the first time, by Today when
/// a language they speak starts teaching a course they learn, and from
/// Settings ("Learn Telugu from"). [onChosen] gets the native language's
/// code; nothing is saved here.
class NativeChoice extends StatefulWidget {
  const NativeChoice({
    super.key,
    required this.language,
    required this.onChosen,
    this.initial,
  });

  final LanguageInfo language;
  final ValueChanged<String> onChosen;

  /// The choice to start with; [AppState.courseNative] when null.
  final String? initial;

  @override
  State<NativeChoice> createState() => _NativeChoiceState();
}

class _NativeChoiceState extends State<NativeChoice> {
  String? _chosen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final options = state.nativeOptions(widget.language.code);
    final chosen =
        _chosen ?? widget.initial ?? state.courseNative(widget.language.code);
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
      children: <Widget>[
        Text(
          l10n.nativeChoiceTitle(widget.language.name),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.nativeChoiceBody(widget.language.name),
          style: theme.textTheme.bodyLarge!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: l10n.nativeChoiceGroup(widget.language.name),
          child: RadioGroup<String>(
            groupValue: chosen,
            onChanged: (code) => setState(() => _chosen = code),
            child: GroupedList(
              children: <Widget>[
                for (final option in options)
                  GroupedTile(
                    selected: option.native.code == chosen,
                    title: option.native.name,
                    subtitle: coverageLine(l10n, option),
                    onTap: () => setState(() => _chosen = option.native.code),
                    trailing: Radio<String>(
                      value: option.native.code,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          style: AppButtonStyles.tall(context),
          onPressed: chosen == null ? null : () => widget.onChosen(chosen),
          child: Text(l10n.commonContinue),
        ),
      ],
    );
  }

  /// "30 of 34 units so far", "All 34 units", or nothing for a language
  /// with no path.
  static String? coverageLine(AppLocalizations l10n, NativeOption option) {
    final (:covered, :total, native: _) = option;
    if (covered == null || total == null) return null;
    return covered >= total
        ? l10n.nativeChoiceCoverageAll(total)
        : l10n.nativeChoiceCoverage(covered, total);
  }
}

/// [NativeChoice] on a page of its own, from Settings and Today: choosing
/// saves the choice and goes back.
class NativeChoicePage extends StatelessWidget {
  const NativeChoicePage({super.key, required this.language});

  final LanguageInfo language;

  static Future<void> open(BuildContext context, LanguageInfo language) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/native-choice'),
          builder: (_) => NativeChoicePage(language: language),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(language.name),
        actions: const <Widget>[ReportButton()],
      ),
      body: SafeArea(
        top: false,
        child: NativeChoice(
          language: language,
          onChosen: (native) {
            state.chooseNative(language.code, native);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

/// On Today, for each language the profile learns that a language the
/// learner speaks has started teaching since they chose (or that they never
/// chose for): which to learn it from, asked once.
class NativeChoiceCards extends StatelessWidget {
  const NativeChoiceCards({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // The choice is a setting: answered, the card goes.
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) => _cards(context, state),
    );
  }

  Widget _cards(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final due = <LanguageInfo>[
      for (final language in state.languages)
        if (state.currentProfile.learns(language.code) &&
            state.needsNativeChoice(language.code))
          language,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final language in due) ...<Widget>[
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.translate, color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.nativeChoiceNew(language.name),
                    style: theme.textTheme.titleSmall!.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: () => NativeChoicePage.open(context, language),
                  child: Text(l10n.nativeChoiceChoose),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
